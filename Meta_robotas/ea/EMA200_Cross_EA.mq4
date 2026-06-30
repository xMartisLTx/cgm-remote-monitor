//+------------------------------------------------------------------+
//| EMA200 Cross EA v5.0                                             |
//| 1. Reversal: kaina kerta atgal → uždaro ir atidaro priešingą   |
//| 2. Compound: kas +30€ balansas → +10€ investicija              |
//| 3. Portfolio rizika: SL suma negali viršyti 20% balanso         |
//| 4. Sesija: tik nauji sandoriai blokuojami; esami valdomi 24/7  |
//| 5. Dynamic trailing: prie 50%/100% pelno → SL artimesnis       |
//+------------------------------------------------------------------+
#property copyright "Forex Signalai v5.0"
#property version   "5.0"
#property strict

// ─── PAGRINDINIAI NUSTATYMAI ──────────────────────────────────────
input int    EMA_Period       = 200;   // EMA periodas (raudona linija)
input int    ATR_Period       = 14;    // ATR periodas
input double RR_TP            = 3.0;   // Take-Profit RR (atsarginis)

// ─── TRAILING STOP NUSTATYMAI ─────────────────────────────────────
input double TrailingATR      = 1.5;   // Normalus trailing (ATR kartotinis)
input double Trailing50pct    = 1.0;   // Trailing kai pelnas >= 50% investicijos
input double Trailing100pct   = 0.5;   // Trailing kai pelnas >= 100% investicijos

// ─── MULTI-TRADE NUSTATYMAI ───────────────────────────────────────
input int    MaxTrades        = 3;     // Maks. sandorių skaičius vienu metu

// ─── RIZIKA ───────────────────────────────────────────────────────
input double StartBalance     = 50.0;  // Pradinis balansas (bazė)
input double InvestmentBase   = 10.0;  // Pradinė investicija EUR
input double BalanceStep      = 30.0;  // Kas +30€ balanse → investicija +10€
input double InvestmentStep   = 10.0;  // Investicijos padidėjimas EUR
input double SL_Percent       = 20.0;  // SL nuostolis % nuo investicijos (20%=2€)
input double MaxPortfolioRisk = 20.0;  // Max bendra rizika % nuo balanso

// ─── FILTRAI ──────────────────────────────────────────────────────
input int    MaxDailyLosses   = 3;     // Maks. nuostolių per dieną šiai porai
input double MaxDailyLossPct  = 20.0;  // Dienos nuostolių limitas % nuo balanso
input bool   UseSessionFilter = true;  // Sesijų filtras
input int    Session_Start    = 7;     // Sesijos pradžia GMT
input int    Session_End      = 17;    // Sesijos pabaiga GMT
input bool   ShowDebug        = true;  // Debug žurnalas
input int    MagicNumber      = 20250101;
input string EA_Comment       = "EMA200_Cross";

// ─── GLOBALŪS ─────────────────────────────────────────────────────
double   g_DayStartBalance = 0;
datetime g_LastTradeDay    = 0;
datetime g_LastBarTime     = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   g_DayStartBalance = AccountBalance();
   Print("=== EMA200 Cross EA v5.0 paleistas ===");
   Print("Pora: ", Symbol(), " | Max sandoriai: ", MaxTrades,
         " | Max nuostoliai/dieną: ", MaxDailyLosses);
   Print("Trailing: normalus ATR×", TrailingATR,
         " | 50% pelno ATR×", Trailing50pct,
         " | 100% pelno ATR×", Trailing100pct);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Investicija pagal balansą (be debug spausdinimo)                |
//+------------------------------------------------------------------+
double GetInvestmentAmount()
{
   double steps = MathFloor((AccountBalance() - StartBalance) / BalanceStep);
   if (steps < 0) steps = 0;
   return InvestmentBase + steps * InvestmentStep;
}

double GetRiskAmount() { return GetInvestmentAmount() * SL_Percent / 100.0; }

//+------------------------------------------------------------------+
//| Suskaičiuoja šiandien uždarytus nuostolingus sandorius šiai porai|
//+------------------------------------------------------------------+
int CountDailyLosses()
{
   int losses = 0;
   datetime dayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));

   for (int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if (OrderMagicNumber() != MagicNumber)            continue;
      if (OrderSymbol() != Symbol())                    continue;
      if (OrderType() > OP_SELL)                        continue;
      if (OrderCloseTime() < dayStart)                  break;
      if (OrderProfit() + OrderSwap() + OrderCommission() < 0)
         losses++;
   }
   return losses;
}

//+------------------------------------------------------------------+
//| Uždaro visus sandorius nurodytos krypties                        |
//+------------------------------------------------------------------+
void CloseTradesByType(int type)
{
   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderMagicNumber() != MagicNumber)           continue;
      if (OrderSymbol() != Symbol())                   continue;
      if (OrderType() != type)                         continue;

      double closePrice = (type == OP_BUY) ? Bid : Ask;
      if (OrderClose(OrderTicket(), OrderLots(), closePrice, 5, clrOrange))
         Print("[REVERSAL] Uždarytas ", (type == OP_BUY ? "BUY" : "SELL"),
               " #", OrderTicket(), " | Pelnas: ",
               DoubleToString(OrderProfit(), 2), "€");
   }
}

//+------------------------------------------------------------------+
//| EUR užrakinta SL pozicijoje (teigiama = pelnas užrakintas)      |
//+------------------------------------------------------------------+
double GetLockedProfit(int orderIndex)
{
   if (!OrderSelect(orderIndex, SELECT_BY_POS, MODE_TRADES)) return -9999;
   double op       = OrderOpenPrice();
   double sl       = OrderStopLoss();
   double lots     = OrderLots();
   double tickVal  = MarketInfo(OrderSymbol(), MODE_TICKVALUE);
   double tickSize = MarketInfo(OrderSymbol(), MODE_TICKSIZE);
   if (sl == 0 || tickVal == 0 || tickSize == 0) return -9999;
   double diff = (OrderType() == OP_BUY) ? (sl - op) : (op - sl);
   return (diff / tickSize) * tickVal * lots;
}

//+------------------------------------------------------------------+
//| Skaičiuoja bendrą riziką EUR — suma visų SL nuostolių          |
//| Sandoriai su SL virš atvėrimo = 0 rizika (pelnas užrakintas)   |
//+------------------------------------------------------------------+
double GetTotalRiskAtStake()
{
   double total = 0;
   for (int i = 0; i < OrdersTotal(); i++)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderMagicNumber() != MagicNumber)           continue;
      if (OrderSymbol() != Symbol())                   continue;

      double op       = OrderOpenPrice();
      double sl       = OrderStopLoss();
      double lots     = OrderLots();
      double tickVal  = MarketInfo(OrderSymbol(), MODE_TICKVALUE);
      double tickSize = MarketInfo(OrderSymbol(), MODE_TICKSIZE);

      if (sl == 0 || tickVal == 0 || tickSize == 0) continue;

      double diff = 0;
      if (OrderType() == OP_BUY  && sl < op) diff = op - sl;
      if (OrderType() == OP_SELL && sl > op) diff = sl - op;

      if (diff > 0)
         total += (diff / tickSize) * tickVal * lots;
   }
   return total;
}

//+------------------------------------------------------------------+
//| Tikrina ar galima atidaryti naują sandorį pagal portfelio riziką|
//+------------------------------------------------------------------+
bool PortfolioRiskOK()
{
   double maxRisk      = AccountBalance() * (MaxPortfolioRisk / 100.0);
   double currentRisk  = GetTotalRiskAtStake();
   double newRisk      = GetRiskAmount();
   double totalIfOpen  = currentRisk + newRisk;

   if (ShowDebug)
      Print("[RIZIKA] Dabartinė: ", DoubleToString(currentRisk, 2),
            "€ | Naujas: +", DoubleToString(newRisk, 2),
            "€ | Iš viso: ", DoubleToString(totalIfOpen, 2),
            "€ | Limitas: ", DoubleToString(maxRisk, 2), "€");

   if (totalIfOpen > maxRisk)
   {
      if (ShowDebug)
         Print("[BLOKUOTA] Rizika ", DoubleToString(totalIfOpen, 2),
               "€ > limitas ", DoubleToString(maxRisk, 2), "€ (",
               MaxPortfolioRisk, "% nuo ", DoubleToString(AccountBalance(), 2), "€)");
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
int CountOpenTrades()
{
   int n = 0;
   for (int i = 0; i < OrdersTotal(); i++)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol()) n++;
   }
   return n;
}

int GetOpenDirection()
{
   for (int i = 0; i < OrdersTotal(); i++)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderMagicNumber() != MagicNumber)           continue;
      if (OrderSymbol() != Symbol())                   continue;
      if (OrderType() == OP_BUY)  return  1;
      if (OrderType() == OP_SELL) return -1;
   }
   return 0;
}

//+------------------------------------------------------------------+
void OnTick()
{
   if (Time[0] == g_LastBarTime) return;
   g_LastBarTime = Time[0];

   ResetDailyBalance();
   ManageOpenTrades();   // Trailing valdymas VISADA — net už sesijos ribų

   // ─── DIENOS NUOSTOLIŲ LIMITAS (šiai porai) ────────────────────
   int dailyLosses = CountDailyLosses();
   if (dailyLosses >= MaxDailyLosses)
   {
      if (ShowDebug)
         Print("[FILTRAS] ", Symbol(), " šiandien ", dailyLosses,
               " nuostoliai — nauji sandoriai šiai porai blokuoti");
      return;
   }

   // ─── 20% DIENOS NUOSTOLIŲ LIMITAS (visoms poroms) ────────────
   if (g_DayStartBalance > 0)
   {
      double loss = (g_DayStartBalance - AccountBalance()) / g_DayStartBalance * 100.0;
      if (loss >= MaxDailyLossPct)
      {
         if (ShowDebug)
            Print("[FILTRAS] Dienos limitas -", DoubleToString(loss, 1),
                  "% (riba ", MaxDailyLossPct, "%) — sustabdyta");
         return;
      }
   }

   // ─── SESIJŲ FILTRAS (tik naujų sandorių blokavimas) ──────────
   if (UseSessionFilter)
   {
      int hour = TimeHour(TimeGMT());
      if (hour < Session_Start || hour >= Session_End)
      {
         if (ShowDebug)
            Print("[FILTRAS] Ne sesijos laikas GMT ", hour,
                  ":xx — nauji sandoriai blokuoti, esami toliau valdomi");
         return;
      }
   }

   // ─── EMA200 KIRTIMO APTIKIMAS ─────────────────────────────────
   double ema1 = iMA(NULL, 0, EMA_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema2 = iMA(NULL, 0, EMA_Period, 0, MODE_EMA, PRICE_CLOSE, 2);

   bool crossUp   = (Close[2] < ema2) && (Close[1] > ema1);
   bool crossDown = (Close[2] > ema2) && (Close[1] < ema1);

   int    openDir   = GetOpenDirection();
   int    openCount = CountOpenTrades();
   double invest    = GetInvestmentAmount();
   double riskNow   = invest * SL_Percent / 100.0;

   if (ShowDebug && (crossUp || crossDown))
      Print("[SIGNALAS] ", (crossUp ? "AUKŠTYN" : "ŽEMYN"),
            " | Balansas: ", DoubleToString(AccountBalance(), 2),
            "€ | Investicija: ", DoubleToString(invest, 2),
            "€ | Rizika: ", DoubleToString(riskNow, 2), "€");

   // ─── REVERSAL: priešinga kryptis → uždaryti ir apsisukti ──────
   if (crossUp && openDir == -1)
   {
      Print("[REVERSAL] Kaina kerta AUKŠTYN — uždaromi SELL, atidaromas BUY");
      CloseTradesByType(OP_SELL);
      OpenTrade(1, riskNow);
      return;
   }
   if (crossDown && openDir == 1)
   {
      Print("[REVERSAL] Kaina kerta ŽEMYN — uždaromi BUY, atidaromas SELL");
      CloseTradesByType(OP_BUY);
      OpenTrade(-1, riskNow);
      return;
   }

   // ─── PAPILDOMAS SANDORIS TA PAČIA KRYPTIMI ────────────────────
   if (openCount >= MaxTrades) return;
   if (!PortfolioRiskOK())     return;

   if (crossUp)   OpenTrade(1,  riskNow);
   if (crossDown) OpenTrade(-1, riskNow);
}

//+------------------------------------------------------------------+
void OpenTrade(int signal, double riskAmt)
{
   double atr    = iATR(NULL, 0, ATR_Period, 1);
   double slDist = atr * TrailingATR;
   double price  = (signal == 1) ? Ask : Bid;
   double sl     = (signal == 1) ? price - slDist : price + slDist;
   double tp     = (signal == 1) ? price + slDist * RR_TP : price - slDist * RR_TP;

   sl = NormalizeDouble(sl, Digits);
   tp = NormalizeDouble(tp, Digits);

   double tickVal  = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   double lotStep  = MarketInfo(Symbol(), MODE_LOTSTEP);
   double minLot   = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot   = MarketInfo(Symbol(), MODE_MAXLOT);

   double lot = minLot;
   if (tickVal > 0 && tickSize > 0 && slDist > 0)
   {
      lot = riskAmt / (slDist / tickSize * tickVal);
      lot = MathFloor(lot / lotStep) * lotStep;
      lot = MathMax(minLot, MathMin(maxLot, lot));
   }

   int    type = (signal == 1) ? OP_BUY  : OP_SELL;
   string dir  = (signal == 1) ? "BUY"   : "SELL";
   color  clr  = (signal == 1) ? clrGreen : clrRed;

   int ticket = OrderSend(Symbol(), type, lot, price, 5, sl, tp,
                          EA_Comment, MagicNumber, 0, clr);
   if (ticket > 0)
      Print("✅ ", dir, " atverta | Lot: ", DoubleToString(lot, 2),
            " | Kaina: ", DoubleToString(price, Digits),
            " | SL: ", DoubleToString(sl, Digits),
            " | TP: ", DoubleToString(tp, Digits),
            " | Max nuostolis: ", DoubleToString(riskAmt, 2), "€");
   else
      Print("❌ Klaida ", GetLastError(), " atidarant ", dir);
}

//+------------------------------------------------------------------+
//| Dynamic trailing: SL artėja prie kainos kai pelnas auga         |
//|                                                                  |
//| Pelnas < 50% investicijos  → ATR × 1.5 (normalus atstumas)     |
//| Pelnas 50–99% investicijos → ATR × 1.0 (artimesnis)            |
//| Pelnas ≥ 100% investicijos → ATR × 0.5 (labai artimas)         |
//|                                                                  |
//| Rezultatas: kuo didesnis pelnas, tuo greičiau užsidaro          |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
   double invest = GetInvestmentAmount();

   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderMagicNumber() != MagicNumber)           continue;
      if (OrderSymbol() != Symbol())                   continue;

      double op     = OrderOpenPrice();
      double sl     = OrderStopLoss();
      double atr    = iATR(NULL, 0, ATR_Period, 1);
      double profit = OrderProfit();

      // Pasirinkti trailing multiplier pagal dabartinį pelną
      double profitRatio = (invest > 0) ? (profit / invest) : 0.0;
      double trailMult;
      string trailLabel;
      if (profitRatio >= 1.0)
      {
         trailMult  = Trailing100pct;
         trailLabel = "100%+";
      }
      else if (profitRatio >= 0.5)
      {
         trailMult  = Trailing50pct;
         trailLabel = "50%+";
      }
      else
      {
         trailMult  = TrailingATR;
         trailLabel = "normalus";
      }

      if (OrderType() == OP_BUY)
      {
         double newSL = NormalizeDouble(Bid - atr * trailMult, Digits);
         if (newSL > sl && newSL > op)
         {
            if (OrderModify(OrderTicket(), op, newSL, OrderTakeProfit(), 0, clrBlue))
            {
               if (ShowDebug)
                  Print("[TRAILING BUY] SL: ", DoubleToString(sl, Digits),
                        " → ", DoubleToString(newSL, Digits),
                        " | ATR×", DoubleToString(trailMult, 1), " (", trailLabel, ")",
                        " | Pelnas: ", DoubleToString(profit, 2), "€",
                        " | Užrakinta: ", DoubleToString(GetLockedProfit(i), 2), "€");
            }
         }
      }
      else if (OrderType() == OP_SELL)
      {
         double newSL = NormalizeDouble(Ask + atr * trailMult, Digits);
         if ((sl == 0 || newSL < sl) && newSL < op)
         {
            if (OrderModify(OrderTicket(), op, newSL, OrderTakeProfit(), 0, clrBlue))
            {
               if (ShowDebug)
                  Print("[TRAILING SELL] SL: ", DoubleToString(sl, Digits),
                        " → ", DoubleToString(newSL, Digits),
                        " | ATR×", DoubleToString(trailMult, 1), " (", trailLabel, ")",
                        " | Pelnas: ", DoubleToString(profit, 2), "€",
                        " | Užrakinta: ", DoubleToString(GetLockedProfit(i), 2), "€");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
void ResetDailyBalance()
{
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if (today != g_LastTradeDay)
   {
      g_DayStartBalance = AccountBalance();
      g_LastTradeDay    = today;
      if (ShowDebug)
         Print("=== Nauja diena | ", Symbol(), " | Balansas: ",
               DoubleToString(g_DayStartBalance, 2), "€ ===");
   }
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("EMA200 Cross EA v5.0 sustabdytas | Balansas: ",
         DoubleToString(AccountBalance(), 2), "€");
}
//+------------------------------------------------------------------+
