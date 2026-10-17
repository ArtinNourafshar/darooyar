import 'package:darooyar/core/utils/persian_utils.dart';

/// نتیجهٔ محاسبهٔ BMI.
class BmiResult {
  const BmiResult({required this.value, required this.category});

  final double value;
  final BmiCategory category;
}

/// دسته‌بندی‌های BMI بر اساس معیار WHO.
enum BmiCategory {
  underweight('کمبود وزن', 'وزن کمتر از حد طبیعی است؛ تغذیهٔ کافی مهم است.'),
  normal('نرمال', 'وزن شما در محدودهٔ سالم است؛ همین را حفظ کنید.'),
  overweight('اضافه وزن', 'کمی بالاتر از محدودهٔ سالم؛ فعالیت بدنی کمک می‌کند.'),
  obese('چاقی', 'بالاتر از محدودهٔ سالم؛ مشورت با پزشک توصیه می‌شود.');

  const BmiCategory(this.label, this.advice);

  final String label;
  final String advice;
}

/// محاسبهٔ شاخص تودهٔ بدنی (BMI) و دسته‌بندی آن — منطق خالص و قابل تست.
abstract final class BmiCalculator {
  /// BMI = وزن(kg) / قد(m)²
  ///
  /// قد یا وزن نامعتبر → null.
  static double? calculate({required double weightKg, required double heightCm}) {
    if (weightKg <= 0 || heightCm <= 0) return null;
    final meters = heightCm / 100;
    final bmi = weightKg / (meters * meters);
    if (bmi.isNaN || bmi.isInfinite) return null;
    return double.parse(bmi.toStringAsFixed(1));
  }

  /// دسته‌بندی بر اساس BMI (مرد/زن یکسان — معیار عمومی WHO).
  static BmiCategory categoryOf(double bmi) {
    if (bmi < 18.5) return BmiCategory.underweight;
    if (bmi < 25) return BmiCategory.normal;
    if (bmi < 30) return BmiCategory.overweight;
    return BmiCategory.obese;
  }

  static BmiResult? calculateWithCategory({
    required double weightKg,
    required double heightCm,
  }) {
    final bmi = calculate(weightKg: weightKg, heightCm: heightCm);
    if (bmi == null) return null;
    return BmiResult(value: bmi, category: categoryOf(bmi));
  }

  /// قالب فارسی «۲۳٫۴» (نقطهٔ اعشار فارسی).
  static String format(double bmi) => PersianUtils.toPersianDigits(
        bmi.toStringAsFixed(1),
      ).replaceAll('.', '٫');
}
