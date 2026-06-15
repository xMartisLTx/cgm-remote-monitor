# Forex Roboto Strategija

## Bendra informacija

| Parametras | Reikšmė |
|---|---|
| Platforma | MetaTrader 4 (MT4) |
| Signalų šaltinis | TradingView |
| Strategijos tipas | SMC + Techninė analizė + Price Action |
| Valiutų poros | (užpildyti) |
| Pagrindinis timeframe | (užpildyti) |
| Struktūros timeframe | (užpildyti) |

---

## 1. Smart Money Concepts (SMC)

### Break of Structure (BOS) / Change of Character (CHOCH)
- **BOS** = tendencija tęsiasi → prekiaujame su tendencija
- **CHOCH** = tendencija keičiasi → laukiame patvirtinimo
- Nustatome ant **aukštesnio timeframe** (H4 arba D1)

### Order Block (OB)
- Ieškome paskutinės žvakės prieš stiprų judėjimą
- **Bullish OB** = paskutinė bearish žvakė prieš kylimą (pirkti)
- **Bearish OB** = paskutinė bullish žvakė prieš kritimą (parduoti)

### Fair Value Gap (FVG)
- Trys žvakės kur vidurinė "praleidžia" kainą
- Kaina dažnai grįžta užpildyti FVG
- Naudojame kaip papildomą zoną

### Inducement (IDM)
- Likvidumo gaudymas prieš tikrą judėjimą
- Laukiame kol rinka "pagaus" stop-loss zonoje esančius orderius

---

## 2. Techniniai indikatoriai (patvirtinimas)

### RSI (Relative Strength Index)
- Periodas: **14**
- Pirkimas: RSI < 30 (perparduotas) arba kryžius iš apačios
- Pardavimas: RSI > 70 (perkuptas) arba kryžius iš viršaus

### MACD
- Greitas EMA: **12**
- Lėtas EMA: **26**
- Signalinė linija: **9**
- Pirkimas: MACD kerta signalą iš apačios
- Pardavimas: MACD kerta signalą iš viršaus

### Moving Averages
- EMA 50 — vidutinės tendencijos kryptis
- EMA 200 — ilgos tendencijos kryptis
- Pirkimas tik kai kaina virš EMA 200

---

## 3. Price Action (tikslus įėjimas)

### Žvakių modeliai
- **Pin Bar** — atstūmimas nuo zonos
- **Engulfing** — stiprus apvertimas
- **Doji** — neapibrėžtumas (vengti)

### Taisyklė
Įėjimas TIK kai žvakės modelis susiformuoja **OB arba FVG zonoje**

---

## 4. Įėjimo taisyklės (visos sąlygos turi sutapti)

### Pirkimas (BUY) ✅
- [ ] HTF tendencija — bullish (BOS aukštyn)
- [ ] Kaina pasiekė Bullish Order Block
- [ ] RSI < 50 ir kyla
- [ ] MACD bullish
- [ ] Bullish žvakės modelis zonoje

### Pardavimas (SELL) ✅
- [ ] HTF tendencija — bearish (BOS žemyn)
- [ ] Kaina pasiekė Bearish Order Block
- [ ] RSI > 50 ir krenta
- [ ] MACD bearish
- [ ] Bearish žvakės modelis zonoje

---

## 5. Rizikos valdymas

| Parametras | Reikšmė |
|---|---|
| Rizika per sandorį | (užpildyti) % |
| Stop-Loss | Už Order Block ribų |
| Take-Profit 1 | 1:1 RR (50% pozicijos) |
| Take-Profit 2 | 1:2 RR (likusi dalis) |
| Maks. sandorių per dieną | (užpildyti) |
| Maks. nuostolis per dieną | (užpildyti) % |

---

## 6. Kada NEPREKIAUTI

- Prieš svarbias naujienas (NFP, CPI, Fed...)
- Penktadienį po 20:00
- Sesijų sandūrose (mažas likvidumas)
- Kai spread didesnis nei įprastai

---

## 7. Brokerio informacija

| Parametras | Reikšmė |
|---|---|
| Brokeris | (užpildyti) |
| Sąskaitos tipas | Demo / Reali |
| Minimalus lotas | 0.01 |
| Svertas | (užpildyti) |
