import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'package:darooyar/core/alarms/alarm_payload.dart';
import 'package:darooyar/core/notifications/notification_service.dart';
import 'package:darooyar/core/settings/settings_repository.dart';
import 'package:darooyar/core/utils/persian_utils.dart';

/// پوشش تمام‌صفحهٔ زنگ — دقیقاً مثل الارم گوشی:
///
/// - صدای زنگ **حلقه‌ای** (هرگز تمام نمی‌شود) تا وقتی کاربر
///   دکمهٔ «قطع زنگ» را بزند؛ خروج از پوشش با دکمهٔ بازگشت/لمس بیرون
///   ممکن نیست (`barrierDismissible: false` + `PopScope(canPop: false)`).
/// - ساعت زنده، آیکون پالس‌دار و دکمه‌های «قطع زنگ» و «چرت ۵ دقیقه».
/// - پس از قطع، نوتیفیکیشن لغو و زمان‌بندی بعدی همان نوبت ساخته می‌شود.
class AlarmOverlay extends StatefulWidget {
  const AlarmOverlay({super.key, required this.alarm});

  final AlarmPayload alarm;

  static bool _visible = false;

  /// نمایش پوشش زنگ (فقط یک نمونه همزمان).
  static Future<void> show(BuildContext context, AlarmPayload alarm) async {
    if (_visible || !context.mounted) return;
    _visible = true;
    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (_) => AlarmOverlay(alarm: alarm),
      );
    } finally {
      _visible = false;
    }
  }

  @override
  State<AlarmOverlay> createState() => _AlarmOverlayState();
}

class _AlarmOverlayState extends State<AlarmOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  AudioPlayer? _player;
  Timer? _clock;
  DateTime _now = DateTime.now();
  bool _busy = false;
  bool _soundFailed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      lowerBound: 0.85,
      upperBound: 1.15,
      value: 1,
    )..repeat(reverse: true);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    unawaited(_startRinging());
  }

  /// شروع صدای حلقه‌ای زنگ (صدای انتخابی کاربر).
  Future<void> _startRinging() async {
    try {
      final value = await const SettingsRepository().get(SettingKeys.alarmSound);
      final index = int.tryParse(value ?? '') ?? 1;
      final file = index == 1 ? 'audio/alarm_beep.wav' : 'audio/alarm_beep$index.wav';

      final player = AudioPlayer();
      // استفاده از stream آلارم اندروید: با صدای بلند و بدون دخالت دکمه‌های رسانه.
      await player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
          ),
        ),
      );
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(1);
      await player.play(AssetSource(file));
      _player = player;
    } catch (e) {
      debugPrint('خطا در پخش صدای زنگ: $e');
      if (mounted) setState(() => _soundFailed = true);
    }
  }

  Future<void> _stopSound() async {
    final player = _player;
    _player = null;
    if (player == null) return;
    try {
      await player.stop();
      await player.dispose();
    } catch (_) {}
  }

  Future<void> _stop() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _stopSound();
    try {
      await NotificationService.instance.stopAlarmFromUi(widget.alarm);
    } catch (e) {
      debugPrint('خطا در قطع زنگ: $e');
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _snooze() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _stopSound();
    try {
      await NotificationService.instance.snoozeAlarmFromUi(widget.alarm);
    } catch (e) {
      debugPrint('خطا در چرت زنگ: $e');
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _pulse.dispose();
    unawaited(_stopSound());
    super.dispose();
  }

  String get _clockText =>
      PersianUtils.toPersianDigits(PersianUtils.formatTime(_now));

  @override
  Widget build(BuildContext context) {
    final description = NotificationService.instance.describeAlarm(widget.alarm);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _pulse,
                    child: Container(
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.alarm_rounded,
                        size: 72,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    _clockText,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily: 'IRANYekan',
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'IRANYekan',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      height: 1.6,
                    ),
                  ),
                  if (_soundFailed) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'پخش صدا ممکن نشد؛ لطفاً دکمهٔ قطع را بزنید.',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 13,
                        color: Colors.orangeAccent,
                      ),
                    ),
                  ],
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _stop,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      icon: const Icon(Icons.stop_circle_rounded, size: 28),
                      label: const Text('قطع زنگ'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _snooze,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54, width: 1.4),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: const Icon(Icons.snooze_rounded),
                      label: const Text('چرت ۵ دقیقه'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'زنگ تا فشردن «قطع زنگ» ادامه دارد',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'IRANYekan',
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
