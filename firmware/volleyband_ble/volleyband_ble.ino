// VolleyBand - Bluetooth firmware v2
// Reads the motion sensor 100 times a second and streams every reading
// to the laptop over Bluetooth. No cable needed.
//
// Board:   XIAO nRF52840 Sense (Seeed nRF52 mbed-enabled boards)
// Library: ArduinoBLE (Library Manager), Seeed Arduino LSM6DS3
//
// Upload once per board. Change DEVICE_NAME to "VolleyBand-ANKLE"
// before uploading to the second board.
//
// v2: readings are sent in small batches (up to 8 per message) once the
// laptop says how big a message it can take. Fewer, bigger messages stop the
// computer dropping readings when both pods are connected at once.
//
// LED:  blue blinking = waiting for the laptop
//       green solid   = connected and streaming
//       red solid     = motion sensor not found

#include <ArduinoBLE.h>
#include <LSM6DS3.h>
#include <Wire.h>

const char* DEVICE_NAME = "VolleyBand-ARM";

const unsigned long SAMPLE_US = 10000;   // 10 ms between readings = 100 Hz

LSM6DS3 imu(I2C_MODE, 0x6A);

// One Bluetooth message:
//   header:  seq of the first reading (2) | time of the first reading in ms (4)
//   then 1-8 readings, 13 bytes each:
//            ms since the header time (1) | ax ay az gx gy gz (2 each, raw counts)
// The laptop converts the raw counts: accel x 0.000488 = g, gyro x 0.07 = deg/s
const int MAX_BATCH = 8;
const int HEADER = 6;
const int PER_READING = 13;
const int MAX_MSG = HEADER + MAX_BATCH * PER_READING;   // 110 bytes

uint8_t msg[MAX_MSG];
int batch = 1;          // readings per message; the laptop raises it after connecting
int inMsg = 0;          // readings waiting in msg[]
uint32_t msgStartMs = 0;

BLEService vbService("7b1f0001-5e3a-4c8e-9d2a-6f1b2c3d4e5f");
BLECharacteristic dataChar("7b1f0002-5e3a-4c8e-9d2a-6f1b2c3d4e5f",
                           BLERead | BLENotify, MAX_MSG, false);
// the laptop writes how many readings per message it can take
BLEByteCharacteristic batchChar("7b1f0003-5e3a-4c8e-9d2a-6f1b2c3d4e5f",
                                BLERead | BLEWrite | BLEWriteWithoutResponse);

// The XIAO's LEDs turn ON when the pin is LOW
void led(bool r, bool g, bool b) {
  digitalWrite(LED_RED,   r ? LOW : HIGH);
  digitalWrite(LED_GREEN, g ? LOW : HIGH);
  digitalWrite(LED_BLUE,  b ? LOW : HIGH);
}

void setup() {
  pinMode(LED_RED, OUTPUT);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_BLUE, OUTPUT);
  led(false, false, false);

  Serial.begin(115200);   // only for debugging; the board never waits for it

  // 16 g and 2000 deg/s: the sensor's top ranges, so hard swings don't max out
  imu.settings.accelRange = 16;
  imu.settings.gyroRange = 2000;
  imu.settings.accelSampleRate = 416;
  imu.settings.gyroSampleRate = 416;
  if (imu.begin() != 0) {
    led(true, false, false);
    while (true) {}
  }
  Wire.setClock(400000);  // faster sensor reads

  if (!BLE.begin()) {
    led(true, false, false);
    while (true) {}
  }
  BLE.setLocalName(DEVICE_NAME);
  BLE.setDeviceName(DEVICE_NAME);
  BLE.setConnectionInterval(6, 12);   // ask for 7.5-15 ms between radio exchanges
  BLE.setAdvertisedService(vbService);
  vbService.addCharacteristic(dataChar);
  vbService.addCharacteristic(batchChar);
  batchChar.writeValue(1);
  BLE.addService(vbService);
  BLE.advertise();
}

void put16(uint8_t* p, int16_t v) { memcpy(p, &v, 2); }

void sendMsg() {
  if (inMsg == 0) return;
  dataChar.writeValue(msg, HEADER + inMsg * PER_READING);
  inMsg = 0;
}

void stream(BLEDevice& central) {
  uint16_t seq = 0;
  unsigned long next = micros();
  batch = 1;
  inMsg = 0;
  batchChar.writeValue(1);
  led(false, true, false);

  while (central.connected()) {          // connected() also services the radio
    if ((long)(micros() - next) < 0) continue;
    next += SAMPLE_US;
    // if the radio held us up, don't burst to catch up: just carry on
    if ((long)(micros() - next) > (long)(5 * SAMPLE_US)) next = micros() + SAMPLE_US;

    // the laptop asked for a different batch size: send what we have, switch
    if (batchChar.written()) {
      sendMsg();
      batch = constrain((int)batchChar.value(), 1, MAX_BATCH);
    }

    uint32_t now = millis();
    if (inMsg == 0) {                       // start a new message
      msgStartMs = now;
      memcpy(&msg[0], &seq, 2);
      memcpy(&msg[2], &msgStartMs, 4);
    }
    uint8_t* p = &msg[HEADER + inMsg * PER_READING];
    p[0] = (uint8_t)min((uint32_t)255, now - msgStartMs);
    put16(p + 1,  imu.readRawAccelX());
    put16(p + 3,  imu.readRawAccelY());
    put16(p + 5,  imu.readRawAccelZ());
    put16(p + 7,  imu.readRawGyroX());
    put16(p + 9,  imu.readRawGyroY());
    put16(p + 11, imu.readRawGyroZ());
    seq++;
    inMsg++;
    if (inMsg >= batch) sendMsg();
  }

  led(false, false, false);
  BLE.advertise();                        // be ready for the next connection
}

void loop() {
  BLEDevice central = BLE.central();
  if (central) {
    stream(central);
    return;
  }
  // waiting: short blue blink every second
  led(false, false, (millis() % 1000) < 80);
}
