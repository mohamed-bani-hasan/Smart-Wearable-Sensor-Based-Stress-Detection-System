import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../main.dart'; // Import main.dart to access globalDatabaseRef
import '../../design_system.dart';
import 'doctor_alerts.dart';
import '../../services/firebase_paths.dart';
import '../../services/stress_level_utils.dart';

class DoctorHomeScreen extends StatefulWidget {
  final String doctorId;
  const DoctorHomeScreen({super.key, required this.doctorId});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  // Using the globally initialized DatabaseReference
  late final DatabaseReference _dbRef = requireDatabaseRef();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: AppChrome.subtleScreenBackground(context),
        child: SafeArea(
          child: StreamBuilder<DatabaseEvent>(
          stream: _dbRef.child('doctors/${widget.doctorId}').onValue,
          builder: (context, docSnap) {
            String drName = "Doctor";
            String specialty = "Specialist";
            
            if (docSnap.hasData && docSnap.data!.snapshot.value != null) {
              var data = Map<String, dynamic>.from(docSnap.data!.snapshot.value as Map);
              drName = data['name'] ?? drName;
              specialty = data['specialty'] ?? specialty;
            }

            return StreamBuilder<DatabaseEvent>(
              stream: _dbRef.child('users').orderByChild('doctorId').equalTo(widget.doctorId).onValue,
              builder: (context, patientsSnap) {
                List<MapEntry<dynamic, dynamic>> patients = [];
                if (patientsSnap.hasData && patientsSnap.data!.snapshot.value != null) {
                  patients = (patientsSnap.data!.snapshot.value as Map)
                      .entries
                      .where((entry) {
                        if (entry.value is! Map) return false;
                        final patientData =
                            Map<String, dynamic>.from(entry.value as Map);
                        return (patientData['role']?.toString() ?? 'patient') ==
                            'patient';
                      })
                      .toList();
                }

                return StreamBuilder<DatabaseEvent>(
                  stream: _dbRef.child('doctor_dashboard/${widget.doctorId}/alerts').orderByChild('seen').equalTo(false).onValue,
                  builder: (context, alertsSnap) {
                    int unreadAlerts = 0;
                    Map<dynamic, dynamic> alerts = {};
                    if (alertsSnap.hasData && alertsSnap.data!.snapshot.value != null) {
                      alerts = Map<dynamic, dynamic>.from(
                        alertsSnap.data!.snapshot.value as Map,
                      );
                      unreadAlerts = alerts.length;
                    }

                    return StreamBuilder<DatabaseEvent>(
                      stream: _dbRef.child('device_status').onValue,
                      builder: (context, deviceStatusSnap) {
                        final deviceStatusMap =
                            deviceStatusSnap.hasData &&
                                    deviceStatusSnap.data!.snapshot.value != null
                                ? Map<String, dynamic>.from(
                                    deviceStatusSnap.data!.snapshot.value as Map,
                                  )
                                : <String, dynamic>{};

                        final linkedDeviceIds = patients
                            .map((entry) => FirebasePaths.assignedDeviceId(
                                  Map<String, dynamic>.from(entry.value as Map),
                                ))
                            .whereType<String>()
                            .toSet();

                        int onlineDevices = 0;
                        for (final deviceId in linkedDeviceIds) {
                          final rawStatus = deviceStatusMap[deviceId];
                          if (rawStatus is! Map) continue;
                          final deviceData = Map<String, dynamic>.from(rawStatus);
                          if (deviceData['online'] == true) {
                            onlineDevices++;
                          }
                        }

                        return StreamBuilder<DatabaseEvent>(
                          stream: _dbRef.child('vitals/live').onValue,
                          builder: (context, liveVitalsSnap) {
                            final liveVitalsMap =
                                liveVitalsSnap.hasData &&
                                        liveVitalsSnap.data!.snapshot.value != null
                                    ? Map<String, dynamic>.from(
                                        liveVitalsSnap.data!.snapshot.value as Map,
                                      )
                                    : <String, dynamic>{};

                            final connectedPatients = patients.where((entry) {
                              if (entry.value is! Map) return false;
                              final patientData =
                                  Map<String, dynamic>.from(entry.value as Map);
                              final deviceId =
                                  FirebasePaths.assignedDeviceId(patientData);
                              if (deviceId == null) return false;
                              final rawStatus = deviceStatusMap[deviceId];
                              if (rawStatus is! Map) return false;
                              final statusData =
                                  Map<String, dynamic>.from(rawStatus);
                              return statusData['online'] == true;
                            }).toList();

                            return SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 12),
                                  AppScreenHeader(
                                    leadingCaption: 'Welcome back,',
                                    title: 'Dr. $drName',
                                    subtitle: specialty,
                                    showDateChip: true,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildStatsGrid(
                                    patients.length,
                                    linkedDeviceIds.length,
                                    onlineDevices,
                                    unreadAlerts,
                                  ),
                                  const SizedBox(height: 30),
                                  if (unreadAlerts > 0)
                                    _buildCriticalPatientsBanner(
                                      alerts,
                                      onViewPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => DoctorAlertsScreen(
                                              doctorId: widget.doctorId,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  const SizedBox(height: 30),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'CONNECTED PATIENTS',
                                        style: theme.textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.15,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        'Realtime',
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.primary.withValues(alpha: 0.85),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 15),
                                  _buildPatientList(
                                    connectedPatients,
                                    liveVitalsMap,
                                    alerts,
                                  ),
                                  const SizedBox(height: 30),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  }
                );
              },
            );
          },
        ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(
    int totalPatients,
    int linkedDevices,
    int onlineDevices,
    int criticalAlerts,
  ) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    // Taller cells — icon + value + title + subtitle overflow on small phones otherwise.
    childAspectRatio: 1.05,
    children: [
      _statCard("Total Patients", "$totalPatients", Icons.people_outline, AppSemanticColors.info, "Assigned to this doctor"),
      _statCard("Linked Devices", "$linkedDevices", Icons.devices_other_outlined, Theme.of(context).colorScheme.secondary, "Patients with a device"),
      _statCard("Online Devices", "$onlineDevices", Icons.wifi, AppSemanticColors.success, "Currently reachable"),
      _statCard("Critical Alerts", "$criticalAlerts", Icons.warning_amber_rounded, AppSemanticColors.stressHigh, "Unread patient alerts"),
    ],
  );

  Widget _statCard(String title, String val, IconData icon, Color color, String sub) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.65)),
        boxShadow: AppChrome.cardShadow(context, opacity: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const Spacer(),
          Text(
            val,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              height: 1.0,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color.withValues(alpha: 0.88),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCriticalPatientsBanner(
    Map alerts, {
    required VoidCallback onViewPressed,
  }) {
    final theme = Theme.of(context);
    var firstAlert = alerts.values.first;
    final stressLevel = StressLevelUtils.normalize(
      firstAlert['stressLevel'] ?? firstAlert['stresslevel'],
    );
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppSemanticColors.stressHigh.withValues(alpha: 0.28)),
        boxShadow: AppChrome.cardShadow(context, opacity: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.warning_amber_rounded, color: AppSemanticColors.stressHigh, size: 18), const SizedBox(width: 8), Text('Critical Patients', style: TextStyle(color: AppSemanticColors.stressHigh, fontWeight: FontWeight.w800, fontSize: 14))]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: BorderRadius.circular(15)),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppDesign.avatarBackgroundColor(firstAlert['patientName']?.toString() ?? 'Patient').withValues(alpha: 0.2),
                  child: Text(
                    AppDesign.avatarInitials(firstAlert['patientName']?.toString() ?? 'Patient'),
                    style: TextStyle(
                      color: AppDesign.avatarBackgroundColor(firstAlert['patientName']?.toString() ?? 'Patient').computeLuminance() > 0.6 ? Colors.black : Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(firstAlert['patientName'] ?? "Patient", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface)),
                    Text("Stress level: $stressLevel", style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 11)),
                  ]),
                ),
                FilledButton(
                  onPressed: onViewPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppSemanticColors.stressHigh,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPatientList(
    List<MapEntry<dynamic, dynamic>> patients,
    Map<String, dynamic> liveVitalsMap,
    Map<dynamic, dynamic> alertsMap,
  ) {
    final theme = Theme.of(context);
    if (patients.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 18,
              color: theme.textTheme.bodySmall?.color,
            ),
            const SizedBox(width: 8),
            Text(
              "No connected patients right now.",
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: patients.length,
      itemBuilder: (context, index) {
        var data = Map<String, dynamic>.from(patients[index].value as Map);
        String name = data['name'] ?? "Unknown";
        final deviceId = FirebasePaths.assignedDeviceId(data);

        if (deviceId == null) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                CircleAvatar(radius: 20, backgroundColor: AppDesign.avatarBackgroundColor(name), child: Text(AppDesign.avatarInitials(name), style: TextStyle(color: AppDesign.avatarBackgroundColor(name).computeLuminance() > 0.6 ? Colors.black : Colors.white, fontWeight: FontWeight.bold))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
                  Text("No linked device", style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 11)),
                ])),
              ],
            ),
          );
        }

        double? liveHr;
        double? liveGsr;
        String liveLevel = "Unknown";
        int unreadAlertsCount = 0;
        final rawLiveData = liveVitalsMap[deviceId];
        if (rawLiveData is Map) {
          final liveData = Map<String, dynamic>.from(rawLiveData);
          liveHr = _parseDoubleNullable(liveData['heartRate']);
          liveGsr = _parseDoubleNullable(liveData['gsr']);
          liveLevel = StressLevelUtils.normalize(
            liveData['stressLevel'] ?? liveData['stresslevel'],
            stressScore: _parseDoubleNullable(liveData['stressScore']),
          );
        }

        for (final rawAlert in alertsMap.values) {
          if (rawAlert is! Map) continue;
          final alert = Map<String, dynamic>.from(rawAlert);
          if (alert['uid']?.toString() == patients[index].key.toString() &&
              alert['seen'] == false) {
            unreadAlertsCount++;
          }
        }

            Color statusColor = liveLevel == 'High'
                ? AppSemanticColors.stressHigh
                : (liveLevel == 'Medium' ? AppSemanticColors.stressMedium : theme.colorScheme.outline);

        return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(radius: 20, backgroundColor: AppDesign.avatarBackgroundColor(name), child: Text(AppDesign.avatarInitials(name), style: TextStyle(color: AppDesign.avatarBackgroundColor(name).computeLuminance() > 0.6 ? Colors.black : Colors.white, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
                            const SizedBox(width: 6),
                            Icon(Icons.monitor_heart_outlined, color: theme.colorScheme.primary, size: 12),
                          ]),
                          Text("Live • HR: ${liveHr != null ? liveHr.toInt() : 'N/A'} BPM", style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 11)),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                        child: Text(liveLevel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.chevron_right, size: 18, color: theme.textTheme.bodySmall?.color),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _patientMiniStat(Icons.favorite_border, liveHr != null ? "${liveHr.toInt()}" : "N/A", "BPM", theme.colorScheme.error),
                      _patientMiniStat(Icons.show_chart, liveGsr != null ? liveGsr.toStringAsFixed(1) : "N/A", "uS", theme.colorScheme.secondary),
                      _patientMiniStat(Icons.trending_up, liveLevel, "Stress", statusColor),
                      _patientMiniStat(Icons.notifications_none, "$unreadAlertsCount", "Alerts", AppSemanticColors.stressHigh),
                    ],
                  )
                ],
              ),
        );
      },
    );
  }

  Widget _patientMiniStat(IconData icon, String value, String unit, Color color) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            Text(unit, style: TextStyle(fontSize: 9, color: theme.textTheme.bodySmall?.color)),
          ],
        ),
      ],
    );
  }

  double? _parseDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}




