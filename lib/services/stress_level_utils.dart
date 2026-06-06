class StressLevelUtils {
  static String normalize(dynamic rawLevel, {double? stressScore}) {
    if (rawLevel is String) {
      final normalized = rawLevel.trim().toLowerCase();
      switch (normalized) {
        case 'high':
          return 'High';
        case 'medium':
        case 'moderate':
          return 'Medium';
        case 'normal':
        case 'low':
          return 'Normal';
      }

      final numeric = double.tryParse(normalized);
      if (numeric != null) {
        return fromScore(numeric);
      }
    }

    if (rawLevel is num) {
      return fromScore(rawLevel.toDouble());
    }

    if (stressScore != null) {
      return fromScore(stressScore);
    }

    return 'Unknown';
  }

  static double scoreFrom(dynamic rawScore, {dynamic rawLevel}) {
    if (rawScore is num) {
      return rawScore.toDouble().clamp(0.0, 100.0);
    }

    if (rawScore is String) {
      final parsed = double.tryParse(rawScore.trim());
      if (parsed != null) {
        return parsed.clamp(0.0, 100.0);
      }
    }

    final normalizedLevel = normalize(rawLevel);
    switch (normalizedLevel) {
      case 'High':
        return 85.0;
      case 'Medium':
        return 55.0;
      case 'Normal':
        return 20.0;
      default:
        return 0.0;
    }
  }

  static bool isHigh(dynamic rawLevel, {double? stressScore}) {
    return normalize(rawLevel, stressScore: stressScore) == 'High';
  }

  static String fromScore(double score) {
    if (score >= 70) return 'High';
    if (score >= 40) return 'Medium';
    return 'Normal';
  }

}
