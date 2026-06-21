import pandas as pd
import numpy as np

np.random.seed(42)

def run_simulation(n_sim=1000, n_trades=44, win_rate=0.57,
                   rr=2.5, risk_pct=0.01, capital=10_000):
    finals, max_dds, ruins = [], [], 0

    for _ in range(n_sim):
        cap        = capital
        peak       = capital
        max_dd     = 0
        ruined     = False
        loss_streak = 0

        for _ in range(n_trades):
            if loss_streak >= 3:
                loss_streak = 0
                continue
            risk_amt = cap * risk_pct
            won      = np.random.random() < win_rate
            pnl      = risk_amt * rr if won else -risk_amt
            cap     += pnl
            peak     = max(peak, cap)
            dd       = (peak - cap) / peak * 100
            max_dd   = max(max_dd, dd)
            loss_streak = 0 if won else loss_streak + 1
            if cap < capital * 0.5:
                ruined = True
                break

        finals.append(cap)
        max_dds.append(max_dd)
        if ruined:
            ruins += 1

    return np.array(finals), np.array(max_dds), ruins

def print_results(finals, max_dds, ruins, capital=10_000, n_sim=1000):
    pct = (finals - capital) / capital * 100

    print("\n" + "="*54)
    print("     SMC SNIPER — MONTE CARLO SIMULIACIJA")
    print(f"     ({n_sim:,} simuliacijų × 44 sandoriai)")
    print("="*54)

    print("\n📊 GALUTINIO KAPITALO PASISKIRSTYMAS:")
    p5, p25, p50, p75, p95 = np.percentile(pct, [5, 25, 50, 75, 95])
    print(f"   Blogiausias 5%  : {p5:>+.1f}%  (${capital*(1+p5/100):>8,.0f})")
    print(f"   Blogesnis 25%   : {p25:>+.1f}%  (${capital*(1+p25/100):>8,.0f})")
    print(f"   Medianas 50%    : {p50:>+.1f}%  (${capital*(1+p50/100):>8,.0f})")
    print(f"   Geresnis 75%    : {p75:>+.1f}%  (${capital*(1+p75/100):>8,.0f})")
    print(f"   Geriausias 95%  : {p95:>+.1f}%  (${capital*(1+p95/100):>8,.0f})")

    prob_profit = (finals > capital).sum() / n_sim * 100
    prob_20pct  = (pct > 20).sum() / n_sim * 100
    prob_50pct  = (pct > 50).sum() / n_sim * 100

    print(f"\n🎯 TIKIMYBĖS:")
    print(f"   Pelno tikimybė       : {prob_profit:.1f}%")
    print(f"   >20% augimo tikimybė : {prob_20pct:.1f}%")
    print(f"   >50% augimo tikimybė : {prob_50pct:.1f}%")
    print(f"   Bankroto tikimybė    : {ruins/n_sim*100:.1f}%")

    print(f"\n📉 DRAWDOWN ANALIZĖ:")
    dd5, dd50, dd95 = np.percentile(max_dds, [5, 50, 95])
    print(f"   Vidutinis max DD     : {np.mean(max_dds):.1f}%")
    print(f"   Blogiausias 95% DD   : {dd95:.1f}%")
    print(f"   Medianas DD          : {dd50:.1f}%")

    print(f"\n🔍 STRATEGIJOS PATIKIMUMAS:")
    if ruins / n_sim < 0.01:
        print("   ✅ Bankroto rizika < 1% — LABAI SAUGI")
    elif ruins / n_sim < 0.05:
        print("   ⚠️  Bankroto rizika < 5% — SAUGI")
    else:
        print("   ❌ Bankroto rizika > 5% — PERŽIŪRĖTI")

    if prob_profit > 80:
        print("   ✅ Pelno tikimybė > 80% — PATIKIMA")
    elif prob_profit > 65:
        print("   ⚠️  Pelno tikimybė > 65% — VIDUTINĖ")
    else:
        print("   ❌ Pelno tikimybė < 65% — SILPNA")

    if dd95 < 15:
        print("   ✅ Blogiausias DD < 15% — VALDOMAS")
    else:
        print("   ⚠️  Blogiausias DD > 15% — PERŽIŪRĖTI RIZIKĄ")

    print(f"\n💡 IŠVADA:")
    print(f"   Tikėtinas metų rezultatas: {p50:+.0f}% — {p75:+.0f}%")
    print(f"   Blogiausias scenarijus   : {p5:+.0f}%")
    print(f"   Geriausias scenarijus    : {p95:+.0f}%")
    print(f"   Strategija yra {'PATIKIMA' if prob_profit > 75 and ruins/n_sim < 0.02 else 'VIDUTINĖ'}")
    print("="*54 + "\n")

if __name__ == "__main__":
    print("Vykdoma Monte Carlo simuliacija (1000 scenarijų)...")
    finals, max_dds, ruins = run_simulation()
    print_results(finals, max_dds, ruins)
