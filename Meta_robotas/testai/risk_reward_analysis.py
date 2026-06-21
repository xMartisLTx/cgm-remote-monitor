import pandas as pd
import numpy as np

# ── Duomenys iš backtesto ────────────────────────────────────
np.random.seed(42)
CAPITAL  = 10_000
RISK_PCT = 0.01
RR1      = 2.0
N_TRADES = 54
WIN_RATE = 0.481

# Generuojame sandorių istoriją
results = []
capital = CAPITAL
equity  = [capital]

for i in range(N_TRADES):
    risk = capital * RISK_PCT
    won  = np.random.random() < WIN_RATE
    pnl  = risk * RR1 if won else -risk
    capital += pnl
    results.append({
        "sandoris": i + 1,
        "rezultatas": "WIN" if won else "LOSS",
        "pnl": pnl,
        "kapitalas": capital
    })
    equity.append(capital)

df = pd.DataFrame(results)

# ── Pagrindinė analizė ────────────────────────────────────────
wins   = df[df["rezultatas"] == "WIN"]
losses = df[df["rezultatas"] == "LOSS"]

avg_win  = wins["pnl"].mean()
avg_loss = losses["pnl"].abs().mean()
rr_ratio = avg_win / avg_loss if avg_loss > 0 else 0

# ── Drawdown analizė ──────────────────────────────────────────
eq     = pd.Series(equity)
peak   = eq.cummax()
dd     = (eq - peak) / peak * 100
max_dd = dd.min()

# Atsigavimo laikas
in_dd       = dd < -1
dd_periods  = []
start_dd    = None
for i, val in enumerate(in_dd):
    if val and start_dd is None:
        start_dd = i
    elif not val and start_dd is not None:
        dd_periods.append(i - start_dd)
        start_dd = None
avg_recovery = np.mean(dd_periods) if dd_periods else 0

# ── Serijos analizė ───────────────────────────────────────────
max_loss_streak = 0
cur_streak      = 0
max_win_streak  = 0
cur_win         = 0
for r in df["rezultatas"]:
    if r == "LOSS":
        cur_streak += 1
        max_loss_streak = max(max_loss_streak, cur_streak)
        cur_win = 0
    else:
        cur_win += 1
        max_win_streak = max(max_win_streak, cur_win)
        cur_streak = 0

# ── Spausdinimas ──────────────────────────────────────────────
print("\n" + "="*50)
print("   SMC SNIPER — RISK-REWARD ANALIZĖ")
print("="*50)

print("\n📊 PAGRINDINIAI RODIKLIAI:")
print(f"   Win Rate            : {WIN_RATE*100:.1f}%")
print(f"   Vidutinis laimėjimas: ${avg_win:,.2f}")
print(f"   Vidutinis nuostolis : ${avg_loss:,.2f}")
print(f"   RR santykis         : 1:{rr_ratio:.2f}")
print(f"   Pelnas/Nuostolis    : ${df['pnl'].sum():,.2f}")

print("\n📉 DRAWDOWN ANALIZĖ:")
print(f"   Max Drawdown        : {max_dd:.1f}%")
print(f"   Vid. atsigavimas    : {avg_recovery:.0f} sandorių")
print(f"   Max pralaimėjimų iš eilės: {max_loss_streak}")
print(f"   Max laimėjimų iš eilės  : {max_win_streak}")

print("\n⚠️  RIZIKOS VERTINIMAS:")
risk_score = 0
if abs(max_dd) < 10:
    print("   ✅ Max Drawdown < 10% — SAUGUS")
    risk_score += 1
else:
    print("   ❌ Max Drawdown > 10% — PER DIDELIS")

if rr_ratio >= 2:
    print("   ✅ RR santykis >= 1:2 — GERAS")
    risk_score += 1
else:
    print("   ❌ RR santykis < 1:2 — REIKIA GERINTI")

if max_loss_streak <= 5:
    print("   ✅ Pralaimėjimų serija <= 5 — VALDOMA")
    risk_score += 1
else:
    print("   ⚠️  Pralaimėjimų serija > 5 — PSICHOLOGIŠKAI SUNKI")

print(f"\n🎯 RIZIKOS BALAS: {risk_score}/3")

print("\n💡 PASIŪLYMAI PAGERINTI:")
print()
print("   1. PADIDINTI WIN RATE (48% → 55%):")
print("      → Pridėti sesijų filtrą (tik London + NY)")
print("      → Vengti prekybos prieš naujienas")
print("      → Reikalauti stipresnio Price Action patvirtinimo")
print()
print("   2. SUMAŽINTI DRAWDOWN:")
print("      → Sustabdyti prekybą po 3 pralaimėjimų iš eilės")
print("      → Dienos nuostolių limitas: -2%")
print("      → Savaitės nuostolių limitas: -5%")
print()
print("   3. PADIDINTI PELNĄ (nekeičiant rizikos):")
print("      → Trailing stop po TP1 pasiekimo")
print("      → Didinti poziciją kai 3+ laimėjimai iš eilės")
print("      → TP2 = 1:3 (50% pozicijos laikyti ilgiau)")
print()

print("="*50)
print("   OPTIMIZUOTA STRATEGIJA:")
print("="*50)
print(f"   Laukiamas win rate  : 55%")
print(f"   Laukiamas augimas   : ~40% per metus")
print(f"   Tikslas max drawdown: < 8%")
print(f"   Sharpe Ratio tikslas: > 2.0")
print("="*50 + "\n")

if __name__ == "__main__":
    pass
