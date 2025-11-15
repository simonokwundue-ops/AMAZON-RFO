//+------------------------------------------------------------------+
//|                                           RFO_MarketAdvisor.mqh |
//|                                     Amazon RFO Quantum Scalper |
//+------------------------------------------------------------------+
#property copyright "Amazon RFO"
#property link      ""
#property strict

#include "RegimeDetector.mqh"

// Market Context Structure - RFO's awareness of market conditions
struct MarketContext
{
   // Regime Information
   ENUM_MARKET_REGIME currentRegime;
   double regimeStrength;           // 0.0-1.0 confidence in regime
   int regimeDurationBars;          // How long in current regime
   
   // Volatility Metrics from 250 M1 candles
   double avgVolatility;            // Average pip range
   double currentVolatility;        // Current volatility vs average
   double volatilityTrend;          // Increasing/Decreasing (-1.0 to 1.0)
   double highestHigh250;           // Highest high in 250 M1 bars
   double lowestLow250;             // Lowest low in 250 M1 bars
   double pricePosition;            // Where price is in range (0.0-1.0)
   
   // Price Action Analysis
   double momentum;                 // Price momentum strength
   double trendStrength;            // Trend clarity (0.0-1.0)
   double consolidationLevel;       // Ranging level (0.0-1.0)
   
   // Time Context
   bool isLondonSession;           // London 08:00-10:30
   bool isNewYorkSession;          // New York 13:00-16:00
   bool isAsianSession;            // Asian 00:00-06:00
   int hourOfDay;
   int dayOfWeek;
   
   // Signal Quality Indicators
   double signalNoiseRatio;        // Clean signal vs noise
   double priceActionQuality;      // Quality of price movement
   bool isChoppy;                  // Choppy market detection
   bool isBreakout;                // Breakout conditions
   
   // Recent Performance Context
   double recentWinRate;           // Last 20 trades
   double recentProfitFactor;      // Last 20 trades
   int consecutiveWins;
   int consecutiveLosses;
};

// Strategy Performance Data - RFO's knowledge of strategy effectiveness
struct StrategyPerformance
{
   int strategyId;
   string strategyName;
   
   // Performance in Current Regime
   double winRateInRegime;
   double avgProfitInRegime;
   int tradesInRegime;
   
   // Overall Performance
   double overallWinRate;
   double overallProfitFactor;
   
   // Signal Quality
   double avgSignalScore;
   double falseSignalRate;        // Signals that didn't work out
   
   // Optimal Conditions
   double bestVolatilityRange[2]; // Min/Max volatility for this strategy
   ENUM_MARKET_REGIME bestRegime;
   int bestTimeOfDay;             // Hour
};

//+------------------------------------------------------------------+
//| RFO Market Advisory System                                       |
//| Provides RFO with comprehensive market awareness                 |
//+------------------------------------------------------------------+
class CRFO_MarketAdvisor
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   
   // Market Context
   MarketContext m_context;
   
   // Strategy Performance Tracking
   StrategyPerformance m_strategyPerf[6];
   
   // Historical M1 Data (250 candles)
   double m_m1Opens[250];
   double m_m1Closes[250];
   double m_m1Highs[250];
   double m_m1Lows[250];
   datetime m_m1Times[250];
   
   // Regime Detector
   CRegimeDetector* m_regimeDetector;
   
   // Analysis caching
   datetime m_lastAnalysisTime;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CRFO_MarketAdvisor(string symbol = NULL, ENUM_TIMEFRAMES timeframe = PERIOD_M5)
   {
      m_symbol = (symbol == NULL) ? _Symbol : symbol;
      m_timeframe = timeframe;
      m_lastAnalysisTime = 0;
      
      m_regimeDetector = new CRegimeDetector(m_symbol, PERIOD_M5);
      
      // Initialize strategy performance structures
      InitializeStrategyPerformance();
      
      // Initialize context
      ZeroMemory(m_context);
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~CRFO_MarketAdvisor()
   {
      if(m_regimeDetector != NULL)
         delete m_regimeDetector;
   }
   
   //+------------------------------------------------------------------+
   //| Initialize Strategy Performance Tracking                          |
   //+------------------------------------------------------------------+
   void InitializeStrategyPerformance()
   {
      string strategyNames[6] = {"MA Breakout", "RSI Divergence", "BB Fade", 
                                  "MACD Acceleration", "Session Breakout", "Candle Patterns"};
      
      for(int i = 0; i < 6; i++)
      {
         m_strategyPerf[i].strategyId = i + 1;
         m_strategyPerf[i].strategyName = strategyNames[i];
         m_strategyPerf[i].winRateInRegime = 0.5;
         m_strategyPerf[i].avgProfitInRegime = 0.0;
         m_strategyPerf[i].tradesInRegime = 0;
         m_strategyPerf[i].overallWinRate = 0.5;
         m_strategyPerf[i].overallProfitFactor = 1.0;
         m_strategyPerf[i].avgSignalScore = 0.7;
         m_strategyPerf[i].falseSignalRate = 0.3;
         m_strategyPerf[i].bestVolatilityRange[0] = 10.0;
         m_strategyPerf[i].bestVolatilityRange[1] = 50.0;
         m_strategyPerf[i].bestRegime = REGIME_TREND;
         m_strategyPerf[i].bestTimeOfDay = 9; // London open
      }
   }
   
   //+------------------------------------------------------------------+
   //| Update Market Context - Call every tick                          |
   //+------------------------------------------------------------------+
   bool UpdateMarketContext()
   {
      // Update every 5 seconds maximum
      if(TimeCurrent() - m_lastAnalysisTime < 5)
         return true;
         
      m_lastAnalysisTime = TimeCurrent();
      
      // 1. Load 250 M1 candles
      if(!LoadM1History())
         return false;
      
      // 2. Analyze volatility from M1 data
      AnalyzeVolatility();
      
      // 3. Analyze price action
      AnalyzePriceAction();
      
      // 4. Detect market regime
      m_regimeDetector.Update();
      m_context.currentRegime = m_regimeDetector.GetCurrentRegime();
      m_context.regimeStrength = CalculateRegimeStrength();
      
      // 5. Analyze time context
      AnalyzeTimeContext();
      
      // 6. Calculate signal quality indicators
      CalculateSignalQuality();
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Load M1 historical data (250 candles)                            |
   //+------------------------------------------------------------------+
   bool LoadM1History()
   {
      int copied = CopyOpen(m_symbol, PERIOD_M1, 0, 250, m_m1Opens);
      if(copied < 250) return false;
      
      copied = CopyClose(m_symbol, PERIOD_M1, 0, 250, m_m1Closes);
      if(copied < 250) return false;
      
      copied = CopyHigh(m_symbol, PERIOD_M1, 0, 250, m_m1Highs);
      if(copied < 250) return false;
      
      copied = CopyLow(m_symbol, PERIOD_M1, 0, 250, m_m1Lows);
      if(copied < 250) return false;
      
      copied = CopyTime(m_symbol, PERIOD_M1, 0, 250, m_m1Times);
      if(copied < 250) return false;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Analyze Volatility from 250 M1 candles                           |
   //+------------------------------------------------------------------+
   void AnalyzeVolatility()
   {
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double sumRange = 0.0;
      double sumTrend = 0.0;
      
      m_context.highestHigh250 = m_m1Highs[ArrayMaximum(m_m1Highs, 0, 250)];
      m_context.lowestLow250 = m_m1Lows[ArrayMinimum(m_m1Lows, 0, 250)];
      
      // Calculate average volatility
      for(int i = 0; i < 250; i++)
      {
         double range = (m_m1Highs[i] - m_m1Lows[i]) / point;
         sumRange += range;
         
         // Trend component
         if(i < 249)
         {
            double move = (m_m1Closes[i] - m_m1Closes[i+1]) / point;
            sumTrend += move;
         }
      }
      
      m_context.avgVolatility = sumRange / 250.0;
      
      // Current volatility (last 20 bars)
      double currentSum = 0.0;
      for(int i = 0; i < 20; i++)
      {
         currentSum += (m_m1Highs[i] - m_m1Lows[i]) / point;
      }
      m_context.currentVolatility = (currentSum / 20.0) / m_context.avgVolatility;
      
      // Volatility trend (increasing/decreasing)
      double recentVol = currentSum / 20.0;
      double olderSum = 0.0;
      for(int i = 20; i < 40; i++)
      {
         olderSum += (m_m1Highs[i] - m_m1Lows[i]) / point;
      }
      double olderVol = olderSum / 20.0;
      m_context.volatilityTrend = (recentVol - olderVol) / olderVol;
      
      // Price position in 250-bar range
      double currentPrice = m_m1Closes[0];
      if(m_context.highestHigh250 != m_context.lowestLow250)
      {
         m_context.pricePosition = (currentPrice - m_context.lowestLow250) / 
                                   (m_context.highestHigh250 - m_context.lowestLow250);
      }
      else
      {
         m_context.pricePosition = 0.5;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Analyze Price Action                                              |
   //+------------------------------------------------------------------+
   void AnalyzePriceAction()
   {
      // Momentum from recent closes
      double momentum = 0.0;
      for(int i = 0; i < 20; i++)
      {
         if(i < 19)
         {
            momentum += (m_m1Closes[i] - m_m1Closes[i+1]);
         }
      }
      m_context.momentum = momentum / SymbolInfoDouble(m_symbol, SYMBOL_POINT) / 20.0;
      
      // Trend strength from linear regression
      m_context.trendStrength = CalculateTrendStrength();
      
      // Consolidation level (inverse of trend strength)
      m_context.consolidationLevel = 1.0 - m_context.trendStrength;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Trend Strength (0.0-1.0)                               |
   //+------------------------------------------------------------------+
   double CalculateTrendStrength()
   {
      // Simple linear regression on last 50 M1 closes
      double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      int n = 50;
      
      for(int i = 0; i < n; i++)
      {
         double x = i;
         double y = m_m1Closes[i];
         sumX += x;
         sumY += y;
         sumXY += x * y;
         sumX2 += x * x;
      }
      
      double slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
      double avgY = sumY / n;
      
      // R-squared as trend strength
      double ssTotal = 0, ssRes = 0;
      for(int i = 0; i < n; i++)
      {
         double predicted = avgY + slope * i;
         ssTotal += MathPow(m_m1Closes[i] - avgY, 2);
         ssRes += MathPow(m_m1Closes[i] - predicted, 2);
      }
      
      double rSquared = 1.0 - (ssRes / ssTotal);
      return MathMax(0.0, MathMin(1.0, rSquared));
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Regime Strength                                         |
   //+------------------------------------------------------------------+
   double CalculateRegimeStrength()
   {
      // Combine multiple factors
      double strength = 0.0;
      
      switch(m_context.currentRegime)
      {
         case REGIME_TREND:
            strength = m_context.trendStrength * 0.6 + (1.0 - m_context.consolidationLevel) * 0.4;
            break;
         case REGIME_RANGE:
            strength = m_context.consolidationLevel * 0.7 + (1.0 - MathAbs(m_context.momentum) / 10.0) * 0.3;
            break;
         case REGIME_REVERSAL:
            strength = 0.6; // Moderate default for reversal
            break;
         case REGIME_VOLATILE:
            strength = MathMin(1.0, m_context.currentVolatility * 0.5);
            break;
      }
      
      return MathMax(0.0, MathMin(1.0, strength));
   }
   
   //+------------------------------------------------------------------+
   //| Analyze Time Context                                              |
   //+------------------------------------------------------------------+
   void AnalyzeTimeContext()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      m_context.hourOfDay = dt.hour;
      m_context.dayOfWeek = dt.day_of_week;
      
      // London session: 08:00-10:30 GMT
      m_context.isLondonSession = (dt.hour >= 8 && dt.hour < 11);
      
      // New York session: 13:00-16:00 GMT
      m_context.isNewYorkSession = (dt.hour >= 13 && dt.hour < 16);
      
      // Asian session: 00:00-06:00 GMT
      m_context.isAsianSession = (dt.hour >= 0 && dt.hour < 6);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Signal Quality Indicators                               |
   //+------------------------------------------------------------------+
   void CalculateSignalQuality()
   {
      // Signal-to-noise ratio based on volatility consistency
      double volatilityStdDev = 0.0;
      double mean = m_context.avgVolatility;
      
      for(int i = 0; i < 50; i++)
      {
         double range = (m_m1Highs[i] - m_m1Lows[i]) / SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         volatilityStdDev += MathPow(range - mean, 2);
      }
      volatilityStdDev = MathSqrt(volatilityStdDev / 50.0);
      
      // Lower std dev = cleaner signal
      m_context.signalNoiseRatio = mean / (volatilityStdDev + 1.0);
      
      // Price action quality
      m_context.priceActionQuality = (m_context.trendStrength * 0.5) + 
                                      (m_context.signalNoiseRatio / 10.0);
      m_context.priceActionQuality = MathMin(1.0, m_context.priceActionQuality);
      
      // Choppy market detection
      m_context.isChoppy = (volatilityStdDev > mean * 0.5) && (m_context.trendStrength < 0.3);
      
      // Breakout detection
      double recentRange = m_m1Highs[0] - m_m1Lows[0];
      double avgRecentRange = 0.0;
      for(int i = 1; i < 20; i++)
      {
         avgRecentRange += (m_m1Highs[i] - m_m1Lows[i]);
      }
      avgRecentRange /= 19.0;
      
      m_context.isBreakout = (recentRange > avgRecentRange * 1.5) && (MathAbs(m_context.momentum) > 5.0);
   }
   
   //+------------------------------------------------------------------+
   //| Get Market Context for RFO                                        |
   //+------------------------------------------------------------------+
   MarketContext GetMarketContext() { return m_context; }
   
   //+------------------------------------------------------------------+
   //| Advise RFO on Signal Quality                                      |
   //| Returns confidence score 0.0-1.0                                  |
   //+------------------------------------------------------------------+
   double AdviseOnSignal(int strategyId, double signalScore, ENUM_MARKET_REGIME signalRegime)
   {
      double confidence = signalScore;
      
      // Check if regime matches
      if(signalRegime != m_context.currentRegime && signalRegime != REGIME_VOLATILE)
      {
         confidence *= 0.5; // Major penalty for wrong regime
      }
      
      // Adjust for regime strength
      confidence *= (0.5 + m_context.regimeStrength * 0.5);
      
      // Adjust for signal quality
      if(m_context.isChoppy)
      {
         confidence *= 0.6; // Penalize in choppy markets
      }
      
      if(m_context.priceActionQuality < 0.4)
      {
         confidence *= 0.7; // Penalize poor price action
      }
      
      // Reward breakout conditions for breakout strategies
      if(m_context.isBreakout && (strategyId == 1 || strategyId == 4 || strategyId == 5))
      {
         confidence *= 1.2;
      }
      
      // Time of day adjustments
      if(m_context.isLondonSession || m_context.isNewYorkSession)
      {
         confidence *= 1.1; // Reward active sessions
      }
      else if(m_context.isAsianSession)
      {
         confidence *= 0.9; // Slight penalty for quiet Asian session
      }
      
      // Strategy-specific performance in current regime
      if(strategyId >= 1 && strategyId <= 6)
      {
         StrategyPerformance perf = m_strategyPerf[strategyId - 1];
         if(perf.tradesInRegime > 5) // Enough data
         {
            confidence *= (0.7 + perf.winRateInRegime * 0.3);
         }
      }
      
      return MathMax(0.0, MathMin(1.0, confidence));
   }
   
   //+------------------------------------------------------------------+
   //| Record Strategy Trade Result                                      |
   //+------------------------------------------------------------------+
   void RecordStrategyTrade(int strategyId, bool isWin, double profit, ENUM_MARKET_REGIME regime)
   {
      if(strategyId < 1 || strategyId > 6) return;
      
      int idx = strategyId - 1;
      
      // Update regime-specific performance
      if(regime == m_context.currentRegime)
      {
         m_strategyPerf[idx].tradesInRegime++;
         double oldWinRate = m_strategyPerf[idx].winRateInRegime;
         double alpha = 1.0 / MathMin(m_strategyPerf[idx].tradesInRegime, 20);
         m_strategyPerf[idx].winRateInRegime = oldWinRate + alpha * ((isWin ? 1.0 : 0.0) - oldWinRate);
         m_strategyPerf[idx].avgProfitInRegime += alpha * (profit - m_strategyPerf[idx].avgProfitInRegime);
      }
      
      // Update overall performance
      double alpha = 0.05; // Exponential moving average
      m_strategyPerf[idx].overallWinRate += alpha * ((isWin ? 1.0 : 0.0) - m_strategyPerf[idx].overallWinRate);
   }
   
   //+------------------------------------------------------------------+
   //| Is Signal Likely a Bluff? (False signal detection)               |
   //+------------------------------------------------------------------+
   bool IsSignalBluff(double signalScore, int strategyId)
   {
      // Very low signal score
      if(signalScore < 0.55) return true;
      
      // Choppy market with weak signal
      if(m_context.isChoppy && signalScore < 0.75) return true;
      
      // Poor price action quality
      if(m_context.priceActionQuality < 0.3) return true;
      
      // Very low signal-to-noise ratio
      if(m_context.signalNoiseRatio < 1.5) return true;
      
      // Strategy has high false signal rate in current regime
      if(strategyId >= 1 && strategyId <= 6)
      {
         int idx = strategyId - 1;
         if(m_strategyPerf[idx].falseSignalRate > 0.6 && m_strategyPerf[idx].tradesInRegime > 10)
         {
            return true;
         }
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Get Recommended Position Size Adjustment                          |
   //+------------------------------------------------------------------+
   double GetPositionSizeAdjustment()
   {
      double adjustment = 1.0;
      
      // Reduce size in choppy markets
      if(m_context.isChoppy) adjustment *= 0.7;
      
      // Reduce size with poor price action
      if(m_context.priceActionQuality < 0.5)
      {
         adjustment *= (0.5 + m_context.priceActionQuality);
      }
      
      // Increase size in good conditions
      if(m_context.regimeStrength > 0.7 && !m_context.isChoppy)
      {
         adjustment *= 1.2;
      }
      
      // Increase during active sessions
      if(m_context.isLondonSession || m_context.isNewYorkSession)
      {
         adjustment *= 1.1;
      }
      
      return MathMax(0.5, MathMin(1.5, adjustment));
   }
   
   //+------------------------------------------------------------------+
   //| Get Strategy Performance                                           |
   //+------------------------------------------------------------------+
   StrategyPerformance GetStrategyPerformance(int strategyId)
   {
      if(strategyId >= 1 && strategyId <= 6)
         return m_strategyPerf[strategyId - 1];
      
      StrategyPerformance empty;
      ZeroMemory(empty);
      return empty;
   }
   
   //+------------------------------------------------------------------+
   //| Print Market Advisory Report                                      |
   //+------------------------------------------------------------------+
   void PrintAdvisoryReport()
   {
      string regimeName = "";
      switch(m_context.currentRegime)
      {
         case REGIME_TREND: regimeName = "TREND"; break;
         case REGIME_RANGE: regimeName = "RANGE"; break;
         case REGIME_REVERSAL: regimeName = "REVERSAL"; break;
         case REGIME_VOLATILE: regimeName = "VOLATILE"; break;
      }
      
      Print("═══════════════ RFO MARKET ADVISORY ═══════════════");
      Print("Regime: ", regimeName, " (Strength: ", DoubleToString(m_context.regimeStrength * 100, 1), "%)");
      Print("Volatility: Avg=", DoubleToString(m_context.avgVolatility, 1), 
            " pips, Current=", DoubleToString(m_context.currentVolatility * 100, 0), "%");
      Print("Trend Strength: ", DoubleToString(m_context.trendStrength * 100, 1), "%");
      Print("Signal Quality: SNR=", DoubleToString(m_context.signalNoiseRatio, 2),
            ", PA Quality=", DoubleToString(m_context.priceActionQuality * 100, 1), "%");
      Print("Market State: ", m_context.isChoppy ? "CHOPPY" : "CLEAN",
            ", ", m_context.isBreakout ? "BREAKOUT" : "NORMAL");
      Print("Session: ", m_context.isLondonSession ? "LONDON" : 
                         (m_context.isNewYorkSession ? "NEW YORK" : 
                         (m_context.isAsianSession ? "ASIAN" : "OFF-HOURS")));
      Print("═══════════════════════════════════════════════════");
   }
};
