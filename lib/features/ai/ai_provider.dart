import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:darooyar/core/settings/settings_repository.dart';
import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/ai/ai_config.dart';
import 'package:darooyar/features/ai/ai_insight_repository.dart';
import 'package:darooyar/features/ai/ai_prompts.dart';
import 'package:darooyar/features/ai/ai_service.dart';
import 'package:darooyar/features/ai/doctor_skill.dart';

/// یک پیام چت (کاربر یا مدل).
class AiMessage {
  const AiMessage({required this.fromUser, required this.text, required this.time});

  final bool fromUser;
  final String text;
  final DateTime time;
}

/// وضعیت بخش «دستیار»: تنظیمات opt-in، چت و بررسی روزانه.
class AiProvider extends ChangeNotifier {
  AiProvider({
    AiService? service,
    SettingsRepository? settings,
    AiInsightRepository? insights,
  })  : _service = service ?? const AiService(),
        _settings = settings ?? const SettingsRepository(),
        _insights = insights ?? const AiInsightRepository();

  final AiService _service;
  final SettingsRepository _settings;
  final AiInsightRepository _insights;

  /// حداکثر پیامِ تاریخچه که با هر درخواست به مدل فرستاده می‌شود.
  static const int _historyLimit = 12;

  /// حداکثر پیام نگهداری‌شدهٔ گفتگو (قدیمی‌ترین‌ها حذف می‌شوند).
  static const int _storeLimit = 200;

  bool _enabled = false;
  bool _dailyCheck = true;
  String _model = kAiDefaultModel;
  String? _lastCheckDay;

  bool _busy = false;
  bool _loading = false;
  bool _disposed = false;
  String? _error;

  final List<AiMessage> _messages = [];
  AiInsight? _dailyInsight;

  bool get enabled => _enabled;
  bool get dailyCheck => _dailyCheck;

  /// آیا کلید سازنده در این ساخت قرار دارد؟ (کاربر چیزی وارد نمی‌کند)
  bool get hasApiKey => kAiApiKey.trim().isNotEmpty;
  String get model => _model;
  bool get busy => _busy;
  bool get loading => _loading;
  String? get error => _error;
  List<AiMessage> get messages => List.unmodifiable(_messages);
  AiInsight? get dailyInsight => _dailyInsight;

  /// آیا پیکربندی کامل است؟ (فعال + کلید سازنده در ساخت)
  bool get isConfigured => _enabled && hasApiKey;

  Future<void> load() async {
    _loading = true;
    if (!_disposed) notifyListeners();

    try {
      _enabled = await _settings.getBool(SettingKeys.aiEnabled);
      _dailyCheck = await _settings.getBool(SettingKeys.aiDailyCheck, orElse: true);
      // مدل ذخیره‌شدهٔ نسخه‌های قبلی (مثلاً grok-4.3) روی Gemini کار نمی‌کند؛
      // فقط مدل‌های gemini معتبرند وگرنه مدل پیش‌فرض.
      final storedModel = (await _settings.get(SettingKeys.aiModel)) ?? '';
      final normalized = storedModel.trim().toLowerCase();
      _model = normalized.startsWith('gemini')
          ? normalized
          : kAiDefaultModel;
      _lastCheckDay = await _settings.get(SettingKeys.aiLastCheckDay);
      _dailyInsight = await _insights.latest('daily');
      await _loadChat();
    } catch (e) {
      debugPrint('AiProvider.load: $e');
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// ذخیرهٔ تنظیمات (فعال‌سازی + بررسی روزانه). کلید کاربر نمی‌گیرد؛
  /// کلید از پیش در `ai_config.dart` سازنده ثبت شده است.
  Future<void> saveSettings({
    required bool enabled,
    required bool dailyCheck,
  }) async {
    _enabled = enabled;
    _dailyCheck = dailyCheck;
    _error = null;
    if (!_disposed) notifyListeners();

    await _settings.setBool(SettingKeys.aiEnabled, _enabled);
    await _settings.setBool(SettingKeys.aiDailyCheck, _dailyCheck);
  }

  /// بررسی روزانهٔ خودکار — حداکثر یک بار در روز.
  ///
  /// [snapshot] خلاصهٔ وضعیت است که فراخواننده می‌سازد؛ اگر اجرا نشود
  /// (خاموش/بدون کلید/تکراری) false برمی‌گرداند.
  Future<bool> maybeRunDailyCheck(String snapshot) async {
    if (!isConfigured || !_dailyCheck) return false;

    final today = PersianUtils.dateKey(DateTime.now());
    if (_lastCheckDay == today) return false;

    return runDailyCheck(snapshot, day: today);
  }

  /// اجرای دستی بررسی روزانه (دکمهٔ «بررسی دوباره»).
  Future<bool> runDailyCheck(String snapshot, {String? day}) async {
    if (!isConfigured) {
      _error = 'دستیار هنوز فعال نشده است (کلید هوش مصنوعی در دسترس نیست).';
      if (!_disposed) notifyListeners();
      return false;
    }

    final targetDay = day ?? PersianUtils.dateKey(DateTime.now());
    return _guard(() async {
      final text = await _service.generate(
        model: _model,
        system: DoctorSkill.systemPrompt,
        prompt: AiPrompts.dailyCheckPrompt(snapshot),
      );
      await _insights.save(
        day: targetDay,
        kind: 'daily',
        text: text,
        createdAt: DateTime.now().toIso8601String(),
      );
      await _insights.prune();
      _dailyInsight = await _insights.latest('daily');
      _lastCheckDay = targetDay;
      await _settings.set(SettingKeys.aiLastCheckDay, targetDay);
    });
  }

  /// ارسال پیام چت؛ تاریخچهٔ مکالمه هم به مدل فرستاده می‌شود.
  ///
  /// [snapshot] متن کامل «اطلاعات کاربر» است (`buildAiSnapshot`)؛ با هر
  /// درخواست تازه می‌شود تا مدل همیشه آخرین داده‌های اپ را ببیند.
  /// [displayText] اگر داده شود به‌جای متن خامِ ارسالی در چت نمایش داده
  /// می‌شود (مثلاً برچسب «تحلیل کامل من» جای پرامپت بلند).
  Future<bool> sendChat(
    String message, {
    required String snapshot,
    String? displayText,
  }) async {
    final text = message.trim();
    if (text.isEmpty || _busy) return false;
    if (!isConfigured) {
      _error = 'پزشک هنوز فعال نشده است (کلید هوش مصنوعی در دسترس نیست).';
      if (!_disposed) notifyListeners();
      return false;
    }

    final shown = (displayText ?? '').trim();
    _messages.add(AiMessage(
      fromUser: true,
      text: shown.isEmpty ? text : shown,
      time: DateTime.now(),
    ));
    while (_messages.length > _storeLimit) {
      _messages.removeAt(0);
    }
    _error = null;
    if (!_disposed) notifyListeners();
    await _persistChat();

    // تاریخچهٔ گفتگو (بدون پیام تازه) تا مدل مکالمه را به‌یاد داشته باشد.
    final past = _messages.sublist(0, _messages.length - 1);
    final start = past.length > _historyLimit ? past.length - _historyLimit : 0;
    final history = [
      for (final m in past.sublist(start))
        (role: m.fromUser ? 'user' : 'assistant', content: m.text),
    ];

    return _guard(() async {
      final answer = await _service.generate(
        model: _model,
        system: AiPrompts.withSnapshot(DoctorSkill.systemPrompt, snapshot),
        history: history,
        prompt: text,
        maxTokens: 2200,
        temperature: 0.4,
      );
      _messages.add(AiMessage(
        fromUser: false,
        text: answer,
        time: DateTime.now(),
      ));
      await _persistChat();
    });
  }

  /// تحلیل سریع یک موضوع (دکمه‌های آماده).
  ///
  /// [prompt] متن کاملی است که برای مدل می‌رود (پیش‌فرض: برچسب دکمه) و
  /// برچسب کوتاه همان‌طور که در چت نمایش داده می‌شود باقی می‌ماند.
  Future<bool> quickAnalysis(
    String topicLabel, {
    required String snapshot,
    String? prompt,
  }) {
    return sendChat(
      prompt ?? topicLabel,
      snapshot: snapshot,
      displayText: topicLabel,
    );
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    if (!_disposed) notifyListeners();
  }

  void clearChat() {
    _messages.clear();
    if (!_disposed) notifyListeners();
    unawaited(_settings.remove(SettingKeys.aiChat));
  }

  /// بارگذاری گفتگوی ذخیره‌شدهٔ محلی.
  Future<void> _loadChat() async {
    try {
      final raw = await _settings.get(SettingKeys.aiChat);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final loaded = <AiMessage>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final text = item['t'];
        if (text is! String || text.trim().isEmpty) continue;
        final millis = item['d'];
        loaded.add(AiMessage(
          fromUser: item['u'] == 1,
          text: text,
          time: DateTime.fromMillisecondsSinceEpoch(
            millis is int ? millis : 0,
          ),
        ));
      }
      if (loaded.length > _storeLimit) {
        loaded.removeRange(0, loaded.length - _storeLimit);
      }
      _messages
        ..clear()
        ..addAll(loaded);
    } catch (e) {
      debugPrint('AiProvider chat load: $e');
    }
  }

  /// ذخیرهٔ گفتگو در پایگاه‌دادهٔ محلی (فقط روی دستگاه کاربر).
  Future<void> _persistChat() async {
    try {
      final data = [
        for (final m in _messages)
          {
            'u': m.fromUser ? 1 : 0,
            't': m.text,
            'd': m.time.millisecondsSinceEpoch,
          },
      ];
      await _settings.set(SettingKeys.aiChat, jsonEncode(data));
    } catch (e) {
      debugPrint('AiProvider chat persist: $e');
    }
  }

  /// اجرای یک عملیات شبکه‌ای با مدیریت خطا/بارگذاری.
  Future<bool> _guard(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    if (!_disposed) notifyListeners();

    try {
      await action();
      return true;
    } on AiException catch (e) {
      _error = e.message;
      // پیام کاربری که جواب نگرفت از تاریخچه حذف شود تا چت گیج‌کننده نشود.
      if (_messages.isNotEmpty && _messages.last.fromUser) {
        _messages.removeLast();
      }
      return false;
    } catch (e) {
      debugPrint('AiProvider: $e');
      _error = 'خطای ناشناخته؛ دوباره تلاش کنید.';
      if (_messages.isNotEmpty && _messages.last.fromUser) {
        _messages.removeLast();
      }
      return false;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
