import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import '../constants/app_colors.dart';

/// Shows a custom Hijri Date Picker modal dialog
Future<DateTime?> showHijriDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  String title = 'اختر التاريخ الهجري',
}) async {
  HijriCalendar.setLocal('ar');
  final initialHijri = HijriCalendar.fromDate(initialDate ?? DateTime.now());
  final nowHijri = HijriCalendar.now();

  int selectedYear = initialHijri.hYear;
  int selectedMonth = initialHijri.hMonth;
  int selectedDay = initialHijri.hDay;

  final months = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الثاني',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  // Provide a reasonable range of Hijri years (from current - 5 to current + 1)
  final years = List.generate(7, (index) => (nowHijri.hYear - 4) + index);

  return showDialog<DateTime>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          // Compute days in current selected Hijri month/year
          final tempHijri = HijriCalendar()
            ..hYear = selectedYear
            ..hMonth = selectedMonth
            ..hDay = 1;
          final maxDays = tempHijri.getDaysInMonth(selectedYear, selectedMonth);
          if (selectedDay > maxDays) selectedDay = maxDays;

          final days = List.generate(maxDays, (i) => i + 1);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: EdgeInsets.zero,
            content: Container(
              width: 380,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isDark ? AppColors.darkSurface : Colors.white,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dialog Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, color: AppColors.goldAccent, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Selected Date Preview Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.emeraldPrimary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.emeraldPrimary.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'التاريخ الهجري المحدد:',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$selectedDay ${months[selectedMonth - 1]} $selectedYear هـ',
                                style: const TextStyle(
                                  color: AppColors.emeraldPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Pickers Row (Day, Month, Year)
                        Row(
                          children: [
                            // Day
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('اليوم', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey.shade400),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: selectedDay,
                                        isExpanded: true,
                                        items: days.map((d) {
                                          return DropdownMenuItem<int>(
                                            value: d,
                                            child: Text('$d', textAlign: TextAlign.center),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) setState(() => selectedDay = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Month
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('الشهر الهجري', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey.shade400),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: selectedMonth,
                                        isExpanded: true,
                                        items: List.generate(12, (i) {
                                          return DropdownMenuItem<int>(
                                            value: i + 1,
                                            child: Text(
                                              months[i],
                                              style: const TextStyle(fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        }),
                                        onChanged: (val) {
                                          if (val != null) setState(() => selectedMonth = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Year
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('السنة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey.shade400),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: selectedYear,
                                        isExpanded: true,
                                        items: years.map((y) {
                                          return DropdownMenuItem<int>(
                                            value: y,
                                            child: Text('$y هـ', style: const TextStyle(fontSize: 13)),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) setState(() => selectedYear = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Presets: Today, 1 Ramadan, 1 Muharram
                        Wrap(
                          spacing: 8,
                          children: [
                            ActionChip(
                              label: const Text('اليوم', style: TextStyle(fontSize: 12)),
                              avatar: const Icon(Icons.today, size: 14),
                              onPressed: () {
                                setState(() {
                                  selectedYear = nowHijri.hYear;
                                  selectedMonth = nowHijri.hMonth;
                                  selectedDay = nowHijri.hDay;
                                });
                              },
                            ),
                            ActionChip(
                              label: const Text('1 رمضان', style: TextStyle(fontSize: 12)),
                              avatar: const Icon(Icons.star_outline, size: 14),
                              onPressed: () {
                                setState(() {
                                  selectedMonth = 9;
                                  selectedDay = 1;
                                });
                              },
                            ),
                            ActionChip(
                              label: const Text('1 محرم', style: TextStyle(fontSize: 12)),
                              avatar: const Icon(Icons.flag_outlined, size: 14),
                              onPressed: () {
                                setState(() {
                                  selectedMonth = 1;
                                  selectedDay = 1;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, null),
                          child: const Text('إلغاء'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final hijriCalc = HijriCalendar()
                              ..hYear = selectedYear
                              ..hMonth = selectedMonth
                              ..hDay = selectedDay;
                            final gregorian = hijriCalc.hijriToGregorian(
                              selectedYear,
                              selectedMonth,
                              selectedDay,
                            );
                            Navigator.pop(ctx, gregorian);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emeraldPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('تأكيد واختيار', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
