# SMC Sniper EA — Įdiegimas į MetaTrader 4

## Žingsniai kompiuteryje

### 1. Nukopijuoti failą
Nukopijuok `SMC_Sniper_EA.mq4` į:
```
C:\Users\[tavo vardas]\AppData\Roaming\MetaQuotes\Terminal\[ID]\MQL4\Experts\
```
Arba MT4 meniu: **File → Open Data Folder → MQL4 → Experts**

### 2. Sukompiliuoti
1. MT4 atidaryti **MetaEditor** (F4 arba Tools → MetaEditor)
2. Atidaryti `SMC_Sniper_EA.mq4`
3. Spausti **Compile** (F7)
4. Turi būti: `0 errors, 0 warnings`

### 3. Prijungti prie grafiko
1. Atidaryti grafiką (pvz. EURUSD, H1)
2. Navigator lange rasti **Expert Advisors → SMC_Sniper_EA**
3. Vilkti ant grafiko
4. Lange įjungti: ✅ Allow live trading
5. Spausti OK

### 4. Įjungti Auto Trading
Spausti mygtuką **"Auto Trading"** viršuje (turi būti žalias)

---

## Rekomenduojami parametrai pradžiai

| Parametras | Demo sąskaita | Reali sąskaita |
|---|---|---|
| RiskPercent | 2.0% | 1.0% |
| RR_TP1 | 2.0 | 2.0 |
| RR_TP2 | 3.0 | 3.0 |
| MaxLossStreak | 3 | 3 |
| MaxDailyLossPct | 3.0% | 2.0% |
| UseSessionFilter | true | true |

---

## Grafiko nustatymai
- **Pora:** EURUSD, GBPUSD, arba USDJPY
- **Timeframe:** H1 (1 valanda)
- **Brokeris:** ECN su mažu spread (< 1.5 pip EURUSD)

---

## Stebėjimas
- Žurnale (Journal) matysi visus EA veiksmus
- Raudona X ant grafiko = EA sustabdytas
- Juodveidas = EA veikia

---

## SVARBU
- Pirmiausia testuok ant **Demo sąskaitos** bent 1 mėnesį
- Naudok MT4 **Strategy Tester** (Ctrl+R) backtestui
- Pradėk su mažu lotažu (0.01)
