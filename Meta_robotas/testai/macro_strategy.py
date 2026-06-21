import pandas as pd
import numpy as np
from datetime import datetime

# ── Makro rodiklių duomenys (sintetiniai/tipiški) ────────────
MACRO_DATA = {
    "palukanos_fed"   : {"reiksme": 5.25, "pokytis": "stabilu",   "kryptis": "neutral"},
    "palukanos_ecb"   : {"reiksme": 4.50, "pokytis": "mazeja",    "kryptis": "dovish"},
    "infliacija_us"   : {"reiksme": 3.2,  "pokytis": "mazeja",    "kryptis": "bullish_USD"},
    "infliacija_eu"   : {"reiksme": 2.6,  "pokytis": "mazeja",    "kryptis": "dovish_EUR"},
    "bdp_us"          : {"reiksme": 2.8,  "pokytis": "auga",      "kryptis": "bullish_USD"},
    "bdp_eu"          : {"reiksme": 0.4,  "pokytis": "silpnas",   "kryptis": "bearish_EUR"},
    "nfp_us"          : {"reiksme": 175,  "pokytis": "stiprus",   "kryptis": "bullish_USD"},
    "rizikos_apetitas": {"reiksme": "vid","pokytis": "neutral",   "kryptis": "neutral"},
}

# ── Makro analizė pagal porą ──────────────────────────────────
def analyze_pair_macro(pair):
    analyses = {
        "EURUSD": {
            "makro_kryptis": "BEARISH",
            "stiprumas"    : 3,
            "priezastys"   : [
                "Fed palūkanos 5.25% > ECB 4.50% → USD stipresnis",
                "JAV BVP 2.8% >> ES BVP 0.4% → USD pranašesnis",
                "ES infliacija mažėja greičiau → ECB mažins palūkanas anksčiau",
                "JAV NFP 175k — stipri darbo rinka → Fed nesku bėja mažinti",
            ],
            "signalai"     : [
                "SELL EURUSD artėjant prie resistancų",
                "Vengti BUY pozicijų prieš Fed posėdžius",
            ],
            "rizikos"      : [
                "Jei ECB netikėtai pakelia palūkanas — EUR stiprės",
                "Geopolitiniai įvykiai Europoje gali suardyti prognozę",
            ],
        },
        "GBPUSD": {
            "makro_kryptis": "NEUTRAL",
            "stiprumas"    : 2,
            "priezastys"   : [
                "BOE palūkanos aukštos — GBP palaikomas",
                "UK infliacija vis dar aukšta — BOE neskuba mažinti",
                "USD stiprus — spaudžia GBP žemyn",
            ],
            "signalai"     : [
                "Prekyba diapazone 1.25-1.30",
                "Pirkti palaikymuose, parduoti pasipriešinimuose",
            ],
            "rizikos"      : [
                "UK ekonomikos silpnėjimas gali spausti GBP žemyn",
            ],
        },
        "USDJPY": {
            "makro_kryptis": "BULLISH",
            "stiprumas"    : 4,
            "priezastys"   : [
                "BOJ palūkanos ~0% << Fed 5.25% → didžiulis skirtumas",
                "Japonija veda ultra-laisva monetarines politika",
                "Carry trade populiarus — skolinamasi JPY, perkamas USD",
            ],
            "signalai"     : [
                "BUY USDJPY pullback metu",
                "Vengti SELL pozicijų be BOJ intervencijos signalų",
            ],
            "rizikos"      : [
                "BOJ staigi intervencija gali sukelti 200-300 pip kritimą",
                "Rizikos vengimo epizodai (risk-off) stiprina JPY",
            ],
        },
    }
    return analyses.get(pair, None)

def print_results():
    laikas = datetime.utcnow().strftime("%Y-%m-%d")

    print("\n" + "="*56)
    print("     SMC SNIPER — MACRO-BASED STRATEGY")
    print(f"     {laikas}")
    print("="*56)

    print("\n🌍 DABARTINIAI MAKRO RODIKLIAI:")
    print(f"   {'Rodiklis':<25} {'Reikšmė':>8} {'Pokytis':>12} {'Signalo kryptis'}")
    print("   " + "-"*65)
    for rodiklis, data in MACRO_DATA.items():
        print(f"   {rodiklis:<25} {str(data['reiksme']):>8} {data['pokytis']:>12}  → {data['kryptis']}")

    pairs = ["EURUSD", "GBPUSD", "USDJPY"]
    for pair in pairs:
        a = analyze_pair_macro(pair)
        if not a:
            continue
        stars = "★" * a["stiprumas"] + "☆" * (5 - a["stiprumas"])
        print(f"\n{'─'*56}")
        print(f"  📊 {pair} — Makro kryptis: {a['makro_kryptis']} {stars}")
        print(f"  Priežastys:")
        for p in a["priezastys"]:
            print(f"    • {p}")
        print(f"  Prekybos signalai:")
        for s in a["signalai"]:
            print(f"    → {s}")
        print(f"  Rizikos:")
        for r in a["rizikos"]:
            print(f"    ⚠️  {r}")

    print(f"\n{'='*56}")
    print("  📅 SVARBIOS DATOS (stebėti ir NEPREKIAUTI):")
    events = [
        ("2026-06-25", "Fed kalbos"),
        ("2026-07-01", "ISM Manufacturing PMI"),
        ("2026-07-03", "NFP (Non-Farm Payrolls)"),
        ("2026-07-10", "CPI infliacija JAV"),
        ("2026-07-24", "ECB posėdis"),
    ]
    for data, event in events:
        print(f"    📌 {data}: {event}")

    print(f"\n💡 MAKRO STRATEGIJOS TAISYKLĖ:")
    print(f"   → Prekyba su makro kryptimi = didesnis win rate")
    print(f"   → Prieš svarbius pranešimus — uždaryti pozicijas")
    print(f"   → USDJPY šiuo metu geriausias makro signalo pora")
    print("="*56 + "\n")

if __name__ == "__main__":
    print("Analizuojami makroekonominiai rodikliai...")
    print_results()
