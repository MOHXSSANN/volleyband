# VolleyBand v4 - live CAD build for filming
# Types the v4 case (snap-fit lid) into the OpenSCAD editor line by line and
# re-renders after every line, so the 3D view keeps building while you watch.
#
# 1. Open OpenSCAD > New (an empty file). Make the window big, editor wide.
# 2. Run:
#    powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\OneDrive\Desktop\VolleyBand_Timelapse\openscad_live_build_v4.ps1"
# 3. During the 10 s countdown: click INSIDE the OpenSCAD editor and start
#    recording. Don't touch the mouse or keyboard until it says Done.
#
# Options:
#   -Speed 1.5   bigger = slower typing (default 1)
#   -FromLid     start at the lid. Use this if a take broke during the lid:
#                first delete everything from "// lid, flat side down" to the
#                end, so the code ends with the case's closing }.

param([double]$Speed = 1, [switch]$FromLid)

Add-Type -AssemblyName System.Windows.Forms
$rand = New-Object System.Random
$special = '+^%~(){}[]'

function Key([string]$k) {
    [System.Windows.Forms.SendKeys]::SendWait($k)
    Start-Sleep -Milliseconds ([int](60 * $Speed))
}

function TypeText([string]$t) {
    foreach ($c in $t.ToCharArray()) {
        if ($special.Contains($c)) { [System.Windows.Forms.SendKeys]::SendWait("{" + $c + "}") }
        else { [System.Windows.Forms.SendKeys]::SendWait([string]$c) }
        $d = 25 + $rand.Next(55)
        if ($c -eq ' ') { $d += $rand.Next(40) }
        Start-Sleep -Milliseconds ([int]($d * $Speed))
    }
}

# New line, wiping whatever indentation the editor added, then our own text.
function Line([string]$t) {
    Key "{ENTER}"
    Key "{HOME}"
    Key "+{END}"
    if ($t.Length -gt 0) { TypeText $t } else { Key "{DEL}" }
    # re-render after every line so the model keeps updating as the code grows
    [System.Windows.Forms.SendKeys]::SendWait("{F5}")
    # OpenSCAD ignores keys while it renders, so wait for the render to finish
    Start-Sleep -Milliseconds ([int]((1400 + $rand.Next(300)) * $Speed))
}

# Render the preview and hold so the camera sees it
function Preview([double]$hold = 2.5) {
    Start-Sleep -Milliseconds 300
    Key "{F5}"
    Start-Sleep -Milliseconds ([int]($hold * 1000))
}

Write-Host ""
if ($FromLid) {
    Write-Host "Click at the END of the code in OpenSCAD now, then start recording." -ForegroundColor Yellow
} else {
    Write-Host "Click inside the EMPTY OpenSCAD editor now, then start recording." -ForegroundColor Yellow
}
for ($i = 10; $i -gt 0; $i--) { Write-Host "Starting in $i..."; Start-Sleep -Seconds 1 }

if (-not $FromLid) {
# ---- start from a guaranteed-empty editor
Key "^a"
Key "{DEL}"
Start-Sleep -Milliseconds 800

TypeText '// VolleyBand sensor pod case  v4'
Line ''
Line 'batt  = [36, 25.5, 4.3];'
Line 'board = [17.8, 21, 4];'
Line 'wall  = 1.8;'
Line 'floor_t = 6;'
Line 'foam  = 1.2;'
Line ''
Line 'inner = [batt[0] + 0.8, batt[1] + 0.8];'
Line 'depth = batt[2] + board[2] + foam + 2.4;'
Line 'outer = [inner[0] + 2*wall, inner[1] + 2*wall, floor_t + depth];'
Line ''
Line 'module rbox(s, r) {'
Line '  linear_extrude(s[2]) offset(r) square([s[0] - 2*r, s[1] - 2*r], center=true);'
Line '}'
Line ''
Line 'difference() {'
Line '  rbox(outer, 2.5);'
Line '}'
Preview 3
Key "{UP}"; Key "{END}"
Line '  // cavity for the battery and board'
Line '  translate([0, 0, floor_t]) rbox([inner[0], inner[1], depth + 1], 0.8);'
Preview 2.5
Line '  // strap tunnel'
Line '  translate([-12.75, -outer[1]/2 - 1, 1.6]) cube([25.5, outer[1] + 2, 2.8]);'
Preview 2.5
Line '  // USB-C opening'
Line '  translate([-7, outer[1]/2 - wall - 1, floor_t + batt[2] - 1.5]) cube([14, wall + 2, depth]);'
Preview 2.5
Line '  // alignment groove'
Line '  translate([outer[0]/2 - 1, -1, floor_t + 2]) cube([1.1, 2, depth * 0.7]);'
Preview 2.5
Line '  // grooves the lid clips snap into'
Line '  for (m = [0, 1]) mirror([m, 0, 0]) translate([inner[0]/2 - 0.1, -8.8, outer[2] - 7.5]) cube([0.9, 7.6, 2.4]);'
Preview 2.5
}

# ---- the lid
Key "^{END}"
Line ''
Line '// lid, flat side down like it prints'
Line 'translate([outer[0] + 8, 0, 0]) {'
Line '  // plate, with ARM cut into the underside'
Line '  difference() {'
Line '    rbox([outer[0], outer[1], 2], 2.5);'
Line '    translate([0, 0, -1]) linear_extrude(1.6) mirror([1, 0, 0]) text("ARM", size=5, halign="center", valign="center");'
Line '  }'
Line '}'
Preview 2.5
Key "{UP}"; Key "{END}"
Line '  // lip that sits inside the case'
Line '  translate([0, 0, 2]) difference() {'
Line '    rbox([inner[0] - 0.6, inner[1] - 0.6, 2], 0.8);'
Line '    for (m = [0, 1]) mirror([m, 0, 0]) translate([inner[0]/2 - 1.9, 0.9, -1]) cube([3, 8.2, 4]);'
Line '    translate([-8, -inner[1]/2 - 1, -1]) cube([16, 4, 4]);'
Line '  }'
Preview 2.5
Line '  // ribs that hold the board'
Line '  translate([0, -2, 4]) linear_extrude(5.3) difference() {'
Line '    offset(1.2) square([board[0] + 0.8, board[1] + 0.8], center=true);'
Line '    square([board[0] + 0.8, board[1] + 0.8], center=true);'
Line '    translate([0, -(board[1]/2 + 2)]) square([board[0] + 6, 4], center=true);'
Line '  }'
Preview 2.5
Line '  // snap clips'
Line '  for (m = [0, 1]) mirror([m, 0, 0]) translate([inner[0]/2 - 1.3, 1.5, 2]) {'
Line '    cube([1, 7, 7.3]);'
Line '    translate([1, 0, 5.9]) cube([0.8, 7, 1.2]);'
Line '  }'
Preview 3

# ---- change one number and the whole case resizes: wall 1.8 -> 3.5 -> 1.8
Key "^{HOME}"
Key "{DOWN}"; Key "{DOWN}"; Key "{DOWN}"; Key "{DOWN}"
Key "{END}"
Start-Sleep -Milliseconds 600
Key "{BACKSPACE}"; Key "{BACKSPACE}"; Key "{BACKSPACE}"; Key "{BACKSPACE}"
TypeText "3.5;"
Preview 3
Key "{BACKSPACE}"; Key "{BACKSPACE}"; Key "{BACKSPACE}"; Key "{BACKSPACE}"
TypeText "1.8;"
Preview 3

Write-Host "Done." -ForegroundColor Green
