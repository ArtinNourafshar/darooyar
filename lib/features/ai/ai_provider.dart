import 'package:flutter/foundation.dart';

import 'package:darooyar/core/settings/settings_repository.dart';
import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/ai/ai_insight_repository.dart';
import 'package:darooyar/features/ai/ai_prompts.dart';
import 'package:darooyar/features/ai/gemini_service.dart';

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
    GeminiService? service,
    SettingsRepository? settings,
    AiInsightRepository? insights,
  })  : _service = service ?? const GeminiService(),
        _settings = settings ?? const SettingsRepository(),
        _insights = insights ?? const AiInsightRepository();

  final GeminiService _service;
  final SettingsRepository _settings;
  final AiInsightRepository _insights;

  bool _enabled = false;
  bool _dailyCheck = true;
  String _apiKey = '';
  String _model = GeminiService.defaultModel;
  String? _lastCheckDay;

  bool _busy = false;
  bool _loading = false;
  bool _disposed = false;
  String? _error;

  final List<AiMessage> _messages = [];
  AiInsight? _dailyInsight;

  bool get enabled => _enabled;
  bool get dailyCheck => _dailyCheck;

  /// کلید API (برای نمایش بخشی از آن در تنظیمات).
  String get apiKeyMasked {
    if (_apiKey.isEmpty) return '';
    if (_apiKey.length <= 8) return '••••••';
    return '••••••${_apiKey.substring(_apiKey.length - 4)}';
  }

  bool get hasApiKey => _apiKey.isNotEmpty;
  String get model => _model;
  bool get busy => _busy;
  bool get loading => _loading;
  String? get error => _error;
  List<AiMessage> get messages => List.unmodifiable(_messages);
  AiInsight? get dailyInsight => _dailyInsight;

  /// آیا پیکربندی کامل است؟ (فعال + کلید)
  bool get isConfigured => _enabled && _apiKey.isNotEmpty;

  Future<void> load() async {
    _loading = true;
    if (!_disposed) notifyListeners();

    try {
      _enabled = await _settings.getBool(SettingKeys.aiEnabled);
      _dailyCheck = await _settings.getBool(SettingKeys.aiDailyCheck, orElse: true);
      _apiKey = await _settings.get(SettingKeys.aiApiKey) ?? '';
      _model =
          await _settings.get(SettingKeys.aiModel) ?? GeminiService.defaultModel;
      _lastCheckDay = await _settings.get(SettingKeys.aiLastCheckDay);
      _dailyInsight = await _insights.latest('daily');
    } catch (e) {
      debugPrint('AiProvider.load: $e');
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// ذخیرهٔ تنظیمات (کلید/مدل/فعال‌سازی). کلید را خالی بگذارید تا پاک شود.
  Future<void> saveSettings({
    required bool enabled,
    required bool dailyCheck,
    required String apiKey,
    String? model,
  }) async {
    _enabled = enabled;
    _dailyCheck = dailyCheck;
    _apiKey = apiKey.trim();
    final newModel = (model ?? '').trim();
    if (newModel.isNotEmpty && newModel != _model) _model = newModel;
    _error = null;
    if (!_disposed) notifyListeners();

    await _settings.setBool(SettingKeys.aiEnabled, _enabled);
    await _settings.setBool(SettingKeys.aiDailyCheck, _dailyCheck);
    if (_apiKey.isEmpty) {
      await _settings.remove(SettingKeys.aiApiKey);
    } else {
      await _settings.set(SettingKeys.aiApiKey, _apiKey);
    }
    await _settings.set(SettingKeys.aiModel, _model);
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
      _error = 'برای بررسی روزانه، ابتدا کلید API را ثبت کنید.';
      if (!_disposed) notifyListeners();
      return false;
    }

    final targetDay = day ?? PersianUtils.dateKey(DateTime.now());
    return _guard(() async {
      final text = await _service.generate(
        apiKey: _apiKey,
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
      _error = 'برای چت، ابتدا کلید API را ثبت کنید.';
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
        apiKey: _apiKey,
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
