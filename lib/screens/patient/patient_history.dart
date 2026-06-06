import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../design_system.dart';
import '../../services/firebase_paths.dart';
import '../../services/stress_level_utils.dart';

class PatientHistoryScreen extends StatefulWidget {
  final String uid;
  const PatientHistoryScreen({super.key, required this.uid});

  @override
  State<PatientHistoryScreen> createState() => _PatientHistoryScreenState();
}

class _PatientHistoryScreenState extends State<PatientHistoryScreen> {
  final DatabaseReference _dbRef = globalDatabaseRef!;
  String _selectedPeriod = "Week";

  List<Map<String, dynamic>> _filterHistoryByPeriod(
    List<Map<String, dynamic>> history,
  ) {
    if (history.isEmpty) return history;

    final now = DateTime.now();
    DateTime cutoff;

    switch (_selectedPeriod) {
      case "Today":
        cutoff = DateTime(now.year, now.month, now.day);
        break;
      case "Month":
        cutoff = now.subtract(const Duration(days: 30));
        break;
      case "Week":
      default:
        cutoff = now.subtract(const Duration(days: 7));
        break;
    }

    return history.where((item) {
      final timestamp = item['timestamp'] as int? ?? 0;
      if (timestamp <= 0) return false;
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return !date.isBefore(cutoff);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
                  title: 'Stress History',
                  subtitle: 'Track your stress patterns',
                ),
              ),
              Expanded(
                child: StreamBuilder<DatabaseEvent>(
          stream: _dbRef.child('users/${widget.uid}').onValue,
          builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userSnapshot.hasData || userSnapshot.data!.snapshot.value == null) {
            return const Center(child: Text('User data not found'));
          }

            return StreamBuilder<DatabaseEvent>(
              stream: FirebasePaths.userHistoryRef(_dbRef, widget.uid).onValue,
              builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var history = <Map<String, dynamic>>[];
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            var rawData = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
            history = rawData.entries.map((entry) {
              var data = Map<String, dynamic>.from(entry.value as Map);
              int timestamp = data['timestamp'] is int ? data['timestamp'] : int.tryParse(data['timestamp']?.toString() ?? '0') ?? 0;
              final level = StressLevelUtils.normalize(
                data['stressLevel'] ?? data['stresslevel'],
              );
              final score = StressLevelUtils.scoreFrom(
                data['stressScore'],
                rawLevel: level,
              );
              return {
                'timestamp': timestamp,
                'stressScore': score,
                'stressLevel': level,
              };
            }).toList();
          }

          history.sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));
          final filteredHistory = _filterHistoryByPeriod(history);
          final bool hasHistory = filteredHistory.isNotEmpty;
          final List<Map<String, dynamic>> historyForChart = hasHistory
              ? filteredHistory
              : [
                  {
                    'timestamp': DateTime.now().millisecondsSinceEpoch,
                    'stressScore': 0.0,
                    'stressLevel': 'Normal',
                  }
                ];

          List<FlSpot> spots = historyForChart.asMap().entries.map((entry) {
            return FlSpot(entry.key.toDouble(), (entry.value['stressScore'] as double).clamp(0, 100));
          }).toList();

          double averageStress = hasHistory
              ? filteredHistory.fold(0.0, (sum, item) => sum + (item['stressScore'] as double)) / filteredHistory.length
              : 0.0;
          double peakStress = hasHistory
              ? filteredHistory.fold(0.0, (maxValue, item) {
                  double current = item['stressScore'] as double;
                  return maxValue > current ? maxValue : current;
                })
              : 0.0;
          int normalCount = hasHistory ? filteredHistory.where((e) => e['stressLevel'] == 'Normal').length : 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                if (!hasHistory)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
                        ),
                        boxShadow: AppChrome.cardShadow(context, opacity: 0.04),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No history yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "The layout is shown with zero values. Your device data will appear here once available.",
                            style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                _buildPeriodSelector(theme),
                const SizedBox(height: 25),
                _buildChartSection(theme, spots, historyForChart),
                const SizedBox(height: 30),
                _buildStatsGrid(theme, averageStress, peakStress, hasHistory ? filteredHistory.length : 0, normalCount),
                const SizedBox(height: 30),
              ],
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

  Widget _buildPeriodSelector(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.65)),
        boxShadow: AppChrome.cardShadow(context, opacity: 0.035),
      ),
      child: Row(
        children: ['Today', 'Week', 'Month'].map((period) {
          bool isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? scheme.primary : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : scheme.outline.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? scheme.onPrimary : scheme.onSurface.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChartSection(ThemeData theme, List<FlSpot> spots, List<Map<String, dynamic>> history) {
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.65)),
        boxShadow: AppChrome.cardShadow(context, opacity: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STRESS TREND',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 25),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, meta) {
                    int index = val.toInt();
                    if (index >= 0 && index < history.length) {
                      String label = DateFormat('MMM d').format(DateTime.fromMillisecondsSinceEpoch(history[index]['timestamp'] as int));
                      return Text(label, style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 10));
                    }
                    return const Text("");
                  })),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: theme.colorScheme.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.2),
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(ThemeData theme, double averageStress, double peakStress, int eventCount, int calmCount) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.4,
      children: [
        _statCard(theme, 'Average', '${averageStress.toStringAsFixed(0)}%', 'Stress level', Icons.trending_down, AppSemanticColors.success),
        _statCard(theme, 'Peak', '${peakStress.toStringAsFixed(0)}%', 'Highest value', Icons.trending_up, AppSemanticColors.stressHigh),
        _statCard(theme, 'Normal Readings', '$calmCount', 'Healthy entries', Icons.access_time, AppSemanticColors.info),
        _statCard(theme, 'Events', '$eventCount', 'Recorded values', Icons.local_fire_department, AppSemanticColors.stressMedium),
      ],
    );
  }

  Widget _statCard(ThemeData theme, String label, String val, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: AppChrome.cardShadow(context, opacity: 0.035),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color.withValues(alpha: 0.75)),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const Spacer(),
          Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
          Text(sub, style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 10)),
        ],
      ),
    );
  }

}
