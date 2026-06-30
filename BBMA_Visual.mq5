//+------------------------------------------------------------------+
//|                                                BBMA_Visual.mq5   |
//|      Converted from TradingView Pine Script (BBMA Visual)        |
//|      ChatGPT Conversion                                          |
//+------------------------------------------------------------------+
#property copyright "OpenAI"
#property version   "1.00"
#property strict

#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   8

//=============================
// Plot 1 : BB Basis
//=============================
#property indicator_label1  "BB Basis"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMagenta
#property indicator_width1  1

//=============================
// Plot 2 : BB Upper
//=============================
#property indicator_label2  "BB Upper"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrMagenta
#property indicator_width2  1

//=============================
// Plot 3 : BB Lower
//=============================
#property indicator_label3  "BB Lower"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrMagenta
#property indicator_width3  1

//=============================
// Plot 4 : EMA
//=============================
#property indicator_label4  "EMA 50"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrWhite
#property indicator_width4  1

//=============================
// Plot 5 : LWMA High 5
//=============================
#property indicator_label5  "LWMA High 5"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrRed
#property indicator_width5  1

//=============================
// Plot 6 : LWMA High 10
//=============================
#property indicator_label6  "LWMA High 10"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrOrange
#property indicator_width6  1

//=============================
// Plot 7 : LWMA Low 5
//=============================
#property indicator_label7  "LWMA Low 5"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrGreen
#property indicator_width7  1

//=============================
// Plot 8 : LWMA Low 10
//=============================
#property indicator_label8  "LWMA Low 10"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrLime
#property indicator_width8  1

//==================================================
// Inputs
//==================================================

// Bollinger Bands
input int      BB_Period      =20;
input double   BB_Deviation   =2.0;
input ENUM_APPLIED_PRICE BB_Price=PRICE_CLOSE;

// EMA
input int      EMA_Period     =50;
input ENUM_APPLIED_PRICE EMA_Price=PRICE_CLOSE;

// LWMA
input int      LWMA_High5_Period=5;
input int      LWMA_High10_Period=10;

input int      LWMA_Low5_Period=5;
input int      LWMA_Low10_Period=10;

//==================================================
// Buffers
//==================================================

double BBBasisBuffer[];
double BBUpperBuffer[];
double BBLowerBuffer[];

double EMABuffer[];

double LWMAHigh5Buffer[];
double LWMAHigh10Buffer[];

double LWMALow5Buffer[];
double LWMALow10Buffer[];

//==================================================
// Indicator Handles
//==================================================

int bbHandle;
int emaHandle;

int lwmaHigh5Handle;
int lwmaHigh10Handle;

int lwmaLow5Handle;
int lwmaLow10Handle;

//==================================================
// Initialization
//==================================================

int OnInit()
{

   // Buffers

   SetIndexBuffer(0,BBBasisBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,BBUpperBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,BBLowerBuffer,INDICATOR_DATA);

   SetIndexBuffer(3,EMABuffer,INDICATOR_DATA);

   SetIndexBuffer(4,LWMAHigh5Buffer,INDICATOR_DATA);
   SetIndexBuffer(5,LWMAHigh10Buffer,INDICATOR_DATA);

   SetIndexBuffer(6,LWMALow5Buffer,INDICATOR_DATA);
   SetIndexBuffer(7,LWMALow10Buffer,INDICATOR_DATA);

   ArraySetAsSeries(BBBasisBuffer,true);
   ArraySetAsSeries(BBUpperBuffer,true);
   ArraySetAsSeries(BBLowerBuffer,true);

   ArraySetAsSeries(EMABuffer,true);

   ArraySetAsSeries(LWMAHigh5Buffer,true);
   ArraySetAsSeries(LWMAHigh10Buffer,true);

   ArraySetAsSeries(LWMALow5Buffer,true);
   ArraySetAsSeries(LWMALow10Buffer,true);

   // Bollinger Bands

   bbHandle=iBands(
      _Symbol,
      _Period,
      BB_Period,
      0,
      BB_Deviation,
      BB_Price
   );

   if(bbHandle==INVALID_HANDLE)
      return(INIT_FAILED);

   // EMA

   emaHandle=iMA(
      _Symbol,
      _Period,
      EMA_Period,
      0,
      MODE_EMA,
      EMA_Price
   );

   if(emaHandle==INVALID_HANDLE)
      return(INIT_FAILED);

   // LWMA High 5

   lwmaHigh5Handle=iMA(
      _Symbol,
      _Period,
      LWMA_High5_Period,
      0,
      MODE_LWMA,
      PRICE_HIGH
   );

   if(lwmaHigh5Handle==INVALID_HANDLE)
      return(INIT_FAILED);

   // LWMA High 10

   lwmaHigh10Handle=iMA(
      _Symbol,
      _Period,
      LWMA_High10_Period,
      0,
      MODE_LWMA,
      PRICE_HIGH
   );

   if(lwmaHigh10Handle==INVALID_HANDLE)
      return(INIT_FAILED);

   // LWMA Low 5

   lwmaLow5Handle=iMA(
      _Symbol,
      _Period,
      LWMA_Low5_Period,
      0,
      MODE_LWMA,
      PRICE_LOW
   );

   if(lwmaLow5Handle==INVALID_HANDLE)
      return(INIT_FAILED);

   // LWMA Low 10

   lwmaLow10Handle=iMA(
      _Symbol,
      _Period,
      LWMA_Low10_Period,
      0,
      MODE_LWMA,
      PRICE_LOW
   );

   if(lwmaLow10Handle==INVALID_HANDLE)
      return(INIT_FAILED);

   IndicatorSetString(
      INDICATOR_SHORTNAME,
      "BBMA Visual"
   );

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| OnCalculate                                                      |
//+------------------------------------------------------------------+
int OnCalculate(
   const int rates_total,
   const int prev_calculated,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const long &tick_volume[],
   const long &volume[],
   const int &spread[]
)
{
   if(rates_total<=BB_Period)
      return(0);

   //=============================
   // Copy Bollinger Bands
   // Buffer 0 = Middle
   // Buffer 1 = Upper
   // Buffer 2 = Lower
   //=============================

   if(CopyBuffer(
         bbHandle,
         0,
         0,
         rates_total,
         BBBasisBuffer) <= 0)
      return(prev_calculated);

   if(CopyBuffer(
         bbHandle,
         1,
         0,
         rates_total,
         BBUpperBuffer) <= 0)
      return(prev_calculated);

   if(CopyBuffer(
         bbHandle,
         2,
         0,
         rates_total,
         BBLowerBuffer) <= 0)
      return(prev_calculated);

   //=============================
   // EMA
   //=============================

   if(CopyBuffer(
         emaHandle,
         0,
         0,
         rates_total,
         EMABuffer) <= 0)
      return(prev_calculated);

   //=============================
   // LWMA High 5
   //=============================

   if(CopyBuffer(
         lwmaHigh5Handle,
         0,
         0,
         rates_total,
         LWMAHigh5Buffer) <= 0)
      return(prev_calculated);

   //=============================
   // LWMA High 10
   //=============================

   if(CopyBuffer(
         lwmaHigh10Handle,
         0,
         0,
         rates_total,
         LWMAHigh10Buffer) <= 0)
      return(prev_calculated);

   //=============================
   // LWMA Low 5
   //=============================

   if(CopyBuffer(
         lwmaLow5Handle,
         0,
         0,
         rates_total,
         LWMALow5Buffer) <= 0)
      return(prev_calculated);

   //=============================
   // LWMA Low 10
   //=============================

   if(CopyBuffer(
         lwmaLow10Handle,
         0,
         0,
         rates_total,
         LWMALow10Buffer) <= 0)
      return(prev_calculated);

   return(rates_total);
}
//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(bbHandle != INVALID_HANDLE)
      IndicatorRelease(bbHandle);

   if(emaHandle != INVALID_HANDLE)
      IndicatorRelease(emaHandle);

   if(lwmaHigh5Handle != INVALID_HANDLE)
      IndicatorRelease(lwmaHigh5Handle);

   if(lwmaHigh10Handle != INVALID_HANDLE)
      IndicatorRelease(lwmaHigh10Handle);

   if(lwmaLow5Handle != INVALID_HANDLE)
      IndicatorRelease(lwmaLow5Handle);

   if(lwmaLow10Handle != INVALID_HANDLE)
      IndicatorRelease(lwmaLow10Handle);
}
//+------------------------------------------------------------------+