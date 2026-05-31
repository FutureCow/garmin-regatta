# Regatta Garmin IQ

Garmin watch app voor zeilwedstrijden — timer met GPS-recorder die direct synchroniseert met de [regatta-server](https://github.com/FutureCow/regatta-server) via WiFi.

Ondersteunde watches: **Fenix 6/7/8, Quatix 6/7, Forerunner 255/265/955/965, Epix 2, Enduro 2/3, MARQ 2, Tactix 7**

## Features

- ⏱️ **Afteltimer** — 5, 10 of 15 minuten preset, schakelt automatisch naar opgaande racetijd
- 📡 **GPS Recorder** — start automatisch als de timer start, slaat trackpoints op 1 Hz
- 📤 **Sync via WiFi** — uploadt de GPX-track direct naar de regatta-server via WiFi (geen telefoon nodig)
- 🔗 **Race koppelen** — voer een deelnamecode in en tracks worden automatisch gekoppeld
- ⚙️ **Instelbaar via Garmin IQ** — server URL, auth token en deelnamecode

## Hoe het werkt

```\n┌──────────┐    WiFi     ┌──────────────┐\n│  Watch   │ ─────────→  │ Regatta      │\n│ (Garmin) │   HTTP(S)   │ server       │\n└──────────┘             └──────────────┘\n```\n\n1. Je stopt de timer op je watch → GPX wordt gegenereerd\n2. De watch uploadt de GPX direct via WiFi naar de regatta-server\n3. Klaar — geen telefoon of BLE nodig\n\n> **Let op:** de watch moet verbonden zijn met WiFi. Als er geen WiFi is bij het stoppen, wordt de track bewaard en kun je hem later handmatig uploaden via het menu.

## Installatie

1. Download de `.iq` file van de [releases pagina](https://github.com/FutureCow/garmin-regatta/releases)
2. Kopieer naar `GARMIN/APPS/` op je watch via USB, of
3. Installeer via de [Garmin Connect IQ Store](https://apps.garmin.com/) (na publicatie)

## Configuratie

Open **Garmin Connect IQ** op je telefoon → Mijn apparaat → Regatta → Instellingen:

| Instelling | Uitleg |
|---|---|
| **Server URL** | URL van de regatta-server, bijv. `https://regatta.fhettinga.nl` |
| **Auth token** | JWT token van je account (te vinden in de regatta-screen app → Instellingen) |
| **Deelnamecode** | Code van de wedstrijd/reeks waaraan je meedoet |
| **Auto-sync** | Automatisch uploaden na stoppen (aan/uit) |

## Bediening

| Knop | Actie |
|---|---|
| **START** | Timer starten/stoppen + GPS start/stopt mee |
| **UP** | Preset wisselen (5m → 10m → 15m) — alleen als timer stil staat |
| **DOWN** | Menu openen (handmatig syncen, uploaden, instellingen) |
| **BACK** | Reset timer (alleen als timer gestopt is) |

## Build from source

Je hebt de [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) nodig.

```bash
# Genereer developer key (eenmalig)
monkeyc -g -y developer_key.der

# Build
monkeyc -f monkey.jungle -o bin/regatta.iq -y developer_key.der
```

## CI/CD

Bij elke push naar `master` bouwt GitHub Actions automatisch een `.iq` file:

- Checkout → Download Garmin SDK → Build → Upload artifact
- De `.iq` file is te downloaden vanaf de Actions pagina

## Projectstructuur

```
garmin-regatta/
├── manifest.xml              # App manifest (app ID, permissies, producten)
├── monkey.jungle             # Jungle build config
├── source/
│   ├── RegattaApp.mc         # Application entry point, lifecycle
│   ├── RegattaView.mc        # Main UI view (timer, GPS status)
│   ├── RegattaDelegate.mc    # Button/touch input handling
│   ├── TimerModel.mc         # Countdown + elapsed timer logic
│   ├── GpsRecorder.mc        # GPS recording + FIT + GPX export
│   └── SyncManager.mc        # WiFi direct HTTP sync
└── resources/
    ├── strings.xml           # Vertaalbare strings (EN/NL)
    ├── settings.xml          # App instellingen (server URL, token)
    └── drawables/
        ├── drawables.xml     # Icon mapping
        └── launcher.png      # App icoon (40×40)
```
