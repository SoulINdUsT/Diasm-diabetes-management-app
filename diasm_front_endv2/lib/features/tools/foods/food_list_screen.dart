// lib/features/tools/foods/food_list_screen.dart

import 'package:flutter/material.dart';

import 'package:diasm_front_endv2/core/lifestyle_models.dart';
import 'package:diasm_front_endv2/core/food_repository.dart';

import 'food_detail_screen.dart';

/// English → Bangla labels for food categories
const Map<String, String> _categoryBnLabels = {
  'Beverages': 'পানীয়',
  'Cereals and products': 'শস্যদানা ও পণ্য',
  'Cereals and their products': 'শস্যদানা ও তাদের পণ্য',
  'Eggs and their products': 'ডিম ও ডিমজাত খাবার',
  'Fat and oils': 'চর্বি ও তেল',
  'Fish, shellfish and their products': 'মাছ ও সামুদ্রিক খাবার',
  'Fruits': 'ফলমূল',
  'Leafy vegetables': 'পাতাওয়ালা শাকসবজি',
  'Meat, poultry and their products': 'মাংস ও হাঁস-মুরগীজাত খাবার',
  'Milk and its product': 'দুধ ও দুধের পণ্য',
  'Milk and products': 'দুধ ও দুগ্ধজাত খাবার',
  'Miscellaneous': 'বিবিধ',
  'Nuts, seeds and their products': 'বাদাম, বীজ ও পণ্য',
  'Protein / Animal': 'প্রোটিন / প্রাণীজাত',
  'Protein / Plant': 'প্রোটিন / উদ্ভিজ্জ',
};

class FoodListScreen extends StatefulWidget {
  static const routeName = '/tools/foods';

  final bool isEnglish;

  const FoodListScreen({
    super.key,
    required this.isEnglish,
  });

  @override
  State<FoodListScreen> createState() => _FoodListScreenState();
}

class _FoodListScreenState extends State<FoodListScreen> {
  final _repo = FoodRepository();
  final TextEditingController _searchController = TextEditingController();

  /// We keep our own language state so user can toggle EN/BN
  late bool _isEnglish;

  List<Food> _foods = const [];
  List<String> _categories = const []; // distinct category list
  String _selectedCategory = ''; // '' = all

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isEnglish = widget.isEnglish;
    _loadFoods();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFoods() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final lang = _isEnglish ? 'en' : 'bn';
      final query = _searchController.text.trim();

      final results = await _repo.searchFoods(
        q: query.isEmpty ? null : query,
        limit: 500, // enough for all rows
        offset: 0,
        lang: lang,
      );

      // Build category list from results
      final categorySet = <String>{};
      for (final f in results) {
        final c = f.category?.trim();
        if (c != null && c.isNotEmpty) {
          categorySet.add(c);
        }
      }
      final cats = categorySet.toList()..sort();

      if (!mounted) return;

      setState(() {
        _foods = results;
        _categories = cats;

        // If current selection no longer exists, reset to "All"
        if (_selectedCategory.isNotEmpty &&
            !_categories.contains(_selectedCategory)) {
          _selectedCategory = '';
        }

        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _isEnglish
            ? 'Failed to load foods.'
            : 'খাদ্য তালিকা লোড করা যায়নি।';
      });
    }
  }

  void _onSearchPressed() {
    _loadFoods();
  }

  void _toggleLanguage(bool toEnglish) {
    if (_isEnglish == toEnglish) return;
    setState(() {
      _isEnglish = toEnglish;
    });
    _loadFoods();
  }

  /// Apply category filter on top of the raw list
  List<Food> get _visibleFoods {
    if (_selectedCategory.isEmpty) return _foods;
    return _foods
        .where((f) => (f.category ?? '').trim() == _selectedCategory)
        .toList();
  }

  /// Show category as "English / Bangla" or "Bangla / English"
  String _displayCategory(String? raw, bool isEn) {
    if (raw == null || raw.trim().isEmpty) return '';
    final cat = raw.trim();
    final bn = _categoryBnLabels[cat];

    if (bn == null) return cat; // fallback if no mapping

    return isEn ? '$cat / $bn' : '$bn / $cat';
  }

  @override
  Widget build(BuildContext context) {
    final isEn = _isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Foods' : 'খাদ্য তালিকা'),
        actions: [
          _buildLangToggle(),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(isEn),
          _buildCategoryFilter(isEn),
          _buildHeaderRow(isEn),
          const Divider(height: 0),
          Expanded(
            child: _buildListBody(isEn),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------
  // Top controls
  // ---------------------------------------------------

  Widget _buildLangToggle() {
    final cs = Theme.of(context).colorScheme;

    TextStyle style(bool active) => TextStyle(
          fontSize: 12,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          color: active ? cs.onPrimary : cs.onSurface,
        );

    BoxDecoration box(bool active) => BoxDecoration(
          color: active ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.primary),
        );

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _toggleLanguage(true),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: box(_isEnglish),
              child: Text('EN', style: style(_isEnglish)),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => _toggleLanguage(false),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: box(!_isEnglish),
              child: Text('BN', style: style(!_isEnglish)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isEn) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _onSearchPressed(),
        decoration: InputDecoration(
          labelText: isEn
              ? 'Search food (English / বাংলা)'
              : 'খাদ্য খুঁজুন (ইংরেজি / বাংলা)',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.search),
            onPressed: _onSearchPressed,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(bool isEn) {
    if (_categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedCategory.isEmpty ? '' : _selectedCategory,
        isExpanded: true,
        decoration: InputDecoration(
          labelText:
              isEn ? 'Filter by category' : 'ক্যাটাগরি অনুযায়ী দেখুন',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: [
          DropdownMenuItem(
            value: '',
            child: Text(
              isEn ? 'All categories' : 'সব ক্যাটাগরি',
            ),
          ),
          ..._categories.map(
            (c) => DropdownMenuItem(
              value: c,
              child: Text(_displayCategory(c, isEn)),
            ),
          ),
        ],
        onChanged: (value) {
          setState(() {
            _selectedCategory = value ?? '';
          });
        },
      ),
    );
  }

  // ---------------------------------------------------
  // Table header + list
  // ---------------------------------------------------

  Widget _buildHeaderRow(bool isEn) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.7),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              isEn ? 'Food' : 'খাদ্য',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              isEn ? 'Category' : 'ক্যাটাগরি',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'kcal / 100 g',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListBody(bool isEn) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!));
    }

    final foods = _visibleFoods;

    if (foods.isEmpty) {
      return Center(
        child: Text(
          isEn ? 'No foods found.' : 'কোনো খাদ্য পাওয়া যায়নি।',
        ),
      );
    }

    return ListView.separated(
      itemCount: foods.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (context, index) {
        final food = foods[index];

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FoodDetailScreen(
                  foodId: food.id,
                  isEnglish: _isEnglish,
                  initialFood: food,
                ),
              ),
            );
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    food.name,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    _displayCategory(food.category, isEn),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    food.kcalPer100g == null
                        ? ''
                        : food.kcalPer100g!.toStringAsFixed(0),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
