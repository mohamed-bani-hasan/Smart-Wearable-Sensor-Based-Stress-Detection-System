import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../main.dart';
import '../../design_system.dart';

class PatientNotificationsScreen extends StatefulWidget {
  final String uid;
  const PatientNotificationsScreen({super.key, required this.uid});

  @override
  State<PatientNotificationsScreen> createState() => _PatientNotificationsScreenState();
}

class _PatientNotificationsScreenState extends State<PatientNotificationsScreen> {
  // Use a getter or initialize in initState to safely access the global ref
  late final DatabaseReference _dbRef;

  @override
  void initState() {
    super.initState();
    _dbRef = globalDatabaseRef!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

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
                  title: 'Notifications',
                  subtitle: 'Stay updated with your health',
                ),
              ),
              Expanded(
                child: StreamBuilder<DatabaseEvent>(
        stream: _dbRef.child('notifications/${widget.uid}').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_outlined, size: 64, color: colorScheme.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text("No notifications yet", style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6))),
                ],
              ),
            );
          }

          Map itemsMap = snapshot.data!.snapshot.value as Map;
          var list = itemsMap.entries.toList()
            ..sort((a, b) {
              final bTs = _parseTimestamp((b.value as Map)['timestamp']);
              final aTs = _parseTimestamp((a.value as Map)['timestamp']);
              return bTs.compareTo(aTs);
            });

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            itemCount: list.length,
            itemBuilder: (context, index) {
              var entry = list[index];
              var data = Map<String, dynamic>.from(entry.value as Map);
              
              String type = data['type'] ?? 'info';
              bool isRecommendation = type == 'recommendation';
              String title = data['title'] ?? (isRecommendation ? "Doctor's Recommendation" : "Notification");
              String message = data['message'] ?? "";
              bool isRead = data['read'] ?? true;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: colorScheme.shadow.withValues(alpha: 0.02), blurRadius: 10)
                  ],
                  border: isRead ? null : Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _showNotificationDetails(entry.key, data),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isRecommendation ? colorScheme.secondaryContainer : colorScheme.primaryContainer,
                            shape: BoxShape.circle
                          ),
                          child: Icon(
                            isRecommendation ? Icons.medical_information_outlined : Icons.notifications_outlined,
                            color: isRecommendation ? colorScheme.onSecondaryContainer : colorScheme.onPrimaryContainer,
                            size: 20
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                              if (message.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(message, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.7))),
                                ),
                              const SizedBox(height: 6),
                              Text(_getTimeAgo(data['timestamp']), style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.5))),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!isRead)
                              Icon(Icons.circle, color: colorScheme.primary, size: 10),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 22),
                              onPressed: () => _deleteNotification(entry.key),
                              tooltip: "Delete notification",
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteNotification(String key) async {
    await _dbRef.child('notifications/${widget.uid}/$key').remove();
  }

  Future<void> _showNotificationDetails(String key, Map<String, dynamic> data) async {
    bool isRead = data['read'] ?? true;
    if (!isRead) {
      await _dbRef.child('notifications/${widget.uid}/$key/read').set(true);
    }

    String type = data['type'] ?? 'info';
    final normalizedType = type.replaceAll('_', ' ').toUpperCase();
    String title = data['title'] ?? (type == 'recommendation' ? "Doctor's Recommendation" : "Notification");
    String message = data['message'] ?? 'No additional details available.';
    final dateParts = _formatTimestampParts(data['timestamp']);

    if (!mounted) return;
    final theme = Theme.of(context);
    final accentColor = type == 'recommendation'
        ? theme.colorScheme.secondary
        : theme.colorScheme.primary;
    final accentIcon = type == 'recommendation'
        ? Icons.medical_information_outlined
        : Icons.notifications_active_outlined;

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
                  color: accentColor.withValues(alpha: 0.12),
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        normalizedType,
                        style: theme.textTheme.labelSmall?.copyWith(
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
                value: data['patientName']?.toString() ?? 'You',
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
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            TextButton(
              onPressed: () async {
                await _deleteNotification(key);
                if (mounted) Navigator.pop(context);
              },
              child: Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        );
      },
    );
  }

  Widget _detailCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
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

  int _parseTimestamp(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }
}
