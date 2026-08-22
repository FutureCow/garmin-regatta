# Regatta Garmin IQ

Garmin watch-app voor zeilwedstrijden — afteltimer met GPS-recorder die de race
wegschrijft als FIT-activiteit met `SPORT_SAILING`. De activiteit synchroniseert
via Garmin Connect; de [regatta-server](https://github.com/Regatta-Companion/regatta-server)
haalt zeilactiviteiten daar vandaan op.

**Ondersteund toestel:** Forerunner 965 (`fr965`)

## Features

- ⏱️ **Afteltimer** — preset 5, 10 of 15 minuten, schakelt bij 0 automatisch over naar oplopende racetijd
- 🔔 **Startsignalen** — piep + trilling op 5:00/4:00/3:00/2:00/1:00, elke 10 s in de laatste minuut, elke seconde in de laatste 5
- ➕ **±1 minuut** — timer bijstellen tijdens het aftellen (uitstel of vervroeging van de start), afgerond op hele minuten
- 📍 **GPS-recorder** — start en stopt mee met de timer, schrijft een FIT-activiteit met `SPORT_SAILING`
- 🧭 **Infoscherm tijdens de race** — snelheid in knopen, koers over grond en de klok naast de racetijd
- 🔒 **Geen pauzeknop** — de opname loopt onafgebroken door; START doet tijdens het varen niets, zodat je hem niet per ongeluk kunt indrukken
- 🚫 **Touch geblokkeerd tijdens opname** — spatwater veroorzaakt anders valse taps

## Hoe het werkt

```
┌──────────┐   FIT (SPORT_SAILING)   ┌─────────────────┐   garmin_sync.py   ┌──────────────┐
│  Watch   │ ──────────────────────► │ Garmin Connect  │ ─────────────────► │ Regatta      │
│ (fr965)  │      via de telefoon    │                 │   (op de server)   │ server       │
└──────────┘                         └─────────────────┘                    └──────────────┘
```

1. Je stopt de opname op het horloge en kiest **Opslaan** → de FIT-activiteit wordt op het horloge bewaard
2. Het horloge synchroniseert de activiteit zelf naar Garmin Connect, zoals elke andere activiteit
3. De regatta-server haalt zeilactiviteiten uit Garmin Connect op via `garmin_sync.py` en koppelt ze aan de wedstrijd

> De app heeft **geen** eigen serverconfiguratie, WiFi-upload of Bluetooth-verbinding.
> Dat is er in juni 2026 uit gehaald (commit `bf89cff`); koppelen met een wedstrijd
> gebeurt aan de serverkant. Verbind je Garmin-account op de webinterface van de
> regatta-server onder **Garmin**.

## Bediening

| Knop | Idle | Tijdens aftellen | Tijdens race |
|---|---|---|---|
| **START** | Timer + GPS starten | — | — |
| **UP** | Vorige preset (15m → 10m → 5m) | **+1 min** (afronden omhoog) | Blader van scherm |
| **DOWN** | Volgende preset (5m → 10m → 15m) | **−1 min** (afronden omlaag) | Blader van scherm |
| **BACK** | App verlaten | Menu openen | Menu openen |

**Er is geen pauze.** Zodra de timer loopt doet START niets meer — op het water
druk je die knop te makkelijk per ongeluk in. Stoppen gaat altijd via BACK, en
dat stopt of pauzeert op zichzelf niets: timer en GPS lopen gewoon door zolang
het menu open staat.

| Keuze | Effect |
|---|---|
| **Verder opnemen** | Sluit het menu, er verandert niets — staat bovenaan en is de gemarkeerde keuze |
| **Opslaan** | FIT-activiteit bewaren en terug naar het startscherm |
| **Verwijderen** | Opname weggooien en terug naar het startscherm |

Omdat *Verder opnemen* bovenaan staat, zijn zowel BACK-BACK als BACK-START
onschadelijk: je vaart gewoon door.

## Schermen

Vóór de start is er één scherm: de aftelklok, met UP en DOWN op ±1 minuut.
Zodra de aftelling op nul staat en de race loopt, bladeren UP en DOWN tussen
twee schermen. Twee stipjes onderin laten zien op welk scherm je zit; die
verschijnen alleen tijdens de race, want alleen dan valt er te bladeren.

```
   ┌─────────────────────┐      ┌─────────────────────┐
   │        RACE         │      │        RACE         │
   │                     │      │                     │
   │       12:34         │  ⇄   │       12:34         │
   │                     │      │                     │
   │                     │      │  6.4 kn      247°   │
   │                     │      │  KNOPEN      KOERS  │
   │         ●           │      │                     │
   │     BACK = MENU     │      │     ● 18:42         │
   │        ● ○          │      │     BACK = MENU     │
   └─────────────────────┘      │        ○ ●          │
        racetijd                └─────────────────────┘
                                    racetijd + info
```

Gemeenschappelijk op beide schermen:

- Bovenaan het label **AFTELLEN** of **RACE**
- Grote cijfers: **wit** op het startscherm en tijdens het aftellen, **rood** in de laatste 10 seconden voor de start, **cyaan** tijdens de race
- Stip: **groen** = GPS-punten binnen, **rood** = opname loopt maar nog geen bruikbare fix
- Onderin de hint `START` op het startscherm en `BACK = MENU` tijdens het varen
- Presets 5m / 10m / 15m alleen zichtbaar als de timer stilstaat

Over de waarden op het infoscherm:

- **Knopen** is het gemiddelde over de laatste 5 seconden, niet de rauwe meting. Instantane GPS-snelheid springt op het water te veel heen en weer om af te lezen.
- **Koers** is koers over grond uit `Activity.Info.track`, dus de uit GPS-beweging afgeleide richting — niet de kompaskoers. Onder 0,5 knoop staat er `---`, omdat de waarde dan pure ruis is.
- **Klok** volgt de 12/24-uursinstelling van het horloge.

## Installatie

1. Download `regatta.iq` (of `regatta-fr965.prg`) van de [releases-pagina](https://github.com/Regatta-Companion/garmin-regatta/releases)
2. Kopieer het `.prg`-bestand via USB naar `GARMIN/APPS/` op je horloge

## Build from source

Je hebt de [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) nodig.

```bash
# Genereer developer key (eenmalig)
monkeyc -g -y developer_key.der

# Build
monkeyc -f monkey.jungle -o bin/regatta.iq -y developer_key.der
```

## CI/CD

[`.github/workflows/build.yml`](.github/workflows/build.yml) bouwt bij elke push naar
`master` of `main` automatisch een `.iq` en een `.prg` als artifact. Bij een tag `v*`
worden die aan de GitHub-release gehangen. De workflow heeft de repo-secret
`GARMIN_DEVELOPER_KEY_B64` nodig (de developer key, base64-encoded).

## Projectstructuur

```
garmin-regatta/
├── manifest.xml              # App manifest (app ID, permissies, fr965)
├── monkey.jungle             # Jungle build config
├── source/
│   ├── RegattaApp.mc         # Entry point, lifecycle, alerts, racemenu
│   ├── RegattaView.mc        # Beide schermen — rond 454×454
│   ├── RegattaDelegate.mc    # Knop- en touch-afhandeling
│   ├── TimerModel.mc         # Aftellen + oplopende racetijd (IDLE / RUNNING)
│   ├── GpsRecorder.mc        # FIT-opname met SPORT_SAILING
│   └── Telemetry.mc          # Gedempte snelheid + koers over grond
└── resources/
    ├── strings.xml           # Alleen AppName — UI-labels staan in de .mc-bestanden
    └── drawables/
        ├── drawables.xml     # Icon mapping
        └── launcher.png      # App-icoon
```
