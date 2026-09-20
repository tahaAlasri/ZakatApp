import 'package:flutter/services.dart';

/// Custom input formatters and validation rules for the Zakat App.
/// Ensures strict prevention of text in numeric fields and digits in text/name fields,
/// while seamlessly normalizing Arabic-Indic numerals (٠١٢٣٤٥٦٧٨٩) to standard digits.
class AppInputFormatters {
  /// Converts Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩) and Arabic decimal comma (، / ٫) to standard ASCII
  static String normalizeArabicNumbers(String input) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    var result = input;
    for (int i = 0; i < arabicDigits.length; i++) {
      result = result.replaceAll(arabicDigits[i], englishDigits[i]);
    }
    // Replace Arabic decimal separators with standard dot
    result = result.replaceAll('٫', '.').replaceAll('،', '.');
    return result;
  }

  /// Safely parses a double from input string after normalizing Arabic numerals
  static double? tryParseDouble(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final normalized = normalizeArabicNumbers(input.trim());
    return double.tryParse(normalized);
  }

  /// Safely parses an int from input string after normalizing Arabic numerals
  static int? tryParseInt(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final normalized = normalizeArabicNumbers(input.trim());
    return int.tryParse(normalized);
  }

  /// Formatter for decimal numbers:
  /// - Automatically converts Arabic numerals
  /// - Strictly rejects any letters, words, or special symbols
  /// - Allows only digits and at most one decimal point
  static final TextInputFormatter decimal = TextInputFormatter.withFunction((oldValue, newValue) {
    final normalized = normalizeArabicNumbers(newValue.text);

    // Allow empty text so user can backspace to clear
    if (normalized.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // RegEx pattern: zero or more digits, optionally followed by a single decimal point and digits
    final regExp = RegExp(r'^\d*\.?\d*$');
    if (regExp.hasMatch(normalized)) {
      return newValue.copyWith(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }

    // If new value has letters or multiple dots, reject it and keep old value
    return oldValue;
  });

  /// Formatter for whole integer numbers:
  /// - Converts Arabic digits to standard ASCII
  /// - Strictly rejects any text, letters, decimal points, and symbols
  static final TextInputFormatter digitsOnly = TextInputFormatter.withFunction((oldValue, newValue) {
    final normalized = normalizeArabicNumbers(newValue.text);

    if (normalized.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final regExp = RegExp(r'^\d+$');
    if (regExp.hasMatch(normalized)) {
      return newValue.copyWith(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }

    return oldValue;
  });

  /// Formatter for text and names:
  /// - Strictly ALLOWS only Arabic letters, English letters, and spaces
  /// - Strictly REJECTS all digits (0-9 and ٠-٩) and arithmetic symbols
  static final TextInputFormatter lettersOnly = FilteringTextInputFormatter.allow(
    RegExp(r'[\u0600-\u06FFa-zA-Z\s]'),
  );
}

/// Standardized validation rules with clear Arabic error messages
class AppValidators {
  // --- FormFieldValidator Factories (for: `validator: AppValidators.requiredPositiveNumber('المبلغ')`) ---

  static String? Function(String?) requiredPositiveNumber([String fieldName = 'القيمة']) =>
      (val) => validatePositiveNumber(val, fieldName: fieldName);

  static String? Function(String?) nonNegativeNumber([String fieldName = 'القيمة']) =>
      (val) => validateNonNegativeNumber(val, fieldName: fieldName);

  static String? Function(String?) requiredPositiveInteger([String fieldName = 'العدد']) =>
      (val) => validatePositiveInteger(val, fieldName: fieldName);

  static String? Function(String?) personName([String fieldName = 'الاسم']) =>
      (val) => validatePersonName(val, fieldName: fieldName);

  static String? Function(String?) phoneNumber([String fieldName = 'رقم الهاتف']) =>
      (val) => validatePhoneNumber(val, fieldName: fieldName);

  static String? Function(String?) idNumber([String fieldName = 'رقم البطاقة']) =>
      (val) => validateIdNumber(val, fieldName: fieldName);

  static String? Function(String?) textNotPureNumbers(String fieldName) =>
      (val) => validateTextNotPureNumbers(val, fieldName: fieldName);

  // --- Direct Validation Functions ---

  /// Validates required decimal amount (e.g. monetary wealth, gold grams, market price)
  static String? validatePositiveNumber(String? value, {String fieldName = 'القيمة'}) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال $fieldName';
    }
    final normalized = AppInputFormatters.normalizeArabicNumbers(value.trim());
    final number = double.tryParse(normalized);
    if (number == null) {
      return 'يرجى إدخال أرقام صحيحة فقط بدون حروف';
    }
    if (number <= 0) {
      return 'يجب أن تكون $fieldName أكبر من الصفر';
    }
    return null;
  }

  /// Validates non-negative decimal amount (allows 0 for optional deductions/liabilities)
  static String? validateNonNegativeNumber(String? value, {String fieldName = 'القيمة'}) {
    if (value == null || value.trim().isEmpty) {
      return null; // optional or defaults to 0
    }
    final normalized = AppInputFormatters.normalizeArabicNumbers(value.trim());
    final number = double.tryParse(normalized);
    if (number == null) {
      return 'يرجى إدخال أرقام صحيحة فقط بدون حروف';
    }
    if (number < 0) {
      return 'لا يمكن أن تكون $fieldName بالسالب';
    }
    return null;
  }

  /// Validates required positive integer count (e.g. camels, cows, sheep, family members)
  static String? validatePositiveInteger(String? value, {String fieldName = 'العدد'}) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال $fieldName';
    }
    final normalized = AppInputFormatters.normalizeArabicNumbers(value.trim());
    final number = int.tryParse(normalized);
    if (number == null) {
      return 'أرقام صحيحة فقط بدون كسور';
    }
    if (number <= 0) {
      return 'يجب أن يكون $fieldName أكبر من الصفر (1 على الأقل)';
    }
    return null;
  }

  /// Validates personal name fields:
  /// - Cannot be empty
  /// - Must have at least 2 characters
  /// - Cannot contain any digits or numbers
  static String? validatePersonName(String? value, {String fieldName = 'الاسم'}) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال $fieldName';
    }
    final trimmed = value.trim();
    if (RegExp(r'[\d\u0660-\u0669]').hasMatch(trimmed)) {
      return '$fieldName يجب أن يحتوي على حروف فقط ولا يمكن أن يحتوي على أرقام';
    }
    if (trimmed.length < 2) {
      return '$fieldName قصير جداً (حرفين على الأقل)';
    }
    return null;
  }

  /// Validates phone number (digits only, length 7-15)
  static String? validatePhoneNumber(String? value, {String fieldName = 'رقم الهاتف / الجوال'}) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال $fieldName';
    }
    final normalized = AppInputFormatters.normalizeArabicNumbers(value.trim());
    if (!RegExp(r'^\d+$').hasMatch(normalized)) {
      return '$fieldName يجب أن يحتوي على أرقام فقط بدون أحرف';
    }
    if (normalized.length < 7 || normalized.length > 15) {
      return '$fieldName يجب أن يتكون من بين 7 و 15 رقماً';
    }
    return null;
  }

  /// Validates national ID or identity card number
  static String? validateIdNumber(String? value, {String fieldName = 'رقم البطاقة الشخصية / الهوية'}) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال $fieldName';
    }
    final normalized = AppInputFormatters.normalizeArabicNumbers(value.trim());
    if (!RegExp(r'^\d+$').hasMatch(normalized)) {
      return '$fieldName يجب أن يتكون من أرقام فقط بدون أحرف';
    }
    if (normalized.length < 6 || normalized.length > 20) {
      return '$fieldName غير صحيح (بين 6 و 20 رقماً)';
    }
    return null;
  }

  /// Validates meaningful text field: must not be purely digits
  static String? validateTextNotPureNumbers(String? value, {required String fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال $fieldName';
    }
    final trimmed = value.trim();
    final normalized = AppInputFormatters.normalizeArabicNumbers(trimmed);
    if (RegExp(r'^\d+$').hasMatch(normalized)) {
      return '$fieldName يجب أن يكون نصاً واضحاً ولا يمكن أن يكون أرقاماً فقط';
    }
    return null;
  }
}
