//+------------------------------------------------------------------+
//|                                      Linear_Regression_Slope.mq5 |
//|                                                  Copyright gpwr. |
//+------------------------------------------------------------------+
#property copyright "gpwr"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "LRS"
#property indicator_type1   DRAW_LINE
#property indicator_color1  Blue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
//--- indicator inputs
input int                  Per   =40;           // Linear regression period
input ENUM_APPLIED_PRICE   Price =PRICE_MEDIAN; // Applied price
//--- global variables
double x[];
//--- indicator buffers
double lrs[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- allocate memory for global arrays
   ArrayResize(x,Per+1);

//--- indicator buffers mapping
   SetIndexBuffer(0,lrs);
   IndicatorSetInteger(INDICATOR_DIGITS,5);
   IndicatorSetString(INDICATOR_SHORTNAME,"LRS("+string(Per)+")");
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,Per+1);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &Time[],
                const double &Open[],
                const double &High[],
                const double &Low[],
                const double &Close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//--- check for insufficient data
   if(rates_total<Per+1)
     {
      Print("Error: not enough bars in history!");
      return(0);
     }

//--- main cycle
   int i=prev_calculated-1;
   if(i<Per) i=Per;
   while(i<rates_total)
     {
      for(int j=1;j<=Per;j++)
        {
         if(Price==PRICE_CLOSE)     x[j]=Close[i-j];
         if(Price==PRICE_OPEN)      x[j]=Open[i-j];
         if(Price==PRICE_HIGH)      x[j]=High[i-j];
         if(Price==PRICE_LOW)       x[j]=Low[i-j];
         if(Price==PRICE_MEDIAN)    x[j]=(Low[i-j]+High[i-j])/2.;
         if(Price==PRICE_TYPICAL)   x[j]=(Low[i-j]+High[i-j]+Close[i-j])/3.;
         if(Price==PRICE_WEIGHTED)  x[j]=(Low[i-j]+High[i-j]+Close[i-j]+Open[i-j])/4.;
        }
      lrs[i]=LinRegrSlope(Per);
      i++;
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Linear regression slope                                          |
//+------------------------------------------------------------------+
double LinRegrSlope(int per)
  {
   double sum=0.0;
   double wsum=0.0;
   for(int i=per;i>0;i--)
     {
      sum+=x[i];
      wsum+=x[i]*(per+1-i);
     }
   double lrs1;
   lrs1=6.*(2.*wsum/(per+1)/sum-1.)/(per-1); // normalize to SMA
   //lrs=6.*(1.0-(per+1)*sum/2./wsum)/(per-1); // normalize to LWMA
   return(lrs1*100000.); // convert to parts per 100k
  }
//+------------------------------------------------------------------+