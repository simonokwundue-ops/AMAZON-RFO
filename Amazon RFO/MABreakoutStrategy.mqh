//+------------------------------------------------------------------+
//|                                        MABreakoutStrategy.mqh     |
//|                     Moving Average Breakout Strategy              |
//+------------------------------------------------------------------+
#include "SignalGrid.mqh"

class CMABreakoutStrategy : public CStrategy
{
private:
   int m_handleMA;
   int m_handleATR;
   int m_maPeriod;
   
public:
   CMABreakoutStrategy() : CStrategy("MA Breakout", 1)
   {
      m_maPeriod = 50;
      m_handleMA = INVALID_HANDLE;
      m_handleATR = INVALID_HANDLE;
      
      // Only allowed in TREND regime
      string regimes[1];
      regimes[0] = "TREND";
      SetAllowedRegimes(regimes);
   }
   
   ~CMABreakoutStrategy()
   {
      if(m_handleMA != INVALID_HANDLE) IndicatorRelease(m_handleMA);
      if(m_handleATR != INVALID_HANDLE) IndicatorRelease(m_handleATR);
   }
   
   bool Init(string symbol, ENUM_TIMEFRAMES tf)
   {
      m_handleMA = iMA(symbol, tf, m_maPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_handleATR = iATR(symbol, tf, 14);
      
      return (m_handleMA != INVALID_HANDLE && m_handleATR != INVALID_HANDLE);
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
      
      // Only in TREND regime
      if(currentRegime != "TREND") return sig;
      
      // Get data
      double ma[], atr[], close[], high[], low[];
      ArraySetAsSeries(ma, true);
      ArraySetAsSeries(atr, true);
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      
      if(CopyBuffer(m_handleMA, 0, 0, 5, ma) < 5) return sig;
      if(CopyBuffer(m_handleATR, 0, 0, 3, atr) < 3) return sig;
      if(CopyClose(symbol, tf, 0, 5, close) < 5) return sig;
      if(CopyHigh(symbol, tf, 0, 5, high) < 5) return sig;
      if(CopyLow(symbol, tf, 0, 5, low) < 5) return sig;
      
      // Detect crossover
      bool bullishCross = (close[1] < ma[1] && close[0] > ma[0]);
      bool bearishCross = (close[1] > ma[1] && close[0] < ma[0]);
      
      if(!bullishCross && !bearishCross) return sig;
      
      // Build score
      double score = 0.0;
      sig.justification = "MA Breakout: ";
      
      // Condition 1: Price crossed MA (0.25)
      if(bullishCross)
      {
         score += 0.25;
         sig.direction = 1;
         sig.justification += "Bullish cross ";
      }
      else
      {
         score += 0.25;
         sig.direction = -1;
         sig.justification += "Bearish cross ";
      }
      
      // Condition 2: Trend confirmation - price momentum (0.20)
      bool strongMomentum = false;
      if(sig.direction == 1 && close[0] > close[1] && close[1] > close[2])
      {
         score += 0.20;
         strongMomentum = true;
         sig.justification += "+ momentum ";
      }
      else if(sig.direction == -1 && close[0] < close[1] && close[1] < close[2])
      {
         score += 0.20;
         strongMomentum = true;
         sig.justification += "+ momentum ";
      }
      
      // Condition 3: Distance from MA not too far (0.15)
      double distance = MathAbs(close[0] - ma[0]) / ma[0];
      if(distance < 0.005) // Within 0.5%
      {
         score += 0.15;
         sig.justification += "+ near MA ";
      }
      
      // Condition 4: Candle strength (0.20)
      double candleBody = MathAbs(close[0] - close[1]);
      double candleRange = high[0] - low[0];
      if(candleRange > 0 && (candleBody / candleRange) > 0.6) // Strong candle
      {
         score += 0.20;
         sig.justification += "+ strong candle ";
      }
      
      // Condition 5: No recent false breaks (0.20)
      bool noFalseBreak = true;
      for(int i = 2; i < 5; i++)
      {
         if((close[i] > ma[i] && close[i-1] < ma[i-1]) || 
            (close[i] < ma[i] && close[i-1] > ma[i-1]))
         {
            noFalseBreak = false;
            break;
         }
      }
      if(noFalseBreak)
      {
         score += 0.20;
         sig.justification += "+ clean break";
      }
      
      sig.score = score;
      
      // Calculate SL/TP based on ATR
      double atrValue = atr[0];
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      sig.slPips = (atrValue * 1.5) / (point * 10); // 1.5 ATR for SL
      sig.tpPips = (atrValue * 3.0) / (point * 10); // 3.0 ATR for TP (1:2 R:R)
      
      // Ensure within reasonable bounds
      sig.slPips = MathMax(5, MathMin(sig.slPips, 30));
      sig.tpPips = MathMax(10, MathMin(sig.tpPips, 60));
      
      sig.isValid = true;
      
      return sig;
   }
};
