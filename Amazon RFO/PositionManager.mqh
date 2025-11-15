//+------------------------------------------------------------------+
//|                                           PositionManager.mqh    |
//| Manage multiple simultaneous micro-positions with dynamic control|
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>

// Position info structure
struct PositionInfo
{
   ulong ticket;
   int type;                // 0=buy, 1=sell
   double openPrice;
   double currentPrice;
   double sl;
   double tp;
   double lots;
   double profit;
   datetime openTime;
   bool isTrailing;
   double highestPrice;     // For trailing
   double lowestPrice;      // For trailing
};

// Position manager class for quantum-style multi-position handling
class CPositionManager
{
private:
   CTrade m_trade;
   PositionInfo m_positions[];
   int m_maxPositions;
   string m_symbol;
   double m_point;
   int m_digits;
   
   // Dynamic TP/SL settings
   double m_minTPPips;
   double m_maxTPPips;
   double m_minSLPips;
   double m_maxSLPips;
   double m_trailStepPips;
   
public:
   CPositionManager(string symbol = "", int maxPos = 5)
   {
      m_symbol = (symbol == "") ? _Symbol : symbol;
      m_maxPositions = maxPos;
      m_point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      
      // Initialize dynamic ranges (will be adjusted)
      m_minTPPips = 5.0;
      m_maxTPPips = 30.0;
      m_minSLPips = 3.0;
      m_maxSLPips = 20.0;
      m_trailStepPips = 2.0;
      
      ArrayResize(m_positions, 0);
   }
   
   // Update position list from terminal
   void UpdatePositions()
   {
      ArrayResize(m_positions, 0);
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == m_symbol)
         {
            PositionInfo info;
            info.ticket = ticket;
            info.type = (int)PositionGetInteger(POSITION_TYPE);
            info.openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            info.currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            info.sl = PositionGetDouble(POSITION_SL);
            info.tp = PositionGetDouble(POSITION_TP);
            info.lots = PositionGetDouble(POSITION_VOLUME);
            info.profit = PositionGetDouble(POSITION_PROFIT);
            info.openTime = (datetime)PositionGetInteger(POSITION_TIME);
            info.isTrailing = false;
            
            // Initialize trailing prices
            if(info.type == POSITION_TYPE_BUY)
            {
               info.highestPrice = info.currentPrice;
               info.lowestPrice = info.openPrice;
            }
            else
            {
               info.highestPrice = info.openPrice;
               info.lowestPrice = info.currentPrice;
            }
            
            int newSize = ArraySize(m_positions) + 1;
            ArrayResize(m_positions, newSize);
            m_positions[newSize - 1] = info;
         }
      }
   }
   
   // Get current position count
   int GetPositionCount()
   {
      UpdatePositions();
      return ArraySize(m_positions);
   }
   
   // Check if can open new position
   bool CanOpenPosition()
   {
      return (GetPositionCount() < m_maxPositions);
   }
   
   // Calculate dynamic TP/SL based on volatility and regime
   void CalculateDynamicTPSL(double volatility, double regimeMultTP, double regimeMultSL,
                            double &tpPips, double &slPips)
   {
      // Base on volatility (ATR)
      double baseTP = m_minTPPips + (volatility * 10.0); // Scale volatility to pips
      double baseSL = m_minSLPips + (volatility * 5.0);
      
      // Apply regime multipliers
      tpPips = baseTP * regimeMultTP;
      slPips = baseSL * regimeMultSL;
      
      // Clamp to min/max
      tpPips = MathMax(m_minTPPips, MathMin(m_maxTPPips, tpPips));
      slPips = MathMax(m_minSLPips, MathMin(m_maxSLPips, slPips));
   }
   
   // Open micro position with dynamic TP/SL
   bool OpenPosition(int type, double lots, double tpPips, double slPips, string comment = "")
   {
      if(!CanOpenPosition()) return false;
      
      double price, sl, tp;
      
      if(type == ORDER_TYPE_BUY)
      {
         price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         sl = NormalizeDouble(price - slPips * m_point * 10, m_digits);
         tp = NormalizeDouble(price + tpPips * m_point * 10, m_digits);
         
         return m_trade.Buy(lots, m_symbol, price, sl, tp, comment);
      }
      else if(type == ORDER_TYPE_SELL)
      {
         price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         sl = NormalizeDouble(price + slPips * m_point * 10, m_digits);
         tp = NormalizeDouble(price - tpPips * m_point * 10, m_digits);
         
         return m_trade.Sell(lots, m_symbol, price, sl, tp, comment);
      }
      
      return false;
   }
   
   // Trail stop for all positions
   void TrailAllPositions()
   {
      UpdatePositions();
      
      for(int i = 0; i < ArraySize(m_positions); i++)
      {
         TrailPosition(m_positions[i]);
      }
   }
   
   // Trail individual position
   void TrailPosition(PositionInfo &pos)
   {
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double trailStep = m_trailStepPips * m_point * 10;
      
      if(pos.type == POSITION_TYPE_BUY)
      {
         // Update highest price
         if(bid > pos.highestPrice)
            pos.highestPrice = bid;
         
         // Check if profitable enough to trail
         double profitPips = (bid - pos.openPrice) / (m_point * 10);
         if(profitPips > m_minTPPips * 0.5) // Trail after 50% of min TP
         {
            double newSL = NormalizeDouble(pos.highestPrice - trailStep, m_digits);
            if(newSL > pos.sl && newSL < bid)
            {
               m_trade.PositionModify(pos.ticket, newSL, pos.tp);
               pos.isTrailing = true;
            }
         }
      }
      else if(pos.type == POSITION_TYPE_SELL)
      {
         // Update lowest price
         if(ask < pos.lowestPrice)
            pos.lowestPrice = ask;
         
         // Check if profitable enough to trail
         double profitPips = (pos.openPrice - ask) / (m_point * 10);
         if(profitPips > m_minTPPips * 0.5)
         {
            double newSL = NormalizeDouble(pos.lowestPrice + trailStep, m_digits);
            if(newSL < pos.sl && newSL > ask)
            {
               m_trade.PositionModify(pos.ticket, newSL, pos.tp);
               pos.isTrailing = true;
            }
         }
      }
   }
   
   // Close all positions
   void CloseAllPositions()
   {
      UpdatePositions();
      
      for(int i = ArraySize(m_positions) - 1; i >= 0; i--)
      {
         m_trade.PositionClose(m_positions[i].ticket);
      }
   }
   
   // Close losing positions (for recovery strategy)
   void CloseLosingPositions()
   {
      UpdatePositions();
      
      for(int i = ArraySize(m_positions) - 1; i >= 0; i--)
      {
         if(m_positions[i].profit < 0)
         {
            m_trade.PositionClose(m_positions[i].ticket);
         }
      }
   }
   
   // Close winning positions (lock in profits)
   void CloseWinningPositions(double minProfitPips = 0)
   {
      UpdatePositions();
      
      for(int i = ArraySize(m_positions) - 1; i >= 0; i--)
      {
         double profitPips = 0;
         if(m_positions[i].type == POSITION_TYPE_BUY)
            profitPips = (m_positions[i].currentPrice - m_positions[i].openPrice) / (m_point * 10);
         else
            profitPips = (m_positions[i].openPrice - m_positions[i].currentPrice) / (m_point * 10);
         
         if(profitPips >= minProfitPips)
         {
            m_trade.PositionClose(m_positions[i].ticket);
         }
      }
   }
   
   // Get total profit of all positions
   double GetTotalProfit()
   {
      UpdatePositions();
      double total = 0;
      
      for(int i = 0; i < ArraySize(m_positions); i++)
         total += m_positions[i].profit;
      
      return total;
   }
   
   // Get net direction (positive = more buys, negative = more sells)
   double GetNetDirection()
   {
      UpdatePositions();
      if(ArraySize(m_positions) == 0) return 0;
      
      int buyCount = 0;
      int sellCount = 0;
      
      for(int i = 0; i < ArraySize(m_positions); i++)
      {
         if(m_positions[i].type == POSITION_TYPE_BUY)
            buyCount++;
         else
            sellCount++;
      }
      
      return (double)(buyCount - sellCount) / ArraySize(m_positions);
   }
   
   // Hedge positions (open opposite to current net direction)
   bool HedgePositions(double lots)
   {
      double netDir = GetNetDirection();
      
      if(netDir > 0.3) // More buys, hedge with sell
      {
         double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         double sl = NormalizeDouble(price + m_maxSLPips * m_point * 10, m_digits);
         double tp = NormalizeDouble(price - m_maxTPPips * m_point * 10, m_digits);
         return m_trade.Sell(lots, m_symbol, price, sl, tp, "HEDGE");
      }
      else if(netDir < -0.3) // More sells, hedge with buy
      {
         double price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         double sl = NormalizeDouble(price - m_maxSLPips * m_point * 10, m_digits);
         double tp = NormalizeDouble(price + m_maxTPPips * m_point * 10, m_digits);
         return m_trade.Buy(lots, m_symbol, price, sl, tp, "HEDGE");
      }
      
      return false;
   }
   
   // Set TP/SL ranges
   void SetTPSLRanges(double minTP, double maxTP, double minSL, double maxSL)
   {
      m_minTPPips = minTP;
      m_maxTPPips = maxTP;
      m_minSLPips = minSL;
      m_maxSLPips = maxSL;
   }
   
   // Set max positions
   void SetMaxPositions(int max)
   {
      m_maxPositions = max;
   }
};
