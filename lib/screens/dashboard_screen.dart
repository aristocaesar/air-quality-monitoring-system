import 'dart:convert';
import 'package:air_quality_monitoring/screens/history_screen.dart';
import 'package:air_quality_monitoring/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late MqttServerClient client;

  // ===== DATA SENSOR =====
  double pm10 = 0;
  double pm25 = 0;
  double pm100 = 0;
  double temperature = 0;
  double humidity = 0;
  int mq135 = 0;

  // ===== MQTT CONFIG =====
  final String broker = 'test.mosquitto.org';
  final String topic = 'ESP32/AIR_QUALITY_MONITORING/raw';
  final String clientId = 'air_quality_bg_client_dashboard';

  @override
  void initState() {
    super.initState();
    setupMqtt();
  }

  Future<void> setupMqtt() async {
    client = MqttServerClient(broker, clientId);
    client.port = 1883;
    client.keepAlivePeriod = 20;
    client.logging(on: false);

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);
    client.connectionMessage = connMessage;

    try {
      await client.connect();
    } catch (e) {
      debugPrint("MQTT Error: $e");
      client.disconnect();
    }

    client.subscribe(topic, MqttQos.atMostOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> events) {
      final MqttPublishMessage recMessage =
          events[0].payload as MqttPublishMessage;
      final String payload = MqttPublishPayload.bytesToStringAsString(
        recMessage.payload.message,
      );

      try {
        final data = jsonDecode(payload);
        setState(() {
          pm10 = (data['pm1'] ?? 0).toDouble();
          pm25 = (data['pm25'] ?? 0).toDouble();
          pm100 = (data['pm10'] ?? 0).toDouble();
          temperature = (data['temp'] ?? 0).toDouble();
          humidity = (data['humi'] ?? 0).toDouble();
          mq135 = (data['mq135'] ?? 0);
        });
      } catch (e) {
        debugPrint("JSON Error: $e");
      }
    });
  }

  // ================= STATUS =================

  Color getColorStatus(String type, double value) {
    if (value == 0) return Colors.grey;

    if (type == 'PM25') {
      if (value > 55) return Colors.red;
      if (value >= 16) return Colors.orange;
      return Colors.green;
    } else if (type == 'PM10') {
      if (value > 150) return Colors.red;
      if (value >= 51) return Colors.orange;
      return Colors.green;
    } else if (type == 'MQ135') {
      if (value > 2000) return Colors.red;
      if (value >= 1001) return Colors.orange;
      return Colors.green;
    }
    return Colors.blue;
  }

  String getLabelStatus(String type, double value) {
    if (value == 0) return "MEMUAT";

    if (type == 'PM25') {
      if (value > 55) return "TIDAK SEHAT";
      if (value >= 16) return "SEDANG";
      return "BAIK";
    } else if (type == 'PM10') {
      if (value > 150) return "TIDAK SEHAT";
      if (value >= 51) return "SEDANG";
      return "BAIK";
    } else if (type == 'MQ135') {
      if (value > 2000) return "TIDAK SEHAT";
      if (value >= 1001) return "SEDANG";
      return "BAIK";
    }
    return "NORMAL";
  }

  Color getMainColor() {
    if (pm25 == 0 && pm100 == 0 && mq135 == 0) return Colors.grey;
    if (pm25 > 55 || pm100 > 150 || mq135 > 2000) return Colors.red;
    if (pm25 >= 16 || pm100 >= 51 || mq135 >= 1001) return Colors.orange;
    return Colors.green;
  }

  String getMainStatus() {
    Color current = getMainColor();
    if (current == Colors.red) return "TIDAK SEHAT";
    if (current == Colors.orange) return "SEDANG";
    if (current == Colors.green) return "BAIK";
    return "MENUNGGU DATA...";
  }

  String getDetailedAdvice() {
    if (pm25 == 0 && mq135 == 0) return "Menghubungkan ke sensor ESP32...";

    Color current = getMainColor();
    if (current == Colors.red) {
      return "Kualitas udara buruk! Gunakan masker dan nyalakan pemurni udara.";
    } else if (current == Colors.orange) {
      return "Kualitas udara sedang. Batasi aktivitas luar bagi yang sensitif.";
    }
    return "Kualitas udara baik. Aman untuk beraktivitas normal.";
  }

  // ================= UI WIDGETS =================

  Widget buildSummaryCard() {
    Color mainColor = getMainColor();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [mainColor, mainColor.withAlpha(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: mainColor.withAlpha(80),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "STATUS KUALITAS UDARA",
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Icon(
                getMainStatus() == "BAIK"
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            getMainStatus(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              getDetailedAdvice(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPmCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: color.withAlpha(30), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 35),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const Text(
            "µg/m³",
            style: TextStyle(fontSize: 9, color: Colors.black38),
          ),
        ],
      ),
    );
  }

  Widget buildWideCard({
    required String title,
    required String value,
    required String status,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsetsGeometry.all(10),
          child: Text(
            "Air Quality Monitor",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          Padding(
            padding: EdgeInsetsGeometry.all(10),
            child: IconButton(
              icon: const Icon(Icons.history),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

                if (isLoggedIn) {
                  // Jika sudah login, langsung ke History
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HistoryScreen(),
                    ),
                  );
                } else {
                  // Jika belum, arahkan ke Login
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildSummaryCard(),
            const SizedBox(height: 25),
            const Text(
              "Particulate Matter",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: buildPmCard(
                    "PM 1.0",
                    pm10 == 0 ? "..." : pm10.toStringAsFixed(1),
                    Colors.teal,
                    Icons.grain,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: buildPmCard(
                    "PM 2.5",
                    pm25 == 0 ? "..." : pm25.toStringAsFixed(1),
                    getColorStatus('PM25', pm25),
                    Icons.blur_on,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: buildPmCard(
                    "PM 10.0",
                    pm100 == 0 ? "..." : pm100.toStringAsFixed(1),
                    getColorStatus('PM10', pm100),
                    Icons.cloud,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            const Text(
              "Detail Sensor & Gas",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            buildWideCard(
              title: "Konsentrasi Gas (CO2/MQ135)",
              value: "$mq135 PPM",
              status: getLabelStatus('MQ135', mq135.toDouble()),
              color: getColorStatus('MQ135', mq135.toDouble()),
              icon: Icons.gas_meter_outlined,
            ),
            buildWideCard(
              title: "Suhu Udara",
              value: temperature == 0 ? "Memuat..." : "$temperature °C",
              status: temperature > 30 ? "PANAS" : "NORMAL",
              color: temperature > 30 ? Colors.deepOrange : Colors.blue,
              icon: Icons.thermostat_outlined,
            ),
            buildWideCard(
              title: "Kelembapan",
              value: humidity == 0 ? "Memuat..." : "$humidity %",
              status: humidity > 70 ? "LEMBAP" : "NORMAL",
              color: Colors.blueAccent,
              icon: Icons.water_drop_outlined,
            ),
          ],
        ),
      ),
    );
  }
}
