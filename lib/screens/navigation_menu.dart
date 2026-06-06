import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'doctor/doctor_alerts.dart';
import 'doctor/doctor_patients.dart';
import 'patient/patient_exercises.dart';
import 'patient/patient_history.dart';
import 'patient/patient_home.dart';
import 'patient/patient_notifications.dart';
import 'profile_screen.dart';
import 'doctor/doctor_home.dart' as doctor_home;

class NavigationMenu extends StatefulWidget {
  final String role;
  final String uid;
  const NavigationMenu({super.key, required this.role, required this.uid});

  @override
  State<NavigationMenu> createState() => _NavigationMenuState();
}

class _NavigationMenuState extends State<NavigationMenu> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    bool isPatient = widget.role == 'patient';

    final List<Widget> patientScreens = [
      PatientHomeScreen(uid: widget.uid),
      PatientHistoryScreen(uid: widget.uid),
      PatientNotificationsScreen(uid: widget.uid), // New screen added
      PatientExercisesScreen(uid: widget.uid),
      ProfileScreen(uid: widget.uid, role: 'patient'),
    ];

    final List<Widget> doctorScreens = [
      doctor_home.DoctorHomeScreen(doctorId: widget.uid),
      DoctorPatientsScreen(doctorId: widget.uid),
      DoctorAlertsScreen(doctorId: widget.uid),
      ProfileScreen(uid: widget.uid, role: 'doctor'),
    ];

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: isPatient
          ? patientScreens[_selectedIndex]
          : doctorScreens[_selectedIndex],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.75),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 28,
              offset: const Offset(0, 10),
              spreadRadius: -6,
              color: Colors.black.withValues(alpha: 0.08),
            ),
            BoxShadow(
              blurRadius: 0,
              offset: const Offset(0, 0),
              color: theme.colorScheme.primary.withValues(alpha: 0.07),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
            child: GNav(
              rippleColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              gap: 6,
              activeColor: theme.colorScheme.onPrimary,
              iconSize: 22,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              duration: const Duration(milliseconds: 380),
              tabBorderRadius: 16,
              tabBackgroundColor: theme.colorScheme.primary,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.55) ??
                  theme.colorScheme.onSurface.withValues(alpha: 0.45),
              tabs: isPatient ? _patientGTabs() : _doctorGTabs(),
              selectedIndex: _selectedIndex,
              onTabChange: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  List<GButton> _patientGTabs() {
    return const [
      GButton(icon: Icons.home_outlined, text: 'Home'),
      GButton(icon: Icons.bar_chart_outlined, text: 'History'),
      GButton(
        icon: Icons.notifications_none_outlined,
        text: 'Alerts',
      ), // New tab
      GButton(icon: Icons.favorite_border, text: 'Exercises'),
      GButton(icon: Icons.person_outline, text: 'Profile'),
    ];
  }

  List<GButton> _doctorGTabs() {
    return const [
      GButton(icon: Icons.home_outlined, text: 'Dashboard'),
      GButton(icon: Icons.group_outlined, text: 'Patients'),
      GButton(icon: Icons.notifications_none_outlined, text: 'Alerts'),
      GButton(icon: Icons.person_outline, text: 'Profile'),
    ];
  }
}
