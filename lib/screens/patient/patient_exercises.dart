import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../main.dart';
import '../../design_system.dart';
import '../../services/firebase_paths.dart';
import '../../services/stress_level_utils.dart';

class ExerciseItem {
  const ExerciseItem(
    this.title,
    this.subtitle,
    this.time,
    this.seconds,
    this.icon,
    this.color,
    this.steps,
  );

  final String title;
  final String subtitle;
  final String time;
  final int seconds;
  final IconData icon;
  final Color color;
  final List<String> steps;
}

class ExerciseRecommendation {
  const ExerciseRecommendation({
    required this.title,
    required this.message,
    required this.exerciseTitle,
    required this.colorA,
    required this.colorB,
    required this.badge,
  });

  final String title;
  final String message;
  final String exerciseTitle;
  final Color colorA;
  final Color colorB;
  final String badge;
}

const _items = [
  ExerciseItem(
    '4-7-8 Breathing',
    'A calming breathing technique for anxiety relief',
    '5 min',
    300,
    Icons.air_rounded,
    Color(0xFF2F80ED),
    [
      'Inhale gently for 4 seconds',
      'Hold your breath for 7 seconds',
      'Exhale slowly for 8 seconds',
    ],
  ),
  ExerciseItem(
    'Guided Meditation',
    'Mindful relaxation for stress relief',
    '10 min',
    600,
    Icons.self_improvement_rounded,
    Color(0xFF8E63D2),
    [
      'Sit comfortably',
      'Observe your breathing',
      'Let thoughts pass without judgment',
      'Return attention to the present moment',
    ],
  ),
  ExerciseItem(
    'Body Scan',
    'Progressive physical relaxation',
    '8 min',
    480,
    Icons.accessibility_new_rounded,
    Color(0xFF4D7CFE),
    [
      'Relax the forehead and jaw',
      'Release the shoulders and chest',
      'Relax the stomach and hips',
      'Soften the legs and feet',
    ],
  ),
  ExerciseItem(
    'Quick Calm',
    'One minute stress reset',
    '1 min',
    60,
    Icons.flash_on_rounded,
    Color(0xFF2F9E44),
    [
      'Pause where you are',
      'Take one deep breath',
      'Drop your shoulders',
      'Focus on one thing you can feel',
    ],
  ),
];

class PatientExercisesScreen extends StatelessWidget {
  const PatientExercisesScreen({super.key, required this.uid});

  final String uid;

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
                  title: 'Stress Relief',
                  subtitle: 'Interactive sessions for calmer recovery',
                ),
              ),
              Expanded(
                child: StreamBuilder<DatabaseEvent>(
        stream: globalDatabaseRef!.child('users/$uid').onValue,
        builder: (context, userSnap) {
          if (!userSnap.hasData || userSnap.data?.snapshot.value == null) {
            return _ExercisesBody(
              recommendation: _defaultRecommendation(),
            );
          }

          final userData = Map<String, dynamic>.from(
            userSnap.data!.snapshot.value as Map,
          );
          final deviceId = FirebasePaths.assignedDeviceId(userData);

          if (deviceId == null) {
            return _ExercisesBody(
              recommendation: _defaultRecommendation(),
            );
          }

          return StreamBuilder<DatabaseEvent>(
            stream: FirebasePaths.userLiveVitalsRef(
              globalDatabaseRef!,
              uid,
              deviceId,
            ).onValue,
            builder: (context, liveSnap) {
              if (!liveSnap.hasData || liveSnap.data?.snapshot.value == null) {
                return _ExercisesBody(
                  recommendation: _defaultRecommendation(),
                );
              }

              final liveData = Map<String, dynamic>.from(
                liveSnap.data!.snapshot.value as Map,
              );
              final stressLevel = StressLevelUtils.normalize(
                liveData['stressLevel'] ?? liveData['stresslevel'],
                stressScore: StressLevelUtils.scoreFrom(
                  liveData['stressScore'],
                  rawLevel: liveData['stressLevel'] ?? liveData['stresslevel'],
                ),
              );

              return StreamBuilder<DatabaseEvent>(
                stream: globalDatabaseRef!
                    .child('recommendations/$stressLevel')
                    .onValue,
                builder: (context, recommendationSnap) {
                  String recommendationMessage = _recommendationFallback(
                    stressLevel,
                  );
                  if (recommendationSnap.hasData &&
                      recommendationSnap.data?.snapshot.value is Map) {
                    final data = Map<String, dynamic>.from(
                      recommendationSnap.data!.snapshot.value as Map,
                    );
                    final dbText = data['text']?.toString().trim() ?? '';
                    if (dbText.isNotEmpty) {
                      recommendationMessage = dbText;
                    }
                  }
                  return _ExercisesBody(
                    recommendation: _recommendationForStress(
                      stressLevel,
                      recommendationMessage,
                    ),
                  );
                },
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
}

class _ExercisesBody extends StatelessWidget {
  const _ExercisesBody({required this.recommendation});

  final ExerciseRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [recommendation.colorA, recommendation.colorB],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  recommendation.badge,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                recommendation.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                recommendation.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Suggested exercise: ${recommendation.exerciseTitle}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ..._items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Material(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ExerciseDetailsScreen(item: item),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(item.icon, color: item.color, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: item.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                item.time,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: item.color,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.28),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

ExerciseRecommendation _defaultRecommendation() {
  return const ExerciseRecommendation(
    title: 'No live stress reading is available yet.',
    message: 'This account is not currently linked to an active device, so a general calming exercise is recommended for now.',
    exerciseTitle: 'Quick Calm',
    colorA: Color(0xFF2F9E44),
    colorB: Color(0xFF56C271),
    badge: 'Default Recommendation',
  );
}

ExerciseRecommendation _recommendationForStress(
  String stressLevel,
  String message,
) {
  switch (StressLevelUtils.normalize(stressLevel)) {
    case 'High':
      return ExerciseRecommendation(
        title: 'High stress detected. Start with slow breathing now.',
        message: message,
        exerciseTitle: '4-7-8 Breathing',
        colorA: Color(0xFFD64545),
        colorB: Color(0xFFF08A5D),
        badge: 'High Stress',
      );
    case 'Medium':
      return ExerciseRecommendation(
        title: 'Moderate stress detected. Try a guided reset.',
        message: message,
        exerciseTitle: 'Body Scan',
        colorA: Color(0xFFE49E2D),
        colorB: Color(0xFFF2C66D),
        badge: 'Medium Stress',
      );
    case 'Normal':
      return ExerciseRecommendation(
        title: 'Your stress level looks stable right now.',
        message: message,
        exerciseTitle: 'Guided Meditation',
        colorA: Color(0xFF2F80ED),
        colorB: Color(0xFF7CB8FF),
        badge: 'Normal Stress',
      );
    default:
      return _defaultRecommendation();
  }
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

class ExerciseDetailsScreen extends StatelessWidget {
  const ExerciseDetailsScreen({super.key, required this.item});

  final ExerciseItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(elevation: 0),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: item.color,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ExerciseSessionScreen(item: item),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start Session'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(item.icon, color: item.color, size: 30),
                ),
                const SizedBox(height: 18),
                Text(
                  item.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  item.time,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: item.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How It Works',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(item.steps.length, (i) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: i == item.steps.length - 1 ? 0 : 14,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: item.color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              item.steps[i],
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ExerciseSessionScreen extends StatefulWidget {
  const ExerciseSessionScreen({super.key, required this.item});

  final ExerciseItem item;

  @override
  State<ExerciseSessionScreen> createState() => _ExerciseSessionScreenState();
}

class _ExerciseSessionScreenState extends State<ExerciseSessionScreen> {
  Timer? _timer;
  late int _left;
  int _step = 0;
  bool _running = false;
  bool _expanded = true;
  static const _phases = [('Inhale', 4), ('Hold', 7), ('Exhale', 8)];
  int _phase = 0;
  int _phaseLeft = 4;

  @override
  void initState() {
    super.initState();
    _left = widget.item.seconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }

    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_left <= 1) {
        timer.cancel();
        setState(() {
          _left = 0;
          _running = false;
        });
        _done();
        return;
      }

      setState(() {
        _left--;
        if (widget.item.title == '4-7-8 Breathing') {
          _phaseLeft--;
          if (_phaseLeft <= 0) {
            _phase = (_phase + 1) % _phases.length;
            _phaseLeft = _phases[_phase].$2;
            _expanded = _phase != 2;
          }
          _step = _phase.clamp(0, widget.item.steps.length - 1);
        } else {
          final per = (widget.item.seconds / widget.item.steps.length).ceil();
          _step = ((widget.item.seconds - _left) / per)
              .floor()
              .clamp(0, widget.item.steps.length - 1);
        }
      });
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _left = widget.item.seconds;
      _step = 0;
      _running = false;
      _phase = 0;
      _phaseLeft = 4;
      _expanded = true;
    });
  }

  Future<void> _done() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Session Completed'),
        content: Text(
          'You completed ${widget.item.title.toLowerCase()}. Take a moment to notice how your body feels now.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _reset();
            },
            child: const Text('Repeat'),
          ),
        ],
      ),
    );
  }

  String get _clock =>
      '${(_left ~/ 60).toString().padLeft(2, '0')}:${(_left % 60).toString().padLeft(2, '0')}';

  String get _currentHeadline {
    if (widget.item.title == '4-7-8 Breathing') {
      return _phases[_phase].$1;
    }
    return 'Step ${_step + 1}';
  }

  String get _currentSupportingText {
    if (widget.item.title == '4-7-8 Breathing') {
      return '${_phaseLeft}s in this phase';
    }
    return widget.item.steps[_step];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = 1 - (_left / widget.item.seconds);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          widget.item.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  colors: [widget.item.color, Color.lerp(widget.item.color, Colors.black, 0.16)!],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(widget.item.icon, color: Colors.white),
                      const Spacer(),
                      Text(
                        _clock,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.item.subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Guidance',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeInOut,
                          width: widget.item.title == '4-7-8 Breathing'
                              ? (_expanded ? 230 : 190)
                              : 210,
                          height: widget.item.title == '4-7-8 Breathing'
                              ? (_expanded ? 230 : 190)
                              : 210,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.item.color,
                            boxShadow: [
                              BoxShadow(
                                color: widget.item.color.withValues(alpha: 0.25),
                                blurRadius: 26,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Text(
                                  _currentHeadline,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _clock,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  widget.item.title == '4-7-8 Breathing'
                                      ? _currentSupportingText
                                      : 'Follow the current step calmly',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: widget.item.color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.item.title == '4-7-8 Breathing'
                                  ? 'Breathing pattern'
                                  : 'Current step',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: widget.item.color,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _currentSupportingText,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      ...List.generate(widget.item.steps.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                i < _step
                                    ? Icons.check_circle
                                    : i == _step
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                color: i <= _step
                                    ? widget.item.color
                                    : theme.dividerColor,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.item.steps[i],
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: i == _step
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (widget.item.title == '4-7-8 Breathing') ...[
                        const SizedBox(height: 8),
                        Text(
                          'Pattern: 4 • 7 • 8',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: widget.item.color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.item.color,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _toggle,
                    icon: Icon(
                      _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      _running ? 'Pause Session' : 'Start Session',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
