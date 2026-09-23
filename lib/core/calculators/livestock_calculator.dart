import 'zakat_calculation_result.dart';

class LivestockCalculator {
  static ZakatCalculationResult calculateCamels(
    int count, {
    double? sheepPrice,
    double? bintLaboonPrice,
    double? hiqqahPrice,
    String currency = 'ر.ي',
  }) {
    if (count < 5) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'لم يكتمل النصاب الشرعي للإبل (نصابها 5 من الإبل السائمة)',
      );
    }

    String resultText;
    double cashAmount = 0.0;

    if (count <= 9) {
      resultText = 'شاة واحدة (جذع من الضأن أو ثني من المعز)';
      if (sheepPrice != null && sheepPrice > 0) cashAmount = sheepPrice * 1;
    } else if (count <= 14) {
      resultText = 'شاتان';
      if (sheepPrice != null && sheepPrice > 0) cashAmount = sheepPrice * 2;
    } else if (count <= 19) {
      resultText = 'ثلاث شياه';
      if (sheepPrice != null && sheepPrice > 0) cashAmount = sheepPrice * 3;
    } else if (count <= 24) {
      resultText = 'أربع شياه';
      if (sheepPrice != null && sheepPrice > 0) cashAmount = sheepPrice * 4;
    } else if (count <= 35) {
      resultText = 'بنت مخاض (أنثى أتمت سنة)';
      if (bintLaboonPrice != null && bintLaboonPrice > 0) cashAmount = bintLaboonPrice * 0.8;
    } else if (count <= 45) {
      resultText = 'بنت لبون (أنثى أتمت سنتين)';
      if (bintLaboonPrice != null && bintLaboonPrice > 0) cashAmount = bintLaboonPrice * 1;
    } else if (count <= 60) {
      resultText = 'حِقّة (أنثى أتمت ثلاث سنين)';
      if (hiqqahPrice != null && hiqqahPrice > 0) cashAmount = hiqqahPrice * 1;
    } else if (count <= 75) {
      resultText = 'جَذَعة (أنثى أتمت أربع سنين)';
      if (hiqqahPrice != null && hiqqahPrice > 0) cashAmount = hiqqahPrice * 1.25;
    } else if (count <= 90) {
      resultText = 'بنتا لبون (اثنتان كل منهما أتمت سنتين)';
      if (bintLaboonPrice != null && bintLaboonPrice > 0) cashAmount = bintLaboonPrice * 2;
    } else if (count <= 120) {
      resultText = 'حِقّتان (اثنتان كل منهما أتمت ثلاث سنين)';
      if (hiqqahPrice != null && hiqqahPrice > 0) cashAmount = hiqqahPrice * 2;
    } else {
      final target = count - (count % 10);
      final waqas = count - target;
      final combinations = <({int hiqqah, int bintLaboon})>[];

      for (int hiqqah = 0; hiqqah <= target ~/ 50; hiqqah++) {
        final remaining = target - (hiqqah * 50);
        if (remaining % 40 == 0) {
          final bintLaboon = remaining ~/ 40;
          combinations.add((hiqqah: hiqqah, bintLaboon: bintLaboon));
        }
      }

      if (combinations.isEmpty) {
        return ZakatCalculationResult(
          reachedNisab: true,
          zakatAmount: 0,
          zakatInKindDescription: 'يحتاج إلى مراجعة فقهية',
          explanation: 'العدد ($count من الإبل) يحتاج إلى مراجعة فقهية خاصة لتحديد الفريضة في الوقص.',
        );
      }

      final formattedList = combinations.map((c) {
        final parts = <String>[];
        if (c.hiqqah > 0) {
          if (c.hiqqah == 1) {
            parts.add('حِقّة واحدة (عن 50)');
          } else if (c.hiqqah == 2) {
            parts.add('حِقّتان (عن 100)');
          } else {
            parts.add('${c.hiqqah} حِقاق (عن ${c.hiqqah * 50})');
          }
        }
        if (c.bintLaboon > 0) {
          if (c.bintLaboon == 1) {
            parts.add('بنت لبون واحدة (عن 40)');
          } else if (c.bintLaboon == 2) {
            parts.add('بنتا لبون (عن 80)');
          } else {
            parts.add('${c.bintLaboon} بنات لبون (عن ${c.bintLaboon * 40})');
          }
        }
        return parts.join(' مع ');
      }).toList();

      resultText = formattedList.join('، أو ');
      if (waqas > 0) {
        resultText += ' (والزائد $waqas من الإبل وقص عفو شرعي لا زكاة فيه)';
      }

      if (combinations.isNotEmpty && hiqqahPrice != null && bintLaboonPrice != null) {
        final first = combinations.first;
        cashAmount = (first.hiqqah * hiqqahPrice) + (first.bintLaboon * bintLaboonPrice);
      }
    }

    final String cashNote = cashAmount > 0
        ? ' (أو قيمتها نقداً وفق مذهب الهادوية والزيدية: «ويجزي إخراج القيمة»: ${cashAmount.toStringAsFixed(2)} $currency)'
        : '';

    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: cashAmount,
      zakatInKindDescription: '$resultText$cashNote',
      explanation: 'اكتمل النصاب الشرعي للإبل. المقدار الواجب إخراجه عيناً: $resultText.$cashNote\nملاحظة فقهية: الأصل الإخراج عيناً، ويجزي إخراج القيمة نقداً بمذهب الهادوية رعاية لمصلحة المستحقين.',
    );
  }

  static ZakatCalculationResult calculateCows(
    int count, {
    double? tabeePrice,
    double? musinnaPrice,
    String currency = 'ر.ي',
  }) {
    if (count < 30) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'لم يكتمل النصاب الشرعي للبقر (نصابها 30 بقرة سائمة)',
      );
    }

    String resultText;
    double cashAmount = 0.0;

    if (count <= 39) {
      resultText = 'تبيع أو تبيعة (أتم سنة)';
      if (tabeePrice != null && tabeePrice > 0) cashAmount = tabeePrice * 1;
    } else if (count <= 59) {
      resultText = 'مُسنّة (أتمت سنتين)';
      if (musinnaPrice != null && musinnaPrice > 0) cashAmount = musinnaPrice * 1;
    } else if (count <= 69) {
      resultText = 'تبيعان';
      if (tabeePrice != null && tabeePrice > 0) cashAmount = tabeePrice * 2;
    } else if (count <= 79) {
      resultText = 'مسنّة وتبيع';
      if (tabeePrice != null && musinnaPrice != null) cashAmount = musinnaPrice + tabeePrice;
    } else if (count <= 89) {
      resultText = 'مسنّتان';
      if (musinnaPrice != null && musinnaPrice > 0) cashAmount = musinnaPrice * 2;
    } else if (count <= 99) {
      resultText = 'ثلاثة أتبعة';
      if (tabeePrice != null && tabeePrice > 0) cashAmount = tabeePrice * 3;
    } else if (count <= 119) {
      resultText = 'مسنّة مع تبيعين';
      if (tabeePrice != null && musinnaPrice != null) cashAmount = musinnaPrice + (tabeePrice * 2);
    } else {
      final target = count - (count % 10);
      final waqas = count - target;
      final combinations = <({int tabee, int musinna})>[];

      for (int musinna = 0; musinna <= target ~/ 40; musinna++) {
        final remaining = target - (musinna * 40);
        if (remaining % 30 == 0) {
          final tabee = remaining ~/ 30;
          combinations.add((tabee: tabee, musinna: musinna));
        }
      }

      if (combinations.isEmpty) {
        return ZakatCalculationResult(
          reachedNisab: true,
          zakatAmount: 0,
          zakatInKindDescription: 'يحتاج إلى مراجعة فقهية',
          explanation: 'العدد ($count من البقر) يحتاج إلى مراجعة فقهية خاصة لتحديد الفرض في الوقص.',
        );
      }

      final formattedList = combinations.map((c) {
        final parts = <String>[];
        if (c.musinna > 0) {
          if (c.musinna == 1) {
            parts.add('مسنّة واحدة (عن 40)');
          } else if (c.musinna == 2) {
            parts.add('مسنّتان (عن 80)');
          } else {
            parts.add('${c.musinna} مسنّات (عن ${c.musinna * 40})');
          }
        }
        if (c.tabee > 0) {
          if (c.tabee == 1) {
            parts.add('تبيع واحد (عن 30)');
          } else if (c.tabee == 2) {
            parts.add('تبيعان (عن 60)');
          } else {
            parts.add('${c.tabee} أتبعة (عن ${c.tabee * 30})');
          }
        }
        return parts.join(' مع ');
      }).toList();

      resultText = formattedList.join('، أو ');
      if (waqas > 0) {
        resultText += ' (والزائد $waqas من البقر وقص عفو شرعي لا زكاة فيه)';
      }

      if (combinations.isNotEmpty && tabeePrice != null && musinnaPrice != null) {
        final first = combinations.first;
        cashAmount = (first.tabee * tabeePrice) + (first.musinna * musinnaPrice);
      }
    }

    final String cashNote = cashAmount > 0
        ? ' (أو قيمتها نقداً وفق مذهب الهادوية والزيدية: «ويجزي إخراج القيمة»: ${cashAmount.toStringAsFixed(2)} $currency)'
        : '';

    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: cashAmount,
      zakatInKindDescription: '$resultText$cashNote',
      explanation: 'اكتمل النصاب الشرعي للبقر. المقدار الواجب إخراجه عيناً: $resultText.$cashNote\nملاحظة فقهية: الأصل الإخراج عيناً، وتجزي القيمة نقداً بمذهب الهادوية والزيدية.',
    );
  }

  static ZakatCalculationResult calculateSheep(
    int count, {
    double? sheepPrice,
    String currency = 'ر.ي',
  }) {
    if (count < 40) {
      return ZakatCalculationResult(
        reachedNisab: false,
        zakatAmount: 0,
        explanation: 'لم يكتمل النصاب الشرعي للغنم (نصابها 40 شاة سائمة)',
      );
    }

    String resultText;
    int sheepCount = 0;

    if (count <= 120) {
      resultText = 'شاة واحدة (أتمت سنة أو ثني من المعز)';
      sheepCount = 1;
    } else if (count <= 200) {
      resultText = 'شاتان';
      sheepCount = 2;
    } else if (count <= 399) {
      resultText = 'ثلاث شياه';
      sheepCount = 3;
    } else if (count <= 499) {
      resultText = 'أربع شياه';
      sheepCount = 4;
    } else if (count <= 599) {
      resultText = 'خمس شياه';
      sheepCount = 5;
    } else {
      final hundreds = count ~/ 100;
      resultText = '$hundreds شياه (لكل مئة شاة شاة واحدة)';
      sheepCount = hundreds;
    }

    final double cashAmount = (sheepPrice != null && sheepPrice > 0) ? (sheepCount * sheepPrice) : 0.0;
    final String cashNote = cashAmount > 0
        ? ' (أو قيمتها نقداً وفق مذهب الهادوية والزيدية: «ويجزي إخراج القيمة»: ${cashAmount.toStringAsFixed(2)} $currency)'
        : '';

    return ZakatCalculationResult(
      reachedNisab: true,
      zakatAmount: cashAmount,
      zakatInKindDescription: '$resultText$cashNote',
      explanation: 'اكتمل النصاب الشرعي للغنم. المقدار الواجب إخراجه عيناً: $resultText.$cashNote\nملاحظة فقهية: يجزي إخراج القيمة نقداً بالريال اليمني لمصلحة الفقير بمذهب الهادوية.',
    );
  }
}
