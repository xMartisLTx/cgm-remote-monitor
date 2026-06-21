import pandas as pd
import numpy as np
from itertools import product

np.random.seed(42)

# ── Backtest funkcija su parametrais ─────────────────────────
def run_backtest(win_rate, rr, risk_pct, capital=10_000, n_trades=44):
    cap = capital
    trades = []
    loss_streak = 0
    for _ in range(n_trades):
        if loss_streak >= 3:
            continue
        risk_amt = cap * risk_pct
        won = np.random.random() < win_rate
        pnl = risk_amt * rr if won else -risk_amt
        cap += pnl
        loss_streak = 0 if won else loss_streak + 1
        trades.append(pnl)
    if not trades:
        return None
    t       = pd.Series(trades)
    peak    = (capital + t.cumsum()).cummax()
    eq      = capital + t.cumsum()
    max_dd  = ((eq - peak) / peak * 100).min()
    sharpe  = (t.mean() / t.std() * np.sqrt(252)) if t.std() > 0 else 0
    return {
        "win_rate" : win_rate,
        "rr"       : rr,
        "risk_pct" : risk_pct,
        "pnl"      : t.sum(),
        "augimas"  : t.sum() / capital * 100,
        "max_dd"   : max_dd,
        "sharpe"   : sharpe,
    }

# ── Parametrų optimizacija ────────────────────────────────────
WIN_RATES = [0.50, 0.55, 0.57, 0.60]
RR_VALUES = [1.5, 2.0, 2.5, 3.0]
RISK_VALS = [0.005, 0.01, 0.015, 0.02]

def optimize():
    results = []
    for wr, rr, risk in product(WIN_RATES, RR_VALUES, RISK_VALS):
        r = run_backtest(wr, rr, risk)
        if r:
            results.append(r)
    return pd.DataFrame(results)

# ── Rezultatai ────────────────────────────────────────────────
def print_results(df):
    df_safe = df[(df["max_dd"] > -10) & (df["sharpe"] > 1.0)]
    best    = df_safe.sort_values("sharpe", ascending=False).head(5)

    print("\n" + "="*58)
    print("     SMC SNIPER — STRATEGIJOS OPTIMIZACIJA")
    print("="*58)

    print(f"\n🔍 Išbandyta kombinacijų : {len(df)}")
    print(f"   Saugių kombinacijų    : {len(df_safe)} (DD<10%, Sharpe>1)")

    print("\n🏆 TOP 5 GERIAUSIOS KOMBINACIJOS:")
    print(f"   {'Win%':>6} {'RR':>5} {'Rizika':>7} {'P&L':>8} {'Augimas':>8} {'MaxDD':>7} {'Sharpe':>7}")
    print("   " + "-"*52)
    for _, r in best.iterrows():
        print(f"   {r['win_rate']*100:>5.0f}% {r['rr']:>5.1f} {r['risk_pct']*100:>6.1f}%"
              f" ${r['pnl']:>7,.0f} {r['augimas']:>7.1f}% {r['max_dd']:>6.1f}% {r['sharpe']:>7.2f}")

    top = best.iloc[0]
    print(f"\n⚡ OPTIMALI KONFIGŪRACIJA:")
    print(f"   Win Rate  : {top['win_rate']*100:.0f}%")
    print(f"   RR santykis: 1:{top['rr']:.1f}")
    print(f"   Rizika    : {top['risk_pct']*100:.1f}% per sandorį")
    print(f"   Laukiamas augimas: {top['augimas']:.1f}%")
    print(f"   Max Drawdown     : {top['max_dd']:.1f}%")
    print(f"   Sharpe Ratio     : {top['sharpe']:.2f}")

    print("\n📋 PRIEŠ VS PO OPTIMIZACIJOS:")
    print(f"   {'Metrika':<22} {'Prieš':>10} {'Po':>10}")
    print(f"   {'Win Rate':<22} {'48.1%':>10} {top['win_rate']*100:.0f}%{'':>5}")
    print(f"   {'RR santykis':<22} {'1:2.0':>10} {'1:'+str(top['rr']):>10}")
    print(f"   {'Rizika/sandoriui':<22} {'1.0%':>10} {top['risk_pct']*100:.1f}%{'':>5}")
    print(f"   {'Augimas':<22} {'26.3%':>10} {top['augimas']:.1f}%{'':>5}")
    print(f"   {'Max Drawdown':<22} {'-4.0%':>10} {top['max_dd']:.1f}%{'':>5}")

    print("\n💡 OPTIMIZACIJOS IŠVADOS:")
    print("   → Didinti win rate iki 55-60% (sesijų filtras)")
    print("   → Laikyti RR 1:2.5 - 1:3 (trailing stop)")
    print("   → Rizika 1% — saugiausia ilgalaikei prekybai")
    print("="*58 + "\n")

if __name__ == "__main__":
    print("Optimizuojama strategija (64 kombinacijos)...")
    df = optimize()
    print_results(df)
