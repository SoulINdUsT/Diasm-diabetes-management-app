enum Gm700sbMealMarker {
  none,
  beforeMeal,
  afterMeal,
  sport,
  unknown,
}

class Gm700sbRecord {
  /// Two-byte wrapper/index value that precedes the
  /// actual 16-byte Full Security record.
  final int wrapperIndex;

  /// Glucose value exactly as stored by the meter.
  final int glucoseMgDl;

  /// Date/time decoded from the meter record.
  /// Seconds are currently treated as zero.
  final DateTime measuredAt;

  /// Decoded meal/activity marker.
  final Gm700sbMealMarker marker;

  /// Original marker byte from record[8].
  final int rawMarker;

  /// Original 18-byte payload:
  /// 2-byte wrapper + 16-byte Full Security record.
  final List<int> rawPayload;

  const Gm700sbRecord({
    required this.wrapperIndex,
    required this.glucoseMgDl,
    required this.measuredAt,
    required this.marker,
    required this.rawMarker,
    required this.rawPayload,
  });

  /// Convenience conversion for display only.
  ///
  /// DIAsm should ultimately store/import the original mg/dL
  /// value rather than converting mmol/L back to mg/dL.
  double get glucoseMmolL =>
      glucoseMgDl / 18.0;

  String get markerLabel {
    switch (marker) {
      case Gm700sbMealMarker.none:
        return 'None';

      case Gm700sbMealMarker.beforeMeal:
        return 'Before Meal';

      case Gm700sbMealMarker.afterMeal:
        return 'After Meal';

      case Gm700sbMealMarker.sport:
        return 'Sport';

      case Gm700sbMealMarker.unknown:
        return 'Unknown';
    }
  }

  @override
  String toString() {
    return 'Gm700sbRecord('
        'wrapperIndex: $wrapperIndex, '
        'glucoseMgDl: $glucoseMgDl, '
        'glucoseMmolL: ${glucoseMmolL.toStringAsFixed(1)}, '
        'marker: $markerLabel, '
        'rawMarker: $rawMarker, '
        'measuredAt: $measuredAt'
        ')';
  }
}
