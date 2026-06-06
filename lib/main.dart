import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'theme/app_theme.dart';
import 'services/firebase_bootstrap.dart';
import 'services/firebase_paths.dart';
import 'screens/login_screen.dart';
import 'screens/navigation_menu.dart';

export 'services/firebase_bootstrap.dart'
    show globalDatabaseRef, globalFirebaseApp, isFirebaseDatabaseReady, requireDatabaseRef;

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebaseServices();
  runApp(const StressApp());
}

class StressApp extends StatelessWidget {
  const StressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Stress Monitor',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _bootError;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _bootError = null;
      _retrying = true;
    });

    await Future<void>.delayed(const Duration(seconds: 2));

    if (!isFirebaseDatabaseReady) {
      final ok = await initializeFirebaseServices();
      if (!ok && mounted) {
        setState(() {
          _bootError =
              'Could not connect to Firebase. Check internet and try again.';
          _retrying = false;
        });
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_bootError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 56, color: Colors.white70),
                const SizedBox(height: 16),
                Text(
                  _bootError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _retrying ? null : _boot,
                  child: Text(_retrying ? 'Connecting...' : 'Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F766E),
              Color(0xFF0E7490),
              Color(0xFF155E75),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                    ),
                    child: const Icon(Icons.monitor_heart_rounded, size: 72, color: Colors.white),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Stress Monitor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Clinical stress & vitals monitoring',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> ensurePatientDeviceStatus(String customId) async {
  if (!isFirebaseDatabaseReady) return;
  final dbRef = requireDatabaseRef();
  final userSnap = await dbRef.child('users/$customId').get();
  if (!userSnap.exists || userSnap.value is! Map) return;
  final userData = Map<String, dynamic>.from(userSnap.value as Map);
  final deviceId = FirebasePaths.assignedDeviceId(userData);
  if (deviceId == null) return;

  final statusRef = FirebasePaths.deviceStatusRef(dbRef, deviceId);
  final statusSnap = await statusRef.get();

  if (statusSnap.exists) {
    var statusData = <String, dynamic>{};
    if (statusSnap.value != null && statusSnap.value is Map) {
      statusData = Map<String, dynamic>.from(statusSnap.value as Map);
    }

    final monitoringActive = statusData['monitoringActive'] == true;
    final linkedUserId = statusData['linkedUserId']?.toString().trim() ?? '';

    final updates = <String, dynamic>{};
    if (!statusData.containsKey('online')) updates['online'] = false;
    if (!statusData.containsKey('lastSeen')) updates['lastSeen'] = ServerValue.timestamp;
    if (!statusData.containsKey('wifi')) updates['wifi'] = 0;
    if (!statusData.containsKey('battery')) updates['battery'] = 0;
    if (!statusData.containsKey('monitoringActive')) updates['monitoringActive'] = false;
    if (!statusData.containsKey('linkedUserId')) updates['linkedUserId'] = '';

    if (!monitoringActive && linkedUserId == customId) {
      updates['linkedUserId'] = '';
    }

    if (updates.isNotEmpty) {
      await statusRef.update(updates);
    }

    if (!monitoringActive) {
      await dbRef.child('users/$customId').update({'deviceId': ''});
    }
  } else {
    await statusRef.set({
      'deviceId': deviceId,
      'online': false,
      'lastSeen': ServerValue.timestamp,
      'wifi': 0,
      'battery': 0,
      'monitoringActive': false,
      'linkedUserId': '',
    });
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          String? customId = snapshot.data!.displayName;
          if (customId == null || customId.isEmpty) {
            return const LoginScreen();
          }

          if (!isFirebaseDatabaseReady) {
            return _FirebaseNotReadyScreen(
              onRetry: () async {
                await initializeFirebaseServices();
              },
            );
          }

          final dbRef = requireDatabaseRef();
          return FutureBuilder<DataSnapshot>(
            future: dbRef.child('users/$customId').get(),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (userSnap.hasError) {
                return Scaffold(
                  body: Center(
                    child: Text(
                      'Database access error: ${userSnap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }
              
              if (userSnap.hasData && userSnap.data!.exists) {
                var userData = Map<String, dynamic>.from(userSnap.data!.value as Map);
                final role = userData['role']?.toString().trim().toLowerCase() ?? 'patient';

                if (role == 'doctor') {
                  return FutureBuilder<DataSnapshot>(
                    future: dbRef.child('doctors/$customId').get(),
                    builder: (context, doctorSnap) {
                      if (doctorSnap.connectionState == ConnectionState.waiting) {
                        return const Scaffold(body: Center(child: CircularProgressIndicator()));
                      }
                      if (doctorSnap.hasError) {
                        return Scaffold(
                          body: Center(
                            child: Text(
                              'Database access error: ${doctorSnap.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        );
                      }

                      if (doctorSnap.hasData && doctorSnap.data!.exists) {
                        final doctorData = Map<String, dynamic>.from(doctorSnap.data!.value as Map);
                        if (doctorData['settings'] != null) {
                          final settings = Map<String, dynamic>.from(doctorData['settings'] as Map);
                          final darkMode = settings['dark_mode'] == true;
                          themeModeNotifier.value = darkMode ? ThemeMode.dark : ThemeMode.light;
                        }
                      } else if (userData['settings'] != null) {
                        final settings = Map<String, dynamic>.from(userData['settings'] as Map);
                        final darkMode = settings['dark_mode'] == true;
                        themeModeNotifier.value = darkMode ? ThemeMode.dark : ThemeMode.light;
                      }

                      return NavigationMenu(role: 'doctor', uid: customId);
                    },
                  );
                }

                if (userData['settings'] != null) {
                  var settings = Map<String, dynamic>.from(userData['settings'] as Map);
                  bool darkMode = settings['dark_mode'] ?? false;
                  themeModeNotifier.value = darkMode ? ThemeMode.dark : ThemeMode.light;
                }
                return FutureBuilder<void>(
                  future: ensurePatientDeviceStatus(customId),
                  builder: (context, statusSnapshot) {
                    if (statusSnapshot.connectionState != ConnectionState.done) {
                      return const Scaffold(body: Center(child: CircularProgressIndicator()));
                    }
                    if (statusSnapshot.hasError) {
                      return Scaffold(
                        body: Center(
                          child: Text(
                            'Device status migration error: ${statusSnapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      );
                    }
                    return NavigationMenu(role: 'patient', uid: customId);
                  },
                );
              } else {
                return FutureBuilder<DataSnapshot>(
                  future: dbRef.child('doctors/$customId').get(),
                  builder: (context, docSnap) {
                    if (docSnap.connectionState == ConnectionState.waiting) {
                      return const Scaffold(body: Center(child: CircularProgressIndicator()));
                    }
                    if (docSnap.hasError) {
                      return Scaffold(
                        body: Center(
                          child: Text(
                            'Database access error: ${docSnap.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      );
                    }
                    if (docSnap.hasData && docSnap.data!.exists) {
                      var doctorData = Map<String, dynamic>.from(docSnap.data!.value as Map);
                      if (doctorData['settings'] != null) {
                        var settings = Map<String, dynamic>.from(doctorData['settings'] as Map);
                        bool darkMode = settings['dark_mode'] ?? false;
                        themeModeNotifier.value = darkMode ? ThemeMode.dark : ThemeMode.light;
                      }
                      return NavigationMenu(role: 'doctor', uid: customId);
                    }
                    return const LoginScreen();
                  },
                );
              }
            },
          );
        }
        return const LoginScreen();
      },
    );
  }
}

class _FirebaseNotReadyScreen extends StatefulWidget {
  const _FirebaseNotReadyScreen({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  State<_FirebaseNotReadyScreen> createState() => _FirebaseNotReadyScreenState();
}

class _FirebaseNotReadyScreenState extends State<_FirebaseNotReadyScreen> {
  bool _loading = false;
  String? _message;

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    await widget.onRetry();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _message = isFirebaseDatabaseReady
          ? null
          : 'Database not initialized. Check internet connection.';
    });
    if (isFirebaseDatabaseReady) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storage_rounded, size: 48),
              const SizedBox(height: 16),
              Text(
                _message ?? 'Database not initialized',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _retry,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
