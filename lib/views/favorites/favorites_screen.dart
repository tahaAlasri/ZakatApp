import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/favorite_item.dart';
import '../../providers/favorites_provider.dart';
import '../calculators/money_calc_screen.dart';
import '../calculators/gold_calc_screen.dart';
import '../calculators/silver_calc_screen.dart';
import '../calculators/trade_calc_screen.dart';
import '../calculators/crops_calc_screen.dart';
import '../calculators/livestock_calc_screen.dart';
import '../calculators/minerals_screen.dart';
import '../calculators/fields_calc_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  void _navigateToItem(BuildContext context, FavoriteItem item) {
    Widget screen;
    switch (item.route) {
      case '/money_calc':
        screen = const MoneyCalcScreen();
        break;
      case '/gold_calc':
        screen = const GoldCalcScreen();
        break;
      case '/silver_calc':
        screen = const SilverCalcScreen();
        break;
      case '/trade_calc':
        screen = const TradeCalcScreen();
        break;
      case '/crops_calc':
        screen = const CropsCalcScreen();
        break;
      case '/livestock_calc':
        screen = const LivestockCalcScreen();
        break;
      case '/minerals_calc':
        screen = const MineralsScreen();
        break;
      case '/fields_calc':
        screen = const FieldsCalcScreen();
        break;
      default:
        screen = const MoneyCalcScreen();
    }

    Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المفضلة'),
      ),
      body: Consumer<FavoritesProvider>(
        builder: (context, favProv, _) {
          final items = favProv.favorites;

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        color: AppColors.emeraldSubtle,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_border,
                        size: 50,
                        color: AppColors.emeraldPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'قائمتك المفضلة فارغة',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.emeraldDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'يمكنك إضافة أي حاسبة زكاة إلى المفضلة بالنقر على أيقونة القلب في أعلى شاشة الحاسبة لسهولة الوصول إليها لاحقاً.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Dismissible(
                key: Key(item.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  favProv.removeFavorite(item.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تمت إزالة "${item.title}" من المفضلة'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 50,
                      height: 50,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldSubtle,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.asset(item.imagePath, fit: BoxFit.contain),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(
                      item.subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.redAccent),
                      onPressed: () => favProv.removeFavorite(item.id),
                    ),
                    onTap: () => _navigateToItem(context, item),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
