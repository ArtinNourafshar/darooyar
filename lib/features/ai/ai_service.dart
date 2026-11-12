import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:darooyar/features/ai/ai_config.dart';

/// خطای بخش هوش مصنوعی با پیام فارسی قابل نمایش به کاربر.
class AiException implements Exception {
  const AiException(this.message, {this.isConfig = false});

  final String message;

  /// true یعنی مشکل از پیکربندی (کلید/مدل) است و باید راهنمایی شود.
  final bool isConfig;

  @override
  String toString() => message;
}

/// فراخوانی مدل‌های Google Gemini (سازگار با API شرکت OpenAI).
///
/// - کلید سازنده در `ai_config.dart` ثبت شده و کاربر نهایی چیزی وارد نمی‌کند؛
///   هیچ سرور واسطی در کار نیست.
/// - درخواست‌ها opt-in هستند: تا وقتی کاربر بخش دستیار را فعال نکرده،
///   هیچ ترافیک شبکه‌ای ارسال نمی‌شود.
class AiService {
  const AiService();

  /// یک پاسخ از مدل می‌گیرد؛ [history] تاریخچهٔ چت (نقش‌های user/assistant)
  /// است تا مدل مکالمهٔ قبلی را به‌یاد داشته باشد.
  Future<String> generate({
    String system = '',
    required String prompt,
    String? model,
    List<({String role, String content})> history = const [],
    int maxTokens = 900,
    double temperature = 0.6,
  }) async {
    final key = kAiApiKey.trim();
    if (key.isEmpty) {
      throw const AiException(
        'کلید هوش مصنوعی در این ساخت برنامه قرار نگرفته است؛ '
        'با سازندهٔ برنامه تماس بگیرید.',
        isConfig: true,
      );
    }

    final requestedModel = (model ?? '').trim();
    final uri = Uri.parse('$kAiBaseUrl/chat/completions');
    final body = jsonEncode({
      'model': requestedModel.isEmpty ? kAiDefaultModel : requestedModel,
      'messages': [
        if (system.trim().isNotEmpty)
          {'role': 'system', 'content': system.trim()},
        for (final turn in history)
          {'role': turn.role, 'content': turn.content},
        {'role': 'user', 'content': prompt},
      ],
      'temperature': temperature,
      'max_tokens': maxTokens,
    });

    // تا دو بار تلاش می‌شود (شبکهٔ موبایل معمولاً در تلاش اول قطع می‌کند).
    Object? lastError;
    http.Response? response;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      try {
        response = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $key',
              },
              body: body,
            )
            .timeout(const Duration(seconds: 45));
        break;
      } on TimeoutException {
        lastError = const AiException(
          'پاسخی از دستیار نرسید (شبکه کند است)؛ دوباره تلاش کنید.',
        );
      } catch (e) {
        debugPrint('AiService attempt $attempt: $e');
        lastError = const AiException(
          'اتصال به دستیار برقرار نشد؛ اینترنت را بررسی کنید '
          'و در صورت نیاز VPN روشن کنید.',
        );
      }
    }
    final resp = response;
    if (resp == null) {
      throw lastError is AiException
          ? lastError
          : const AiException(
              'اتصال به دستیار برقرار نشد؛ دوباره تلاش کنید.',
            );
    }

    if (resp.statusCode == 200) {
      try {
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
        final text = decoded['choices']?[0]?['message']?['content'] as String?;
        if (text == null || text.trim().isEmpty) {
          throw const AiException('دستیار پاسخ خالی فرستاد؛ دوباره بپرسید.');
        }
        return text.trim();
      } catch (e) {
        debugPrint('AiService parse: $e');
        throw const AiException('پاسخ دستیار قابل خواندن نبود؛ دوباره تلاش کنید.');
      }
    }

    debugPrint('AiService HTTP ${resp.statusCode}: ${resp.body}');

    // مدل درخواستی در دسترس نیست → یک بار با مدل جایگزین تلاش شود.
    if (resp.statusCode == 404 && requestedModel != kAiFallbackModel) {
      return generate(
        system: system,
        prompt: prompt,
        model: kAiFallbackModel,
        history: history,
        maxTokens: maxTokens,
        temperature: temperature,
      );
    }

    throw AiException(
      _messageFor(resp.statusCode),
      isConfig: resp.statusCode == 401,
    );
  }

  /// آیا کلید در این ساخت وجود دارد؟ (برای پیام‌های دقیق‌تر)
  static bool get hasKey => kAiApiKey.trim().isNotEmpty;

  String _messageFor(int code) {
    if (code == 401) {
      return 'کلید هوش مصنوعی معتبر نیست؛ آخرین نسخهٔ برنامه را نصب کنید.';
    }
    if (code == 403) {
      // ۴۰۳ معمولاً یعنی سرور گوگل از این شبکه/کشور در دسترس نیست، نه اینکه
      // کلید خراب باشد — پس کاربر نباید به خطا مقصر دانسته شود.
      return 'اتصال به سرور گوگل مسدود است؛ VPN را روشن کنید و دوباره '
          'تلاش کنید. (این خطا معمولاً به کلید شما مربوط نیست.)';
    }
    if (code == 402) {
      return 'موجودی حساب هوش مصنوعی کافی نیست؛ مدل رایگان انتخاب شده؟';
    }
    if (code == 404) {
      return 'مدل درخواستی در دسترس نیست؛ دوباره تلاش کنید.';
    }
    if (code == 429) {
      return 'سهمیهٔ روزانهٔ دستیار پر شد؛ کمی بعد دوباره تلاش کنید.';
    }
    if (code >= 500) {
      return 'سرویس دستیار موقتاً در دسترس نیست؛ دوباره تلاش کنید.';
    }
    return 'خطا در برقراری ارتباط با دستیار (کد $code).';
  }
}
