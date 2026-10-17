import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// خطای بخش هوش مصنوعی با پیام فارسی قابل نمایش به کاربر.
class AiException implements Exception {
  const AiException(this.message, {this.isConfig = false});

  final String message;

  /// true یعنی مشکل از تنظیمات (کلید/مدل) است و باید راهنمایی شود.
  final bool isConfig;

  @override
  String toString() => message;
}

/// فراخوانی مدل‌های Google Gemini (سرنویس رایگان).
///
/// - کلید API را فقط کاربر وارد می‌کند و همراهٔ هر درخواست به گوگل می‌رود؛
///   هیچ سرور واسطی در کار نیست.
/// - درخواست‌ها opt-in هستند: تا وقتی کاربر بخش AI را فعال نکرده،
///   هیچ ترافیک شبکه‌ای ارسال نمی‌شود.
class GeminiService {
  const GeminiService();

  static const String _base =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// مدل پیش‌فرض: ارزان‌ترین مدل رایگان (سرنویس رایگان Google AI Studio).
  static const String defaultModel = 'gemini-2.5-flash-lite';

  Future<String> generate({
    required String apiKey,
    required String model,
    required String system,
    required String prompt,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final trimmedKey = apiKey.trim();
    if (trimmedKey.isEmpty) {
      throw const AiException(
        'کلید API وارد نشده است. در بخش تنظیمات دستیار، کلید Gemini را ثبت کنید.',
        isConfig: true,
      );
    }

    final endpoint = Uri.parse(
      '$_base/${Uri.encodeComponent(model.trim())}:generateContent',
    );

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': system},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.6,
        'maxOutputTokens': 1024,
      },
    });

    final http.Response response;
    try {
      response = await http
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': trimmedKey,
            },
            body: body,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AiException('پاسخ‌گیری از هوش مصنوعی طول کشید؛ اینترنت را بررسی کنید.');
    } catch (e) {
      debugPrint('GeminiService network: $e');
      throw const AiException('اتصال به اینترنت برقرار نیست.');
    }

    return _parse(response);
  }

  String _parse(http.Response response) {
    final status = response.statusCode;
    if (status == 200) {
      try {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final candidates = data['candidates'];
        if (candidates is! List || candidates.isEmpty) {
          final feedback = data['promptFeedback']?['blockReason'];
          if (feedback != null) {
            throw const AiException('پاسخ توسط مدل مسدود شد؛ متن را ساده‌تر کنید.');
          }
          throw const AiException('پاسخی از مدل دریافت نشد؛ دوباره تلاش کنید.');
        }
        final parts = candidates[0]['content']?['parts'];
        if (parts is! List) {
          throw const AiException('پاسخ نامعتبر از مدل دریافت شد.');
        }
        final text = parts
            .map((p) => p is Map ? (p['text'] as String? ?? '') : '')
            .join()
            .trim();
        if (text.isEmpty) {
          throw const AiException('پاسخ خالی از مدل دریافت شد؛ دوباره تلاش کنید.');
        }
        return text;
      } on AiException {
        rethrow;
      } catch (e) {
        debugPrint('GeminiService parse: $e');
        throw const AiException('پاسخ هوش مصنوعی قابل خواندن نبود؛ دوباره تلاش کنید.');
      }
    }

    if (status == 400 || status == 401 || status == 403) {
      throw const AiException(
        'کلید API نامعتبر است یا دسترسی ندارد. کلید را در تنظیمات دستیار بررسی کنید.',
        isConfig: true,
      );
    }
    if (status == 404) {
      throw const AiException(
        'شناسهٔ مدل پیدا نشد. شناسهٔ مدل را در تنظیمات دستیار بررسی کنید.',
        isConfig: true,
      );
    }
    if (status == 429) {
      throw const AiException('سهمیهٔ رایگان مدل تمام شد؛ کمی بعد دوباره تلاش کنید.');
    }

    debugPrint('GeminiService HTTP $status: ${response.body}');
    throw const AiException('خطای ناشناخته از سرویس هوش مصنوعی؛ بعداً تلاش کنید.');
  }
}
