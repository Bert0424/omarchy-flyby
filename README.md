# Flyby

A bar widget that shows the aircraft flying over you on a live **radar scope**,
built from free community ADS-B data. Click the pill to open the scope: a
sweeping radar with range rings, a blip per aircraft placed by bearing and
distance, and a list of the nearest contacts with altitude, speed, climb/descent
and heading. The pill shows how many aircraft are in range, or the closest
callsign (with a pulsing dot) when one is passing directly overhead.

![preview](preview.png)

## Install

```
omarchy plugin add https://github.com/Bert0424/omarchy-flyby.git
omarchy plugin enable bert.flyby
```

Then set your location (see below) and the scope fills in within a few seconds.

## Using it

- **Left click** the pill — open / close the radar scope.
- **Middle click** the pill — force an immediate refresh.
- **Click a blip** (or a row in the list) — select that aircraft; it gets a
  ring and its callsign on the scope.
- The scope polls every 15 seconds while the shell is running.

### Footer controls (in the popup)

| Control | What it does |
|---|---|
| `📍 lat, lon` | Reopen the location form to fine-tune or re-enter your coordinates. |
| `5nm … 100nm` | Range of the scope (the outer ring). |
| `km` | Cycle distance units: km → mi → nm. |
| `🔕 / 🔔` | Toggle a desktop notification when a new aircraft enters the overhead zone (within 3 km, airborne). |
| `air only / 🛬 ground` | Include or hide aircraft that are on the ground (parked, taxiing, tower, service vehicles). Off by default. |
| `adsb.lol / adsb.fi` | Which community feed to query. |

## Setting your location

Flyby needs your latitude and longitude in decimal degrees.

- **First run** — the popup shows a small form: type `lat` / `lon` and hit
  **Save**, or press **Locate me (approx)** for a one-shot coarse lookup from
  your public IP via `https://ipapi.co` (city-level; fine for a 25 nm scope).
- **Later** — tap the **📍 lat, lon** chip in the footer to reopen that form
  and fine-tune the coordinates by hand (IP lookup only gets you to the right
  city; for the "overhead" detection to be meaningful you want your real spot).
  Get exact coordinates from Google Maps: right-click your location, the lat/lon
  is at the top of the menu.
- The `Latitude` / `Longitude` fields in the widget's settings do the same thing.

## Data sources

- **adsb.lol** — `https://api.adsb.lol/v2/point/{lat}/{lon}/{radius_nm}`
- **adsb.fi** — `https://opendata.adsb.fi/api/v2/lat/{lat}/lon/{lon}/dist/{radius_nm}`

Both are free, community-run ADS-B aggregators. No account, no API key. Please be
a good citizen — the 15 s poll interval is deliberately gentle; don't crank it.

## What it does to your system

- **Network:** while enabled it makes one HTTPS GET every 15 seconds to the
  selected data source (`api.adsb.lol` or `opendata.adsb.fi`), sending only your
  configured latitude/longitude and range as part of the URL. If you press
  "Locate me", it additionally makes one HTTPS GET to `https://ipapi.co/latlong/`.
  Nothing else is sent anywhere.
- **No telemetry, no analytics, no accounts.**
- **No privilege escalation.** Runs entirely as your user — no polkit, no
  system services, no writes outside your own config.
- **Files written:** none of its own. Your latitude/longitude/range/units and the
  toggle states are stored by Omarchy in `~/.config/omarchy/shell.json` alongside
  every other bar-widget setting.
- **Processes:** `curl` (for the fetches) and `omarchy-notification-send` (only
  when the overhead notification is enabled and a plane passes over).
- Every string that comes back from the API is stripped of markup and control
  characters and length-clamped before it is displayed.

## Uninstall

```
omarchy plugin disable bert.flyby   # or: omarchy plugin remove bert.flyby
```

It keeps nothing running in the background beyond the poll timer, which stops
with the widget.

## Credits

Made by [@AlbertDIII](https://x.com/AlbertDIII).

## License

MIT
