import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../main.dart';
import '../../design_system.dart';
import '../../services/firebase_paths.dart';
import '../../services/stress_level_utils.dart';

class PatientHomeScreen extends StatefulWidget {
  final String uid;
  const PatientHomeScreen({super.key, required this.uid});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  late final DatabaseReference _dbRef = requireDatabaseRef();

  DateTime? _lastAlertTime;
  DateTime? _lastRecommendationTime;
  DateTime? _lastStatusSyncTime;
  bool _statusSyncInProgress = false;
  bool _monitoringActionInProgress = false;
  String _monitoringPhase = 'idle';
  String _monitoringStatusMessage = '';
  StreamSubscription<DatabaseEvent>? _liveVitalsSub;
  String? _liveVitalsDeviceId;
  Map<String, dynamic>? _latestLiveReading;

  // آلية العمل: التحقق من مستوى التوتر وإرسال تنبيه آلي للدكتور
  void _checkAndSendAutoAlert(
    String stressLevel,
    String name,
    String doctorId,
  ) async {
    // إذا كان التوتر عالياً والدكتور موجود
    if (StressLevelUtils.isHigh(stressLevel) && doctorId.isNotEmpty) {
      // إرسال تنبيه واحد كل 5 دقائق لتجنب التكرار المزعج
      if (_lastAlertTime == null ||
          DateTime.now().difference(_lastAlertTime!).inMinutes >= 5) {
        _lastAlertTime = DateTime.now();

        try {
          DatabaseReference alertRef = _dbRef
              .child('doctor_dashboard/$doctorId/alerts')
              .push();
          await alertRef.set({
            'uid': widget.uid,
            'patientName': name,
            'stressLevel': 'High',
            'alertType': 'auto_stress',
            'message':
                '$name has high stress level. Immediate attention may be needed.',
            'timestamp': ServerValue.timestamp,
            'seen': false,
          });
        } catch (e) {
          debugPrint("Error sending auto alert: $e");
        }
      }
    }
  }

  Future<void> _syncPatientStatusFromHistory(String currentStatus) async {
    if (_statusSyncInProgress) return;
    if (_lastStatusSyncTime != null &&
        DateTime.now().difference(_lastStatusSyncTime!).inMinutes < 5) {
      return;
    }

    _statusSyncInProgress = true;
    _lastStatusSyncTime = DateTime.now();
    try {
      final historySnap = await FirebasePaths.userHistoryRef(
        _dbRef,
        widget.uid,
      ).limitToLast(200).get();
      if (!historySnap.exists || historySnap.value is! Map) {
        return;
      }

      final now = DateTime.now();
      final windowStart = now.subtract(const Duration(days: 3));
      final entries = <Map<String, dynamic>>[];
      final historyMap = Map<String, dynamic>.from(historySnap.value as Map);

      for (final item in historyMap.values) {
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);
        final ts = _parseInt(row['timestamp'], fallback: 0);
        if (ts <= 0) continue;
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        if (dt.isBefore(windowStart) || dt.isAfter(now)) continue;
        final level = StressLevelUtils.normalize(
          row['stressLevel'] ?? row['stresslevel'],
          stressScore: _parseDoubleNullable(row['stressScore']),
        );
        entries.add({'timestamp': ts, 'level': level});
      }

      if (entries.length < 20) {
        return;
      }

      entries.sort(
        (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int),
      );
      final recent20 = entries.take(20).toList();
      final newestTs = recent20.first['timestamp'] as int;
      final oldestTs = recent20.last['timestamp'] as int;
      final coverage = Duration(milliseconds: newestTs - oldestTs);

      final normalCount = recent20
          .where((entry) => entry['level'] == 'Normal')
          .length;
      final mostlyNormal = normalCount >= 12;
      final spansThreeDays = coverage >= const Duration(days: 3);
      final targetStatus = (mostlyNormal && spansThreeDays)
          ? 'improved'
          : 'normal';

      final normalizedCurrent = currentStatus.trim().toLowerCase();
      if (normalizedCurrent != targetStatus) {
        await _dbRef.child('users/${widget.uid}').update({
          'status': targetStatus,
        });
      }
    } catch (e) {
      debugPrint('Auto status sync failed: $e');
    } finally {
      _statusSyncInProgress = false;
    }
  }

  void _attachLiveVitalsListener(String deviceId) {
    if (_liveVitalsDeviceId == deviceId && _liveVitalsSub != null) return;

    _liveVitalsSub?.cancel();
    _liveVitalsDeviceId = deviceId;
    _latestLiveReading = null;

    _liveVitalsSub =
        FirebasePaths.userLiveVitalsRef(
          _dbRef,
          widget.uid,
          deviceId,
        ).onValue.listen((event) {
          Map<String, dynamic>? nextReading;
          if (event.snapshot.value is Map) {
            nextReading = Map<String, dynamic>.from(
              event.snapshot.value as Map,
            );
          }
          if (!mounted) return;
          setState(() {
            _latestLiveReading = nextReading;
          });
        });
  }

  void _detachLiveVitalsListener() {
    _liveVitalsSub?.cancel();
    _liveVitalsSub = null;
    _liveVitalsDeviceId = null;
    if (_latestLiveReading == null) return;
    if (!mounted) {
      _latestLiveReading = null;
      return;
    }
    setState(() => _latestLiveReading = null);
  }

  @override
  void dispose() {
    _detachLiveVitalsListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: AppChrome.subtleScreenBackground(context),
        child: SafeArea(
          child: StreamBuilder<DatabaseEvent>(
            stream: _dbRef.child('users/${widget.uid}').onValue,
            builder: (context, userSnap) {
              if (!userSnap.hasData || userSnap.data?.snapshot.value == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final snapshotValue = userSnap.data!.snapshot.value;
              if (snapshotValue is! Map) {
                _detachLiveVitalsListener();
                return const Center(child: Text('Invalid user data'));
              }

              final userData = Map<String, dynamic>.from(snapshotValue);
              final settings = userData['settings'] is Map
                  ? Map<String, dynamic>.from(userData['settings'] as Map)
                  : const <String, dynamic>{};

              final name =
                  userData['name']?.toString().trim().isNotEmpty == true
                  ? userData['name'].toString()
                  : 'User';
              final doctorId = userData['doctorId']?.toString() ?? '';
              final currentStatus = userData['status']?.toString() ?? 'normal';
              final deviceId = FirebasePaths.assignedDeviceId(userData);

              final stressAlertsEnabled =
                  settings['stress_level_alerts_enabled'] is bool
                  ? settings['stress_level_alerts_enabled'] as bool
                  : true;
              final recommendationsEnabled =
                  settings['doctor_recommendations_enabled'] is bool
                  ? settings['doctor_recommendations_enabled'] as bool
                  : true;
              final deviceStatusAlertsEnabled =
                  settings['device_status_alerts_enabled'] is bool
                  ? settings['device_status_alerts_enabled'] as bool
                  : true;

              if (deviceId == null) {
                if (_liveVitalsSub != null) {
                  _detachLiveVitalsListener();
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 15),
                      _buildHeaderPro(name),
                      const SizedBox(height: 12),
                      _buildStatusBadgesPro(
                        false,
                        false,
                        null,
                        null,
                        'Unlinked',
                      ),
                      const SizedBox(height: 15),
                      _buildDisabledNoticePro(
                        'No device is linked yet. Start monitoring to auto-connect an available device.',
                      ),
                      if (!deviceStatusAlertsEnabled) ...[
                        const SizedBox(height: 10),
                        _buildDisabledNoticePro(
                          'Device status alerts are turned off.',
                        ),
                      ],
                      const SizedBox(height: 15),
                      if (recommendationsEnabled)
                        _buildRecommendationSectionPro('Unknown')
                      else
                        _buildDisabledNoticePro(
                          'Doctor recommendations are turned off.',
                        ),
                      const SizedBox(height: 20),
                      _buildStressCirclePro(
                        context,
                        null,
                        'Unknown',
                        'Waiting...',
                      ),
                      const SizedBox(height: 25),
                      Row(
                        children: [
                          Expanded(
                            child: _vitalCardPro(
                              'Heart Rate',
                              'N/A',
                              'BPM',
                              Icons.favorite,
                              Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _vitalCardPro(
                              'GSR Level',
                              'N/A',
                              'uS',
                              Icons.show_chart,
                              Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildActionButtonsPro(false, false, doctorId, name),
                      const SizedBox(height: 20),
                      _buildSummarySectionPro(widget.uid),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              }

              double? heartRate;
              double? gsr;
              String stressLevel = 'Unknown';
              double? stressVal;
              String lastUpdate = 'Waiting...';
              final reading = _latestLiveReading;

              if (reading != null) {
                heartRate = _parseDoubleNullable(
                  reading['heartRate'] ?? reading['heartrate'],
                );
                gsr = _parseDoubleNullable(reading['gsr']);
                stressVal = StressLevelUtils.scoreFrom(
                  reading['stressScore'],
                  rawLevel: reading['stressLevel'] ?? reading['stresslevel'],
                );
                stressLevel = StressLevelUtils.normalize(
                  reading['stressLevel'] ?? reading['stresslevel'],
                  stressScore: stressVal,
                );

                if (reading['timestamp'] != null) {
                  final ts = _parseInt(reading['timestamp'], fallback: 0);
                  if (ts > 0) {
                    final date = DateTime.fromMillisecondsSinceEpoch(ts);
                    lastUpdate = DateFormat('h:mm:ss a').format(date);
                  }
                }

              }

              return StreamBuilder<DatabaseEvent>(
                stream: FirebasePaths.deviceStatusRef(_dbRef, deviceId).onValue,
                builder: (context, statusSnap) {
                  bool online = false;
                  bool monitoringActive = false;
                  int? wifiPercent;
                  int? batteryPercent;
                  String connectionText = 'Unknown';

                  if (statusSnap.hasData &&
                      statusSnap.data?.snapshot.value is Map) {
                    final statusData = Map<String, dynamic>.from(
                      statusSnap.data!.snapshot.value as Map,
                    );
                    online = statusData['online'] == true;
                    monitoringActive = statusData['monitoringActive'] == true;
                    wifiPercent = _parseIntNullable(statusData['wifi']);
                    batteryPercent = _parseIntNullable(statusData['battery']);
                    connectionText =
                        statusData['connectionType']?.toString() ?? 'Unknown';
                  }

                  if (monitoringActive) {
                    _attachLiveVitalsListener(deviceId);
                  } else if (_liveVitalsSub != null) {
                    _detachLiveVitalsListener();
                  }

                  final displayHeartRate = monitoringActive ? heartRate : null;
                  final displayGsr = monitoringActive ? gsr : null;
                  final displayStressLevel =
                      monitoringActive ? stressLevel : 'Unknown';
                  final displayStressVal = monitoringActive ? stressVal : null;
                  final displayLastUpdate =
                      monitoringActive ? lastUpdate : 'Stopped';

                  if (monitoringActive && reading != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      if (stressAlertsEnabled) {
                        _checkAndSendAutoAlert(
                          displayStressLevel,
                          name,
                          doctorId,
                        );
                      }
                      if (recommendationsEnabled) {
                        _checkAndSendAutoRecommendation(displayStressLevel);
                      }
                      _syncPatientStatusFromHistory(currentStatus);
                    });
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 15),
                        _buildHeaderPro(name),
                        const SizedBox(height: 12),
                        _buildStatusBadgesPro(
                          online,
                          monitoringActive,
                          wifiPercent,
                          batteryPercent,
                          connectionText,
                        ),
                        if (!deviceStatusAlertsEnabled) ...[
                          const SizedBox(height: 15),
                          _buildDisabledNoticePro(
                            'Device status alerts are turned off.',
                          ),
                        ],
                        const SizedBox(height: 15),
                        if (recommendationsEnabled)
                          _buildRecommendationSectionPro(displayStressLevel)
                        else
                          _buildDisabledNoticePro(
                            'Doctor recommendations are turned off.',
                          ),
                        const SizedBox(height: 20),
                        _buildStressCirclePro(
                          context,
                          displayStressVal,
                          displayStressLevel,
                          displayLastUpdate,
                        ),
                        const SizedBox(height: 25),
                        Row(
                          children: [
                            Expanded(
                              child: _vitalCardPro(
                                'Heart Rate',
                                displayHeartRate != null
                                    ? "${displayHeartRate.toInt()}"
                                    : 'N/A',
                                'BPM',
                                Icons.favorite,
                                theme.colorScheme.error,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _vitalCardPro(
                                'GSR Level',
                                displayGsr != null
                                    ? displayGsr.toStringAsFixed(1)
                                    : 'N/A',
                                'uS',
                                Icons.show_chart,
                                theme.colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildActionButtonsPro(
                          monitoringActive,
                          online,
                          doctorId,
                          name,
                        ),
                        const SizedBox(height: 20),
                        _buildSummarySectionPro(
                          widget.uid,
                          liveReading: reading,
                          includeLiveReading:
                              monitoringActive && reading != null,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderPro(String name) {
    final firstName = name.trim().split(RegExp(r'\s+')).first;
    return AppScreenHeader(
      title: 'Hello, $firstName',
      subtitle: 'Live health dashboard',
      showDateChip: true,
    );
  }

  Widget _buildStatusBadgesPro(
    bool online,
    bool monitoringActive,
    int? wifiPercent,
    int? batteryPercent,
    String connectionText,
  ) {
    final theme = Theme.of(context);
    return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _statusChipPro(
        Icons.wifi,
        wifiPercent != null ? "Wi-Fi $wifiPercent%" : "Wi-Fi N/A",
        wifiPercent != null
            ? (wifiPercent >= 50
                ? AppSemanticColors.success
                : AppSemanticColors.stressMedium)
            : theme.colorScheme.outline,
      ),
      _statusChipPro(
        monitoringActive ? Icons.play_circle_fill : Icons.pause_circle_filled,
        monitoringActive ? "Monitoring" : "Stopped",
        monitoringActive ? AppSemanticColors.success : theme.colorScheme.outline,
      ),
      _statusChipPro(
        Icons.sensors,
        online ? connectionText : "Offline",
        online ? AppSemanticColors.deviceOnline : theme.colorScheme.error,
      ),
      _statusChipPro(
        Icons.battery_4_bar,
        batteryPercent != null ? "Battery $batteryPercent%" : "Battery N/A",
        batteryPercent != null
            ? (batteryPercent >= 20
                ? theme.colorScheme.outline
                : theme.colorScheme.error)
            : theme.colorScheme.outline,
      ),
    ],
    );
  }

  Widget _statusChipPro(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.22)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 12, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _buildRecommendationSectionPro(String level) {
    final normalizedLevel = StressLevelUtils.normalize(level);
    if (normalizedLevel == 'Unknown') {
      return _buildRecommendationNoDataCard();
    }

    return StreamBuilder<DatabaseEvent>(
      stream: _dbRef.child('recommendations/$normalizedLevel').onValue,
      builder: (context, snapshot) {
        String message = _recommendationFallback(level);
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final data = Map<String, dynamic>.from(
            snapshot.data!.snapshot.value as Map,
          );
          message = data['text'] ?? message;
        }

        final bool isHigh = normalizedLevel == 'High';
        final bool isMedium = normalizedLevel == 'Medium';
        final accent = isHigh
            ? AppSemanticColors.stressHigh
            : (isMedium
                ? AppSemanticColors.stressMedium
                : AppSemanticColors.stressNormal);
        final title = isHigh
            ? 'High Stress Detected'
            : (isMedium ? 'Moderate Stress' : 'Stress Level Stable');
        final theme = Theme.of(context);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent.withValues(alpha: 0.12), theme.cardColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.24)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isHigh
                      ? Icons.warning_amber_rounded
                      : Icons.lightbulb_outline,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: TextStyle(
                        height: 1.35,
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Shown when there is no linked device or no live vitals yet — not a "stable" stress reading.
  Widget _buildRecommendationNoDataCard() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = scheme.outline;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.1),
            theme.cardColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.sensors_off_outlined,
              color: scheme.onSurface.withValues(alpha: 0.55),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No live stress data',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Recommendations appear after you link a device and receive vitals. '
                  'Use Start Live Monitoring when your device is ready.',
                  style: TextStyle(
                    height: 1.35,
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledNoticePro(String text) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.info_outline,
              color: theme.colorScheme.primary,
              size: 15,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStressCirclePro(
    BuildContext context,
    double? val,
    String level,
    String time,
  ) {
    final theme = Theme.of(context);
    final normalizedLevel = StressLevelUtils.normalize(level, stressScore: val);
    final Color color = normalizedLevel == 'High'
        ? AppSemanticColors.stressHigh
        : (normalizedLevel == 'Medium'
            ? AppSemanticColors.stressMedium
            : AppSemanticColors.stressNormal);
    final int displayValue = val?.toInt() ?? 0;
    final radius = (MediaQuery.of(context).size.width * 0.21).clamp(74.0, 88.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "Live Stress Overview",
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: (radius * 2) + 22,
                height: (radius * 2) + 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [color.withValues(alpha: 0.12), Colors.transparent],
                  ),
                ),
              ),
              CircularPercentIndicator(
                radius: radius,
                lineWidth: 11,
                percent: ((val ?? 0) / 100).clamp(0, 1),
                animation: true,
                circularStrokeCap: CircularStrokeCap.round,
                progressColor: color,
                backgroundColor: theme.dividerColor,
                center: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      val != null ? "$displayValue" : "N/A",
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "Stress Level",
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      normalizedLevel,
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _legendDotPro("Normal", AppSemanticColors.stressNormal),
              _legendDotPro("Medium", AppSemanticColors.stressMedium),
              _legendDotPro("High", AppSemanticColors.stressHigh),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Last update: $time",
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDotPro(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vitalCardPro(
    String title,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsPro(
    bool monitoringActive,
    bool online,
    String doctorId,
    String patientName,
  ) {
    final theme = Theme.of(context);
    if (!_monitoringActionInProgress) {
      if (monitoringActive && _monitoringPhase != 'active') {
        _monitoringPhase = 'active';
        _monitoringStatusMessage = 'Live monitoring is active.';
      } else if (!monitoringActive && _monitoringPhase == 'active') {
        _monitoringPhase = 'idle';
        _monitoringStatusMessage = '';
      }
    }

    final isStarting = _monitoringActionInProgress && !monitoringActive;
    final isStopping = _monitoringActionInProgress && monitoringActive;
    final startLabel = _monitoringPhase == 'failed'
        ? 'Retry Live Monitoring'
        : (monitoringActive
              ? (isStopping ? 'Stopping...' : 'Stop Live Monitoring')
              : (isStarting
                    ? (_monitoringPhase == 'checking'
                          ? 'Checking...'
                          : 'Connecting...')
                    : 'Start Live Monitoring'));
    final startIcon = monitoringActive
        ? Icons.pause_circle_outline
        : Icons.play_circle_outline;
    final startColor = monitoringActive
        ? theme.colorScheme.error
        : AppSemanticColors.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _actionButtonPro(
          startIcon,
          startLabel,
          startColor,
          startColor,
          isOutlined: false,
          isLoading: _monitoringActionInProgress,
          isDisabled: _monitoringActionInProgress,
          onPressed: () => _toggleMonitoring(!monitoringActive),
        ),
        if (_monitoringStatusMessage.isNotEmpty) ...[
          const SizedBox(height: 9),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: (_monitoringPhase == 'failed'
                      ? theme.colorScheme.error
                      : AppSemanticColors.info)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (_monitoringPhase == 'failed'
                        ? theme.colorScheme.error
                        : AppSemanticColors.info)
                    .withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              _monitoringStatusMessage,
              style: TextStyle(
                color: _monitoringPhase == 'failed'
                    ? theme.colorScheme.error
                    : theme.textTheme.bodySmall?.color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _actionButtonPro(
          Icons.chat_bubble_outline,
          "Send Consultation",
          AppSemanticColors.info,
          theme.cardColor,
          isOutlined: true,
          isDisabled: _monitoringActionInProgress,
          onPressed: () => _showConsultationDialog(doctorId, patientName),
        ),
      ],
    );
  }

  Widget _actionButtonPro(
    IconData icon,
    String label,
    Color color,
    Color bg, {
    bool isOutlined = false,
    bool isLoading = false,
    bool isDisabled = false,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final fgColor = isOutlined ? color : Colors.white;

    return InkWell(
      onTap: isDisabled ? null : onPressed,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          gradient: isOutlined
              ? null
              : LinearGradient(
                  colors: [
                    Color.lerp(color, Colors.white, 0.08)!,
                    Color.lerp(color, Colors.black, 0.08)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: isOutlined ? theme.cardColor : bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOutlined
                ? color.withValues(alpha: 0.22)
                : color.withValues(alpha: 0.34),
          ),
          boxShadow: isOutlined
              ? null
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                ),
              )
            else
              Icon(icon, color: fgColor, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: fgColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _stressScoreFromHistoryEntry(Map<String, dynamic> entry) {
    final level = _stressLevelFromHistoryEntry(entry);
    return StressLevelUtils.scoreFrom(
      entry['stressScore'],
      rawLevel: level,
    );
  }

  String _stressLevelFromHistoryEntry(Map<String, dynamic> entry) {
    if (entry['stressLevel'] != null || entry['stresslevel'] != null) {
      return StressLevelUtils.normalize(
        entry['stressLevel'] ?? entry['stresslevel'],
        stressScore: _parseDoubleNullable(entry['stressScore']),
      );
    }

    final gsr = _parseDoubleNullable(entry['gsr']);
    final hr = _parseDoubleNullable(entry['heartRate'] ?? entry['heartrate']);
    if (gsr == null && hr == null) return 'Unknown';

    if (gsr != null) {
      if (gsr >= 2400) return 'High';
      if (gsr >= 1600) return 'Medium';
      return 'Normal';
    }

    if (hr != null) {
      if (hr >= 100) return 'High';
      if (hr >= 85) return 'Medium';
    }
    return 'Normal';
  }

  bool _historyEntryHasStressData(Map<String, dynamic> entry) {
    return entry['stressLevel'] != null ||
        entry['stresslevel'] != null ||
        entry['stressScore'] != null ||
        entry['gsr'] != null ||
        entry['heartRate'] != null ||
        entry['heartrate'] != null;
  }

  List<Map<String, dynamic>> _parseHistoryEntries(dynamic rawHistory) {
    if (rawHistory is! Map) return [];

    final entries = <Map<String, dynamic>>[];
    for (final value in rawHistory.values) {
      if (value is! Map) continue;
      final entry = Map<String, dynamic>.from(value);
      final ts = _parseTimestampMs(entry['timestamp']);
      if (ts <= 0) continue;
      entry['timestamp'] = ts;
      entries.add(entry);
    }

    entries.sort(
      (a, b) => _parseInt(a['timestamp']).compareTo(_parseInt(b['timestamp'])),
    );
    return entries;
  }

  int _parseTimestampMs(dynamic value) {
    var ts = _parseInt(value, fallback: 0);
    if (ts <= 0) return 0;
    // Firebase server timestamps are ms; accept 10-digit second values too.
    if (ts < 10000000000) ts *= 1000;
    return ts;
  }

  List<Map<String, dynamic>> _entriesForSummary(
    List<Map<String, dynamic>> allEntries,
  ) {
    if (allEntries.isEmpty) return allEntries;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startMs = startOfDay.millisecondsSinceEpoch;
    final endMs = startOfDay.add(const Duration(days: 1)).millisecondsSinceEpoch;
    final last24hMs = now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch;

    final todayEntries = allEntries.where((entry) {
      final ts = _parseInt(entry['timestamp'], fallback: 0);
      return ts >= startMs && ts < endMs;
    }).toList();
    if (todayEntries.isNotEmpty) return todayEntries;

    final recentEntries = allEntries.where((entry) {
      final ts = _parseInt(entry['timestamp'], fallback: 0);
      return ts >= last24hMs;
    }).toList();
    if (recentEntries.isNotEmpty) return recentEntries;

    return allEntries.length <= 50
        ? allEntries
        : allEntries.sublist(allEntries.length - 50);
  }

  List<Map<String, dynamic>> _mergeLiveReadingIntoSummaryEntries(
    List<Map<String, dynamic>> entries,
    Map<String, dynamic>? liveReading,
  ) {
    if (liveReading == null) return entries;

    final ts = _parseTimestampMs(liveReading['timestamp']);
    if (ts <= 0) return entries;

    final liveEntry = Map<String, dynamic>.from(liveReading);
    liveEntry['timestamp'] = ts;

    final merged = List<Map<String, dynamic>>.from(entries);
    final duplicate = merged.any(
      (entry) => (_parseInt(entry['timestamp']) - ts).abs() < 3000,
    );
    if (!duplicate) {
      merged.add(liveEntry);
      merged.sort(
        (a, b) =>
            _parseInt(a['timestamp']).compareTo(_parseInt(b['timestamp'])),
      );
    }
    return merged;
  }

  String _formatCalmDuration(int calmMillis) {
    if (calmMillis <= 0) return '0m';
    final calmHours = calmMillis ~/ Duration.millisecondsPerHour;
    final calmMinutes =
        (calmMillis % Duration.millisecondsPerHour) ~/
        Duration.millisecondsPerMinute;
    if (calmHours > 0) {
      return '${calmHours}h ${calmMinutes}m';
    }
    return '${calmMinutes}m';
  }

  ({double avgStress, String peakTime, String calmTime}) _computeTodaySummary(
    List<Map<String, dynamic>> todayEntries,
  ) {
    if (todayEntries.isEmpty) {
      return (avgStress: 0, peakTime: 'N/A', calmTime: '0m');
    }

    double stressSum = 0;
    int stressCount = 0;
    double maxVal = -1;
    int maxTs = 0;

    for (final entry in todayEntries) {
      if (!_historyEntryHasStressData(entry)) continue;

      final score = _stressScoreFromHistoryEntry(entry);
      stressSum += score;
      stressCount++;

      final ts = _parseInt(entry['timestamp'], fallback: 0);
      if (score > maxVal) {
        maxVal = score;
        maxTs = ts;
      }
    }

    final avgStress = stressCount > 0 ? stressSum / stressCount : 0.0;
    final peakTime = maxTs > 0
        ? DateFormat('h:mm a').format(
            DateTime.fromMillisecondsSinceEpoch(maxTs),
          )
        : 'N/A';

    int calmMillis = 0;
    for (int i = 1; i < todayEntries.length; i++) {
      final prev = todayEntries[i - 1];
      final curr = todayEntries[i];
      final prevLevel = _stressLevelFromHistoryEntry(prev);
      if (prevLevel != 'Normal') continue;

      final prevTs = _parseInt(prev['timestamp'], fallback: 0);
      final currTs = _parseInt(curr['timestamp'], fallback: 0);
      if (prevTs <= 0 || currTs <= prevTs) continue;
      calmMillis += currTs - prevTs;
    }

    if (todayEntries.isNotEmpty) {
      final last = todayEntries.last;
      final lastLevel = _stressLevelFromHistoryEntry(last);
      if (lastLevel == 'Normal') {
        final lastTs = _parseInt(last['timestamp'], fallback: 0);
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (lastTs > 0 && nowMs > lastTs) {
          final trailing = nowMs - lastTs;
          final maxTrailing = const Duration(minutes: 30).inMilliseconds;
          calmMillis += trailing > maxTrailing ? maxTrailing : trailing;
        }
      }
    }

    return (
      avgStress: avgStress,
      peakTime: peakTime,
      calmTime: _formatCalmDuration(calmMillis),
    );
  }

  Widget _buildSummarySectionPro(
    String uid, {
    Map<String, dynamic>? liveReading,
    bool includeLiveReading = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "TODAY'S SUMMARY",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: theme.textTheme.bodySmall?.color,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: StreamBuilder<DatabaseEvent>(
            stream: FirebasePaths.userHistoryRef(
              _dbRef,
              uid,
            ).limitToLast(200).onValue,
            builder: (context, snapshot) {
              double avgStress = 0;
              String peakTime = 'N/A';
              String calmTime = '0m';

              if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                final allEntries = _parseHistoryEntries(
                  snapshot.data!.snapshot.value,
                );
                var summaryEntries = _entriesForSummary(allEntries);
                if (includeLiveReading) {
                  summaryEntries = _mergeLiveReadingIntoSummaryEntries(
                    summaryEntries,
                    liveReading,
                  );
                }
                final summary = _computeTodaySummary(summaryEntries);
                avgStress = summary.avgStress;
                peakTime = summary.peakTime;
                calmTime = summary.calmTime;
              }

              return IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _summaryMetricPro(
                        icon: Icons.monitor_heart_outlined,
                        value: "${avgStress.toInt()}%",
                        label: "Avg Stress",
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    VerticalDivider(
                      width: 18,
                      thickness: 1,
                      color: theme.dividerColor.withValues(alpha: 0.45),
                    ),
                    Expanded(
                      child: _summaryMetricPro(
                        icon: Icons.schedule_outlined,
                        value: peakTime,
                        label: "Peak Time",
                        color: AppSemanticColors.stressMedium,
                      ),
                    ),
                    VerticalDivider(
                      width: 18,
                      thickness: 1,
                      color: theme.dividerColor.withValues(alpha: 0.45),
                    ),
                    Expanded(
                      child: _summaryMetricPro(
                        icon: Icons.spa_outlined,
                        value: calmTime,
                        label: "Calm Time",
                        color: AppSemanticColors.success,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _summaryMetricPro({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: theme.textTheme.bodySmall?.color,
            fontSize: 10,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _recommendationFallback(String level) {
    switch (StressLevelUtils.normalize(level)) {
      case 'High':
        return 'High stress detected. Please practice deep breathing.';
      case 'Medium':
        return 'Moderate stress detected. Try relaxing music.';
      case 'Normal':
        return 'Your stress level is normal. Keep it up!';
      case 'Unknown':
        return 'Connect a device and start monitoring to see personalized tips.';
      default:
        return 'Your stress level is normal. Keep it up!';
    }
  }

  int _parseInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  int? _parseIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _parseDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<List<String>> _findAvailableDeviceIds() async {
    final statusSnap = await _dbRef.child('device_status').get();
    if (!statusSnap.exists || statusSnap.value is! Map) {
      return [];
    }

    final statusMap = Map<String, dynamic>.from(statusSnap.value as Map);
    final usersSnap = await _dbRef.child('users').get();
    final assignedDeviceIds = <String>{};

    if (usersSnap.exists && usersSnap.value is Map) {
      final usersMap = Map<String, dynamic>.from(usersSnap.value as Map);
      for (final entry in usersMap.entries) {
        final userData = entry.value is Map<String, dynamic>
            ? entry.value as Map<String, dynamic>
            : Map<String, dynamic>.from(entry.value as Map);
        final assignedDeviceId = FirebasePaths.assignedDeviceId(userData);
        if (assignedDeviceId == null || entry.key == widget.uid) continue;

        final deviceEntry = statusMap[assignedDeviceId];
        final isActivelyUsed = deviceEntry is Map &&
            Map<String, dynamic>.from(deviceEntry)['monitoringActive'] == true;
        if (isActivelyUsed) {
          assignedDeviceIds.add(assignedDeviceId);
        }
      }
    }

    final candidates = <String>[];
    for (final entry in statusMap.entries) {
      final deviceId = entry.key;
      if (!FirebasePaths.isValidDeviceId(deviceId)) continue;
      if (entry.value is! Map) continue;
      final deviceData = Map<String, dynamic>.from(entry.value as Map);
      final isOnline = deviceData['online'] == true;
      final isMonitoring = deviceData['monitoringActive'] == true;
      final linkedUserId = deviceData['linkedUserId']?.toString().trim() ?? '';

      if (!isOnline) continue;
      if (isMonitoring) continue;
      if (linkedUserId.isNotEmpty && linkedUserId != widget.uid) {
        final linkedUserEntry = usersSnap.exists && usersSnap.value is Map
            ? (usersSnap.value as Map)[linkedUserId]
            : null;
        if (linkedUserEntry is Map) {
          final linkedUserData = Map<String, dynamic>.from(linkedUserEntry);
          final linkedDevice = FirebasePaths.assignedDeviceId(linkedUserData);
          if (linkedDevice == deviceId) continue;
        }
      }
      if (assignedDeviceIds.contains(deviceId)) continue;

      candidates.add(deviceId);
    }

    candidates.sort();
    return candidates;
  }

  Future<void> _releaseDeviceFromOtherUsers(String deviceId) async {
    final usersSnap = await _dbRef.child('users').get();
    if (!usersSnap.exists || usersSnap.value is! Map) return;

    final usersMap = Map<String, dynamic>.from(usersSnap.value as Map);
    for (final entry in usersMap.entries) {
      if (entry.key == widget.uid || entry.value is! Map) continue;
      final userData = Map<String, dynamic>.from(entry.value as Map);
      if (FirebasePaths.assignedDeviceId(userData) == deviceId) {
        await _dbRef.child('users/${entry.key}').update({'deviceId': ''});
      }
    }
  }

  Future<bool> _isDeviceLinkedToAnotherUser(String deviceId) async {
    final statusSnap = await FirebasePaths.deviceStatusRef(_dbRef, deviceId).get();
    if (statusSnap.exists && statusSnap.value is Map) {
      final statusData = Map<String, dynamic>.from(statusSnap.value as Map);
      if (statusData['monitoringActive'] != true) {
        return false;
      }
    }

    final usersSnap = await _dbRef.child('users').get();
    if (!usersSnap.exists || usersSnap.value is! Map) {
      return false;
    }

    final usersMap = Map<String, dynamic>.from(usersSnap.value as Map);
    for (final entry in usersMap.entries) {
      if (entry.key == widget.uid || entry.value is! Map) {
        continue;
      }
      final userData = Map<String, dynamic>.from(entry.value as Map);
      final assigned = FirebasePaths.assignedDeviceId(userData);
      if (assigned == deviceId) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _canUseDevice(String deviceId) async {
    final statusSnap = await FirebasePaths.deviceStatusRef(
      _dbRef,
      deviceId,
    ).get();
    if (!statusSnap.exists || statusSnap.value is! Map) {
      return false;
    }

    final statusData = Map<String, dynamic>.from(statusSnap.value as Map);
    final online = statusData['online'] == true;
    final monitoringActive = statusData['monitoringActive'] == true;
    final linkedUserId = statusData['linkedUserId']?.toString().trim() ?? '';
    if (!online || monitoringActive) {
      return false;
    }
    if (linkedUserId.isNotEmpty && linkedUserId != widget.uid) {
      final usersSnap = await _dbRef.child('users/$linkedUserId').get();
      if (usersSnap.exists && usersSnap.value is Map) {
        final linkedUserData = Map<String, dynamic>.from(usersSnap.value as Map);
        final linkedDevice = FirebasePaths.assignedDeviceId(linkedUserData);
        if (linkedDevice == deviceId) {
          return false;
        }
      }
    }

    return !(await _isDeviceLinkedToAnotherUser(deviceId));
  }

  Future<String?> _selectDeviceId(List<String> deviceIds) async {
    if (!mounted) return null;
    final theme = Theme.of(context);
    String? selectedDeviceId = deviceIds.first;

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Select Device',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'More than one available device was found. Select the device you want to connect.',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...deviceIds.map((deviceId) {
                      final isSelected = selectedDeviceId == deviceId;
                      return RadioListTile<String>(
                        value: deviceId,
                        groupValue: selectedDeviceId,
                        dense: true,
                        activeColor: theme.colorScheme.primary,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          deviceId,
                          style: TextStyle(
                            color: isSelected
                                ? theme.colorScheme.onSurface
                                : theme.textTheme.bodyMedium?.color,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            selectedDeviceId = value;
                          });
                        },
                      );
                    }),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(selectedDeviceId),
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showConnectionDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    String? deviceId,
  }) async {
    if (!mounted) return;
    final theme = Theme.of(context);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color,
                  fontSize: 13,
                ),
              ),
              if (deviceId != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Connected Device",
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        deviceId,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleMonitoring(bool activate) async {
    if (_monitoringActionInProgress) return;
    setState(() {
      _monitoringActionInProgress = true;
      _monitoringPhase = activate ? 'checking' : 'stopping';
      _monitoringStatusMessage = activate
          ? 'Checking device readiness...'
          : 'Stopping monitoring...';
    });

    try {
      final userSnap = await _dbRef.child('users/${widget.uid}').get();
      String? deviceId;
      if (userSnap.exists && userSnap.value is Map) {
        deviceId = FirebasePaths.assignedDeviceId(
          Map<String, dynamic>.from(userSnap.value as Map),
        );
      }

      if (activate && deviceId != null) {
        final currentStatusSnap = await FirebasePaths.deviceStatusRef(
          _dbRef,
          deviceId,
        ).get();
        bool shouldReconnect = true;

        if (currentStatusSnap.exists && currentStatusSnap.value is Map) {
          final statusData = Map<String, dynamic>.from(
            currentStatusSnap.value as Map,
          );
          final isOnline = statusData['online'] == true;
          final linkedToAnotherUser = await _isDeviceLinkedToAnotherUser(
            deviceId,
          );
          shouldReconnect = !isOnline || linkedToAnotherUser;
        }

        if (shouldReconnect) {
          await _dbRef.child('users/${widget.uid}').update({'deviceId': ''});
          deviceId = null;
        }
      }

      if (activate && deviceId == null) {
        if (mounted) {
          setState(() {
            _monitoringPhase = 'connecting';
            _monitoringStatusMessage = 'Searching for an available device...';
          });
        }

        final availableDeviceIds = await _findAvailableDeviceIds();

        if (availableDeviceIds.isEmpty) {
          if (mounted) {
            setState(() {
              _monitoringPhase = 'failed';
              _monitoringStatusMessage = 'No available online device found.';
            });
          }
          await _showConnectionDialog(
            title: 'Connection Failed',
            message:
                'No available online device was found. Make sure the ESP32 is online and not linked to another user.',
            icon: Icons.portable_wifi_off_outlined,
            color: Theme.of(context).colorScheme.error,
          );
          return;
        }

        if (availableDeviceIds.length == 1) {
          deviceId = availableDeviceIds.first;
        } else {
          deviceId = await _selectDeviceId(availableDeviceIds);
          if (deviceId == null) {
            return;
          }
        }

        final canUseSelectedDevice = await _canUseDevice(deviceId);
        if (!canUseSelectedDevice) {
          if (mounted) {
            setState(() {
              _monitoringPhase = 'failed';
              _monitoringStatusMessage =
                  'Selected device is no longer available.';
            });
          }
          await _showConnectionDialog(
            title: 'Connection Failed',
            message:
                'The selected device is no longer available. Please try again.',
            icon: Icons.sync_problem_outlined,
            color: Theme.of(context).colorScheme.error,
          );
          return;
        }

        await _dbRef.child('users/${widget.uid}').update({
          'deviceId': deviceId,
        });
      }

      if (deviceId == null) {
        throw Exception('No device linked to this account');
      }

      if (activate) {
        await _releaseDeviceFromOtherUsers(deviceId);
      }

      if (mounted && activate) {
        setState(() {
          _monitoringPhase = 'connecting';
          _monitoringStatusMessage = 'Activating monitoring...';
        });
      }

      final deviceStatusUpdate = <String, dynamic>{
        'monitoringActive': activate,
        'lastSeen': ServerValue.timestamp,
      };
      if (activate) {
        deviceStatusUpdate['linkedUserId'] = widget.uid;
      } else {
        deviceStatusUpdate['linkedUserId'] = '';
      }

      await FirebasePaths.deviceStatusRef(
        _dbRef,
        deviceId,
      ).update(deviceStatusUpdate);

      if (!activate) {
        await _dbRef.child('users/${widget.uid}').update({'deviceId': ''});
        _detachLiveVitalsListener();
      }

      if (activate) {
        if (mounted) {
          setState(() {
            _monitoringStatusMessage = 'Waiting for first live reading...';
          });
        }
        final gotLiveReading = await _waitForFirstLiveReading(deviceId);
        if (!gotLiveReading) {
          await FirebasePaths.deviceStatusRef(_dbRef, deviceId).update({
            'monitoringActive': false,
            'linkedUserId': '',
            'lastSeen': ServerValue.timestamp,
          });
          await _dbRef.child('users/${widget.uid}').update({'deviceId': ''});
          _detachLiveVitalsListener();
          if (mounted) {
            setState(() {
              _monitoringPhase = 'failed';
              _monitoringStatusMessage =
                  'Connection timeout. No live data received.';
            });
          }
          await _showConnectionDialog(
            title: 'Connection Timeout',
            message:
                'The device was detected, but no live data was received in time. Please try again.',
            icon: Icons.timer_off_outlined,
            color: Theme.of(context).colorScheme.error,
          );
          return;
        }
        if (mounted) {
          setState(() {
            _monitoringPhase = 'active';
            _monitoringStatusMessage = 'Live monitoring is active.';
          });
        }
        await _showConnectionDialog(
          title: 'Device Connected',
          message:
              'Monitoring started successfully. The user is now linked to the detected device.',
          icon: Icons.check_circle_outline,
          color: AppSemanticColors.success,
          deviceId: deviceId,
        );
      } else if (mounted) {
        setState(() {
          _monitoringPhase = 'idle';
          _monitoringStatusMessage = 'Monitoring stopped.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Monitoring stopped. Device released for other patients.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _monitoringPhase = 'failed';
          _monitoringStatusMessage = 'Monitoring update failed. Please retry.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Monitoring update failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _monitoringActionInProgress = false;
        });
      } else {
        _monitoringActionInProgress = false;
      }
    }
  }

  Future<bool> _waitForFirstLiveReading(String deviceId) async {
    final startMillis = DateTime.now().millisecondsSinceEpoch;
    const timeout = Duration(seconds: 8);
    const pollInterval = Duration(milliseconds: 500);
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final snap = await FirebasePaths.userLiveVitalsRef(
        _dbRef,
        widget.uid,
        deviceId,
      ).get();
      if (snap.exists && snap.value is Map) {
        final live = Map<String, dynamic>.from(snap.value as Map);
        final ts = _parseInt(live['timestamp'], fallback: 0);
        if (ts > 0 && ts >= startMillis - 3000) {
          return true;
        }
      }
      await Future<void>.delayed(pollInterval);
    }
    return false;
  }

  void _checkAndSendAutoRecommendation(String stressLevel) async {
    final normalizedLevel = StressLevelUtils.normalize(stressLevel);
    if (!StressLevelUtils.isHigh(normalizedLevel)) {
      return;
    }

    if (_lastRecommendationTime != null &&
        DateTime.now().difference(_lastRecommendationTime!).inMinutes < 5) {
      return;
    }

    _lastRecommendationTime = DateTime.now();

    try {
      final recommendationSnap = await _dbRef
          .child('recommendations/$normalizedLevel')
          .get();
      String recommendationMessage = _recommendationFallback(normalizedLevel);

      if (recommendationSnap.exists && recommendationSnap.value is Map) {
        final recommendationData = Map<String, dynamic>.from(
          recommendationSnap.value as Map,
        );
        final text = recommendationData['text']?.toString().trim();
        if (text != null && text.isNotEmpty) {
          recommendationMessage = text;
        }
      }

      final recommendationRef = _dbRef
          .child('notifications/${widget.uid}')
          .push();
      await recommendationRef.set({
        'title': 'Automatic Stress Recommendation',
        'message': recommendationMessage,
        'timestamp': ServerValue.timestamp,
        'type': 'recommendation',
        'read': false,
        'patientName': 'You',
      });
    } catch (e) {
      debugPrint("Error sending auto recommendation: $e");
    }
  }

  void _showConsultationDialog(String doctorId, String patientName) {
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Send Consultation Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Write your consultation or question here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final message = messageController.text.trim();
                if (message.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter your consultation message.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                _sendConsultation(doctorId, patientName, message);
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendConsultation(
    String doctorId,
    String patientName,
    String message,
  ) async {
    if (doctorId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No assigned doctor found for consultation request.'),
          ),
        );
      }
      return;
    }

    try {
      final alertRef = _dbRef.child('doctor_dashboard/$doctorId/alerts').push();
      await alertRef.set({
        'uid': widget.uid,
        'patientName': patientName,
        'stressLevel': 'Consultation',
        'alertType': 'consultation',
        'message': message,
        'timestamp': ServerValue.timestamp,
        'seen': false,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Consultation request sent to your doctor.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request failed: ${e.toString()}')),
        );
      }
    }
  }
}
