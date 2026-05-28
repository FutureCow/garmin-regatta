#!/usr/bin/env python3
"""Genereert minimale Garmin device-definities voor monkeyc compiler.

Device specs op basis van bekende waardes. Wordt aangeroepen in CI
voordat monkeyc draait met --override-devices-json.
"""

import json, os

DEVICES_DIR = os.path.expanduser("~/.Garmin/ConnectIQ/Devices")

DEVICES = {
    # ── Fenix 6 series ──────────────────────────────────────────────
    "fenix6":      ("Fenix 6",        "round-260x260", 260, 260),
    "fenix6pro":   ("Fenix 6 Pro",    "round-260x260", 260, 260),
    "fenix6s":     ("Fenix 6S",       "round-240x240", 240, 240),
    "fenix6spro":  ("Fenix 6S Pro",   "round-240x240", 240, 240),

    # ── Fenix 7 series ──────────────────────────────────────────────
    "fenix7":      ("Fenix 7",        "round-260x260", 260, 260),
    "fenix7pro":   ("Fenix 7 Pro",    "round-260x260", 260, 260),
    "fenix7s":     ("Fenix 7S",       "round-240x240", 240, 240),
    "fenix7spro":  ("Fenix 7S Pro",   "round-240x240", 240, 240),
    "fenix7x":     ("Fenix 7X",       "round-280x280", 280, 280),
    "fenix7xpro":  ("Fenix 7X Pro",   "round-280x280", 280, 280),

    # ── Fenix 8 series ──────────────────────────────────────────────
    "fenix8":      ("Fenix 8",        "round-454x454", 454, 454),
    "fenix8solar": ("Fenix 8 Solar",  "round-454x454", 454, 454),
    "fenixE":      ("Fenix E",        "round-390x390", 390, 390),

    # ── Quatix series ───────────────────────────────────────────────
    "quatix6":     ("Quatix 6",       "round-260x260", 260, 260),
    "quatix7":     ("Quatix 7",       "round-260x260", 260, 260),
    "quatix7pro":  ("Quatix 7 Pro",   "round-260x260", 260, 260),

    # ── Forerunner series ───────────────────────────────────────────
    "forerunner255":  ("Forerunner 255",  "round-260x260", 260, 260),
    "forerunner265":  ("Forerunner 265",  "round-416x416", 416, 416),
    "forerunner955":  ("Forerunner 955",  "round-260x260", 260, 260),
    "forerunner965":  ("Forerunner 965",  "round-454x454", 454, 454),

    # ── Epix series ─────────────────────────────────────────────────
    "epix2":        ("Epix 2",         "round-416x416", 416, 416),
    "epix2pro":     ("Epix 2 Pro",     "round-454x454", 454, 454),
    "epixpro51mm":  ("Epix Pro 51mm",  "round-454x454", 454, 454),

    # ── Enduro series ───────────────────────────────────────────────
    "enduro2":  ("Enduro 2",   "round-280x280", 280, 280),
    "enduro3":  ("Enduro 3",   "round-280x280", 280, 280),

    # ── MARQ / Tactix ───────────────────────────────────────────────
    "marq2":      ("MARQ 2",     "round-390x390", 390, 390),
    "tactix7":    ("Tactix 7",   "round-280x280", 280, 280),
    "tactix7pro": ("Tactix 7 Pro", "round-280x280", 280, 280),
}


def make_device(device_id, display_name, device_family, w, h):
    """Maak een compiler.json voor één device."""
    # Launcher icon size: Garmin standaard is 40x40 voor oudere,
    # 65x65 voor nieuwere (454px schermen).
    launcher_size = 65 if max(w, h) >= 390 else 40

    return {
        "deviceId": device_id,
        "displayName": display_name,
        "deviceFamily": device_family,
        "worldWidePartNumber": f"006-{device_id.upper()}-00",
        "partNumbers": [
            {
                "number": f"006-{device_id.upper()}-00",
                "firmwareVersion": "2502",
                "connectIQVersion": "5.2.0",
            }
        ],
        "resolution": {"width": w, "height": h},
        "launcherIcon": {"width": launcher_size, "height": launcher_size},
        "bitsPerPixel": 16,
        "orientation": "GFX_ORNTN_0",
        "gpuSupport": True,
        "alphaBlendingSupport": True,
        "screenRotationSupport": False,
        "exportSupport": True,
        "codePageSize": 4096,
        "appTypes": [
            {"type": "watchApp",   "memoryLimit": 786432},
            {"type": "watchFace",  "memoryLimit": 131072},
            {"type": "datafield",  "memoryLimit": 262144},
            {"type": "background", "memoryLimit": 65536},
            {"type": "glance",     "memoryLimit": 65536},
        ],
    }


def main():
    os.makedirs(DEVICES_DIR, exist_ok=True)

    for device_id, (name, family, w, h) in DEVICES.items():
        device_dir = os.path.join(DEVICES_DIR, device_id)
        os.makedirs(device_dir, exist_ok=True)

        compiler = make_device(device_id, name, family, w, h)
        path = os.path.join(device_dir, "compiler.json")

        with open(path, "w") as f:
            json.dump(compiler, f, indent=2)

        print(f"  {device_id:20s} → {family} {w}×{h}")

    print(f"\n{len(DEVICES)} devices geschreven naar {DEVICES_DIR}")


if __name__ == "__main__":
    main()
