//+------------------------------------------------------------------+
//|                                                  Stokastiskt.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//-PROPERTIES-//
#property description   "EA based on Knastish template"

//-INCLUDES-//
// '#include' allows to import code from other files.
// In the following instance the file has to be placed in the MQL5\Include folder.
#include <Trade\Trade.mqh> // This file is required to easily manage orders and positions.
#include <MQLTA ErrorHandling.mqh> // This file contains useful descriptions for errors.
#include <MQLTA Utils.mqh> // This file contains some useful functions.

enum ENUM_RISK_BASE
{
    RISK_BASE_EQUITY = 1,     // EQUITY
    RISK_BASE_BALANCE = 2,    // BALANCE
    RISK_BASE_FREEMARGIN = 3, // FREE MARGIN
    RISK_BASE_FLAT = 4,       // FLAT AMOUNT
};

enum ENUM_RISK_DEFAULT_SIZE
{
    RISK_DEFAULT_FIXED = 1,   // FIXED LOT SIZE
    RISK_DEFAULT_AUTO = 2,    // AUTOMATIC SIZE BASED ON RISK
};

enum ENUM_MODE_SL
{
    SL_FIXED = 0,             // FIXED STOP LOSS
    SL_AUTO = 1,              // CUSTOM MADE STOP LOSS
};

enum ENUM_MODE_TP
{
    TP_FIXED = 0,             // FIXED TAKE PROFIT
    TP_AUTO = 1,              // CUSTOM MADE TAKE PROFIT
    TP_RR = 2,                // TP BASED ON SL AND RISK REWARD RATIO
};

// EA Parameters
input string Comment_0 = "==========";          // EA-Specific Parameters

input int MA_Period = 100;
input int MA_Shift = 0;
input ENUM_MA_METHOD MA_Mode = MODE_SMA;
input ENUM_APPLIED_PRICE MA_Price = PRICE_CLOSE;

input int Kperiod = 8;
input int Dperiod = 3;
input int slowing = 5;

input int rsi_period = 10;

input string Comment_1 = "==========";  // Trading Hours Settings
input bool UseTradingHours = false;     // Limit trading hours
input ENUM_HOUR TradingHourStart = h07; // Trading start hour (Broker server hour)
input ENUM_HOUR TradingHourEnd = h19;   // Trading end hour (Broker server hour)

input string Comment_2 = "==========";  // ATR Settings
input int ATRPeriod = 100;              // ATR period
input ENUM_TIMEFRAMES ATRTimeFrame = PERIOD_CURRENT; // ATR timeframe
input double ATRMultiplierSL = 2;       // ATR multiplier for stop-loss
input double ATRMultiplierTP = 3;       // ATR multiplier for take-profit

// General input parameters
input string Comment_a = "==========";                             // Risk Management Settings
input ENUM_RISK_DEFAULT_SIZE RiskDefaultSize = RISK_DEFAULT_FIXED; // Position size mode
input double DefaultLotSize = 0.01;                                // Position size (if fixed or if no stop loss defined)
input ENUM_RISK_BASE RiskBase = RISK_BASE_BALANCE;                 // Risk base
input int MaxRiskPerTrade = 2;                                     // Percentage to risk each trade
input int RiskFlatAmount = 100;                                    // Fixed risk in flat money (account currancy)
input double MinLotSize = 0.01;                                    // Minimum position size allowed
input double MaxLotSize = 100;                                     // Maximum position size allowed
input int MaxPositions = 1;                                        // Maximum number of positions for this EA
input bool UseExitSignals = true;                                  // Use defined exit signals

input string Comment_b = "==========";                             // Stop-Loss and Take-Profit Settings
input ENUM_MODE_SL StopLossMode = SL_FIXED;                        // Stop-loss mode
input int DefaultStopLoss = 0;                                     // Default stop-loss in points (0 = no stop-loss)
input int MinStopLoss = 0;                                         // Minimum allowed stop-loss in points
input int MaxStopLoss = 5000;                                      // Maximum allowed stop-loss in points
input ENUM_MODE_TP TakeProfitMode = TP_FIXED;                      // Take-profit mode
input int DefaultTakeProfit = 0;                                   // Default take-profit in points (0 = no take-profit)
input int MinTakeProfit = 0;                                       // Minimum allowed take-profit in points
input int MaxTakeProfit = 5000;                                    // Maximum allowed take-profit in points
input double RRRatio = 2.0;                                        // RRatio

input string Comment_c = "==========";                             // Partial Close Settings
input bool UsePartialClose = false;                                // Use partial close
input double PartialClosePerc = 50;                                // Partial close percentage
input double ATRMultiplierPC = 1;                                  // ATR multiplier for partial close

input string Comment_d = "==========";                             // Additional Settings
input int MagicNumber = 0;                                         // Magic number
input string OrderNote = "";                                       // Comment for orders
input int Slippage = 5;                                            // Slippage in points
input int MaxSpread = 50;                                          // Maximum allowed spread to trade, in points


// Global Variables
CTrade Trade; // Trade object.
int ATRHandle; // Indicator handle for ATR.
int MAHandle; // Global indicator handle for the EA's main signal indicator.
int StochHandle;
int LRSHandle;

int barsTotal;
int exitstate = 0;

double ATR_current, ATR_previous; // ATR values.
double ma_current, ma_previous; 
double Kstoch_current, Kstoch_previous, Kstoch_previous_previous;
double Dstoch_current, Dstoch_previous, Dstoch_previous_previous;  

int RSIHandle;
double RSI_current, RSI_previous, RSI_previous_previous;

bool cooldown = false;
// Here go all the event handling functions. They all run on specific events generated for the expert advisor.
// All event handlers are optional and can be removed if you don't need to process that specific event.

//+-------------------------------------------------------------------+
//| Expert initialization handler                                     |
//| Here goes the code that runs just once each time you load the EA. |
//+-------------------------------------------------------------------+
int OnInit()
{
    // EventSetTimer(60); // Starting a 60-second timer.
    // EventSetMillisecondTimer(500); // Starting a 500-millisecond timer.

    if (!Prechecks()) // Check if everything is OK with input parameters.
    {
        return INIT_FAILED; // Don't initialize the EA if checks fail.
    }

    if (!InitializeHandles()) // Initialize indicator handles.
    {
        PrintFormat("Error initializing indicator handles - %s - %d", GetLastErrorText(GetLastError()), GetLastError());
        return INIT_FAILED;
    }

    SetTradeObject();

    return INIT_SUCCEEDED; // Successful initialization.
}

void OnDeinit(const int reason)
{
    // Normally, there isn't much stuff you need to do on deinitialization.
}

//+------------------------------------------------------------------+
void OnTick()
{
    ProcessTick(); // Calling the EA's main processing function here. It's defined farther below.
}

void OnTimer()
{
    // For example, you can update a display timer here if you have one in your EA.
}

void OnTrade()
{
    // For example, if you want to do something when a pending order gets triggered, you can do it here without overloading the OnTick() handler too much.
}

// Initialize handles. Indicator handles have to be initialized at the beginning of the EA's operation.
bool InitializeHandles()
{
    ATRHandle = iATR(Symbol(), ATRTimeFrame, ATRPeriod);
    if (ATRHandle == INVALID_HANDLE)
    {
        PrintFormat("Unable to create ATR handle - %s - %d.", GetLastErrorText(GetLastError()), GetLastError());
        return false;
    }
        
    MAHandle = iMA(Symbol(), PERIOD_D1, MA_Period, MA_Shift, MA_Mode, MA_Price);
    if (MAHandle == INVALID_HANDLE)
    {
        PrintFormat("Unable to create MA handle - %s - %d.", GetLastErrorText(GetLastError()), GetLastError());
        return false;
    }
    
    StochHandle = iStochastic(Symbol(), Period(), Kperiod, Dperiod, slowing, MODE_SMA, STO_LOWHIGH);
    if (StochHandle == INVALID_HANDLE)
    {
        PrintFormat("Unable to create iStochastic handle - %s - %d.", GetLastErrorText(GetLastError()), GetLastError());
        return false;
    }
    
    RSIHandle = iRSI(Symbol(), PERIOD_CURRENT, rsi_period, PRICE_CLOSE);
    if (RSIHandle == INVALID_HANDLE)
    {
        PrintFormat("Unable to create RSI handle - %s - %d.", GetLastErrorText(GetLastError()), GetLastError());
        return false;
    }
    
    return true;
}

// Entry and exit processing
void ProcessTick()
{
    if (!GetIndicatorsData()) return;
    
    if (cooldown){
      cooldown = !(Kstoch_previous>70);
    }
    
    if (CountPositions())
    {
        // There is a position open. Manage SL, TP, or close if necessary.
        if (UsePartialClose) PartialCloseAll();
        if (UseExitSignals) CheckExitSignal();
    }
 
    if (CountPositions() < MaxPositions) CheckEntrySignal(); // Check entry signals only if there aren't too many positions already.
}


bool GetIndicatorsData()
{
   double buf[]; // Needed for CopyBuffer().
   
   CopyBuffer(ATRHandle, 0, 0, 2, buf); // Copy using ATR indicator handle 2 latest values from 0th buffer to the buf array.
   ATR_current = buf[1];
   ATR_previous = buf[0];
   
   // This is where the main indicator data is read.
   // !! Uncomment and modify to use indicator values in your entry and exit signals
   CopyBuffer(MAHandle, 0, 0, 2, buf); // Copying using main indicator handle 2 latest completed candles (hence starting from the 1st, and not 0th, candle) from 0th buffer to the buf array.
   ma_current = buf[1];
   ma_previous = buf[0];
   
   CopyBuffer(StochHandle, 0, 0, 3, buf); // Copying using main indicator handle 2 latest completed candles (hence starting from the 1st, and not 0th, candle) from 0th buffer to the buf array.
   Kstoch_current = buf[2];
   Kstoch_previous = buf[1];
   Kstoch_previous_previous = buf[0];
   
   CopyBuffer(StochHandle, 1, 0, 3, buf); // Copying using main indicator handle 2 latest completed candles (hence starting from the 1st, and not 0th, candle) from 0th buffer to the buf array.
   Dstoch_current = buf[2];
   Dstoch_previous = buf[1];
   Dstoch_previous_previous = buf[0];
   
   CopyBuffer(RSIHandle, 0, 0, 3, buf); // Copying using main indicator handle 2 latest completed candles (hence starting from the 1st, and not 0th, candle) from 0th buffer to the buf array.
   RSI_current = buf[2];
   RSI_previous = buf[1];
   RSI_previous_previous = buf[0];
     
   return true;
}

// Entry signal
void CheckEntrySignal()
{
   if ((UseTradingHours) && (!IsCurrentTimeInInterval(TradingHourStart, TradingHourEnd))) return; // Trading hours restrictions for entry.
   
   bool BuySignal = false;
   bool SellSignal = false;
   
   int bars = iBars(_Symbol, PERIOD_CURRENT);
   if(barsTotal == bars){
      return;
   }
   
   barsTotal = bars;

   
   bool longentry1 = ma_current < LocalMin(2);
   bool longentry2 = Kstoch_previous_previous < Dstoch_previous_previous;
   bool longentry3 = Kstoch_previous_previous < 40;
   bool longentry4 = Kstoch_previous_previous < Kstoch_previous;
   bool longentry5 = Kstoch_previous > Dstoch_previous;
   bool longentry6 = RSI_current < 50;
   
   if (longentry1 && longentry2 && longentry3 && longentry5 && longentry6 && !cooldown)
   {
      OpenBuy();
      cooldown = true;
      exitstate = 0;
   }
   
   
   
   if (SellSignal)
   {
      OpenSell();
   }
}

// Exit signal
void CheckExitSignal()
{
    //!! if ((UseTradingHours) && (!IsCurrentTimeInInterval(TradingHourStart, TradingHourEnd))) return; // Trading hours restrictions for exit. Normally, you don't want to restrict exit by hours. Still, it's a possibility.

    bool SignalExitLong = false;
    bool SignalExitShort = false;
    
    /*if(exitstate == 0 && Kstoch_previous > 80 ){exitstate = 1;}
    if(exitstate == 1 && Kstoch_current < 70){
      SignalExitLong = true;
    }*/
    
    if(RSI_current > 90){
      SignalExitLong = true;
    }
    
    if (SignalExitLong) CloseAllBuy();
    if (SignalExitShort) CloseAllSell();
}

// Trading functions

// Open a position with a buy order.
bool OpenBuy()
{
    double Ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double Bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double OpenPrice = Ask; // Buy at Ask.
    double StopLossPrice = StopLoss(ORDER_TYPE_BUY, OpenPrice); // Calculate SL based on direction, price, and SL rules.
    if(StopLossPrice > MaxStopLoss || StopLossPrice < MinStopLoss) {
      PrintFormat("Unable to open BUY: Stop loss outside range");
      return false;
    }
    double TakeProfitPrice = TakeProfit(ORDER_TYPE_BUY, OpenPrice, StopLossPrice); // Calculate TP based on direction, price, and TP rules.
    double Size = LotSize(StopLossPrice, OpenPrice); // Calculate position size based on the SL, price, and the given rules.
    // Use the standard Trade object to open the position with calculated parameters.
    if (!Trade.Buy(Size, Symbol(), OpenPrice, StopLossPrice, TakeProfitPrice))
    {
        PrintFormat("Unable to open BUY: %s - %d", Trade.ResultRetcodeDescription(), Trade.ResultRetcode());
        return false;
    }
    return true;
}

// Open a position with a sell order.
bool OpenSell()
{
    double Ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double Bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double OpenPrice = Bid; // Sell at Bid.
    double StopLossPrice = StopLoss(ORDER_TYPE_SELL, OpenPrice); // Calculate SL based on direction, price, and SL rules.
    if(StopLossPrice > MaxStopLoss || StopLossPrice < MinStopLoss) {
      PrintFormat("Unable to open Sell: Stop loss outside range");
      return false;
    }
    double TakeProfitPrice = TakeProfit(ORDER_TYPE_SELL, OpenPrice, StopLossPrice); // Calculate TP based on direction, price, and TP rules.
    double Size = LotSize(StopLossPrice, OpenPrice); // Calculate position size based on the SL, price, and the given rules.
    // Use the standard Trade object to open the position with calculated parameters.
    if (!Trade.Sell(Size, Symbol(), OpenPrice, StopLossPrice, TakeProfitPrice))
    {
        PrintFormat("Unable to open SELL: %s - %d", Trade.ResultRetcodeDescription(), Trade.ResultRetcode());
        return false;
    }
    return true;
}


// Custom made stop-loss calculation
double DynamicStopLossPrice(ENUM_ORDER_TYPE type, double open_price)
{
    double StopLossPrice = 0;
    if (type == ORDER_TYPE_BUY)
    {
        StopLossPrice = open_price - ATR_previous * ATRMultiplierSL;

    }
    else if (type == ORDER_TYPE_SELL)
    {
        StopLossPrice = open_price + ATR_previous * ATRMultiplierSL;
    }
    return NormalizeDouble(StopLossPrice, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
}

// Custom take-profit calculation
double DynamicTakeProfitPrice(ENUM_ORDER_TYPE type, double open_price)
{
    double TakeProfitPrice = 0;
    if (type == ORDER_TYPE_BUY)
    {
        TakeProfitPrice = open_price + ATR_previous * ATRMultiplierTP;
    }
    else if (type == ORDER_TYPE_SELL)
    {
        TakeProfitPrice = open_price - ATR_previous * ATRMultiplierTP;
    }
    return NormalizeDouble(TakeProfitPrice, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
}

// Calculate the position size for an order.
double LotSize(double stop_loss, double open_price)
{
    double Size = DefaultLotSize;
    if (RiskDefaultSize == RISK_DEFAULT_AUTO) // If the position size is dynamic.
    {
        if (stop_loss != 0) // Calculate position size only if SL is non-zero, otherwise there will be a division by zero error.
        {
            double RiskBaseAmount = 0;
            // TickValue is the value of the individual price increment for 1 lot of the instrument expressed in the account currency.
            double TickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
            // Define the base for the risk calculation depending on the parameter chosen
            if (RiskBase == RISK_BASE_BALANCE) RiskBaseAmount = AccountBalance();
            else if (RiskBase == RISK_BASE_EQUITY) RiskBaseAmount = AccountEquity();
            else if (RiskBase == RISK_BASE_FREEMARGIN) RiskBaseAmount = AccountFreeMargin();
            double SL = MathAbs(open_price - stop_loss) / SymbolInfoDouble(Symbol(), SYMBOL_POINT); // SL as a number of points.
            // Calculate the Position Size.
            if(RiskBase == RISK_BASE_FLAT){
               Size = RiskFlatAmount / (SL * TickValue);
            } else {
               Size = (RiskBaseAmount * MaxRiskPerTrade / 100) / (SL * TickValue);
            }
        }
        // If the stop loss is zero, then use the default size.
        if (stop_loss == 0)
        {
            Size = DefaultLotSize;
        }
    }
    
    // Normalize the Lot Size to satisfy the allowed lot increment and minimum and maximum position size.
    double LotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    double MaxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    double MinLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    Size = MathFloor(Size / LotStep) * LotStep;
    // If the lot size is too big, then set it to 0 and don't trade.
    if (Size > MaxLotSize || (Size > MaxLot)) Size = 0;
    // If the lot size is too small, then set it to 0 and don't trade.
    if ((Size < MinLotSize) || (Size < MinLot)) Size = 0;
    
    return Size;
}

// Calculate a stop-loss price for an order.
double StopLoss(ENUM_ORDER_TYPE order_type, double open_price)
{
    double StopLossPrice = 0;
    if (StopLossMode == SL_FIXED) // Easy way.
    {
        if (DefaultStopLoss == 0) return 0;
        if (order_type == ORDER_TYPE_BUY)
        {
            StopLossPrice = open_price - DefaultStopLoss * SymbolInfoDouble(Symbol(), SYMBOL_POINT);
        }
        if (order_type == ORDER_TYPE_SELL)
        {
            StopLossPrice = open_price + DefaultStopLoss * SymbolInfoDouble(Symbol(), SYMBOL_POINT);
        }
    }
    else // Special cases.
    {
        StopLossPrice = DynamicStopLossPrice(order_type, open_price);
    }
    return NormalizeDouble(StopLossPrice, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
}

// Calculate the take-profit price for an order.
double TakeProfit(ENUM_ORDER_TYPE order_type, double open_price, double stop_loss_price)
{
    double TakeProfitPrice = 0;
    if (TakeProfitMode == TP_FIXED) // Easy way.
    {
        if (DefaultTakeProfit == 0) return 0;
        if (order_type == ORDER_TYPE_BUY)
        {
            TakeProfitPrice = open_price + DefaultTakeProfit * SymbolInfoDouble(Symbol(), SYMBOL_POINT);
        }
        if (order_type == ORDER_TYPE_SELL)
        {
            TakeProfitPrice = open_price - DefaultTakeProfit * SymbolInfoDouble(Symbol(), SYMBOL_POINT);
        }
    } else if (TakeProfitMode == TP_RR){
        if (RRRatio == 0) return 0;
        if (order_type == ORDER_TYPE_BUY)
        {
            TakeProfitPrice = open_price + RRRatio*(open_price - stop_loss_price);
        }
        if (order_type == ORDER_TYPE_SELL)
        {
            TakeProfitPrice = open_price - RRRatio*(stop_loss_price - open_price);
        }
    }
    else // Special cases.
    {
        TakeProfitPrice = DynamicTakeProfitPrice(order_type, open_price);
    }
    return NormalizeDouble(TakeProfitPrice, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
}

double LocalMin(int nBars){
   double min = 0;
   double ref;
   for(int i=1;i<=nBars;i++){
      ref = iLow(_Symbol, PERIOD_CURRENT, i);
      if(ref < min || min == 0){
         min = ref;
      }
   }
   return min;
}

double LocalMax(int nBars){
   double max = 0;
   double ref;
   for(int i=1;i<=nBars;i++){
      ref = iHigh(_Symbol, PERIOD_CURRENT, i);
      if(ref > max || max == 0){
         max = ref;
      }
   }
   return max;
}