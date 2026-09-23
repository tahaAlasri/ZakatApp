import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/services/cloud_sync_service.dart';
import 'package:provider/provider.dart';

class PaymentChannel {
  final String name;
  final String accountNumber;
  final String accountName;
  final String code;
  final IconData icon;
  final Color brandColor;
  final String notes;

  const PaymentChannel({
    required this.name,
    required this.accountNumber,
    required this.accountName,
    required this.code,
    required this.icon,
    required this.brandColor,
    required this.notes,
  });
}

class ZakatPaymentScreen extends StatefulWidget {
  final double? suggestedAmount;
  final String? zakatType;

  const ZakatPaymentScreen({
    super.key,
    this.suggestedAmount,
    this.zakatType,
  });

  @override
  State<ZakatPaymentScreen> createState() => _ZakatPaymentScreenState();
}

class _ZakatPaymentScreenState extends State<ZakatPaymentScreen> {
  String _selectedPurpose = 'الزكاة العامة (الفقراء والمساكين)';

  static const List<Map<String, dynamic>> _defaultAccounts = [
    {
      'id': 1,
      'bankName': 'بنك التسليف التعاوني والزراعي (CAC Bank)',
      'accountNum': '1001-234567-001',
      'currency': 'ريال يمني',
    },
    {
      'id': 2,
      'bankName': 'بنك الكريمي للتمويل الأصغر الإسلامي',
      'accountNum': '300-8877665',
      'currency': 'ريال يمني',
    },
    {
      'id': 3,
      'bankName': 'الهيئة العامة للبريد والتوفير البريدي',
      'accountNum': 'الحساب الموحد: 1111',
      'currency': 'ريال يمني',
    },
    {
      'id': 4,
      'bankName': 'محفظة جيب / كاش الإلكترونية',
      'accountNum': '777000111',
      'currency': 'ريال يمني',
    },
    {
      'id': 5,
      'bankName': 'محفظة ون كاش (OneCash)',
      'accountNum': '777000222',
      'currency': 'ريال يمني',
    },
    {
      'id': 6,
      'bankName': 'محفظة فلوسك (بنك اليمن والكويت)',
      'accountNum': '50050011',
      'currency': 'ريال يمني',
    },
    {
      'id': 7,
      'bankName': 'بنك التضامن الإسلامي',
      'accountNum': '21008899',
      'currency': 'ريال يمني',
    },
    {
      'id': 8,
      'bankName': 'محفظة جوالي (Jawwali)',
      'accountNum': '770001122',
      'currency': 'ريال يمني',
    },
  ];

  static PaymentChannel _mapAccountToChannel(Map<String, dynamic> acc) {
    final bankName = acc['bankName']?.toString() ?? 'حساب بنكي معتمد';
    final accountNum = acc['accountNum']?.toString() ?? '';
    final currency = acc['currency']?.toString() ?? 'ريال يمني';
    final id = acc['id']?.toString() ?? accountNum;

    IconData icon = Icons.account_balance;
    Color brandColor = AppColors.emeraldPrimary;
    String notes = 'حساب رسمي معتمد بالهيئة العامة للزكاة ($currency).';

    final lower = bankName.toLowerCase();
    if (lower.contains('cac') || lower.contains('تسليف') || lower.contains('كاك')) {
      icon = Icons.account_balance;
      brandColor = const Color(0xFF006633);
      notes = 'متاح السداد المباشر عبر تطبيق سداد كاك بنك وفروع البنك في عموم المحافظات ($currency).';
    } else if (lower.contains('كريمي') || lower.contains('kuraimi')) {
      icon = Icons.payments_outlined;
      brandColor = const Color(0xFF0D47A1);
      notes = 'عبر تطبيق كريمي جوال (سداد فواتير وجهات حكومية > الهيئة العامة للزكاة) أو نقاط أم فلوس ($currency).';
    } else if (lower.contains('بريد') || lower.contains('barid') || lower.contains('توفير')) {
      icon = Icons.markunread_mailbox_outlined;
      brandColor = const Color(0xFFE65100);
      notes = 'عبر مكاتب الهيئة العامة للبريد والتوفير البريدي في كافة المحافظات ($currency).';
    } else if (lower.contains('ون كاش') || lower.contains('onecash') || lower.contains('one cash')) {
      icon = Icons.phone_android;
      brandColor = const Color(0xFFEF6C00);
      notes = 'عبر تطبيق ون كاش المباشر من قائمة المدفوعات والخدمات الحكومية ($currency).';
    } else if (lower.contains('جيب') || lower.contains('jeeb') || lower.contains('كاش')) {
      icon = Icons.smartphone_outlined;
      brandColor = const Color(0xFF00897B);
      notes = 'متاح السداد والتحويل الفوري عبر محفظة جيب الإلكترونية ($currency).';
    } else if (lower.contains('فلوسك') || lower.contains('floosak') || lower.contains('يمن والكويت')) {
      icon = Icons.wallet_outlined;
      brandColor = const Color(0xFF4A148C);
      notes = 'متاح السداد المباشر عبر محفظة فلوسك برقم الحساب الموحد ($currency).';
    } else if (lower.contains('تضامن') || lower.contains('tadhamon')) {
      icon = Icons.account_balance_outlined;
      brandColor = const Color(0xFF004D40);
      notes = 'متاح التحويل عبر تطبيق تضامن باي وجميع فروع البنك ($currency).';
    } else if (lower.contains('جوالي') || lower.contains('jawwali')) {
      icon = Icons.contactless_outlined;
      brandColor = const Color(0xFFB71C1C);
      notes = 'سداد فوري عبر تطبيق جوالي التابع لمصرف البحرين الشامل ($currency).';
    }

    return PaymentChannel(
      name: bankName,
      accountNumber: accountNum,
      accountName: 'الهيئة العامة للزكاة - الحساب المعتمد رسمياً',
      code: 'acc_$id',
      icon: icon,
      brandColor: brandColor,
      notes: notes,
    );
  }

  static const List<String> _purposes = [
    'الزكاة العامة (الفقراء والمساكين)',
    'مصرف الغارمين (تفريج كرب المعسرين)',
    'مصرف ابن السبيل والمحتاجين',
    'زكاة الفطرة للفقراء',
    'الرعاية الصحية والمشاريع الإنتاجية',
  ];

  void _copyAccountNumber(String number, String bankName) {
    Clipboard.setData(ClipboardData(text: number));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ رقم حساب $bankName ($number) إلى الحافظة!'),
        backgroundColor: AppColors.emeraldDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cloudSync = Provider.of<CloudSyncService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('قنوات سداد وتوجيه الزكاة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: isDark ? AppColors.cardDarkGradient : AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.goldAccent.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.verified, color: AppColors.goldAccent, size: 26),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الحسابات الرسمية المعتمدة',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'الهيئة العامة للزكاة - الجمهورية اليمنية',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.suggestedAmount != null && widget.suggestedAmount! > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.goldAccent.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.zakatType != null ? 'المقدار المحسوب (${widget.zakatType}):' : 'المقدار الواجب إخراجه:',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppFormatters.formatCurrency(widget.suggestedAmount!),
                                style: const TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: widget.suggestedAmount!.toStringAsFixed(0)));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم نسخ المبلغ إلى الحافظة!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.goldAccent,
                              foregroundColor: AppColors.emeraldDark,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            icon: const Icon(Icons.copy, size: 14),
                            label: const Text('نسخ المبلغ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Purpose / Masraf Selector
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.alt_route, color: AppColors.emeraldPrimary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'توجيه الزكاة إلى مصرف معين:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedPurpose,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _purposes.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPurpose = val);
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'اختر البنك أو المحفظة الإلكترونية للسداد:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (cloudSync.bankAccounts.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.emeraldPrimary.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'محدث سحابياً',
                      style: TextStyle(fontSize: 10, color: AppColors.emeraldPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Payment Channels List (Cloud-Synced + Fallback)
            ...() {
              final rawList = cloudSync.bankAccounts.isNotEmpty
                  ? cloudSync.bankAccounts
                  : _defaultAccounts;
              final displayList = rawList.map((acc) => _mapAccountToChannel(acc)).toList();

              return displayList.map((ch) {
                return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: ch.brandColor.withValues(alpha: 0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: ch.brandColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(ch.icon, color: ch.brandColor, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ch.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ch.accountName,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Account Number Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('رقم الحساب الموحد:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                const SizedBox(height: 2),
                                SelectableText(
                                  ch.accountNumber,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: ch.brandColor,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _copyAccountNumber(ch.accountNumber, ch.name),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.emeraldPrimary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.copy, size: 14),
                              label: const Text('نسخ الرقم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      Text(
                        '💡 ${ch.notes}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),
                      ),
                    ],
                  ),
                ),
              );
            }).toList();
          }(),

            const SizedBox(height: 16),

            // Sharia Masaref Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.emeraldPrimary.withValues(alpha: 0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.menu_book, color: AppColors.emeraldPrimary, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'مصارف الزكاة الشرعية الثمانية',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'قال تعالى: {إِنَّمَا الصَّدَقَاتُ لِلْفُقَرَاءِ وَالْمَسَاكِينِ وَالْعَامِلِينَ عَلَيْهَا وَالْمُؤَلَّفَةِ قُلُوبُهُمْ وَفِي الرِّقَابِ وَالْغَارِمِينَ وَفِي سَبِيلِ اللَّهِ وَابْنِ السَّبِيلِ ۖ فَرِيضَةً مِّنَ اللَّهِ ۗ وَاللَّهُ عَلِيمٌ حَكِيمٌ} [التوبة: 60]',
                      style: TextStyle(fontSize: 12, height: 1.6, color: Colors.brown),
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'تتولى الهيئة العامة للزكاة صرف الإيرادات وفق هذه المصارف الشرعية عبر مشاريع الرعاية الاجتماعية والتمكين الاقتصادي وسداد ديون الغارمين.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
