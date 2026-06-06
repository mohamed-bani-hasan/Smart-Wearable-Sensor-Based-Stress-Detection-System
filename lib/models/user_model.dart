import 'package:firebase_database/firebase_database.dart';

class UserModel {
  final String uid;
  final String name;
  final int age;
  final String doctorId;
  final String role;

  UserModel({
    required this.uid,
    required this.name,
    required this.age,
    required this.doctorId,
    required this.role,
  });

  factory UserModel.fromSnapshot(DataSnapshot snapshot) {
    final Map<dynamic, dynamic>? data = snapshot.value as Map<dynamic, dynamic>?;
    return UserModel(
      uid: snapshot.key ?? '',
      name: data?['name'] ?? '',
      age: data?['age'] is int ? data!['age'] : int.tryParse(data?['age']?.toString() ?? '0') ?? 0,
      doctorId: data?['doctorId'] ?? data?['doctorid'] ?? '',
      role: data?['role'] ?? 'patient',
    );
  }

  factory UserModel.fromMap(String uid, Map<dynamic, dynamic> map) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      age: map['age'] is int ? map['age'] : int.tryParse(map['age']?.toString() ?? '0') ?? 0,
      doctorId: map['doctorId'] ?? map['doctorid'] ?? '',
      role: map['role'] ?? 'patient',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'doctorId': doctorId,
      'role': role,
    };
  }
}

class Reading {
  final DateTime timestamp;
  final double heartRate;
  final double gsr;
  final String stressLevel;

  Reading({
    required this.timestamp,
    required this.heartRate,
    required this.gsr,
    required this.stressLevel,
  });

  factory Reading.fromSnapshot(DataSnapshot snapshot) {
    final Map<dynamic, dynamic>? data = snapshot.value as Map<dynamic, dynamic>?;
    return Reading(
      timestamp: data?['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data!['timestamp']) 
          : DateTime.now(),
      heartRate: (data?['heartRate'] ?? data?['heartrate'] ?? 0.0).toDouble(),
      gsr: (data?['gsr'] ?? 0.0).toDouble(),
      stressLevel: data?['stressLevel'] ?? data?['stresslevel'] ?? 'Normal',
    );
  }

  factory Reading.fromMap(Map<dynamic, dynamic> map) {
    return Reading(
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] is int 
              ? DateTime.fromMillisecondsSinceEpoch(map['timestamp']) 
              : DateTime.now())
          : DateTime.now(),
      heartRate: (map['heartRate'] ?? map['heartrate'] ?? 0.0).toDouble(),
      gsr: (map['gsr'] ?? 0.0).toDouble(),
      stressLevel: map['stressLevel'] ?? map['stresslevel'] ?? 'Normal',
    );
  }
}

class Alert {
  final DateTime timestamp;
  final String stressLevel;

  Alert({
    required this.timestamp,
    required this.stressLevel,
  });

  factory Alert.fromSnapshot(DataSnapshot snapshot) {
    final Map<dynamic, dynamic>? data = snapshot.value as Map<dynamic, dynamic>?;
    return Alert(
      timestamp: data?['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data!['timestamp']) 
          : DateTime.now(),
      stressLevel: data?['stressLevel'] ?? data?['stresslevel'] ?? '',
    );
  }

  factory Alert.fromMap(Map<dynamic, dynamic> map) {
    return Alert(
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] is int 
              ? DateTime.fromMillisecondsSinceEpoch(map['timestamp']) 
              : DateTime.now())
          : DateTime.now(),
      stressLevel: map['stressLevel'] ?? map['stresslevel'] ?? '',
    );
  }
}

class DoctorModel {
  final String doctorId;
  final String name;
  final String specialty;

  DoctorModel({
    required this.doctorId,
    required this.name,
    required this.specialty,
  });

  factory DoctorModel.fromSnapshot(DataSnapshot snapshot) {
    final Map<dynamic, dynamic>? data = snapshot.value as Map<dynamic, dynamic>?;
    return DoctorModel(
      doctorId: snapshot.key ?? '',
      name: data?['name'] ?? '',
      specialty: data?['specialty'] ?? '',
    );
  }

  factory DoctorModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return DoctorModel(
      doctorId: id,
      name: map['name'] ?? '',
      specialty: map['specialty'] ?? '',
    );
  }
}

class Recommendation {
  final String stressLevel;
  final String text;

  Recommendation({
    required this.stressLevel,
    required this.text,
  });

  factory Recommendation.fromSnapshot(DataSnapshot snapshot) {
    final Map<dynamic, dynamic>? data = snapshot.value as Map<dynamic, dynamic>?;
    return Recommendation(
      stressLevel: data?['stressLevel'] ?? data?['stresslevel'] ?? '',
      text: data?['text'] ?? '',
    );
  }

  factory Recommendation.fromMap(Map<dynamic, dynamic> map) {
    return Recommendation(
      stressLevel: map['stressLevel'] ?? map['stresslevel'] ?? '',
      text: map['text'] ?? '',
    );
  }
}
