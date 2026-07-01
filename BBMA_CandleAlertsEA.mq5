//+-----------------------------------------------------------------------+
//|                                              BBMA_CandleAlertsEA.mq5  |
//|      Reads BBMA_Visual.mq5 and sends Telegram Alerts                  |
//+-----------------------------------------------------------------------+
#property copyright "OpenAI"
#property version   "1.00"
#property strict

//==========================================================
// INPUTS
//==========================================================

input string IndicatorName = "BBMA_Visual";
input string BotToken      = "8964584245:AAE1fSJ4gVVUYcQheDYlAza61hCwcAM5JzM";
input string ChatID        = "1216288023";

//==========================================================
// GLOBAL VARIABLES
//==========================================================

int BBHandle = INVALID_HANDLE;

datetime LastBarTime = 0;
datetime LastAlertBar = 0;
datetime LastR1SellBar = 0;
datetime LastR1BuyBar  = 0;

double MiddleBB[];
double UpperBB[];
double LowerBB[];
double MAHigh5[];
double MALow5[];

//==========================================================
// SIGNAL ENUM
//==========================================================

enum SIGNAL_TYPE
{
   SIGNAL_NONE = 0,
   SIGNAL_C1_BUY,
   SIGNAL_C1_SELL,
   SIGNAL_EC_BUY,
   SIGNAL_EC_SELL,
   SIGNAL_C3_BUY,
   SIGNAL_C3_SELL
};

//==========================================================
// SIGNAL NAME
//==========================================================

string SignalName(SIGNAL_TYPE signal)
{
   switch(signal)
   {
      case SIGNAL_C1_BUY : return("C1 BUY");
      case SIGNAL_C1_SELL: return("C1 SELL");
      case SIGNAL_EC_BUY : return("EC BUY");
      case SIGNAL_EC_SELL: return("EC SELL");
      case SIGNAL_C3_BUY : return("C3 BUY");
      case SIGNAL_C3_SELL: return("C3 SELL");
   }

   return("NONE");
}

//==========================================================
// TIMEFRAME STRING
//==========================================================

string TFString()
{
   switch(_Period)
   {
      case PERIOD_M1 : return("M1");
      case PERIOD_M5 : return("M5");
      case PERIOD_M15: return("M15");
      case PERIOD_M30: return("M30");
      case PERIOD_H1 : return("H1");
      case PERIOD_H4 : return("H4");
      case PERIOD_D1 : return("D1");
      case PERIOD_W1 : return("W1");
      case PERIOD_MN1: return("MN");
   }

   return(IntegerToString(_Period));
}

//==========================================================
// URL ENCODE
//==========================================================

string UrlEncode(string txt)
{
   uchar data[];
   StringToCharArray(txt,data);

   string out="";

   for(int i=0;i<ArraySize(data)-1;i++)
   {
      uchar c=data[i];

      if((c>='A' && c<='Z') ||
         (c>='a' && c<='z') ||
         (c>='0' && c<='9'))
      {
         out+=(string)CharToString(c);
      }
      else if(c==' ')
      {
         out+="%20";
      }
      else if(c=='\n')
      {
         out+="%0A";
      }
      else
      {
         out+=StringFormat("%%%02X",c);
      }
   }

   return(out);
}

//==========================================================
// TELEGRAM
//==========================================================

bool SendTelegram(string text)
{
   if(BotToken=="")
      return(false);

   if(ChatID=="")
      return(false);

   string url=
      "https://api.telegram.org/bot"+
      BotToken+
      "/sendMessage";

   string body=
      "chat_id="+ChatID+
      "&text="+UrlEncode(text);

   char post[];
   StringToCharArray(body,post);

   char result[];

   string headers=
      "Content-Type: application/x-www-form-urlencoded\r\n";

   string response_headers;

   ResetLastError();

   int res=
      WebRequest(
         "POST",
         url,
         headers,
         10000,
         post,
         result,
         response_headers
      );

   if(res==-1)
   {
      Print("Telegram Error : ",GetLastError());
      return(false);
   }

   Print(CharArrayToString(result));

   return(true);
}

//==========================================================
// MESSAGE
//==========================================================

string BuildMessage(
   SIGNAL_TYPE signal,
   double price,
   datetime t)
{
   string msg="";

   msg+="BBMA ALERT";
   msg+="\n\n";

   msg+="Signal : ";
   msg+=SignalName(signal);

   msg+="\n";

   msg+="Symbol : ";
   msg+=_Symbol;

   msg+="\n";

   msg+="Timeframe : ";
   msg+=TFString();

   msg+="\n";

   msg+="Price : ";
   msg+=DoubleToString(price,_Digits);

   msg+="\n";

   msg+="Time : ";
   msg+=TimeToString(t,TIME_DATE|TIME_MINUTES);

   return(msg);
}

//==========================================================
// ONINIT
//==========================================================

int OnInit()
{
   BBHandle=
      iCustom(
         _Symbol,
         _Period,
         IndicatorName
      );

   if(BBHandle==INVALID_HANDLE)
   {
      Print("Cannot load BBMA_Visual");

      return(INIT_FAILED);
   }

   ArraySetAsSeries(MiddleBB,true);
   ArraySetAsSeries(UpperBB,true);
   ArraySetAsSeries(LowerBB,true);
   ArraySetAsSeries(MAHigh5,true);
   ArraySetAsSeries(MALow5,true);

   Print("BBMA Telegram EA Loaded.");

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//|                        PART 2                                    |
//+------------------------------------------------------------------+

//==========================================================
// ON DEINIT
//==========================================================

void OnDeinit(const int reason)
{
   if(BBHandle!=INVALID_HANDLE)
      IndicatorRelease(BBHandle);
}

//==========================================================
// COPY BBMA BUFFERS
//==========================================================

bool UpdateBBMA()
{
   if(BBHandle==INVALID_HANDLE)
      return(false);

   if(CopyBuffer(BBHandle,0,0,5,MiddleBB)!=5)
      return(false);

   if(CopyBuffer(BBHandle,1,0,5,UpperBB)!=5)
      return(false);

   if(CopyBuffer(BBHandle,2,0,5,LowerBB)!=5)
      return(false);

   if(CopyBuffer(BBHandle,4,0,5,MAHigh5)!=5)
      return(false);

   if(CopyBuffer(BBHandle,6,0,5,MALow5)!=5)
      return(false);

   return(true);
}

//==========================================================
// GET CLOSED CANDLE
//==========================================================

bool GetClosedBar(MqlRates &bar)
{
   MqlRates rates[];

   ArraySetAsSeries(rates,true);

   if(CopyRates(_Symbol,_Period,0,3,rates)!=3)
      return(false);

   bar=rates[1];

   return(true);
}

//==========================================================
// NEW BAR DETECTION
//==========================================================

bool IsNewBar()
{
   datetime current=iTime(_Symbol,_Period,0);

   if(current!=LastBarTime)
   {
      LastBarTime=current;
      return(true);
   }

   return(false);
}

//==========================================================
// BBMA ACCESS FUNCTIONS
//==========================================================

//==========================================================
// CURRENT BAR VALUES (Index 0)
//==========================================================

double MidBB()
{
   return(MiddleBB[1]);
}

double UpperBand0()
{
   return(UpperBB[0]);
}

double LowerBand0()
{
   return(LowerBB[0]);
}

double HighMA0()
{
   return(MAHigh5[0]);
}

double LowMA0()
{
   return(MALow5[0]);
}

//==========================================================
// CLOSED BAR VALUES (Index 1)
//==========================================================

double UpperBand()
{
   return(UpperBB[1]);
}

double LowerBand()
{
   return(LowerBB[1]);
}

double HighMA()
{
   return(MAHigh5[1]);
}

double LowMA()
{
   return(MALow5[1]);
}

//==========================================================
// CANDLE HELPERS
//==========================================================

bool Bullish(const MqlRates &bar)
{
   return(bar.close>bar.open);
}

bool Bearish(const MqlRates &bar)
{
   return(bar.close<bar.open);
}

//==========================================================
// CHECK DATA READY
//==========================================================

bool DataReady()
{
   if(Bars(_Symbol,_Period)<100)
      return(false);

   if(!UpdateBBMA())
      return(false);

   if(MiddleBB[1]==EMPTY_VALUE)
      return(false);

   if(UpperBB[1]==EMPTY_VALUE)
      return(false);

   if(LowerBB[1]==EMPTY_VALUE)
      return(false);

   if(MAHigh5[1]==EMPTY_VALUE)
      return(false);

   if(MALow5[1]==EMPTY_VALUE)
      return(false);

   return(true);
}
//==========================================================
// DETECT C1 BUY
// Close > Upper BB
//==========================================================

bool DetectC1Buy(const MqlRates &bar)
{
   return(bar.close > UpperBand());
}

//==========================================================
// DETECT C1 SELL
// Close < Lower BB
//==========================================================

bool DetectC1Sell(const MqlRates &bar)
{
   return(bar.close < LowerBand());
}

//==========================================================
// DETECT EC BUY
//
// High >= Upper BB
// Close < Upper BB
// Close > MA High 5
//==========================================================

bool DetectECBuy(const MqlRates &bar)
{
   if(bar.high < UpperBand())
      return(false);

   if(bar.close >= UpperBand())
      return(false);

   if(bar.close <= HighMA())
      return(false);

   return(true);
}

//==========================================================
// DETECT EC SELL
//
// Low <= Lower BB
// Close > Lower BB
// Close < MA Low 5
//==========================================================

bool DetectECSell(const MqlRates &bar)
{
   if(bar.low > LowerBand())
      return(false);

   if(bar.close <= LowerBand())
      return(false);

   if(bar.close >= LowMA())
      return(false);

   return(true);
}

//==========================================================
// DETECT C3 BUY
//
// Low <= Middle BB
// Close > Middle BB
// Close > MA High 5
// Green Candle
//==========================================================

bool DetectC3Buy(const MqlRates &bar)
{
   if(bar.low > MidBB())
      return(false);

   if(bar.close <= MidBB())
      return(false);

   if(bar.close <= HighMA())
      return(false);

   if(bar.close <= bar.open)
      return(false);

   return(true);
}

//==========================================================
// DETECT C3 SELL
//
// High >= Middle BB
// Close < Middle BB
// Close < MA Low 5
// Red Candle
//==========================================================

bool DetectC3Sell(const MqlRates &bar)
{
   if(bar.high < MidBB())
      return(false);

   if(bar.close >= MidBB())
      return(false);

   if(bar.close >= LowMA())
      return(false);

   if(bar.close >= bar.open)
      return(false);

   return(true);
}

//==========================================================
// CHECK SIGNAL
//
// Priority:
// C1
// EC
// C3
//==========================================================

SIGNAL_TYPE CheckSignal(const MqlRates &bar)
{
   if(DetectC1Buy(bar))
      return(SIGNAL_C1_BUY);

   if(DetectC1Sell(bar))
      return(SIGNAL_C1_SELL);

   if(DetectECBuy(bar))
      return(SIGNAL_EC_BUY);

   if(DetectECSell(bar))
      return(SIGNAL_EC_SELL);

   if(DetectC3Buy(bar))
      return(SIGNAL_C3_BUY);

   if(DetectC3Sell(bar))
      return(SIGNAL_C3_SELL);

   return(SIGNAL_NONE);
}
//==========================================================
// R1 SELL
//==========================================================

bool DetectR1Sell()
{
   return(HighMA0() > UpperBand0());
}

//==========================================================
// R1 BUY
//==========================================================

bool DetectR1Buy()
{
   return(LowMA0() < LowerBand0());
}

void CheckR1Signals()
{
   static bool R1SellActive=false;
   static bool R1BuyActive=false;

   //============================
   // R1 SELL
   //============================

   if(DetectR1Sell())
   {
      if(!R1SellActive)
      {
         string msg=
         "BBMA ALERT\n\n"
         "Signal : R1 SELL\n"
         "Symbol : "+_Symbol+
         "\nTimeframe : "+TFString()+
         "\nTime : "+TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);

         if(SendTelegram(msg))
         {
            Print("R1 SELL Sent");
            R1SellActive=true;
         }
      }
   }
   else
   {
      R1SellActive=false;
   }

   //============================
   // R1 BUY
   //============================

   if(DetectR1Buy())
   {
      if(!R1BuyActive)
      {
         string msg=
         "BBMA ALERT\n\n"
         "Signal : R1 BUY\n"
         "Symbol : "+_Symbol+
         "\nTimeframe : "+TFString()+
         "\nTime : "+TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);

         if(SendTelegram(msg))
         {
            Print("R1 BUY Sent");
            R1BuyActive=true;
         }
      }
   }
   else
   {
      R1BuyActive=false;
   }
}
//==========================================================
// ON TICK
//==========================================================

void OnTick()
{
   if(!DataReady())
      return;

   // Check R1 every tick
   CheckR1Signals();

   // Other candle alerts only once per new bar
   if(!IsNewBar())
      return;

   MqlRates bar;

   if(!GetClosedBar(bar))
      return;

   // Prevent duplicate alerts for the same closed candle
   if(bar.time == LastAlertBar)
      return;
//--------------------------------------------------
// R1 SELL
//--------------------------------------------------

if(DetectR1Sell())
{
   if(bar.time != LastR1SellBar)
   {
      string msg =
      "BBMA ALERT\n\n"
      "Signal : R1 SELL\n"
      "Symbol : "+_Symbol+
      "\nTimeframe : "+TFString()+
      "\nTime : "+TimeToString(bar.time,TIME_DATE|TIME_MINUTES);

      if(SendTelegram(msg))
      {
         LastR1SellBar = bar.time;
         Print("R1 SELL Alert Sent");
      }
   }
}

//--------------------------------------------------
// R1 BUY
//--------------------------------------------------

if(DetectR1Buy())
{
   if(bar.time != LastR1BuyBar)
   {
      string msg =
      "BBMA ALERT\n\n"
      "Signal : R1 BUY\n"
      "Symbol : "+_Symbol+
      "\nTimeframe : "+TFString()+
      "\nTime : "+TimeToString(bar.time,TIME_DATE|TIME_MINUTES);

      if(SendTelegram(msg))
      {
         LastR1BuyBar = bar.time;
         Print("R1 BUY Alert Sent");
      }
   }
}
   SIGNAL_TYPE signal = CheckSignal(bar);

   if(signal == SIGNAL_NONE)
      return;

   string message = BuildMessage(
      signal,
      bar.close,
      bar.time
   );

   bool sent = SendTelegram(message);

   if(sent)
   {
      LastAlertBar = bar.time;

      Print(
         "BBMA Telegram Alert Sent : ",
         SignalName(signal),
         "  ",
         _Symbol,
         " ",
         TFString()
      );
   }
   else
   {
      Print("Telegram message failed.");
   }
}