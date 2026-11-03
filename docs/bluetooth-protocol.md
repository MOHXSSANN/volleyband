# Bluetooth message format

Each pod is a Bluetooth LE peripheral named `VolleyBand-ARM` or `VolleyBand-ANKLE`.

| UUID | Name | Use |
|---|---|---|
| `7b1f0001-5e3a-4c8e-9d2a-6f1b2c3d4e5f` | service | |
| `7b1f0002-5e3a-4c8e-9d2a-6f1b2c3d4e5f` | data | notify: sensor readings |
| `7b1f0003-5e3a-4c8e-9d2a-6f1b2c3d4e5f` | batch | write: readings per message, 1 to 8 |

## Data message (little-endian)

| Bytes | Field |
|---|---|
| 0-1 | `seq`: number of the first reading in this message (uint16, wraps at 65535) |
| 2-5 | `ms`: time of the first reading, ms since the pod started (uint32) |
| then, per reading, 13 bytes: | |
| 0 | ms since the header time (uint8) |
| 1-12 | ax, ay, az, gx, gy, gz as raw sensor counts (int16 each) |

Conversion: acceleration in g = count × 0.000488, rotation in deg/s = count × 0.07.

## Batching

The pod starts at 1 reading per message (19 bytes, fits the default 23-byte BLE packet). After connecting, the logger reads the negotiated MTU and writes the largest batch that fits, up to 8. With two pods on one Windows PC, single-reading messages lost about 12% of readings on one pod; batching 8 per message brought that to 0 to 0.5%.

Missing readings show up as gaps in `seq`.
