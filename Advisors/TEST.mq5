//+------------------------------------------------------------------+
//|                                                TimeIntervalEA.mq5 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

input int HourStart = 3;
input int MinuteStart = 10;

input int HourEnd = 10;
input int MinuteEnd = 10;

int RSIhandle;
void OnTick()
{  
   double rsi[];
   RSIhandle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
   CopyBuffer(RSIhandle, 0, 0, 1, rsi);
   Comment(rsi[0]);
}

//+------------------------------------------------------------------+