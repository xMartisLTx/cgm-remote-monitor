//+------------------------------------------------------------------+
//| EMA200 Cross EA v1.1                                             |
//| Perka kai žvakė kerta EMA200 aukštyn                            |
//| Parduoda kai žvakė kerta EMA200 žemyn                           |
//+------------------------------------------------------------------+
#property copyright "Forex Signalai v5.0"
#property version   "1.1"
#property strict

//--- Parametrai
input bool   UseFixedRisk     = true;  // true = fiksuota EUR suma, false = %
input double FixedRiskEUR     = 10.0;  // Fiksuota rizika EUR per sandorį
input double RiskPercent      = 1.0;   // Rizika % (naudojama jei UseFixedRisk=false)
input double RR_TP            = 2.0;   // Take-Profit RR (2 = 1:2)
input int    EMA_Period       = 200;   // EMA periodas (raudona linija)
input int    ATR_Period       = 14;    // ATR SL skaičiavimui
input bool   UseSessionFilter = true;  // Sesijų filtras
input int    Session_Start    = 7;     // Sesijos pradžia GMT
input int    Session_End      = 17;    // Sesijos pabaiga GMT
input double MaxDailyLossPct  = 3.0;  // Dienos nuostolių limitas %
input bool   ShowDebug        = true;  // Debug žurnalas
input int    MagicNumber      = 20250101;
input string EA_Comment       = "EMA200_Cross";

//--- Papildomi parametrai
input double ProfitLockEUR    = 50.0;  // Uždaryti jei pelnas nukrenta žemiau X EUR
input double TrailingATR      = 1.5;   // Trailing SL atstumas (ATR kartotinis)

//--- Globalūs
double   g_DayStartBalance = 0;
datetime g_LastTradeDay    = 0;
datetime g_LastBarTime     = 0;
double   g_MaxProfit       = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   g_DayStartBalance = AccountBalance();
   Print("=== EMA200 Cross EA paleistas ===");
   Print("Pora: ", Symbol(), " | TF: ", Period(), " | Balansas: $", AccountBalance());
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnTick()
{
   // Tik naujos žvakės pradžioje
   if (Time[0] == g_LastBarTime) return;
   g_LastBarTime = Time[0];

   ResetDailyBalance();
   ManageOpenTrades();

   // Jei jau yra atviras sandoris — nedarom naujo
   if (CountOpenTrades() > 0) return;

   // ─── SESIJŲ FILTRAS ────────────────────────────────────────────
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

   // ─── DIENOS NUOSTOLIŲ LIMITAS ──────────────────────────────────
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

   // ─── EMA200 KIRTIMO APTIKIMAS ──────────────────────────────────
   // [1] = praėjusi uždara žvakė (signalinė)
   // [2] = prieš tai buvusi žvakė (palyginimui)
   double ema1 = iMA(NULL, 0, EMA_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema2 = iMA(NULL, 0, EMA_Period, 0, MODE_EMA, PRICE_CLOSE, 2);

   bool crossUp   = (Close[2] < ema2) && (Close[1] > ema1);  // kerta aukštyn → BUY
   bool crossDown = (Close[2] > ema2) && (Close[1] < ema1);  // kerta žemyn  → SELL

   if (ShowDebug)
      Print("[INFO] Close[1]=", Close[1], " EMA200=", DoubleToString(ema1, Digits),
            " | KirtasAukstyn=", crossUp, " | KirtasZemyn=", crossDown);

   if (crossUp)
      OpenTrade(1);
   else if (crossDown)
      OpenTrade(-1);
}

//+------------------------------------------------------------------+
//| Atidaro sandorį su ATR-pagrįstu SL ir TP                        |
//+------------------------------------------------------------------+
void OpenTrade(int signal)
{
   double atr    = iATR(NULL, 0, ATR_Period, 1);
   double slDist = atr * 1.5;

   double price = (signal == 1) ? Ask : Bid;
   double sl    = (signal == 1) ? price - slDist : price + slDist;
   double tp    = (signal == 1) ? price + slDist * RR_TP : price - slDist * RR_TP;

   sl = NormalizeDouble(sl, Digits);
   tp = NormalizeDouble(tp, Digits);

   // ─── LOT SKAIČIAVIMAS ─────────────────────────────────────────
   double riskAmt  = UseFixedRisk ? FixedRiskEUR : AccountBalance() * (RiskPercent / 100.0);
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

   int    type = (signal == 1) ? OP_BUY : OP_SELL;
   string dir  = (signal == 1) ? "BUY"  : "SELL";
   color  clr  = (signal == 1) ? clrGreen : clrRed;

   int ticket = OrderSend(Symbol(), type, lot, price, 5, sl, tp,
                          EA_Comment, MagicNumber, 0, clr);

   if (ticket > 0)
      Print("✅ ", dir, " atidarytas | Lot:", DoubleToString(lot, 2),
            " | SL:", DoubleToString(sl, Digits),
            " | TP:", DoubleToString(tp, Digits));
   else
      Print("❌ Klaida ", GetLastError(), " | ", dir,
            " | Price:", price, " | SL:", sl, " | TP:", tp);
}

//+------------------------------------------------------------------+
//| Tvarko atvirus sandorius: trailing stop + pelno apsauga         |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
   bool hasOpen = false;

   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderMagicNumber() != MagicNumber)           continue;
      if (OrderSymbol() != Symbol())                   continue;

      hasOpen = true;
      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      double op     = OrderOpenPrice();
      double sl     = OrderStopLoss();
      double atr    = iATR(NULL, 0, ATR_Period, 1);

      // Atnaujinti maksimalų pelną
      if (profit > g_MaxProfit)
         g_MaxProfit = profit;

      // ─── PELNO APSAUGA ─────────────────────────────────────────
      // Jei pelnas buvo virš ProfitLockEUR ir nukrito žemiau — uždaryti
      if (g_MaxProfit >= ProfitLockEUR && profit < ProfitLockEUR)
      {
         double closePrice = (OrderType() == OP_BUY) ? Bid : Ask;
         if (OrderClose(OrderTicket(), OrderLots(), closePrice, 5, clrBlue))
         {
            Print("💰 Pelno apsauga! Uždarytas | Maks.pelnas: ",
                  DoubleToString(g_MaxProfit, 2), "€ | Dabartinis: ",
                  DoubleToString(profit, 2), "€");
            g_MaxProfit = 0;
         }
         continue;
      }

      // ─── TRAILING STOP ─────────────────────────────────────────
      if (OrderType() == OP_BUY)
      {
         double newSL = NormalizeDouble(Bid - atr * TrailingATR, Digits);
         // Kelti SL tik aukštyn, tik virš atvėrimo kainos
         if (newSL > sl && newSL > op)
         {
            OrderModify(OrderTicket(), op, newSL, OrderTakeProfit(), 0, clrBlue);
            if (ShowDebug)
               Print("[TRAILING] BUY SL pakeltas į ", DoubleToString(newSL, Digits));
         }
      }
      else if (OrderType() == OP_SELL)
      {
         double newSL = NormalizeDouble(Ask + atr * TrailingATR, Digits);
         // Leisti SL tik žemyn, tik žemiau atvėrimo kainos
         if ((sl == 0 || newSL < sl) && newSL < op)
         {
            OrderModify(OrderTicket(), op, newSL, OrderTakeProfit(), 0, clrBlue);
            if (ShowDebug)
               Print("[TRAILING] SELL SL nuleistas į ", DoubleToString(newSL, Digits));
         }
      }
   }

   // Nustatyti maks. pelną kai nėra atvirų sandorių
   if (!hasOpen)
      g_MaxProfit = 0;
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
void ResetDailyBalance()
{
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if (today != g_LastTradeDay)
   {
      g_DayStartBalance = AccountBalance();
      g_LastTradeDay    = today;
      if (ShowDebug)
         Print("=== Nauja diena | Balansas: $", DoubleToString(g_DayStartBalance, 2), " ===");
   }
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("EMA200 Cross EA sustabdytas.");
}
//+------------------------------------------------------------------+
