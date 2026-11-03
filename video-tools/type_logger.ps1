# VolleyBand - types the laptop logger into VS Code for filming.
#
# 1. Double-click VolleyBand_film.code-workspace in this folder. It opens VS Code
#    with auto-brackets and pop-ups switched off, so the typing comes out clean.
# 2. File > New File, save it as logger_demo.py. Make the window big.
# 3. In PowerShell run:
#    powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\OneDrive\Desktop\VolleyBand_Bluetooth\film\type_logger.ps1"
# 4. During the 10 s countdown click inside the empty file and start recording.
# Optional: -Speed 1.5 types slower.

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
"""
VolleyBand logger: connects to the pods over Bluetooth and saves every
reading to a CSV file, one file per pod.

Setup (once):   pip install bleak
Run:            python volleyband_logger.py
Only the arm:   python volleyband_logger.py --pods VolleyBand-ARM
Stop:           Ctrl+C. The files are saved as it goes.

Files go in a VolleyBand_Data folder next to this script.
"""
import argparse
import asyncio
import csv
import math
import struct
import time
from datetime import datetime
from pathlib import Path

from bleak import BleakClient, BleakScanner

DATA_UUID = "7b1f0002-5e3a-4c8e-9d2a-6f1b2c3d4e5f"
BATCH_UUID = "7b1f0003-5e3a-4c8e-9d2a-6f1b2c3d4e5f"
HEADER = struct.Struct("<HI")      # seq of first reading, ms of first reading
READING = struct.Struct("<B6h")    # ms offset, ax ay az gx gy gz
MAX_BATCH = 8
ACC_G = 0.488 / 1000               # g per count at +/-16 g
GYR_DPS = 70 / 1000                # deg/s per count at +/-2000 deg/s

OUT_DIR = Path(__file__).resolve().parent / "VolleyBand_Data"


def decode(data: bytes):
    """One message -> list of (seq, ms, [ax,ay,az] in g, [gx,gy,gz] in deg/s)."""
    seq0, ms0 = HEADER.unpack_from(data, 0)
    n = (len(data) - HEADER.size) // READING.size
    out = []
    for i in range(n):
        dt, ax, ay, az, gx, gy, gz = READING.unpack_from(data, HEADER.size + i * READING.size)
        out.append(((seq0 + i) % 65536, ms0 + dt,
                    [ax * ACC_G, ay * ACC_G, az * ACC_G],
                    [gx * GYR_DPS, gy * GYR_DPS, gz * GYR_DPS]))
    return out


async def run_pod(name: str, stamp: str):
    print(f"[{name}] looking for it...")
    dev = await BleakScanner.find_device_by_name(name, timeout=20)
    if dev is None:
        print(f"[{name}] not found. Is it switched on and blinking blue?")
        return

    path = OUT_DIR / f"{stamp}_{name}.csv"
    stats = {"n": 0, "lost": 0, "last_seq": None, "peak_g": 0.0, "peak_dps": 0.0}

    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["pc_time", "pod_ms", "seq", "ax_g", "ay_g", "az_g",
                    "gx_dps", "gy_dps", "gz_dps", "acc_mag_g", "gyro_mag_dps"])

        def on_data(_, data: bytearray):
            if len(data) < HEADER.size + READING.size:
                return
            now = f"{time.time():.3f}"
            for seq, ms, a, g in decode(bytes(data)):
                if stats["last_seq"] is not None:
                    gap = (seq - stats["last_seq"] - 1) % 65536
                    stats["lost"] += gap
                stats["last_seq"] = seq
                stats["n"] += 1
                am = math.sqrt(sum(x * x for x in a))
                gm = math.sqrt(sum(x * x for x in g))
                stats["peak_g"] = max(stats["peak_g"], am)
                stats["peak_dps"] = max(stats["peak_dps"], gm)
                w.writerow([now, ms, seq,
                            *(f"{x:.3f}" for x in a), *(f"{x:.1f}" for x in g),
                            f"{am:.3f}", f"{gm:.1f}"])

        async with BleakClient(dev) as client:
            print(f"[{name}] connected, saving to {path.name}")
            # bigger messages = fewer of them = nothing dropped with two pods
            mtu = getattr(client, "mtu_size", 23) or 23
            batch = max(1, min(MAX_BATCH, (mtu - 3 - HEADER.size) // READING.size))
            await client.start_notify(DATA_UUID, on_data)
            await client.write_gatt_char(BATCH_UUID, bytes([batch]), response=True)
            print(f"[{name}] {batch} readings per message (MTU {mtu})")
            last_n = 0
            while client.is_connected:
                await asyncio.sleep(1)
                f.flush()
                rate = stats["n"] - last_n
                last_n = stats["n"]
                print(f"[{name}] {rate:3d} readings/s | total {stats['n']} | "
                      f"lost {stats['lost']} | peak {stats['peak_g']:.1f} g, "
                      f"{stats['peak_dps']:.0f} deg/s")
            print(f"[{name}] disconnected")


async def main(pods):
    OUT_DIR.mkdir(exist_ok=True)
    stamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    await asyncio.gather(*(run_pod(p, stamp) for p in pods))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--pods", nargs="+",
                    default=["VolleyBand-ARM", "VolleyBand-ANKLE"])
    args = ap.parse_args()
    try:
        asyncio.run(main(args.pods))
    except KeyboardInterrupt:
        print("\nStopped. Data saved in", OUT_DIR)
'@

Countdown "VS Code file"
$lines = $code -split "`r?`n"
for ($n = 0; $n -lt $lines.Count; $n++) {
    $t = $lines[$n].TrimEnd()
    if ($n -gt 0) {
        Start-Sleep -Milliseconds ([int]((180 + $rand.Next(280)) * $Speed))
        Key "{ENTER}"
        # wipe any indentation the editor added, then type our own
        Key "{HOME}"; Key "+{END}"
        if ($t.Length -eq 0) { Key "{DEL}" }
    }
    if ($t.Length -gt 0) { TypeText $t }
}
Key "^s"
Write-Host "Done." -ForegroundColor Green
