import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

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
  final String clientId =
      'flutter_air_client_${DateTime.now().millisecondsSinceEpoch}';

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

  // ================= LOGIK STATUS KOMPREHENSIF =================

  Color getMainColor() {
    if (pm25 == 0 && mq135 == 0) return Colors.grey; // Warna netral saat memuat
    if (pm25 > 55 || mq135 > 2000) return Colors.red;
    if (pm25 > 35 || mq135 > 1000) return Colors.orange;
    if (pm25 > 12 || mq135 > 500) return Colors.blue;
    return Colors.green;
  }

  String getMainStatus() {
    if (pm25 == 0 && mq135 == 0) return "MENUNGGU DATA...";
    if (mq135 > 2000) return "GAS BERBAHAYA!";
    if (pm25 > 55) return "POLUSI SANGAT TINGGI";
    if (mq135 > 1000) return "UDARA TERCEMAR GAS";
    if (pm25 > 35) return "KUALITAS UDARA BURUK";
    if (pm25 > 12 || mq135 > 500) return "KUALITAS SEDANG";
    return "UDARA BERSIH & AMAN";
  }

  String getDetailedAdvice() {
    if (pm25 == 0 && mq135 == 0) {
      return "Sedang sinkronisasi dengan sensor ESP32...";
    }

    String levelGas;
    if (mq135 <= 500) {
      levelGas = "Aman";
    } else if (mq135 <= 1000) {
      levelGas = "Normal";
    } else if (mq135 <= 2000) {
      levelGas = "Waspada";
    } else {
      levelGas = "Bahaya";
    }

    bool isUnhealthy = mq135 > 1000 || pm25 > 35;

    return isUnhealthy
        ? "Level: $levelGas. Segera buka ventilasi atau gunakan pemurni udara."
        : "Level: $levelGas. Lingkungan Anda dalam kondisi yang baik.";
  }

  // ================= UI WIDGETS =================

  Widget buildSummaryCard() {
    Color mainColor = getMainColor();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [mainColor, mainColor.withValues(alpha: .8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: mainColor.withValues(alpha: .3),
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
                "RINGKASAN KONDISI",
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Icon(
                mq135 > 1000 || pm25 > 35
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
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
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .15),
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
        border: Border.all(color: color.withValues(alpha: .1), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .02), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 40),
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
              fontSize: value == "Memuat..." ? 12 : 15,
              fontWeight: FontWeight.bold,
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
                  style: TextStyle(
                    fontSize: value == "Memuat..." ? 14 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
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
        title: const Text(
          "Air Quality Monitor",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
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
                    pm10 == 0 ? "Memuat..." : pm10.toStringAsFixed(1),
                    Colors.teal,
                    Icons.grain,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: buildPmCard(
                    "PM 2.5",
                    pm25 == 0 ? "Memuat..." : pm25.toStringAsFixed(1),
                    Colors.orange,
                    Icons.blur_on,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: buildPmCard(
                    "PM 10.0",
                    pm100 == 0 ? "Memuat..." : pm100.toStringAsFixed(1),
                    Colors.blueGrey,
                    Icons.cloud,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            const Text(
              "Detail Sensor",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            buildWideCard(
              title: "Kualitas Gas",
              value: "$mq135 PPM",
              status: mq135 > 1000 ? "POLUSI" : "AMAN",
              color: Colors.purple,
              icon: Icons.gas_meter_outlined,
            ),
            buildWideCard(
              title: "Suhu Udara",
              value: temperature == 0 ? "Memuat..." : "$temperature °C",
              status: temperature == 0
                  ? "MENUNGGU"
                  : (temperature > 30 ? "PANAS" : "NYAMAN"),
              color: Colors.deepOrange,
              icon: Icons.thermostat_outlined,
            ),
            buildWideCard(
              title: "Kelembapan",
              value: humidity == 0 ? "Memuat..." : "$humidity %",
              status: humidity == 0
                  ? "MENUNGGU"
                  : (humidity > 70 ? "LEMBAP" : "NORMAL"),
              color: Colors.blueAccent,
              icon: Icons.water_drop_outlined,
            ),
          ],
        ),
      ),
    );
  }
}
