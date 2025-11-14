//+------------------------------------------------------------------+
//|                                         RegimeDetector.mqh        |
//|                     Market Regime Detection Engine                |
//+------------------------------------------------------------------+

enum ENUM_REGIME
{
   REGIME_TREND,          // Trend
   REGIME_REVERSAL,       // Reversal Zone
   REGIME_RANGE,          // Ranging
   REGIME_VOLATILE        // Volatile Burst
};

class CRegimeDetector
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_tf;
   datetime m_lastUpdate;
   int m_updateInterval;  // seconds
   
   ENUM_REGIME m_currentRegime;
   double m_regimeStrength;
   
   // Indicator handles
   int m_handleEMA50;
   int m_handleEMA200;
   int m_handleADX;
   int m_handleATR;
   int m_handleBB;
   int m_handleRSI;
   
public:
   CRegimeDetector()
   {
      m_symbol = _Symbol;
      m_tf = PERIOD_M15;
      m_updateInterval = 900; // 15 minutes
      m_currentRegime = REGIME_RANGE;
      m_regimeStrength = 0.5;
      m_lastUpdate = 0;
      
      m_handleEMA50 = INVALID_HANDLE;
      m_handleEMA200 = INVALID_HANDLE;
      m_handleADX = INVALID_HANDLE;
      m_handleATR = INVALID_HANDLE;
      m_handleBB = INVALID_HANDLE;
      m_handleRSI = INVALID_HANDLE;
   }
   
   ~CRegimeDetector()
   {
      if(m_handleEMA50 != INVALID_HANDLE) IndicatorRelease(m_handleEMA50);
      if(m_handleEMA200 != INVALID_HANDLE) IndicatorRelease(m_handleEMA200);
      if(m_handleADX != INVALID_HANDLE) IndicatorRelease(m_handleADX);
      if(m_handleATR != INVALID_HANDLE) IndicatorRelease(m_handleATR);
      if(m_handleBB != INVALID_HANDLE) IndicatorRelease(m_handleBB);
      if(m_handleRSI != INVALID_HANDLE) IndicatorRelease(m_handleRSI);
   }
   
   bool Init(string symbol, ENUM_TIMEFRAMES tf)
   {
      m_symbol = symbol;
      m_tf = tf;
      
      // Create indicators
      m_handleEMA50 = iMA(m_symbol, m_tf, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_handleEMA200 = iMA(m_symbol, m_tf, 200, 0, MODE_EMA, PRICE_CLOSE);
      m_handleADX = iADX(m_symbol, m_tf, 14);
      m_handleATR = iATR(m_symbol, m_tf, 14);
      m_handleBB = iBands(m_symbol, m_tf, 20, 0, 2.0, PRICE_CLOSE);
      m_handleRSI = iRSI(m_symbol, m_tf, 14, PRICE_CLOSE);
      
      if(m_handleEMA50 == INVALID_HANDLE || m_handleEMA200 == INVALID_HANDLE ||
         m_handleADX == INVALID_HANDLE || m_handleATR == INVALID_HANDLE ||
         m_handleBB == INVALID_HANDLE || m_handleRSI == INVALID_HANDLE)
      {
         Print("RegimeDetector: Failed to initialize indicators");
         return false;
      }
      
      return true;
   }
   
   void Update()
   {
      datetime currentTime = TimeCurrent();
      if(currentTime - m_lastUpdate < m_updateInterval && m_lastUpdate > 0)
         return; // Not time to update yet
      
      m_lastUpdate = currentTime;
      
      // Get current values
      double ema50[], ema200[], adx[], atr[], bbUpper[], bbLower[], bbMiddle[], rsi[];
      double close[];
      
      ArraySetAsSeries(ema50, true);
      ArraySetAsSeries(ema200, true);
      ArraySetAsSeries(adx, true);
      ArraySetAsSeries(atr, true);
      ArraySetAsSeries(bbUpper, true);
      ArraySetAsSeries(bbLower, true);
      ArraySetAsSeries(bbMiddle, true);
      ArraySetAsSeries(rsi, true);
      ArraySetAsSeries(close, true);
      
      if(CopyBuffer(m_handleEMA50, 0, 0, 3, ema50) < 3) return;
      if(CopyBuffer(m_handleEMA200, 0, 0, 3, ema200) < 3) return;
      if(CopyBuffer(m_handleADX, 0, 0, 3, adx) < 3) return;
      if(CopyBuffer(m_handleATR, 0, 0, 10, atr) < 10) return;
      if(CopyBuffer(m_handleBB, 0, 0, 3, bbUpper) < 3) return;
      if(CopyBuffer(m_handleBB, 1, 0, 3, bbMiddle) < 3) return;
      if(CopyBuffer(m_handleBB, 2, 0, 3, bbLower) < 3) return;
      if(CopyBuffer(m_handleRSI, 0, 0, 10, rsi) < 10) return;
      if(CopyClose(m_symbol, m_tf, 0, 3, close) < 3) return;
      
      // Calculate regime scores
      double trendScore = CalculateTrendScore(ema50[0], ema200[0], close[0], adx[0]);
      double reversalScore = CalculateReversalScore(rsi, close);
      double rangeScore = CalculateRangeScore(bbUpper[0], bbLower[0], bbMiddle[0], ema50, ema200, adx[0]);
      double volatileScore = CalculateVolatileScore(atr);
      
      // Determine regime (highest score wins)
      double maxScore = trendScore;
      m_currentRegime = REGIME_TREND;
      
      if(reversalScore > maxScore)
      {
         maxScore = reversalScore;
         m_currentRegime = REGIME_REVERSAL;
      }
      if(rangeScore > maxScore)
      {
         maxScore = rangeScore;
         m_currentRegime = REGIME_RANGE;
      }
      if(volatileScore > maxScore)
      {
         maxScore = volatileScore;
         m_currentRegime = REGIME_VOLATILE;
      }
      
      m_regimeStrength = maxScore;
   }
   
   ENUM_REGIME GetRegime() { return m_currentRegime; }
   string GetRegimeName()
   {
      switch(m_currentRegime)
      {
         case REGIME_TREND: return "TREND";
         case REGIME_REVERSAL: return "REVERSAL";
         case REGIME_RANGE: return "RANGE";
         case REGIME_VOLATILE: return "VOLATILE";
         default: return "UNKNOWN";
      }
   }
   double GetStrength() { return m_regimeStrength; }
   
private:
   // Trend: 50 EMA > 200 EMA, price > 50 EMA, ADX > 25
   double CalculateTrendScore(double ema50, double ema200, double price, double adx)
   {
      double score = 0.0;
      
      if(ema50 > ema200) score += 0.35;
      if(price > ema50) score += 0.35;
      if(adx > 25) score += 0.30;
      
      return score;
   }
   
   // Reversal Zone: RSI divergence, reversal candle
   double CalculateReversalScore(const double &rsi[], const double &close[])
   {
      double score = 0.0;
      
      // Check for oversold/overbought
      if(rsi[0] < 30 || rsi[0] > 70) score += 0.40;
      
      // Simple divergence check (price making new high/low, RSI not)
      bool priceDivergence = (close[0] > close[2] && rsi[0] < rsi[2]) || 
                             (close[0] < close[2] && rsi[0] > rsi[2]);
      if(priceDivergence) score += 0.40;
      
      // RSI turning
      if((rsi[0] > rsi[1] && rsi[1] < rsi[2]) || (rsi[0] < rsi[1] && rsi[1] > rsi[2]))
         score += 0.20;
      
      return score;
   }
   
   // Range: BB compression, MA convergence, ADX < 20
   double CalculateRangeScore(double bbUpper, double bbLower, double bbMiddle, 
                              const double &ema50[], const double &ema200[], double adx)
   {
      double score = 0.0;
      
      // BB compression (tight bands)
      double bbWidth = (bbUpper - bbLower) / bbMiddle;
      if(bbWidth < 0.02) score += 0.35; // Less than 2% width
      
      // MA convergence
      double maDistance = MathAbs(ema50[0] - ema200[0]) / ema200[0];
      if(maDistance < 0.01) score += 0.35; // Less than 1% apart
      
      // Low ADX
      if(adx < 20) score += 0.30;
      
      return score;
   }
   
   // Volatile Burst: ATR spike, volume burst
   double CalculateVolatileScore(const double &atr[])
   {
      double score = 0.0;
      
      // ATR spike (current ATR > average of last 10)
      double atrAvg = 0;
      for(int i = 1; i < 10; i++)
         atrAvg += atr[i];
      atrAvg /= 9;
      
      if(atr[0] > atrAvg * 1.5) score += 0.50; // 50% spike
      if(atr[0] > atrAvg * 2.0) score += 0.30; // 100% spike
      
      return score;
   }
};
