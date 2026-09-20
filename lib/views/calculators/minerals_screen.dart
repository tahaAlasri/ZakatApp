import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_input_formatters.dart';
import '../../core/widgets/category_icon_badge.dart';
import '../../core/widgets/zakat_result_card.dart';
import '../../models/favorite_item.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/favorites_provider.dart';

class MineralsScreen extends StatefulWidget {
  const MineralsScreen({super.key});

  @override
  State<MineralsScreen> createState() => _MineralsScreenState();
}

class _MineralsScreenState extends State<MineralsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _isRikaz = true; // true = الركاز (20%), false = المعادن (2.5%)
  ZakatCalculationResult? _result;
  bool _isCalculated = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(AppInputFormatters.normalizeArabicNumbers(_amountController.text.trim())) ?? 0.0;
    final zakatProv = Provider.of<ZakatProvider>(context, listen: false);

    final res = zakatProv.calculateMineralsZakat(
      totalExtractedValue: amount,
      isRikaz: _isRikaz,
    );

    setState(() {
      _result = res;
      _isCalculated = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res.reachedNisab
              ? 'تم احتساب زكاة ${_isRikaz ? "الركاز" : "المعادن"} بنجاح'
              : 'لم تبلغ قيمة المعادن المستخرجة النصاب الشرعي',
        ),
        backgroundColor: res.reachedNisab ? AppColors.emeraldPrimary : Colors.orange.shade800,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zakatProv = Provider.of<ZakatProvider>(context);
    final favProv = Provider.of<FavoritesProvider>(context);
    const favId = 'calc_minerals';
    final isFav = favProv.isFavorite(favId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الركاز والمعادن'),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.redAccent : Colors.white,
            ),
            tooltip: isFav ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
            onPressed: () {
              final isNowFav = !isFav;
              favProv.toggleFavorite(
                FavoriteItem(
                  id: favId,
                  title: 'حاسبة الركاز والمعادن',
                  subtitle: 'حساب زكاة الكنوز والمعادن المستخرجة',
                  type: 'calculator',
                  route: '/minerals_calc',
                  imagePath: 'assets/images/minral.png',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isNowFav
                        ? 'تمت إضافة "حاسبة الركاز والمعادن" إلى المفضلة'
                        : 'تمت إزالة "حاسبة الركاز والمعادن" من المفضلة',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CategoryIconBadge(
                        imagePath: 'assets/images/minral.png',
                        size: 60,
                        iconSize: 32,
                        padding: 8,
                        borderRadius: 14,
                        fallbackIcon: Icons.diamond_outlined,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'زكاة الركاز والمعادن',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'الركاز (دفين الجاهلية) يجب فيه الخمس (20%) فور استخراجه دون اشتراط حول أو نصاب، والمعادن المستخرجة من الأرض يجب فيها ربع العشر (2.5%) عند بلوغ النصاب الشرعي (85 جرام ذهب خالص عيار 24).',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Toggle Rikaz vs Minerals
              const Text(
                'نوع المستخرج من الأرض:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      title: const Text('ركاز (دفين وكنوز الجاهلية القديمة)'),
                      subtitle: const Text('الواجب الشرعي: الخمس (20%) فور استخراجه'),
                      value: true,
                      groupValue: _isRikaz,
                      activeColor: AppColors.emeraldPrimary,
                      onChanged: (val) {
                        if (val != null) setState(() => _isRikaz = val);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<bool>(
                      title: const Text('معادن مستخرجة (حديد، نحاس، نفط، كبريت)'),
                      subtitle: const Text('الواجب الشرعي: ربع العشر (2.5%) بنصاب الذهب'),
                      value: false,
                      groupValue: _isRikaz,
                      activeColor: AppColors.emeraldPrimary,
                      onChanged: (val) {
                        if (val != null) setState(() => _isRikaz = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [AppInputFormatters.decimal],
                decoration: InputDecoration(
                  labelText: _isRikaz ? 'قيمة الركاز المستخرج الإجمالية' : 'قيمة المعادن المستخرجة الصافية',
                  hintText: 'مثال: 5000000',
                  suffixText: zakatProv.currency,
                  prefixIcon: const Icon(Icons.monetization_on_outlined, color: AppColors.emeraldPrimary),
                ),
                validator: AppValidators.requiredPositiveNumber(
                  _isRikaz ? 'قيمة الركاز المستخرج' : 'قيمة المعادن المستخرجة',
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate),
                label: const Text('احسب الزكاة الواجبة', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 24),

              // Unified Result Card
              if (_isCalculated && _result != null)
                ZakatResultCard(
                  result: _result!,
                  typeName: _isRikaz ? 'زكاة الركاز (الخمس)' : 'زكاة المعادن المستخرجة',
                  categoryKey: 'minerals',
                  totalWealth: double.tryParse(AppInputFormatters.normalizeArabicNumbers(_amountController.text.trim())) ?? 0.0,
                  currency: zakatProv.currency,
                  appliedPrice: _result?.appliedPrice,
                  pdfFileName: 'zakat_minerals_receipt.pdf',
                  pdfTitle: 'إقرار وتفصيل حساب زكاة الركاز والمعادن',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
