# Bench test, 2026-11-02

Both pods on a desk, connected to a Windows PC, moved by hand.

| File | Firmware | Result |
|---|---|---|
| `18-48-11_*` | v1, 1 reading per message, both pods | ARM lost 1, ANKLE lost about 12% |
| `18-50-34_*ANKLE` | v1, ANKLE alone | lost 0 |
| `19-05-55_*` | v2, 8 readings per message, both pods | ANKLE lost 0, ARM lost 16 |

Columns: `pc_time` (Unix seconds), `pod_ms`, `seq`, `ax_g ay_g az_g`, `gx_dps gy_dps gz_dps`, `acc_mag_g`, `gyro_mag_dps`.
