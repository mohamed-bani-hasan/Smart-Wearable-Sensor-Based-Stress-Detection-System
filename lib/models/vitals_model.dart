class VitalsModel {
  final double heartRate;     // نبض القلب
  final double temperature;   // حرارة الجسم
  final double gsr;           // مقياس تعرق الجلد
  final String stressLevel;   // المستوى المحسوب (Low, Medium, High)
  final DateTime timestamp;   // وقت القراءة

  VitalsModel({
    required this.heartRate,
    required this.temperature,
    required this.gsr,
    required this.stressLevel,
    required this.timestamp,
  });

  // دالة لتحويل بيانات المستشعرات من JSON
  factory VitalsModel.fromJson(Map<String, dynamic> json) {
    return VitalsModel(
      heartRate: json['heartRate']?.toDouble() ?? 0.0,
      temperature: json['temperature']?.toDouble() ?? 0.0,
      gsr: json['gsr']?.toDouble() ?? 0.0,
      stressLevel: json['stressLevel'] ?? 'Normal',
      timestamp: DateTime.now(),
    );
  }
}