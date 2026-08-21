import 'package:intl/intl.dart';

/// Centralized utility class for monetary (Paise <-> Rupees) and quantity (Grams <-> Kilograms) conversions.
///
/// SYSTEM STORAGE CONTRACT:
///   - Money is stored as INTEGER paise in SQLite / models (e.g. ₹55.50 = 5550 paise).
///   - Milk quantity is stored as INTEGER grams in SQLite / models (e.g. 30.5 kg = 30500 grams).
///   - All string-to-integer parsing uses [.round()] to prevent floating-point truncation bugs (e.g., 19.99 * 100).
abstract final class MoneyUtils {
  static final NumberFormat _rupeeFormatter = NumberFormat('0.00', 'en_US');
  static final NumberFormat _kgFormatter = NumberFormat('0.0#', 'en_US');

  /// Converts a Rupee representation (String, double, or int) to INTEGER paise.
  /// Uses [.round()] to safely handle floating-point imprecision.
  ///
  /// Examples:
  ///   rupeesToPaise("55.50")  -> 5550
  ///   rupeesToPaise(55.5)     -> 5550
  ///   rupeesToPaise("19.99")  -> 1999 (prevents 1998 truncation bug)
  ///   rupeesToPaise(null)     -> 0
  static int rupeesToPaise(dynamic rupeesInput) {
    if (rupeesInput == null) return 0;
    if (rupeesInput is int) return rupeesInput * 100;
    
    double? val;
    if (rupeesInput is double) {
      val = rupeesInput;
    } else if (rupeesInput is String) {
      val = double.tryParse(rupeesInput.trim());
    }
    
    if (val == null || val.isNaN || val.isInfinite) return 0;
    return (val * 100).round();
  }

  /// Converts INTEGER paise to double Rupees.
  ///
  /// Examples:
  ///   paiseToRupees(5550) -> 55.5
  static double paiseToRupees(int paise) {
    return paise / 100.0;
  }

  /// Formats INTEGER paise as a 2-decimal place Rupee string.
  ///
  /// Examples:
  ///   formatPaiseToRupees(5550) -> "55.50"
  ///   formatPaiseToRupees(0)    -> "0.00"
  static String formatPaiseToRupees(int paise) {
    return _rupeeFormatter.format(paise / 100.0);
  }

  /// Converts a Kilograms representation (String, double, or int) to INTEGER grams.
  ///
  /// Examples:
  ///   kgToGrams("30.5") -> 30500
  ///   kgToGrams(30.5)   -> 30500
  static int kgToGrams(dynamic kgInput) {
    if (kgInput == null) return 0;
    if (kgInput is int) return kgInput * 1000;

    double? val;
    if (kgInput is double) {
      val = kgInput;
    } else if (kgInput is String) {
      val = double.tryParse(kgInput.trim());
    }

    if (val == null || val.isNaN || val.isInfinite) return 0;
    return (val * 1000).round();
  }

  /// Converts INTEGER grams to double Kilograms.
  ///
  /// Examples:
  ///   gramsToKg(30500) -> 30.5
  static double gramsToKg(int grams) {
    return grams / 1000.0;
  }

  /// Formats INTEGER grams as a Kilograms string (1-2 decimal places).
  ///
  /// Examples:
  ///   formatGramsToKg(30500) -> "30.5"
  ///   formatGramsToKg(30250) -> "30.25"
  static String formatGramsToKg(int grams) {
    return _kgFormatter.format(grams / 1000.0);
  }

  /// Calculates the total sale amount in INTEGER paise from quantity in grams and rate in paise.
  ///
  /// Math contract: (quantityGrams * ratePaise) / 1000, rounded to nearest integer paise.
  ///
  /// Examples:
  ///   calculateMilkSalePaise(30500, 550) -> 16775 (₹167.75)
  static int calculateMilkSalePaise(int quantityGrams, int ratePaise) {
    return ((quantityGrams * ratePaise) / 1000).round();
  }
}
