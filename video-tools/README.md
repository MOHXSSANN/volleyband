# Video tools

Scripts that type code into an editor at human speed, for filming. Run from PowerShell, click into the empty editor during the 10 second countdown, then hands off.

| Script | Types | Into |
|---|---|---|
| `openscad_live_build_v4.ps1` | the case model (`film_v4.scad`), re-rendering after every line | OpenSCAD |
| `type_firmware.ps1` | the Bluetooth firmware (`film_firmware.ino`) | Arduino IDE |
| `type_logger.ps1` | the logger | VS Code, opened through `VolleyBand_film.code-workspace` (turns off auto-brackets) |

Add `-Speed 1.5` to type slower.
