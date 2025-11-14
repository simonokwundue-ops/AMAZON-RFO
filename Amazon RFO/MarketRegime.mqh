//+------------------------------------------------------------------+
//|                                              MarketRegime.mqh    |
//| Market regime detection and strategy selection                   |
//+------------------------------------------------------------------+
#property strict

// Market regime types
enum ENUM_MARKET_REGIME
{
   REGIME_RANGING = 0,   // Sideways/ranging market
   REGIME_TRENDING = 1,  // Strong trend
   REGIME_VOLATILE = 2   // High volatility/choppy
};

// Market regime detector class
class CMarketRegime
{
private:
   int m_atrHandle;
   int m_adxHandle;
   int m_bbHandle;
   ENUM_TIMEFRAMES m_timeframe;
   
   double m_volatilityThreshold;
   double m_trendThreshold;
   double m_rangeThreshold;
   
public:
   CMarketRegime(ENUM_TIMEFRAMES tf = PERIOD_M5)
   {
      m_timeframe = tf;
      m_volatilityThreshold = 1.5; // ATR multiplier for volatility
      m_trendThreshold = 25.0;     // ADX threshold for trend
      m_rangeThreshold = 20.0;     // ADX threshold for range
      
      // Initialize indicators
      m_atrHandle = iATR(_Symbol, m_timeframe, 14);
      m_adxHandle = iADX(_Symbol, m_timeframe, 14);
      m_bbHandle = iBands(_Symbol, m_timeframe, 20, 0, 2.0, PRICE_CLOSE);
      
      if(m_atrHandle == INVALID_HANDLE || m_adxHandle == INVALID_HANDLE || m_bbHandle == INVALID_HANDLE)
         Print("MarketRegime: Failed to initialize indicators");
   }
   
   ~CMarketRegime()
   {
      if(m_atrHandle != INVALID_HANDLE) IndicatorRelease(m_atrHandle);
      if(m_adxHandle != INVALID_HANDLE) IndicatorRelease(m_adxHandle);
      if(m_bbHandle != INVALID_HANDLE) IndicatorRelease(m_bbHandle);
   }
   
   // Detect current market regime
   ENUM_MARKET_REGIME DetectRegime(double &strength)
   {
      double atr[], adx[], bbUpper[], bbLower[], bbMiddle[];
      
      // Copy indicator values
      if(CopyBuffer(m_atrHandle, 0, 0, 3, atr) <= 0) return REGIME_RANGING;
      if(CopyBuffer(m_adxHandle, 0, 0, 3, adx) <= 0) return REGIME_RANGING;
      if(CopyBuffer(m_bbHandle, 1, 0, 1, bbUpper) <= 0) return REGIME_RANGING;
      if(CopyBuffer(m_bbHandle, 2, 0, 1, bbLower) <= 0) return REGIME_RANGING;
      if(CopyBuffer(m_bbHandle, 0, 0, 1, bbMiddle) <= 0) return REGIME_RANGING;
      
      ArraySetAsSeries(atr, true);
      ArraySetAsSeries(adx, true);
      
      // Calculate metrics
      double currentATR = atr[0];
      double avgATR = (atr[0] + atr[1] + atr[2]) / 3.0;
      double currentADX = adx[0];
      double bbWidth = (bbUpper[0] - bbLower[0]) / bbMiddle[0];
      
      // Volatility detection
      bool isVolatile = (currentATR > avgATR * m_volatilityThreshold) || (bbWidth > 0.05);
      
      // Trend detection
      bool isTrending = (currentADX > m_trendThreshold);
      
      // Ranging detection
      bool isRanging = (currentADX < m_rangeThreshold);
      
      // Determine regime
      ENUM_MARKET_REGIME regime = REGIME_RANGING;
      strength = 0.5;
      
      if(isVolatile && !isTrending)
      {
         regime = REGIME_VOLATILE;
         strength = MathMin(1.0, currentATR / avgATR / 2.0);
      }
      else if(isTrending)
      {
         regime = REGIME_TRENDING;
         strength = MathMin(1.0, currentADX / 50.0);
      }
      else if(isRanging)
      {
         regime = REGIME_RANGING;
         strength = MathMin(1.0, (m_trendThreshold - currentADX) / m_trendThreshold);
      }
      
      return regime;
   }
   
   // Get optimal strategy parameters for current regime
   void GetRegimeParameters(ENUM_MARKET_REGIME regime, 
                           double &tpMultiplier, 
                           double &slMultiplier, 
                           int &maxPositions,
                           double &aggressiveness)
   {
      switch(regime)
      {
         case REGIME_RANGING:
            // In ranging markets: tight TP/SL, more positions, moderate aggression
            tpMultiplier = 1.2;
            slMultiplier = 0.8;
            maxPositions = 7;
            aggressiveness = 0.6;
            break;
            
         case REGIME_TRENDING:
            // In trending markets: wider TP, tighter SL, fewer positions, high aggression
            tpMultiplier = 2.0;
            slMultiplier = 0.7;
            maxPositions = 4;
            aggressiveness = 0.8;
            break;
            
         case REGIME_VOLATILE:
            // In volatile markets: wider SL, moderate TP, fewer positions, low aggression
            tpMultiplier = 1.5;
            slMultiplier = 1.3;
            maxPositions = 3;
            aggressiveness = 0.3;
            break;
      }
   }
   
   // Get regime name for logging
   string GetRegimeName(ENUM_MARKET_REGIME regime)
   {
      switch(regime)
      {
         case REGIME_RANGING: return "RANGING";
         case REGIME_TRENDING: return "TRENDING";
         case REGIME_VOLATILE: return "VOLATILE";
         default: return "UNKNOWN";
      }
   }
   
   // Calculate market pressure (buy/sell pressure)
   double CalculateMarketPressure()
   {
      double close[], high[], low[];
      if(CopyClose(_Symbol, m_timeframe, 0, 20, close) <= 0) return 0;
      if(CopyHigh(_Symbol, m_timeframe, 0, 20, high) <= 0) return 0;
      if(CopyLow(_Symbol, m_timeframe, 0, 20, low) <= 0) return 0;
      
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      
      double buyPressure = 0;
      double sellPressure = 0;
      
      for(int i = 0; i < 20; i++)
      {
         double range = high[i] - low[i];
         if(range > 0)
         {
            double closePos = (close[i] - low[i]) / range;
            buyPressure += closePos;
            sellPressure += (1.0 - closePos);
         }
      }
      
      // Return pressure in range [-1, 1]: -1 = strong sell, +1 = strong buy
      double totalPressure = buyPressure + sellPressure;
      if(totalPressure > 0)
         return (buyPressure - sellPressure) / totalPressure;
      
      return 0;
   }
   
   // Get optimal entry timing based on regime
   bool IsGoodEntryTiming(ENUM_MARKET_REGIME regime)
   {
      double pressure = CalculateMarketPressure();
      
      switch(regime)
      {
         case REGIME_RANGING:
            // In range, enter on extremes
            return (MathAbs(pressure) > 0.3);
            
         case REGIME_TRENDING:
            // In trend, enter on pullbacks
            return true; // Let main logic decide based on trend direction
            
         case REGIME_VOLATILE:
            // In volatility, wait for calmer moments
            return (MathAbs(pressure) < 0.5);
      }
      
      return true;
   }
   
   // Get recovery strategy based on consecutive losses
   void GetRecoveryStrategy(int consecutiveLosses, 
                           double &riskReduction, 
                           double &tpIncrease,
                           bool &useHedge)
   {
      if(consecutiveLosses <= 1)
      {
         riskReduction = 1.0;  // Normal risk
         tpIncrease = 1.0;     // Normal TP
         useHedge = false;
      }
      else if(consecutiveLosses <= 3)
      {
         riskReduction = 0.7;  // Reduce risk by 30%
         tpIncrease = 1.3;     // Increase TP by 30%
         useHedge = false;
      }
      else if(consecutiveLosses <= 5)
      {
         riskReduction = 0.5;  // Reduce risk by 50%
         tpIncrease = 1.5;     // Increase TP by 50%
         useHedge = true;      // Consider hedging
      }
      else
      {
         riskReduction = 0.3;  // Minimal risk
         tpIncrease = 2.0;     // Double TP
         useHedge = true;      // Definitely hedge
      }
   }
};
