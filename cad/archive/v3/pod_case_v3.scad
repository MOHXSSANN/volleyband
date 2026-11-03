// ===========================================================================
//  VolleyBand - sensor pod enclosure    v3
//  Tested against OpenSCAD 2021.01
//
//  One design, printed twice: one pod for the upper arm, one for the ankle.
//  The strap threads through a tunnel underneath, so the pod cannot rotate on
//  the band. A band that shifts between sessions changes your axis readings
//  for reasons that have nothing to do with your swing.
//
//  ---------------------------------------------------------------------
//  CHANGES FROM v2
//    * FIXED: the board was turned the wrong way. The USB-C port is on the
//      board's SHORT edge (17.8 mm), so the 21 mm length now runs along Y,
//      pointing the port at the notch in the +Y wall. The lid ribs follow.
//    * board width 17.5 -> 17.8 mm (Seeed's published size).
//
//  CHANGES FROM v1  (all found by drawing the exploded view)
//    * FIXED: the lid lip was a solid plug dropping 3 mm into an 8.9 mm
//      cavity, leaving 5.9 mm for 8.3 mm of parts. The lid could not close.
//      The lip now sits in its own rebate ABOVE the components.
//    * Added foam_t, so there is actually room for the pad under the lid.
//    * Added ribs under the lid that box the board in sideways.
//    * The lip is cut away above the USB notch so a plug can get in.
//
//  ---------------------------------------------------------------------
//  HOW TO USE
//    1.  F5 = fast preview.  F6 = proper render (do this before exporting).
//    2.  Set  part = "case"  ->  F6  ->  File > Export > Export as STL
//        Set  part = "lid"   ->  F6  ->  export again
//    3.  Print 2 of each.  Case open-side UP. No supports needed.
//
//  Every number tagged [MEASURE] came from a datasheet, not the part in your
//  hand. Check it when the hardware arrives and edit it here.
// ===========================================================================


/* [What to render] */
part = "both";          // ["case":Case only, "lid":Lid only, "both":Both side by side]

/* [Label] */
label = "ARM";          // Use "ANKLE" for the second pod. "" for none.
label_size = 5;


/* [Components - MEASURE these] */
board_x   = 17.8;       // [MEASURE] XIAO nRF52840 Sense, short edge (USB-C end)
board_y   = 21.0;       // [MEASURE] long edge, runs toward the USB notch
board_z   = 4.0;        // [MEASURE] tallest point, which is the USB-C shell

batt_x    = 25.5;       // [MEASURE] EEMB LP402535
batt_y    = 36.0;       // [MEASURE]
batt_z    = 4.3;        // [MEASURE] measure the FATTEST point - cells puff

strap_w   = 24.5;       // [MEASURE] MOOFIT RA1
strap_t   = 2.0;        // [MEASURE] the listing never states this - guess


/* [Assembly extras] */
foam_t    = 1.2;        // compressed thickness of the pad under the lid.
                        // Craft foam is ~2 mm uncompressed and squashes to
                        // roughly this. Set to 0 if you skip the pad.


/* [Fit and clearances] */
fit_clear     = 0.8;    // slack around the stack in X and Y
stack_clear   = 0.4;    // spare height on top of everything
strap_clear_x = 1.0;    // tunnel wider than the strap
strap_clear_z = 0.8;    // tunnel taller than the strap. Generous on purpose:
                        // the roof is a 25 mm bridge and FDM bridges sag. If
                        // the strap will not thread, raise to 1.2 and reprint.
lid_clear     = 0.30;   // gap per side around the lid lip
rib_clear     = 0.40;   // gap per side between ribs and the board


/* [Walls and cosmetics] */
wall      = 1.8;
floor_t   = 1.0;        // thin plate that sits against your skin
mid_t     = 1.2;        // between strap tunnel and battery
lid_t     = 1.5;
lid_lip   = 2.0;        // how deep the lid lip sits in its rebate
rib_w     = 1.2;        // thickness of the board-retaining ribs
corner_r  = 2.5;
chamfer   = 0.8;        // softens the top edge - this gets landed on


/* [USB-C opening] */
// The board rides on the battery, so its socket sits high in the cavity.
// The opening is a NOTCH cut down from the rim rather than a hole, so there
// is no fragile strip of plastic above it and nothing to bridge when
// printing. The lid closes the top of it.
usb_w      = 13.0;      // wide enough for a cable PLUG, not just the socket
usb_margin = 0.5;       // how far below the board the notch floor starts


/* [Alignment notch] */
notch   = true;         // groove down one side. Line it up the same way every
                        // session so the sensor sits in a repeatable pose.
notch_w = 2.0;
notch_d = 1.0;

/* [Lid ribs] */
lid_ribs = true;        // three short walls that stop the board sliding


// ===========================================================================
//  DERIVED - no need to edit below here
// ===========================================================================

// The battery is turned 90 degrees to the board, so its long side runs across
// the case. Footprint is whichever part is wider on each axis.
inner_x = max(batt_y, board_x) + fit_clear;
inner_y = max(batt_x, board_y) + fit_clear;

tunnel_w = strap_w + strap_clear_x;
tunnel_h = strap_t + strap_clear_z;

// Vertical budget, bottom to top:
//   floor | tunnel | mid | battery | board | foam | slack | lid rebate | lid
base_h   = floor_t + tunnel_h + mid_t;          // solid stack under the parts
pocket_z = batt_z + board_z + foam_t + stack_clear;   // where the parts live
cavity_z = pocket_z + lid_lip;                  // plus the lid's rebate
case_z   = base_h + cavity_z;                   // the tub, before the lid

case_x = inner_x + 2 * wall;
case_y = inner_y + 2 * wall;

// Board is pushed against the +Y wall so its socket lines up with the notch.
board_cy = inner_y / 2 - board_y / 2 - 0.8;

usb_z0 = base_h + batt_z - usb_margin;          // floor of the USB notch
rib_h  = pocket_z - batt_z - 0.3;               // ribs stop above the battery

$fn = 48;

echo(str("  OUTER       ", case_x, " x ", case_y, " x ", case_z + lid_t, " mm"));
echo(str("  PARTS POCKET ", inner_x, " x ", inner_y, " x ", pocket_z, " mm"));
echo(str("  parts need   ", batt_z + board_z + foam_t, " mm of that"));
echo(str("  TUNNEL       ", tunnel_w, " wide x ", tunnel_h, " tall"));


// ---------------------------------------------------------------- helpers

module rrect(x, y, r) {
    offset(r = r) square([x - 2 * r, y - 2 * r], center = true);
}

// Rounded vertical corners, chamfered top edge, flat bottom for printing.
module rbox(x, y, z, r, ch) {
    hull() {
        linear_extrude(height = z - ch) rrect(x, y, r);
        translate([0, 0, z - ch])
            linear_extrude(height = ch) rrect(x - 2 * ch, y - 2 * ch, max(r - ch, 0.6));
    }
}

module pbox(x, y, z, r) {
    linear_extrude(height = z) rrect(x, y, r);
}


// ---------------------------------------------------------------- the case

module case_body() {
    difference() {
        rbox(case_x, case_y, case_z, corner_r, chamfer);

        // one cavity: parts pocket plus the lid rebate above it
        translate([0, 0, base_h])
            pbox(inner_x, inner_y, cavity_z + 1, max(corner_r - wall, 0.8));

        // strap tunnel, straight through in Y
        translate([-tunnel_w / 2, -case_y / 2 - 1, floor_t])
            cube([tunnel_w, case_y + 2, tunnel_h]);

        // USB-C notch in the +Y wall, open at the top
        translate([0, case_y / 2, usb_z0])
            cube([usb_w, wall * 4, (case_z - usb_z0) * 2], center = true);

        // alignment groove down the +X face
        if (notch)
            translate([case_x / 2 - notch_d / 2 + 0.01, 0, base_h + pocket_z / 2])
                cube([notch_d, notch_w, pocket_z * 0.8], center = true);
    }
}


// ---------------------------------------------------------------- the lid
//  Local origin: plate spans z = 0..lid_t, lip hangs below into -z.

module lid_lip_block() {
    difference() {
        translate([0, 0, -lid_lip])
            pbox(inner_x - 2 * lid_clear, inner_y - 2 * lid_clear, lid_lip,
                 max(corner_r - wall, 0.8));
        // cut the lip away above the USB notch so a plug can get in
        translate([0, inner_y / 2, -lid_lip / 2])
            cube([usb_w + 2, 8, lid_lip + 2], center = true);
    }
}

// Three short walls around the board: both long sides and the back. The +Y
// wall is left off entirely - the USB connector needs that side clear, and a
// partial wall there would poke outside the cavity and stop the lid seating.
// The case's own +Y wall holds the board on that side.
module lid_rib_walls() {
    bw = board_x + 2 * rib_clear;
    bd = board_y + 2 * rib_clear;
    translate([0, board_cy, -lid_lip - rib_h])
        linear_extrude(height = rib_h)
            difference() {
                rrect(bw + 2 * rib_w, bd + 2 * rib_w, 0.8);
                square([bw, bd], center = true);
                translate([0, bd / 2 + rib_w])
                    square([bw + 2 * rib_w + 2, rib_w * 2 + 0.2], center = true);
            }
}

module lid() {
    rbox(case_x, case_y, lid_t, corner_r, chamfer);
    lid_lip_block();
    if (lid_ribs) lid_rib_walls();
    if (label != "")
        translate([0, 0, lid_t])
            linear_extrude(height = 0.6)
                text(label, size = label_size, halign = "center",
                     valign = "center", font = "Liberation Sans:style=Bold");
}


// ---------------------------------------------------------------- render

if (part == "case") case_body();
else if (part == "lid") translate([0, 0, lid_lip + rib_h]) lid();
else {
    case_body();
    translate([case_x + 8, 0, lid_lip + rib_h]) lid();
}
