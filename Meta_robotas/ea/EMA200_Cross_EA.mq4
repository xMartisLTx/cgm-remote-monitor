//+------------------------------------------------------------------+
//| EMA200 Cross EA v5.6                                             |
//| 1. Reversal: kaina kerta atgal → uždaro ir atidaro priešingą   |
//| 2. Compound: kas +30€ balansas → +10€ investicija              |
//| 3. Portfolio rizika: SL suma negali viršyti 20% balanso         |
//| 4. SL seka kainą nuo pat atidarymo                              |
//| 5. Breakeven prie 30% pelno → SL šoka į entry, tada tęsia      |
//| 6. ADX filtras: šoninis rinka → neprekiaujame                   |
//| 7. Dvigubų sandorių blokavimas (cooldown po atidarymo)          |
//+------------------------------------------------------------------+
#property copyright "Forex Signalai v5.6"
#property version   "5.6"
#property strict

// ─── PAGRINDINIAI NUSTATYMAI ──────────────────────────────────────
input int    EMA_Period       = 200;   // EMA periodas (raudona linija)
input int    ATR_Period       = 14;    // ATR periodas

// ─── TRAILING STOP NUSTATYMAI ─────────────────────────────────────
input double TrailingATR      = 1.5;   // Normalus trailing (ATR kartotinis)
input double BreakevenPct     = 30.0;  // % pelno → SL šoka į entry (breakeven)
input double Trailing50pct    = 1.0;   // Trailing kai pelnas >= 50% investicijos
input double Trailing100pct   = 0.5;   // Trailing kai pelnas >= 100% investicijos

// ─── RIZIKA ───────────────────────────────────────────────────────
input double StartBalance     = 50.0;  // Pradinis balansas (bazė compound skaičiavimui)
input double InvestmentBase   = 10.0;  // Pradinė investicija EUR
input double BalanceStep      = 30.0;  // Kas +30€ balanse → investicija +10€
input double InvestmentStep   = 10.0;  // Investicijos padidėjimas EUR
input double MaxInvestment    = 100.0; // Maksimali investicija EUR (riba)
input double SL_Percent       = 20.0;  // SL nuostolis % nuo investicijos (20%=2€)
input double MaxPortfolioRisk = 20.0;  // Max bendra rizika % nuo balanso

// ─── ŠONINIO RINKOS FILTRAS ──────────────────────────────────────
input bool   UseADXFilter     = true;  // Šoninio rinkos filtras (ADX)
input int    ADX_Period       = 14;    // ADX periodas
input double ADX_MinLevel     = 20.0;  // Min ADX (žemiau = šoninis rinka, neprekiaujame)

// ─── FILTRAI ──────────────────────────────────────────────────────
input int    MaxDailyLosses   = 3;     // Maks. nuostolių per dieną šiai porai
input double MaxDailyLossPct  = 20.0;  // Dienos nuostolių limitas % nuo balanso
input bool   UseSessionFilter = false; // Sesijų filtras (false = 24h)
input int    Session_Start    = 7;     // Sesijos pradžia GMT (jei filtras įjungtas)
input int    Session_End      = 17;    // Sesijos pabaiga GMT (jei filtras įjungtas)
input bool   ShowDebug        = true;  // Debug žurnalas
input int    MagicNumber      = 20250101;
input string EA_Comment       = "EMA200_Cross";

// ─── GLOBALŪS ─────────────────────────────────────────────────────
double   g_DayStartBalance  = 0;
datetime g_LastTradeDay     = 0;
bool     g_WasAboveEMA      = false;
bool     g_EMAStateInited   = false;
int      g_LastHistoryTotal = 0;
datetime g_LastOpenBar      = 0;     // Paskutinis baras kuriame atidarytas sandoris

//+------------------------------------------------------------------+
int OnInit()
{
   g_DayStartBalance  = AccountBalance();
   g_LastHistoryTotal = OrdersHistoryTotal();
   Print("=== EMA200 Cross EA v5.6 paleistas ===");
   Print("Pora: ", Symbol(), " | Portfolio rizika: ", MaxPortfolioRisk,
         "% | Max nuostoliai/dieną: ", MaxDailyLosses);
   Print("Trailing: ATR×", TrailingATR,
         " | Breakeven: ", BreakevenPct, "%",
         " | 50%: ATR×", Trailing50pct,
         " | 100%: ATR×", Trailing100pct);
   Print("ADX filtras: ", UseADXFilter ? "ĮJUNGTAS" : "IŠJUNGTAS",
         " | Min ADX: ", ADX_MinLevel);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
double GetInvestmentAmount()
{
   double steps  = MathFloor((AccountBalance() - StartBalance) / BalanceStep);
   if (steps < 0) steps = 0;
   double invest = InvestmentBase + steps * InvestmentStep;
   return MathMin(invest, MaxInvestment);
}

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
      if (diff > 0) total += (diff / tickSize) * tickVal * lots;
   }
   return total;
}

//+------------------------------------------------------------------+
bool PortfolioRiskOK(double riskAmt)
{
   double maxRisk     = AccountBalance() * (MaxPortfolioRisk / 100.0);
   double currentRisk = GetTotalRiskAtStake();
   double totalIfOpen = currentRisk + riskAmt;
   if (ShowDebug)
      Print("[RIZIKA] Dabartinė: ", DoubleToString(currentRisk, 2),
            "€ | Naujas: +", DoubleToString(riskAmt, 2),
            "€ | Iš viso: ", DoubleToString(totalIfOpen, 2),
            "€ | Limitas: ", DoubleToString(maxRisk, 2), "€");
   if (totalIfOpen > maxRisk)
   {
      if (ShowDebug)
         Print("[BLOKUOTA] ", DoubleToString(totalIfOpen, 2), "€ > ",
               DoubleToString(maxRisk, 2), "€");
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
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
void LogClosedTrade()
{
   string filename = "EMA200_log_" + Symbol() + ".csv";
   bool   newFile  = (FileSize(filename) == 0 || !FileIsExist(filename));
   int    handle   = FileOpen(filename, FILE_CSV|FILE_READ|FILE_WRITE, ',');
   if (handle == INVALID_HANDLE) return;
   FileSeek(handle, 0, SEEK_END);
   if (newFile)
      FileWrite(handle, "Data", "Pora", "Tipas", "Entry", "Exit",
                "SL_atidarymo", "Lotai", "Pelnas_EUR", "Priezastis");
   string tipas    = (OrderType() == OP_BUY) ? "BUY" : "SELL";
   string priezast = "Reversal";
   string com      = OrderComment();
   if (StringFind(com, "[tp]") >= 0) priezast = "TP";
   if (StringFind(com, "[sl]") >= 0) priezast = "SL";
   double pelnas = OrderProfit() + OrderSwap() + OrderCommission();
   FileWrite(handle,
      TimeToString(OrderCloseTime(), TIME_DATE|TIME_MINUTES),
      OrderSymbol(), tipas,
      DoubleToString(OrderOpenPrice(),  Digits),
      DoubleToString(OrderClosePrice(), Digits),
      DoubleToString(OrderStopLoss(),   Digits),
      DoubleToString(OrderLots(), 2),
      DoubleToString(pelnas, 2),
      priezast);
   FileClose(handle);
   Print("[LOG] ", tipas, " užregistruotas → ", DoubleToString(pelnas, 2), "€ | ", priezast);
}

//+------------------------------------------------------------------+
void CheckClosedTrades()
{
   int total = OrdersHistoryTotal();
   if (total <= g_LastHistoryTotal) return;
   for (int i = g_LastHistoryTotal; i < total; i++)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if (OrderMagicNumber() != MagicNumber)            continue;
      if (OrderSymbol() != Symbol())                    continue;
      if (OrderType() > OP_SELL)                        continue;
      LogClosedTrade();
   }
   g_LastHistoryTotal = total;
}

//+------------------------------------------------------------------+
void OnTick()
{
   ResetDailyBalance();
   CheckClosedTrades();
   ManageOpenTrades();

   // ─── EMA200 REALAUS LAIKO APTIKIMAS ──────────────────────────
   double ema0    = iMA(NULL, 0, EMA_Period, 0, MODE_EMA, PRICE_CLOSE, 0);
   bool   isAbove = (Bid > ema0);

   if (!g_EMAStateInited)
   {
      g_WasAboveEMA    = isAbove;
      g_EMAStateInited = true;
      return;
   }

   bool crossUp   = (!g_WasAboveEMA && isAbove);
   bool crossDown = ( g_WasAboveEMA && !isAbove);
   g_WasAboveEMA  = isAbove;

   if (!crossUp && !crossDown) return;

   // ─── DIENOS NUOSTOLIŲ LIMITAS ─────────────────────────────────
   int dailyLosses = CountDailyLosses();
   if (dailyLosses >= MaxDailyLosses)
   {
      if (ShowDebug) Print("[FILTRAS] ", dailyLosses, " nuostoliai šiandien — blokuota");
      return;
   }

   // ─── DIENOS BALANSO LIMITAS ───────────────────────────────────
   if (g_DayStartBalance > 0)
   {
      double loss = (g_DayStartBalance - AccountBalance()) / g_DayStartBalance * 100.0;
      if (loss >= MaxDailyLossPct)
      {
         if (ShowDebug) Print("[FILTRAS] Dienos limitas -", DoubleToString(loss, 1), "%");
         return;
      }
   }

   // ─── SESIJŲ FILTRAS ───────────────────────────────────────────
   if (UseSessionFilter)
   {
      int hour = TimeHour(TimeGMT());
      if (hour < Session_Start || hour >= Session_End)
      {
         if (ShowDebug) Print("[FILTRAS] Ne sesijos laikas GMT ", hour, ":xx");
         return;
      }
   }

   // ─── ADX ŠONINIO RINKOS FILTRAS ──────────────────────────────
   if (UseADXFilter)
   {
      double adx = iADX(NULL, 0, ADX_Period, PRICE_CLOSE, MODE_MAIN, 1);
      if (adx < ADX_MinLevel)
      {
         if (ShowDebug)
            Print("[FILTRAS] ADX=", DoubleToString(adx, 1),
                  " < ", ADX_MinLevel, " — šoninis rinka, neprekiaujame");
         return;
      }
   }

   // ─── DVIGUBŲ SANDORIŲ APSAUGA ────────────────────────────────
   if (Time[0] == g_LastOpenBar)
   {
      if (ShowDebug) Print("[FILTRAS] Sandoris jau atidarytas šiame bare — laukiame");
      return;
   }

   int    openDir = GetOpenDirection();
   double invest  = GetInvestmentAmount();
   double riskNow = invest * SL_Percent / 100.0;

   if (ShowDebug)
      Print("[SIGNALAS] ", (crossUp ? "AUKŠTYN" : "ŽEMYN"),
            " | Bid: ", DoubleToString(Bid, Digits),
            " | EMA200: ", DoubleToString(ema0, Digits),
            " | Invest: ", DoubleToString(invest, 2),
            "€ | Rizika: ", DoubleToString(riskNow, 2), "€");

   // ─── REVERSAL ────────────────────────────────────────────────
   if (crossUp && openDir == -1)
   {
      Print("[REVERSAL] AUKŠTYN — uždaromi SELL, atidaromas BUY");
      CloseTradesByType(OP_SELL);
      OpenTrade(1, riskNow);
      return;
   }
   if (crossDown && openDir == 1)
   {
      Print("[REVERSAL] ŽEMYN — uždaromi BUY, atidaromas SELL");
      CloseTradesByType(OP_BUY);
      OpenTrade(-1, riskNow);
      return;
   }

   // ─── NAUJAS SANDORIS ─────────────────────────────────────────
   if (!PortfolioRiskOK(riskNow)) return;

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

   sl = NormalizeDouble(sl, Digits);

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

   int    type = (signal == 1) ? OP_BUY   : OP_SELL;
   string dir  = (signal == 1) ? "BUY"    : "SELL";
   color  clr  = (signal == 1) ? clrGreen : clrRed;

   int ticket = OrderSend(Symbol(), type, lot, price, 5, sl, 0,
                          EA_Comment, MagicNumber, 0, clr);
   if (ticket > 0)
   {
      g_LastOpenBar = Time[0];  // Blokuoti dvigubus tame pačiame bare
      Print("✅ ", dir, " | Lot: ", DoubleToString(lot, 2),
            " | Kaina: ", DoubleToString(price, Digits),
            " | SL: ", DoubleToString(sl, Digits),
            " | Max nuostolis: ", DoubleToString(riskAmt, 2), "€");
   }
   else
      Print("❌ Klaida ", GetLastError(), " atidarant ", dir);
}

//+------------------------------------------------------------------+
//| Dynamic trailing + breakeven prie 30% pelno                     |
//|                                                                  |
//| Pelnas < 30%   → SL seka kainą (ATR × 1.5)                     |
//| Pelnas >= 30%  → SL šoka į entry (breakeven), tada tęsia        |
//| Pelnas >= 50%  → trailing artimesnis (ATR × 1.0)                |
//| Pelnas >= 100% → trailing labai artimas (ATR × 0.5)             |
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

      double profitRatio = (invest > 0) ? (profit / invest) : 0.0;

      double trailMult;
      string trailLabel;
      if      (profitRatio >= 1.0) { trailMult = Trailing100pct; trailLabel = "100%+"; }
      else if (profitRatio >= 0.5) { trailMult = Trailing50pct;  trailLabel = "50%+";  }
      else                         { trailMult = TrailingATR;     trailLabel = "normalus"; }

      if (OrderType() == OP_BUY)
      {
         double newSL = NormalizeDouble(Bid - atr * trailMult, Digits);

         // Breakeven: kai pelnas >= 30% → SL ne žemiau entry
         if (profitRatio >= BreakevenPct / 100.0 && newSL < op)
         {
            newSL      = NormalizeDouble(op, Digits);
            trailLabel = "breakeven";
         }

         if (newSL > sl)
         {
            if (OrderModify(OrderTicket(), op, newSL, 0, 0, clrBlue))
            {
               if (ShowDebug)
                  Print("[TRAILING BUY] SL: ", DoubleToString(sl, Digits),
                        " → ", DoubleToString(newSL, Digits),
                        " (", trailLabel, ")",
                        " | Pelnas: ", DoubleToString(profit, 2), "€",
                        " | Užrakinta: ", DoubleToString(GetLockedProfit(i), 2), "€");
            }
         }
      }
      else if (OrderType() == OP_SELL)
      {
         double newSL = NormalizeDouble(Ask + atr * trailMult, Digits);

         // Breakeven: kai pelnas >= 30% → SL ne aukščiau entry
         if (profitRatio >= BreakevenPct / 100.0 && newSL > op)
         {
            newSL      = NormalizeDouble(op, Digits);
            trailLabel = "breakeven";
         }

         if (sl == 0 || newSL < sl)
         {
            if (OrderModify(OrderTicket(), op, newSL, 0, 0, clrBlue))
            {
               if (ShowDebug)
                  Print("[TRAILING SELL] SL: ", DoubleToString(sl, Digits),
                        " → ", DoubleToString(newSL, Digits),
                        " (", trailLabel, ")",
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
   Print("EMA200 Cross EA v5.6 sustabdytas | Balansas: ",
         DoubleToString(AccountBalance(), 2), "€");
}
//+------------------------------------------------------------------+
