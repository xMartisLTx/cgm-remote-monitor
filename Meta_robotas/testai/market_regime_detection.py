import pandas as pd
import numpy as np

# ── Sintetiniai duomenys ──────────────────────────────────────
def generate_data(n=2000):
    np.random.seed(99)
    price  = 1.1000
    prices = []
    for i in range(n):
        # Sukuriame skirtingus rinkos režimus
        if i < 500:       # BULL
            drift = 0.0003
        elif i < 1000:    # BEAR
            drift = -0.0003
        else:             # SIDEWAYS
            drift = 0.0
        price += np.random.normal(drift, 0.0008)
        price  = max(1.05, min(1.20, price))
        prices.append(price)
    c = pd.Series(prices)
    h = c + np.abs(np.random.normal(0, 0.0003, n))
    l = c - np.abs(np.random.normal(0, 0.0003, n))
    o = c.shift(1).fillna(c.iloc[0])
    return pd.DataFrame({"Open": o, "High": h, "Low": l, "Close": c})

# ── Indikatoriai ─────────────────────────────────────────────
def add_indicators(df):
    df["EMA50"]   = df["Close"].ewm(span=50).mean()
    df["EMA200"]  = df["Close"].ewm(span=200).mean()
    df["ATR"]     = (df["High"] - df["Low"]).rolling(14).mean()
    df["ATR_avg"] = df["ATR"].rolling(50).mean()

    delta = df["Close"].diff()
    gain  = delta.clip(lower=0).rolling(14).mean()
    loss  = (-delta.clip(upper=0)).rolling(14).mean()
    df["RSI"] = 100 - (100 / (1 + gain / loss.replace(0, np.nan)))

    # ADX (tendencijos stiprumas)
    plus_dm  = df["High"].diff().clip(lower=0)
    minus_dm = (-df["Low"].diff()).clip(lower=0)
    tr       = df["ATR"]
    df["ADX"] = (
        (plus_dm.rolling(14).mean() - minus_dm.rolling(14).mean()).abs()
        / (plus_dm.rolling(14).mean() + minus_dm.rolling(14).mean()).replace(0, np.nan)
        * 100
    ).rolling(14).mean()
    return df

# ── Rinkos režimo nustatymas ──────────────────────────────────
def detect_regime(df):
    regimes = []
    for i in range(len(df)):
        row = df.iloc[i]
        if pd.isna(row["EMA200"]) or pd.isna(row["ADX"]):
            regimes.append("NEŽINOMA")
            continue

        adx       = row["ADX"]
        ema_bull  = row["EMA50"] > row["EMA200"]
        ema_bear  = row["EMA50"] < row["EMA200"]
        rsi       = row["RSI"]
        vol_high  = row["ATR"] > row["ATR_avg"] * 1.2 if not pd.isna(row["ATR_avg"]) else False

        if adx > 25 and ema_bull:
            regime = "BULL"
        elif adx > 25 and ema_bear:
            regime = "BEAR"
        else:
            regime = "SIDEWAYS"

        regimes.append(regime)

    df["Regime"] = regimes
    return df

# ── Rekomendacijos pagal režimą ───────────────────────────────
REGIME_RULES = {
    "BULL": {
        "veiksmas"    : "PIRKTI",
        "strategija"  : "SMC Sniper — tik BUY sandoriai",
        "vengti"      : "SELL sandorių prieš tendenciją",
        "SL"          : "Standartinis (OB + 5 pip)",
        "TP"          : "Pailgintas (1:3)",
        "pozicija"    : "Pilna pozicija (1-2%)",
    },
    "BEAR": {
        "veiksmas"    : "PARDUOTI",
        "strategija"  : "SMC Sniper — tik SELL sandoriai",
        "vengti"      : "BUY sandorių prieš tendenciją",
        "SL"          : "Standartinis (OB + 5 pip)",
        "TP"          : "Pailgintas (1:3)",
        "pozicija"    : "Pilna pozicija (1-2%)",
    },
    "SIDEWAYS": {
        "veiksmas"    : "LAUKTI arba RANGE prekyba",
        "strategija"  : "Pirkti palaikyme, parduoti pasipriešinime",
        "vengti"      : "Breakout sandorių",
        "SL"          : "Siauras (OB + 2 pip)",
        "TP"          : "Konservatyvus (1:1.5)",
        "pozicija"    : "Sumažinta pozicija (0.5-1%)",
    },
}

# ── Rezultatai ────────────────────────────────────────────────
def print_results(df):
    counts  = df["Regime"].value_counts()
    current = df["Regime"].iloc[-1]
    last_50 = df["Regime"].tail(50).value_counts()

    print("\n" + "="*52)
    print("     SMC SNIPER — MARKET REGIME DETECTION")
    print("="*52)

    print("\n📊 RINKOS REŽIMŲ PASISKIRSTYMAS (visi duomenys):")
    for regime, count in counts.items():
        pct = count / len(df) * 100
        bar = "█" * int(pct / 5)
        print(f"   {regime:<10}: {bar:<20} {pct:.0f}%")

    print(f"\n🔍 DABARTINIS REŽIMAS (paskutinės 50 žvakių):")
    for regime, count in last_50.items():
        pct = count / 50 * 100
        print(f"   {regime}: {pct:.0f}%")

    print(f"\n⚡ AKTYVIAUSIAS REŽIMAS: {current}")
    print("-"*52)

    rules = REGIME_RULES.get(current, {})
    print(f"\n🎯 REKOMENDACIJOS ŠIANDIEN ({current}):")
    for key, val in rules.items():
        print(f"   {key:<15}: {val}")

    print("\n📋 VISŲ REŽIMŲ TAISYKLĖS:")
    for regime, rules in REGIME_RULES.items():
        print(f"\n   [{regime}]")
        for key, val in rules.items():
            print(f"     {key:<15}: {val}")

    print("\n" + "="*52)
    print("   IŠVADA:")
    if current == "BULL":
        print("   Rinka KYLANTI — robotas prekiauja TIK BUY")
    elif current == "BEAR":
        print("   Rinka KRENTANTI — robotas prekiauja TIK SELL")
    else:
        print("   Rinka ŠONINĖ — robotas sumažina pozicijas")
    print("="*52 + "\n")

# ── Paleidimas ────────────────────────────────────────────────
if __name__ == "__main__":
    print("Analizuojamas rinkos režimas...")
    df = generate_data()
    df = add_indicators(df)
    df = detect_regime(df)
    print_results(df)
