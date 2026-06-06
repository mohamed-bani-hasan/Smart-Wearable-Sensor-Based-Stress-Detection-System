import 'package:firebase_database/firebase_database.dart';

class PatientModel {
  final String uid;
  final String name;
  final int age;
  final String doctorId;
  final String role;

  PatientModel({
    required this.uid,
    required this.name,
    required this.age,
    required this.doctorId,
    this.role = 'patient',
  });

  factory PatientModel.fromSnapshot(DataSnapshot snapshot) {
    final Map<dynamic, dynamic>? data = snapshot.value as Map<dynamic, dynamic>?;
    return PatientModel(
      uid: snapshot.key ?? '',
      name: data?['name'] ?? '',
      age: data?['age'] is int ? data!['age'] : int.tryParse(data?['age']?.toString() ?? '0') ?? 0,
      doctorId: data?['doctorId'] ?? data?['doctorid'] ?? '',
      role: data?['role'] ?? 'patient',
    );
  }

  factory PatientModel.fromMap(String uid, Map<dynamic, dynamic> map) {
    return PatientModel(
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
