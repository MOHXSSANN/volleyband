// VolleyBand - Step 2: motion sensor test
// Prints accelerometer (g) and gyroscope (deg/s) readings.
// Open Tools > Serial Plotter to see live graphs.

#include <LSM6DS3.h>
#include <Wire.h>

LSM6DS3 imu(I2C_MODE, 0x6A);  // built-in motion sensor on the XIAO Sense

void setup() {
  pinMode(LEDR, OUTPUT);
  pinMode(LEDG, OUTPUT);
  pinMode(LEDB, OUTPUT);
  digitalWrite(LEDR, HIGH);  // LEDs are on when LOW
  digitalWrite(LEDG, HIGH);
  digitalWrite(LEDB, HIGH);

  Serial.begin(115200);
  while (!Serial && millis() < 5000) {}  // wait up to 5 s for the laptop

  // Match the ranges from the research: 16 g and 2000 deg/s
  imu.settings.accelRange = 16;
  imu.settings.gyroRange = 2000;
  imu.settings.accelSampleRate = 416;
  imu.settings.gyroSampleRate = 416;

  if (imu.begin() != 0) {
    Serial.println("ERROR: motion sensor not found. Is this a Sense board?");
    while (true) {  // blink red forever
      digitalWrite(LEDR, !digitalRead(LEDR));
      delay(250);
    }
  }
  Serial.println("Motion sensor OK");
}

unsigned long lastPrint = 0;
unsigned long lastBlink = 0;

void loop() {
  unsigned long now = millis();

  // Blink blue once a second so you can see the board is running
  if (now - lastBlink >= 500) {
    lastBlink = now;
    digitalWrite(LEDB, !digitalRead(LEDB));
  }

  // Send 20 lines a second. The Arduino Serial Monitor can't keep up with more.
  if (now - lastPrint >= 50) {
    lastPrint = now;
    String line = "ax:" + String(imu.readFloatAccelX(), 2) +
                  ",ay:" + String(imu.readFloatAccelY(), 2) +
                  ",az:" + String(imu.readFloatAccelZ(), 2) +
                  ",gx:" + String(imu.readFloatGyroX(), 0) +
                  ",gy:" + String(imu.readFloatGyroY(), 0) +
                  ",gz:" + String(imu.readFloatGyroZ(), 0);
    if (Serial) Serial.println(line);  // only send when the laptop is listening
  }
}
