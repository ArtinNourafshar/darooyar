import 'package:flutter_test/flutter_test.dart';

import 'package:darooyar/features/medications/medication.dart';
import 'package:darooyar/features/profiles/profile.dart';
import 'package:darooyar/features/schedule/dose_log.dart';
import 'package:darooyar/features/schedule/dose_slot.dart';

void main() {
  final profile = Profile(
    id: 1,
    name: 'مادر',
    colorValue: 0xFF16706B,
    createdAt: '2025-01-01',
  );

  Medication medication({
    List<String>? times,
    String? createdAt,
    String? createdTime,
    int? id,
  }) {
    return Medication(
      id: id ?? 1,
      profileId: 1,
      name: 'استامینوفن',
      dose: '۱ قرص',
      times: times ?? ['08:00', '20:00'],
      createdAt: createdAt ?? '2025-01-01',
      createdTime: createdTime ?? '00:00',
    );
  }

  DoseLog log({required int medicationId, required String time, required String status}) {
    return DoseLog(
      medicationId: medicationId,
      logDate: '2025-10-02',
      logTime: time,
      status: status,
      confirmedAt: '2025-10-02T08:01:00.000',
    );
  }

  const dateKey = '2025-10-02';

  // ساعت ۱۰ صبح: نوبت ۰۸ گذشته و نوبت ۲۰ آینده است.
  final now = DateTime(2025, 10, 2, 10, 0);

  List<DoseSlot> build({
    List<Medication>? meds,
    List<Profile>? profiles,
    Map<String, DoseLog>? logs,
    int? profileFilterId,
    DateTime? at,
  }) {
    final logMap = <String, DoseLog>{};
    for (final entry in (logs ?? <String, DoseLog>{}).entries) {
      logMap['${entry.value.medicationId}|${entry.value.logTime}'] = entry.value;
    }
    return DoseSlotBuilder.build(
      medications: meds ?? [medication()],
      profiles: profiles ?? [profile],
      logs: logMap,
      dateKey: dateKey,
      now: at ?? now,
      profileFilterId: profileFilterId,
    );
  }

  group('DoseSlotBuilder', () {
    test('بدون سابقه: زمان گذشته missed و زمان آینده upcoming است', () {
      final slots = build();
      expect(slots, hasLength(2));
      expect(slots[0].timeKey, '08:00');
      expect(slots[0].status, DoseStatus.missed);
      expect(slots[1].timeKey, '20:00');
      expect(slots[1].status, DoseStatus.upcoming);
    });

    test('سابقهٔ مصرف روی وضعیت اولویت دارد (taken و skipped)', () {
      final slots = build(
        logs: {
          '08:00': log(medicationId: 1, time: '08:00', status: 'taken'),
          '20:00': log(medicationId: 1, time: '20:00', status: 'skipped'),
        },
      );
      expect(slots[0].status, DoseStatus.taken);
      expect(slots[1].status, DoseStatus.skipped);
      expect(slots[0].isConfirmed, isTrue);
      expect(slots[1].isConfirmed, isTrue);
    });

    test('هر دو زمان گذشته بدون سابقه missed می‌شوند', () {
      final slots = build(at: DateTime(2025, 10, 2, 23, 59));
      expect(slots.every((s) => s.status == DoseStatus.missed), isTrue);
    });

    test('هر دو زمان آینده upcoming می‌شوند', () {
      final slots = build(at: DateTime(2025, 10, 2, 6, 0));
      expect(slots.every((s) => s.status == DoseStatus.upcoming), isTrue);
    });

    test('فیلتر فرد فقط داروهای همان فرد را می‌آورد', () {
      final otherProfile = Profile(
        id: 2,
        name: 'پدر',
        colorValue: 0xFF3F6FA8,
        createdAt: '2025-01-01',
      );
      final other = Medication(
        id: 2,
        profileId: 2,
        name: 'ویتامین',
        dose: '۱ عدد',
        times: ['09:00'],
        createdAt: '2025-01-01',
      );
      final meds = [medication(), other];
      final people = [profile, otherProfile];

      // profileFilterId ناموجود → هیچ نوبتی ساخته نمی‌شود.
      expect(build(profileFilterId: 99), isEmpty);
      // فیلتر فرد اول → فقط داروهای او (۲ نوبت).
      expect(
        build(meds: meds, profiles: people, profileFilterId: 1),
        hasLength(2),
      );
      expect(
        build(meds: meds, profiles: people, profileFilterId: 1)
            .every((s) => s.profileId == 1),
        isTrue,
      );
      // فیلتر فرد دوم → فقط داروی او (۱ نوبت).
      expect(
        build(meds: meds, profiles: people, profileFilterId: 2),
        hasLength(1),
      );
    });

    test('دارویی که هنوز در این تاریخ ثبت نشده نوبتی ندارد', () {
      final slots = build(meds: [medication(createdAt: '2025-10-03')]);
      expect(slots, isEmpty);
    });

    test('داروی ثبت‌شده در میانهٔ روز، نوبت‌های پیش از ثبت را ندارد', () {
      // ثبت در ساعت ۱۵ → نوبت ۰۸ امروز نباید «مصرف نشده» شمرده شود.
      final slots = build(
        meds: [medication(createdAt: dateKey, createdTime: '15:00')],
      );
      expect(slots, hasLength(1));
      expect(slots.single.timeKey, '20:00');
    });

    test('نوبت پیش از ثبت، فقط با سابقهٔ معتبر نمایش داده می‌شود', () {
      final slots = build(
        meds: [medication(createdAt: dateKey, createdTime: '15:00')],
        logs: {
          '08:00': log(medicationId: 1, time: '08:00', status: 'taken'),
        },
      );
      expect(slots, hasLength(2));
      expect(slots.first.timeKey, '08:00');
      expect(slots.first.status, DoseStatus.taken);
    });

    test('داروی قدیمی (بدون ساعت ثبت دقیق) همهٔ نوبت‌های روز را دارد', () {
      final slots = build(meds: [medication(createdAt: dateKey)]);
      expect(slots, hasLength(2));
    });

    test('فیلدهای نمایشی کلید و برچسب درست ساخته می‌شوند', () {
      final slot = build().first;
      expect(slot.medicationId, 1);
      expect(slot.profileName, 'مادر');
      expect(slot.medicationName, 'استامینوفن');
      expect(slot.dose, '۱ قرص');
      expect(slot.dateKey, dateKey);
      expect(slot.logKey, '1|08:00');
      expect(slot.timeLabel, '۰۸:۰۰');
    });

    test('نوبت‌ها بر اساس ساعت مرتب می‌شوند', () {
      final other = Medication(
        id: 2,
        profileId: 1,
        name: 'ویتامین',
        dose: '۱ عدد',
        times: ['07:30'],
        createdAt: '2025-01-01',
      );
      final slots = build(meds: [medication(), other]);
      expect(
        slots.map((s) => s.timeKey).toList(),
        ['07:30', '08:00', '20:00'],
      );
    });
  });
}
