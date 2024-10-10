#include <Trade\Trade.mqh>
CTrade Trade; // Trade object.
   // Parameters
   input int EMA_period = 20;   // Period of EMA
   input double lotSize = 0.1;  // Lot size for trade
   input double slippage = 3;   // Maximum slippage allowed
   input double stopLoss = 50;  // Stop loss in pips
   input double takeProfit = 50;// Take profit in pips
   
   int handleEMA;

int OnInit()
  {
   string name = "Egna indikatorer\\Linear_Regression_Slope.ex5";
   handleEMA = iCustom(_Symbol, PERIOD_CURRENT, name, 80, PRICE_CLOSE);
   return(INIT_SUCCEEDED);
  }
  
void OnDeinit(const int reason)
  {
  }
  
void OnTick()
  {
   // Get the current and previous EMA values

   double EMAs[]; 
   CopyBuffer(handleEMA,0,0,1,EMAs);
   Comment("EMAs ", EMAs[0]);
   Comment("Close ", iClose("", PERIOD_CURRENT, 1));
   
  }
//+------------------------------------------------------------------+
