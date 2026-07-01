//+------------------------------------------------------------------+
//|                                                BBMA_RetestEA.mq5 |
//|         BBMA Retest EA (Telegram + Rectangle)                    |
//|         Reads BBMA_Visual.mq5                                    |
//+------------------------------------------------------------------+
#property copyright "BBMA Alerts"
#property version   "2.00"
#property strict

//==========================================================
// INPUTS
//==========================================================

input string IndicatorName = "BBMA_Visual";

// Telegram
input string BotToken = "8964584245:AAE1fSJ4gVVUYcQheDYlAza61hCwcAM5JzM";
input string ChatID   = "1216288023";

// Rectangle
input int RectangleForwardCandles = 8;
input int RectangleLifeDays = 2;
input int RetestTolerancePoints = 0;
input bool KeepOnlyLatestRectangle = true;

// Expiry
input int MaxRetestBars = 20;

//==========================================================
// GLOBALS
//==========================================================

int BBHandle = INVALID_HANDLE;

datetime LastBarTime = 0;

string LastBuyRectangle  = "";
string LastSellRectangle = "";

//----------------------------------------------------------
// Indicator Buffers
//----------------------------------------------------------

double MiddleBB[];
double UpperBB[];
double LowerBB[];
double MAHigh5[];
double MAHigh10[];
double MALow5[];
double MALow10[];


//----------------------------------------------------------
// Signal Enum
//----------------------------------------------------------

enum SIGNAL_TYPE
{
   SIGNAL_NONE=0,

   SIGNAL_C1_BUY,
   SIGNAL_C1_SELL,

   SIGNAL_EC_BUY,
   SIGNAL_EC_SELL,

   SIGNAL_C3_BUY,
   SIGNAL_C3_SELL
};

//----------------------------------------------------------
// Waiting State
//----------------------------------------------------------

bool WaitingBuyRetest=false;
bool WaitingSellRetest=false;

SIGNAL_TYPE WaitingBuySignal=SIGNAL_NONE;
SIGNAL_TYPE WaitingSellSignal=SIGNAL_NONE;

bool WaitingBuyCrossover=false;
bool WaitingSellCrossover=false;

SIGNAL_TYPE BuyCrossoverSignal=SIGNAL_NONE;
SIGNAL_TYPE SellCrossoverSignal=SIGNAL_NONE;

datetime WaitingBuyBarTime=0;
datetime WaitingSellBarTime=0;

int WaitingBuyBarIndex=0;
int WaitingSellBarIndex=0;

//----------------------------------------------------------
// Duplicate Protection
//----------------------------------------------------------

datetime LastBuyRetestAlert=0;
datetime LastSellRetestAlert=0;

//==========================================================
// RECTANGLE STORAGE
//==========================================================

double BuyRectLow5=0;
double BuyRectLow10=0;
double SellRectHigh5=0;
double SellRectHigh10=0;

datetime BuyRetestTime=0;
datetime SellRetestTime=0;

struct RECT_INFO
{
   string name;
   datetime expiry;
};

RECT_INFO Rectangles[500];
int RectangleCount=0;

//==========================================================
// SIGNAL NAME
//==========================================================

string SignalName(SIGNAL_TYPE signal)
{
   switch(signal)
   {
      case SIGNAL_C1_BUY:  return("C1 BUY");
      case SIGNAL_C1_SELL: return("C1 SELL");

      case SIGNAL_EC_BUY:  return("EC BUY");
      case SIGNAL_EC_SELL: return("EC SELL");

      case SIGNAL_C3_BUY:  return("C3 BUY");
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
      case PERIOD_M1: return("M1");
      case PERIOD_M5: return("M5");
      case PERIOD_M15:return("M15");
      case PERIOD_M30:return("M30");
      case PERIOD_H1:return("H1");
      case PERIOD_H4:return("H4");
      case PERIOD_D1:return("D1");
      case PERIOD_W1:return("W1");
      case PERIOD_MN1:return("MN1");
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
         out+=CharToString(c);
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

   int http=
      WebRequest(
         "POST",
         url,
         headers,
         10000,
         post,
         result,
         response_headers
      );

   if(http==-1)
   {
      Print("Telegram Error : ",GetLastError());
      return(false);
   }

   string response=CharArrayToString(result);

   Print(response);

   if(StringFind(response,"\"ok\":true")>=0)
      return(true);

   return(false);
}

//==========================================================
// ON INIT
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
   ArraySetAsSeries(MAHigh10,true);
   ArraySetAsSeries(MALow5,true);
   ArraySetAsSeries(MALow10,true);

   Print("BBMA Retest EA Loaded.");

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//|                         PART 2                                   |
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
// UPDATE BBMA BUFFERS
//==========================================================

bool UpdateBBMA()
{
   if(BBHandle==INVALID_HANDLE)
      return(false);

   if(CopyBuffer(BBHandle,0,0,10,MiddleBB)!=10)
      return(false);

   if(CopyBuffer(BBHandle,1,0,10,UpperBB)!=10)
      return(false);

   if(CopyBuffer(BBHandle,2,0,10,LowerBB)!=10)
      return(false);

   if(CopyBuffer(BBHandle,4,0,10,MAHigh5)!=10)
   return(false);

   if(CopyBuffer(BBHandle,5,0,10,MAHigh10)!=10)
   return(false);

   if(CopyBuffer(BBHandle,6,0,10,MALow5)!=10)
   return(false);

   if(CopyBuffer(BBHandle,7,0,10,MALow10)!=10)
   return(false);

   return(true);
}

//==========================================================
// DATA READY
//==========================================================

bool DataReady()
{
   if(Bars(_Symbol,_Period)<100)
      return(false);

   if(!UpdateBBMA())
      return(false);

   return(true);
}

//==========================================================
// NEW BAR
//==========================================================

bool IsNewBar()
{
   datetime t=iTime(_Symbol,_Period,0);

   if(t!=LastBarTime)
   {
      LastBarTime=t;
      return(true);
   }

   return(false);
}

//==========================================================
// GET CLOSED BAR
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
// HELPER FUNCTIONS
//==========================================================

double MidBB()
{
   return(MiddleBB[1]);
}

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

double HighMA10()
{
   return(MAHigh10[1]);
}

double LowMA10()
{
   return(MALow10[1]);
}

//==========================================================
// DETECT C1 BUY
//==========================================================

bool DetectC1Buy(const MqlRates &bar)
{
   return(bar.close>UpperBand());
}

//==========================================================
// DETECT C1 SELL
//==========================================================

bool DetectC1Sell(const MqlRates &bar)
{
   return(bar.close<LowerBand());
}

//==========================================================
// DETECT EC BUY
//==========================================================

bool DetectECBuy(const MqlRates &bar)
{
   if(bar.high<UpperBand())
      return(false);

   if(bar.close>=UpperBand())
      return(false);

   if(bar.close<=HighMA())
      return(false);

   return(true);
}

//==========================================================
// DETECT EC SELL
//==========================================================

bool DetectECSell(const MqlRates &bar)
{
   if(bar.low>LowerBand())
      return(false);

   if(bar.close<=LowerBand())
      return(false);

   if(bar.close>=LowMA())
      return(false);

   return(true);
}

//==========================================================
// DETECT C3 BUY
//==========================================================

bool DetectC3Buy(const MqlRates &bar)
{
   if(bar.low > GetMidBB())
      return(false);

   if(bar.close <= GetMidBB())
      return(false);

   if(bar.close <= GetHighMA5())
      return(false);

   if(bar.close <= bar.open)      // Green candle required
      return(false);

   return(true);
}

//==========================================================
// DETECT C3 SELL
//==========================================================

bool DetectC3Sell(const MqlRates &bar)
{
   if(bar.high < GetMidBB())
      return(false);

   if(bar.close >= GetMidBB())
      return(false);

   if(bar.close >= GetLowMA5())
      return(false);

   if(bar.close >= bar.open)      // Red candle required
      return(false);

   return(true);
}

//==========================================================
// CHECK SIGNAL
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
//+------------------------------------------------------------------+
//|                         PART 3                                   |
//|             BBMA RETEST ENGINE                                   |
//+------------------------------------------------------------------+

//==========================================================
// START WAITING
//==========================================================

void StartWaiting(SIGNAL_TYPE signal,const MqlRates &bar)
{
   switch(signal)
   {
      case SIGNAL_C1_BUY:
      case SIGNAL_EC_BUY:
      case SIGNAL_C3_BUY:
      
         ClearBuyWaiting();
      
         WaitingBuyRetest = true;
         WaitingBuySignal = signal;
         WaitingBuyBarTime = bar.time;      
     
         Print("Waiting BUY : ",SignalName(signal));
      
         break;

      case SIGNAL_C1_SELL:
      case SIGNAL_EC_SELL:
      case SIGNAL_C3_SELL:
      
         ClearSellWaiting();
      
         WaitingSellRetest = true;
         WaitingSellSignal = signal;
         WaitingSellBarTime = bar.time;
         
           
         Print("Waiting SELL : ",SignalName(signal));
      
         break;
   }
}

//==========================================================
// SAVE RECTANGLE
//==========================================================

void SaveRectangle(string name)
{
   if(RectangleCount>=500)
      return;

   Rectangles[RectangleCount].name=name;
   Rectangles[RectangleCount].expiry=
      TimeCurrent()+RectangleLifeDays*86400;

   RectangleCount++;
}

//==========================================================
// DELETE EXPIRED RECTANGLES
//==========================================================

void DeleteExpiredRectangles()
{
   datetime now=TimeCurrent();

   for(int i=RectangleCount-1;i>=0;i--)
   {
      if(now>=Rectangles[i].expiry)
      {
         ObjectDelete(0,Rectangles[i].name);

         for(int j=i;j<RectangleCount-1;j++)
            Rectangles[j]=Rectangles[j+1];

         RectangleCount--;
      }
   }
}

//==========================================================
// DRAW BUY RECTANGLE
//==========================================================

void DrawBuyRectangle()
{
      // Retest candle shift
      int retestShift=iBarShift(_Symbol,_Period,BuyRetestTime,false);
      
      if(retestShift<0)
         return;
      
      int seconds = PeriodSeconds(_Period);
      
      datetime left=iTime(_Symbol,_Period,1);          // previous candle
      
      datetime right=
      left+
      (RectangleForwardCandles+1)*PeriodSeconds(_Period);
      
      if(left>right)
      {
         datetime t=left;
         left=right;
         right=t;
      }

   string signal=SignalName(WaitingBuySignal);
   StringReplace(signal," ","_");

   string name=
      signal+
      "_Buy_Retest_"+
      IntegerToString((int)TimeCurrent());
      
      if(KeepOnlyLatestRectangle)
      {
         if(LastBuyRectangle != "" && ObjectFind(0, LastBuyRectangle) >= 0)
            ObjectDelete(0, LastBuyRectangle);
      }
      
   if(!ObjectCreate(
         0,
         name,
         OBJ_RECTANGLE,
         0,
         left,
         BuyRectLow5,
         right,
         BuyRectLow10))
   {
      Print("Buy Rectangle Error = ",GetLastError());
   
      Print("Left  = ",TimeToString(left));
      Print("Right = ",TimeToString(right));
   
      Print("Top    = ",BuyRectLow5);
      Print("Bottom = ",BuyRectLow10);
   
      return;
   }

   ObjectSetInteger(0,name,OBJPROP_COLOR,clrGreen);
   ObjectSetInteger(0,name,OBJPROP_FILL,false);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);

   SaveRectangle(name);
   LastBuyRectangle = name;
   ChartRedraw();
}

//==========================================================
// DRAW SELL RECTANGLE
//==========================================================

void DrawSellRectangle()
{
      int retestShift=iBarShift(_Symbol,_Period,SellRetestTime,false);
      
      if(retestShift<0)
         return;
      
      int seconds = PeriodSeconds(_Period);
      
      datetime left=iTime(_Symbol,_Period,1);          // previous candle
      
      datetime right=
      left+
      (RectangleForwardCandles+1)*PeriodSeconds(_Period);
      
      if(left>right)
      {
         datetime t=left;
         left=right;
         right=t;
      }

   string signal=SignalName(WaitingSellSignal);
   StringReplace(signal," ","_");

   string name=
      signal+
      "_Sell_Retest_"+
      IntegerToString((int)TimeCurrent());
      
      if(KeepOnlyLatestRectangle)
      {
         if(LastSellRectangle != "" && ObjectFind(0, LastSellRectangle) >= 0)
            ObjectDelete(0, LastSellRectangle);
      }
      
   if(!ObjectCreate(
         0,
         name,
         OBJ_RECTANGLE,
         0,
         left,
         SellRectHigh10,
         right,
         SellRectHigh5))
   {
      Print("Sell Rectangle Error=",GetLastError());
      return;
   }

   ObjectSetInteger(0,name,OBJPROP_COLOR,clrRed);
   ObjectSetInteger(0,name,OBJPROP_FILL,false);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);

   SaveRectangle(name);
   LastSellRectangle = name;
   ChartRedraw();
}

//==========================================================
// BUILD RETEST MESSAGE
//==========================================================

string BuildRetestMessage(
   SIGNAL_TYPE signal,
   bool buy)
{
   string txt="BBMA ALERT\n\n";

   txt+=SignalName(signal);

   if(buy)
      txt+=" RETEST BUY";
   else
      txt+=" RETEST SELL";

   txt+="\n\n";

   txt+="Symbol : ";
   txt+=_Symbol;

   txt+="\n";

   txt+="Timeframe : ";
   txt+=TFString();

   txt+="\n";

   txt+="Time : ";
   txt+=TimeToString(
         TimeCurrent(),
         TIME_DATE|TIME_SECONDS);

   return(txt);
}

string BuildCrossoverMessage(SIGNAL_TYPE signal,bool buy)
{
   string txt="BBMA ALERT\n\n";

   txt+=SignalName(signal);

   if(buy)
      txt+="\nBUY RETEST CROSSOVER";
   else
      txt+="\nSELL RETEST CROSSOVER";

   txt+="\n\n";

   txt+="Symbol : ";
   txt+=_Symbol;

   txt+="\nTimeframe : ";
   txt+=TFString();

   txt+="\nTime : ";
   txt+=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);

   return(txt);
}

//==========================================================
// CLEAR BUY
//==========================================================

void ClearBuyWaiting()
{
   WaitingBuyRetest=false;
   WaitingBuySignal=SIGNAL_NONE;
   WaitingBuyBarTime=0;
}

//==========================================================
// CLEAR SELL
//==========================================================

void ClearSellWaiting()
{
   WaitingSellRetest=false;
   WaitingSellSignal=SIGNAL_NONE;
   WaitingSellBarTime=0;
}

//==========================================================
// EXPIRE OLD SETUPS
//==========================================================

void CheckExpiredSignals()
{
   if(WaitingBuyRetest)
   {
      int bars=iBarShift(
         _Symbol,
         _Period,
         WaitingBuyBarTime
      );

      if(bars>MaxRetestBars)
      {
         Print("BUY setup expired");
         ClearBuyWaiting();
      }
   }

   if(WaitingSellRetest)
   {
      int bars=iBarShift(
         _Symbol,
         _Period,
         WaitingSellBarTime
      );

      if(bars>MaxRetestBars)
      {
         Print("SELL setup expired");
         ClearSellWaiting();
      }
   }
}
//==========================================================
// LIVE BUY RETEST
//==========================================================

bool IsBuyRetest()
{
   if(!WaitingBuyRetest)
      return(false);

   MqlTick tick;

   if(!SymbolInfoTick(_Symbol,tick))
      return(false);

   double tol = RetestTolerancePoints * _Point;

   if(MathAbs(tick.bid - MALow5[0]) <= tol)
      return(true);

   return(false);
}

//==========================================================
// LIVE SELL RETEST
//==========================================================

bool IsSellRetest()
{
   if(!WaitingSellRetest)
      return(false);

   MqlTick tick;

   if(!SymbolInfoTick(_Symbol,tick))
      return(false);

   double tol = RetestTolerancePoints * _Point;

   if(MathAbs(tick.ask - MAHigh5[0]) <= tol)
      return(true);

   return(false);
}

//+------------------------------------------------------------------+
//|                    PART 5 - RECTANGLE MANAGER                    |
//+------------------------------------------------------------------+

//==========================================================
// ON TICK
//==========================================================

void OnTick()
{
   //-------------------------------------------------------
   // Update BBMA data
   //-------------------------------------------------------

   if(!UpdateBBMA())
      return;

   //-------------------------------------------------------
   // Delete expired rectangles
   //-------------------------------------------------------

   DeleteExpiredRectangles();

   //-------------------------------------------------------
   // Expire old waiting setups
   //-------------------------------------------------------

   CheckExpiredSignals();

   //-------------------------------------------------------
   // Detect NEW CLOSED candle
   //-------------------------------------------------------

   static datetime LastClosedBar=0;

   MqlRates bar[];

   ArraySetAsSeries(bar,true);

   if(CopyRates(_Symbol,_Period,0,3,bar)!=3)
      return;

   if(bar[1].time!=LastClosedBar)
   {
      LastClosedBar=bar[1].time;

      //----------------------------------------------------
      // BUY SIGNALS
      //----------------------------------------------------

      if(DetectC1Buy(bar[1]))
      {
         StartWaiting(SIGNAL_C1_BUY,bar[1]);
      }

      else if(DetectECBuy(bar[1]))
      {
         StartWaiting(SIGNAL_EC_BUY,bar[1]);
      }

      else if(DetectC3Buy(bar[1]))
      {
         StartWaiting(SIGNAL_C3_BUY,bar[1]);
      }

      //----------------------------------------------------
      // SELL SIGNALS
      //----------------------------------------------------

      else if(DetectC1Sell(bar[1]))
      {
         StartWaiting(SIGNAL_C1_SELL,bar[1]);
      }

      else if(DetectECSell(bar[1]))
      {
         StartWaiting(SIGNAL_EC_SELL,bar[1]);
      }

      else if(DetectC3Sell(bar[1]))
      {
         StartWaiting(SIGNAL_C3_SELL,bar[1]);
      }

   }

   //-------------------------------------------------------
   // LIVE BUY RETEST
   //-------------------------------------------------------

   if(IsBuyRetest())
   {
      UpdateBBMA();      // refresh indicator   
      // Freeze MA values at RETEST
      BuyRectLow5  = MALow5[0];
      BuyRectLow10 = MALow10[0];
   
      BuyRetestTime = iTime(_Symbol,_Period,0); 
      
      Print("========== BUY RETEST ==========");
      Print("MALow5  = ",DoubleToString(BuyRectLow5,_Digits));
      Print("MALow10 = ",DoubleToString(BuyRectLow10,_Digits));   
                             
      DrawBuyRectangle();
      
      WaitingBuyCrossover=true;
      BuyCrossoverSignal=WaitingBuySignal;
      
      SendTelegram(
         BuildRetestMessage(
            WaitingBuySignal,
            true
         )
      );

      Print(
         SignalName(
            WaitingBuySignal
         ),
         " BUY RETEST"
      );

      ClearBuyWaiting();
   }

   //-------------------------------------------------------
   // LIVE SELL RETEST
   //-------------------------------------------------------

   if(IsSellRetest())
   {
      UpdateBBMA();      // refresh indicator   
     // Freeze MA values at RETEST
      SellRectHigh5  = MAHigh5[0];
      SellRectHigh10 = MAHigh10[0];
      Print("========== SELL RETEST ==========");
      Print("MAHigh5  = ",DoubleToString(SellRectHigh5,_Digits));
      Print("MAHigh10 = ",DoubleToString(SellRectHigh10,_Digits));   
      SellRetestTime = iTime(_Symbol,_Period,0);    
                          
      DrawSellRectangle();
      
      WaitingSellCrossover=true;
      SellCrossoverSignal=WaitingSellSignal;
      
      SendTelegram(
         BuildRetestMessage(
            WaitingSellSignal,
            false
         )
      );

      Print(
         SignalName(
            WaitingSellSignal
         ),
         " SELL RETEST"
      );

      ClearSellWaiting();
   }
   //---------------------------------------
   // BUY RETEST CROSSOVER
   //---------------------------------------
   
   if(WaitingBuyCrossover)
   {
      if(MAHigh5[0] < MAHigh10[0])
      {
         SendTelegram(
            BuildCrossoverMessage(
               BuyCrossoverSignal,
               true));
   
         Print("BUY RETEST CROSSOVER");
   
         WaitingBuyCrossover=false;
         BuyCrossoverSignal=SIGNAL_NONE;
      }
   }
   
   //---------------------------------------
   // SELL RETEST CROSSOVER
   //---------------------------------------
   
   if(WaitingSellCrossover)
   {
      if(MALow5[0] > MALow10[0])
      {
         SendTelegram(
            BuildCrossoverMessage(
               SellCrossoverSignal,
               false));
   
         Print("SELL RETEST CROSSOVER");
   
         WaitingSellCrossover=false;
         SellCrossoverSignal=SIGNAL_NONE;
      }
   }

}
//+------------------------------------------------------------------+
//|                       PART 7                                     |
//|                  FINALIZATION                                    |
//+------------------------------------------------------------------+

//==========================================================
// BBMA VALUE HELPERS
//==========================================================

double GetMidBB()
{
   return(MiddleBB[1]);
}

double GetUpperBB()
{
   return(UpperBB[1]);
}

double GetLowerBB()
{
   return(LowerBB[1]);
}

double GetHighMA5()
{
   return(MAHigh5[1]);
}

double GetHighMA10()
{
   return(MAHigh10[1]);
}

double GetLowMA5()
{
   return(MALow5[1]);
}

double GetLowMA10()
{
   return(MALow10[1]);
}