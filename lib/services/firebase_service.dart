import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';
import '../main.dart'; // Import main.dart to access globalDatabaseRef

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Use the globally initialized DatabaseReference
  final DatabaseReference _db = globalDatabaseRef!;
  

  // Sign In
  Future<UserCredential?> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      debugPrint("Login error: $e");
      rethrow;
    }
  }

  // Sign Up / Register
  Future<UserCredential?> signUp(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      debugPrint("Registration error: $e");
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Save User Data to Realtime Database
  Future<void> saveUserData(UserModel user) async {
    await _db.child('users').child(user.uid).set(user.toMap());
  }

  // Save Doctor Data to Realtime Database
  Future<void> saveDoctorData(String uid, String name, String specialty) async {
    await _db.child('doctors').child(uid).set({
      'name': name,
      'specialty': specialty,
    });
    // Also save basic user role
    await _db.child('users').child(uid).update({
      'name': name,
      'role': 'doctor',
    });
  }

  // Check Role
  Future<String?> getUserRole(String uid) async {
    final userSnapshot = await _db.child('users').child(uid).get();
    if (userSnapshot.exists && userSnapshot.value is Map) {
      final data = Map<dynamic, dynamic>.from(userSnapshot.value as Map);
      final role = data['role']?.toString().trim();
      if (role != null && role.isNotEmpty) {
        return role;
      }
    }

    final doctorSnapshot = await _db.child('doctors').child(uid).get();
    if (doctorSnapshot.exists) return 'doctor';
    return null;
  }

  // Streams
  Stream<DatabaseEvent> streamPatientData(String uid) => 
      _db.child('users').child(uid).onValue;

  Stream<DatabaseEvent> streamLatestReading(String uid) {
    return _db.child('vitals').child('history').child(uid).limitToLast(1).onValue;
  }

  Stream<DatabaseEvent> streamDoctorPatients(String doctorId) {
    // Realtime Database doesn't support multiple where clauses easily.
    // Usually, we filter by doctorId and handle role in the UI or restructure data.
    return _db.child('users')
        .orderByChild('doctorId')
        .equalTo(doctorId)
        .onValue;
  }
}
