//+------------------------------------------------------------------+
//|                                      RSIDivergenceStrategy.mqh    |
//|                     RSI Divergence Reversal Strategy              |
//+------------------------------------------------------------------+
#include "SignalGrid.mqh"

class CRSIDivergenceStrategy : public CStrategy
{
private:
   int m_handleRSI;
   int m_handleATR;
   
public:
   CRSIDivergenceStrategy() : CStrategy("RSI Divergence", 2)
   {
      m_handleRSI = INVALID_HANDLE;
      m_handleATR = INVALID_HANDLE;
      
      // Only allowed in REVERSAL regime
      string regimes[1];
      regimes[0] = "REVERSAL";
      SetAllowedRegimes(regimes);
   }
   
   ~CRSIDivergenceStrategy()
   {
      if(m_handleRSI != INVALID_HANDLE) IndicatorRelease(m_handleRSI);
      if(m_handleATR != INVALID_HANDLE) IndicatorRelease(m_handleATR);
   }
   
   bool Init(string symbol, ENUM_TIMEFRAMES tf)
   {
      m_handleRSI = iRSI(symbol, tf, 14, PRICE_CLOSE);
      m_handleATR = iATR(symbol, tf, 14);
      
      return (m_handleRSI != INVALID_HANDLE && m_handleATR != INVALID_HANDLE);
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
      
      // Only in REVERSAL regime
      if(currentRegime != "REVERSAL") return sig;
      
      // Get data
      double rsi[], atr[], close[], high[], low[], open[];
      ArraySetAsSeries(rsi, true);
      ArraySetAsSeries(atr, true);
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(open, true);
      
      if(CopyBuffer(m_handleRSI, 0, 0, 10, rsi) < 10) return sig;
      if(CopyBuffer(m_handleATR, 0, 0, 3, atr) < 3) return sig;
      if(CopyClose(symbol, tf, 0, 10, close) < 10) return sig;
      if(CopyHigh(symbol, tf, 0, 10, high) < 10) return sig;
      if(CopyLow(symbol, tf, 0, 10, low) < 10) return sig;
      if(CopyOpen(symbol, tf, 0, 10, open) < 10) return sig;
      
      // Check for divergence and conditions
      double score = 0.0;
      sig.justification = "RSI Divergence: ";
      
      // Condition 1: Oversold/Overbought (0.25)
      bool oversold = (rsi[0] < 30);
      bool overbought = (rsi[0] > 70);
      
      if(oversold)
      {
         score += 0.25;
         sig.direction = 1;
         sig.justification += "Oversold ";
      }
      else if(overbought)
      {
         score += 0.25;
         sig.direction = -1;
         sig.justification += "Overbought ";
      }
      else
         return sig; // Must be OB/OS
      
      // Condition 2: Divergence detection (0.30)
      bool bullishDiv = false;
      bool bearishDiv = false;
      
      // Find recent swing points (last 5-10 bars)
      int swingIdx1 = -1, swingIdx2 = -1;
      for(int i = 2; i < 8; i++)
      {
         if(sig.direction == 1) // Looking for bullish divergence (lower lows in price, higher lows in RSI)
         {
            if(low[i] < low[i-1] && low[i] < low[i+1])
            {
               if(swingIdx1 < 0) swingIdx1 = i;
               else if(swingIdx2 < 0) { swingIdx2 = i; break; }
            }
         }
         else // Looking for bearish divergence (higher highs in price, lower highs in RSI)
         {
            if(high[i] > high[i-1] && high[i] > high[i+1])
            {
               if(swingIdx1 < 0) swingIdx1 = i;
               else if(swingIdx2 < 0) { swingIdx2 = i; break; }
            }
         }
      }
      
      if(swingIdx1 > 0 && swingIdx2 > 0)
      {
         if(sig.direction == 1) // Bullish divergence
         {
            if(low[0] < low[swingIdx1] && rsi[0] > rsi[swingIdx1])
            {
               bullishDiv = true;
               score += 0.30;
               sig.justification += "+ bullish div ";
            }
         }
         else // Bearish divergence
         {
            if(high[0] > high[swingIdx1] && rsi[0] < rsi[swingIdx1])
            {
               bearishDiv = true;
               score += 0.30;
               sig.justification += "+ bearish div ";
            }
         }
      }
      
      // Condition 3: Reversal candle pattern (0.25)
      double bodySize = MathAbs(close[0] - open[0]);
      double upperWick = high[0] - MathMax(close[0], open[0]);
      double lowerWick = MathMin(close[0], open[0]) - low[0];
      double totalRange = high[0] - low[0];
      
      bool reversalCandle = false;
      if(sig.direction == 1 && lowerWick > bodySize * 2 && close[0] > open[0]) // Hammer
      {
         reversalCandle = true;
         score += 0.25;
         sig.justification += "+ hammer ";
      }
      else if(sig.direction == -1 && upperWick > bodySize * 2 && close[0] < open[0]) // Shooting star
      {
         reversalCandle = true;
         score += 0.25;
         sig.justification += "+ shooting star ";
      }
      
      // Condition 4: RSI turning (0.15)
      if((sig.direction == 1 && rsi[0] > rsi[1] && rsi[1] < rsi[2]) ||
         (sig.direction == -1 && rsi[0] < rsi[1] && rsi[1] > rsi[2]))
      {
         score += 0.15;
         sig.justification += "+ RSI turn ";
      }
      
      // Condition 5: Volume/momentum confirmation (0.05)
      if(sig.direction == 1 && close[0] > open[0])
      {
         score += 0.05;
         sig.justification += "+ bullish close";
      }
      else if(sig.direction == -1 && close[0] < open[0])
      {
         score += 0.05;
         sig.justification += "+ bearish close";
      }
      
      sig.score = score;
      
      // Calculate SL/TP based on ATR
      double atrValue = atr[0];
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      sig.slPips = (atrValue * 1.5) / (point * 10); // 1.5 ATR for SL
      sig.tpPips = (atrValue * 2.5) / (point * 10); // 2.5 ATR for TP
      
      // Ensure within reasonable bounds
      sig.slPips = MathMax(5, MathMin(sig.slPips, 25));
      sig.tpPips = MathMax(8, MathMin(sig.tpPips, 50));
      
      sig.isValid = true;
      
      return sig;
   }
};
