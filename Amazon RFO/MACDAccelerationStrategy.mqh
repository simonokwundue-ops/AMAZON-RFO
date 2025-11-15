//+------------------------------------------------------------------+
//|                                    MACDAccelerationStrategy.mqh   |
//|                     MACD Acceleration/Burst Strategy              |
//+------------------------------------------------------------------+
#include "SignalGrid.mqh"

class CMACDAccelerationStrategy : public CStrategy
{
private:
   int m_handleMACD;
   int m_handleATR;
   
public:
   CMACDAccelerationStrategy() : CStrategy("MACD Acceleration", 4)
   {
      m_handleMACD = INVALID_HANDLE;
      m_handleATR = INVALID_HANDLE;
      
      // Allowed in TREND or VOLATILE regimes
      string regimes[2];
      regimes[0] = "TREND";
      regimes[1] = "VOLATILE";
      SetAllowedRegimes(regimes);
   }
   
   ~CMACDAccelerationStrategy()
   {
      if(m_handleMACD != INVALID_HANDLE) IndicatorRelease(m_handleMACD);
      if(m_handleATR != INVALID_HANDLE) IndicatorRelease(m_handleATR);
   }
   
   bool Init(string symbol, ENUM_TIMEFRAMES tf)
   {
      m_handleMACD = iMACD(symbol, tf, 12, 26, 9, PRICE_CLOSE);
      m_handleATR = iATR(symbol, tf, 14);
      
      return (m_handleMACD != INVALID_HANDLE && m_handleATR != INVALID_HANDLE);
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
      
      // Only in TREND or VOLATILE regimes
      if(currentRegime != "TREND" && currentRegime != "VOLATILE") return sig;
      
      // Get data
      double macdMain[], macdSignal[], macdHist[], atr[], close[];
      ArraySetAsSeries(macdMain, true);
      ArraySetAsSeries(macdSignal, true);
      ArraySetAsSeries(macdHist, true);
      ArraySetAsSeries(atr, true);
      ArraySetAsSeries(close, true);
      
      if(CopyBuffer(m_handleMACD, 0, 0, 10, macdMain) < 10) return sig;
      if(CopyBuffer(m_handleMACD, 1, 0, 10, macdSignal) < 10) return sig;
      if(CopyBuffer(m_handleMACD, 2, 0, 10, macdHist) < 10) return sig;
      if(CopyBuffer(m_handleATR, 0, 0, 3, atr) < 3) return sig;
      if(CopyClose(symbol, tf, 0, 10, close) < 10) return sig;
      
      double score = 0.0;
      sig.justification = "MACD Accel: ";
      
      // Determine direction from histogram
      if(macdHist[0] > 0)
         sig.direction = 1;
      else if(macdHist[0] < 0)
         sig.direction = -1;
      else
         return sig;
      
      // Condition 1: Fast/slow line separation increasing (0.25)
      double separation = MathAbs(macdMain[0] - macdSignal[0]);
      double prevSeparation = MathAbs(macdMain[1] - macdSignal[1]);
      
      if(separation > prevSeparation * 1.1) // Separating by at least 10%
      {
         score += 0.25;
         sig.justification += "Line separation ";
      }
      
      // Condition 2: Histogram burst (expanding rapidly) (0.30)
      double histChange = MathAbs(macdHist[0]) - MathAbs(macdHist[1]);
      double avgHistChange = 0;
      for(int i = 1; i < 5; i++)
         avgHistChange += MathAbs(MathAbs(macdHist[i]) - MathAbs(macdHist[i+1]));
      avgHistChange /= 4;
      
      if(histChange > avgHistChange * 1.5) // Burst is 50% above average
      {
         score += 0.30;
         sig.justification += "+ histogram burst ";
      }
      
      // Condition 3: MACD main line crossed signal recently (0.20)
      bool recentCross = false;
      for(int i = 1; i < 4; i++)
      {
         if((macdMain[i] > macdSignal[i] && macdMain[i+1] <= macdSignal[i+1] && sig.direction == 1) ||
            (macdMain[i] < macdSignal[i] && macdMain[i+1] >= macdSignal[i+1] && sig.direction == -1))
         {
            recentCross = true;
            break;
         }
      }
      
      if(recentCross)
      {
         score += 0.20;
         sig.justification += "+ recent cross ";
      }
      
      // Condition 4: Histogram accelerating (consecutive increases) (0.15)
      bool accelerating = false;
      if(sig.direction == 1)
      {
         if(macdHist[0] > macdHist[1] && macdHist[1] > macdHist[2])
            accelerating = true;
      }
      else
      {
         if(macdHist[0] < macdHist[1] && macdHist[1] < macdHist[2])
            accelerating = true;
      }
      
      if(accelerating)
      {
         score += 0.15;
         sig.justification += "+ accelerating ";
      }
      
      // Condition 5: Price momentum aligned (0.10)
      if((sig.direction == 1 && close[0] > close[1] && close[1] > close[2]) ||
         (sig.direction == -1 && close[0] < close[1] && close[1] < close[2]))
      {
         score += 0.10;
         sig.justification += "+ price momentum";
      }
      
      sig.score = score;
      
      // Calculate SL/TP based on ATR - tighter for fast moves
      double atrValue = atr[0];
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      sig.slPips = (atrValue * 1.2) / (point * 10); // 1.2 ATR for SL
      sig.tpPips = (atrValue * 2.5) / (point * 10); // 2.5 ATR for TP
      
      // Use trailing logic for this strategy (will be implemented in position manager)
      
      // Ensure within reasonable bounds
      sig.slPips = MathMax(5, MathMin(sig.slPips, 25));
      sig.tpPips = MathMax(10, MathMin(sig.tpPips, 50));
      
      sig.isValid = true;
      
      return sig;
   }
};
