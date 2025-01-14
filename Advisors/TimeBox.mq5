//+------------------------------------------------------------------+
//|                                                TimeIntervalEA.mq5 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

CTrade Trade; // Trade object.
input int HourStart = 3;
input int MinuteStart = 5;

input int HourEnd = 6;
input int MinuteEnd = 5;

input double lot = 0.1;

input int CloseTimeHour = 18;
input int CloseTimeMin = 5;

double highestPrice = 0;
double lowestPrice = 0;

// Base name for the rectangle objects
string boxBaseName = "IntervalBox_";

bool boxNotPainted = false;
bool readyToTrade = false;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
// Get current time
   datetime currentTime = TimeCurrent();
   MqlDateTime currentTimeStruct;
   TimeCurrent(currentTimeStruct);

   MqlDateTime structTime;
   TimeCurrent(structTime);
   structTime.sec = 0;

   structTime.hour = HourStart;
   structTime.min = MinuteStart;
   datetime timeStart = StructToTime(structTime);

   structTime.hour = HourEnd;
   structTime.min = MinuteEnd;
   datetime timeEnd = StructToTime(structTime);

   double currentAsk = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double currentBid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   double diff = highestPrice-lowestPrice;

// Check if the current time is within the specified interval
   if(currentTimeStruct.hour == CloseTimeHour && currentTimeStruct.min == CloseTimeMin){
      if(!readyToTrade){
         Trade.PositionClose(Symbol());
      } else {readyToTrade = false;}
      highestPrice = 0;
      lowestPrice = 0;
     } 
   else if(currentTime >= timeStart && currentTime <= timeEnd){
      boxNotPainted = true;
      if(currentAsk > highestPrice || highestPrice == 0)
        {
         highestPrice = currentAsk;
        }
      else if(currentBid < lowestPrice || lowestPrice == 0)
        {
         lowestPrice = currentBid;
        }
     }
   else if(boxNotPainted) {
      string box = boxBaseName + TimeToString(currentTime);
      Print("Rangen för ", structTime.day, " var ", lowestPrice, " -> ", highestPrice);
      ObjectCreate(0, box, OBJ_RECTANGLE, 0, timeStart, highestPrice, timeEnd, lowestPrice);
      // Ställ in egenskaper för rektangeln
      ObjectSetInteger(0, box, OBJPROP_COLOR, clrLightBlue); // Färg
      ObjectSetInteger(0, box, OBJPROP_WIDTH, 2); // Linjebredd
      ObjectSetInteger(0, box, OBJPROP_STYLE, STYLE_SOLID); // Linjestil

      boxNotPainted = false;
      readyToTrade = true;
     }
   else if(currentAsk > highestPrice && readyToTrade)
     {
      if(!Trade.Buy(lot, NULL, currentAsk));
      {
        PrintFormat("Unable to open BUY: %s - %d", Trade.ResultRetcodeDescription(), Trade.ResultRetcode());
      }
      readyToTrade = false;
     }
   /*else if(currentBid < lowestPrice && readyToTrade)
     {
      if(!Trade.Sell(lot, NULL, currentBid));
      {
        PrintFormat("Unable to open Sell: %s - %d", Trade.ResultRetcodeDescription(), Trade.ResultRetcode());
      }
      readyToTrade = false;
     }*/
  }

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
