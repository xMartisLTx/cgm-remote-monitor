//+------------------------------------------------------------------+
//|  SMC Sniper EA — Pilna versija                                   |
//|  Strategija: SMC + EMA + RSI + Sesijų filtras + Risk Management |
//+------------------------------------------------------------------+
#property copyright "SMC Sniper EA"
#property version   "1.0"
#property strict

//--- Įvesties parametrai
input double RiskPercent     = 1.0;    // Rizika % per sandorį
input double RR_TP1          = 2.0;    // Take-Profit 1 (RR santykis)
input double RR_TP2          = 3.0;    // Take-Profit 2 (RR santykis)
input int    EMA_Fast        = 50;     // Greita EMA
input int    EMA_Slow        = 200;    // Lėta EMA
input int    RSI_Period      = 14;     // RSI periodas
input double RSI_Buy_Max     = 52.0;   // RSI maks. pirkimui
input double RSI_Sell_Min    = 48.0;   // RSI min. pardavimui
input int    OB_Lookback     = 10;     // Order Block paieška (žvakės)
input int    BOS_Window      = 20;     // BOS paieška (žvakės)
input int    MaxLossStreak   = 3;      // Pauzė po N pralaimėjimų
input double MaxDailyLossPct = 2.0;    // Dienos nuostolių limitas %
input bool   UseSessionFilter= true;   // Sesijų filtras
input int    London_Start    = 8;      // London sesija pradžia (GMT)
input int    London_End      = 12;     // London sesija pabaiga (GMT)
input int    NY_Start        = 13;     // NY sesija pradžia (GMT)
input int    NY_End          = 17;     // NY sesija pabaiga (GMT)
input int    MagicNumber     = 20240101;
input string EA_Comment      = "SMC_Sniper";

//--- Globalūs kintamieji
int    g_LossStreak      = 0;
double g_DayStartBalance = 0;
datetime g_LastTradeDay  = 0;
datetime g_LastBarTime   = 0;

//+------------------------------------------------------------------+
//| Inicializacija                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   g_DayStartBalance = AccountBalance();
   g_LastTradeDay    = 0;
   g_LossStreak      = 0;
   Print("SMC Sniper EA paleistas. Balansas: ", AccountBalance());
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Pagrindinis ciklas — kiekvienas tikas                            |
//+------------------------------------------------------------------+
void OnTick()
{
   // Nauja žvakė tik vieną kartą
   if (Time[0] == g_LastBarTime) return;
   g_LastBarTime = Time[0];

   // Dienos balanso atstatymas
   ResetDailyBalance();

   // Atnaujinti pralaimėjimų seriją
   UpdateLossStreak();

   // Tvarkyti atviras pozicijas (trailing stop, BE)
   ManageOpenTrades();

   // Jei jau yra atvira pozicija — neatidarome kitos
   if (CountOpenTrades() > 0) return;

   // Tikrinimų filtrai
   if (!PassFilters()) return;

   // Analizuojame rinką
   int signal = GetSignal();
   if (signal == 0) return;

   // Atidarome sandorį
   OpenTrade(signal);
}

//+------------------------------------------------------------------+
//| Sesijų filtras                                                   |
//+------------------------------------------------------------------+
bool IsInSession()
{
   if (!UseSessionFilter) return true;
   int hour = TimeHour(TimeGMT());
   bool london = (hour >= London_Start && hour < London_End);
   bool ny     = (hour >= NY_Start     && hour < NY_End);
   return (london || ny);
}

//+------------------------------------------------------------------+
//| Visi filtrai                                                     |
//+------------------------------------------------------------------+
bool PassFilters()
{
   // Sesijų filtras
   if (!IsInSession())
   {
      return false;
   }

   // Pralaimėjimų serijos filtras
   if (g_LossStreak >= MaxLossStreak)
   {
      Print("Pauzė: ", g_LossStreak, " pralaimėjimai iš eilės");
      return false;
   }

   // Dienos nuostolių limitas
   double dayLoss = (g_DayStartBalance - AccountBalance()) / g_DayStartBalance * 100;
   if (dayLoss >= MaxDailyLossPct)
   {
      Print("Dienos nuostolių limitas pasiektas: -", dayLoss, "%");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Pagrindinis signalo generatorius                                 |
//+------------------------------------------------------------------+
int GetSignal()
{
   // Indikatoriai
   double ema_fast_curr = iMA(NULL, 0, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema_fast_prev = iMA(NULL, 0, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE, 2);
   double ema_slow_curr = iMA(NULL, 0, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE, 1);
   double rsi           = iRSI(NULL, 0, RSI_Period, PRICE_CLOSE, 1);
   double atr           = iATR(NULL, 0, 14, 1);

   // Tendencija
   bool bull_trend = (ema_fast_curr > ema_slow_curr);
   bool bear_trend = (ema_fast_curr < ema_slow_curr);

   // Market Regime Detection (ADX)
   double adx = iADX(NULL, 0, 14, PRICE_CLOSE, MODE_MAIN, 1);
   bool trending = (adx > 20);

   // BOS (Break of Structure)
   bool bos_bull = IsBullishBOS();
   bool bos_bear = IsBearishBOS();

   // Order Block
   bool ob_bull = IsBullishOB();
   bool ob_bear = IsBearishOB();

   // BUY sąlygos
   if (bull_trend && trending && bos_bull && ob_bull && rsi < RSI_Buy_Max)
   {
      Print("BUY signalas: EMA=", ema_fast_curr, " RSI=", rsi, " ADX=", adx);
      return 1;
   }

   // SELL sąlygos
   if (bear_trend && trending && bos_bear && ob_bear && rsi > RSI_Sell_Min)
   {
      Print("SELL signalas: EMA=", ema_fast_curr, " RSI=", rsi, " ADX=", adx);
      return -1;
   }

   return 0;
}

//+------------------------------------------------------------------+
//| Bullish BOS patikrinimas                                         |
//+------------------------------------------------------------------+
bool IsBullishBOS()
{
   double maxHigh = 0;
   for (int i = 2; i <= BOS_Window + 1; i++)
      maxHigh = MathMax(maxHigh, High[i]);
   return (High[1] > maxHigh);
}

//+------------------------------------------------------------------+
//| Bearish BOS patikrinimas                                         |
//+------------------------------------------------------------------+
bool IsBearishBOS()
{
   double minLow = DBL_MAX;
   for (int i = 2; i <= BOS_Window + 1; i++)
      minLow = MathMin(minLow, Low[i]);
   return (Low[1] < minLow);
}

//+------------------------------------------------------------------+
//| Bullish Order Block                                              |
//+------------------------------------------------------------------+
bool IsBullishOB()
{
   for (int i = 2; i <= OB_Lookback + 1; i++)
   {
      bool bearish_candle = (Close[i] < Open[i]);
      bool next_bullish   = (Close[i-1] > High[i]);
      if (bearish_candle && next_bullish)
      {
         double ob_high = High[i];
         double ob_low  = Low[i];
         return (Close[1] >= ob_low && Close[1] <= ob_high * 1.001);
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Bearish Order Block                                              |
//+------------------------------------------------------------------+
bool IsBearishOB()
{
   for (int i = 2; i <= OB_Lookback + 1; i++)
   {
      bool bullish_candle = (Close[i] > Open[i]);
      bool next_bearish   = (Close[i-1] < Low[i]);
      if (bullish_candle && next_bearish)
      {
         double ob_high = High[i];
         double ob_low  = Low[i];
         return (Close[1] <= ob_high && Close[1] >= ob_low * 0.999);
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Loto dydžio skaičiavimas                                        |
//+------------------------------------------------------------------+
double CalcLotSize(double sl_points)
{
   double balance   = AccountBalance();

   // Anti-martingale: mažesnis lotas po pralaimėjimų
   double riskPct = RiskPercent / 100.0;
   if (g_LossStreak == 1) riskPct *= 0.75;
   if (g_LossStreak == 2) riskPct *= 0.50;

   double riskAmt   = balance * riskPct;
   double tickVal   = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
   double lotStep   = MarketInfo(Symbol(), MODE_LOTSTEP);
   double minLot    = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot    = MarketInfo(Symbol(), MODE_MAXLOT);

   if (tickVal <= 0 || tickSize <= 0 || sl_points <= 0) return minLot;

   double lot = riskAmt / (sl_points / tickSize * tickVal);
   lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(minLot, MathMin(maxLot, lot));

   return lot;
}

//+------------------------------------------------------------------+
//| Sandorio atidarymas                                              |
//+------------------------------------------------------------------+
void OpenTrade(int signal)
{
   double atr     = iATR(NULL, 0, 14, 1);
   double spread  = MarketInfo(Symbol(), MODE_SPREAD) * Point;
   double sl_dist = atr * 1.2;

   double price, sl, tp1, tp2;

   if (signal == 1) // BUY
   {
      price = Ask;
      sl    = price - sl_dist;
      tp1   = price + sl_dist * RR_TP1;
      tp2   = price + sl_dist * RR_TP2;
   }
   else // SELL
   {
      price = Bid;
      sl    = price + sl_dist;
      tp1   = price - sl_dist * RR_TP1;
      tp2   = price - sl_dist * RR_TP2;
   }

   // Normalizuojame kainas
   sl  = NormalizeDouble(sl,  Digits);
   tp1 = NormalizeDouble(tp1, Digits);
   tp2 = NormalizeDouble(tp2, Digits);

   double lot = CalcLotSize(MathAbs(price - sl) / Point);

   int type   = (signal == 1) ? OP_BUY : OP_SELL;
   string dir = (signal == 1) ? "BUY" : "SELL";

   // Pirmasis sandoris: 50% loto, TP1
   double lot1 = NormalizeDouble(lot * 0.5, 2);
   double lot2 = NormalizeDouble(lot * 0.5, 2);
   if (lot1 < MarketInfo(Symbol(), MODE_MINLOT))
      lot1 = MarketInfo(Symbol(), MODE_MINLOT);
   if (lot2 < MarketInfo(Symbol(), MODE_MINLOT))
      lot2 = MarketInfo(Symbol(), MODE_MINLOT);

   int ticket1 = OrderSend(Symbol(), type, lot1, price, 3, sl, tp1,
                            EA_Comment + "_TP1", MagicNumber, 0,
                            signal == 1 ? clrGreen : clrRed);

   int ticket2 = OrderSend(Symbol(), type, lot2, price, 3, sl, tp2,
                            EA_Comment + "_TP2", MagicNumber, 0,
                            signal == 1 ? clrLime : clrOrangeRed);

   if (ticket1 > 0 && ticket2 > 0)
      Print(dir, " atidarytas. SL=", sl, " TP1=", tp1, " TP2=", tp2, " Lot=", lot);
   else
      Print("Klaida atidarant sandorį: ", GetLastError());
}

//+------------------------------------------------------------------+
//| Atvirų sandorių valdymas (BE + Trailing)                        |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderMagicNumber() != MagicNumber)           continue;
      if (OrderSymbol() != Symbol())                   continue;

      double openPrice = OrderOpenPrice();
      double sl        = OrderStopLoss();
      double atr       = iATR(NULL, 0, 14, 1);

      // Break-even: kai pelnas = 1x ATR, perkelti SL į įėjimą
      if (OrderType() == OP_BUY)
      {
         if (Bid > openPrice + atr && sl < openPrice - Point)
         {
            double newSL = NormalizeDouble(openPrice + Point * 2, Digits);
            if (newSL > sl)
               OrderModify(OrderTicket(), openPrice, newSL, OrderTakeProfit(), 0, clrBlue);
         }
         // Trailing stop
         double trailSL = NormalizeDouble(Bid - atr * 1.0, Digits);
         if (trailSL > sl && trailSL > openPrice)
            OrderModify(OrderTicket(), openPrice, trailSL, OrderTakeProfit(), 0, clrBlue);
      }

      if (OrderType() == OP_SELL)
      {
         if (Ask < openPrice - atr && sl > openPrice + Point)
         {
            double newSL = NormalizeDouble(openPrice - Point * 2, Digits);
            if (newSL < sl)
               OrderModify(OrderTicket(), openPrice, newSL, OrderTakeProfit(), 0, clrBlue);
         }
         double trailSL = NormalizeDouble(Ask + atr * 1.0, Digits);
         if (trailSL < sl && trailSL < openPrice)
            OrderModify(OrderTicket(), openPrice, trailSL, OrderTakeProfit(), 0, clrBlue);
      }
   }
}

//+------------------------------------------------------------------+
//| Pralaimėjimų serijos atnaujinimas                               |
//+------------------------------------------------------------------+
void UpdateLossStreak()
{
   int losses = 0, wins = 0;
   for (int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if (OrderMagicNumber() != MagicNumber)            continue;
      if (OrderSymbol() != Symbol())                    continue;
      if (OrderType() > OP_SELL)                        continue;

      if (OrderProfit() < 0) { losses++; wins = 0; }
      else                   { wins++;   break;     }

      if (wins > 0 || losses > 5) break;
   }
   g_LossStreak = losses;
}

//+------------------------------------------------------------------+
//| Dienos balanso atstatymas                                       |
//+------------------------------------------------------------------+
void ResetDailyBalance()
{
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if (today != g_LastTradeDay)
   {
      g_DayStartBalance = AccountBalance();
      g_LastTradeDay    = today;
      g_LossStreak      = 0;
      Print("Nauja diena. Balansas: ", g_DayStartBalance);
   }
}

//+------------------------------------------------------------------+
//| Atvirų sandorių skaičiavimas                                    |
//+------------------------------------------------------------------+
int CountOpenTrades()
{
   int count = 0;
   for (int i = 0; i < OrdersTotal(); i++)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Deaktyvacija                                                     |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("SMC Sniper EA sustabdytas.");
}
//+------------------------------------------------------------------+
