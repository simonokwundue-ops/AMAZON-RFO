//+------------------------------------------------------------------+
//|                                  EnhancedPositionManager.mqh     |
//| Enhanced per-position management with intelligent trailing       |
//| and recovery strategies                                           |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>

// Enhanced position info with recovery tracking
struct EnhancedPosition
{
   ulong ticket;
   int type;
   double openPrice;
   double currentPrice;
   double sl;
   double tp;
   double lots;
   double profit;
   datetime openTime;
   int strategyID;           // Which strategy opened this
   
   // Trailing state
   bool trailingActive;
   double highWaterMark;     // Highest profit for BUY
   double lowWaterMark;      // Lowest profit for SELL
   double profitPeakPips;    // Peak profit in pips
   
   // Recovery state
   bool hasHedge;
   ulong hedgeTicket;
   int recoveryAttempts;
};

class CEnhancedPositionManager
{
private:
   CTrade m_trade;
   EnhancedPosition m_positions[];
   string m_symbol;
   double m_point;
   int m_digits;
   int m_maxPositions;
   
   // Trailing configuration
   double m_trailActivationPercent;  // % of TP to activate trailing (default 70%)
   double m_trailBufferPercent;      // % of gained pips to keep as buffer (default 30%)
   double m_minTrailStepPips;        // Minimum trail step
   
   // Dynamic TP/SL settings
   double m_minTPPips;
   double m_maxTPPips;
   double m_minSLPips;
   double m_maxSLPips;
   
public:
   CEnhancedPositionManager(string symbol = "", int maxPos = 3)
   {
      m_symbol = (symbol == "") ? _Symbol : symbol;
      m_maxPositions = maxPos;
      m_point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      
      // Conservative trailing defaults
      m_trailActivationPercent = 0.70;  // Trail only after 70% to TP
      m_trailBufferPercent = 0.30;      // Keep 30% of gained pips as buffer
      m_minTrailStepPips = 3.0;         // Minimum 3 pips per trail
      
      m_minTPPips = 5.0;
      m_maxTPPips = 30.0;
      m_minSLPips = 3.0;
      m_maxSLPips = 20.0;
      
      ArrayResize(m_positions, 0);
   }
   
   // Update all positions from terminal
   void UpdatePositions()
   {
      int oldSize = ArraySize(m_positions);
      ArrayResize(m_positions, 0);
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == m_symbol)
         {
            EnhancedPosition pos;
            pos.ticket = ticket;
            pos.type = (int)PositionGetInteger(POSITION_TYPE);
            pos.openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            pos.currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            pos.sl = PositionGetDouble(POSITION_SL);
            pos.tp = PositionGetDouble(POSITION_TP);
            pos.lots = PositionGetDouble(POSITION_VOLUME);
            pos.profit = PositionGetDouble(POSITION_PROFIT);
            pos.openTime = (datetime)PositionGetInteger(POSITION_TIME);
            
            // Extract strategy ID from comment if possible
            string comment = PositionGetString(POSITION_COMMENT);
            pos.strategyID = 0;
            if(StringFind(comment, "ST") == 0 && StringLen(comment) > 2)
               pos.strategyID = (int)StringToInteger(StringSubstr(comment, 2, 1));
            
            // Initialize trailing state - preserve from previous if exists
            pos.trailingActive = false;
            pos.profitPeakPips = 0;
            pos.hasHedge = false;
            pos.hedgeTicket = 0;
            pos.recoveryAttempts = 0;
            
            // Try to find previous state
            for(int j = 0; j < oldSize; j++)
            {
               if(m_positions[j].ticket == ticket)
               {
                  pos.trailingActive = m_positions[j].trailingActive;
                  pos.highWaterMark = m_positions[j].highWaterMark;
                  pos.lowWaterMark = m_positions[j].lowWaterMark;
                  pos.profitPeakPips = m_positions[j].profitPeakPips;
                  pos.hasHedge = m_positions[j].hasHedge;
                  pos.hedgeTicket = m_positions[j].hedgeTicket;
                  pos.recoveryAttempts = m_positions[j].recoveryAttempts;
                  break;
               }
            }
            
            // Initialize watermarks if new position
            if(pos.type == POSITION_TYPE_BUY)
            {
               if(pos.highWaterMark == 0) pos.highWaterMark = pos.openPrice;
               pos.lowWaterMark = pos.openPrice;
            }
            else
            {
               pos.highWaterMark = pos.openPrice;
               if(pos.lowWaterMark == 0) pos.lowWaterMark = pos.openPrice;
            }
            
            int newSize = ArraySize(m_positions) + 1;
            ArrayResize(m_positions, newSize);
            m_positions[newSize - 1] = pos;
         }
      }
   }
   
   // Intelligent trailing - let winners run, protect profits
   void TrailAllPositions()
   {
      UpdatePositions();
      
      for(int i = 0; i < ArraySize(m_positions); i++)
      {
         TrailPosition(i);
      }
   }
   
   void TrailPosition(int posIndex)
   {
      if(posIndex < 0 || posIndex >= ArraySize(m_positions)) return;
      
      EnhancedPosition pos = m_positions[posIndex];
      if(pos.tp == 0 || pos.sl == 0) return;
      
      double currentProfitPips = 0;
      double targetPips = 0;
      double distanceToTP = 0;
      
      if(pos.type == POSITION_TYPE_BUY)
      {
         currentProfitPips = (pos.currentPrice - pos.openPrice) / (m_point * 10);
         targetPips = (pos.tp - pos.openPrice) / (m_point * 10);
         distanceToTP = (pos.tp - pos.currentPrice) / (m_point * 10);
         
         // Update high water mark
         if(pos.currentPrice > pos.highWaterMark)
         {
            pos.highWaterMark = pos.currentPrice;
            pos.profitPeakPips = currentProfitPips;
         }
      }
      else // SELL
      {
         currentProfitPips = (pos.openPrice - pos.currentPrice) / (m_point * 10);
         targetPips = (pos.openPrice - pos.tp) / (m_point * 10);
         distanceToTP = (pos.currentPrice - pos.tp) / (m_point * 10);
         
         // Update low water mark
         if(pos.currentPrice < pos.lowWaterMark)
         {
            pos.lowWaterMark = pos.currentPrice;
            pos.profitPeakPips = currentProfitPips;
         }
      }
      
      // Only activate trailing after reaching activation threshold
      if(currentProfitPips < targetPips * m_trailActivationPercent)
         return; // Not profitable enough yet
      
      pos.trailingActive = true;
      
      // Calculate how many pips to protect
      // Keep buffer% of the pips gained from activation point
      double activationPips = targetPips * m_trailActivationPercent;
      double gainedPips = pos.profitPeakPips - activationPips;
      double protectPips = activationPips + (gainedPips * (1.0 - m_trailBufferPercent));
      
      // Ensure minimum trail step
      if(protectPips < m_minTrailStepPips)
         protectPips = m_minTrailStepPips;
      
      // Calculate new SL
      double newSL = 0;
      if(pos.type == POSITION_TYPE_BUY)
      {
         newSL = NormalizeDouble(pos.openPrice + protectPips * m_point * 10, m_digits);
         
         // Only move SL up, never down
         if(newSL > pos.sl)
         {
            // Check if extension makes sense - if very close to TP, extend TP
            if(distanceToTP < targetPips * 0.2 && currentProfitPips > targetPips * 0.9)
            {
               // Extend TP by 50% to let winners run
               double newTP = NormalizeDouble(pos.tp + targetPips * 0.5 * m_point * 10, m_digits);
               m_trade.PositionModify(pos.ticket, newSL, newTP);
               Print("♦ Extended TP for winning BUY #", pos.ticket, " to let it run");
            }
            else
            {
               m_trade.PositionModify(pos.ticket, newSL, pos.tp);
            }
         }
      }
      else // SELL
      {
         newSL = NormalizeDouble(pos.openPrice - protectPips * m_point * 10, m_digits);
         
         // Only move SL down, never up
         if(newSL < pos.sl || pos.sl == 0)
         {
            // Check if extension makes sense
            if(distanceToTP < targetPips * 0.2 && currentProfitPips > targetPips * 0.9)
            {
               // Extend TP by 50%
               double newTP = NormalizeDouble(pos.tp - targetPips * 0.5 * m_point * 10, m_digits);
               m_trade.PositionModify(pos.ticket, newSL, newTP);
               Print("♦ Extended TP for winning SELL #", pos.ticket, " to let it run");
            }
            else
            {
               m_trade.PositionModify(pos.ticket, newSL, pos.tp);
            }
         }
      }
   }
   
   // Per-position hedging for recovery
   bool HedgePosition(int posIndex, double hedgeLotRatio = 0.5)
   {
      if(posIndex < 0 || posIndex >= ArraySize(m_positions)) return false;
      if(m_positions[posIndex].hasHedge) return false; // Already hedged
      
      // Get position data (cannot use reference for struct in MQL5)
      double hedgeLots = m_positions[posIndex].lots * hedgeLotRatio;
      
      // Round to valid lot size
      double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      hedgeLots = MathFloor(hedgeLots / lotStep) * lotStep;
      if(hedgeLots < minLot) hedgeLots = minLot;
      
      bool success = false;
      ulong hedgeTicket = 0;
      
      if(m_positions[posIndex].type == POSITION_TYPE_BUY)
      {
         double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         double sl = NormalizeDouble(price + m_maxSLPips * m_point * 10, m_digits);
         double tp = NormalizeDouble(price - m_minTPPips * m_point * 10, m_digits);
         success = m_trade.Sell(hedgeLots, m_symbol, price, sl, tp, "HEDGE-" + IntegerToString(m_positions[posIndex].ticket));
         if(success) hedgeTicket = m_trade.ResultOrder();
      }
      else
      {
         double price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         double sl = NormalizeDouble(price - m_maxSLPips * m_point * 10, m_digits);
         double tp = NormalizeDouble(price + m_minTPPips * m_point * 10, m_digits);
         success = m_trade.Buy(hedgeLots, m_symbol, price, sl, tp, "HEDGE-" + IntegerToString(m_positions[posIndex].ticket));
         if(success) hedgeTicket = m_trade.ResultOrder();
      }
      
      if(success)
      {
         m_positions[posIndex].hasHedge = true;
         m_positions[posIndex].hedgeTicket = hedgeTicket;
         m_positions[posIndex].recoveryAttempts++;
         Print("♦ Hedged position #", m_positions[posIndex].ticket, " with hedge #", hedgeTicket);
      }
      
      return success;
   }
   
   // Open position with strategy tracking
   bool OpenPosition(int direction, double lots, double tpPips, double slPips, int strategyID, string justification = "")
   {
      if(GetPositionCount() >= m_maxPositions) return false;
      
      bool success = false;
      string comment = "ST" + IntegerToString(strategyID);
      
      if(direction > 0) // BUY
      {
         double price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         double sl = NormalizeDouble(price - slPips * m_point * 10, m_digits);
         double tp = NormalizeDouble(price + tpPips * m_point * 10, m_digits);
         success = m_trade.Buy(lots, m_symbol, price, sl, tp, comment);
      }
      else if(direction < 0) // SELL
      {
         double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         double sl = NormalizeDouble(price + slPips * m_point * 10, m_digits);
         double tp = NormalizeDouble(price - tpPips * m_point * 10, m_digits);
         success = m_trade.Sell(lots, m_symbol, price, sl, tp, comment);
      }
      
      if(success)
      {
         Print("✓ Opened ", (direction > 0 ? "BUY" : "SELL"), 
               " | Strategy: ", strategyID,
               " | Lots: ", DoubleToString(lots, 2),
               " | TP: ", DoubleToString(tpPips, 1), " pips",
               " | SL: ", DoubleToString(slPips, 1), " pips");
         if(justification != "")
            Print("  Reason: ", justification);
      }
      
      return success;
   }
   
   // Get position count
   int GetPositionCount()
   {
      UpdatePositions();
      return ArraySize(m_positions);
   }
   
   // Can open new position
   bool CanOpenPosition()
   {
      return GetPositionCount() < m_maxPositions;
   }
   
   // Calculate dynamic TP/SL based on ATR
   void CalculateDynamicTPSL(double atr, double tpMult, double slMult, double &tpPips, double &slPips)
   {
      // Convert ATR to pips
      double atrPips = atr / (m_point * 10);
      
      // Calculate TP/SL
      tpPips = atrPips * tpMult;
      slPips = atrPips * slMult;
      
      // Clamp to ranges
      if(tpPips < m_minTPPips) tpPips = m_minTPPips;
      if(tpPips > m_maxTPPips) tpPips = m_maxTPPips;
      if(slPips < m_minSLPips) slPips = m_minSLPips;
      if(slPips > m_maxSLPips) slPips = m_maxSLPips;
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
   
   // Set trailing parameters
   void SetTrailingConfig(double activationPercent, double bufferPercent, double minStepPips)
   {
      m_trailActivationPercent = activationPercent;
      m_trailBufferPercent = bufferPercent;
      m_minTrailStepPips = minStepPips;
   }
   
   // Get losing positions for recovery
   void GetLosingPositions(int &indices[], double &lossPips[])
   {
      UpdatePositions();
      ArrayResize(indices, 0);
      ArrayResize(lossPips, 0);
      
      for(int i = 0; i < ArraySize(m_positions); i++)
      {
         double profitPips = 0;
         if(m_positions[i].type == POSITION_TYPE_BUY)
            profitPips = (m_positions[i].currentPrice - m_positions[i].openPrice) / (m_point * 10);
         else
            profitPips = (m_positions[i].openPrice - m_positions[i].currentPrice) / (m_point * 10);
         
         if(profitPips < 0)
         {
            int size = ArraySize(indices);
            ArrayResize(indices, size + 1);
            ArrayResize(lossPips, size + 1);
            indices[size] = i;
            lossPips[size] = MathAbs(profitPips);
         }
      }
   }
   
   // Get total profit
   double GetTotalProfit()
   {
      UpdatePositions();
      double total = 0;
      for(int i = 0; i < ArraySize(m_positions); i++)
         total += m_positions[i].profit;
      return total;
   }
   
   // Close all positions
   void CloseAllPositions()
   {
      UpdatePositions();
      for(int i = ArraySize(m_positions) - 1; i >= 0; i--)
         m_trade.PositionClose(m_positions[i].ticket);
   }
};
