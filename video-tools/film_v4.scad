// VolleyBand sensor pod case  v4

batt  = [36, 25.5, 4.3];
board = [17.8, 21, 4];
wall  = 1.8;
floor_t = 6;
foam  = 1.2;

inner = [batt[0] + 0.8, batt[1] + 0.8];
depth = batt[2] + board[2] + foam + 2.4;
outer = [inner[0] + 2*wall, inner[1] + 2*wall, floor_t + depth];

module rbox(s, r) {
  linear_extrude(s[2]) offset(r) square([s[0] - 2*r, s[1] - 2*r], center=true);
}

difference() {
  rbox(outer, 2.5);
  // cavity for the battery and board
  translate([0, 0, floor_t]) rbox([inner[0], inner[1], depth + 1], 0.8);
  // strap tunnel
  translate([-12.75, -outer[1]/2 - 1, 1.6]) cube([25.5, outer[1] + 2, 2.8]);
  // USB-C opening
  translate([-7, outer[1]/2 - wall - 1, floor_t + batt[2] - 1.5]) cube([14, wall + 2, depth]);
  // alignment groove
  translate([outer[0]/2 - 1, -1, floor_t + 2]) cube([1.1, 2, depth * 0.7]);
  // grooves the lid clips snap into
  for (m = [0, 1]) mirror([m, 0, 0]) translate([inner[0]/2 - 0.1, -8.8, outer[2] - 7.5]) cube([0.9, 7.6, 2.4]);
}

// lid, flat side down like it prints
translate([outer[0] + 8, 0, 0]) {
  // plate, with ARM cut into the underside
  difference() {
    rbox([outer[0], outer[1], 2], 2.5);
    translate([0, 0, -1]) linear_extrude(1.6) mirror([1, 0, 0]) text("ARM", size=5, halign="center", valign="center");
  }
  // lip that sits inside the case
  translate([0, 0, 2]) difference() {
    rbox([inner[0] - 0.6, inner[1] - 0.6, 2], 0.8);
    for (m = [0, 1]) mirror([m, 0, 0]) translate([inner[0]/2 - 1.9, 0.9, -1]) cube([3, 8.2, 4]);
    translate([-8, -inner[1]/2 - 1, -1]) cube([16, 4, 4]);
  }
  // ribs that hold the board
  translate([0, -2, 4]) linear_extrude(5.3) difference() {
    offset(1.2) square([board[0] + 0.8, board[1] + 0.8], center=true);
    square([board[0] + 0.8, board[1] + 0.8], center=true);
    translate([0, -(board[1]/2 + 2)]) square([board[0] + 6, 4], center=true);
  }
  // snap clips
  for (m = [0, 1]) mirror([m, 0, 0]) translate([inner[0]/2 - 1.3, 1.5, 2]) {
    cube([1, 7, 7.3]);
    translate([1, 0, 5.9]) cube([0.8, 7, 1.2]);
  }
}
