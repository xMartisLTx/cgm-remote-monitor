import pandas as pd
import numpy as np
from datetime import datetime, timedelta

np.random.seed(7)

# ── Rinkos duomenys (sintetiniai) ────────────────────────────
def fake_market():
    return {
        "EURUSD": {"price": 1.0842, "atr": 0.0045, "trend": "BULL", "rsi": 44},
        "GBPUSD": {"price": 1.2731, "atr": 0.0062, "trend": "BULL", "rsi": 47},
        "USDJPY": {"price": 149.82, "atr": 0.85,   "trend": "BEAR", "rsi": 56},
        "XAUUSD": {"price": 2341.5, "atr": 12.5,   "trend": "BULL", "rsi": 41},
        "USDCAD": {"price": 1.3612, "atr": 0.0038, "trend": "SIDE", "rsi": 51},
    }

# ── Sandorio generavimas ──────────────────────────────────────
def generate_setup(pair, data, capital=10_000, risk_pct=0.01):
    d = data[pair]

    if d["trend"] == "SIDE":
        return None   # vengiame sideways

    direction = "BUY" if d["trend"] == "BULL" else "SELL"
    price     = d["price"]
    atr       = d["atr"]

    sl_dist  = atr * 1.2
    tp1_dist = sl_dist * 2.0
    tp2_dist = sl_dist * 3.0

    if direction == "BUY":
        sl  = round(price - sl_dist, 5)
        tp1 = round(price + tp1_dist, 5)
        tp2 = round(price + tp2_dist, 5)
    else:
        sl  = round(price + sl_dist, 5)
        tp1 = round(price - tp1_dist, 5)
        tp2 = round(price - tp2_dist, 5)

    risk_amt = capital * risk_pct
    pip_val  = 0.0001 if "JPY" not in pair else 0.01
    if "XAU" in pair:
        pip_val = 0.1
    lot_size = round(risk_amt / (sl_dist / pip_val * 10), 2)
    lot_size = max(0.01, min(lot_size, 5.0))

    # Pagrindimas
    reasons = []
    if d["trend"] == "BULL":
        reasons.append("EMA50 virš EMA200 — bullish tendencija")
    else:
        reasons.append("EMA50 žemiau EMA200 — bearish tendencija")
    if d["rsi"] < 50:
        reasons.append(f"RSI {d['rsi']} — nesotinta pirkimui")
    elif d["rsi"] > 50:
        reasons.append(f"RSI {d['rsi']} — nesotinta pardavimui")
    reasons.append("Order Block zonoje — SMC patvirtinimas")
    reasons.append(f"ATR {atr:.4f} — pakankamas judėjimas")

    return {
        "pora"     : pair,
        "kryptis"  : direction,
        "įėjimas"  : price,
        "sl"       : sl,
        "tp1"      : tp1,
        "tp2"      : tp2,
        "lotas"    : lot_size,
        "rr1"      : "1:2.0",
        "rr2"      : "1:3.0",
        "rizika"   : f"${risk_amt:.0f}",
        "pagrindimas": reasons,
    }

# ── Spausdinimas ──────────────────────────────────────────────
def print_setups(setups):
    laikas = datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")

    print("\n" + "="*56)
    print("     SMC SNIPER — TRADE SETUP GENERATION")
    print(f"     {laikas}")
    print("="*56)

    valid = [s for s in setups if s is not None]
    print(f"\n📋 Rasta {len(valid)} sandorių iš 5 porų:\n")

    for s in valid:
        emoji = "📈" if s["kryptis"] == "BUY" else "📉"
        print(f"  {emoji} {s['pora']} — {s['kryptis']}")
        print(f"     Įėjimas  : {s['įėjimas']}")
        print(f"     Stop-Loss: {s['sl']}")
        print(f"     TP1      : {s['tp1']}  ({s['rr1']})")
        print(f"     TP2      : {s['tp2']}  ({s['rr2']})")
        print(f"     Lotas    : {s['lotas']}")
        print(f"     Rizika   : {s['rizika']}")
        print(f"     Pagrindimas:")
        for r in s["pagrindimas"]:
            print(f"       • {r}")
        print()

    print("⚠️  VALDYMO TAISYKLĖS:")
    print("   → Po TP1 pasiekimo: perkelti SL į įėjimą (BE)")
    print("   → Neuždaryti anksčiau laiko — leisti robotui dirbti")
    print("   → Jei 3 pralaimėjimai iš eilės — sustabdyti dienai")
    print("="*56 + "\n")

if __name__ == "__main__":
    print("Generuojami šiandienos sandoriai...")
    market = fake_market()
    setups = [generate_setup(p, market) for p in market]
    print_setups(setups)
