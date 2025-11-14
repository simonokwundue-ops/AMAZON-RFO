//+------------------------------------------------------------------+
//|                                         BBFadeStrategy.mqh        |
//|                     Bollinger Band Fade Strategy                  |
//+------------------------------------------------------------------+
#include "SignalGrid.mqh"

class CBBFadeStrategy : public CStrategy
{
private:
   int m_handleBB;
   int m_handleATR;
   
public:
   CBBFadeStrategy() : CStrategy("BB Fade", 3)
   {
      m_handleBB = INVALID_HANDLE;
      m_handleATR = INVALID_HANDLE;
      
      // Only allowed in RANGE regime
      string regimes[1];
      regimes[0] = "RANGE";
      SetAllowedRegimes(regimes);
   }
   
   ~CBBFadeStrategy()
   {
      if(m_handleBB != INVALID_HANDLE) IndicatorRelease(m_handleBB);
      if(m_handleATR != INVALID_HANDLE) IndicatorRelease(m_handleATR);
   }
   
   bool Init(string symbol, ENUM_TIMEFRAMES tf)
   {
      m_handleBB = iBands(symbol, tf, 20, 0, 2.0, PRICE_CLOSE);
      m_handleATR = iATR(symbol, tf, 14);
      
      return (m_handleBB != INVALID_HANDLE && m_handleATR != INVALID_HANDLE);
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
      
      // Only in RANGE regime
      if(currentRegime != "RANGE") return sig;
      
      // Get data
      double bbUpper[], bbMiddle[], bbLower[], atr[], close[], high[], low[], open[];
      ArraySetAsSeries(bbUpper, true);
      ArraySetAsSeries(bbMiddle, true);
      ArraySetAsSeries(bbLower, true);
      ArraySetAsSeries(atr, true);
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(open, true);
      
      if(CopyBuffer(m_handleBB, 0, 0, 10, bbUpper) < 10) return sig;
      if(CopyBuffer(m_handleBB, 1, 0, 10, bbMiddle) < 10) return sig;
      if(CopyBuffer(m_handleBB, 2, 0, 10, bbLower) < 10) return sig;
      if(CopyBuffer(m_handleATR, 0, 0, 3, atr) < 3) return sig;
      if(CopyClose(symbol, tf, 0, 10, close) < 10) return sig;
      if(CopyHigh(symbol, tf, 0, 10, high) < 10) return sig;
      if(CopyLow(symbol, tf, 0, 10, low) < 10) return sig;
      if(CopyOpen(symbol, tf, 0, 10, open) < 10) return sig;
      
      double score = 0.0;
      sig.justification = "BB Fade: ";
      
      // Condition 1: Price pierces outer band (0.30)
      bool piercedUpper = (close[0] > bbUpper[0] || high[0] > bbUpper[0]);
      bool piercedLower = (close[0] < bbLower[0] || low[0] < bbLower[0]);
      
      if(piercedLower)
      {
         score += 0.30;
         sig.direction = 1; // Fade down = buy
         sig.justification += "Lower band pierce ";
      }
      else if(piercedUpper)
      {
         score += 0.30;
         sig.direction = -1; // Fade up = sell
         sig.justification += "Upper band pierce ";
      }
      else
         return sig; // Must pierce band
      
      // Condition 2: BB squeeze (tight bands) (0.25)
      double bbWidth = (bbUpper[0] - bbLower[0]) / bbMiddle[0];
      double avgWidth = 0;
      for(int i = 1; i < 10; i++)
         avgWidth += (bbUpper[i] - bbLower[i]) / bbMiddle[i];
      avgWidth /= 9;
      
      if(bbWidth < avgWidth * 0.8) // Currently tighter than average
      {
         score += 0.25;
         sig.justification += "+ squeeze ";
      }
      
      // Condition 3: Candle type - rejection candle (0.20)
      double bodySize = MathAbs(close[0] - open[0]);
      double upperWick = high[0] - MathMax(close[0], open[0]);
      double lowerWick = MathMin(close[0], open[0]) - low[0];
      
      if(sig.direction == 1 && lowerWick > bodySize * 1.5) // Lower rejection
      {
         score += 0.20;
         sig.justification += "+ rejection wick ";
      }
      else if(sig.direction == -1 && upperWick > bodySize * 1.5) // Upper rejection
      {
         score += 0.20;
         sig.justification += "+ rejection wick ";
      }
      
      // Condition 4: Flat volatility (low ATR) (0.15)
      double atrAvg = 0;
      for(int i = 1; i < 10; i++)
         atrAvg += atr[i];
      atrAvg /= 9;
      
      if(atr[0] < atrAvg * 1.1) // Not spiking
      {
         score += 0.15;
         sig.justification += "+ flat vol ";
      }
      
      // Condition 5: Proximity to band edge (0.10)
      double distFromBand = 0;
      if(sig.direction == 1)
         distFromBand = MathAbs(close[0] - bbLower[0]) / bbLower[0];
      else
         distFromBand = MathAbs(close[0] - bbUpper[0]) / bbUpper[0];
      
      if(distFromBand < 0.002) // Very close to band
      {
         score += 0.10;
         sig.justification += "+ at band";
      }
      
      sig.score = score;
      
      // Calculate SL/TP based on ATR and BB width
      double atrValue = atr[0];
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      // Tighter SL/TP for range trading
      sig.slPips = (atrValue * 1.0) / (point * 10); // 1.0 ATR for SL
      sig.tpPips = (atrValue * 2.0) / (point * 10); // 2.0 ATR for TP
      
      // Ensure within reasonable bounds
      sig.slPips = MathMax(5, MathMin(sig.slPips, 20));
      sig.tpPips = MathMax(8, MathMin(sig.tpPips, 40));
      
      sig.isValid = true;
      
      return sig;
   }
};
