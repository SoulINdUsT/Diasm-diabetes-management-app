
// lib/core/lifestyle_models.dart

/// Root snapshot object for the Lifestyle screen.
class LifestyleSnapshot {
  final bool ok;
  final int userId;

  final ActivitySummary activity;
  final HydrationSummary hydration;

  final List<dynamic> fasting; // keep as dynamic list for now
  final dynamic mealplan;      // null or object

  LifestyleSnapshot({
    required this.ok,
    required this.userId,
    required this.activity,
    required this.hydration,
    required this.fasting,
    required this.mealplan,
  });

  factory LifestyleSnapshot.fromJson(Map<String, dynamic> json) {
    return LifestyleSnapshot(
      ok: json['ok'] == true,
      userId: int.tryParse(json['user_id'].toString()) ?? 0,
      activity:
          ActivitySummary.fromJson(json['activity'] as Map<String, dynamic>?),
      hydration: HydrationSummary.fromJson(
        json['hydration'] as Map<String, dynamic>?,
      ),
      fasting: (json['fasting'] as List?) ?? const [],
      mealplan: json['mealplan'],
    );
  }

  @override
  String toString() =>
      'LifestyleSnapshot(ok:$ok,userId:$userId,activity:$activity,hydration:$hydration)';
}

/// Activity summary: today & weekly are LISTS in your JSON.
class ActivitySummary {
  final List<dynamic> today;
  final List<dynamic> weekly;

  ActivitySummary({
    required this.today,
    required this.weekly,
  });

  factory ActivitySummary.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return ActivitySummary(
      today: (j['today'] as List?) ?? const [],
      weekly: (j['weekly'] as List?) ?? const [],
    );
  }

  @override
  String toString() => 'ActivitySummary(today:$today,weekly:$weekly)';
}

/// Aggregated hydration info for "Hydration Today" card.
class HydrationSummary {
  final double totalMl;
  final double? goalMl;
  final double? pctOfGoal;

  HydrationSummary({
    required this.totalMl,
    required this.goalMl,
    required this.pctOfGoal,
  });

  factory HydrationSummary.fromJson(Map<String, dynamic>? json) {
    // If backend sends null or {}, treat as "no data yet".
    if (json == null || json.isEmpty) {
      return HydrationSummary(
        totalMl: 0.0,
        goalMl: null,
        pctOfGoal: null,
      );
    }

    final j = json;

    final totalRaw = j['total_ml'];
    final goalRaw = j['goal_ml'];
    final pctRaw = j['pct_of_goal'];

    return HydrationSummary(
      totalMl:
          totalRaw == null ? 0.0 : double.tryParse(totalRaw.toString()) ?? 0.0,
      goalMl: goalRaw == null ? null : double.tryParse(goalRaw.toString()),
      pctOfGoal: pctRaw == null ? null : double.tryParse(pctRaw.toString()),
    );
  }

  @override
  String toString() =>
      'HydrationSummary(totalMl:$totalMl,goalMl:$goalMl,pct:$pctOfGoal)';
}

/// ------------------------------
/// FASTING MODELS
/// ------------------------------

/// Active fasting session (if any).
class FastingActiveSession {
  final int id;
  final int userId;
  final DateTime startAt;

  /// 'intermittent', 'religious', 'medical', 'custom'
  final String fastKind;

  /// e.g. '16-8', 'Ramadan', 'OMAD'
  final String protocol;

  /// Target hours for this fast (e.g. 16.0)
  final double targetHours;

  final String? notes;

  FastingActiveSession({
    required this.id,
    required this.userId,
    required this.startAt,
    required this.fastKind,
    required this.protocol,
    required this.targetHours,
    this.notes,
  });

  factory FastingActiveSession.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final userRaw = json['user_id'];
    final targetRaw = json['target_hours'];
    final startRaw = json['start_at'];

    return FastingActiveSession(
      id: int.tryParse(idRaw?.toString() ?? '') ?? 0,
      userId: int.tryParse(userRaw?.toString() ?? '') ?? 0,
      startAt: DateTime.tryParse(startRaw?.toString() ?? '') ??
          DateTime.now(), // fallback
      fastKind: (json['fast_kind'] ?? '').toString(),
      protocol: (json['protocol'] ?? '').toString(),
      targetHours: double.tryParse(targetRaw?.toString() ?? '') ?? 0.0,
      notes: json['notes']?.toString(),
    );
  }

  @override
  String toString() =>
      'FastingActiveSession(id:$id,userId:$userId,kind:$fastKind,protocol:$protocol,targetHours:$targetHours,startAt:$startAt)';
}

/// A single fasting session in history.
class FastingHistoryItem {
  final int id;
  final int userId;

  final DateTime startAt;
  final DateTime? endAt;

  /// Total hours fasted (as computed by backend).
  final double hours;

  final String fastKind;
  final String protocol;
  final double targetHours;

  final String? brokeReason;
  final String? notes;

  FastingHistoryItem({
    required this.id,
    required this.userId,
    required this.startAt,
    required this.endAt,
    required this.hours,
    required this.fastKind,
    required this.protocol,
    required this.targetHours,
    this.brokeReason,
    this.notes,
  });

  factory FastingHistoryItem.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final userRaw = json['user_id'];
    final hoursRaw = json['hours'];
    final targetRaw = json['target_hours'];

    final startRaw = json['start_at'];
    final endRaw = json['end_at'];

    return FastingHistoryItem(
      id: int.tryParse(idRaw?.toString() ?? '') ?? 0,
      userId: int.tryParse(userRaw?.toString() ?? '') ?? 0,
      startAt: DateTime.tryParse(startRaw?.toString() ?? '') ??
          DateTime.now(), // fallback
      endAt: endRaw == null ? null : DateTime.tryParse(endRaw.toString()),
      hours: double.tryParse(hoursRaw?.toString() ?? '') ?? 0.0,
      fastKind: (json['fast_kind'] ?? '').toString(),
      protocol: (json['protocol'] ?? '').toString(),
      targetHours: double.tryParse(targetRaw?.toString() ?? '') ?? 0.0,
      brokeReason: json['broke_reason']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  @override
  String toString() =>
      'FastingHistoryItem(id:$id,userId:$userId,hours:$hours,kind:$fastKind,protocol:$protocol,startAt:$startAt,endAt:$endAt)';
}

/// Daily rollup summary returned by /lifestyle/fasting/summary
class FastingSummaryDay {
  final int userId;
  final DateTime day;

  final int fastsStarted;
  final int totalMinutes;

  final int count12hPlus;
  final int count16hPlus;

  FastingSummaryDay({
    required this.userId,
    required this.day,
    required this.fastsStarted,
    required this.totalMinutes,
    required this.count12hPlus,
    required this.count16hPlus,
  });

  factory FastingSummaryDay.fromJson(Map<String, dynamic> json) {
    final userRaw = json['user_id'];
    final dayRaw = json['day'];
    final fastsRaw = json['fasts_started'];
    final totalMinRaw = json['total_minutes'];
    final c12Raw = json['count_12h_plus'];
    final c16Raw = json['count_16h_plus'];

    return FastingSummaryDay(
      userId: int.tryParse(userRaw?.toString() ?? '') ?? 0,
      day: DateTime.tryParse(dayRaw?.toString() ?? '') ??
          DateTime.now(), // fallback
      fastsStarted: int.tryParse(fastsRaw?.toString() ?? '') ?? 0,
      totalMinutes: int.tryParse(totalMinRaw?.toString() ?? '') ?? 0,
      count12hPlus: int.tryParse(c12Raw?.toString() ?? '') ?? 0,
      count16hPlus: int.tryParse(c16Raw?.toString() ?? '') ?? 0,
    );
  }

  @override
  String toString() =>
      'FastingSummaryDay(userId:$userId,day:$day,fasts:$fastsStarted,mins:$totalMinutes,12h:$count12hPlus,16h:$count16hPlus)';
}

/// ------------------------------
/// MEAL PLAN MODELS
/// ------------------------------

/// Represents a daily meal plan template (BIRDEM, etc.).
/// Used both for list endpoints (/lifestyle/mealplans)
/// and detail endpoint (/lifestyle/mealplans/:id).
class MealPlan {
  final int id;
  final String title;
  final double calories;

  /// Backend sends 0/1; we expose as bool.
  final bool isTemplate;

  final String? forDiabetesType;
  final String? sourceRef;
  final DateTime? createdAt;

  /// items_by_meal: { breakfast: [...], lunch: [...], ... }
  final Map<String, List<MealItem>> itemsByMeal;

  /// Aggregated nutrition totals for the whole plan.
  final MealTotals? totals;

  MealPlan({
    required this.id,
    required this.title,
    required this.calories,
    required this.isTemplate,
    this.forDiabetesType,
    this.sourceRef,
    this.createdAt,
    Map<String, List<MealItem>>? itemsByMeal,
    this.totals,
  }) : itemsByMeal = itemsByMeal ?? const {};

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final titleRaw = json['title'];
    final caloriesRaw = json['calories'];
    final isTemplateRaw = json['is_template'];
    final typeRaw = json['for_diabetes_type'];
    final srcRaw = json['source_ref'];
    final createdRaw = json['created_at'];

    // Parse items_by_meal if present
    final Map<String, List<MealItem>> itemsByMeal = {};
    final ibm = json['items_by_meal'];
    if (ibm is Map<String, dynamic>) {
      ibm.forEach((key, value) {
        if (value is List) {
          final list = value
              .whereType<Map<String, dynamic>>()
              .map((j) => MealItem.fromJson(j))
              .toList();
          if (list.isNotEmpty) {
            itemsByMeal[key] = list;
          }
        }
      });
    }

    final totalsJson = json['totals'];
    final totals =
        (totalsJson is Map<String, dynamic>) ? MealTotals.fromJson(totalsJson) : null;

    return MealPlan(
      id: int.tryParse(idRaw?.toString() ?? '') ?? 0,
      title: titleRaw?.toString() ?? '',
      calories: caloriesRaw == null
          ? 0.0
          : double.tryParse(caloriesRaw.toString()) ?? 0.0,
      isTemplate: isTemplateRaw == 1 || isTemplateRaw == true,
      forDiabetesType: typeRaw?.toString(),
      sourceRef: srcRaw?.toString(),
      createdAt:
          createdRaw == null ? null : DateTime.tryParse(createdRaw.toString()),
      itemsByMeal: itemsByMeal,
      totals: totals,
    );
  }

  @override
  String toString() =>
      'MealPlan(id:$id,title:$title,cal:$calories,isTemplate:$isTemplate)';
}

/// A single food item inside a meal (breakfast, lunch, etc.).
class MealItem {
  final int id;
  final String mealTime;

  final int? foodId;
  final String? foodNameEn;
  final String? foodNameBn;

  final int? portionId;
  final String? portionLabelEn;
  final String? portionLabelBn;

  final double? grams;

  final String? customLabel;
  final String? notes;

  final double? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;

  MealItem({
    required this.id,
    required this.mealTime,
    this.foodId,
    this.foodNameEn,
    this.foodNameBn,
    this.portionId,
    this.portionLabelEn,
    this.portionLabelBn,
    this.grams,
    this.customLabel,
    this.notes,
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
  });

  factory MealItem.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final mealTimeRaw = json['meal_time'];

    double? toDouble(dynamic v) {
      if (v == null) return null;
      return double.tryParse(v.toString());
    }

    int? toInt(dynamic v) {
      if (v == null) return null;
      return int.tryParse(v.toString());
    }

    return MealItem(
      id: int.tryParse(idRaw?.toString() ?? '') ?? 0,
      mealTime: mealTimeRaw?.toString() ?? '',
      foodId: toInt(json['food_id']),
      foodNameEn: json['food_name_en']?.toString(),
      foodNameBn: json['food_name_bn']?.toString(),
      portionId: toInt(json['portion_id']),
      portionLabelEn: json['portion_label_en']?.toString(),
      portionLabelBn: json['portion_label_bn']?.toString(),
      grams: toDouble(json['grams']),
      customLabel: json['custom_label']?.toString(),
      notes: json['notes']?.toString(),
      calories: toDouble(json['calories']),
      proteinG: toDouble(json['protein_g']),
      carbsG: toDouble(json['carbs_g']),
      fatG: toDouble(json['fat_g']),
    );
  }

  @override
  String toString() =>
      'MealItem(id:$id,meal:$mealTime,foodEn:$foodNameEn,grams:$grams,cal:$calories)';
}

/// Aggregated macronutrients for a meal plan.
class MealTotals {
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  MealTotals({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  factory MealTotals.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) {
      if (v == null) return 0.0;
      return double.tryParse(v.toString()) ?? 0.0;
    }

    return MealTotals(
      calories: toDouble(json['calories']),
      proteinG: toDouble(json['protein_g']),
      carbsG: toDouble(json['carbs_g']),
      fatG: toDouble(json['fat_g']),
    );
  }

  @override
  String toString() =>
      'MealTotals(cal:$calories,P:$proteinG,C:$carbsG,F:$fatG)';
}

/// Represents a user-specific assignment of a meal plan.
class MealPlanAssignment {
  final int id; // assignment id
  final DateTime? startDate;
  final bool active;

  final int mealPlanId;
  final String title;
  final double calories;
  final String? forDiabetesType;

  MealPlanAssignment({
    required this.id,
    required this.startDate,
    required this.active,
    required this.mealPlanId,
    required this.title,
    required this.calories,
    this.forDiabetesType,
  });

  factory MealPlanAssignment.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final sdRaw = json['start_date'];
    final activeRaw = json['active'];
    final planIdRaw = json['meal_plan_id'];
    final titleRaw = json['title'];
    final calRaw = json['calories'];
    final typeRaw = json['for_diabetes_type'];

    return MealPlanAssignment(
      id: int.tryParse(idRaw?.toString() ?? '') ?? 0,
      startDate: sdRaw == null ? null : DateTime.tryParse(sdRaw.toString()),
      active: activeRaw == 1 || activeRaw == true,
      mealPlanId: int.tryParse(planIdRaw?.toString() ?? '') ?? 0,
      title: titleRaw?.toString() ?? '',
      calories:
          calRaw == null ? 0.0 : double.tryParse(calRaw.toString()) ?? 0.0,
      forDiabetesType: typeRaw?.toString(),
    );
  }

  @override
  String toString() =>
      'MealPlanAssignment(id:$id,planId:$mealPlanId,title:$title,active:$active)';
}

/// NEW: Recommendation payload from /lifestyle/mealplans/recommend
class MealPlanRecommendation {
  final double targetCalories;
  final MealPlan recommended;
  final List<MealPlan> alternatives;

  MealPlanRecommendation({
    required this.targetCalories,
    required this.recommended,
    required this.alternatives,
  });

  factory MealPlanRecommendation.fromJson(Map<String, dynamic> json) {
    final tcRaw = json['target_calories'];
    final targetCalories =
        tcRaw == null ? 0.0 : double.tryParse(tcRaw.toString()) ?? 0.0;

    final recJson = json['recommended_plan'] ?? json['recommended'];
    if (recJson is! Map<String, dynamic>) {
      throw ArgumentError('recommended_plan must be an object');
    }

    final altJson = json['alternatives'];
    final alternatives = (altJson is List)
        ? altJson
            .whereType<Map<String, dynamic>>()
            .map((j) => MealPlan.fromJson(j))
            .toList()
        : <MealPlan>[];

    return MealPlanRecommendation(
      targetCalories: targetCalories,
      recommended: MealPlan.fromJson(recJson),
      alternatives: alternatives,
    );
  }
}

/// ------------------------------
/// FOOD MODELS
/// ------------------------------

class Food {
  final int id;

  /// Localized display name (English or Bangla depending on lang).
  final String name;

  /// Optional English / Bangla names.
  final String? nameEn;
  final String? nameBn;

  /// Category (e.g. Leafy vegetables, Fruits, etc.)
  final String? category;

  /// Per-100 g values from FCTB:
  /// kcal_per_100g, carb_g, protein_g, fat_g, fiber_g, sodium_mg
  final double? kcalPer100g;
  final double? carbPer100g;
  final double? proteinPer100g;
  final double? fatPer100g;
  final double? fiberPer100g;
  final double? sodiumMgPer100g;

  /// We keep these for future use in list view (right now they are null).
  final String? primaryPortionName;
  final double? primaryPortionGrams;
  final double? primaryPortionKcal;

  Food({
    required this.id,
    required this.name,
    this.nameEn,
    this.nameBn,
    this.category,
    this.kcalPer100g,
    this.carbPer100g,
    this.proteinPer100g,
    this.fatPer100g,
    this.fiberPer100g,
    this.sodiumMgPer100g,
    this.primaryPortionName,
    this.primaryPortionGrams,
    this.primaryPortionKcal,
  });

  factory Food.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return Food(id: 0, name: '');
    }

    double? toDouble(dynamic v) {
      if (v == null) return null;
      return double.tryParse(v.toString());
    }

    // Backend example:
    // {id, code, name_en, name_bn, category, kcal_per_100g, carb_g, protein_g, fat_g, fiber_g, sodium_mg, ...}
    final idRaw = json['id'];
    final nameEnRaw = json['name_en'];
    final nameBnRaw = json['name_bn'];
    final nameRaw = json['name'] ?? nameEnRaw ?? nameBnRaw;

    final categoryRaw = json['category'];

    final kcal100Raw = json['kcal_per_100g'];
    final carbRaw = json['carb_g'];
    final proteinRaw = json['protein_g'];
    final fatRaw = json['fat_g'];
    final fiberRaw = json['fiber_g'];
    final sodiumRaw = json['sodium_mg'];

    return Food(
      id: int.tryParse(idRaw?.toString() ?? '') ?? 0,
      name: nameRaw?.toString() ?? '',
      nameEn: nameEnRaw?.toString(),
      nameBn: nameBnRaw?.toString(),
      category: categoryRaw?.toString(),
      kcalPer100g: toDouble(kcal100Raw),
      carbPer100g: toDouble(carbRaw),
      proteinPer100g: toDouble(proteinRaw),
      fatPer100g: toDouble(fatRaw),
      fiberPer100g: toDouble(fiberRaw),
      sodiumMgPer100g: toDouble(sodiumRaw),
      // list / detail API do not send a single "primary" portion,
      // so we leave these null for now.
      primaryPortionName: null,
      primaryPortionGrams: null,
      primaryPortionKcal: null,
    );
  }

  @override
  String toString() {
    return 'Food(id:$id,name:$name,category:$category,'
        'kcal100:$kcalPer100g,carb100:$carbPer100g,protein100:$proteinPer100g,'
        'fat100:$fatPer100g,fiber100:$fiberPer100g,Na100:$sodiumMgPer100g)';
  }
}

class FoodPortion {
  final int id;
  final int foodId;

  /// Portion description, e.g. "1 cup raw" / "1 cup cooked"
  final String name;

  /// Weight in grams for this portion.
  final double grams;

  /// kcal for this portion.
  final double kcal;

  FoodPortion({
    required this.id,
    required this.foodId,
    required this.name,
    required this.grams,
    required this.kcal,
  });

  factory FoodPortion.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return FoodPortion(
        id: 0,
        foodId: 0,
        name: '',
        grams: 0,
        kcal: 0,
      );
    }

    // Detail endpoint example:
    // "portions":[
    //   {"id":200,"food_id":142,"label_en":"1 cup raw","label_bn":"১ কাপ কাঁচা","label":"1 cup raw",
    //    "grams":"90.00","kcal":"79.2", ...},
    //   {...}
    // ]
    final idRaw = json['id'] ?? json['portion_id'];
    final foodIdRaw = json['food_id'];

    final nameRaw = json['label'] ??
        json['label_en'] ??
        json['label_bn'] ??
        json['name'] ??
        json['portion_name'];

    final gramsRaw = json['grams'] ??
        json['g'] ??
        json['weight_g'] ??
        json['weight'] ??
        json['amount_g'];

    final kcalRaw =
        json['kcal'] ?? json['calories'] ?? json['energy_kcal'] ?? json['energy'];

    double toDouble(dynamic v) {
      if (v == null) return 0.0;
      return double.tryParse(v.toString()) ?? 0.0;
    }

    return FoodPortion(
      id: int.tryParse(idRaw?.toString() ?? '') ?? 0,
      foodId: int.tryParse(foodIdRaw?.toString() ?? '') ?? 0,
      name: nameRaw?.toString() ?? '',
      grams: toDouble(gramsRaw),
      kcal: toDouble(kcalRaw),
    );
  }

  @override
  String toString() =>
      'FoodPortion(id:$id,foodId:$foodId,name:$name,grams:$grams,kcal:$kcal)';
}
