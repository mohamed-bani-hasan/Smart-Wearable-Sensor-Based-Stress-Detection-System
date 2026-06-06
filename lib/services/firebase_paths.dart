import 'package:firebase_database/firebase_database.dart';

class FirebasePaths {
  /// Schema template keys in Firebase (not real devices/users).
  static const Set<String> placeholderKeys = {
    'deviceId',
    'userId',
    'doctorId',
    'patientId',
    'alertId',
    'notificationId',
    'entryId',
  };

  static bool isPlaceholderKey(String key) {
    final normalized = key.trim();
    return normalized.isEmpty || placeholderKeys.contains(normalized);
  }

  static bool isValidDeviceId(String? deviceId) {
    if (deviceId == null) return false;
    return !isPlaceholderKey(deviceId);
  }

  static String? assignedDeviceId(Map<dynamic, dynamic> userData) {
    final rawDeviceId = userData['deviceId']?.toString().trim();
    if (rawDeviceId != null &&
        rawDeviceId.isNotEmpty &&
        isValidDeviceId(rawDeviceId)) {
      return rawDeviceId;
    }
    return null;
  }

  static DatabaseReference userLiveVitalsRef(
    DatabaseReference dbRef,
    String uid,
    String deviceId,
  ) {
    return dbRef.child('vitals/live/$deviceId');
  }

  static DatabaseReference userHistoryRef(
    DatabaseReference dbRef,
    String uid,
  ) {
    return dbRef.child('vitals/history/$uid');
  }

  static DatabaseReference deviceStatusRef(
    DatabaseReference dbRef,
    String deviceId,
  ) {
    return dbRef.child('device_status/$deviceId');
  }
}
