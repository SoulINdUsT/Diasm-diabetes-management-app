
// lib/features/tools/lifestyle/foods/food_detail_screen.dart

import 'package:flutter/material.dart';

import 'package:diasm_front_endv2/core/lifestyle_models.dart';
import 'package:diasm_front_endv2/core/food_repository.dart';
import 'package:diasm_front_endv2/features/tools/foods/food_portion_widget.dart';


class FoodDetailScreen extends StatefulWidget {
  static const routeName = '/tools/lifestyle/foods/detail';

  final int foodId;
  final bool isEnglish;

  /// Optional already-loaded food from list, to show instantly.
  final Food? initialFood;

  const FoodDetailScreen({
    super.key,
    required this.foodId,
    required this.isEnglish,
    this.initialFood,
  });

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  final _repo = FoodRepository();

  Food? _food;
  List<FoodPortion> _portions = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _food = widget.initialFood;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final lang = widget.isEnglish ? 'en' : 'bn';

      // Using repository in a way that matches backend:
      // getFood(int id, String lang)
      final fetchedFood =
          await _repo.getFood(widget.foodId, lang) ?? _food;

      final portions = await _repo.getPortions(widget.foodId);

      if (!mounted) return;

      setState(() {
        _food = fetchedFood;
        _portions = portions;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.isEnglish
            ? 'Failed to load food details.'
            : 'খাদ্যের তথ্য লোড করা যায়নি।';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = widget.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _food?.name.isNotEmpty == true
              ? _food!.name
              : (isEn ? 'Food details' : 'খাদ্য বিবরণ'),
        ),
      ),
      body: _buildBody(isEn),
    );
  }

  Widget _buildBody(bool isEn) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(_error!),
      );
    }

    final food = _food;
    if (food == null) {
      return Center(
        child: Text(
          isEn ? 'No data.' : 'কোনো তথ্য পাওয়া যায়নি।',
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFoodInfoCard(isEn, food),
          const SizedBox(height: 24),
          _buildPortionTable(isEn),
        ],
      ),
    );
  }

    Widget _buildFoodInfoCard(bool isEn, Food food) {
    final theme = Theme.of(context);

    String fmt(double? v, {int decimals = 1}) {
      if (v == null) return '-';
      return v.toStringAsFixed(decimals);
    }

    final hasMacros = food.carbPer100g != null ||
        food.proteinPer100g != null ||
        food.fatPer100g != null ||
        food.fiberPer100g != null ||
        food.sodiumMgPer100g != null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              food.name,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (food.category != null && food.category!.isNotEmpty)
              Text(
                (isEn ? 'Category: ' : 'ধরণ: ') + food.category!,
                style: theme.textTheme.bodyMedium,
              ),
            if (food.kcalPer100g != null) ...[
              const SizedBox(height: 4),
              Text(
                '${isEn ? 'Per 100 g: ' : 'প্রতি ১০০ গ্রাম: '}${food.kcalPer100g!.toStringAsFixed(0)} kcal',
                style: theme.textTheme.bodyMedium,
              ),
            ],

            // -----------------------------
            // Macros per 100 g (table style)
            // -----------------------------
            if (hasMacros) ...[
              const SizedBox(height: 12),
              Text(
                isEn ? 'Per 100 g (approx.)' : 'প্রতি ১০০ গ্রাম (আনুমানিক)',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1),
                },
                children: [
                  if (food.carbPer100g != null)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            isEn ? 'Carbs' : 'কার্বোহাইড্রেট',
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text('${fmt(food.carbPer100g)} g'),
                          ),
                        ),
                      ],
                    ),
                  if (food.proteinPer100g != null)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            isEn ? 'Protein' : 'প্রোটিন',
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text('${fmt(food.proteinPer100g)} g'),
                          ),
                        ),
                      ],
                    ),
                  if (food.fatPer100g != null)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            isEn ? 'Fat' : 'ফ্যাট',
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text('${fmt(food.fatPer100g)} g'),
                          ),
                        ),
                      ],
                    ),
                  if (food.fiberPer100g != null)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            isEn ? 'Fiber' : 'ফাইবার',
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text('${fmt(food.fiberPer100g)} g'),
                          ),
                        ),
                      ],
                    ),
                  if (food.sodiumMgPer100g != null)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            isEn ? 'Sodium' : 'সোডিয়াম',
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text('${fmt(food.sodiumMgPer100g)} mg'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPortionTable(bool isEn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEn ? 'Portion table' : 'পরিমাণ তালিকা',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),

        // Header row
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  isEn ? 'Portion' : 'পরিমাণ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  isEn ? 'Weight (g)' : 'ওজন (গ্রাম)',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'kcal',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 0),

        if (_portions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              isEn ? 'No portions found.' : 'কোনো পরিমাণের তথ্য নেই।',
            ),
          )
        else
          Column(
            children: _portions
                .map((p) => FoodPortionWidget(portion: p))
                .toList(),
          ),
      ],
    );
  }
}
