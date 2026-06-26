//+------------------------------------------------------------------+
//|  SMC Sniper EA v2.0 — su CRT + TBS + Debug                      |
//|  Pataisyta: atsipalaidavusios sąlygos, CRT pridėtas             |
//+------------------------------------------------------------------+
#property copyright "SMC Sniper EA v2.0"
#property version   "2.0"
#property strict

//--- Parametrai
input double RiskPercent      = 1.0;    // Rizika % per sandorį
input double RR_TP1           = 2.0;    // Take-Profit 1 RR
input double RR_TP2           = 3.0;    // Take-Profit 2 RR
input int    EMA_Fast         = 50;     // Greita EMA
input int    EMA_Slow         = 200;    // Lėta EMA
input int    RSI_Period       = 14;     // RSI periodas
input int    ATR_Period       = 14;     // ATR periodas
input int    MinScoreRequired = 3;      // Min. balų signalui (iš 5)
input bool   UseSessionFilter = true;   // Sesijų filtras
input int    London_Start     = 7;      // London pradžia GMT
input int    London_End       = 12;     // London pabaiga GMT
input int    NY_Start         = 13;     // NY pradžia GMT
input int    NY_End           = 18;     // NY pabaiga GMT
input int    MaxLossStreak    = 3;      // Pauzė po N pralaimėjimų
input double MaxDailyLossPct  = 3.0;   // Dienos nuostolių limitas %
input bool   UseCRT           = true;   // CRT filtras
input bool   ShowDebug        = true;   // Rodyti debug info
input int    MagicNumber      = 20240202;
input string EA_Comment       = "SMC_v2";

//--- Globalūs
int      g_LossStreak      = 0;
double   g_DayStartBalance = 0;
datetime g_LastTradeDay    = 0;
datetime g_LastBarTime     = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   g_DayStartBalance = AccountBalance();
   Print("=== SMC Sniper v2.0 paleistas ===");
   Print("Balansas: $", AccountBalance(), " | Pora: ", Symbol(), " | TF: ", Period());
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnTick()
{
   if (Time[0] == g_LastBarTime) return;
   g_LastBarTime = Time[0];

   ResetDailyBalance();
   UpdateLossStreak();
   ManageOpenTrades();

   if (CountOpenTrades() > 0) return;

   string blockReason = "";
   if (!PassFilters(blockReason))
   {
      if (ShowDebug) Print("[FILTRAS] ", blockReason);
      return;
   }

   int signal = 0;
   int score  = 0;
   string debugInfo = "";
   GetSignal(signal, score, debugInfo);

   if (ShowDebug)
      Print("[SIGNALAS] Balai: ", score, "/5 | ", debugInfo);

   if (signal != 0 && score >= MinScoreRequired)
      OpenTrade(signal, score);
}

//+------------------------------------------------------------------+
//| Signalo skaičiavimas su balų sistema                            |
//+------------------------------------------------------------------+
void GetSignal(int &signal, int &score, string &info)
{
   signal = 0;
   score  = 0;
   info   = "";

   double ema_fast = iMA(NULL, 0, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema_slow = iMA(NULL, 0, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE, 1);
   double rsi      = iRSI(NULL, 0, RSI_Period, PRICE_CLOSE, 1);
   double adx      = iADX(NULL, 0, 14, PRICE_CLOSE, MODE_MAIN, 1);
   double atr      = iATR(NULL, 0, ATR_Period, 1);

   bool bull_trend = (ema_fast > ema_slow);
   bool bear_trend = (ema_fast < ema_slow);
   bool trending   = (adx > 18);

   // === 1. TENDENCIJA (EMA) — privaloma ===
   int trendDir = 0;
   if (bull_trend) { trendDir =  1; score++; info += "EMA↑ "; }
   if (bear_trend) { trendDir = -1; score++; info += "EMA↓ "; }

   if (trendDir == 0) return;

   // === 2. ADX — tendencija stipri ===
   if (trending) { score++; info += "ADX✓ "; }
   else info += "ADX✗ ";

   // === 3. RSI filtras (atsipalaidavęs) ===
   if (trendDir == 1 && rsi < 60) { score++; info += "RSI✓ "; }
   else if (trendDir == -1 && rsi > 40) { score++; info += "RSI✓ "; }
   else info += "RSI✗ ";

   // === 4. BOS arba CRT ===
   bool bos = false;
   bool crt = false;

   if (trendDir == 1)
   {
      bos = IsBullishBOS(15);
      crt = UseCRT ? IsBullishCRT() : false;
   }
   else
   {
      bos = IsBearishBOS(15);
      crt = UseCRT ? IsBearishCRT() : false;
   }

   if (bos || crt)
   {
      score++;
      info += (bos ? "BOS✓ " : "CRT✓ ");
   }
   else info += "BOS/CRT✗ ";

   // === 5. Order Block arba kaina virš/žemiau EMA50 ===
   bool ob = false;
   if (trendDir == 1) ob = IsBullishOB();
   else               ob = IsBearishOB();

   // Papildoma sąlyga: kaina tarp EMA50 ir EMA200 (pullback zona)
   double price     = Close[1];
   bool pullback_zone = false;
   if (trendDir == 1) pullback_zone = (price > ema_slow && price < ema_fast * 1.002);
   else               pullback_zone = (price < ema_slow && price > ema_fast * 0.998);

   if (ob || pullback_zone)
   {
      score++;
      info += (ob ? "OB✓ " : "PB✓ ");
   }
   else info += "OB/PB✗ ";

   // Galutinis sprendimas
   if (score >= MinScoreRequired)
      signal = trendDir;
}

//+------------------------------------------------------------------+
//| CRT — Bullish (kaina nušlavė ankstesnės žvakės žemumą)         |
//+------------------------------------------------------------------+
bool IsBullishCRT()
{
   // Ankstesnės žvakės žemumas nušluotas, bet kaina užsidarė aukščiau
   double prev_low  = Low[2];
   double prev_mid  = (High[2] + Low[2]) / 2.0;
   bool   swept_low = (Low[1] < prev_low);
   bool   closed_up = (Close[1] > prev_mid);
   return (swept_low && closed_up);
}

//+------------------------------------------------------------------+
//| CRT — Bearish (kaina nušlavė ankstesnės žvakės aukštumą)       |
//+------------------------------------------------------------------+
bool IsBearishCRT()
{
   double prev_high = High[2];
   double prev_mid  = (High[2] + Low[2]) / 2.0;
   bool   swept_high = (High[1] > prev_high);
   bool   closed_dn  = (Close[1] < prev_mid);
   return (swept_high && closed_dn);
}

//+------------------------------------------------------------------+
bool IsBullishBOS(int window = 20)
{
   double maxHigh = 0;
   for (int i = 2; i <= window; i++)
      maxHigh = MathMax(maxHigh, High[i]);
   return (High[1] > maxHigh);
}

bool IsBearishBOS(int window = 20)
{
   double minLow = DBL_MAX;
   for (int i = 2; i <= window; i++)
      minLow = MathMin(minLow, Low[i]);
   return (Low[1] < minLow);
}

bool IsBullishOB()
{
   for (int i = 3; i <= 15; i++)
   {
      if (Close[i] < Open[i] && Close[i-1] > High[i])
      {
         double zone_high = High[i] * 1.002;
         double zone_low  = Low[i]  * 0.998;
         if (Close[1] >= zone_low && Close[1] <= zone_high)
            return true;
      }
   }
   return false;
}

bool IsBearishOB()
{
   for (int i = 3; i <= 15; i++)
   {
      if (Close[i] > Open[i] && Close[i-1] < Low[i])
      {
         double zone_high = High[i] * 1.002;
         double zone_low  = Low[i]  * 0.998;
         if (Close[1] <= zone_high && Close[1] >= zone_low)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
bool PassFilters(string &reason)
{
   if (UseSessionFilter)
   {
      int hour   = TimeHour(TimeGMT());
      bool lon   = (hour >= London_Start && hour < London_End);
      bool ny    = (hour >= NY_Start     && hour < NY_End);
      if (!lon && !ny)
      {
         reason = "Ne sesijos laikas (GMT " + IntegerToString(hour) + ":xx)";
         return false;
      }
   }

   if (g_LossStreak >= MaxLossStreak)
   {
      reason = "Pauzė po " + IntegerToString(g_LossStreak) + " pralaimėjimų";
      return false;
   }

   if (g_DayStartBalance > 0)
   {
      double loss = (g_DayStartBalance - AccountBalance()) / g_DayStartBalance * 100;
      if (loss >= MaxDailyLossPct)
      {
         reason = "Dienos limitas -" + DoubleToString(loss, 1) + "%";
         return false;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
void OpenTrade(int signal, int score)
{
   double atr     = iATR(NULL, 0, ATR_Period, 1);
   double sl_dist = atr * 1.5;

   double price = (signal == 1) ? Ask : Bid;
   double sl    = (signal == 1) ? price - sl_dist : price + sl_dist;
   double tp1   = (signal == 1) ? price + sl_dist * RR_TP1 : price - sl_dist * RR_TP1;
   double tp2   = (signal == 1) ? price + sl_dist * RR_TP2 : price - sl_dist * RR_TP2;

   sl  = NormalizeDouble(sl,  Digits);
   tp1 = NormalizeDouble(tp1, Digits);
   tp2 = NormalizeDouble(tp2, Digits);

   double riskPct = RiskPercent / 100.0;
   if (g_LossStreak == 1) riskPct *= 0.75;
   if (g_LossStreak == 2) riskPct *= 0.50;

   double riskAmt  = AccountBalance() * riskPct;
   double tickVal  = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   double lotStep  = MarketInfo(Symbol(), MODE_LOTSTEP);
   double minLot   = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot   = MarketInfo(Symbol(), MODE_MAXLOT);

   double lot = 0.01;
   if (tickVal > 0 && tickSize > 0 && sl_dist > 0)
   {
      lot = riskAmt / (sl_dist / tickSize * tickVal);
      lot = MathFloor(lot / lotStep) * lotStep;
      lot = MathMax(minLot, MathMin(maxLot, lot));
   }

   int type  = (signal == 1) ? OP_BUY : OP_SELL;
   string dir = (signal == 1) ? "BUY" : "SELL";

   double lot1 = MathMax(minLot, NormalizeDouble(lot * 0.5, 2));
   double lot2 = MathMax(minLot, NormalizeDouble(lot * 0.5, 2));

   int t1 = OrderSend(Symbol(), type, lot1, price, 5, sl, tp1,
                      EA_Comment + "_TP1", MagicNumber, 0,
                      signal == 1 ? clrGreen : clrRed);
   int t2 = OrderSend(Symbol(), type, lot2, price, 5, sl, tp2,
                      EA_Comment + "_TP2", MagicNumber, 0,
                      signal == 1 ? clrLime  : clrOrangeRed);

   if (t1 > 0)
      Print("✅ ", dir, " | Balai:", score, "/5 | Lot:", lot,
            " | SL:", sl, " | TP1:", tp1, " | TP2:", tp2);
   else
      Print("❌ Klaida: ", GetLastError(), " | Dir:", dir);
}

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
         // Break-even
         if (Bid >= op + atr && sl < op)
         {
            double nsl = NormalizeDouble(op + Point * 5, Digits);
            if (nsl > sl) OrderModify(OrderTicket(), op, nsl, OrderTakeProfit(), 0, clrBlue);
         }
         // Trailing
         double tsl = NormalizeDouble(Bid - atr, Digits);
         if (tsl > sl && tsl > op)
            OrderModify(OrderTicket(), op, tsl, OrderTakeProfit(), 0, clrBlue);
      }

      if (OrderType() == OP_SELL)
      {
         if (Ask <= op - atr && sl > op)
         {
            double nsl = NormalizeDouble(op - Point * 5, Digits);
            if (nsl < sl) OrderModify(OrderTicket(), op, nsl, OrderTakeProfit(), 0, clrBlue);
         }
         double tsl = NormalizeDouble(Ask + atr, Digits);
         if (tsl < sl && tsl < op)
            OrderModify(OrderTicket(), op, tsl, OrderTakeProfit(), 0, clrBlue);
      }
   }
}

//+------------------------------------------------------------------+
void UpdateLossStreak()
{
   int losses = 0;
   for (int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if (OrderMagicNumber() != MagicNumber)            continue;
      if (OrderSymbol() != Symbol())                    continue;
      if (OrderType() > OP_SELL)                        continue;
      if (OrderProfit() >= 0) break;
      losses++;
      if (losses >= MaxLossStreak) break;
   }
   g_LossStreak = losses;
}

void ResetDailyBalance()
{
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if (today != g_LastTradeDay)
   {
      g_DayStartBalance = AccountBalance();
      g_LastTradeDay    = today;
      g_LossStreak      = 0;
      if (ShowDebug)
         Print("=== Nauja diena | Balansas: $", g_DayStartBalance, " ===");
   }
}

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

void OnDeinit(const int reason)
{
   Print("SMC Sniper v2.0 sustabdytas.");
}
//+------------------------------------------------------------------+
