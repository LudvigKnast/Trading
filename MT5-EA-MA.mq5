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
    RISK_DEFAULT_FIXED = 1,   // FIXED SIZE
    RISK_DEFAULT_AUTO = 2,    // AUTOMATIC SIZE BASED ON RISK
};

enum ENUM_MODE_SL
{
    SL_FIXED = 0,             // FIXED STOP LOSS
    SL_AUTO = 1,              // AUTOMATIC STOP LOSS
};

enum ENUM_MODE_TP
{
    TP_FIXED = 0,             // FIXED TAKE PROFIT
    TP_AUTO = 1,              // AUTOMATIC TAKE PROFIT
    TP_RR = 2,                // TP BASED ON SL AND RISK REWARD RATIO
};

// EA Parameters
input string Comment_0 = "==========";          // EA-Specific Parameters
input int MA_Period = 100;
input int MA_Shift = 0;
input ENUM_MA_METHOD MA_Mode = MODE_EMA;
input ENUM_APPLIED_PRICE MA_Price = PRICE_CLOSE;

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
input double MinLotSize = 0.01;                                    // Minimum position size allowed
input double MaxLotSize = 100;                                     // Maximum position size allowed
input int MaxPositions = 1;                                        // Maximum number of positions for this EA
input int RiskFlatAmount = 100;                                    // Fixed risk in flat money (account currancy)
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
input double RRRatio = 2.0;                                          // Risk/Reward ratio

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
int IndicatorHandle = -1; // Global indicator handle for the EA's main signal indicator.
double ATR_current, ATR_previous; // ATR values.
double Indicator_current, Indicator_previous; // Indicator values.

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
    // Indicator handle is the main handle for the signal generating indicator.
    IndicatorHandle = iMA(Symbol(), Period(), MA_Period, MA_Shift, MA_Mode, MA_Price);
    if (IndicatorHandle == INVALID_HANDLE)
    {
        PrintFormat("Unable to create main indicator handle - %s - %d.", GetLastErrorText(GetLastError()), GetLastError());
        return false;
    }
    // ATR handle for stop-loss and take-profit.
    ATRHandle = iATR(Symbol(), ATRTimeFrame, ATRPeriod);
    if (ATRHandle == INVALID_HANDLE)
    {
        PrintFormat("Unable to create ATR handle - %s - %d.", GetLastErrorText(GetLastError()), GetLastError());
        return false;
    }
    return true;
}

// Entry and exit processing
void ProcessTick()
{
    if (!GetIndicatorsData()) return;
    
    if (CountPositions())
    {
        // There is a position open. Manage SL, TP, or close if necessary.
        if (UsePartialClose) PartialCloseAll();
        if (UseExitSignals) CheckExitSignal();
    }
    
    // A block of code that lets the subsequent code execute only when a new bar appears on the chart.
    // This means that the entry signals will be checked only twice per bar.
    /* static datetime current_bar_time = WRONG_VALUE;
    datetime previous_bar_time = current_bar_time;
    current_bar_time = iTime(Symbol(), Period(), 0);
    static int ticks_of_new_bar = 0; // Process two ticks of each new bar to allow indicator buffers to refresh.
    if (current_bar_time == previous_bar_time)
    {
        ticks_of_new_bar++;
        if (ticks_of_new_bar > 1) return; // Skip after two ticks.
    } 
    else ticks_of_new_bar = 0; */

    // The number is recalculated after the first call because some trades could have been gotten closed.
    if (CountPositions() < MaxPositions) CheckEntrySignal(); // Check entry signals only if there aren't too many positions already.
}


// Utility functions

// Retrieve indicator data necessary for entry, update, and exit.
// Boolean type, so it can return true if all the data is available or false if it is not.
// Other advantage of this function is to move part of repetitive code into one location to make it leaner.
bool GetIndicatorsData()
{
   double buf[]; // Needed for CopyBuffer().
   
   CopyBuffer(ATRHandle, 0, 0, 2, buf); // Copy using ATR indicator handle 2 latest values from 0th buffer to the buf array.
   ATR_current = buf[1];
   ATR_previous = buf[0];
   
   // This is where the main indicator data is read.
   // !! Uncomment and modify to use indicator values in your entry and exit signals
   CopyBuffer(IndicatorHandle, 0, 1, 2, buf); // Copying using main indicator handle 2 latest completed candles (hence starting from the 1st, and not 0th, candle) from 0th buffer to the buf array.
   Indicator_current = buf[1];
   Indicator_previous = buf[0];
     
   return true;
}

// Entry signal
void CheckEntrySignal()
{
    if ((UseTradingHours) && (!IsCurrentTimeInInterval(TradingHourStart, TradingHourEnd))) return; // Trading hours restrictions for entry.

    bool BuySignal = false;
    bool SellSignal = false;

    // Buy signal conditions

    // This is where you should insert your entry signal for BUY orders.
    // Include a condition to open a buy order, the condition will have to set BuySignal to true or false.
   
    //!! Uncomment and modify this buy entry signal check line:
    if ((Indicator_current < iClose(Symbol(), Period(), 1)) && (Indicator_previous >= iClose(Symbol(), Period(), 2))) BuySignal = true; // Check if the indicator's value crossed the Close price level from below.

    if (BuySignal)
    {
        OpenBuy();
    }

    // Sell signal conditions

    // This is where you should insert your entry signal for SELL orders.
    // Include a condition to open a sell order, the condition will have to set SellSignal to true or false.
    
    //!! Uncomment and modify this sell entry signal check line:
    if ((Indicator_current > iClose(Symbol(), Period(), 1)) && (Indicator_previous <= iClose(Symbol(), Period(), 2))) SellSignal = true; // Check if the indicator's value crossed the Close price level from above.

    if (SellSignal)
    {
        OpenSell();
    }
}

// Exit signal
void CheckExitSignal()
{
    if ((UseTradingHours) && (!IsCurrentTimeInInterval(TradingHourStart, TradingHourEnd))) return; // Trading hours restrictions for exit. Normally, you don't want to restrict exit by hours. Still, it's a possibility.

    bool SignalExitLong = false;
    bool SignalExitShort = false;

    //!! Uncomment and modify these exit signal checks:
    if ((Indicator_current < iClose(Symbol(), Period(), 1)) && (Indicator_previous >= iClose(Symbol(), Period(), 2))) SignalExitShort = true; // Check if the indicator's value crossed the Close price level from below.
    else if ((Indicator_current > iClose(Symbol(), Period(), 1)) && (Indicator_previous <= iClose(Symbol(), Period(), 2))) SignalExitLong = true; // Check if the indicator's value crossed the Close price level from above.

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
    double TakeProfitPrice = TakeProfit(ORDER_TYPE_BUY, OpenPrice, StopLossPrice); // Calculate TP based on direction, price, and TP rules.
    double Size = LotSize(StopLossPrice, OpenPrice); // Calculate position size based on the SL, price, and the given rules.
    // Use the standard Trade object to open the position with calculated parameters.
    if (!Trade.Buy(Size, Symbol(), OpenPrice, StopLossPrice, OpenPrice+2*(OpenPrice-StopLossPrice)))
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
    double TakeProfitPrice = TakeProfit(ORDER_TYPE_SELL, OpenPrice, StopLossPrice); // Calculate TP based on direction, price, and TP rules.
    double Size = LotSize(StopLossPrice, OpenPrice); // Calculate position size based on the SL, price, and the given rules.
    // Use the standard Trade object to open the position with calculated parameters.
    if (!Trade.Sell(Size, Symbol(), OpenPrice, StopLossPrice, OpenPrice-2*(StopLossPrice-OpenPrice)))
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
        StopLossPrice = iLow(_Symbol,_Period,1);
    }
    else if (type == ORDER_TYPE_SELL)
    {
        StopLossPrice = iHigh(_Symbol,_Period,1);
    }
    return NormalizeDouble(StopLossPrice, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
}



// Custom made take-profit calculation
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
    // Limit the lot size in case it is greater than the maximum allowed by the user.
    if (Size > MaxLotSize) Size = MaxLotSize;
    // Limit the lot size in case it is greater than the maximum allowed by the broker.
    if (Size > MaxLot) Size = MaxLot;
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