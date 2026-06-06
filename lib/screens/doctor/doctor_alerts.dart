import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../main.dart';
import '../../design_system.dart';
import '../../services/stress_level_utils.dart';

class DoctorAlertsScreen extends StatefulWidget {
  final String doctorId;
  const DoctorAlertsScreen({super.key, required this.doctorId});

  @override
  State<DoctorAlertsScreen> createState() => _DoctorAlertsScreenState();
}

class _DoctorAlertsScreenState extends State<DoctorAlertsScreen> {
  final DatabaseReference _dbRef = globalDatabaseRef!;
  String _selectedFilter = "All";

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: _dbRef.child('doctors/${widget.doctorId}/settings').onValue,
      builder: (context, settingsSnapshot) {
        bool stressAlertsEnabled = true;
        if (settingsSnapshot.hasData && settingsSnapshot.data!.snapshot.value != null) {
          var settings = Map<String, dynamic>.from(settingsSnapshot.data!.snapshot.value as Map);
          stressAlertsEnabled = settings['patient_stress_alerts_enabled'] ?? true;
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
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: StreamBuilder<DatabaseEvent>(
                      stream: _dbRef
                          .child('doctor_dashboard/${widget.doctorId}/alerts')
                          .orderByChild('seen')
                          .equalTo(false)
                          .onValue,
                      builder: (context, snapshot) {
                        int unreadCount = 0;
                        if (snapshot.hasData &&
                            snapshot.data!.snapshot.value != null) {
                          unreadCount =
                              (snapshot.data!.snapshot.value as Map).length;
                        }
                        if (!stressAlertsEnabled) unreadCount = 0;
                        return AppScreenHeader(
                          title: 'Alerts',
                          subtitle: stressAlertsEnabled
                              ? '$unreadCount unread notifications'
                              : 'Patient alert notifications are disabled',
                        );
                      },
                    ),
                  ),
                  if (stressAlertsEnabled)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _markAllAsRead,
                          icon: Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          label: Text(
                            'Mark all read',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
              if (!stressAlertsEnabled)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text("Patient stress alerts are disabled in your settings. Enable them to receive new alerts.", style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, height: 1.4))),
                    ],
                  ),
                ),
              _buildFilters(),
              Expanded(child: _buildAlertsList(stressAlertsEnabled)),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildFilters() => StreamBuilder<DatabaseEvent>(
    stream: _dbRef.child('doctor_dashboard/${widget.doctorId}/alerts').orderByChild('seen').equalTo(false).onValue,
    builder: (context, snapshot) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      int unreadCount = 0;
      if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
        unreadCount = (snapshot.data!.snapshot.value as Map).length;
      }
      
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: ['All', 'Unread', 'Critical'].map((filter) {
            bool isSelected = _selectedFilter == filter;
            return GestureDetector(
              onTap: () => setState(() => _selectedFilter = filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? scheme.primary : theme.cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.75),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : AppChrome.cardShadow(context, opacity: 0.03),
                ),
                child: Row(
                  children: [
                    Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? scheme.onPrimary : scheme.onSurface.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    if (filter == 'Unread' && unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppSemanticColors.stressHigh,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      );
    }
  );

  Widget _buildAlertsList(bool alertsEnabled) {
    if (!alertsEnabled) {
      return const Center(child: Text("Patient alerts are disabled. Enable them in profile to view alerts."));
    }

    return StreamBuilder<DatabaseEvent>(
      stream: _dbRef.child('doctor_dashboard/${widget.doctorId}/alerts').onValue,
      builder: (context, snapshot) {
        final theme = Theme.of(context);
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return const Center(child: Text("No alerts found"));

        Map alertsMap = snapshot.data!.snapshot.value as Map;
        var entries = alertsMap.entries.toList();
        
        var filteredList = entries.where((entry) {
          var data = Map<String, dynamic>.from(entry.value as Map);
          if (_selectedFilter == "Unread") return data['seen'] == false;
          if (_selectedFilter == "Critical") return _isCriticalAlert(data);
          return true;
        }).toList();

        filteredList.sort((a, b) {
          final bTs = _parseTimestamp((b.value as Map)['timestamp']);
          final aTs = _parseTimestamp((a.value as Map)['timestamp']);
          return bTs.compareTo(aTs);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: filteredList.length,
          itemBuilder: (context, index) {
            var alertId = filteredList[index].key;
            var data = Map<String, dynamic>.from(filteredList[index].value as Map);
            bool isCritical = _isCriticalAlert(data);
            bool isConsultation = _isConsultationAlert(data);
            String patientName = data['patientName']?.toString() ?? 'Patient';
            String title;
            if (isConsultation) {
              title = "$patientName requested consultation";
            } else {
              title = "$patientName - ${StressLevelUtils.normalize(data['stressLevel'] ?? data['stresslevel'])} stress";
            }
            bool isNew = data['seen'] == false;
            Color accentColor = isCritical ? Colors.red : (isConsultation ? Colors.blue : Colors.orange);
            IconData accentIcon = isCritical ? Icons.report_problem_outlined : (isConsultation ? Icons.chat_bubble_outline : Icons.local_fire_department);
            
            return InkWell(
              onTap: () => _showAlertDetails(alertId, data),
              child: Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border(left: BorderSide(color: accentColor, width: 4)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: accentColor.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(accentIcon, color: accentColor, size: 20),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          if (data['message'] != null) Text(data['message'], style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          const SizedBox(height: 6),
                          Text(_getTimeAgo(data['timestamp']), style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isNew) Icon(Icons.circle, color: theme.colorScheme.primary, size: 8),
                        const SizedBox(height: 8),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 22),
                          onPressed: () => _deleteAlert(alertId),
                          tooltip: 'Delete alert',
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: theme.textTheme.bodySmall?.color, size: 18),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getTimeAgo(dynamic timestamp) {
    final ts = _parseTimestamp(timestamp);
    if (ts <= 0) return "Unknown time";
    DateTime date = DateTime.fromMillisecondsSinceEpoch(ts);
    Duration diff = DateTime.now().difference(date);
    if (diff.isNegative) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  bool _isCriticalAlert(Map<String, dynamic> data) {
    String alertType = data['alertType']?.toString().trim().toLowerCase() ?? '';
    final stressLevel = StressLevelUtils.normalize(
      data['stressLevel'] ?? data['stresslevel'],
    );
    if (alertType == 'manual_sos' || alertType == 'consultation') return false;
    return stressLevel == 'High' || alertType == 'auto_stress';
  }

  bool _isConsultationAlert(Map<String, dynamic> data) {
    String alertType = data['alertType']?.toString().trim().toLowerCase() ?? '';
    return alertType == 'consultation' || alertType == 'manual_sos';
  }

  Future<void> _markAllAsRead() async {
    DataSnapshot snapshot = await _dbRef.child('doctor_dashboard/${widget.doctorId}/alerts').orderByChild('seen').equalTo(false).get();
    if (snapshot.exists) {
      Map<dynamic, dynamic> alerts = snapshot.value as Map;
      for (var key in alerts.keys) {
        await _dbRef.child('doctor_dashboard/${widget.doctorId}/alerts/$key').update({'seen': true});
      }
    }
  }

  Future<void> _deleteAlert(String id) async {
    await _dbRef.child('doctor_dashboard/${widget.doctorId}/alerts/$id').remove();
  }

  Future<void> _showAlertDetails(String id, Map<String, dynamic> data) async {
    if (data['seen'] == false) {
      await _markAsRead(id);
    }

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    String alertType = data['alertType']?.toString() ?? 'alert';
    final normalizedAlertType = alertType.replaceAll('_', ' ').toUpperCase();
    String title = alertType == 'manual_sos' || alertType == 'consultation'
        ? '${data['patientName'] ?? 'Patient'} requested consultation'
        : '${data['patientName'] ?? 'Patient'} - ${StressLevelUtils.normalize(data['stressLevel'] ?? data['stresslevel'])} stress';
    String message = data['message']?.toString() ?? 'No details provided.';
    final dateParts = _formatTimestampParts(data['timestamp']);
    final accentColor = _isConsultationAlert(data)
        ? Colors.blue
        : (_isCriticalAlert(data) ? Colors.red : Colors.orange);
    final accentIcon = _isConsultationAlert(data)
        ? Icons.chat_bubble_outline
        : (_isCriticalAlert(data)
            ? Icons.warning_amber_rounded
            : Icons.notifications_active_outlined);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(accentIcon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        normalizedAlertType,
                        style: textTheme.labelSmall?.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailCard(
                theme,
                icon: Icons.person_outline,
                label: 'Patient',
                value: data['patientName']?.toString() ?? 'Unknown',
                fullWidth: true,
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Message',
                      style: textTheme.labelSmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _detailCard(
                      theme,
                      icon: Icons.calendar_today_outlined,
                      label: 'Date',
                      value: dateParts.$1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _detailCard(
                      theme,
                      icon: Icons.schedule_outlined,
                      label: 'Time',
                      value: dateParts.$2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                await _deleteAlert(id);
                if (mounted) Navigator.pop(context);
              },
              child: Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _markAsRead(String id) async {
    await _dbRef.child('doctor_dashboard/${widget.doctorId}/alerts/$id').update({'seen': true});
  }

  Widget _detailCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (String, String) _formatTimestampParts(dynamic timestamp) {
    final ts = _parseTimestamp(timestamp);
    if (ts <= 0) return ('Unknown date', 'Unknown time');
    DateTime date = DateTime.fromMillisecondsSinceEpoch(ts);
    final formattedDate =
        '${_monthName(date.month)} ${date.day}, ${date.year}';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final formattedTime = '$hour:$minute $period';
    return (formattedDate, formattedTime);
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  int _parseTimestamp(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }
}
