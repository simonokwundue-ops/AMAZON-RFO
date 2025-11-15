//+------------------------------------------------------------------+
//|                                    CandlePatternStrategy.mqh      |
//|                     Candle Pattern Recognition Strategy           |
//+------------------------------------------------------------------+
#include "SignalGrid.mqh"

class CCandlePatternStrategy : public CStrategy
{
private:
   int m_handleATR;
   
public:
   CCandlePatternStrategy() : CStrategy("Candle Patterns", 6)
   {
      m_handleATR = INVALID_HANDLE;
      
      // Works in all regimes
      string regimes[4];
      regimes[0] = "TREND";
      regimes[1] = "REVERSAL";
      regimes[2] = "RANGE";
      regimes[3] = "VOLATILE";
      SetAllowedRegimes(regimes);
   }
   
   ~CCandlePatternStrategy()
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
      
      // Get data
      double atr[], close[], high[], low[], open[];
      ArraySetAsSeries(atr, true);
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(open, true);
      
      if(CopyBuffer(m_handleATR, 0, 0, 3, atr) < 3) return sig;
      if(CopyClose(symbol, tf, 0, 10, close) < 10) return sig;
      if(CopyHigh(symbol, tf, 0, 10, high) < 10) return sig;
      if(CopyLow(symbol, tf, 0, 10, low) < 10) return sig;
      if(CopyOpen(symbol, tf, 0, 10, open) < 10) return sig;
      
      double score = 0.0;
      sig.justification = "Candle Pattern: ";
      
      // Detect patterns
      bool engulfingBullish = DetectBullishEngulfing(open, close, high, low);
      bool engulfingBearish = DetectBearishEngulfing(open, close, high, low);
      bool pinBarBullish = DetectBullishPinBar(open, close, high, low);
      bool pinBarBearish = DetectBearishPinBar(open, close, high, low);
      bool dojiReversal = DetectDojiReversal(open, close, high, low);
      
      // Condition 1: Pattern detected (0.35)
      if(engulfingBullish)
      {
         score += 0.35;
         sig.direction = 1;
         sig.justification += "Bullish engulfing ";
      }
      else if(engulfingBearish)
      {
         score += 0.35;
         sig.direction = -1;
         sig.justification += "Bearish engulfing ";
      }
      else if(pinBarBullish)
      {
         score += 0.30;
         sig.direction = 1;
         sig.justification += "Bullish pin bar ";
      }
      else if(pinBarBearish)
      {
         score += 0.30;
         sig.direction = -1;
         sig.justification += "Bearish pin bar ";
      }
      else if(dojiReversal)
      {
         // Doji needs context - check previous trend
         if(close[1] > close[3]) // Was uptrend
         {
            score += 0.25;
            sig.direction = -1;
            sig.justification += "Doji reversal (from up) ";
         }
         else // Was downtrend
         {
            score += 0.25;
            sig.direction = 1;
            sig.justification += "Doji reversal (from down) ";
         }
      }
      else
         return sig; // No pattern found
      
      // Condition 2: Proximity to key level (support/resistance) (0.25)
      // Simple S/R: recent swing highs/lows
      double swingHigh = high[1];
      double swingLow = low[1];
      for(int i = 2; i < 10; i++)
      {
         if(high[i] > swingHigh) swingHigh = high[i];
         if(low[i] < swingLow) swingLow = low[i];
      }
      
      double distToSwingHigh = MathAbs(close[0] - swingHigh) / swingHigh;
      double distToSwingLow = MathAbs(close[0] - swingLow) / swingLow;
      
      if(distToSwingHigh < 0.003 || distToSwingLow < 0.003) // Within 0.3%
      {
         score += 0.25;
         sig.justification += "+ near key level ";
      }
      
      // Condition 3: Volume/range confirmation (0.20)
      double currentRange = high[0] - low[0];
      double avgRange = 0;
      for(int i = 1; i < 6; i++)
         avgRange += (high[i] - low[i]);
      avgRange /= 5;
      
      if(currentRange > avgRange * 1.2) // Above average range
      {
         score += 0.20;
         sig.justification += "+ large range ";
      }
      
      // Condition 4: Pattern quality (body/wick ratios) (0.15)
      double patternQuality = CalculatePatternQuality(open, close, high, low);
      if(patternQuality > 0.7)
      {
         score += 0.15;
         sig.justification += "+ quality pattern ";
      }
      
      // Condition 5: No conflicting recent pattern (0.05)
      bool noConflict = !DetectConflictingPattern(open, close, high, low, sig.direction);
      if(noConflict)
      {
         score += 0.05;
         sig.justification += "+ no conflict";
      }
      
      sig.score = score;
      
      // Calculate SL/TP based on pattern size
      double atrValue = atr[0];
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      sig.slPips = (atrValue * 1.5) / (point * 10); // 1.5 ATR for SL
      sig.tpPips = (atrValue * 2.5) / (point * 10); // 2.5 ATR for TP
      
      // Ensure within reasonable bounds
      sig.slPips = MathMax(5, MathMin(sig.slPips, 25));
      sig.tpPips = MathMax(10, MathMin(sig.tpPips, 50));
      
      sig.isValid = true;
      
      return sig;
   }
   
private:
   bool DetectBullishEngulfing(const double &o[], const double &c[], const double &h[], const double &l[])
   {
      return (c[1] < o[1] && c[0] > o[0] && c[0] > o[1] && o[0] < c[1]);
   }
   
   bool DetectBearishEngulfing(const double &o[], const double &c[], const double &h[], const double &l[])
   {
      return (c[1] > o[1] && c[0] < o[0] && c[0] < o[1] && o[0] > c[1]);
   }
   
   bool DetectBullishPinBar(const double &o[], const double &c[], const double &h[], const double &l[])
   {
      double body = MathAbs(c[0] - o[0]);
      double lowerWick = MathMin(c[0], o[0]) - l[0];
      double upperWick = h[0] - MathMax(c[0], o[0]);
      
      return (lowerWick > body * 2 && upperWick < body && c[0] > o[0]);
   }
   
   bool DetectBearishPinBar(const double &o[], const double &c[], const double &h[], const double &l[])
   {
      double body = MathAbs(c[0] - o[0]);
      double lowerWick = MathMin(c[0], o[0]) - l[0];
      double upperWick = h[0] - MathMax(c[0], o[0]);
      
      return (upperWick > body * 2 && lowerWick < body && c[0] < o[0]);
   }
   
   bool DetectDojiReversal(const double &o[], const double &c[], const double &h[], const double &l[])
   {
      double body = MathAbs(c[0] - o[0]);
      double range = h[0] - l[0];
      
      return (range > 0 && body / range < 0.1); // Body less than 10% of range
   }
   
   double CalculatePatternQuality(const double &o[], const double &c[], const double &h[], const double &l[])
   {
      double body = MathAbs(c[0] - o[0]);
      double range = h[0] - l[0];
      
      if(range == 0) return 0;
      
      return body / range; // Higher is better for most patterns
   }
   
   bool DetectConflictingPattern(const double &o[], const double &c[], const double &h[], const double &l[], int direction)
   {
      // Check if previous 2 candles suggest opposite direction
      bool prevBullish = (c[1] > o[1] && c[2] > o[2]);
      bool prevBearish = (c[1] < o[1] && c[2] < o[2]);
      
      if(direction == 1 && prevBearish) return true;
      if(direction == -1 && prevBullish) return true;
      
      return false;
   }
};
