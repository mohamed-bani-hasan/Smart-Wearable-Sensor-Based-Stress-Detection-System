import 'package:flutter_test/flutter_test.dart';
import 'package:stress_detection/services/stress_level_utils.dart';

void main() {
  test('Stress level normalization works', () {
    expect(StressLevelUtils.normalize('high'), 'High');
    expect(StressLevelUtils.normalize('moderate'), 'Medium');
    expect(StressLevelUtils.normalize('low'), 'Normal');
    expect(StressLevelUtils.normalize(85), 'High');
  });
}
