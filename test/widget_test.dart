import 'package:flutter_test/flutter_test.dart';
import 'package:final_pro/core/constants/zakat_constants.dart';

void main() {
  test('Zakat thresholds test', () {
    expect(ZakatConstants.goldNisabGrams, 85.0);
    expect(ZakatConstants.silverNisabGrams, 595.0);
    expect(ZakatConstants.standardZakatRate, 0.025);
  });
}
