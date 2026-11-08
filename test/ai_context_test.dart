import 'package:flutter_test/flutter_test.dart';

import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/ai/ai_context_builder.dart';
import 'package:darooyar/features/ai/ai_insight_repository.dart';
import 'package:darooyar/features/ai/ai_prompts.dart';
import 'package:darooyar/features/ai/doctor_skill.dart';
import 'package:darooyar/features/medications/medication.dart';
import 'package:darooyar/features/meals/meal_slot.dart';
import 'package:darooyar/features/profiles/profile.dart';
import 'package:darooyar/features/schedule/dose_log.dart';
import 'package:darooyar/features/schedule/dose_slot.dart';

/// تعداد وقوع یک زیررشته در متن (برای بررسی نبودِ عنوان تکراری).
int _count(String text, String needle) {
  var total = 0;
  var index = text.indexOf(needle);
  while (index != -1) {
    total++;
    index = text.indexOf(needle, index + needle.length);
  }
  return total;
}

DoseSlot _slot({
  required String time,
  required String name,
  required DoseStatus status,
  String profileName = 'مادر',
}) {
  return DoseSlot(
    medicationId: 1,
    profileId: 1,
    medicationName: name,
    dose: '۱ قرص',
    profileName: profileName,
    profileColorValue: 0xFFFF6A2B,
    dateKey: '2024-06-01',
    timeKey: time,
    scheduledAt: DateTime(2024, 6, 1, int.parse(time.split(':')[0])),
    status: status,
  );
}

MealSlot _meal({
  required String time,
  required String name,
  required DoseStatus status,
}) {
  return MealSlot(
    mealId: 1,
    name: name,
    timeKey: time,
    dateKey: '2024-06-01',
    scheduledAt: DateTime(2024, 6, 1, int.parse(time.split(':')[0])),
    status: status,
  );
}

void main() {
  group('AiContextBuilder — بخش‌های خالص', () {
    test('profilesSection نام، تاریخ ثبت و تعداد دارو را می‌نویسد', () {
      const mother = Profile(
        id: 1,
        name: 'مادر',
        colorValue: 0xFFFF6A2B,
        createdAt: '2024-03-21',
      );
      const son = Profile(
        id: 2,
        name: 'پسر',
        colorValue: 0xFF25A6E8,
        createdAt: '2024-06-01',
      );

      final text = AiContextBuilder.profilesSection(
        profiles: const [mother, son],
        medicationCounts: const {1: 3, 2: 0},
      );

      expect(text, contains('۱) مادر'));
      expect(text, contains('۳ داروی ثبت‌شده'));
      expect(text, contains('۲) پسر'));
      expect(text, contains('۰ داروی ثبت‌شده'));
      expect(text, contains(PersianUtils.formatJalaliFromDateKey('2024-03-21')));
    });

    test('profilesSection بدون فرد، رشتهٔ خالی برمی‌گرداند', () {
      expect(
        AiContextBuilder.profilesSection(
          profiles: const [],
          medicationCounts: const {},
        ),
        '',
      );
    });

    test('medicationsSection دوز، ساعت، باقی‌مانده و هشدار اتمام را می‌نویسد', () {
      final low = Medication(
        id: 1,
        profileId: 1,
        name: 'استامینوفن',
        dose: '۱ قرص',
        times: const ['08:00', '20:00'],
        createdAt: '2024-06-01',
        remainingDoses: 3,
      );
      final gone = Medication(
        id: 2,
        profileId: 2,
        name: 'قرص فشار',
        dose: 'نصف قرص',
        times: const ['09:00'],
        createdAt: '2024-06-01',
        remainingDoses: 0,
      );
      final safe = Medication(
        id: 3,
        profileId: 1,
        name: 'ویتامین د',
        dose: '۱ کپسول',
        times: const ['12:30'],
        createdAt: '2024-06-01',
        remainingDoses: 20,
      );

      final text = AiContextBuilder.medicationsSection(
        medications: [low, gone, safe],
        profileName: (id) => id == 1 ? 'مادر' : 'پسر',
      );

      expect(text, contains('• مادر: استامینوفن — ۱ قرص'));
      expect(text, contains('ساعت مصرف: ۰۸:۰۰، ۲۰:۰۰'));
      expect(text, contains('باقی‌مانده: ۳'));
      expect(text, contains('هشدار اتمام'));
      expect(text, contains('• پسر: قرص فشار'));
      expect(text, contains('تمام شده'));
      expect(text, contains('باقی‌مانده: ۲۰'));
      // داروی سالم نباید هشدار اتمام بگیرد.
      expect(text, isNot(contains('ویتامین د — ۱ کپسول — ساعت مصرف: ۱۲:۳۰ — باقی‌مانده: ۲۰ (')));
    });

    test('medicationsSection بدون دارو خالی است', () {
      expect(
        AiContextBuilder.medicationsSection(
          medications: const [],
          profileName: (_) => '—',
        ),
        '',
      );
    });

    test('scheduleSection آمار، استریک و جزئیات نوبت‌ها را می‌نویسد', () {
      final text = AiContextBuilder.scheduleSection(
        slots: [
          _slot(time: '08:00', name: 'استامینوفن', status: DoseStatus.taken),
          _slot(time: '14:00', name: 'قرص فشار', status: DoseStatus.taken),
          _slot(time: '20:00', name: 'ویتامین د', status: DoseStatus.missed),
        ],
        streakDays: 5,
      );

      expect(text, contains('امروز ۲ از ۳ نوبت دارو خورده شده'));
      expect(text, contains('۱ نوبت مصرف نشده'));
      expect(text, contains('استریک مصرف کامل: ۵ روز پیاپی'));
      expect(text, contains('۰۸:۰۰ — استامینوفن'));
      expect(text, contains('برای مادر: خورده شد'));
      expect(text, contains('برای مادر: مصرف نشده'));
    });

    test('scheduleSection بدون نوبت خالی است', () {
      expect(
        AiContextBuilder.scheduleSection(slots: const [], streakDays: 0),
        '',
      );
    });

    test('mealsSection آمار و وضعیت هر وعده را می‌نویسد', () {
      final text = AiContextBuilder.mealsSection(
        slots: [
          _meal(time: '07:30', name: 'صبحانه', status: DoseStatus.taken),
          _meal(time: '13:00', name: 'ناهار', status: DoseStatus.missed),
          _meal(time: '19:00', name: 'شام', status: DoseStatus.upcoming),
        ],
      );

      expect(text, contains('امروز ۱ از ۳ وعده ثبت شده'));
      expect(text, contains('۱ وعده سپری شده بدون ثبت'));
      expect(text, contains('صبحانه: خورده شد'));
      expect(text, contains('ناهار: مصرف نشده'));
      expect(text, contains('شام: در انتظار'));
    });

    test('mealsSection بدون وعده خالی است', () {
      expect(AiContextBuilder.mealsSection(slots: const []), '');
    });

    test('waterSection امروز و هفته را با ارقام فارسی می‌نویسد', () {
      final text = AiContextBuilder.waterSection(
        cupsToday: 3,
        target: 8,
        week: const {'2024-06-02': 7, '2024-06-01': 5},
      );

      expect(text, contains('امروز ۳ از ۸ لیوان آب نوشیده شده'));
      expect(text, contains('لیوان شش روز اخیر:'));
      expect(
        text,
        contains(
          '${PersianUtils.formatJalaliFromDateKey('2024-06-01')}: ۵ لیوان',
        ),
      );
      expect(
        text,
        contains(
          '${PersianUtils.formatJalaliFromDateKey('2024-06-02')}: ۷ لیوان',
        ),
      );
    });

    test('waterSection بدون هیچ داده‌ای خالی است', () {
      expect(
        AiContextBuilder.waterSection(
          cupsToday: 0,
          target: 8,
          week: const {},
        ),
        '',
      );
    });

    test('healthSection فقط متن خلاصه را می‌آورد', () {
      expect(
        AiContextBuilder.healthSection(summary: '  فرد: مادر\nBMI: ۲۳٫۴  '),
        'فرد: مادر\nBMI: ۲۳٫۴',
      );
      expect(AiContextBuilder.healthSection(summary: '   '), '');
    });

    test('insightSection بینش را با تاریخ شمسی می‌آورد و خالی‌ها را رد می‌کند', () {
      const insight = AiInsight(
        day: '2024-06-01',
        kind: 'daily',
        text: 'وضعیت کلی: خوب — تغذیه: صبحانه بخور.',
        createdAt: '2024-06-01T08:00:00',
      );

      final text = AiContextBuilder.insightSection(insight);
      expect(
        text,
        contains(PersianUtils.formatJalaliFromDateKey('2024-06-01')),
      );
      expect(text, contains('وضعیت کلی: خوب'));

      expect(AiContextBuilder.insightSection(null), '');
      expect(
        AiContextBuilder.insightSection(
          const AiInsight(
            day: '2024-06-01',
            kind: 'daily',
            text: '   ',
            createdAt: 'x',
          ),
        ),
        '',
      );
    });

    test('clip متن بلند را با «…» می‌برد', () {
      final long = List.filled(400, 'الف').join(' ');
      final clipped = AiContextBuilder.clip(long, maxChars: 50);
      expect(clipped.length, lessThanOrEqualTo(51));
      expect(clipped, endsWith('…'));
      expect(AiContextBuilder.clip('کوتاه', maxChars: 50), 'کوتاه');
    });

    test('assemble سرور و پایان را می‌نویسد و بخش خالی را جا می‌اندازد', () {
      final text = AiContextBuilder.assemble(
        dateLabel: '۱ مهر ۱۴۰۴',
        profiles: '۱) مادر',
        schedule: 'امروز ۱ از ۲ نوبت خورده شده',
        health: '',
        water: '',
      );

      expect(text, startsWith(AiPrompts.contextHeader));
      expect(text, endsWith(AiPrompts.contextFooter));
      expect(text, contains('تاریخ امروز: ۱ مهر ۱۴۰۴'));
      expect(text, contains('— افراد (تو اینفو) —'));
      expect(text, contains('— برنامهٔ امروز و پایبندی —'));
      // بخش خالی نباید عنوان بگیرد.
      expect(text, isNot(contains('شاخص‌های سلامت')));
      expect(text, isNot(contains('نوشیدن آب')));
      expect(_count(text, AiPrompts.contextHeader), 1);
      expect(_count(text, AiPrompts.contextFooter), 1);
    });

    test('assemble حتی بدون بخش، سرور را نگه می‌دارد', () {
      final text = AiContextBuilder.assemble(dateLabel: '۱ مهر ۱۴۰۴');
      expect(text, startsWith(AiPrompts.contextHeader));
      expect(text, contains('تاریخ امروز: ۱ مهر ۱۴۰۴'));
      expect(text, endsWith(AiPrompts.contextFooter));
    });
  });

  group('AiPrompts — زمینه و پرامپت‌ها', () {
    test('withSnapshot زمینهٔ بدون سرور را با عنوان «اطلاعات کاربر» می‌پیچد', () {
      final result = AiPrompts.withSnapshot('دستور سیستم', 'وضعیت امروز');

      expect(result, startsWith('دستور سیستم'));
      expect(result, contains(AiPrompts.contextHeader));
      expect(result, contains(AiPrompts.contextFooter));
      expect(result, contains('وضعیت امروز'));
      expect(_count(result, AiPrompts.contextHeader), 1);
    });

    test('withSnapshot زمینهٔ دارای سرور را بدون تکرار ضمیمه می‌کند', () {
      final context = AiContextBuilder.assemble(dateLabel: '۱ مهر ۱۴۰۴');
      final result = AiPrompts.withSnapshot('دستور سیستم', context);

      expect(result, contains('دستور سیستم'));
      expect(_count(result, AiPrompts.contextHeader), 1);
      expect(result, contains('تاریخ امروز: ۱ مهر ۱۴۰۴'));
    });

    test('withSnapshot با زمینهٔ خالی فقط دستور سیستم را برمی‌گرداند', () {
      expect(AiPrompts.withSnapshot('سیستم', '   '), 'سیستم');
      expect(AiPrompts.withSnapshot('سیستم', ''), 'سیستم');
    });

    test('dailyCheckPrompt به بخش «اطلاعات کاربر» ارجاع می‌دهد', () {
      final prompt = AiPrompts.dailyCheckPrompt('متن زمینه');

      expect(prompt, contains(AiPrompts.contextHeader));
      expect(prompt, contains('«اطلاعات کاربر»'));
      expect(prompt, contains('داروها و پایبندی'));
      expect(prompt, contains('متن زمینه'));
      expect(_count(prompt, AiPrompts.contextHeader), 1);
    });

    test('dailyCheckPrompt زمینهٔ دارای سرور را تکرار نمی‌کند', () {
      final context = AiContextBuilder.assemble(dateLabel: '۱ مهر ۱۴۰۴');
      expect(_count(AiPrompts.dailyCheckPrompt(context), AiPrompts.contextHeader), 1);
    });

    test('quickAnalysisPrompt زمینه و موضوع را می‌آورد', () {
      final prompt = AiPrompts.quickAnalysisPrompt(
        snapshot: 'وضعیت',
        topic: 'تحلیل تغذیه',
      );

      expect(prompt, contains(AiPrompts.contextHeader));
      expect(prompt, contains('«اطلاعات کاربر»'));
      expect(prompt, contains('تحلیل تغذیه'));
    });

    test('quickTopics با «تحلیل کامل من» شروع می‌شود و همه prompt دارند', () {
      final topics = AiPrompts.quickTopics;

      expect(topics.first.key, 'full');
      expect(topics.first.label, 'تحلیل کامل من');
      for (final topic in topics) {
        expect(topic.label, isNotEmpty, reason: topic.key);
        expect(topic.prompt, isNotEmpty, reason: topic.key);
        expect(topic.prompt, contains('اطلاعات کاربر'), reason: topic.key);
      }
      // برچسب‌های کاربردی دیگر هم موجودند.
      final labels = [for (final t in topics) t.label];
      expect(labels, contains('بررسی داروهایم'));
      expect(labels, contains('برنامهٔ امروز'));
      expect(labels, contains('تحلیل خواب و سلامت'));
    });

    test('todayLabel تاریخ شمسی بدون رقم لاتین می‌دهد', () {
      final label = AiPrompts.todayLabel();
      expect(label, isNotEmpty);
      expect(RegExp(r'[0-9]').hasMatch(label), isFalse);
    });
  });

  group('DoctorSkill — دستور سیستم', () {
    test('به بخش «اطلاعات کاربر» و تحلیل شخصی اجبار دارد', () {
      final prompt = DoctorSkill.systemPrompt;

      expect(prompt, contains('اطلاعات کاربر'));
      expect(prompt, contains('موظفی'));
      expect(prompt, contains('تحلیل کامل من'));
      expect(prompt, contains('جایگزین ویزیت حضوری پزشک نیست'));
      expect(prompt, contains('اورژانس ۱۱۵'));
    });

    test('چت با زمینهٔ غنی، اطلاعات کاربر را به دستور سیستم اضافه می‌کند', () {
      final context = AiContextBuilder.assemble(
        dateLabel: '۱ مهر ۱۴۰۴',
        profiles: '۱) مادر',
      );
      final system = AiPrompts.withSnapshot(DoctorSkill.systemPrompt, context);

      expect(system, contains('=== اطلاعات کاربر ==='));
      expect(system, contains('۱) مادر'));
      expect(system, contains('پزشک دارویار'));
    });
  });
}
