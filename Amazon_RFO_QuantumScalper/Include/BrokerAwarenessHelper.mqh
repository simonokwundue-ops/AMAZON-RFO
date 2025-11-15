//+------------------------------------------------------------------+
//|                                      BrokerAwarenessHelper.mqh   |
//|                                    Amazon RFO Quantum Scalper    |
//|                      Broker Rules & Portfolio Management Helper  |
//+------------------------------------------------------------------+
#property copyright "Amazon RFO Quantum Scalper"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Broker Awareness & Portfolio Management Helper                   |
//| Handles broker-specific rules and portfolio monitoring          |
//| Provides account/position statistics and risk exposure tracking  |
//+------------------------------------------------------------------+
class CBrokerAwarenessHelper
{
private:
   datetime m_lastDayReset;
   int m_tradesToday;
   double m_plToday;
   double m_dayHighEquity;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CBrokerAwarenessHelper()
   {
      m_lastDayReset = TimeCurrent();
      m_tradesToday = 0;
      m_plToday = 0.0;
      m_dayHighEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      
      CheckDailyReset();
   }
   
   //+------------------------------------------------------------------+
   //| Check if new day and reset counters                             |
   //+------------------------------------------------------------------+
   void CheckDailyReset()
   {
      datetime currentTime = TimeCurrent();
      MqlDateTime currentDT, lastResetDT;
      
      TimeToStruct(currentTime, currentDT);
      TimeToStruct(m_lastDayReset, lastResetDT);
      
      // Check if day changed
      if(currentDT.day != lastResetDT.day || currentDT.mon != lastResetDT.mon || currentDT.year != lastResetDT.year)
      {
         // New day - reset counters
         m_lastDayReset = currentTime;
         m_tradesToday = 0;
         m_plToday = 0.0;
         m_dayHighEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Account Information                                              |
   //+------------------------------------------------------------------+
   double GetAccountBalance() { return AccountInfoDouble(ACCOUNT_BALANCE); }
   double GetAccountEquity() { return AccountInfoDouble(ACCOUNT_EQUITY); }
   double GetAccountMargin() { return AccountInfoDouble(ACCOUNT_MARGIN); }
   double GetAccountFreeMargin() { return AccountInfoDouble(ACCOUNT_FREEMARGIN); }
   double GetAccountProfit() { return AccountInfoDouble(ACCOUNT_PROFIT); }
   
   //+------------------------------------------------------------------+
   //| Get margin level (%)                                            |
   //+------------------------------------------------------------------+
   double GetMarginLevel()
   {
      double margin = GetAccountMargin();
      if(margin == 0)
         return 0;
         
      double equity = GetAccountEquity();
      return (equity / margin) * 100.0;
   }
   
   //+------------------------------------------------------------------+
   //| Portfolio Statistics                                             |
   //+------------------------------------------------------------------+
   int GetTotalOpenPositions()
   {
      return PositionsTotal();
   }
   
   //+------------------------------------------------------------------+
   //| Get total floating P/L                                          |
   //+------------------------------------------------------------------+
   double GetTotalFloatingPL()
   {
      return GetAccountProfit();
   }
   
   //+------------------------------------------------------------------+
   //| Get total exposure (sum of all position volumes)                |
   //+------------------------------------------------------------------+
   double GetTotalExposure()
   {
      double totalExposure = 0.0;
      
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0)
         {
            double volume = PositionGetDouble(POSITION_VOLUME);
            totalExposure += volume;
         }
      }
      
      return totalExposure;
   }
   
   //+------------------------------------------------------------------+
   //| Get exposure for specific symbol                                 |
   //+------------------------------------------------------------------+
   double GetSymbolExposure(string symbol)
   {
      double symbolExposure = 0.0;
      
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0)
         {
            if(PositionGetString(POSITION_SYMBOL) == symbol)
            {
               double volume = PositionGetDouble(POSITION_VOLUME);
               symbolExposure += volume;
            }
         }
      }
      
      return symbolExposure;
   }
   
   //+------------------------------------------------------------------+
   //| Count positions for symbol                                       |
   //+------------------------------------------------------------------+
   int CountSymbolPositions(string symbol, long magic = -1)
   {
      int count = 0;
      
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0)
         {
            if(PositionGetString(POSITION_SYMBOL) == symbol)
            {
               if(magic < 0 || PositionGetInteger(POSITION_MAGIC) == magic)
                  count++;
            }
         }
      }
      
      return count;
   }
   
   //+------------------------------------------------------------------+
   //| Broker Trading Rules                                             |
   //+------------------------------------------------------------------+
   double GetMinLot(string symbol)
   {
      return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   }
   
   double GetMaxLot(string symbol)
   {
      return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   }
   
   double GetLotStep(string symbol)
   {
      return SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   }
   
   int GetStopsLevel(string symbol)
   {
      return (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   }
   
   int GetFreezeLevel(string symbol)
   {
      return (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   }
   
   //+------------------------------------------------------------------+
   //| Check if trading is allowed for symbol                          |
   //+------------------------------------------------------------------+
   bool IsTradeAllowed(string symbol)
   {
      // Check if symbol exists
      if(!SymbolInfoInteger(symbol, SYMBOL_SELECT))
         return false;
         
      // Check if trading is allowed
      if(!SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE))
         return false;
         
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get margin required for position                                |
   //+------------------------------------------------------------------+
   double GetMarginRequired(string symbol, double lots, ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY)
   {
      double margin = 0;
      
      if(!OrderCalcMargin(orderType, symbol, lots, SymbolInfoDouble(symbol, SYMBOL_ASK), margin))
         return 0;
         
      return margin;
   }
   
   //+------------------------------------------------------------------+
   //| Normalize lot size to broker requirements                       |
   //+------------------------------------------------------------------+
   double NormalizeLot(double lots, string symbol)
   {
      double minLot = GetMinLot(symbol);
      double maxLot = GetMaxLot(symbol);
      double lotStep = GetLotStep(symbol);
      
      // Round to lot step
      lots = MathFloor(lots / lotStep) * lotStep;
      
      // Ensure within limits
      lots = MathMax(lots, minLot);
      lots = MathMin(lots, maxLot);
      
      return lots;
   }
   
   //+------------------------------------------------------------------+
   //| Daily Tracking                                                   |
   //+------------------------------------------------------------------+
   int GetTradesToday()
   {
      CheckDailyReset();
      return m_tradesToday;
   }
   
   double GetPLToday()
   {
      CheckDailyReset();
      return m_plToday;
   }
   
   //+------------------------------------------------------------------+
   //| Record trade                                                     |
   //+------------------------------------------------------------------+
   void RecordTrade(double profit)
   {
      CheckDailyReset();
      m_tradesToday++;
      m_plToday += profit;
   }
   
   //+------------------------------------------------------------------+
   //| Get daily drawdown from high water mark                         |
   //+------------------------------------------------------------------+
   double GetDailyDrawdown()
   {
      CheckDailyReset();
      
      double currentEquity = GetAccountEquity();
      
      // Update high water mark if new high
      if(currentEquity > m_dayHighEquity)
         m_dayHighEquity = currentEquity;
         
      // Calculate drawdown from high
      return m_dayHighEquity - currentEquity;
   }
   
   //+------------------------------------------------------------------+
   //| Get daily drawdown percentage                                   |
   //+------------------------------------------------------------------+
   double GetDrawdownPercent()
   {
      CheckDailyReset();
      
      if(m_dayHighEquity == 0)
         return 0;
         
      double drawdown = GetDailyDrawdown();
      return (drawdown / m_dayHighEquity) * 100.0;
   }
   
   //+------------------------------------------------------------------+
   //| Risk Management Checks                                           |
   //+------------------------------------------------------------------+
   bool IsWithinDailyDrawdownLimit(double maxDrawdownPercent)
   {
      return GetDrawdownPercent() < maxDrawdownPercent;
   }
   
   //+------------------------------------------------------------------+
   //| Check if within floating P/L limit                              |
   //+------------------------------------------------------------------+
   bool IsWithinFloatingPLLimit(double maxFloatingPercent)
   {
      double equity = GetAccountEquity();
      if(equity == 0)
         return false;
         
      double floatingPL = GetTotalFloatingPL();
      double floatingPercent = MathAbs(floatingPL) / equity * 100.0;
      
      return floatingPercent <= maxFloatingPercent;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate maximum allowed lot for risk percentage               |
   //+------------------------------------------------------------------+
   double GetMaxAllowedLot(string symbol, double riskPercent, double slPips)
   {
      if(slPips <= 0)
         return GetMinLot(symbol);
         
      double equity = GetAccountEquity();
      double riskMoney = equity * (riskPercent / 100.0);
      
      // Calculate lot size that gives desired risk
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      if(tickSize == 0 || point == 0)
         return GetMinLot(symbol);
         
      // Get pip size
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double pipSize = (digits == 5 || digits == 3) ? point * 10.0 : point;
      
      // Pip value per lot
      double pipValuePerLot = (tickValue / tickSize) * pipSize;
      
      if(pipValuePerLot == 0)
         return GetMinLot(symbol);
         
      // Calculate lot size
      double lots = riskMoney / (slPips * pipValuePerLot);
      
      // Normalize to broker requirements
      return NormalizeLot(lots, symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Get account leverage                                            |
   //+------------------------------------------------------------------+
   long GetAccountLeverage()
   {
      return AccountInfoInteger(ACCOUNT_LEVERAGE);
   }
   
   //+------------------------------------------------------------------+
   //| Get account currency                                            |
   //+------------------------------------------------------------------+
   string GetAccountCurrency()
   {
      return AccountInfoString(ACCOUNT_CURRENCY);
   }
   
   //+------------------------------------------------------------------+
   //| Print account summary                                           |
   //+------------------------------------------------------------------+
   void PrintAccountSummary()
   {
      Print("═══════════════════════════════════════════════════════════");
      Print("ACCOUNT SUMMARY");
      Print("═══════════════════════════════════════════════════════════");
      Print("Balance: ", DoubleToString(GetAccountBalance(), 2));
      Print("Equity: ", DoubleToString(GetAccountEquity(), 2));
      Print("Free Margin: ", DoubleToString(GetAccountFreeMargin(), 2));
      Print("Margin Level: ", DoubleToString(GetMarginLevel(), 2), "%");
      Print("Open Positions: ", GetTotalOpenPositions());
      Print("Floating P/L: ", DoubleToString(GetTotalFloatingPL(), 2));
      Print("Daily Drawdown: ", DoubleToString(GetDrawdownPercent(), 2), "%");
      Print("Trades Today: ", GetTradesToday());
      Print("P/L Today: ", DoubleToString(GetPLToday(), 2));
      Print("═══════════════════════════════════════════════════════════");
   }
};
//+------------------------------------------------------------------+
