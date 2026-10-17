import 'package:flutter/foundation.dart';

import 'package:darooyar/core/settings/settings_repository.dart';
import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/ai/ai_config.dart';
import 'package:darooyar/features/ai/ai_insight_repository.dart';
import 'package:darooyar/features/ai/ai_prompts.dart';
import 'package:darooyar/features/ai/grok_service.dart';

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
    GrokService? service,
    SettingsRepository? settings,
    AiInsightRepository? insights,
  })  : _service = service ?? const GrokService(),
        _settings = settings ?? const SettingsRepository(),
        _insights = insights ?? const AiInsightRepository();

  final GrokService _service;
  final SettingsRepository _settings;
  final AiInsightRepository _insights;

  bool _enabled = false;
  bool _dailyCheck = true;
  String _model = kGrokDefaultModel;
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
  bool get hasApiKey => kGrokApiKey.trim().isNotEmpty;
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
      final storedModel = await _settings.get(SettingKeys.aiModel);
      _model = (storedModel == null || storedModel.trim().isEmpty)
          ? kGrokDefaultModel
          : storedModel.trim();
      _lastCheckDay = await _settings.get(SettingKeys.aiLastCheckDay);
      _dailyInsight = await _insights.latest('daily');
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
        system: AiPrompts.systemInstruction,
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

  /// ارسال پیام چت؛ پاسخ به تاریخچه اضافه می‌شود.
  Future<bool> sendChat(String message, {required String snapshot}) async {
    final text = message.trim();
    if (text.isEmpty || _busy) return false;
    if (!isConfigured) {
      _error = 'دستیار هنوز فعال نشده است (کلید هوش مصنوعی در دسترس نیست).';
      if (!_disposed) notifyListeners();
      return false;
    }

    _messages.add(AiMessage(
      fromUser: true,
      text: text,
      time: DateTime.now(),
    ));
    _error = null;
    if (!_disposed) notifyListeners();

    return _guard(() async {
      final answer = await _service.generate(
        model: _model,
        system: AiPrompts.systemInstruction,
        prompt: AiPrompts.chatPrompt(snapshot: snapshot, userMessage: text),
      );
      _messages.add(AiMessage(
        fromUser: false,
        text: answer,
        time: DateTime.now(),
      ));
    });
  }

  /// تحلیل سریع یک موضوع (دکمه‌های آماده).
  Future<bool> quickAnalysis(String topicLabel, {required String snapshot}) {
    return sendChat(topicLabel, snapshot: snapshot);
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    if (!_disposed) notifyListeners();
  }

  void clearChat() {
    _messages.clear();
    if (!_disposed) notifyListeners();
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
