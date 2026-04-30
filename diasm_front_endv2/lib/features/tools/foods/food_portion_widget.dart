// lib/features/tools/lifestyle/foods/food_portion_widget.dart

import 'package:flutter/material.dart';
import 'package:diasm_front_endv2/core/lifestyle_models.dart';

class FoodPortionWidget extends StatelessWidget {
  final FoodPortion portion;

  const FoodPortionWidget({
    super.key,
    required this.portion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(width: 0.3),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              portion.name,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              portion.grams.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              portion.kcal.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
