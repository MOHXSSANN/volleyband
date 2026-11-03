# VolleyBand - types the Bluetooth firmware into Arduino IDE for filming.
#
# 1. Arduino IDE > File > New Sketch. Make the window big.
# 2. In PowerShell run:
#    powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\OneDrive\Desktop\VolleyBand_Bluetooth\film\type_firmware.ps1"
# 3. During the 10 s countdown click inside the editor and start recording.
#    Hands off the keyboard and mouse until it says Done.
# Optional: -Speed 1.5 types slower.
#
# Arduino IDE adds the indentation and closing brackets itself, so lines are
# typed without indentation and a line that starts with } is reached by moving
# down onto the } the editor already added.

param([double]$Speed = 1)

Add-Type -AssemblyName System.Windows.Forms
$rand = New-Object System.Random
$special = '+^%~(){}[]'

function Key([string]$k) {
    [System.Windows.Forms.SendKeys]::SendWait($k)
    Start-Sleep -Milliseconds ([int](70 * $Speed))
}

function TypeText([string]$t) {
    foreach ($c in $t.ToCharArray()) {
        if ($special.Contains($c)) { [System.Windows.Forms.SendKeys]::SendWait("{" + $c + "}") }
        else { [System.Windows.Forms.SendKeys]::SendWait([string]$c) }
        $d = 28 + $rand.Next(60)
        if ($c -eq ' ') { $d += $rand.Next(45) }
        Start-Sleep -Milliseconds ([int]($d * $Speed))
    }
}

function Countdown([string]$where) {
    Write-Host ""
    Write-Host "Click inside the EMPTY $where now, then start recording." -ForegroundColor Yellow
    for ($i = 10; $i -gt 0; $i--) { Write-Host "Typing starts in $i..."; Start-Sleep -Seconds 1 }
    Key "^a"; Key "{DEL}"
    Start-Sleep -Milliseconds 600
}

$code = @'
// VolleyBand Bluetooth firmware.
// Reads the motion sensor 100 times a second and sends it to the laptop.

#include <ArduinoBLE.h>
#include <LSM6DS3.h>
#include <Wire.h>

const char* DEVICE_NAME = "VolleyBand-ARM";
const unsigned long SAMPLE_US = 10000;

LSM6DS3 imu(I2C_MODE, 0x6A);

// Each message is a 6 byte header, then up to 8 readings of 13 bytes.
const int MAX_BATCH = 8;
const int HEADER = 6;
const int PER_READING = 13;
const int MAX_MSG = HEADER + MAX_BATCH * PER_READING;

uint8_t msg[MAX_MSG];
int batch = 1;
int inMsg = 0;
uint32_t msgStartMs = 0;

BLEService vbService("7b1f0001-5e3a-4c8e-9d2a-6f1b2c3d4e5f");
BLECharacteristic dataChar("7b1f0002-5e3a-4c8e-9d2a-6f1b2c3d4e5f", BLERead | BLENotify, MAX_MSG, false);
BLEByteCharacteristic batchChar("7b1f0003-5e3a-4c8e-9d2a-6f1b2c3d4e5f", BLERead | BLEWrite | BLEWriteWithoutResponse);

void led(bool r, bool g, bool b) {
  digitalWrite(LED_RED, r ? LOW : HIGH);
  digitalWrite(LED_GREEN, g ? LOW : HIGH);
  digitalWrite(LED_BLUE, b ? LOW : HIGH);
}

void setup() {
  pinMode(LED_RED, OUTPUT);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_BLUE, OUTPUT);
  led(false, false, false);

  // Same ranges as the research: 16 g and 2000 degrees per second.
  imu.settings.accelRange = 16;
  imu.settings.gyroRange = 2000;
  imu.settings.accelSampleRate = 416;
  imu.settings.gyroSampleRate = 416;
  if (imu.begin() != 0) {
    led(true, false, false);
    while (true) {}
  }
  Wire.setClock(400000);

  if (!BLE.begin()) {
    led(true, false, false);
    while (true) {}
  }
  BLE.setLocalName(DEVICE_NAME);
  BLE.setDeviceName(DEVICE_NAME);
  BLE.setConnectionInterval(6, 12);
  BLE.setAdvertisedService(vbService);
  vbService.addCharacteristic(dataChar);
  vbService.addCharacteristic(batchChar);
  batchChar.writeValue(1);
  BLE.addService(vbService);
  BLE.advertise();
}

void put16(uint8_t* p, int16_t v) {
  memcpy(p, &v, 2);
}

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

  while (central.connected()) {
    if ((long)(micros() - next) < 0) continue;
    next += SAMPLE_US;
    if ((long)(micros() - next) > (long)(5 * SAMPLE_US)) next = micros() + SAMPLE_US;

    // The laptop tells us how many readings fit in one message.
    if (batchChar.written()) {
      sendMsg();
      batch = constrain((int)batchChar.value(), 1, MAX_BATCH);
    }

    uint32_t now = millis();
    if (inMsg == 0) {
      msgStartMs = now;
      memcpy(&msg[0], &seq, 2);
      memcpy(&msg[2], &msgStartMs, 4);
    }
    uint8_t* p = &msg[HEADER + inMsg * PER_READING];
    p[0] = (uint8_t)min((uint32_t)255, now - msgStartMs);
    put16(p + 1, imu.readRawAccelX());
    put16(p + 3, imu.readRawAccelY());
    put16(p + 5, imu.readRawAccelZ());
    put16(p + 7, imu.readRawGyroX());
    put16(p + 9, imu.readRawGyroY());
    put16(p + 11, imu.readRawGyroZ());
    seq++;
    inMsg++;
    if (inMsg >= batch) sendMsg();
  }

  led(false, false, false);
  BLE.advertise();
}

void loop() {
  BLEDevice central = BLE.central();
  if (central) {
    stream(central);
    return;
  }
  led(false, false, (millis() % 1000) < 80);
}
'@

Countdown "Arduino IDE editor"
$lines = $code -split "`r?`n"
for ($n = 0; $n -lt $lines.Count; $n++) {
    $t = $lines[$n].Trim()
    if ($t.StartsWith("}")) {
        Start-Sleep -Milliseconds ([int]((150 + $rand.Next(150)) * $Speed))
        Key "{DOWN}"; Key "{END}"
        if ($t.Length -gt 1) { TypeText $t.Substring(1) }
        continue
    }
    if ($n -gt 0) {
        Start-Sleep -Milliseconds ([int]((180 + $rand.Next(280)) * $Speed))
        Key "{ENTER}"
    }
    if ($t.Length -gt 0) { TypeText $t }
}
Key "^s"
Write-Host "Done." -ForegroundColor Green
