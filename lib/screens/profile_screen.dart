import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'login_screen.dart';
import '../../main.dart'; // Import main.dart to access globalDatabaseRef
import '../../design_system.dart';

class ProfileScreen extends StatefulWidget {
  final String uid; 
  final String role;
  const ProfileScreen({super.key, required this.uid, required this.role});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseReference _dbRef = globalDatabaseRef!;

  String _name = "";
  String _specialty = "";
  int _age = 0;
  bool _isLoading = true;
  
  Map<String, dynamic> _patientSettings = {
    'stress_level_alerts_enabled': true,
    'doctor_recommendations_enabled': true,
    'device_status_alerts_enabled': true,
  };

  Map<String, dynamic> _doctorSettings = {
    'patient_stress_alerts_enabled': true,
  };

  Map<String, dynamic> _commonSettings = {
    'dark_mode': false,
  };

  int _totalPatients = 0;
  int _improvedCount = 0; 
  int _criticalCount = 0;
  StreamSubscription<DatabaseEvent>? _patientsCountSub;
  StreamSubscription<DatabaseEvent>? _criticalAlertsSub;
  StreamSubscription<DatabaseEvent>? _improvedPatientsSub;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      String path = widget.role == 'patient' ? 'users/${widget.uid}' : 'doctors/${widget.uid}';
      DataSnapshot snapshot = await _dbRef.child(path).get();
      
      if (snapshot.exists) {
        var data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          _name = data['name'] ?? '';
          _specialty = data['specialty']?.toString() ?? '';
          
          if (widget.role == 'patient') {
            _age = data['age'] is int ? data['age'] : int.tryParse(data['age']?.toString() ?? '0') ?? 0;
          }
          if (data['settings'] != null) {
            Map<String, dynamic> loadedSettings = Map<String, dynamic>.from(data['settings']);
            if (widget.role == 'patient') {
              _patientSettings.forEach((key, value) {
                _patientSettings[key] = loadedSettings[key] ?? value;
              });
            } else {
              _doctorSettings.forEach((key, value) {
                _doctorSettings[key] = loadedSettings[key] ?? value;
              });
            }
            _commonSettings.forEach((key, value) {
              if (loadedSettings.containsKey(key)) {
                _commonSettings[key] = loadedSettings[key];
              }
            });
          }
        });

        if (widget.role == 'doctor') {
          _loadDoctorStats();
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error loading user data: $e");
      setState(() => _isLoading = false);
    }
  }

  void _loadDoctorStats() {
    _patientsCountSub?.cancel();
    _criticalAlertsSub?.cancel();
    _improvedPatientsSub?.cancel();

    _patientsCountSub = _dbRef.child('doctor_patients/${widget.uid}').onValue.listen((event) {
      if (event.snapshot.exists) {
        setState(() {
          _totalPatients = (event.snapshot.value as Map).length;
        });
      } else {
        setState(() => _totalPatients = 0);
      }
    });

    _criticalAlertsSub = _dbRef.child('doctor_dashboard/${widget.uid}/alerts').orderByChild('seen').equalTo(false).onValue.listen((event) {
      if (event.snapshot.exists) {
        setState(() {
          _criticalCount = (event.snapshot.value as Map).length;
        });
      } else {
        setState(() => _criticalCount = 0);
      }
    });

    _improvedPatientsSub = _dbRef
        .child('users')
        .orderByChild('doctorId')
        .equalTo(widget.uid)
        .onValue
        .listen((event) {
      int improved = 0;
      if (event.snapshot.exists && event.snapshot.value is Map) {
        final usersMap = Map<String, dynamic>.from(event.snapshot.value as Map);
        for (final entry in usersMap.entries) {
          if (entry.value is! Map) continue;
          final data = Map<String, dynamic>.from(entry.value as Map);
          final status = data['status']?.toString().trim().toLowerCase() ?? '';
          if (status == 'improved') {
            improved++;
          }
        }
      }
      if (mounted) {
        setState(() => _improvedCount = improved);
      }
    });
  }

  @override
  void dispose() {
    _patientsCountSub?.cancel();
    _criticalAlertsSub?.cancel();
    _improvedPatientsSub?.cancel();
    super.dispose();
  }

  Future<void> _updateSetting(String key, bool value) async {
    String path = widget.role == 'patient' ? 'users/${widget.uid}/settings' : 'doctors/${widget.uid}/settings';
    
    setState(() {
      if (widget.role == 'patient') {
        if (_patientSettings.containsKey(key)) {
          _patientSettings[key] = value;
        }
      } else {
        if (_doctorSettings.containsKey(key)) {
          _doctorSettings[key] = value;
        }
      }
      if (_commonSettings.containsKey(key)) {
        _commonSettings[key] = value;
      }
    });

    await _dbRef.child(path).update({key: value});
    if (key == 'dark_mode') {
      themeModeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
    }
  }

  void _showEditDialog() {
    final nameController = TextEditingController(text: _name);
    final specialtyController = TextEditingController(text: _specialty);
    final ageController = TextEditingController(text: _age > 0 ? '$_age' : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Profile"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Name")),
            if (widget.role == 'patient')
              TextField(controller: ageController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Age")),
            if (widget.role == 'doctor')
              TextField(controller: specialtyController, decoration: const InputDecoration(labelText: "Specialty")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              String path = widget.role == 'patient' ? 'users/${widget.uid}' : 'doctors/${widget.uid}';
              Map<String, dynamic> updates = {'name': nameController.text.trim()};
              if (widget.role == 'patient') {
                updates['age'] = int.tryParse(ageController.text.trim()) ?? _age;
              }
              if (widget.role == 'doctor') updates['specialty'] = specialtyController.text.trim();
              await _dbRef.child(path).update(updates);
              _loadUserData();
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: AppChrome.subtleScreenBackground(context),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Container(
          decoration: AppChrome.subtleScreenBackground(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: AppScreenHeader(
                  title: 'Profile',
                  subtitle: 'Settings and preferences',
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileCard(),
            const SizedBox(height: 20),
            if (widget.role == 'doctor') ...[
              _buildSectionTitle("YOUR STATS"),
              _buildDoctorStatsRow(),
              const SizedBox(height: 20),
            ],
            _buildSectionTitle("NOTIFICATION SETTINGS"),
            _buildNotificationSettings(),
            const SizedBox(height: 20),
            _buildSectionTitle("APP SETTINGS"),
            _buildAppSettings(),
            const SizedBox(height: 30),
            _buildLogoutButton(),
            const SizedBox(height: 30),
          ],
        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        boxShadow: AppChrome.cardShadow(context, opacity: 0.05),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppDesign.avatarBackgroundColor(_name),
            child: Text(
              AppDesign.avatarInitials(_name),
              style: TextStyle(color: AppDesign.avatarBackgroundColor(_name).computeLuminance() > 0.6 ? Colors.black : Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.role == 'doctor' ? "Dr. $_name" : _name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  FirebaseAuth.instance.currentUser?.email ?? "No email found",
                  style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 11),
                ),
                if (widget.role == 'patient' && _age > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text("Age: $_age years", style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 11)),
                  ),
                if (_specialty.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_specialty, style: TextStyle(color: theme.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _showEditDialog,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
              ),
              child: Icon(Icons.edit_outlined, color: scheme.primary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorStatsRow() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.65)),
        boxShadow: AppChrome.cardShadow(context, opacity: 0.04),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(
            Icons.group_outlined,
            '$_totalPatients',
            'Patients',
            AppSemanticColors.info,
          ),
          _statItem(
            Icons.medical_services_outlined,
            '$_improvedCount',
            'Improved',
            AppSemanticColors.success,
          ),
          _statItem(
            Icons.notifications_none_outlined,
            '$_criticalCount',
            'Critical',
            AppSemanticColors.stressHigh,
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String val, String label, Color color) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          val,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationSettings() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.65)),
        boxShadow: AppChrome.cardShadow(context, opacity: 0.035),
      ),
      child: Column(
        children: [
          if (widget.role == 'patient') ...[
            _settingTile(Icons.warning_amber_rounded, 'Stress Level Alerts', AppSemanticColors.stressHigh, 'stress_level_alerts_enabled', _patientSettings['stress_level_alerts_enabled'] ?? true),
            _divider(),
            _settingTile(Icons.chat_bubble_outline, 'Doctor Recommendations', scheme.secondary, 'doctor_recommendations_enabled', _patientSettings['doctor_recommendations_enabled'] ?? true),
            _divider(),
            _settingTile(Icons.devices_other_outlined, 'Device Status Alerts', AppSemanticColors.stressMedium, 'device_status_alerts_enabled', _patientSettings['device_status_alerts_enabled'] ?? true),
          ] else ...[
            _settingTile(Icons.notifications_active_outlined, 'Patient Stress Alerts', AppSemanticColors.stressHigh, 'patient_stress_alerts_enabled', _doctorSettings['patient_stress_alerts_enabled'] ?? true),
          ]
        ],
      ),
    );
  }

  Widget _buildAppSettings() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.65)),
        boxShadow: AppChrome.cardShadow(context, opacity: 0.035),
      ),
      child: Column(
        children: [
          _menuTile(Icons.dark_mode_outlined, "Dark Mode", hasSwitch: true, settingKey: 'dark_mode', value: _commonSettings['dark_mode'] ?? false),
          _divider(),
          _menuTile(Icons.shield_outlined, "Privacy & Security"),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 1, indent: 50, endIndent: 20, color: Theme.of(context).dividerColor);

  Widget _settingTile(IconData icon, String title, Color color, String settingKey, bool currentValue) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      title: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.textTheme.bodyMedium?.color)),
      trailing: SizedBox(
        height: 30,
        child: Transform.scale(
          scale: 0.82,
          child: Switch(
            value: currentValue,
            onChanged: (v) => _updateSetting(settingKey, v),
          ),
        ),
      ),
    );
  }

  Widget _menuTile(IconData icon, String title, {bool hasSwitch = false, String? settingKey, bool value = false}) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: Icon(icon, color: theme.iconTheme.color, size: 20),
      title: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.textTheme.bodyMedium?.color)),
      trailing: hasSwitch
          ? SizedBox(
              height: 30,
              child: Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: value,
                  onChanged: (v) => _updateSetting(settingKey!, v),
                ),
              ),
            )
          : const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
    );
  }

  Widget _buildLogoutButton() {
    final theme = Theme.of(context);
    final err = theme.colorScheme.error;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: err.withValues(alpha: 0.35)),
        boxShadow: AppChrome.cardShadow(context, opacity: 0.03),
      ),
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          foregroundColor: err,
        ),
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: err, size: 18),
            const SizedBox(width: 8),
            Text(
              'Log out',
              style: theme.textTheme.titleSmall?.copyWith(
                color: err,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
