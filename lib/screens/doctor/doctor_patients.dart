import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../main.dart';
import '../../design_system.dart';
import '../../services/firebase_paths.dart';
import '../../services/stress_level_utils.dart';

class DoctorPatientsScreen extends StatefulWidget {
  final String doctorId;
  const DoctorPatientsScreen({super.key, required this.doctorId});

  @override
  State<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final DatabaseReference dbRef = globalDatabaseRef!;

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
                  title: 'My Patients',
                  subtitle: 'Active monitoring list',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _buildSearchBar(theme),
              ),
            Expanded(
              child: StreamBuilder<DatabaseEvent>(
                stream: dbRef
                    .child('doctor_patients/${widget.doctorId}')
                    .onValue,
                builder: (context, snapshot) {
                  final query = _searchQuery.toLowerCase();
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData ||
                      snapshot.data!.snapshot.value == null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: theme.disabledColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No patients assigned yet",
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  Map patientsMap = snapshot.data!.snapshot.value as Map;
                  List patientIds = patientsMap.keys.toList();

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: patientIds.length,
                    itemBuilder: (context, index) {
                      String patientId = patientIds[index];
                      return StreamBuilder<DatabaseEvent>(
                        stream: dbRef.child('users/$patientId').onValue,
                        builder: (context, userSnap) {
                          if (!userSnap.hasData ||
                              userSnap.data!.snapshot.value == null)
                            return const SizedBox.shrink();
                          var data = Map<String, dynamic>.from(
                            userSnap.data!.snapshot.value as Map,
                          );
                          final name =
                              data['name']?.toString().toLowerCase() ?? '';
                          if (query.isNotEmpty && !name.contains(query)) {
                            return const SizedBox.shrink();
                          }
                          return _buildPatientCard(
                            context,
                            dbRef,
                            patientId,
                            data,
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

  Widget _buildSearchBar(ThemeData theme) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15),
    decoration: BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10),
      ],
    ),
    child: TextField(
      controller: _searchController,
      onChanged: (value) =>
          setState(() => _searchQuery = value.trim().toLowerCase()),
      decoration: const InputDecoration(
        icon: Icon(Icons.search, color: Colors.grey, size: 20),
        hintText: "Search by name...",
        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
        border: InputBorder.none,
      ),
    ),
  );

  Widget _buildPatientCard(
    BuildContext context,
    DatabaseReference dbRef,
    String patientId,
    Map data,
  ) {
    String name = data['name'] ?? "Unknown";
    final deviceId = FirebasePaths.assignedDeviceId(data);

    if (deviceId == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppDesign.avatarBackgroundColor(name),
              child: Text(
                AppDesign.avatarInitials(name),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    "No linked device",
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<DatabaseEvent>(
      stream: FirebasePaths.userLiveVitalsRef(
        dbRef,
        patientId,
        deviceId,
      ).onValue,
      builder: (context, liveSnap) {
        double? hr;
        double? gsr;
        String level = "Unknown";

        if (liveSnap.hasData && liveSnap.data!.snapshot.value != null) {
          var liveData = Map<String, dynamic>.from(
            liveSnap.data!.snapshot.value as Map,
          );
          hr = _parseDoubleNullable(liveData['heartRate']);
          gsr = _parseDoubleNullable(liveData['gsr']);
          level = StressLevelUtils.normalize(
            liveData['stressLevel'] ?? liveData['stresslevel'],
            stressScore: _parseDoubleNullable(liveData['stressScore']),
          );
        }

        Color statusColor = level == 'High'
            ? Colors.red
            : (level == 'Medium' ? Colors.orange : Colors.grey);

        return StreamBuilder<DatabaseEvent>(
          stream: FirebasePaths.deviceStatusRef(dbRef, deviceId).onValue,
          builder: (context, statusSnap) {
            bool isOnline = false;
            if (statusSnap.hasData && statusSnap.data!.snapshot.value != null) {
              var statusData = Map<String, dynamic>.from(
                statusSnap.data!.snapshot.value as Map,
              );
              isOnline = statusData['online'] == true;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: InkWell(
                onTap: () =>
                    _showPatientDetails(context, dbRef, patientId, data),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppDesign.avatarBackgroundColor(
                            name,
                          ),
                          child: Text(
                            AppDesign.avatarInitials(name),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    "Age: ${data['age'] ?? 'N/A'}",
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.color,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isOnline ? "Online" : "Offline",
                                    style: TextStyle(
                                      color: isOnline
                                          ? Colors.green
                                          : Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            level,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _miniStat(
                          Icons.favorite,
                          hr != null ? "${hr.toInt()}" : "N/A",
                          "BPM",
                          Colors.red,
                        ),
                        _miniStat(
                          Icons.show_chart,
                          gsr != null ? gsr.toStringAsFixed(1) : "N/A",
                          "μS",
                          Colors.teal,
                        ),
                        _miniStat(Icons.history, level, "Status", statusColor),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _miniStat(IconData icon, String val, String unit, Color color) => Row(
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 5),
      Text(
        val,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      const SizedBox(width: 2),
      Text(unit, style: const TextStyle(color: Colors.grey, fontSize: 10)),
    ],
  );

  double? _parseDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void _showPatientDetails(
    BuildContext context,
    DatabaseReference dbRef,
    String patientId,
    Map patientData,
  ) {
    final deviceId = FirebasePaths.assignedDeviceId(patientData);
    final TextEditingController recommendationController =
        TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final sheetTheme = Theme.of(context);
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: sheetTheme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.only(
            left: 25,
            right: 25,
            top: 25,
            bottom: MediaQuery.of(context).viewInsets.bottom + 25,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: const Color(0xFF4DB6AC),
                            child: Text(
                              patientData['name']?[0] ?? "P",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  patientData['name'] ?? "Unknown",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  "Patient ID: $patientId",
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.color,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        "LIVE VITALS",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 15),
                      if (deviceId != null)
                        StreamBuilder<DatabaseEvent>(
                          stream: FirebasePaths.userLiveVitalsRef(
                            dbRef,
                            patientId,
                            deviceId,
                          ).onValue,
                          builder: (context, snapshot) {
                            var live =
                                snapshot.hasData &&
                                    snapshot.data!.snapshot.value != null
                                ? Map<String, dynamic>.from(
                                    snapshot.data!.snapshot.value as Map,
                                  )
                                : {};
                            return Row(
                              children: [
                                Expanded(
                                  child: _vitalDetailCard(
                                    context,
                                    "Heart Rate",
                                    "${live['heartRate'] ?? 0}",
                                    "BPM",
                                    Icons.favorite,
                                    Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: _vitalDetailCard(
                                    context,
                                    "GSR Level",
                                    "${live['gsr'] ?? 0}",
                                    "μS",
                                    Icons.show_chart,
                                    Colors.teal,
                                  ),
                                ),
                              ],
                            );
                          },
                        )
                      else
                        Text(
                          "No linked device for this patient.",
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 25),
                      const Text(
                        "ADD MEDICAL RECOMMENDATION",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: recommendationController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: "Type your advice here...",
                          filled: true,
                          fillColor: Theme.of(context).dividerColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4DB6AC),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            if (recommendationController.text
                                .trim()
                                .isNotEmpty) {
                              String drName = "Unknown Doctor";
                              DataSnapshot docSnap = await dbRef
                                  .child('doctors/${widget.doctorId}')
                                  .get();
                              if (docSnap.exists) {
                                drName =
                                    (docSnap.value as Map)['name'] ?? drName;
                              }

                              await dbRef
                                  .child('notifications/$patientId')
                                  .push()
                                  .set({
                                    'title': 'Recommendation from Dr. $drName',
                                    'message': recommendationController.text
                                        .trim(),
                                    'timestamp': ServerValue.timestamp,
                                    'type': 'recommendation',
                                    'read': false,
                                  });
                              recommendationController.clear();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Recommendation sent successfully!",
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text(
                            "Send Recommendation",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        "PATIENT INFO",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 15),
                      _infoTile(
                        context,
                        Icons.cake_outlined,
                        "Age",
                        "${patientData['age'] ?? 'N/A'} years old",
                      ),
                      _infoTile(
                        context,
                        Icons.info_outline,
                        "Medical Status",
                        "${patientData['status'] ?? 'Unknown'}",
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D74FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Close Details",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _vitalDetailCard(
    BuildContext context,
    String title,
    String val,
    String unit,
    IconData icon,
    Color color,
  ) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: color.withOpacity(0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.1)),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 10),
        Text(
          val,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color,
            fontSize: 10,
          ),
        ),
      ],
    ),
  );

  Widget _infoTile(
    BuildContext context,
    IconData icon,
    String label,
    String val,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: Theme.of(context).iconTheme.color),
    title: Text(
      label,
      style: TextStyle(
        color: Theme.of(context).textTheme.bodySmall?.color,
        fontSize: 12,
      ),
    ),
    subtitle: Text(
      val,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}
