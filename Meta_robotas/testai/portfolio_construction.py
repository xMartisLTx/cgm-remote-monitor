import pandas as pd
import numpy as np

np.random.seed(42)

# ── Valiutų porų savybės ──────────────────────────────────────
ASSETS = {
    "EURUSD": {"win_r": 0.57, "rr": 2.5, "korel": 1.0,  "spread": 0.8,  "sesija": "London+NY"},
    "GBPUSD": {"win_r": 0.55, "rr": 2.5, "korel": 0.80, "spread": 1.2,  "sesija": "London+NY"},
    "USDJPY": {"win_r": 0.54, "rr": 2.0, "korel": -0.3, "spread": 1.0,  "sesija": "Azija+NY"},
    "XAUUSD": {"win_r": 0.52, "rr": 3.0, "korel": -0.1, "spread": 3.0,  "sesija": "London+NY"},
    "USDCAD": {"win_r": 0.53, "rr": 2.0, "korel": -0.4, "spread": 1.5,  "sesija": "NY"},
}

# ── Portfelio paskirstymas ────────────────────────────────────
ALLOCATIONS = {
    "EURUSD": 0.35,
    "GBPUSD": 0.25,
    "USDJPY": 0.20,
    "XAUUSD": 0.10,
    "USDCAD": 0.10,
}

# ── Simuliacija ───────────────────────────────────────────────
def simulate_portfolio(capital=10_000, n_months=12, trades_per_month=4):
    monthly = []
    cap     = capital

    for month in range(n_months):
        month_pnl = 0
        for asset, alloc in ALLOCATIONS.items():
            a        = ASSETS[asset]
            risk_amt = cap * alloc * 0.01
            for _ in range(trades_per_month):
                won      = np.random.random() < a["win_r"]
                pnl      = risk_amt * a["rr"] if won else -risk_amt
                month_pnl += pnl
        cap += month_pnl
        monthly.append({"menesis": month + 1, "pnl": month_pnl, "kapitalas": cap})

    return pd.DataFrame(monthly)

# ── Rezultatai ────────────────────────────────────────────────
def print_results(df):
    total   = df["pnl"].sum()
    avg_m   = df["pnl"].mean()
    win_m   = (df["pnl"] > 0).sum()
    peak    = df["kapitalas"].cummax()
    max_dd  = ((df["kapitalas"] - peak) / peak * 100).min()

    print("\n" + "="*54)
    print("     SMC SNIPER — PORTFOLIO CONSTRUCTION")
    print("="*54)

    print("\n📊 PORTFELIO SUDĖTIS:")
    print(f"   {'Pora':<10} {'Svoris':>7} {'Win%':>6} {'RR':>5} {'Spread':>7} {'Sesija'}")
    print("   " + "-"*55)
    for asset, alloc in ALLOCATIONS.items():
        a = ASSETS[asset]
        print(f"   {asset:<10} {alloc*100:>6.0f}% {a['win_r']*100:>5.0f}% "
              f"{a['rr']:>5.1f} {a['spread']:>5.1f}pip  {a['sesija']}")

    print("\n📈 MĖNESINIAI REZULTATAI:")
    print(f"   {'Mėn':>4} {'P&L':>9} {'Kapitalas':>12} {'':>5}")
    print("   " + "-"*32)
    for _, r in df.iterrows():
        arrow = "▲" if r["pnl"] >= 0 else "▼"
        print(f"   {int(r['menesis']):>4} {arrow} ${r['pnl']:>7,.0f}  ${r['kapitalas']:>10,.0f}")

    print(f"\n💰 METINĖ SUVESTINĖ:")
    print(f"   Pradinis kapitalas : $10,000")
    print(f"   Galutinis kapitalas: ${df['kapitalas'].iloc[-1]:,.0f}")
    print(f"   Metinis pelnas     : ${total:,.0f}")
    print(f"   Metinis augimas    : {total/10000*100:.1f}%")
    print(f"   Pelningų mėnesių   : {win_m}/12")
    print(f"   Vid. mėnesinis P&L : ${avg_m:,.0f}")
    print(f"   Max Drawdown       : {max_dd:.1f}%")

    print("\n🎯 DIVERSIFIKACIJOS NAUDA:")
    print("   → EURUSD + GBPUSD   : stipri koreliacija (apdrausta)")
    print("   → USDJPY + USDCAD   : maža koreliacija (diversifikacija)")
    print("   → XAUUSD            : negatyvi koreliacija (apsauga nuo nuosmukio)")

    print("\n⚠️  RIZIKOS TAISYKLĖS:")
    print("   → Max 3 poros vienu metu")
    print("   → Bendras dienos limitas: -2% portfelio")
    print("   → Jei 2 poros SIDEWAYS — trečią praleisti")
    print("="*54 + "\n")

if __name__ == "__main__":
    print("Konstruojamas diversifikuotas portfelis...")
    df = simulate_portfolio()
    print_results(df)
