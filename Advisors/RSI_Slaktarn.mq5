//+------------------------------------------------------------------+
//|                                                 RSI_Slaktarn.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade Trade; // Trade object.

input int StartHour = 0;
input int CloseHour = 24;

input double lot = 0.1;
input int rsi_period = 4;

input double RSIentrylong = 70.0;
input double RSIexitlong = 25.0;

input double RSIentryshort = 30.0;
input double RSIexitshort = 75.0;

input int maxTradesDay = 2;

double RSIBuffer[];
double EMABuffer[];

bool inLong = false;
bool inShort = false;

int nTrades = 0;

int emaHandle;
int rsiHandle;

int OnInit()
  {
   emaHandle = iMA(Symbol(), PERIOD_CURRENT, 200, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle = iRSI(Symbol(), PERIOD_CURRENT, rsi_period, PRICE_CLOSE);
   return(INIT_SUCCEEDED);
  }
  
  
void OnDeinit(const int reason)
  {
  }
  
  
void OnTick()
  {
   // Get current time
   datetime currentTime = TimeCurrent();
   MqlDateTime currentTimeStruct;
   TimeCurrent(currentTimeStruct);
   
   if(currentTimeStruct.hour < StartHour || CloseHour <= currentTimeStruct.hour){
      CloseAllPositions();
      nTrades = 0;
      return;
   }
   
   if(nTrades > maxTradesDay){return;}
   
   CopyBuffer(rsiHandle, 0, 0, 2, RSIBuffer);
   double prevBarRSI = RSIBuffer[0];
   double currentRSI = RSIBuffer[1];
   Comment ("current rsi ", currentRSI);
   
   CopyBuffer(emaHandle, 0, 0, 1, EMABuffer);
   double currentEMA = EMABuffer[0];
   Comment ("current ema ", currentEMA);
   
   double currentAsk = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   if(currentRSI > RSIentrylong && !inLong && !inShort && currentAsk > currentEMA){
      Trade.Buy(lot, NULL, currentAsk, iLow(Symbol(),NULL,2));
      nTrades += 1;
      inLong = true;
   }
   
   if(inLong && currentRSI < RSIexitlong){
      CloseAllPositions();
      inLong = false;
   }

   
   double currentBid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   if(currentRSI < RSIentryshort && !inLong && !inShort && currentBid < currentEMA){
      Trade.Sell(lot, NULL, currentBid, iHigh(Symbol(),NULL,2));
      nTrades += 1;
      inShort = true;
   }
   
   if(inShort && currentRSI > RSIexitshort){
      CloseAllPositions();
      inShort = false;
   }
  }


void CloseAllPositions()
{
    int total = PositionsTotal();

    // Start a loop to scan all the positions.
    // The loop starts from the last, otherwise it could skip positions.
    for (int i = total - 1; i >= 0; i--)
    {
        // If the position cannot be selected log an error.
        if (PositionGetSymbol(i) == "")
        {
            continue;
        }
        for (int try = 0; try < 10; try++)
        {
            bool result = Trade.PositionClose(PositionGetInteger(POSITION_TICKET));
            if (!result)
            {
                PrintFormat(__FUNCTION__, ": ERROR - Unable to close position: %s - %d", Trade.ResultRetcodeDescription(), Trade.ResultRetcode());
            }
            else break;
        }
    }
}