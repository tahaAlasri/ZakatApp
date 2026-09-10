import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/pdf_service.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/hawl_provider.dart';
import '../calculators/money_calc_screen.dart';
import '../calculators/gold_calc_screen.dart';
import '../calculators/silver_calc_screen.dart';
import '../calculators/trade_calc_screen.dart';
import '../calculators/crops_calc_screen.dart';
import '../calculators/livestock_calc_screen.dart';
import '../calculators/minerals_screen.dart';
import '../calculators/fields_calc_screen.dart';
import '../hawl/hawl_tracker_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<AuthProvider>(context);
    final zakatProv = Provider.of<ZakatProvider>(context);
    final hawlProv = Provider.of<HawlProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categories = [
      {'title': 'زكاة المال', 'img': 'assets/images/money.png', 'screen': const MoneyCalcScreen()},
      {'title': 'زكاة الذهب', 'img': 'assets/images/gold.png', 'screen': const GoldCalcScreen()},
      {'title': 'زكاة الفضة', 'img': 'assets/images/silver.png', 'screen': const SilverCalcScreen()},
      {'title': 'عروض التجارة', 'img': 'assets/images/trade.png', 'screen': const TradeCalcScreen()},
      {'title': 'الحبوب والثمار', 'img': 'assets/images/crops.png', 'screen': const CropsCalcScreen()},
      {'title': 'زكاة الإبل', 'img': 'assets/images/camel.png', 'screen': const LivestockCalcScreen(initialTabIndex: 0)},
      {'title': 'زكاة البقر', 'img': 'assets/images/cow.png', 'screen': const LivestockCalcScreen(initialTabIndex: 1)},
      {'title': 'زكاة الغنم', 'img': 'assets/images/goat.png', 'screen': const LivestockCalcScreen(initialTabIndex: 2)},
      {'title': 'الركاز والمعادن', 'img': 'assets/images/minral.png', 'screen': const MineralsScreen()},
      {'title': 'زكاة المستغلات', 'img': 'assets/images/fields.png', 'screen': const FieldsCalcScreen()},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/MainIcon.png', width: 30, height: 30),
            const SizedBox(width: 8),
            const Text('زكــــاتــي'),
          ],
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          zakatProv.loadRecords();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Greeting & Welcome Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emeraldPrimary.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'أهلاً بك، ${authProv.user?.name ?? 'ضيفنا الكريم'}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '{وَأَقِيمُوا الصَّلَاةَ وَآتُوا الزَّكَاةَ}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.85),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.goldAccent.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.goldAccent),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 14, color: AppColors.goldLight),
                              const SizedBox(width: 6),
                              Text(
                                AppFormatters.formatDate(DateTime.now()),
                                style: const TextStyle(fontSize: 12, color: AppColors.goldLight, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Live Gold & Silver Prices Strip
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.circle, size: 10, color: AppColors.goldAccent),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ذهب 21 (جرام)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                '${AppFormatters.formatNumber(zakatProv.goldPrice, decimals: 0)} ${zakatProv.currency}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(height: 30, width: 1, color: Colors.grey.shade300),
                      Row(
                        children: [
                          const Icon(Icons.circle, size: 10, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('فضة (جرام)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                '${AppFormatters.formatNumber(zakatProv.silverPrice, decimals: 0)} ${zakatProv.currency}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(height: 30, width: 1, color: Colors.grey.shade300),
                      Row(
                        children: [
                          const Icon(Icons.balance, size: 14, color: AppColors.emeraldPrimary),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('نصاب النقد (85غ)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                '${AppFormatters.formatNumber(zakatProv.goldPrice * 85, decimals: 0)} ${zakatProv.currency}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.emeraldPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Smart Hawl Tracker Strip (Creative Idea #1)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const HawlTrackerScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: hawlProv.isHawlCompleted
                        ? Colors.amber.shade100
                        : (isDark ? AppColors.darkCard : AppColors.emeraldSubtle),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hawlProv.isHawlCompleted ? AppColors.goldDark : AppColors.emeraldPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: hawlProv.isHawlCompleted ? AppColors.goldAccent : AppColors.emeraldPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          hawlProv.isHawlCompleted ? Icons.notifications_active : Icons.hourglass_bottom,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hawlProv.startDate == null
                                  ? 'متتبع الحول الهجري الذكي'
                                  : (hawlProv.isHawlCompleted
                                      ? 'اكتمل الحول الشرعي - الزكاة واجبة!'
                                      : 'الحول جارٍ: متبقي ${hawlProv.daysRemaining} يوماً'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              hawlProv.startDate == null
                                  ? 'انقر لضبط تاريخ بلوغ النصاب والتنبيهات'
                                  : 'موعد إخراج الزكاة: ${AppFormatters.formatDate(hawlProv.expectedDueDate!)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Categories Grid Title
              const Text(
                'حاسبات الزكاة الشرعية',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Grid of 10 categories
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return Card(
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => cat['screen'] as Widget),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              cat['img'] as String,
                              width: 44,
                              height: 44,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              cat['title'] as String,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Recent Calculations History Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'سجل العمليات الأخيرة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (zakatProv.records.isNotEmpty)
                    TextButton(
                      onPressed: () => zakatProv.clearAll(),
                      child: const Text('مسح السجل', style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (zakatProv.records.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.history_toggle_off, size: 40, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            'لم تقم بأي عملية حسابية بعد، اختر حاسبة من الأعلى للبدء!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: zakatProv.records.take(5).length,
                  itemBuilder: (context, index) {
                    final rec = zakatProv.records[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: rec.reachedNisab ? AppColors.emeraldSubtle : Colors.orange.shade50,
                          child: Icon(
                            rec.reachedNisab ? Icons.check_circle : Icons.info,
                            color: rec.reachedNisab ? AppColors.emeraldPrimary : Colors.orange,
                          ),
                        ),
                        title: Text(rec.typeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(
                          rec.zakatInKindDescription.isNotEmpty
                              ? rec.zakatInKindDescription
                              : 'الواجب: ${rec.zakatAmount.toStringAsFixed(2)} ${rec.currency}',
                          style: TextStyle(
                            fontSize: 12,
                            color: rec.reachedNisab ? AppColors.emeraldPrimary : Colors.brown,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.goldDark),
                          onPressed: () async {
                            final bytes = await PdfService.generateZakatReceipt(rec);
                            await PdfService.shareOrPrintPdf(bytes, 'zakat_receipt_${rec.id}.pdf');
                          },
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
