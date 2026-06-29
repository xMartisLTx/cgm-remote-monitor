//+------------------------------------------------------------------+
//| EMA200 Cross EA v3.0                                             |
//| - Max 3 sandoriai vienu metu (visi gali būti su SL < 0)        |
//| - Naujas sandoris kai BENT VIENAS SL užrakintas +10€            |
//| - Trailing Stop seka kainą                                      |
//| - Auto Compound pagal balansą                                   |
//+------------------------------------------------------------------+
#property copyright "Forex Signalai v5.0"
#property version   "3.0"
#property strict

// ─── PAGRINDINIAI NUSTATYMAI ──────────────────────────────────────
input int    EMA_Period       = 200;   // EMA periodas (raudona linija)
input int    ATR_Period       = 14;    // ATR periodas
input double RR_TP            = 3.0;   // Take-Profit RR (atsarginis)
input double TrailingATR      = 1.5;   // Trailing SL atstumas (ATR kartotinis)

// ─── MULTI-TRADE NUSTATYMAI ───────────────────────────────────────
input int    MaxTrades        = 3;     // Maks. sandorių skaičius vienu metu
input double SL_LockMin       = 10.0;  // Min. užrakinto pelno EUR kad leistų naują sandorį

// ─── COMPOUND RIZIKOS LYGIAI ──────────────────────────────────────
input double Level2_Balance   = 80.0;  // Nuo 80€  → 20€ rizika
input double Level3_Balance   = 120.0; // Nuo 120€ → 30€ rizika
input double Level1_Risk      = 10.0;  // Rizika EUR kai balansas < 80€
input double Level2_Risk      = 20.0;  // Rizika EUR kai balansas 80-120€
input double Level3_Risk      = 30.0;  // Rizika EUR kai balansas > 120€

// ─── FILTRAI ──────────────────────────────────────────────────────
input bool   UseSessionFilter = true;  // Sesijų filtras
input int    Session_Start    = 7;     // Sesijos pradžia GMT
input int    Session_End      = 17;    // Sesijos pabaiga GMT
input double MaxDailyLossPct  = 20.0;  // Dienos nuostolių limitas %
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
   Print("=== EMA200 Cross EA v3.0 paleistas ===");
   Print("Pora: ", Symbol(), " | Maks. sandoriai: ", MaxTrades,
         " | SL užraktas: +", SL_LockMin, "€");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Grąžina rizikos sumą pagal dabartinį balansą                    |
//+------------------------------------------------------------------+
double GetRiskAmount()
{
   double bal = AccountBalance();
   if (bal >= Level3_Balance) return Level3_Risk;
   if (bal >= Level2_Balance) return Level2_Risk;
   return Level1_Risk;
}

//+------------------------------------------------------------------+
//| Skaičiuoja kiek EUR užrakinta SL pozicijoje                     |
//| Teigiamas skaičius = SL virš atvėrimo (pelnas užrakintas)      |
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

   double priceDiff = 0;
   if (OrderType() == OP_BUY)  priceDiff = sl - op;
   if (OrderType() == OP_SELL) priceDiff = op - sl;

   return (priceDiff / tickSize) * tickVal * lots;
}

//+------------------------------------------------------------------+
//| Tikrina ar BENT VIENAS sandoris turi SL užrakintą >= SL_LockMin |
//+------------------------------------------------------------------+
bool AnyTradeSecured()
{
   for (int i = 0; i < OrdersTotal(); i++)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderMagicNumber() != MagicNumber)           continue;
      if (OrderSymbol() != Symbol())                   continue;

      double locked = GetLockedProfit(i);
      if (locked >= SL_LockMin)
      {
         if (ShowDebug)
            Print("[INFO] Sandoris #", OrderTicket(),
                  " užrakintas +", DoubleToString(locked, 2),
                  "€ — leidžiamas naujas sandoris");
         return true;
      }
   }
   if (ShowDebug)
      Print("[INFO] Nė vienas sandoris neužrakintas +", SL_LockMin, "€ — naujas blokuotas");
   return false;
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

//+------------------------------------------------------------------+
//| Grąžina atvirų sandorių kryptį: 1=BUY, -1=SELL, 0=nėra        |
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
void OnTick()
{
   if (Time[0] == g_LastBarTime) return;
   g_LastBarTime = Time[0];

   ResetDailyBalance();
   ManageOpenTrades();

   int openCount = CountOpenTrades();

   // Blokuoti jei pasiektas maks. sandorių skaičius
   if (openCount >= MaxTrades) return;

   // Jei jau yra sandorių — bent vienas turi būti užrakintas +10€
   if (openCount > 0 && !AnyTradeSecured()) return;

   // ─── SESIJŲ FILTRAS ───────────────────────────────────────────
   if (UseSessionFilter)
   {
      int hour = TimeHour(TimeGMT());
      if (hour < Session_Start || hour >= Session_End)
      {
         if (ShowDebug)
            Print("[FILTRAS] Ne sesijos laikas (GMT ", hour, ":xx)");
         return;
      }
   }

   // ─── DIENOS NUOSTOLIŲ LIMITAS ─────────────────────────────────
   if (g_DayStartBalance > 0)
   {
      double loss = (g_DayStartBalance - AccountBalance()) / g_DayStartBalance * 100.0;
      if (loss >= MaxDailyLossPct)
      {
         if (ShowDebug)
            Print("[FILTRAS] Dienos limitas -", DoubleToString(loss, 1), "%");
         return;
      }
   }

   // ─── EMA200 KIRTIMO APTIKIMAS ─────────────────────────────────
   double ema1 = iMA(NULL, 0, EMA_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema2 = iMA(NULL, 0, EMA_Period, 0, MODE_EMA, PRICE_CLOSE, 2);

   bool crossUp   = (Close[2] < ema2) && (Close[1] > ema1);
   bool crossDown = (Close[2] > ema2) && (Close[1] < ema1);

   double riskNow = GetRiskAmount();

   if (ShowDebug)
      Print("[INFO] Sandoriai: ", openCount, "/", MaxTrades,
            " | Balansas: ", DoubleToString(AccountBalance(), 2),
            "€ | Rizika: ", DoubleToString(riskNow, 2), "€");

   // Neatidaryti priešingos krypties sandorio
   int openDir = GetOpenDirection();
   if (crossUp   && openDir != -1) OpenTrade(1,  riskNow);
   if (crossDown && openDir !=  1) OpenTrade(-1, riskNow);
}

//+------------------------------------------------------------------+
//| Atidaro sandorį                                                  |
//+------------------------------------------------------------------+
void OpenTrade(int signal, double riskAmt)
{
   double atr    = iATR(NULL, 0, ATR_Period, 1);
   double slDist = atr * 1.5;

   double price = (signal == 1) ? Ask : Bid;
   double sl    = (signal == 1) ? price - slDist : price + slDist;
   double tp    = (signal == 1) ? price + slDist * RR_TP : price - slDist * RR_TP;

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
      Print("✅ ", dir, " #", CountOpenTrades(), "/", MaxTrades,
            " | Rizika: ", DoubleToString(riskAmt, 2),
            "€ | Lot: ", DoubleToString(lot, 2),
            " | SL: ", DoubleToString(sl, Digits),
            " | TP: ", DoubleToString(tp, Digits));
   else
      Print("❌ Klaida ", GetLastError(), " | ", dir);
}

//+------------------------------------------------------------------+
//| Trailing Stop — SL seka kainą aukštyn                           |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderMagicNumber() != MagicNumber)           continue;
      if (OrderSymbol() != Symbol())                   continue;

      double op  = OrderOpenPrice();
      double sl  = OrderStopLoss();
      double atr = iATR(NULL, 0, ATR_Period, 1);

      if (OrderType() == OP_BUY)
      {
         double newSL = NormalizeDouble(Bid - atr * TrailingATR, Digits);
         if (newSL > sl && newSL > op)
         {
            OrderModify(OrderTicket(), op, newSL, OrderTakeProfit(), 0, clrBlue);
            if (ShowDebug)
               Print("[TRAILING] BUY SL: ", DoubleToString(sl, Digits),
                     " → ", DoubleToString(newSL, Digits),
                     " | Užrakinta: +", DoubleToString(GetLockedProfit(i), 2), "€");
         }
      }
      else if (OrderType() == OP_SELL)
      {
         double newSL = NormalizeDouble(Ask + atr * TrailingATR, Digits);
         if ((sl == 0 || newSL < sl) && newSL < op)
         {
            OrderModify(OrderTicket(), op, newSL, OrderTakeProfit(), 0, clrBlue);
            if (ShowDebug)
               Print("[TRAILING] SELL SL: ", DoubleToString(sl, Digits),
                     " → ", DoubleToString(newSL, Digits),
                     " | Užrakinta: +", DoubleToString(GetLockedProfit(i), 2), "€");
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
         Print("=== Nauja diena | Balansas: ", DoubleToString(g_DayStartBalance, 2), "€ ===");
   }
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("EMA200 Cross EA v3.0 sustabdytas. Balansas: ",
         DoubleToString(AccountBalance(), 2), "€");
}
//+------------------------------------------------------------------+
