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
- 📍 **GPS-recorder** — begint op **5:00** voor de start, schrijft een FIT-activiteit met `SPORT_SAILING`
- 🚩 **Lapmarker op het startschot** — de aanloop is in het FIT-bestand te onderscheiden van de race
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

## Wanneer wordt er opgenomen

De opname begint niet bij het indrukken van START, maar pas als de aftelklok
**5:00** aanwijst. Zet je 15 minuten, dan blijven de eerste 10 minuten dus
buiten de track. Vijf minuten is ruim genoeg voor een GPS-fix — die heeft
doorgaans onder de minuut nodig — en scheelt een hoop aanlooprommel in het
bestand. Bij preset 5m begint de opname meteen.

Op het moment dat de aftelling nul passeert zet de app een **lapmarker** in
het FIT-bestand. Daarmee is achteraf te zien waar de aanloop ophoudt en de
race begint.

```
  START           opname begint      startschot              Opslaan
    │                   │                 │                     │
    ▼                   ▼                 ▼                     ▼
  15:00 ─────────────  5:00 ──────────── 0:00 ───────────────  einde
    └── niet opgenomen ─┘└─ opgenomen ────┴─── opgenomen ────────┘
                                       lapmarker
```

Eenmaal begonnen stopt de opname niet meer. Ga je met **+1** weer boven de
5:00 uit, dan loopt hij door — anders zou er een gat in je track vallen.

> Druk je op **Opslaan** terwijl de klok nog boven de 5:00 staat, dan is er
> niets opgenomen. Het scherm meldt dan `Niets opgenomen` in plaats van
> `Opgeslagen`.

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
   │        RACE         │      │      ● 18:42        │
   │                     │      │                     │
   │       12:34         │  ⇄   │       12:34         │
   │                     │      │                     │
   │                     │      │                     │
   │                     │      │   6.4       247     │
   │         ●           │      │  KNOPEN    KOERS    │
   │     BACK = MENU     │      │                     │
   │        ● ○          │      │        ○ ●          │
   └─────────────────────┘      └─────────────────────┘
        racetijd                    racetijd + info
```

Op beide schermen:

- Grote cijfers: **wit** op het startscherm en tijdens het aftellen, **rood** in de laatste 10 seconden voor de start, **cyaan** tijdens de race
- Stip: **grijs** = timer loopt, opname begint pas op 5:00 · **rood** = opname loopt maar nog geen bruikbare fix · **groen** = punten binnen
- Twee stipjes onderin geven aan op welk scherm je zit

Alleen op het timerscherm:

- Bovenaan het label **AFTELLEN** of **RACE**
- Onderin de hint `START` of `BACK = MENU`
- Presets 5m / 10m / 15m als de timer stilstaat, ±1-knoplabels tijdens het aftellen

Het infoscherm laat label en hint bewust weg. Die pagina bestaat alleen
tijdens de race, dus "RACE" zei niets, en de ruimte gaat naar leesbare
cijfers. De klok staat er bovenaan met de GPS-stip ervoor.

Over de waarden op het infoscherm:

- **Knopen** is het gemiddelde over de laatste 5 seconden, niet de rauwe meting. Instantane GPS-snelheid springt op het water te veel heen en weer om af te lezen.
- **Koers** is koers over grond uit `Activity.Info.track`, dus de uit GPS-beweging afgeleide richting — niet de kompaskoers. Onder 0,5 knoop staat er `---`, omdat de waarde dan pure ruis is. Er staat geen `°` achter: de `FONT_NUMBER_*`-familie is "number only" en kan dat teken niet tekenen.
- **Klok** volgt de 12/24-uursinstelling van het horloge.
- De cijfers staan op `FONT_NUMBER_MILD`, de grootste maat die naast de racetijd past. Dat is op het toestel gemeten en niet berekend: `dc.getFontHeight()` geeft de regelhoogte van een font en niet hoever de cijfers zichtbaar doorlopen, en `Dc` heeft geen `getFontDescent`. `_fitValueFont()` meet de bréédst mogelijke inhoud (`88.8` en `888`) in plaats van de actuele waarden, zodat de maat gelijk blijft terwijl je vaart — anders koos hij een groter font zodra de koers even `---` was.

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
