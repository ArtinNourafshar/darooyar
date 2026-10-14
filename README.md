<div dir="rtl">

# دارویار 🩺 | Darooyar

**یادآور داروی خانوادگی — کاملاً آفلاین، فارسی و راست‌چین**

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Platforms](https://img.shields.io/badge/platform-Windows%20%7C%20Android-333?logo=windows&logoColor=white)
![Tests](https://img.shields.io/badge/tests-29%20passed-4c1?logo=pytest&logoColor=white)
![Offline](https://img.shields.io/badge/data-local%20only%20SQLite-007EC6?logo=sqlite&logoColor=white)

دارویار یک اپلیکیشن **فلاتر** برای یادآوری مصرف داروی اعضای خانواده است؛ با تمرکز بر سالمندان و خانواده‌هایی که چند داروی زمان‌بندی‌شده دارند. همهٔ داده‌ها **به‌صورت محلی** (SQLite) ذخیره می‌شوند، برنامه **هیچ دسترسی به اینترنت ندارد** و رابط کاربری **فارسی و راست‌چین** است.

> **English:** Darooyar is a Persian, RTL, offline-first family medication reminder for Windows and Android. All data stays in a local SQLite database — no account, no server, no internet permission.

<!-- Screenshots: در نسخه‌های بعدی اسکرین‌شات‌های صفحهٔ «امروز»، «داروها» و «گزارش» اینجا قرار می‌گیرد. -->

---

## امکانات

| بخش | جزئیات |
|---|---|
| **افراد خانواده** | پروفایل چندنفره با نام، توضیح و **رنگ اختصاصی** هر فرد برای تشخیص سریع |
| **داروها** | ثبت نام دارو، دوز، شکل مصرف و **چند نوبت ساعتی در روز** برای هر فرد |
| **صفحهٔ «امروز»** | فهرست نوبت‌های امروز با وضعیت‌های «در انتظار / خورده شد / نخوردم / مصرف نشده» و تأیید یک‌لمسی |
| **یادآوری** | نوتیفیکیشن محلی در زمان مصرف؛ در اندروید زمان‌بندی تکرار روزانه + بازسازی پس از ری‌استارت، در ویندوز زمان‌بندی تکی + یادآوری درون‌برنامه‌ای |
| **گزارش مصرف** | بازه‌های «امروز / ۷ روز / ۳۰ روز / همه»، آمار **پایبندی** به درمان و **خروجی PDF** راست‌به‌چپ |
| **تاریخ شمسی** | ذخیرهٔ میلادی، نمایش شمسی با ارقام فارسی |
| **تم و دسترس‌پذیری** | تم داینامیک Material You (رنگ سیستم)، حالت روشن/تیره، مقیاس فونت کاربر ۰٫۸ تا ۱٫۸، چیدمان رسپانسیو از موبایل تا پنجره‌های عریض دسکتاپ |

### چرا کاملاً آفلاین؟

- **بدون دسترسی اینترنت:** مانیفست نسخهٔ نهایی اندروید فقط مجوزهای نوتیفیکیشن را دارد؛ خبری از `INTERNET`، سرور یا حساب کاربری نیست.
- **بدون واسط:** پایگاه‌دادهٔ `darooyar.db` در پوشهٔ دادهٔ خود برنامه می‌ماند و خروجی PDF در پوشهٔ `darooyar_reports/` داخل «اسناد» ذخیره می‌شود.
- داده‌های سلامتی خانواده حتی در اختیار توسعه‌دهنده هم قرار نمی‌گیرد.

---

## پشتهٔ فنی

| لایه | انتخاب | چرا |
|---|---|---|
| UI | Flutter + Material 3 | یک کدپایه برای ویندوز و اندروید |
| State | `provider` | ساده و کافی برای این اندازه اپ |
| DB | `sqflite` (موبایل) / `sqflite_common_ffi` (دسکتاپ) | پشت یک سرویس واحد `DatabaseService` |
| Notifications | `flutter_local_notifications` + `timezone` | زمان‌بندی منطقه‌ای و بازسازی پس از ری‌استارت |
| گزارش | `pdf` + `open_filex` | خروجی PDF راست‌به‌چپ بدون وابستگی به اینترنت |
| تاریخ | `shamsi_date` | تبدیل میلادی به شمسی فقط در لایهٔ نمایش |
| رنگ | `dynamic_color` | Material You با بذر رنگ پیش‌فرض `0xFF16706B` |
| فونت | IRANYekan (۸ وزن) | خوانایی فارسی در هر اندازه |

---

## شروعٔ سریع

### پیش‌نیازها

- **Flutter SDK** با نسخهٔ Dart `^3.13`
- برای اندروید: Android SDK + JDK 17
- برای ویندوز: Visual Studio 2022 با کامپوننت *Desktop development with C++*

### نصب و اجرا

```bash
git clone https://github.com/ArtinNourafshar/darooyar.git
cd darooyar

flutter pub get

# ویندوز
flutter run -d windows

# اندروید (دستگاه یا شبیه‌ساز متصل)
flutter run -d android
```

هیچ متغیر محیطی سفارشی یا سرویس جانبی لازم نیست.

### کیفیت و تست

```bash
flutter analyze   # بدون هیچ خطایی
flutter test      # ۲۹ تست (منطقی + ویجت)
```

پوشش تست: ارقام و تاریخ فارسی، ساخت نوبت‌ها و وضعیت‌ها، بازه‌ها و آمار گزارش، و تست ویجت پوسته (راست‌چین، تم مات، ناوبری، نسخهٔ عریض).

### ساخت خروجی ریلیز

```bash
# اندروید → build/app/outputs/flutter-apk/app-release.apk
flutter build apk --release

# ویندوز → build/windows/x64/runner/Release/
flutter build windows --release
```

نسخه‌های منتشرشده (exe تک‌فایل ویندوز و APK اندروید) در بخش [Releases](../../releases) قرار می‌گیرند.

---

## ساختار پروژه

```
darooyar/
├── assets/fonts/                  فونت‌های IRANYekan (۸ وزن)
├── lib/
│   ├── main.dart                  راه‌اندازی DB و نوتیفیکیشن، سپس اپ
│   ├── app.dart                   MaterialApp: locale فارسی، تم داینامیک، clamp مقیاس فونت
│   ├── core/
│   │   ├── database/database_service.dart        سرویس Singleton پایگاه‌داده
│   │   ├── notifications/notification_service.dart  زمان‌بندی نوتیفیکیشن‌ها
│   │   ├── pdf/pdf_report_service.dart           ساخت و ذخیرهٔ گزارش PDF
│   │   ├── responsive/responsive.dart            کلاس‌های مقیاس و رفتار پنجره
│   │   ├── theme/app_theme.dart                  تم مات Material You
│   │   └── utils/persian_utils.dart              ارقام فارسی، ساعت و تاریخ شمسی
│   ├── features/
│   │   ├── profiles/               مدل / ریپازیتوری / پرووایدر / صفحهٔ افراد
│   │   ├── medications/            مدل / ریپازیتوری / پرووایدر / صفحهٔ داروها
│   │   ├── schedule/               DoseLog، DoseSlot، ScheduleProvider، صفحهٔ «امروز»
│   │   └── reports/                مدل‌ها، آمار پایبندی و PDF + صفحهٔ گزارش
│   ├── shared/widgets/             EmptyState، StatusBadge
│   └── shell/home_shell.dart       NavigationBar (موبایل) / NavigationRail (دسکتاپ)
├── test/                           ۴ فایل تست (واحدی + ویجت)
├── tools/pack-evb.ps1              بسته‌بندی exe تک‌فایل ویندوز
├── android/                        پیکربندی اندروید
└── windows/                        پیکربندی ویندوز
```

### نکات فنی

- **پایگاه‌داده:** حذف فرد یا دارو با `ON DELETE CASCADE` سوابق مرتبط را پاک می‌کند؛ کلید یکتای نوبت `(medication_id, log_date, log_time)` با `ConflictAlgorithm.replace` است تا تأیید مجدد، وضعیت قبلی را جایگزین کند.
- **تاریخ:** ذخیره به‌صورت میلادی `yyyy-MM-dd` و تبدیل به شمسی فقط هنگام نمایش — محاسبات بازهٔ گزارش‌ها ساده و بدون ابهام می‌ماند.
- **نیمه‌شب:** نوبت‌هایی که از بیست‌چهار رد می‌شوند در ساخت نوبت‌های روز لحاظ شده‌اند.
- **PDF:** جدول برعکسِ چیده می‌شود (تاریخ در سمت راست) و هر صفحه ۲۲ ردیف دارد.
- **رسپانسیو:** `MediaQuery.withClampedTextScaling` با محدودهٔ ۰٫۸–۱٫۸ و شکستنی از Compact (زیر ۶۰۰) تا Extended (بالای ۱۱۰۰).

---

## لایسنس فونت

فونت **ایران‌یکان (IRANYekan)** از پکیج npm `@alibaba-aero/iranyekan` گرفته شده و تحت لایسینس **MIT** منتشر شده است.
وزن‌های ۱۰۰ تا ۹۰۰ در `assets/fonts/` قرار دارند و در `pubspec.yaml` ثبت شده‌اند.
پیش از انتشار عمومی نسخهٔ باینری، متن لایسنس MIT فونت را در کنار اعلان‌های برنامه بگنجانید.

</div>
