//+------------------------------------------------------------------+
//|                                   SessionBreakoutStrategy.mqh     |
//|                     Time-Gated Session Breakout Strategy          |
//+------------------------------------------------------------------+
#include "SignalGrid.mqh"

class CSessionBreakoutStrategy : public CStrategy
{
private:
   int m_handleATR;
   int m_sessionStartHour;
   int m_sessionEndHour;
   int m_sessionStartMinute;
   int m_sessionEndMinute;
   
public:
   CSessionBreakoutStrategy() : CStrategy("Session Breakout", 5)
   {
      m_handleATR = INVALID_HANDLE;
      
      // London open window: 08:00-10:30
      m_sessionStartHour = 8;
      m_sessionStartMinute = 0;
      m_sessionEndHour = 10;
      m_sessionEndMinute = 30;
      
      // Can work in any regime but time-gated
      string regimes[4];
      regimes[0] = "TREND";
      regimes[1] = "REVERSAL";
      regimes[2] = "RANGE";
      regimes[3] = "VOLATILE";
      SetAllowedRegimes(regimes);
   }
   
   ~CSessionBreakoutStrategy()
   {
      if(m_handleATR != INVALID_HANDLE) IndicatorRelease(m_handleATR);
   }
   
   bool Init(string symbol, ENUM_TIMEFRAMES tf)
   {
      m_handleATR = iATR(symbol, tf, 14);
      
      return (m_handleATR != INVALID_HANDLE);
   }
   
   virtual Signal Analyze(string symbol, ENUM_TIMEFRAMES tf, string currentRegime) override
   {
      Signal sig;
      sig.isValid = false;
      sig.strategyID = m_id;
      sig.strategyName = m_name;
      sig.symbol = symbol;
      sig.timestamp = TimeCurrent();
      sig.score = 0.0;
      
      // Check if within session window
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      int currentMinutes = dt.hour * 60 + dt.min;
      int sessionStartMinutes = m_sessionStartHour * 60 + m_sessionStartMinute;
      int sessionEndMinutes = m_sessionEndHour * 60 + m_sessionEndMinute;
      
      if(currentMinutes < sessionStartMinutes || currentMinutes > sessionEndMinutes)
         return sig; // Outside session window
      
      // Get data
      double atr[], close[], high[], low[], open[];
      ArraySetAsSeries(atr, true);
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(open, true);
      
      if(CopyBuffer(m_handleATR, 0, 0, 20, atr) < 20) return sig;
      if(CopyClose(symbol, tf, 0, 20, close) < 20) return sig;
      if(CopyHigh(symbol, tf, 0, 20, high) < 20) return sig;
      if(CopyLow(symbol, tf, 0, 20, low) < 20) return sig;
      if(CopyOpen(symbol, tf, 0, 20, open) < 20) return sig;
      
      double score = 0.0;
      sig.justification = "Session Breakout: ";
      
      // Condition 1: Within session window (already checked) (0.20)
      score += 0.20;
      sig.justification += "London session ";
      
      // Condition 2: Volatility surge (ATR spike) (0.30)
      double atrAvg = 0;
      for(int i = 5; i < 20; i++)
         atrAvg += atr[i];
      atrAvg /= 15;
      
      bool volSurge = (atr[0] > atrAvg * 1.3);
      if(volSurge)
      {
         score += 0.30;
         sig.justification += "+ vol surge ";
      }
      
      // Condition 3: Breakout from recent range (0.25)
      // Find highest high and lowest low of last 10 bars
      double rangeHigh = high[1];
      double rangeLow = low[1];
      for(int i = 2; i < 12; i++)
      {
         if(high[i] > rangeHigh) rangeHigh = high[i];
         if(low[i] < rangeLow) rangeLow = low[i];
      }
      
      bool breakoutUp = (close[0] > rangeHigh);
      bool breakoutDown = (close[0] < rangeLow);
      
      if(breakoutUp)
      {
         score += 0.25;
         sig.direction = 1;
         sig.justification += "+ upward break ";
      }
      else if(breakoutDown)
      {
         score += 0.25;
         sig.direction = -1;
         sig.justification += "+ downward break ";
      }
      else
         return sig; // No breakout
      
      // Condition 4: Strong momentum candle (0.15)
      double candleBody = MathAbs(close[0] - open[0]);
      double candleRange = high[0] - low[0];
      
      if(candleRange > 0 && (candleBody / candleRange) > 0.7) // Strong body
      {
         score += 0.15;
         sig.justification += "+ strong candle ";
      }
      
      // Condition 5: Gap from previous close (0.10)
      bool gap = false;
      if(sig.direction == 1 && open[0] > close[1])
      {
         gap = true;
      }
      else if(sig.direction == -1 && open[0] < close[1])
      {
         gap = true;
      }
      
      if(gap)
      {
         score += 0.10;
         sig.justification += "+ gap";
      }
      
      sig.score = score;
      
      // Calculate SL/TP - tight for session breakout
      double atrValue = atr[0];
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      sig.slPips = (atrValue * 1.0) / (point * 10); // 1.0 ATR for SL (tight)
      sig.tpPips = (atrValue * 2.0) / (point * 10); // 2.0 ATR for TP
      
      // Ensure within reasonable bounds
      sig.slPips = MathMax(5, MathMin(sig.slPips, 20));
      sig.tpPips = MathMax(8, MathMin(sig.tpPips, 40));
      
      sig.isValid = true;
      
      return sig;
   }
   
   void SetSessionWindow(int startHour, int startMin, int endHour, int endMin)
   {
      m_sessionStartHour = startHour;
      m_sessionStartMinute = startMin;
      m_sessionEndHour = endHour;
      m_sessionEndMinute = endMin;
   }
};
