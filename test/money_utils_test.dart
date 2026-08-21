import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_farm_app/core/utils/money_utils.dart';

void main() {
  group('MoneyUtils Tests', () {
    test('rupeesToPaise handles double and string correctly', () {
      expect(MoneyUtils.rupeesToPaise("55.50"), equals(5550));
      expect(MoneyUtils.rupeesToPaise(55.5), equals(5550));
      expect(MoneyUtils.rupeesToPaise("19.99"), equals(1999)); // float rounding protection test
      expect(MoneyUtils.rupeesToPaise("0"), equals(0));
      expect(MoneyUtils.rupeesToPaise(null), equals(0));
      expect(MoneyUtils.rupeesToPaise("invalid"), equals(0));
    });

    test('paiseToRupees converts integer paise to double rupees', () {
      expect(MoneyUtils.paiseToRupees(5550), equals(55.5));
      expect(MoneyUtils.paiseToRupees(0), equals(0.0));
    });

    test('formatPaiseToRupees formats 2 decimal places', () {
      expect(MoneyUtils.formatPaiseToRupees(5550), equals("55.50"));
      expect(MoneyUtils.formatPaiseToRupees(500), equals("5.00"));
      expect(MoneyUtils.formatPaiseToRupees(0), equals("0.00"));
    });

    test('kgToGrams converts kg to integer grams correctly', () {
      expect(MoneyUtils.kgToGrams("30.5"), equals(30500));
      expect(MoneyUtils.kgToGrams(30.5), equals(30500));
      expect(MoneyUtils.kgToGrams(null), equals(0));
    });

    test('formatGramsToKg formats kg string', () {
      expect(MoneyUtils.formatGramsToKg(30500), equals("30.5"));
      expect(MoneyUtils.formatGramsToKg(30250), equals("30.25"));
    });

    test('calculateMilkSalePaise performs integer space math', () {
      // 30.5 kg @ ₹5.50/kg = 30,500 g @ 550 paise = 16775 paise (₹167.75)
      expect(MoneyUtils.calculateMilkSalePaise(30500, 550), equals(16775));
    });
  });
}
