# Strategija A — "SMC Sniper"

## Bendra informacija

| Parametras | Reikšmė |
|---|---|
| Platforma | MetaTrader 4 (MT4) |
| Strategijos pavadinimas | SMC Sniper |
| Rinka | Forex |
| Valiutų poros | EURUSD, GBPUSD, USDJPY |
| Struktūros timeframe | H4 |
| Įėjimo timeframe | H1 |
| Rizika per sandorį | 1-2% |
| RR santykis | 1:2 - 1:3 |

---

## Indikatoriai

- **EMA 50** — vidutinė tendencija
- **EMA 200** — ilga tendencija (prekiaujame tik su ja)
- **RSI 14** — patvirtinimas (pirkimas < 50, pardavimas > 50)

---

## Įėjimo taisyklės

### BUY signalas
1. H4: Bullish BOS (aukštesnis aukštumas)
2. Kaina virš EMA 200 (H1)
3. Kaina grįžta į Bullish Order Block
4. RSI < 50 ir kyla
5. Bullish žvakė OB zonoje (Pin Bar arba Engulfing)

### SELL signalas
1. H4: Bearish BOS (žemesnis žemumas)
2. Kaina žemiau EMA 200 (H1)
3. Kaina grįžta į Bearish Order Block
4. RSI > 50 ir krenta
5. Bearish žvakė OB zonoje (Pin Bar arba Engulfing)

---

## Rizikos valdymas

| Parametras | Reikšmė |
|---|---|
| Stop-Loss | Už OB ribų + 3-5 pip buferis |
| Take-Profit 1 | 1:2 RR (uždaryti 50%) |
| Take-Profit 2 | 1:3 RR (likusi dalis) |
| Maks. sandorių per dieną | 3 |
| Maks. nuostolis per dieną | 3% |
| Prekybos sesijos | London (08:00-12:00 GMT), NY (13:00-17:00 GMT) |

---

## Kada NEPREKIAUTI

- Prieš NFP, CPI, Fed sprendimus
- Penktadienį po 17:00 GMT
- Azijos sesijoje (mažas likvidumas)
- Kai spread > 2 pip (EURUSD)
