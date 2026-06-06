import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math';
import '../../main.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  String _role = 'patient';
  String? _selectedDoctorId;
  String? _selectedSpecialty;
  bool _isLoading = false;

  final List<String> _stressSpecialties = [
    'Stress Management',
    'Clinical Stress Psychology',
    'Stress Psychiatry',
    'Behavioral Stress Therapy',
    'Cognitive Behavioral Therapy (Stress)',
    'Mindfulness-Based Stress Reduction',
    'Occupational Stress Medicine',
    'Trauma and Stress Counseling',
  ];

  String _generateCustomId(String name) {
    int randomNumber = Random().nextInt(900) + 100;
    String cleanName = name.replaceAll(' ', '').toLowerCase();
    return '${cleanName}_$randomNumber';
  }

  Future<String> _generateUniqueCustomId(
    String name,
    DatabaseReference dbRef,
  ) async {
    const maxAttempts = 30;
    for (int i = 0; i < maxAttempts; i++) {
      final candidate = _generateCustomId(name);
      final userSnap = await dbRef.child('users/$candidate').get();
      if (userSnap.exists) continue;
      final doctorSnap = await dbRef.child('doctors/$candidate').get();
      if (doctorSnap.exists) continue;
      return candidate;
    }
    throw Exception(
      'Unable to generate a unique ID right now. Please try again.',
    );
  }

  Future<void> _register() async {
    String name = _nameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    if (_role == 'patient' && _selectedDoctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a doctor')),
      );
      return;
    }

    if (!isFirebaseDatabaseReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Database is not ready. Check your internet connection and try again.',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    User? createdUser;
    bool dbWriteSucceeded = false;
    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      createdUser = userCredential.user;

      final DatabaseReference dbRef = requireDatabaseRef();
      final String customId = await _generateUniqueCustomId(name, dbRef);
      await userCredential.user!.updateDisplayName(customId);

      if (_role == 'patient') {
        await dbRef.child('users/$customId').set({
          'name': name,
          'age': int.tryParse(_ageController.text.trim()) ?? 0,
          'deviceId': '',
          'doctorId': _selectedDoctorId,
          'status': 'normal',
          'role': 'patient',
          'settings': {
            'stress_level_alerts_enabled': true,
            'doctor_recommendations_enabled': true,
            'device_status_alerts_enabled': true,
            'dark_mode': false,
          },
        });

        await dbRef.child('doctor_patients/$_selectedDoctorId/$customId').set(true);

        await dbRef.child('notifications/$customId').push().set({
          'title': 'Welcome!',
          'message':
              'Your account has been created and linked to your doctor.',
          'timestamp': ServerValue.timestamp,
          'type': 'info',
          'read': false,
        });
      } else {
        await dbRef.child('doctors/$customId').set({
          'name': name,
          'specialty': _selectedSpecialty ?? 'General',
          'role': 'doctor',
          'settings': {
            'patient_stress_alerts_enabled': true,
            'dark_mode': false,
          },
        });
      }
      dbWriteSucceeded = true;

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Success! Your ID: $customId')),
        );
      }
    } catch (e) {
      if (!dbWriteSucceeded && createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {
          await FirebaseAuth.instance.signOut();
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Create account',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _roleChip(
                      theme,
                      value: 'patient',
                      label: 'Patient',
                      icon: Icons.person_outline_rounded,
                    ),
                  ),
                  Expanded(
                    child: _roleChip(
                      theme,
                      value: 'doctor',
                      label: 'Doctor',
                      icon: Icons.medical_services_outlined,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.65),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Your details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All fields marked in the form are required for registration.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.58),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    _nameController,
                    'Full name',
                    Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    _emailController,
                    'Email',
                    Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    _passwordController,
                    'Password',
                    Icons.lock_outline_rounded,
                    obscureText: true,
                  ),
                  const SizedBox(height: 14),
                  if (_role == 'patient') ...[
                    _buildTextField(
                      _ageController,
                      'Age',
                      Icons.cake_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),
                    _buildDoctorDropdown(theme),
                  ] else ...[
                    _buildSpecialtyDropdown(theme),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              FilledButton(
                onPressed: _register,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                ),
                child: const Text('Create account'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _roleChip(
    ThemeData theme, {
    required String value,
    required String label,
    required IconData icon,
  }) {
    final scheme = theme.colorScheme;
    final selected = _role == value;
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: selected ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => setState(() => _role = value),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? scheme.onPrimary : scheme.onSurface.withValues(alpha: 0.65),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? scheme.onPrimary : scheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 22),
      ),
    );
  }

  Widget _buildDoctorDropdown(ThemeData theme) {
    if (!isFirebaseDatabaseReady) {
      return Text(
        'Cannot load doctors — database not connected.',
        style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
      );
    }

    return StreamBuilder<DatabaseEvent>(
      stream: requireDatabaseRef().child('doctors').onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Error: ${snapshot.error}',
            style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Loading doctors...',
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 12,
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'No doctors found. Please register a doctor account first.',
              style: TextStyle(color: theme.colorScheme.secondary, fontSize: 12),
            ),
          );
        }

        Map<dynamic, dynamic> doctorsMap =
            snapshot.data!.snapshot.value as Map;
        return DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Assign to doctor',
            prefixIcon: Icon(Icons.medical_services_outlined, size: 22),
          ),
          value: _selectedDoctorId,
          items: doctorsMap.entries
              .map(
                (entry) => DropdownMenuItem<String>(
                  value: entry.key.toString(),
                  child: Text(
                    entry.value['name'] ?? 'Dr. Unknown',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _selectedDoctorId = val),
        );
      },
    );
  }

  Widget _buildSpecialtyDropdown(ThemeData theme) {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Specialty',
        prefixIcon: Icon(Icons.star_outline_rounded, size: 22),
      ),
      value: _selectedSpecialty,
      items: _stressSpecialties
          .map(
            (s) => DropdownMenuItem(
              value: s,
              child: Text(s, style: theme.textTheme.bodyMedium),
            ),
          )
          .toList(),
      onChanged: (val) => setState(() => _selectedSpecialty = val),
    );
  }
}
