// Bundled, offline reference data for Flyby — no network, no API.
//
//   AIRCRAFT_TYPES : ICAO type designator -> spec card + Dex metadata
//   AIRLINES       : ICAO operator prefix -> name / radio callsign / country
//
// This is the "universe" the Dex is completed against: every key in
// AIRCRAFT_TYPES is a collectible slot. Types seen on the feed that aren't
// in here still get logged, just shown as "Unclassified <code>".
//
// Spec fields (all approximate — this is a factoid card, not an ops manual):
//   n  full name        s  short name        m  manufacturer
//   c  category  (widebody|narrowbody|regional|turboprop|piston|business|heli|military|vintage)
//   r  rarity    (common|uncommon|rare|exotic)
//   ws wingspan (m)      ln length (m)        mtow max takeoff (t)
//   crz cruise (kt)      eng engines (n)      et  engine type (Jet|Turboprop|Piston)
//   pax typical seats    rng range (km)       yr  first flight (year)
//   wake wake cat (L|M|H|J)
//
// Tested with node:
//   node -e 'const D=require("./Data.js"); console.log(D.typeName("B738"), D.airlineFor("SWA2412"))'

var AIRCRAFT_TYPES = {
  // ---- Airbus narrowbody ------------------------------------------------
  "A318": { n: "Airbus A318",        s: "A318",  m: "Airbus", c: "narrowbody", r: "rare",     ws: 34.1, ln: 31.4, mtow: 68,   crz: 447, eng: 2, et: "Jet", pax: 132, rng: 5750, yr: 2002, wake: "M" },
  "A319": { n: "Airbus A319",        s: "A319",  m: "Airbus", c: "narrowbody", r: "common",   ws: 35.8, ln: 33.8, mtow: 75.5, crz: 447, eng: 2, et: "Jet", pax: 156, rng: 6950, yr: 1995, wake: "M" },
  "A320": { n: "Airbus A320",        s: "A320",  m: "Airbus", c: "narrowbody", r: "common",   ws: 35.8, ln: 37.6, mtow: 78,   crz: 447, eng: 2, et: "Jet", pax: 180, rng: 6100, yr: 1987, wake: "M" },
  "A321": { n: "Airbus A321",        s: "A321",  m: "Airbus", c: "narrowbody", r: "common",   ws: 35.8, ln: 44.5, mtow: 93.5, crz: 447, eng: 2, et: "Jet", pax: 220, rng: 5950, yr: 1993, wake: "M" },
  "A19N": { n: "Airbus A319neo",     s: "A319neo", m: "Airbus", c: "narrowbody", r: "uncommon", ws: 35.8, ln: 33.8, mtow: 75.5, crz: 450, eng: 2, et: "Jet", pax: 160, rng: 6850, yr: 2017, wake: "M" },
  "A20N": { n: "Airbus A320neo",     s: "A320neo", m: "Airbus", c: "narrowbody", r: "common",   ws: 35.8, ln: 37.6, mtow: 79,   crz: 450, eng: 2, et: "Jet", pax: 180, rng: 6300, yr: 2014, wake: "M" },
  "A21N": { n: "Airbus A321neo",     s: "A321neo", m: "Airbus", c: "narrowbody", r: "common",   ws: 35.8, ln: 44.5, mtow: 97,   crz: 450, eng: 2, et: "Jet", pax: 220, rng: 7400, yr: 2016, wake: "M" },
  "A310": { n: "Airbus A310",        s: "A310",  m: "Airbus", c: "widebody",   r: "rare",     ws: 43.9, ln: 46.7, mtow: 164,  crz: 459, eng: 2, et: "Jet", pax: 240, rng: 9600, yr: 1982, wake: "H" },
  "A306": { n: "Airbus A300-600",    s: "A300",  m: "Airbus", c: "widebody",   r: "uncommon", ws: 44.8, ln: 54.1, mtow: 171,  crz: 460, eng: 2, et: "Jet", pax: 266, rng: 7500, yr: 1983, wake: "H" },
  // ---- Airbus widebody -----------------------------------------------
  "A332": { n: "Airbus A330-200",    s: "A330-200", m: "Airbus", c: "widebody", r: "uncommon", ws: 60.3, ln: 58.8, mtow: 242, crz: 470, eng: 2, et: "Jet", pax: 246, rng: 13450, yr: 1997, wake: "H" },
  "A333": { n: "Airbus A330-300",    s: "A330-300", m: "Airbus", c: "widebody", r: "uncommon", ws: 60.3, ln: 63.7, mtow: 242, crz: 470, eng: 2, et: "Jet", pax: 300, rng: 11750, yr: 1992, wake: "H" },
  "A338": { n: "Airbus A330-800neo", s: "A330-800", m: "Airbus", c: "widebody", r: "rare",     ws: 64.0, ln: 58.8, mtow: 251, crz: 472, eng: 2, et: "Jet", pax: 257, rng: 15100, yr: 2018, wake: "H" },
  "A339": { n: "Airbus A330-900neo", s: "A330-900", m: "Airbus", c: "widebody", r: "uncommon", ws: 64.0, ln: 63.7, mtow: 251, crz: 472, eng: 2, et: "Jet", pax: 287, rng: 13330, yr: 2017, wake: "H" },
  "A342": { n: "Airbus A340-200",    s: "A340-200", m: "Airbus", c: "widebody", r: "exotic",   ws: 60.3, ln: 59.4, mtow: 275, crz: 475, eng: 4, et: "Jet", pax: 261, rng: 14800, yr: 1992, wake: "H" },
  "A343": { n: "Airbus A340-300",    s: "A340-300", m: "Airbus", c: "widebody", r: "rare",     ws: 60.3, ln: 63.7, mtow: 276, crz: 475, eng: 4, et: "Jet", pax: 295, rng: 13500, yr: 1991, wake: "H" },
  "A345": { n: "Airbus A340-500",    s: "A340-500", m: "Airbus", c: "widebody", r: "exotic",   ws: 63.5, ln: 67.9, mtow: 380, crz: 481, eng: 4, et: "Jet", pax: 313, rng: 16700, yr: 2002, wake: "H" },
  "A346": { n: "Airbus A340-600",    s: "A340-600", m: "Airbus", c: "widebody", r: "exotic",   ws: 63.5, ln: 75.4, mtow: 380, crz: 481, eng: 4, et: "Jet", pax: 379, rng: 14450, yr: 2001, wake: "H" },
  "A359": { n: "Airbus A350-900",    s: "A350-900", m: "Airbus", c: "widebody", r: "uncommon", ws: 64.8, ln: 66.8, mtow: 280, crz: 488, eng: 2, et: "Jet", pax: 325, rng: 15000, yr: 2013, wake: "H" },
  "A35K": { n: "Airbus A350-1000",   s: "A350-1000", m: "Airbus", c: "widebody", r: "rare",    ws: 64.8, ln: 73.8, mtow: 322, crz: 488, eng: 2, et: "Jet", pax: 366, rng: 16100, yr: 2016, wake: "H" },
  "A388": { n: "Airbus A380-800",    s: "A380",  m: "Airbus", c: "widebody",   r: "rare",     ws: 79.8, ln: 72.7, mtow: 575,  crz: 488, eng: 4, et: "Jet", pax: 525, rng: 14800, yr: 2005, wake: "J" },
  "A337": { n: "Airbus BelugaXL",    s: "BelugaXL", m: "Airbus", c: "widebody", r: "exotic",  ws: 60.3, ln: 63.1, mtow: 227, crz: 470, eng: 2, et: "Jet", pax: 0,   rng: 4300, yr: 2018, wake: "H" },

  // ---- Boeing 737 --------------------------------------------------
  "B731": { n: "Boeing 737-100",     s: "737-100", m: "Boeing", c: "narrowbody", r: "exotic",  ws: 28.4, ln: 28.7, mtow: 50,   crz: 430, eng: 2, et: "Jet", pax: 124, rng: 2850, yr: 1967, wake: "M" },
  "B732": { n: "Boeing 737-200",     s: "737-200", m: "Boeing", c: "narrowbody", r: "rare",    ws: 28.4, ln: 30.5, mtow: 52.4, crz: 430, eng: 2, et: "Jet", pax: 136, rng: 4200, yr: 1967, wake: "M" },
  "B733": { n: "Boeing 737-300",     s: "737-300", m: "Boeing", c: "narrowbody", r: "uncommon", ws: 28.9, ln: 33.4, mtow: 62.8, crz: 430, eng: 2, et: "Jet", pax: 149, rng: 4400, yr: 1984, wake: "M" },
  "B734": { n: "Boeing 737-400",     s: "737-400", m: "Boeing", c: "narrowbody", r: "uncommon", ws: 28.9, ln: 36.4, mtow: 68,   crz: 430, eng: 2, et: "Jet", pax: 168, rng: 3800, yr: 1988, wake: "M" },
  "B735": { n: "Boeing 737-500",     s: "737-500", m: "Boeing", c: "narrowbody", r: "uncommon", ws: 28.9, ln: 31.0, mtow: 60.5, crz: 430, eng: 2, et: "Jet", pax: 132, rng: 4400, yr: 1989, wake: "M" },
  "B736": { n: "Boeing 737-600",     s: "737-600", m: "Boeing", c: "narrowbody", r: "rare",    ws: 34.3, ln: 31.2, mtow: 65.5, crz: 445, eng: 2, et: "Jet", pax: 130, rng: 5600, yr: 1998, wake: "M" },
  "B737": { n: "Boeing 737-700",     s: "737-700", m: "Boeing", c: "narrowbody", r: "common",  ws: 34.3, ln: 33.6, mtow: 70,   crz: 445, eng: 2, et: "Jet", pax: 149, rng: 6370, yr: 1997, wake: "M" },
  "B738": { n: "Boeing 737-800",     s: "737-800", m: "Boeing", c: "narrowbody", r: "common",  ws: 35.8, ln: 39.5, mtow: 79,   crz: 453, eng: 2, et: "Jet", pax: 189, rng: 5440, yr: 1997, wake: "M" },
  "B739": { n: "Boeing 737-900",     s: "737-900", m: "Boeing", c: "narrowbody", r: "common",  ws: 35.8, ln: 42.1, mtow: 85.1, crz: 453, eng: 2, et: "Jet", pax: 215, rng: 5460, yr: 2000, wake: "M" },
  "B37M": { n: "Boeing 737 MAX 7",   s: "737 MAX 7", m: "Boeing", c: "narrowbody", r: "uncommon", ws: 35.9, ln: 35.6, mtow: 80.3, crz: 453, eng: 2, et: "Jet", pax: 172, rng: 7130, yr: 2018, wake: "M" },
  "B38M": { n: "Boeing 737 MAX 8",   s: "737 MAX 8", m: "Boeing", c: "narrowbody", r: "common",   ws: 35.9, ln: 39.5, mtow: 82.2, crz: 453, eng: 2, et: "Jet", pax: 189, rng: 6570, yr: 2016, wake: "M" },
  "B39M": { n: "Boeing 737 MAX 9",   s: "737 MAX 9", m: "Boeing", c: "narrowbody", r: "uncommon", ws: 35.9, ln: 42.2, mtow: 88.3, crz: 453, eng: 2, et: "Jet", pax: 220, rng: 6570, yr: 2017, wake: "M" },
  "B3XM": { n: "Boeing 737 MAX 10",  s: "737 MAX 10", m: "Boeing", c: "narrowbody", r: "rare",    ws: 35.9, ln: 43.8, mtow: 89.8, crz: 453, eng: 2, et: "Jet", pax: 230, rng: 6110, yr: 2021, wake: "M" },
  // ---- Boeing 747/757/767/777/787 --------------------------------
  "B741": { n: "Boeing 747-100",     s: "747-100", m: "Boeing", c: "widebody", r: "exotic",   ws: 59.6, ln: 70.7, mtow: 340, crz: 490, eng: 4, et: "Jet", pax: 400, rng: 8500, yr: 1969, wake: "H" },
  "B742": { n: "Boeing 747-200",     s: "747-200", m: "Boeing", c: "widebody", r: "exotic",   ws: 59.6, ln: 70.7, mtow: 378, crz: 490, eng: 4, et: "Jet", pax: 400, rng: 12700, yr: 1970, wake: "H" },
  "B743": { n: "Boeing 747-300",     s: "747-300", m: "Boeing", c: "widebody", r: "exotic",   ws: 59.6, ln: 70.7, mtow: 378, crz: 490, eng: 4, et: "Jet", pax: 400, rng: 12400, yr: 1982, wake: "H" },
  "B744": { n: "Boeing 747-400",     s: "747-400", m: "Boeing", c: "widebody", r: "rare",     ws: 64.4, ln: 70.7, mtow: 397, crz: 493, eng: 4, et: "Jet", pax: 416, rng: 13450, yr: 1988, wake: "H" },
  "B748": { n: "Boeing 747-8",       s: "747-8",  m: "Boeing", c: "widebody",   r: "rare",     ws: 68.4, ln: 76.3, mtow: 448,  crz: 495, eng: 4, et: "Jet", pax: 467, rng: 14320, yr: 2010, wake: "J" },
  "B74S": { n: "Boeing 747SP",       s: "747SP",  m: "Boeing", c: "widebody",   r: "exotic",   ws: 59.6, ln: 56.3, mtow: 318,  crz: 493, eng: 4, et: "Jet", pax: 276, rng: 15400, yr: 1975, wake: "H" },
  "BLCF": { n: "Boeing 747 Dreamlifter", s: "Dreamlifter", m: "Boeing", c: "widebody", r: "exotic", ws: 64.4, ln: 71.7, mtow: 364, crz: 461, eng: 4, et: "Jet", pax: 0, rng: 7800, yr: 2006, wake: "H" },
  "B752": { n: "Boeing 757-200",     s: "757-200", m: "Boeing", c: "narrowbody", r: "uncommon", ws: 38.0, ln: 47.3, mtow: 116, crz: 458, eng: 2, et: "Jet", pax: 200, rng: 7250, yr: 1982, wake: "M" },
  "B753": { n: "Boeing 757-300",     s: "757-300", m: "Boeing", c: "narrowbody", r: "rare",     ws: 38.0, ln: 54.4, mtow: 124, crz: 458, eng: 2, et: "Jet", pax: 243, rng: 6400, yr: 1998, wake: "M" },
  "B762": { n: "Boeing 767-200",     s: "767-200", m: "Boeing", c: "widebody",   r: "rare",     ws: 47.6, ln: 48.5, mtow: 143, crz: 460, eng: 2, et: "Jet", pax: 216, rng: 12200, yr: 1981, wake: "H" },
  "B763": { n: "Boeing 767-300",     s: "767-300", m: "Boeing", c: "widebody",   r: "uncommon", ws: 47.6, ln: 54.9, mtow: 187, crz: 460, eng: 2, et: "Jet", pax: 269, rng: 11070, yr: 1986, wake: "H" },
  "B764": { n: "Boeing 767-400",     s: "767-400", m: "Boeing", c: "widebody",   r: "rare",     ws: 51.9, ln: 61.4, mtow: 204, crz: 460, eng: 2, et: "Jet", pax: 296, rng: 10400, yr: 1999, wake: "H" },
  "B772": { n: "Boeing 777-200",     s: "777-200", m: "Boeing", c: "widebody",   r: "uncommon", ws: 60.9, ln: 63.7, mtow: 247, crz: 482, eng: 2, et: "Jet", pax: 314, rng: 9700, yr: 1994, wake: "H" },
  "B77L": { n: "Boeing 777-200LR / F", s: "777-200LR", m: "Boeing", c: "widebody", r: "rare",   ws: 64.8, ln: 63.7, mtow: 348, crz: 482, eng: 2, et: "Jet", pax: 317, rng: 15840, yr: 2005, wake: "H" },
  "B773": { n: "Boeing 777-300",     s: "777-300", m: "Boeing", c: "widebody",   r: "uncommon", ws: 60.9, ln: 73.9, mtow: 300, crz: 482, eng: 2, et: "Jet", pax: 396, rng: 11120, yr: 1997, wake: "H" },
  "B77W": { n: "Boeing 777-300ER",   s: "777-300ER", m: "Boeing", c: "widebody", r: "uncommon", ws: 64.8, ln: 73.9, mtow: 351, crz: 482, eng: 2, et: "Jet", pax: 396, rng: 13650, yr: 2003, wake: "H" },
  "B778": { n: "Boeing 777-8",       s: "777-8",  m: "Boeing", c: "widebody",   r: "exotic",   ws: 71.8, ln: 69.8, mtow: 351,  crz: 488, eng: 2, et: "Jet", pax: 395, rng: 16200, yr: 2025, wake: "H" },
  "B779": { n: "Boeing 777-9",       s: "777-9",  m: "Boeing", c: "widebody",   r: "exotic",   ws: 71.8, ln: 76.7, mtow: 351,  crz: 488, eng: 2, et: "Jet", pax: 426, rng: 13500, yr: 2020, wake: "J" },
  "B788": { n: "Boeing 787-8",       s: "787-8",  m: "Boeing", c: "widebody",   r: "uncommon", ws: 60.1, ln: 56.7, mtow: 228,  crz: 488, eng: 2, et: "Jet", pax: 248, rng: 13530, yr: 2009, wake: "H" },
  "B789": { n: "Boeing 787-9",       s: "787-9",  m: "Boeing", c: "widebody",   r: "common",   ws: 60.1, ln: 62.8, mtow: 254,  crz: 488, eng: 2, et: "Jet", pax: 296, rng: 14140, yr: 2013, wake: "H" },
  "B78X": { n: "Boeing 787-10",      s: "787-10", m: "Boeing", c: "widebody",   r: "uncommon", ws: 60.1, ln: 68.3, mtow: 254,  crz: 488, eng: 2, et: "Jet", pax: 336, rng: 11730, yr: 2017, wake: "H" },
  "B722": { n: "Boeing 727-200",     s: "727-200", m: "Boeing", c: "narrowbody", r: "exotic",  ws: 32.9, ln: 46.7, mtow: 95,   crz: 467, eng: 3, et: "Jet", pax: 155, rng: 4000, yr: 1967, wake: "M" },
  "B712": { n: "Boeing 717-200",     s: "717",    m: "Boeing", c: "narrowbody",  r: "rare",     ws: 28.4, ln: 37.8, mtow: 54.9, crz: 438, eng: 2, et: "Jet", pax: 117, rng: 3800, yr: 1998, wake: "M" },

  // ---- Regional jets ---------------------------------------------
  "E135": { n: "Embraer ERJ-135",    s: "ERJ-135", m: "Embraer", c: "regional", r: "rare",     ws: 20.0, ln: 26.3, mtow: 20,   crz: 447, eng: 2, et: "Jet", pax: 37,  rng: 3240, yr: 1998, wake: "M" },
  "E145": { n: "Embraer ERJ-145",    s: "ERJ-145", m: "Embraer", c: "regional", r: "uncommon", ws: 20.0, ln: 29.9, mtow: 22,   crz: 447, eng: 2, et: "Jet", pax: 50,  rng: 2800, yr: 1995, wake: "M" },
  "E170": { n: "Embraer 170",        s: "E170",   m: "Embraer", c: "regional",   r: "uncommon", ws: 26.0, ln: 29.9, mtow: 38,   crz: 447, eng: 2, et: "Jet", pax: 76,  rng: 3900, yr: 2002, wake: "M" },
  "E75S": { n: "Embraer 175 (short wing)", s: "E175", m: "Embraer", c: "regional", r: "common", ws: 26.0, ln: 31.7, mtow: 40,  crz: 447, eng: 2, et: "Jet", pax: 78,  rng: 3300, yr: 2003, wake: "M" },
  "E75L": { n: "Embraer 175",        s: "E175",   m: "Embraer", c: "regional",   r: "common",   ws: 28.7, ln: 31.7, mtow: 40,   crz: 447, eng: 2, et: "Jet", pax: 78,  rng: 3900, yr: 2003, wake: "M" },
  "E190": { n: "Embraer 190",        s: "E190",   m: "Embraer", c: "regional",   r: "common",   ws: 28.7, ln: 36.2, mtow: 51,   crz: 447, eng: 2, et: "Jet", pax: 100, rng: 4500, yr: 2004, wake: "M" },
  "E195": { n: "Embraer 195",        s: "E195",   m: "Embraer", c: "regional",   r: "uncommon", ws: 28.7, ln: 38.7, mtow: 52,   crz: 447, eng: 2, et: "Jet", pax: 120, rng: 4260, yr: 2004, wake: "M" },
  "E290": { n: "Embraer E190-E2",    s: "E190-E2", m: "Embraer", c: "regional",  r: "uncommon", ws: 33.7, ln: 36.2, mtow: 56,   crz: 448, eng: 2, et: "Jet", pax: 106, rng: 5280, yr: 2016, wake: "M" },
  "E295": { n: "Embraer E195-E2",    s: "E195-E2", m: "Embraer", c: "regional",  r: "uncommon", ws: 35.1, ln: 41.5, mtow: 61.5, crz: 448, eng: 2, et: "Jet", pax: 132, rng: 4800, yr: 2017, wake: "M" },
  "CRJ2": { n: "Bombardier CRJ200",  s: "CRJ200", m: "Bombardier", c: "regional", r: "common",  ws: 21.2, ln: 26.8, mtow: 24,   crz: 424, eng: 2, et: "Jet", pax: 50,  rng: 3150, yr: 1991, wake: "M" },
  "CRJ7": { n: "Bombardier CRJ700",  s: "CRJ700", m: "Bombardier", c: "regional", r: "common",  ws: 23.2, ln: 32.5, mtow: 33,   crz: 447, eng: 2, et: "Jet", pax: 70,  rng: 3620, yr: 1999, wake: "M" },
  "CRJ9": { n: "Bombardier CRJ900",  s: "CRJ900", m: "Bombardier", c: "regional", r: "common",  ws: 24.9, ln: 36.4, mtow: 38,   crz: 447, eng: 2, et: "Jet", pax: 88,  rng: 2880, yr: 2001, wake: "M" },
  "CRJX": { n: "Bombardier CRJ1000", s: "CRJ1000", m: "Bombardier", c: "regional", r: "rare",   ws: 26.2, ln: 39.1, mtow: 42,   crz: 447, eng: 2, et: "Jet", pax: 104, rng: 3130, yr: 2008, wake: "M" },
  "BCS1": { n: "Airbus A220-100",    s: "A220-100", m: "Airbus", c: "regional",  r: "uncommon", ws: 35.1, ln: 35.0, mtow: 63.1, crz: 447, eng: 2, et: "Jet", pax: 125, rng: 6390, yr: 2013, wake: "M" },
  "BCS3": { n: "Airbus A220-300",    s: "A220-300", m: "Airbus", c: "regional",  r: "uncommon", ws: 35.1, ln: 38.7, mtow: 70.9, crz: 447, eng: 2, et: "Jet", pax: 160, rng: 6400, yr: 2015, wake: "M" },

  // ---- Turboprops ----------------------------------------------
  "AT43": { n: "ATR 42-300/320",     s: "ATR 42", m: "ATR",     c: "turboprop", r: "uncommon", ws: 24.6, ln: 22.7, mtow: 16.9, crz: 265, eng: 2, et: "Turboprop", pax: 48, rng: 1560, yr: 1984, wake: "M" },
  "AT45": { n: "ATR 42-500",         s: "ATR 42", m: "ATR",     c: "turboprop", r: "uncommon", ws: 24.6, ln: 22.7, mtow: 18.6, crz: 300, eng: 2, et: "Turboprop", pax: 48, rng: 1560, yr: 1995, wake: "M" },
  "AT72": { n: "ATR 72",             s: "ATR 72", m: "ATR",     c: "turboprop", r: "common",   ws: 27.1, ln: 27.2, mtow: 22.8, crz: 275, eng: 2, et: "Turboprop", pax: 72, rng: 1520, yr: 1988, wake: "M" },
  "AT75": { n: "ATR 72-500",         s: "ATR 72", m: "ATR",     c: "turboprop", r: "common",   ws: 27.1, ln: 27.2, mtow: 22.8, crz: 275, eng: 2, et: "Turboprop", pax: 72, rng: 1520, yr: 1997, wake: "M" },
  "AT76": { n: "ATR 72-600",         s: "ATR 72", m: "ATR",     c: "turboprop", r: "common",   ws: 27.1, ln: 27.2, mtow: 23,   crz: 275, eng: 2, et: "Turboprop", pax: 72, rng: 1580, yr: 2010, wake: "M" },
  "DH8A": { n: "De Havilland Dash 8-100", s: "Dash 8-100", m: "De Havilland Canada", c: "turboprop", r: "uncommon", ws: 25.9, ln: 22.3, mtow: 15.6, crz: 268, eng: 2, et: "Turboprop", pax: 39, rng: 1890, yr: 1983, wake: "M" },
  "DH8C": { n: "De Havilland Dash 8-300", s: "Dash 8-300", m: "De Havilland Canada", c: "turboprop", r: "uncommon", ws: 27.4, ln: 25.7, mtow: 19.5, crz: 287, eng: 2, et: "Turboprop", pax: 50, rng: 1700, yr: 1987, wake: "M" },
  "DH8D": { n: "Bombardier Dash 8 Q400", s: "Q400", m: "De Havilland Canada", c: "turboprop", r: "common", ws: 28.4, ln: 32.8, mtow: 29.6, crz: 360, eng: 2, et: "Turboprop", pax: 78, rng: 2040, yr: 1998, wake: "M" },
  "DHC6": { n: "DHC-6 Twin Otter",   s: "Twin Otter", m: "De Havilland Canada", c: "turboprop", r: "uncommon", ws: 19.8, ln: 15.8, mtow: 5.7, crz: 150, eng: 2, et: "Turboprop", pax: 19, rng: 1480, yr: 1965, wake: "L" },
  "SF34": { n: "Saab 340",           s: "Saab 340", m: "Saab",  c: "turboprop", r: "uncommon", ws: 21.4, ln: 19.7, mtow: 13.2, crz: 250, eng: 2, et: "Turboprop", pax: 34, rng: 1730, yr: 1983, wake: "M" },
  "SB20": { n: "Saab 2000",          s: "Saab 2000", m: "Saab", c: "turboprop", r: "rare",     ws: 24.8, ln: 27.3, mtow: 22.8, crz: 370, eng: 2, et: "Turboprop", pax: 50, rng: 2870, yr: 1992, wake: "M" },
  "JS41": { n: "BAe Jetstream 41",   s: "Jetstream 41", m: "BAe", c: "turboprop", r: "rare",   ws: 18.3, ln: 19.3, mtow: 10.9, crz: 295, eng: 2, et: "Turboprop", pax: 29, rng: 1400, yr: 1991, wake: "L" },
  "B190": { n: "Beechcraft 1900D",   s: "1900D",  m: "Beechcraft", c: "turboprop", r: "uncommon", ws: 17.6, ln: 17.6, mtow: 7.7, crz: 280, eng: 2, et: "Turboprop", pax: 19, rng: 1500, yr: 1982, wake: "L" },
  "C208": { n: "Cessna 208 Caravan", s: "Caravan", m: "Cessna", c: "turboprop", r: "common",   ws: 15.9, ln: 12.7, mtow: 3.6, crz: 186, eng: 1, et: "Turboprop", pax: 9, rng: 1980, yr: 1982, wake: "L" },
  "PC12": { n: "Pilatus PC-12",      s: "PC-12",  m: "Pilatus", c: "turboprop", r: "common",   ws: 16.3, ln: 14.4, mtow: 4.7, crz: 280, eng: 1, et: "Turboprop", pax: 9,  rng: 3400, yr: 1991, wake: "L" },
  "TBM7": { n: "Socata TBM 700",     s: "TBM 700", m: "Daher",  c: "turboprop", r: "uncommon", ws: 12.7, ln: 10.6, mtow: 3.0, crz: 300, eng: 1, et: "Turboprop", pax: 6, rng: 2800, yr: 1988, wake: "L" },
  "TBM9": { n: "Daher TBM 900/930/940", s: "TBM 9xx", m: "Daher", c: "turboprop", r: "uncommon", ws: 12.8, ln: 10.7, mtow: 3.4, crz: 330, eng: 1, et: "Turboprop", pax: 6, rng: 3300, yr: 2013, wake: "L" },
  "EPIC": { n: "Epic E1000",         s: "E1000",  m: "Epic",    c: "turboprop", r: "rare",     ws: 13.1, ln: 10.9, mtow: 3.6, crz: 333, eng: 1, et: "Turboprop", pax: 5, rng: 3330, yr: 2015, wake: "L" },
  "SW4": { n: "Fairchild Metro / Merlin", s: "Metroliner", m: "Fairchild", c: "turboprop", r: "uncommon", ws: 17.4, ln: 18.1, mtow: 7.5, crz: 280, eng: 2, et: "Turboprop", pax: 19, rng: 2130, yr: 1969, wake: "L" },
  "F27": { n: "Fokker F27 Friendship", s: "F27", m: "Fokker",  c: "turboprop", r: "exotic",   ws: 29.0, ln: 25.1, mtow: 20.4, crz: 259, eng: 2, et: "Turboprop", pax: 44, rng: 1930, yr: 1955, wake: "M" },
  "F50": { n: "Fokker 50",           s: "F50",    m: "Fokker",  c: "turboprop", r: "rare",     ws: 29.0, ln: 25.2, mtow: 20.8, crz: 282, eng: 2, et: "Turboprop", pax: 58, rng: 2050, yr: 1985, wake: "M" },

  // ---- Piston / light GA --------------------------------------
  "C152": { n: "Cessna 152",         s: "152",    m: "Cessna",  c: "piston",    r: "common",   ws: 10.2, ln: 7.3,  mtow: 0.76, crz: 107, eng: 1, et: "Piston", pax: 2, rng: 780, yr: 1977, wake: "L" },
  "C172": { n: "Cessna 172 Skyhawk", s: "172",    m: "Cessna",  c: "piston",    r: "common",   ws: 11.0, ln: 8.3,  mtow: 1.16, crz: 122, eng: 1, et: "Piston", pax: 3, rng: 1290, yr: 1955, wake: "L" },
  "C72R": { n: "Cessna 172RG Cutlass", s: "172RG", m: "Cessna", c: "piston",    r: "uncommon", ws: 11.0, ln: 8.3,  mtow: 1.2, crz: 140, eng: 1, et: "Piston", pax: 3, rng: 1360, yr: 1980, wake: "L" },
  "C82R": { n: "Cessna 182RG",       s: "182RG",  m: "Cessna",  c: "piston",    r: "uncommon", ws: 10.9, ln: 8.8,  mtow: 1.4, crz: 156, eng: 1, et: "Piston", pax: 3, rng: 1500, yr: 1978, wake: "L" },
  "C182": { n: "Cessna 182 Skylane", s: "182",    m: "Cessna",  c: "piston",    r: "common",   ws: 11.0, ln: 8.8,  mtow: 1.4, crz: 145, eng: 1, et: "Piston", pax: 3, rng: 1720, yr: 1956, wake: "L" },
  "C206": { n: "Cessna 206 Stationair", s: "206", m: "Cessna",  c: "piston",    r: "common",   ws: 10.9, ln: 8.6,  mtow: 1.6, crz: 142, eng: 1, et: "Piston", pax: 5, rng: 1350, yr: 1962, wake: "L" },
  "C210": { n: "Cessna 210 Centurion", s: "210",  m: "Cessna",  c: "piston",    r: "uncommon", ws: 11.2, ln: 8.6,  mtow: 1.7, crz: 170, eng: 1, et: "Piston", pax: 5, rng: 1670, yr: 1957, wake: "L" },
  "C310": { n: "Cessna 310",         s: "310",    m: "Cessna",  c: "piston",    r: "uncommon", ws: 11.3, ln: 9.7,  mtow: 2.4, crz: 190, eng: 2, et: "Piston", pax: 5, rng: 2800, yr: 1953, wake: "L" },
  "T206": { n: "Cessna T206 Turbo Stationair", s: "T206", m: "Cessna", c: "piston", r: "common",   ws: 10.9, ln: 8.6, mtow: 1.6, crz: 164, eng: 1, et: "Piston", pax: 6, rng: 1200, yr: 1966, wake: "L" },
  "P210": { n: "Cessna P210 Pressurized Centurion", s: "P210", m: "Cessna", c: "piston", r: "uncommon", ws: 11.9, ln: 8.8, mtow: 1.8, crz: 190, eng: 1, et: "Piston", pax: 5, rng: 1900, yr: 1978, wake: "L" },
  "C77R": { n: "Cessna 177RG Cardinal RG", s: "177RG", m: "Cessna", c: "piston", r: "uncommon", ws: 10.8, ln: 8.4, mtow: 1.3, crz: 148, eng: 1, et: "Piston", pax: 3, rng: 1500, yr: 1970, wake: "L" },
  "BE35": { n: "Beechcraft Bonanza 35 (V-tail)", s: "V35", m: "Beechcraft", c: "piston", r: "uncommon", ws: 10.2, ln: 8.0, mtow: 1.5, crz: 170, eng: 1, et: "Piston", pax: 3, rng: 1300, yr: 1947, wake: "L" },
  "E300": { n: "Extra EA-300 (aerobatic)", s: "Extra 300", m: "Extra", c: "piston", r: "uncommon", ws: 8.0, ln: 6.7, mtow: 0.95, crz: 190, eng: 1, et: "Piston", pax: 1, rng: 900, yr: 1988, wake: "L" },
  "P28A": { n: "Piper PA-28 Cherokee / Archer", s: "PA-28", m: "Piper", c: "piston", r: "common", ws: 10.7, ln: 7.3, mtow: 1.2, crz: 118, eng: 1, et: "Piston", pax: 3, rng: 990, yr: 1960, wake: "L" },
  "P28R": { n: "Piper PA-28R Arrow", s: "PA-28R", m: "Piper", c: "piston",    r: "uncommon", ws: 10.8, ln: 7.5,  mtow: 1.2, crz: 137, eng: 1, et: "Piston", pax: 3, rng: 1390, yr: 1967, wake: "L" },
  "PA44": { n: "Piper PA-44 Seminole", s: "PA-44", m: "Piper", c: "piston",    r: "uncommon", ws: 11.8, ln: 8.4,  mtow: 1.7, crz: 145, eng: 2, et: "Piston", pax: 3, rng: 1500, yr: 1976, wake: "L" },
  "PA34": { n: "Piper PA-34 Seneca", s: "PA-34",  m: "Piper",   c: "piston",    r: "uncommon", ws: 11.9, ln: 8.7,  mtow: 2.1, crz: 165, eng: 2, et: "Piston", pax: 5, rng: 1500, yr: 1971, wake: "L" },
  "PA46": { n: "Piper PA-46 Malibu / Mirage", s: "PA-46", m: "Piper", c: "piston", r: "uncommon", ws: 13.1, ln: 8.7, mtow: 1.9, crz: 175, eng: 1, et: "Piston", pax: 5, rng: 2500, yr: 1979, wake: "L" },
  "BE33": { n: "Beechcraft Bonanza 33", s: "Bonanza", m: "Beechcraft", c: "piston", r: "uncommon", ws: 10.2, ln: 8.1, mtow: 1.5, crz: 160, eng: 1, et: "Piston", pax: 3, rng: 1360, yr: 1959, wake: "L" },
  "BE36": { n: "Beechcraft Bonanza 36", s: "Bonanza", m: "Beechcraft", c: "piston", r: "common", ws: 10.2, ln: 8.4, mtow: 1.7, crz: 165, eng: 1, et: "Piston", pax: 5, rng: 1400, yr: 1968, wake: "L" },
  "BE58": { n: "Beechcraft Baron 58", s: "Baron",   m: "Beechcraft", c: "piston", r: "uncommon", ws: 11.5, ln: 9.1, mtow: 2.4, crz: 200, eng: 2, et: "Piston", pax: 5, rng: 2780, yr: 1969, wake: "L" },
  "SR20": { n: "Cirrus SR20",        s: "SR20",   m: "Cirrus",  c: "piston",    r: "common",   ws: 11.7, ln: 7.9,  mtow: 1.4, crz: 155, eng: 1, et: "Piston", pax: 4, rng: 1200, yr: 1995, wake: "L" },
  "SR22": { n: "Cirrus SR22",        s: "SR22",   m: "Cirrus",  c: "piston",    r: "common",   ws: 11.7, ln: 7.9,  mtow: 1.6, crz: 180, eng: 1, et: "Piston", pax: 4, rng: 2000, yr: 2000, wake: "L" },
  "S22T": { n: "Cirrus SR22T",       s: "SR22T",  m: "Cirrus",  c: "piston",    r: "common",   ws: 11.7, ln: 7.9,  mtow: 1.6, crz: 213, eng: 1, et: "Piston", pax: 4, rng: 2100, yr: 2010, wake: "L" },
  "DA40": { n: "Diamond DA40 Star",  s: "DA40",   m: "Diamond", c: "piston",    r: "common",   ws: 11.9, ln: 8.1,  mtow: 1.2, crz: 150, eng: 1, et: "Piston", pax: 3, rng: 1300, yr: 1997, wake: "L" },
  "DA42": { n: "Diamond DA42 Twin Star", s: "DA42", m: "Diamond", c: "piston",  r: "uncommon", ws: 13.4, ln: 8.6,  mtow: 1.9, crz: 170, eng: 2, et: "Piston", pax: 3, rng: 2260, yr: 2002, wake: "L" },
  "DA62": { n: "Diamond DA62",       s: "DA62",   m: "Diamond", c: "piston",    r: "uncommon", ws: 14.6, ln: 9.2,  mtow: 2.3, crz: 192, eng: 2, et: "Piston", pax: 7, rng: 2400, yr: 2015, wake: "L" },
  "M20P": { n: "Mooney M20",         s: "M20",    m: "Mooney",  c: "piston",    r: "uncommon", ws: 11.0, ln: 8.2,  mtow: 1.5, crz: 175, eng: 1, et: "Piston", pax: 3, rng: 1600, yr: 1955, wake: "L" },
  "RV7":  { n: "Van's RV-7",         s: "RV-7",   m: "Van's",   c: "piston",    r: "uncommon", ws: 7.6,  ln: 6.2,  mtow: 0.82, crz: 165, eng: 1, et: "Piston", pax: 1, rng: 1500, yr: 2001, wake: "L" },
  "RV10": { n: "Van's RV-10",        s: "RV-10",  m: "Van's",   c: "piston",    r: "uncommon", ws: 9.8,  ln: 7.4,  mtow: 1.2, crz: 168, eng: 1, et: "Piston", pax: 3, rng: 1400, yr: 2003, wake: "L" },
  "BE18": { n: "Beechcraft Model 18", s: "Twin Beech", m: "Beechcraft", c: "vintage", r: "rare", ws: 14.5, ln: 10.4, mtow: 4.5, crz: 150, eng: 2, et: "Piston", pax: 8, rng: 1200, yr: 1937, wake: "L" },
  "S108": { n: "Stinson 108 Voyager", s: "Stinson 108", m: "Stinson", c: "vintage", r: "rare", ws: 10.4, ln: 7.6, mtow: 1.1, crz: 105, eng: 1, et: "Piston", pax: 3, rng: 800, yr: 1946, wake: "L" },
  "NAVI": { n: "Ryan Navion", s: "Navion", m: "Ryan", c: "vintage", r: "rare", ws: 10.4, ln: 8.4, mtow: 1.4, crz: 130, eng: 1, et: "Piston", pax: 3, rng: 1000, yr: 1947, wake: "L" },

  // ---- Business jets / King Air --------------------------------
  "BE20": { n: "Beechcraft King Air 200", s: "King Air 200", m: "Beechcraft", c: "turboprop", r: "common", ws: 16.6, ln: 13.4, mtow: 5.7, crz: 289, eng: 2, et: "Turboprop", pax: 8, rng: 3300, yr: 1972, wake: "L" },
  "BE9L": { n: "Beechcraft King Air 90", s: "King Air 90", m: "Beechcraft", c: "turboprop", r: "common", ws: 15.3, ln: 10.8, mtow: 4.6, crz: 247, eng: 2, et: "Turboprop", pax: 6, rng: 2000, yr: 1963, wake: "L" },
  "B350": { n: "Beechcraft King Air 350", s: "King Air 350", m: "Beechcraft", c: "turboprop", r: "common", ws: 17.7, ln: 14.2, mtow: 6.8, crz: 312, eng: 2, et: "Turboprop", pax: 11, rng: 3340, yr: 1988, wake: "L" },
  "C25A": { n: "Cessna CitationJet CJ2", s: "CJ2", m: "Cessna", c: "business", r: "common",  ws: 15.2, ln: 14.2, mtow: 5.6, crz: 410, eng: 2, et: "Jet", pax: 7, rng: 3200, yr: 1999, wake: "L" },
  "C25B": { n: "Cessna Citation CJ3",  s: "CJ3",   m: "Cessna", c: "business", r: "common",  ws: 16.3, ln: 15.6, mtow: 6.3, crz: 416, eng: 2, et: "Jet", pax: 8, rng: 3780, yr: 2002, wake: "L" },
  "C25C": { n: "Cessna Citation CJ4",  s: "CJ4",   m: "Cessna", c: "business", r: "common",  ws: 15.5, ln: 16.3, mtow: 7.8, crz: 451, eng: 2, et: "Jet", pax: 9, rng: 3710, yr: 2008, wake: "L" },
  "C56X": { n: "Cessna Citation Excel / XLS", s: "Citation XLS", m: "Cessna", c: "business", r: "common", ws: 17.2, ln: 15.8, mtow: 9.2, crz: 433, eng: 2, et: "Jet", pax: 9, rng: 3700, yr: 1996, wake: "M" },
  "C680": { n: "Cessna Citation Sovereign", s: "Sovereign", m: "Cessna", c: "business", r: "uncommon", ws: 19.4, ln: 19.4, mtow: 13.6, crz: 458, eng: 2, et: "Jet", pax: 12, rng: 5560, yr: 2002, wake: "M" },
  "C68A": { n: "Cessna Citation Latitude", s: "Latitude", m: "Cessna", c: "business", r: "uncommon", ws: 22.0, ln: 19.0, mtow: 13.9, crz: 446, eng: 2, et: "Jet", pax: 9, rng: 5200, yr: 2014, wake: "M" },
  "C750": { n: "Cessna Citation X",    s: "Citation X", m: "Cessna", c: "business", r: "uncommon", ws: 19.4, ln: 22.0, mtow: 16.4, crz: 527, eng: 2, et: "Jet", pax: 12, rng: 6400, yr: 1993, wake: "M" },
  "E50P": { n: "Embraer Phenom 100",   s: "Phenom 100", m: "Embraer", c: "business", r: "common", ws: 12.3, ln: 12.8, mtow: 4.8, crz: 390, eng: 2, et: "Jet", pax: 5, rng: 2180, yr: 2007, wake: "L" },
  "E55P": { n: "Embraer Phenom 300",   s: "Phenom 300", m: "Embraer", c: "business", r: "common", ws: 15.9, ln: 15.6, mtow: 8.2, crz: 453, eng: 2, et: "Jet", pax: 9, rng: 3650, yr: 2008, wake: "L" },
  "LJ35": { n: "Learjet 35",           s: "Learjet 35", m: "Learjet", c: "business", r: "uncommon", ws: 12.0, ln: 14.8, mtow: 8.3, crz: 460, eng: 2, et: "Jet", pax: 8, rng: 4070, yr: 1973, wake: "L" },
  "LJ45": { n: "Learjet 45",           s: "Learjet 45", m: "Learjet", c: "business", r: "uncommon", ws: 14.6, ln: 17.7, mtow: 9.5, crz: 464, eng: 2, et: "Jet", pax: 9, rng: 3800, yr: 1995, wake: "L" },
  "LJ60": { n: "Learjet 60",           s: "Learjet 60", m: "Learjet", c: "business", r: "uncommon", ws: 13.3, ln: 17.9, mtow: 10.7, crz: 466, eng: 2, et: "Jet", pax: 8, rng: 4600, yr: 1990, wake: "M" },
  "GLF4": { n: "Gulfstream IV / G450",  s: "G-IV",   m: "Gulfstream", c: "business", r: "uncommon", ws: 23.7, ln: 27.4, mtow: 33.8, crz: 476, eng: 2, et: "Jet", pax: 16, rng: 8060, yr: 1985, wake: "M" },
  "GLF5": { n: "Gulfstream V / G550",   s: "G550",   m: "Gulfstream", c: "business", r: "uncommon", ws: 28.5, ln: 29.4, mtow: 41.3, crz: 488, eng: 2, et: "Jet", pax: 16, rng: 12500, yr: 1995, wake: "M" },
  "GLF6": { n: "Gulfstream G650",       s: "G650",   m: "Gulfstream", c: "business", r: "uncommon", ws: 30.4, ln: 30.4, mtow: 45.4, crz: 516, eng: 2, et: "Jet", pax: 18, rng: 13890, yr: 2009, wake: "M" },
  "GA5C": { n: "Gulfstream G500",       s: "G500",   m: "Gulfstream", c: "business", r: "rare",     ws: 26.3, ln: 27.8, mtow: 35.7, crz: 516, eng: 2, et: "Jet", pax: 13, rng: 9630, yr: 2015, wake: "M" },
  "GALX": { n: "IAI Gulfstream G200 Galaxy", s: "G200", m: "Gulfstream", c: "business", r: "uncommon", ws: 17.7, ln: 18.9, mtow: 16.1, crz: 470, eng: 2, et: "Jet", pax: 10, rng: 6300, yr: 1997, wake: "M" },
  "CL30": { n: "Bombardier Challenger 300/350", s: "Challenger 350", m: "Bombardier", c: "business", r: "common", ws: 21.0, ln: 20.9, mtow: 18.4, crz: 470, eng: 2, et: "Jet", pax: 9, rng: 6300, yr: 2001, wake: "M" },
  "CL60": { n: "Bombardier Challenger 600 series", s: "Challenger 605", m: "Bombardier", c: "business", r: "uncommon", ws: 19.6, ln: 20.9, mtow: 21.9, crz: 459, eng: 2, et: "Jet", pax: 12, rng: 7400, yr: 1978, wake: "M" },
  "GLEX": { n: "Bombardier Global Express / 6000", s: "Global 6000", m: "Bombardier", c: "business", r: "uncommon", ws: 28.7, ln: 30.3, mtow: 45.1, crz: 488, eng: 2, et: "Jet", pax: 17, rng: 11100, yr: 1996, wake: "M" },
  "GL7T": { n: "Bombardier Global 7500", s: "Global 7500", m: "Bombardier", c: "business", r: "rare", ws: 31.7, ln: 33.8, mtow: 51.7, crz: 516, eng: 2, et: "Jet", pax: 19, rng: 14260, yr: 2016, wake: "M" },
  "F2TH": { n: "Dassault Falcon 2000", s: "Falcon 2000", m: "Dassault", c: "business", r: "uncommon", ws: 19.3, ln: 20.2, mtow: 16.6, crz: 470, eng: 2, et: "Jet", pax: 10, rng: 6000, yr: 1993, wake: "M" },
  "FA7X": { n: "Dassault Falcon 7X",   s: "Falcon 7X", m: "Dassault", c: "business", r: "rare",   ws: 26.2, ln: 23.4, mtow: 31.3, crz: 488, eng: 3, et: "Jet", pax: 14, rng: 11000, yr: 2005, wake: "M" },
  "H25B": { n: "Hawker 800 / 900XP",   s: "Hawker 800", m: "Hawker", c: "business", r: "uncommon", ws: 15.7, ln: 15.6, mtow: 12.7, crz: 447, eng: 2, et: "Jet", pax: 8, rng: 5000, yr: 1983, wake: "M" },
  "PRM1": { n: "Beechcraft Premier I", s: "Premier I", m: "Beechcraft", c: "business", r: "rare", ws: 13.6, ln: 14.0, mtow: 5.7, crz: 450, eng: 2, et: "Jet", pax: 6, rng: 2760, yr: 1998, wake: "L" },
  "HDJT": { n: "Honda HA-420 HondaJet", s: "HondaJet", m: "Honda", c: "business", r: "uncommon", ws: 12.1, ln: 12.7, mtow: 4.8, crz: 422, eng: 2, et: "Jet", pax: 5, rng: 2260, yr: 2003, wake: "L" },
  "FA20": { n: "Dassault Falcon 20", s: "Falcon 20", m: "Dassault", c: "business", r: "uncommon", ws: 16.3, ln: 17.2, mtow: 13.0, crz: 465, eng: 2, et: "Jet", pax: 9, rng: 3300, yr: 1963, wake: "M" },
  "F900": { n: "Dassault Falcon 900", s: "Falcon 900", m: "Dassault", c: "business", r: "uncommon", ws: 19.3, ln: 20.2, mtow: 20.6, crz: 480, eng: 3, et: "Jet", pax: 12, rng: 7400, yr: 1984, wake: "M" },
  "CL35": { n: "Bombardier Challenger 350", s: "Challenger 350", m: "Bombardier", c: "business", r: "common", ws: 21.0, ln: 20.9, mtow: 18.4, crz: 470, eng: 2, et: "Jet", pax: 9, rng: 6300, yr: 2013, wake: "M" },

  // ---- Helicopters -------------------------------------------
  "R22":  { n: "Robinson R22",        s: "R22",    m: "Robinson", c: "heli",    r: "common",   ws: 7.7,  ln: 8.8,  mtow: 0.62, crz: 96,  eng: 1, et: "Piston", pax: 1, rng: 390, yr: 1975, wake: "L" },
  "R44":  { n: "Robinson R44",        s: "R44",    m: "Robinson", c: "heli",    r: "common",   ws: 10.0, ln: 11.7, mtow: 1.1, crz: 109, eng: 1, et: "Piston", pax: 3, rng: 560, yr: 1990, wake: "L" },
  "R66":  { n: "Robinson R66",        s: "R66",    m: "Robinson", c: "heli",    r: "uncommon", ws: 10.1, ln: 11.7, mtow: 1.2, crz: 110, eng: 1, et: "Turboprop", pax: 4, rng: 650, yr: 2007, wake: "L" },
  "B06":  { n: "Bell 206 JetRanger",  s: "Bell 206", m: "Bell", c: "heli",     r: "common",   ws: 10.2, ln: 11.8, mtow: 1.5, crz: 115, eng: 1, et: "Turboprop", pax: 4, rng: 690, yr: 1962, wake: "L" },
  "B407": { n: "Bell 407",            s: "Bell 407", m: "Bell", c: "heli",     r: "uncommon", ws: 10.7, ln: 12.7, mtow: 2.7, crz: 133, eng: 1, et: "Turboprop", pax: 6, rng: 610, yr: 1994, wake: "L" },
  "B429": { n: "Bell 429",            s: "Bell 429", m: "Bell", c: "heli",     r: "uncommon", ws: 11.0, ln: 13.1, mtow: 3.4, crz: 150, eng: 2, et: "Turboprop", pax: 7, rng: 690, yr: 2007, wake: "L" },
  "AS50": { n: "Airbus AS350 Écureuil", s: "AS350", m: "Airbus", c: "heli",    r: "common",   ws: 10.7, ln: 12.9, mtow: 2.5, crz: 133, eng: 1, et: "Turboprop", pax: 5, rng: 660, yr: 1974, wake: "L" },
  "EC30": { n: "Airbus H130",         s: "H130",   m: "Airbus", c: "heli",     r: "uncommon", ws: 10.7, ln: 12.6, mtow: 2.5, crz: 130, eng: 1, et: "Turboprop", pax: 7, rng: 610, yr: 1999, wake: "L" },
  "EC35": { n: "Airbus H135",         s: "H135",   m: "Airbus", c: "heli",     r: "uncommon", ws: 10.2, ln: 12.2, mtow: 2.9, crz: 137, eng: 2, et: "Turboprop", pax: 7, rng: 620, yr: 1994, wake: "L" },
  "EC45": { n: "Airbus H145",         s: "H145",   m: "Airbus", c: "heli",     r: "uncommon", ws: 11.0, ln: 13.6, mtow: 3.7, crz: 133, eng: 2, et: "Turboprop", pax: 9, rng: 660, yr: 1999, wake: "L" },
  "A109": { n: "Leonardo AW109",      s: "AW109",  m: "Leonardo", c: "heli",   r: "uncommon", ws: 11.0, ln: 13.0, mtow: 3.0, crz: 154, eng: 2, et: "Turboprop", pax: 7, rng: 860, yr: 1971, wake: "L" },
  "A139": { n: "Leonardo AW139",      s: "AW139",  m: "Leonardo", c: "heli",   r: "uncommon", ws: 13.8, ln: 16.7, mtow: 7.0, crz: 165, eng: 2, et: "Turboprop", pax: 15, rng: 1060, yr: 2001, wake: "L" },
  "S76":  { n: "Sikorsky S-76",       s: "S-76",   m: "Sikorsky", c: "heli",   r: "uncommon", ws: 13.4, ln: 16.0, mtow: 5.3, crz: 155, eng: 2, et: "Turboprop", pax: 12, rng: 830, yr: 1977, wake: "L" },
  "S92":  { n: "Sikorsky S-92",       s: "S-92",   m: "Sikorsky", c: "heli",   r: "rare",     ws: 17.2, ln: 20.9, mtow: 12.0, crz: 151, eng: 2, et: "Turboprop", pax: 19, rng: 1000, yr: 1998, wake: "M" },

  // ---- Military -------------------------------------------
  "C130": { n: "Lockheed C-130 Hercules", s: "C-130", m: "Lockheed", c: "military", r: "uncommon", ws: 40.4, ln: 29.8, mtow: 70.3, crz: 292, eng: 4, et: "Turboprop", pax: 92, rng: 3800, yr: 1954, wake: "M" },
  "C30J": { n: "Lockheed C-130J Super Hercules", s: "C-130J", m: "Lockheed", c: "military", r: "uncommon", ws: 40.4, ln: 34.4, mtow: 74.4, crz: 348, eng: 4, et: "Turboprop", pax: 92, rng: 5250, yr: 1996, wake: "M" },
  "C17":  { n: "Boeing C-17 Globemaster III", s: "C-17", m: "Boeing", c: "military", r: "rare", ws: 51.8, ln: 53.0, mtow: 265, crz: 450, eng: 4, et: "Jet", pax: 102, rng: 4480, yr: 1991, wake: "H" },
  "C5M":  { n: "Lockheed C-5M Super Galaxy", s: "C-5", m: "Lockheed", c: "military", r: "exotic", ws: 67.9, ln: 75.3, mtow: 381, crz: 450, eng: 4, et: "Jet", pax: 0, rng: 8000, yr: 1968, wake: "J" },
  "K35R": { n: "Boeing KC-135 Stratotanker", s: "KC-135", m: "Boeing", c: "military", r: "uncommon", ws: 39.9, ln: 41.5, mtow: 146, crz: 460, eng: 4, et: "Jet", pax: 0, rng: 2400, yr: 1956, wake: "H" },
  "KC10": { n: "McDonnell Douglas KC-10 Extender", s: "KC-10", m: "McDonnell Douglas", c: "military", r: "rare", ws: 50.4, ln: 55.4, mtow: 267, crz: 490, eng: 3, et: "Jet", pax: 0, rng: 7000, yr: 1980, wake: "H" },
  "K35J": { n: "Boeing KC-46 Pegasus", s: "KC-46", m: "Boeing", c: "military", r: "rare", ws: 47.6, ln: 50.5, mtow: 188, crz: 460, eng: 2, et: "Jet", pax: 0, rng: 12200, yr: 2015, wake: "H" },
  "P8":   { n: "Boeing P-8 Poseidon", s: "P-8", m: "Boeing", c: "military", r: "rare", ws: 37.6, ln: 39.5, mtow: 85.1, crz: 453, eng: 2, et: "Jet", pax: 0, rng: 8300, yr: 2009, wake: "M" },
  "E3TF": { n: "Boeing E-3 Sentry (AWACS)", s: "E-3", m: "Boeing", c: "military", r: "exotic", ws: 44.4, ln: 46.6, mtow: 148, crz: 430, eng: 4, et: "Jet", pax: 0, rng: 9250, yr: 1975, wake: "H" },
  "C40":  { n: "Boeing C-40 Clipper", s: "C-40", m: "Boeing", c: "military", r: "rare", ws: 34.3, ln: 33.6, mtow: 77.6, crz: 453, eng: 2, et: "Jet", pax: 121, rng: 8500, yr: 2001, wake: "M" },
  "C12":  { n: "Beechcraft C-12 Huron", s: "C-12", m: "Beechcraft", c: "military", r: "uncommon", ws: 16.6, ln: 13.4, mtow: 5.7, crz: 289, eng: 2, et: "Turboprop", pax: 8, rng: 3300, yr: 1974, wake: "L" },
  "F16":  { n: "General Dynamics F-16 Fighting Falcon", s: "F-16", m: "General Dynamics", c: "military", r: "rare", ws: 9.96, ln: 15.0, mtow: 19.2, crz: 530, eng: 1, et: "Jet", pax: 1, rng: 4220, yr: 1974, wake: "M" },
  "F15":  { n: "McDonnell Douglas F-15 Eagle", s: "F-15", m: "Boeing", c: "military", r: "rare", ws: 13.05, ln: 19.4, mtow: 30.8, crz: 570, eng: 2, et: "Jet", pax: 1, rng: 3450, yr: 1972, wake: "M" },
  "F18H": { n: "Boeing F/A-18E/F Super Hornet", s: "F/A-18", m: "Boeing", c: "military", r: "rare", ws: 13.62, ln: 18.3, mtow: 29.9, crz: 570, eng: 2, et: "Jet", pax: 1, rng: 3330, yr: 1995, wake: "M" },
  "F35":  { n: "Lockheed Martin F-35 Lightning II", s: "F-35", m: "Lockheed Martin", c: "military", r: "exotic", ws: 10.7, ln: 15.7, mtow: 31.8, crz: 570, eng: 1, et: "Jet", pax: 1, rng: 2800, yr: 2006, wake: "M" },
  "A10":  { n: "Fairchild A-10 Thunderbolt II", s: "A-10", m: "Fairchild", c: "military", r: "exotic", ws: 17.53, ln: 16.26, mtow: 23, crz: 300, eng: 2, et: "Jet", pax: 1, rng: 4150, yr: 1972, wake: "M" },
  "B52":  { n: "Boeing B-52 Stratofortress", s: "B-52", m: "Boeing", c: "military", r: "exotic", ws: 56.4, ln: 48.5, mtow: 220, crz: 442, eng: 8, et: "Jet", pax: 5, rng: 14080, yr: 1952, wake: "H" },
  "V22":  { n: "Bell Boeing V-22 Osprey", s: "V-22", m: "Bell Boeing", c: "military", r: "exotic", ws: 25.8, ln: 17.5, mtow: 27.4, crz: 240, eng: 2, et: "Turboprop", pax: 24, rng: 1630, yr: 1989, wake: "M" },
  "H60":  { n: "Sikorsky UH-60 Black Hawk", s: "UH-60", m: "Sikorsky", c: "military", r: "rare", ws: 16.4, ln: 19.8, mtow: 10.7, crz: 150, eng: 2, et: "Turboprop", pax: 11, rng: 590, yr: 1974, wake: "M" },
  "T6":   { n: "Beechcraft T-6 Texan II", s: "T-6", m: "Beechcraft", c: "military", r: "uncommon", ws: 10.2, ln: 10.2, mtow: 2.9, crz: 270, eng: 1, et: "Turboprop", pax: 2, rng: 1600, yr: 1998, wake: "L" },

  // ---- Vintage / classic ------------------------------------
  "DC3":  { n: "Douglas DC-3 / C-47",  s: "DC-3",   m: "Douglas", c: "vintage", r: "exotic",   ws: 29.0, ln: 19.7, mtow: 11.4, crz: 180, eng: 2, et: "Piston", pax: 28, rng: 2400, yr: 1935, wake: "M" },
  "DC6":  { n: "Douglas DC-6",         s: "DC-6",   m: "Douglas", c: "vintage", r: "exotic",   ws: 35.8, ln: 32.2, mtow: 48,  crz: 270, eng: 4, et: "Piston", pax: 100, rng: 4800, yr: 1946, wake: "M" },
  "CVLT": { n: "Convair CV-580 / 5800", s: "Convair 580", m: "Convair", c: "vintage", r: "exotic", ws: 32.1, ln: 24.8, mtow: 26.4, crz: 300, eng: 2, et: "Turboprop", pax: 52, rng: 2900, yr: 1960, wake: "M" },
  "P51":  { n: "North American P-51 Mustang", s: "P-51", m: "North American", c: "vintage", r: "exotic", ws: 11.28, ln: 9.83, mtow: 5.5, crz: 300, eng: 1, et: "Piston", pax: 1, rng: 2700, yr: 1940, wake: "L" },
  "T28":  { n: "North American T-28 Trojan", s: "T-28", m: "North American", c: "vintage", r: "rare", ws: 12.22, ln: 10.06, mtow: 3.9, crz: 190, eng: 1, et: "Piston", pax: 2, rng: 1600, yr: 1949, wake: "L" },
  "YK52": { n: "Yakovlev Yak-52",      s: "Yak-52", m: "Yakovlev", c: "vintage", r: "rare",    ws: 9.3,  ln: 7.75, mtow: 1.3, crz: 150, eng: 1, et: "Piston", pax: 2, rng: 500, yr: 1976, wake: "L" },
  "L188": { n: "Lockheed L-188 Electra", s: "L-188", m: "Lockheed", c: "vintage", r: "exotic", ws: 30.2, ln: 31.8, mtow: 52.7, crz: 324, eng: 4, et: "Turboprop", pax: 98, rng: 3540, yr: 1957, wake: "M" },

  // ---- Big Antonov / Ilyushin freighters ------------------
  "A124": { n: "Antonov An-124 Ruslan", s: "An-124", m: "Antonov", c: "military", r: "exotic", ws: 73.3, ln: 68.96, mtow: 405, crz: 432, eng: 4, et: "Jet", pax: 0, rng: 5400, yr: 1982, wake: "J" },
  "AN12": { n: "Antonov An-12",         s: "An-12",  m: "Antonov", c: "military", r: "exotic", ws: 38.0, ln: 33.1, mtow: 61,  crz: 359, eng: 4, et: "Turboprop", pax: 0, rng: 5700, yr: 1957, wake: "H" },
  "AN26": { n: "Antonov An-26",         s: "An-26",  m: "Antonov", c: "military", r: "exotic", ws: 29.2, ln: 23.8, mtow: 24,  crz: 235, eng: 2, et: "Turboprop", pax: 0, rng: 2550, yr: 1969, wake: "M" },
  "IL76": { n: "Ilyushin Il-76",        s: "Il-76",  m: "Ilyushin", c: "military", r: "exotic", ws: 50.5, ln: 46.6, mtow: 210, crz: 430, eng: 4, et: "Jet", pax: 0, rng: 4400, yr: 1971, wake: "H" }
}

// ICAO airline / operator prefix -> { n: name, c: radio callsign, y: country ISO }
var AIRLINES = {
  // ---- North America ----
  "AAL": { n: "American Airlines",  c: "American",   y: "US" },
  "UAL": { n: "United Airlines",    c: "United",     y: "US" },
  "DAL": { n: "Delta Air Lines",    c: "Delta",      y: "US" },
  "SWA": { n: "Southwest Airlines", c: "Southwest",  y: "US" },
  "ASA": { n: "Alaska Airlines",    c: "Alaska",     y: "US" },
  "JBU": { n: "JetBlue Airways",    c: "JetBlue",    y: "US" },
  "NKS": { n: "Spirit Airlines",    c: "Spirit Wings", y: "US" },
  "FFT": { n: "Frontier Airlines",  c: "Frontier Flight", y: "US" },
  "HAL": { n: "Hawaiian Airlines",  c: "Hawaiian",   y: "US" },
  "AAY": { n: "Allegiant Air",      c: "Allegiant",  y: "US" },
  "SCX": { n: "Sun Country Airlines", c: "Sun Country", y: "US" },
  "SKW": { n: "SkyWest Airlines",   c: "SkyWest",    y: "US" },
  "RPA": { n: "Republic Airways",   c: "Brickyard",  y: "US" },
  "ENY": { n: "Envoy Air",          c: "Envoy",      y: "US" },
  "EDV": { n: "Endeavor Air",       c: "Endeavor",   y: "US" },
  "JIA": { n: "PSA Airlines",       c: "Blue Streak", y: "US" },
  "ASH": { n: "Mesa Airlines",      c: "Air Shuttle", y: "US" },
  "GJS": { n: "GoJet Airlines",     c: "Lindbergh",  y: "US" },
  "QXE": { n: "Horizon Air",        c: "Horizon Air", y: "US" },
  "FDX": { n: "FedEx Express",      c: "FedEx",      y: "US" },
  "UPS": { n: "UPS Airlines",       c: "UPS",        y: "US" },
  "GTI": { n: "Atlas Air",          c: "Giant",      y: "US" },
  "ABX": { n: "ABX Air",            c: "Abex",       y: "US" },
  "CKS": { n: "Kalitta Air",        c: "Connie",     y: "US" },
  "AJT": { n: "Amerijet International", c: "Amerijet", y: "US" },
  "ACA": { n: "Air Canada",         c: "Air Canada", y: "CA" },
  "JZA": { n: "Air Canada Jazz",    c: "Jazz",       y: "CA" },
  "ROU": { n: "Air Canada Rouge",   c: "Rouge",      y: "CA" },
  "WJA": { n: "WestJet",            c: "WestJet",    y: "CA" },
  "WSW": { n: "Swoop",              c: "Swoop",      y: "CA" },
  "POE": { n: "Porter Airlines",    c: "Porter",     y: "CA" },
  "TSC": { n: "Air Transat",        c: "Transat",    y: "CA" },
  "AMX": { n: "Aeroméxico",         c: "Aeromexico", y: "MX" },
  "VOI": { n: "Volaris",            c: "Volaris",    y: "MX" },
  "VIV": { n: "Viva Aerobus",       c: "Aerobus",    y: "MX" },

  // ---- Europe ----
  "BAW": { n: "British Airways",    c: "Speedbird",  y: "GB" },
  "SHT": { n: "British Airways Shuttle", c: "Shuttle", y: "GB" },
  "EZY": { n: "easyJet",            c: "Easy",       y: "GB" },
  "EXS": { n: "Jet2",               c: "Channex",    y: "GB" },
  "TOM": { n: "TUI Airways",        c: "TOM Jet",    y: "GB" },
  "VIR": { n: "Virgin Atlantic",    c: "Virgin",     y: "GB" },
  "RYR": { n: "Ryanair",            c: "Ryanair",    y: "IE" },
  "EIN": { n: "Aer Lingus",         c: "Shamrock",   y: "IE" },
  "DLH": { n: "Lufthansa",          c: "Lufthansa",  y: "DE" },
  "CLH": { n: "Lufthansa CityLine", c: "Hansaline",  y: "DE" },
  "GEC": { n: "Lufthansa Cargo",    c: "Lufthansa Cargo", y: "DE" },
  "EWG": { n: "Eurowings",          c: "Eurowings",  y: "DE" },
  "CFG": { n: "Condor",             c: "Condor",     y: "DE" },
  "AFR": { n: "Air France",         c: "Airfrans",   y: "FR" },
  "KLM": { n: "KLM Royal Dutch Airlines", c: "KLM",  y: "NL" },
  "TRA": { n: "Transavia",          c: "Transavia",  y: "NL" },
  "IBE": { n: "Iberia",             c: "Iberia",     y: "ES" },
  "IBS": { n: "Iberia Express",     c: "Ibexpress",  y: "ES" },
  "VLG": { n: "Vueling",            c: "Vueling",    y: "ES" },
  "AEA": { n: "Air Europa",         c: "Europa",     y: "ES" },
  "RAM": { n: "Royal Air Maroc",    c: "Royalair Maroc", y: "MA" },
  "TAP": { n: "TAP Air Portugal",   c: "Air Portugal", y: "PT" },
  "SWR": { n: "Swiss International Air Lines", c: "Swiss", y: "CH" },
  "AUA": { n: "Austrian Airlines",  c: "Austrian",   y: "AT" },
  "SAS": { n: "Scandinavian Airlines", c: "Scandinavian", y: "SE" },
  "NAX": { n: "Norwegian Air Shuttle", c: "Nor Shuttle", y: "NO" },
  "NSZ": { n: "Norse Atlantic Airways", c: "Norstar", y: "NO" },
  "FIN": { n: "Finnair",            c: "Finnair",    y: "FI" },
  "ICE": { n: "Icelandair",         c: "Iceair",     y: "IS" },
  "AZA": { n: "ITA Airways",        c: "Itarrow",    y: "IT" },
  "WZZ": { n: "Wizz Air",           c: "Wizz Air",   y: "HU" },
  "LOT": { n: "LOT Polish Airlines", c: "Lot",       y: "PL" },
  "THY": { n: "Turkish Airlines",   c: "Turkish",    y: "TR" },
  "PGT": { n: "Pegasus Airlines",   c: "Sunturk",    y: "TR" },
  "AFL": { n: "Aeroflot",           c: "Aeroflot",   y: "RU" },

  // ---- Middle East / Africa ----
  "UAE": { n: "Emirates",           c: "Emirates",   y: "AE" },
  "ETD": { n: "Etihad Airways",     c: "Etihad",     y: "AE" },
  "QTR": { n: "Qatar Airways",      c: "Qatari",     y: "QA" },
  "SVA": { n: "Saudia",             c: "Saudia",     y: "SA" },
  "MSR": { n: "EgyptAir",           c: "Egyptair",   y: "EG" },
  "ELY": { n: "El Al",              c: "El Al",      y: "IL" },
  "RJA": { n: "Royal Jordanian",    c: "Jordanian",  y: "JO" },
  "ETH": { n: "Ethiopian Airlines", c: "Ethiopian",  y: "ET" },
  "SAA": { n: "South African Airways", c: "Springbok", y: "ZA" },
  "KQA": { n: "Kenya Airways",      c: "Kenya",      y: "KE" },

  // ---- Asia / Pacific ----
  "QFA": { n: "Qantas",             c: "Qantas",     y: "AU" },
  "JST": { n: "Jetstar Airways",    c: "Jetstar",    y: "AU" },
  "VOZ": { n: "Virgin Australia",   c: "Velocity",   y: "AU" },
  "ANZ": { n: "Air New Zealand",    c: "New Zealand", y: "NZ" },
  "SIA": { n: "Singapore Airlines", c: "Singapore",  y: "SG" },
  "SLK": { n: "Scoot",              c: "Scooter",    y: "SG" },
  "CPA": { n: "Cathay Pacific",     c: "Cathay",     y: "HK" },
  "CX":  { n: "Cathay Pacific",     c: "Cathay",     y: "HK" },
  "JAL": { n: "Japan Airlines",     c: "Japan Air",  y: "JP" },
  "ANA": { n: "All Nippon Airways", c: "All Nippon", y: "JP" },
  "KAL": { n: "Korean Air",         c: "Korean Air", y: "KR" },
  "AAR": { n: "Asiana Airlines",    c: "Asiana",     y: "KR" },
  "CCA": { n: "Air China",          c: "Air China",  y: "CN" },
  "CES": { n: "China Eastern Airlines", c: "China Eastern", y: "CN" },
  "CSN": { n: "China Southern Airlines", c: "China Southern", y: "CN" },
  "CHH": { n: "Hainan Airlines",    c: "Hainan",     y: "CN" },
  "AIC": { n: "Air India",          c: "Airindia",   y: "IN" },
  "IGO": { n: "IndiGo",             c: "IFLY",       y: "IN" },
  "THA": { n: "Thai Airways International", c: "Thai", y: "TH" },
  "MAS": { n: "Malaysia Airlines",  c: "Malaysian",  y: "MY" },
  "AXM": { n: "AirAsia",            c: "Red Cap",    y: "MY" },
  "GIA": { n: "Garuda Indonesia",   c: "Indonesia",  y: "ID" },
  "PAL": { n: "Philippine Airlines", c: "Philippine", y: "PH" },

  // ---- Latin America ----
  "LAN": { n: "LATAM Airlines",     c: "LAN",        y: "CL" },
  "TAM": { n: "LATAM Brasil",       c: "TAM",        y: "BR" },
  "GLO": { n: "Gol Linhas Aéreas",  c: "Gol Transporte", y: "BR" },
  "AZU": { n: "Azul Brazilian Airlines", c: "Azul",  y: "BR" },
  "ARG": { n: "Aerolíneas Argentinas", c: "Argentina", y: "AR" },
  "AVA": { n: "Avianca",            c: "Avianca",    y: "CO" },
  "CMP": { n: "Copa Airlines",      c: "Copa",       y: "PA" },

  // ---- Misc / operators often seen ----
  "RCH": { n: "US Air Mobility Command", c: "Reach", y: "US" },
  "CNV": { n: "US Navy / Convoy",   c: "Convoy",     y: "US" },
  "NASA": { n: "NASA",              c: "NASA",       y: "US" }
}

// ---- lookups -------------------------------------------------------------

function typeInfo(code) {
  var k = String(code || "").toUpperCase().trim()
  return AIRCRAFT_TYPES[k] || null
}
function typeName(code) {
  var t = typeInfo(code)
  return t ? t.n : (code ? "Unclassified (" + String(code).toUpperCase() + ")" : "Unknown aircraft")
}
function typeShort(code) {
  var t = typeInfo(code)
  return t ? t.s : (code ? String(code).toUpperCase() : "?")
}
function category(code) {
  var t = typeInfo(code)
  return t ? t.c : "unknown"
}
function rarity(code) {
  var t = typeInfo(code)
  return t ? t.r : "unclassified"
}
function allTypeCodes() { return Object.keys(AIRCRAFT_TYPES) }
function typeUniverseCount() { return Object.keys(AIRCRAFT_TYPES).length }

// Parse an ADS-B callsign. Returns:
//   { airline:{name,callsign,country}|null, flightNo:string, isRegistration:bool, display:string }
function parseCallsign(raw) {
  var cs = String(raw || "").toUpperCase().replace(/[^A-Z0-9]/g, "")
  if (!cs) return { airline: null, flightNo: "", isRegistration: false, display: "" }

  // ICAO airline callsign: 3 letters + 1-4 alphanumerics starting with a digit
  var m = cs.match(/^([A-Z]{3})([0-9][0-9A-Z]{0,3})$/)
  if (m && AIRLINES[m[1]]) {
    var a = AIRLINES[m[1]]
    return {
      airline: { name: a.n, callsign: a.c, country: a.y },
      flightNo: m[2],
      isRegistration: false,
      display: a.n + " " + m[2]
    }
  }
  // Unknown 3-letter operator, still clearly an airline-style callsign
  if (m) {
    return { airline: { name: m[1] + " (operator " + m[1] + ")", callsign: "", country: "" },
             flightNo: m[2], isRegistration: false, display: m[1] + " " + m[2] }
  }
  // US registration: N + digits + up to 2 trailing letters
  if (/^N[0-9]/.test(cs)) {
    return { airline: null, flightNo: "", isRegistration: true, display: cs + " (US registration)" }
  }
  // Other national registrations flown as the tail number
  if (/^(G|D|F|C|VH|ZK|EI|OO|PH|SE|LN|OY|HB|OE|SP|SX|9H|CS|EC|TC|A6|HZ|4X|B|JA|HL|VT)[A-Z0-9]{2,5}$/.test(cs)) {
    return { airline: null, flightNo: "", isRegistration: true, display: cs + " (registration)" }
  }
  return { airline: null, flightNo: "", isRegistration: false, display: cs }
}

var RARITY_RANK = { common: 0, uncommon: 1, rare: 2, exotic: 3, unclassified: 1 }
// Points a discovered type is worth toward the Logbook score.
var RARITY_SCORE = { common: 1, uncommon: 3, rare: 8, exotic: 20, unclassified: 0 }

function typeScore(code) {
  var t = typeInfo(code)
  return t ? (RARITY_SCORE[t.r] || 0) : 0
}

if (typeof module !== "undefined") {
  module.exports = {
    AIRCRAFT_TYPES: AIRCRAFT_TYPES,
    AIRLINES: AIRLINES,
    RARITY_RANK: RARITY_RANK,
    RARITY_SCORE: RARITY_SCORE,
    typeInfo: typeInfo,
    typeName: typeName,
    typeShort: typeShort,
    typeScore: typeScore,
    category: category,
    rarity: rarity,
    allTypeCodes: allTypeCodes,
    typeUniverseCount: typeUniverseCount,
    parseCallsign: parseCallsign
  }
}
