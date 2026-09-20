import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/zakat_categories.dart';
import '../../core/widgets/category_icon_badge.dart';

class CalculatorsGridScreen extends StatefulWidget {
  const CalculatorsGridScreen({super.key});

  @override
  State<CalculatorsGridScreen> createState() => _CalculatorsGridScreenState();
}

class _CalculatorsGridScreenState extends State<CalculatorsGridScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedGroup = 'all';

  final List<Map<String, String>> _filterGroups = [
    {'id': 'all', 'label': 'جميع الحاسبات'},
    {'id': 'money', 'label': 'النقود والذهب'},
    {'id': 'livestock', 'label': 'الأنعام والمواشي'},
    {'id': 'crops', 'label': 'الحبوب والزروع'},
    {'id': 'activities', 'label': 'الفطر والتجارة'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredItems = appZakatCategories.where((item) {
      final matchesQuery = _searchQuery.isEmpty ||
          item.title.contains(_searchQuery) ||
          item.description.contains(_searchQuery) ||
          item.shortTitle.contains(_searchQuery);

      final matchesGroup = _selectedGroup == 'all' || item.group == _selectedGroup;

      return matchesQuery && matchesGroup;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('حاسبات الزكاة الشاملة'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن نوع الزكاة أو النصاب...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.emeraldPrimary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
                const SizedBox(height: 10),
                // Horizontal Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filterGroups.map((group) {
                      final isSelected = _selectedGroup == group['id'];
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(group['label']!),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedGroup = group['id']!);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // 2-Column Responsive Grid View
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'لم يتم العثور على حاسبة تطابق "$_searchQuery"',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'جرّب البحث بكلمة أخرى مثل "ذهب"، "فطر"، "غنم"، "زروع"',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 650 ? 3 : 2;
                      final aspectRatio = constraints.maxWidth > 650 ? 1.15 : 0.98;

                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: aspectRatio,
                        ),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isDark
                                    ? AppColors.emeraldPrimary.withValues(alpha: 0.25)
                                    : AppColors.emeraldPrimary.withValues(alpha: 0.12),
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => item.targetScreen),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Icon and Nisab Badge
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CategoryIconBadge(
                                          imagePath: item.imagePath,
                                          size: 46,
                                          iconSize: 26,
                                          padding: 6,
                                          borderRadius: 12,
                                        ),
                                        if (item.nisabBadge.isNotEmpty)
                                          Flexible(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? AppColors.emeraldPrimary.withValues(alpha: 0.22)
                                                    : AppColors.emeraldSubtle,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: AppColors.emeraldPrimary.withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Text(
                                                item.nisabBadge,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? AppColors.goldLight : AppColors.emeraldPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const Spacer(),
                                    // Title
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        item.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Description
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        item.description,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                          height: 1.3,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
