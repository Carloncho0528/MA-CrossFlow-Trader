//+------------------------------------------------------------------+
//|                                              MA CrossFlow Trader |
//|                                        Copyright 2024, Your Name |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Carlos Arturo Garzon"
#property link      "sedsist@gmail.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

input double         LotSize = 0.01;       // Lot Size
input int            SLPips = 100;         // Stop Loss in pips
input int            TPPips = 200;         // Take Profit in pips
input double         RiskPercent = 2.0;    // Risk Percentage
input int            MaxOrdersPerEvent = 3; // Maximum orders per event

int MA10Handle, MA50Handle, MA100Handle, MA150Handle, MA200Handle;
bool buySignal200, sellSignal200;
bool buySignal150, sellSignal150;
bool buySignal100, sellSignal100;
bool buySignal50, sellSignal50;
bool buySignal10, sellSignal10;
double accountBalance;

CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    MA10Handle = iMA(_Symbol, PERIOD_CURRENT, 10, 0, MODE_SMA, PRICE_CLOSE);
    MA50Handle = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);
    MA100Handle = iMA(_Symbol, PERIOD_CURRENT, 100, 0, MODE_SMA, PRICE_CLOSE);
    MA150Handle = iMA(_Symbol, PERIOD_CURRENT, 150, 0, MODE_SMA, PRICE_CLOSE);
    MA200Handle = iMA(_Symbol, PERIOD_CURRENT, 200, 0, MODE_SMA, PRICE_CLOSE);

    buySignal200 = false;
    sellSignal200 = false;
    buySignal150 = false;
    sellSignal150 = false;
    buySignal100 = false;
    sellSignal100 = false;
    buySignal50 = false;
    sellSignal50 = false;
    buySignal10 = false;
    sellSignal10 = false;

    accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(MA10Handle);
    IndicatorRelease(MA50Handle);
    IndicatorRelease(MA100Handle);
    IndicatorRelease(MA150Handle);
    IndicatorRelease(MA200Handle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 1);
    double ma200Value[], ma150Value[], ma100Value[], ma50Value[], ma10Value[];
    
    CopyBuffer(MA200Handle, 0, 0, 1, ma200Value);
    CopyBuffer(MA150Handle, 0, 0, 1, ma150Value);
    CopyBuffer(MA100Handle, 0, 0, 1, ma100Value);
    CopyBuffer(MA50Handle, 0, 0, 1, ma50Value);
    CopyBuffer(MA10Handle, 0, 0, 1, ma10Value);

    // Close all buy orders if MA10 crosses below MA50
    if (ma10Value[0] < ma50Value[0])
    {
        CloseAllBuyOrders();
    }

    // Close all sell orders if MA10 crosses above MA50
    if (ma10Value[0] > ma50Value[0])
    {
        CloseAllSellOrders();
    }

    // Check for buy signals
    if (currentPrice > ma200Value[0] && !buySignal200)
    {
        if (CheckThirdBullishCandle(200))
        {
            OpenBuyOrders(RiskPercent, SLPips, TPPips, MaxOrdersPerEvent, "MA200 Buy");
            buySignal200 = true;
            sellSignal200 = false;
        }
    }
    // ... (repeat for other MA periods)

    // Check for sell signals
    if (currentPrice < ma200Value[0] && !sellSignal200)
    {
        if (CheckThirdBearishCandle(200))
        {
            OpenSellOrders(RiskPercent, SLPips, TPPips, MaxOrdersPerEvent, "MA200 Sell");
            sellSignal200 = true;
            buySignal200 = false;
        }
    }
    // ... (repeat for other MA periods)
}

//+------------------------------------------------------------------+
//| Open Buy Orders function                                         |
//+------------------------------------------------------------------+
void OpenBuyOrders(double riskPercent, int slPips, int tpPips, int maxOrders, string comment)
{
    int ordersOpened = 0;
    while (ordersOpened < maxOrders)
    {
        double lotSize = CalculateLotSize(riskPercent);
        if (OpenBuyOrder(lotSize, slPips, tpPips, comment))
        {
            ordersOpened++;
        }
        else
        {
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Open Sell Orders function                                         |
//+------------------------------------------------------------------+
void OpenSellOrders(double riskPercent, int slPips, int tpPips, int maxOrders, string comment)
{
    int ordersOpened = 0;
    while (ordersOpened < maxOrders)
    {
        double lotSize = CalculateLotSize(riskPercent);
        if (OpenSellOrder(lotSize, slPips, tpPips, comment))
        {
            ordersOpened++;
        }
        else
        {
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Open Buy Order function                                           |
//+------------------------------------------------------------------+
bool OpenBuyOrder(double lotSize, int slPips, int tpPips, string comment)
{
    double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double slPrice = askPrice - slPips * _Point;
    double tpPrice = askPrice + tpPips * _Point;

    return trade.Buy(lotSize, _Symbol, askPrice, slPrice, tpPrice, comment);
}

//+------------------------------------------------------------------+
//| Open Sell Order function                                         |
//+------------------------------------------------------------------+
bool OpenSellOrder(double lotSize, int slPips, int tpPips, string comment)
{
    double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double slPrice = bidPrice + slPips * _Point;
    double tpPrice = bidPrice - tpPips * _Point;

    return trade.Sell(lotSize, _Symbol, bidPrice, slPrice, tpPrice, comment);
}

//+------------------------------------------------------------------+
//| Calculate Lot Size function                                      |
//+------------------------------------------------------------------+
double CalculateLotSize(double riskPercent)
{
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double riskAmount = accountBalance * riskPercent / 100;
    double stopLossInPoints = SLPips * _Point / tickSize;
    double lotSize = NormalizeDouble(riskAmount / (tickValue * stopLossInPoints), 2);

    return MathMax(lotSize, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
}

//+------------------------------------------------------------------+
//| Check Third Bullish Candle function                              |
//+------------------------------------------------------------------+
bool CheckThirdBullishCandle(int period)
{
    double ma[], prevClose[], prevOpen[], currentClose[], currentOpen[];
    CopyBuffer(iMA(_Symbol, PERIOD_CURRENT, period, 0, MODE_SMA, PRICE_CLOSE), 0, 1, 2, ma);
    CopyClose(_Symbol, PERIOD_CURRENT, 1, 2, prevClose);
    CopyOpen(_Symbol, PERIOD_CURRENT, 1, 2, prevOpen);
    CopyClose(_Symbol, PERIOD_CURRENT, 0, 1, currentClose);
    CopyOpen(_Symbol, PERIOD_CURRENT, 0, 1, currentOpen);

    if (currentClose[0] > ma[0] && currentOpen[0] < ma[0] &&
        prevClose[0] < ma[1] && prevOpen[0] < ma[1])
    {
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Check Third Bearish Candle function                              |
//+------------------------------------------------------------------+
bool CheckThirdBearishCandle(int period)
{
    double ma[], prevClose[], prevOpen[], currentClose[], currentOpen[];
    CopyBuffer(iMA(_Symbol, PERIOD_CURRENT, period, 0, MODE_SMA, PRICE_CLOSE), 0, 1, 2, ma);
    CopyClose(_Symbol, PERIOD_CURRENT, 1, 2, prevClose);
    CopyOpen(_Symbol, PERIOD_CURRENT, 1, 2, prevOpen);
    CopyClose(_Symbol, PERIOD_CURRENT, 0, 1, currentClose);
    CopyOpen(_Symbol, PERIOD_CURRENT, 0, 1, currentOpen);

    if (currentClose[0] < ma[0] && currentOpen[0] > ma[0] &&
        prevClose[0] > ma[1] && prevOpen[0] > ma[1])
    {
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Close All Buy Orders function                                     |
//+------------------------------------------------------------------+
void CloseAllBuyOrders()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket))
        {
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
                trade.PositionClose(ticket);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Close All Sell Orders function                                   |
//+------------------------------------------------------------------+
void CloseAllSellOrders()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket))
        {
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            {
                trade.PositionClose(ticket);
            }
        }
    }
}