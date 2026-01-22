import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:air_quality_monitoring/config/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/splash_screen.dart';

final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

/// ===============================
/// AIR QUALITY STATUS
/// ===============================
String getAirQualityStatus({
  required double pm25,
  required double pm10,
  required int mq135,
}) {
  if (pm25 == 0 && pm10 == 0 && mq135 == 0) {
    return 'MENUNGGU DATA...';
  }

  if (pm25 > 55 || pm10 > 150 || mq135 > 2000) {
    return 'TIDAK SEHAT';
  }

  if (pm25 >= 16 || pm10 >= 51 || mq135 >= 1001) {
    return 'SEDANG';
  }

  return 'BAIK';
}

bool shouldNotify(String status) {
  return status == 'TIDAK SEHAT';
}

/// ===============================
/// MQTT BACKGROUND SERVICE
/// ===============================
@pragma('vm:entry-point')
void mqttService(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'Air Quality Monitor',
      content: 'Monitoring Sedang Berjalan',
    );
  }

  final client = MqttServerClient(
    'test.mosquitto.org',
    'air_quality_bg_client_unique',
  );

  client
    ..port = 1883
    ..keepAlivePeriod = 30
    ..autoReconnect = true
    ..logging(on: false)
    ..onConnected = () {
      debugPrint('MQTT Background Connected');
      client.subscribe('ESP32/AIR_QUALITY_MONITORING/raw', MqttQos.atLeastOnce);
    }
    ..onDisconnected = () {
      debugPrint('MQTT Background Disconnected');
    }
    ..connectionMessage = MqttConnectMessage()
        .withClientIdentifier('air_quality_bg_client_unique')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

  try {
    await client.connect();
  } catch (e) {
    debugPrint('MQTT connection error: $e');
    client.disconnect();
    return;
  }

  client.updates?.listen((events) async {
    final recMessage = events.first.payload as MqttPublishMessage;
    final payload = MqttPublishPayload.bytesToStringAsString(
      recMessage.payload.message,
    );

    try {
      final data = jsonDecode(payload);
      final double pm1Val = (data['pm1'] ?? 0).toDouble();
      final double pm25Val = (data['pm25'] ?? 0).toDouble();
      final double pm10Val = (data['pm10'] ?? 0).toDouble();
      final int mq135Val = (data['mq135'] ?? 0);
      final double tempVal = (data['temp'] ?? 0).toDouble();
      final double humiVal = (data['humi'] ?? 0).toDouble();

      final status = getAirQualityStatus(
        pm25: pm25Val,
        pm10: pm10Val,
        mq135: mq135Val,
      );

      if (shouldNotify(status)) {
        await DatabaseHelper.instance.insertHistory({
          'pm1': pm1Val,
          'pm25': pm25Val,
          'pm10': pm10Val,
          'mq135': mq135Val,
          'temp': tempVal,
          'humi': humiVal,
          'status': status,
          'created_at': DateTime.now().toIso8601String(),
        });

        showAlertNotification(
          '⚠️ PERINGATAN: UDARA $status',
          "PM2.5: $pm25Val | PM10: $pm10Val | Gas: $mq135Val. Segera gunakan masker!",
        );
      }
    } catch (e) {
      debugPrint("Background JSON Error: $e");
    }
  });

  Timer.periodic(const Duration(seconds: 15), (_) {
    if (client.connectionStatus!.state != MqttConnectionState.connected) {
      debugPrint("Attempting to reconnect MQTT...");
    }
  });
}

/// ===============================
/// NOTIFICATION
/// ===============================
Future<void> showAlertNotification(String title, String body) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'air_quality_alert_channel',
    'Peringatan Kualitas Udara',
    channelDescription: 'Notifikasi saat udara tidak sehat',
    importance: Importance.max,
    priority: Priority.high,
    color: Colors.red,
    playSound: true,
  );

  const NotificationDetails details = NotificationDetails(
    android: androidDetails,
  );

  await notifications.show(1, title, body, details);
}

Future<void> requestNotificationPermission() async {
  await notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.requestNotificationsPermission();
}

/// ===============================
/// MAIN APP
/// ===============================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings = InitializationSettings(
    android: androidInit,
  );

  await notifications.initialize(initSettings);
  await requestNotificationPermission();

  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: mqttService,
      isForegroundMode: true,
      autoStart: true,
    ),
    iosConfiguration: IosConfiguration(
      onForeground: mqttService,
      onBackground: (_) async => false,
    ),
  );

  service.startService();

  await initializeDateFormatting('id_ID', null).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Air Quality Monitoring',
      theme: ThemeData(
        fontFamily: 'PlusJakartaSans',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const SplashScreen(),
    );
  }
}
