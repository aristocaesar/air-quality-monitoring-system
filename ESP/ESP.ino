#include <WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <WiFiManager.h>

// ================== MQTT DEFAULT =================
char mqtt_server[40] = "test.mosquitto.org";
char mqtt_port[6]    = "1883";
char mqtt_topic[50]  = "ESP32/AIR_QUALITY_MONITORING/raw";

// ================== DHT ==================
#define DHTPIN 4
#define DHTTYPE DHT11
DHT dht(DHTPIN, DHTTYPE);

// ================== MQ-135 ==================
#define MQ135_PIN 34

// ================== PMS5003 ==================
HardwareSerial pmsSerial(2);
#define PMS_RX 16
#define PMS_TX 17

// ================== DATA CACHE ==================
float lastTemp = 0.0;
float lastHum  = 0.0;
int   lastMQ   = 0;
struct PMSData {
  uint16_t pm1  = 0;
  uint16_t pm25 = 0;
  uint16_t pm10 = 0;
} lastPMS;

// ================== TIMING ==================
unsigned long lastPublish  = 0;
unsigned long lastPMSRead  = 0;
const unsigned long PUBLISH_INTERVAL = 5000;
const unsigned long PMS_INTERVAL     = 1000;

// ================== OBJECTS ==================
WiFiClient espClient;
PubSubClient client(espClient);

// ================== PMS READ FUNCTION ==================
bool readPMS() {
  static uint8_t buffer[32];
  static uint8_t idx = 0;

  while (pmsSerial.available()) {
    uint8_t c = pmsSerial.read();

    if (idx == 0 && c != 0x42) continue;
    if (idx == 1 && c != 0x4D) { 
      idx = 0; 
      continue; 
    }

    buffer[idx++] = c;

    if (idx == 32) {
      idx = 0;

      uint16_t sum = 0;
      for (int i = 0; i < 30; i++) sum += buffer[i];

      uint16_t checksum = (buffer[30] << 8) | buffer[31];

      if (sum != checksum) {
        Serial.println("PMS5003 checksum error!");
        return false;
      }

      lastPMS.pm1  = (buffer[10] << 8) | buffer[11];
      lastPMS.pm25 = (buffer[12] << 8) | buffer[13];
      lastPMS.pm10 = (buffer[14] << 8) | buffer[15];

      return true;
    }
  }
  return false;
}

// ================== MQTT RECONNECT ==================
void reconnectMQTT() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    String clientId = "ESP32-AQI-" + String(random(0xffff), HEX);

    if (client.connect(clientId.c_str())) {
      Serial.println("connected");
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" → try again in 5 seconds");
      delay(5000);
    }
  }
}

// ================== SETUP ==================
void setup() {
  Serial.begin(115200);
  delay(100);

  Serial.println("\nESP32 Air Quality Monitor - Starting...");

  dht.begin();
  pmsSerial.begin(9600, SERIAL_8N1, PMS_RX, PMS_TX);

  // ---------- WiFiManager ----------
  WiFiManager wm;
  WiFiManagerParameter custom_mqtt_server("server", "MQTT Broker", mqtt_server, 40);
  WiFiManagerParameter custom_mqtt_port("port", "Port", mqtt_port, 6);
  WiFiManagerParameter custom_mqtt_topic("topic", "MQTT Topic", mqtt_topic, 50);

  wm.addParameter(&custom_mqtt_server);
  wm.addParameter(&custom_mqtt_port);
  wm.addParameter(&custom_mqtt_topic);

  if (!wm.autoConnect("ESP32_AIR_QUALITY_SETUP")) {
    Serial.println("Failed to connect → timeout & restart");
    delay(3000);
    ESP.restart();
  }

  strcpy(mqtt_server, custom_mqtt_server.getValue());
  strcpy(mqtt_port, custom_mqtt_port.getValue());
  strcpy(mqtt_topic, custom_mqtt_topic.getValue());

  Serial.println("WiFi connected!");
  Serial.printf("MQTT Broker : %s:%s\n", mqtt_server, mqtt_port);
  Serial.printf("Topic       : %s\n", mqtt_topic);

  client.setServer(mqtt_server, atoi(mqtt_port));
  Serial.println("Air Quality Monitor READY\n");
}

// ================== LOOP ==================
void loop() {
  if (!client.connected()) {
    reconnectMQTT();
  }
  client.loop();

  if (millis() - lastPMSRead >= PMS_INTERVAL) {
    lastPMSRead = millis();
    readPMS();
  }

  if (millis() - lastPublish >= PUBLISH_INTERVAL) {
    lastPublish = millis();

    // Baca DHT
    float t = dht.readTemperature();
    float h = dht.readHumidity();

    if (!isnan(t) && t > -20 && t < 80) {
      lastTemp = t;
    }
    if (!isnan(h) && h >= 0 && h <= 100) {
      lastHum = h;
    }

    int mq = analogRead(MQ135_PIN);
    if (mq > 50) {
      lastMQ = mq;
    }

    String json = "{";
    json += "\"temp\":"  + String(lastTemp, 1) + ",";
    json += "\"humi\":"  + String(lastHum, 1)  + ",";
    json += "\"mq135\":" + String(lastMQ)      + ",";
    json += "\"pm1\":"   + String(lastPMS.pm1)  + ",";
    json += "\"pm25\":"  + String(lastPMS.pm25) + ",";
    json += "\"pm10\":"  + String(lastPMS.pm10);
    json += "}";

    if (client.publish(mqtt_topic, json.c_str())) {
      Serial.println("Published OK → " + String(mqtt_topic));
      Serial.println(json);
    } else {
      Serial.println("Publish FAILED!");
    }
  }
}
