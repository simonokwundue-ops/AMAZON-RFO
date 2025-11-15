//+------------------------------------------------------------------+
//|                                  Amazon_RFO_QuantumScalper.mq5   |
//|                  Strategy-Based Multi-Position Scalping System    |
//|                    with Self-Optimization & Persistent Memory     |
//+------------------------------------------------------------------+
#property copyright "Amazon RFO Project"
#property link      "https://github.com/simonokwundue-ops/AMAZON-RFO"
#property version   "2.00"
#property strict
#property description "6-Strategy signal grid scalping with RFO optimization"
#property description "Self-optimizing system with persistent memory"
#property description "Intelligent per-position trailing and recovery"

#include "Include/PersistentMemory.mqh"
#include "Include/RegimeDetector.mqh"
#include "Include/SignalGrid.mqh"
#include "Include/EnhancedPositionManager.mqh"
#include "Include/PerformanceTracker.mqh"

// Import all strategies
#include "Include/MABreakoutStrategy.mqh"
#include "Include/RSIDivergenceStrategy.mqh"
#include "Include/BBFadeStrategy.mqh"
#include "Include/MACDAccelerationStrategy.mqh"
#include "Include/SessionBreakoutStrategy.mqh"
#include "Include/CandlePatternStrategy.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

// === BASIC SETTINGS ===
input group "=== Basic Risk Settings ==="
input double   Inp_BaseRisk          = 0.5;      // Base Risk per Position (%)
input double   Inp_MaxRisk           = 3.0;      // Maximum Total Risk (%)
input int      Inp_Magic             = 789456;   // Magic Number

// === POSITION SETTINGS ===
input group "=== Position Settings ==="
input int      Inp_MaxPositions      = 3;        // Maximum Simultaneous Positions
input double   Inp_MinTPPips         = 5.0;      // Minimum TP (pips)
input double   Inp_MaxTPPips         = 30.0;     // Maximum TP (pips)
input double   Inp_MinSLPips         = 3.0;      // Minimum SL (pips)
input double   Inp_MaxSLPips         = 20.0;     // Maximum SL (pips)

// === TRAILING SETTINGS ===
input group "=== Trailing Stop Settings ==="
input bool     Inp_UseTrailing       = true;     // Use Trailing Stop
input double   Inp_TrailActivation   = 70.0;     // Trail Activation (% of TP)
input double   Inp_TrailBuffer       = 30.0;     // Trail Buffer (% of gains)
input double   Inp_MinTrailStep      = 3.0;      // Minimum Trail Step (pips)

// === STRATEGY SETTINGS ===
input group "=== Strategy Settings ==="
input bool     Inp_UseMABreakout     = true;     // Use MA Breakout Strategy
input bool     Inp_UseRSIDivergence  = true;     // Use RSI Divergence Strategy
input bool     Inp_UseBBFade         = true;     // Use BB Fade Strategy
input bool     Inp_UseMACDAccel      = true;     // Use MACD Acceleration Strategy
input bool     Inp_UseSessionBreak   = true;     // Use Session Breakout Strategy
input bool     Inp_UseCandlePattern  = true;     // Use Candle Pattern Strategy
input double   Inp_SignalThreshold   = 0.65;     // Signal Validity Threshold
input int      Inp_MaxSignalsPerTick = 3;        // Max Signals to Process per Tick

// === RECOVERY SETTINGS ===
input group "=== Recovery Settings ==="
input bool     Inp_UseRecovery       = true;     // Use Per-Position Recovery
input double   Inp_HedgeAtLossPips   = 15.0;     // Hedge When Loss Exceeds (pips)
input double   Inp_HedgeLotRatio     = 0.5;      // Hedge Lot Ratio

// === MARKET REGIME SETTINGS ===
input group "=== Market Regime Settings ==="
input bool     Inp_AdaptToRegime     = true;     // Adapt to Market Regime
input ENUM_TIMEFRAMES Inp_RegimeTF   = PERIOD_M5; // Regime Detection Timeframe

// === SELF-OPTIMIZATION ===
input group "=== Self-Optimization ==="
input bool     Inp_SelfOptimize      = true;     // Enable Self-Optimization
input int      Inp_OptimizeEvery     = 20;       // Optimize Every N Trades

// === ADVANCED SETTINGS ===
input group "=== Advanced Settings ==="
input int      Inp_Slippage          = 3;        // Slippage (points)
input double   Inp_MaxSpread         = 3.0;      // Max Spread (pips)
input int      Inp_MinBarsBetween    = 1;        // Min Bars Between Positions

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+

CPersistentMemory* g_memory = NULL;
CRegimeDetector* g_regimeDetector = NULL;
CSignalGrid* g_signalGrid = NULL;
CEnhancedPositionManager* g_posManager = NULL;
CPerformanceTracker* g_perfTracker = NULL;

datetime g_lastBarTime = 0;
int g_barsSinceLastTrade = 0;
datetime g_lastRegimeUpdate = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize persistent memory
   g_memory = new CPersistentMemory(_Symbol);
   if(!g_memory.Load())
   {
      Print("Starting with fresh memory");
   }
   
   // Initialize regime detector
   g_regimeDetector = new CRegimeDetector();
   if(!g_regimeDetector.Init(_Symbol, Inp_RegimeTF))
   {
      Print("ERROR: Failed to initialize regime detector");
      return INIT_FAILED;
   }
   
   // Initialize signal grid
   g_signalGrid = new CSignalGrid();
   g_signalGrid.SetMinScore(Inp_SignalThreshold);
   g_signalGrid.SetMaxSignalsPerTick(Inp_MaxSignalsPerTick);
   
   // Register strategies
   if(Inp_UseMABreakout)
   {
      CMABreakoutStrategy* strategy = new CMABreakoutStrategy();
      if(strategy.Init(_Symbol, Inp_RegimeTF))
         g_signalGrid.AddStrategy(strategy);
      else
         delete strategy;
   }
   
   if(Inp_UseRSIDivergence)
   {
      CRSIDivergenceStrategy* strategy = new CRSIDivergenceStrategy();
      if(strategy.Init(_Symbol, Inp_RegimeTF))
         g_signalGrid.AddStrategy(strategy);
      else
         delete strategy;
   }
   
   if(Inp_UseBBFade)
   {
      CBBFadeStrategy* strategy = new CBBFadeStrategy();
      if(strategy.Init(_Symbol, Inp_RegimeTF))
         g_signalGrid.AddStrategy(strategy);
      else
         delete strategy;
   }
   
   if(Inp_UseMACDAccel)
   {
      CMACDAccelerationStrategy* strategy = new CMACDAccelerationStrategy();
      if(strategy.Init(_Symbol, Inp_RegimeTF))
         g_signalGrid.AddStrategy(strategy);
      else
         delete strategy;
   }
   
   if(Inp_UseSessionBreak)
   {
      CSessionBreakoutStrategy* strategy = new CSessionBreakoutStrategy();
      if(strategy.Init(_Symbol, Inp_RegimeTF))
         g_signalGrid.AddStrategy(strategy);
      else
         delete strategy;
   }
   
   if(Inp_UseCandlePattern)
   {
      CCandlePatternStrategy* strategy = new CCandlePatternStrategy();
      if(strategy.Init(_Symbol, Inp_RegimeTF))
         g_signalGrid.AddStrategy(strategy);
      else
         delete strategy;
   }
   
   Print("Registered ", g_signalGrid.GetStrategyCount(), " strategies");
   
   // Initialize enhanced position manager
   g_posManager = new CEnhancedPositionManager(_Symbol, Inp_MaxPositions);
   g_posManager.SetTPSLRanges(Inp_MinTPPips, Inp_MaxTPPips, Inp_MinSLPips, Inp_MaxSLPips);
   g_posManager.SetTrailingConfig(Inp_TrailActivation / 100.0, 
                                   Inp_TrailBuffer / 100.0, 
                                   Inp_MinTrailStep);
   
   // Initialize performance tracker
   g_perfTracker = new CPerformanceTracker(g_memory);
   
   // Display initialization info
   PerformanceMetrics metrics;
   g_memory.GetPerformance(metrics);
   
   Print("╔════════════════════════════════════════════════════════════════╗");
   Print("║        AMAZON RFO QUANTUM SCALPER V2 - INITIALIZED            ║");
   Print("╠════════════════════════════════════════════════════════════════╣");
   Print("║ Symbol: ", _Symbol, " | Magic: ", Inp_Magic);
   Print("║ Max Positions: ", Inp_MaxPositions, " | Strategies: ", g_signalGrid.GetStrategyCount());
   Print("║ Trailing: ", (Inp_UseTrailing ? "ON" : "OFF"), 
         " (Activate: ", Inp_TrailActivation, "%, Buffer: ", Inp_TrailBuffer, "%)");
   Print("║ Self-Optimization: ", (Inp_SelfOptimize ? "ENABLED" : "DISABLED"));
   Print("║ Trades: ", metrics.totalTrades, 
         " | WR: ", DoubleToString(metrics.winRate * 100, 1), "%", 
         " | PF: ", DoubleToString(metrics.profitFactor, 2),
         " | Profit: ", DoubleToString(metrics.totalProfit, 2));
   Print("╚════════════════════════════════════════════════════════════════╝");
   
   EventSetTimer(300); // Save memory every 5 minutes
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   
   // Save persistent memory
   if(g_memory != NULL)
   {
      g_memory.Save();
      Print("Persistent memory saved");
      delete g_memory;
   }
   
   // Clean up objects
   if(g_regimeDetector != NULL) delete g_regimeDetector;
   if(g_signalGrid != NULL) delete g_signalGrid;
   if(g_posManager != NULL) delete g_posManager;
   if(g_perfTracker != NULL) delete g_perfTracker;
   
   Print("╔════════════════════════════════════════════════════════════════╗");
   Print("║        AMAZON RFO QUANTUM SCALPER V2 - SHUTDOWN               ║");
   Print("╚════════════════════════════════════════════════════════════════╝");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check spread
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) 
                   / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(spread > Inp_MaxSpread * 10) return; // Spread too wide
   
   // Track bars for timing
   datetime currentBarTime = iTime(_Symbol, PERIOD_M1, 0);
   if(currentBarTime != g_lastBarTime)
   {
      g_lastBarTime = currentBarTime;
      g_barsSinceLastTrade++;
   }
   
   // === POSITION MANAGEMENT ===
   
   // Trail stops on existing positions
   if(Inp_UseTrailing)
      g_posManager.TrailAllPositions();
   
   // Per-position recovery (hedge losing positions)
   if(Inp_UseRecovery)
   {
      int losingIndices[];
      double lossPips[];
      g_posManager.GetLosingPositions(losingIndices, lossPips);
      
      for(int i = 0; i < ArraySize(losingIndices); i++)
      {
         if(lossPips[i] > Inp_HedgeAtLossPips)
         {
            g_posManager.HedgePosition(losingIndices[i], Inp_HedgeLotRatio);
         }
      }
   }
   
   // === ENTRY LOGIC ===
   
   // Check if can open new positions
   if(!g_posManager.CanOpenPosition()) return;
   if(g_barsSinceLastTrade < Inp_MinBarsBetween) return;
   
   // Update regime periodically (every 15 minutes)
   datetime currentTime = TimeCurrent();
   if(currentTime - g_lastRegimeUpdate >= 900) // 15 minutes
   {
      g_lastRegimeUpdate = currentTime;
      g_regimeDetector.UpdateRegime();
      
      Print("♦ Regime updated: ", g_regimeDetector.GetRegimeName());
   }
   
   // Get current regime
   string currentRegime = g_regimeDetector.GetRegimeName();
   
   // Analyze all strategies and get signals
   Signal signals[];
   int signalCount = g_signalGrid.GetSignals(signals, _Symbol, Period(), currentRegime);
   
   if(signalCount == 0) return; // No valid signals
   
   // Process top signals (up to max per tick)
   int signalsToProcess = MathMin(ArraySize(signals), Inp_MaxSignalsPerTick);
   int signalsProcessed = 0;
   
   for(int i = 0; i < signalsToProcess && signalsProcessed < signalsToProcess; i++)
   {
      if(!g_posManager.CanOpenPosition()) break;
      
      Signal signal = signals[i];
      
      // Calculate lot size with margin awareness
      double lots = CalculateLotSize(signal.slPips);
      if(lots <= 0) continue;
      
      // Open position
      bool success = g_posManager.OpenPosition(signal.direction, 
                                                lots, 
                                                signal.tpPips, 
                                                signal.slPips, 
                                                signal.strategyID,
                                                signal.justification);
      
      if(success)
      {
         g_barsSinceLastTrade = 0;
         signalsProcessed++;
         
         Print("✓ Signal ", i+1, "/", ArraySize(signals), 
               " Score: ", DoubleToString(signal.score, 2),
               " | Regime: ", g_regimeDetector.GetRegimeName(currentRegime));
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size with margin awareness                          |
//+------------------------------------------------------------------+
double CalculateLotSize(double slPips)
{
   // Get adaptive parameters
   AdaptiveParameters adaptParams;
   g_memory.GetParameters(adaptParams);
   
   // Get number of open positions
   int openPositions = g_posManager.GetPositionCount();
   
   // Calculate risk percentage with position scaling
   double riskPct = Inp_BaseRisk * adaptParams.riskLevel;
   
   // Reduce risk as positions increase
   if(openPositions > 0)
   {
      double positionFactor = 1.0 / (1.0 + openPositions * 0.3);
      riskPct *= positionFactor;
   }
   
   // Absolute limit per position
   double maxRiskPerPos = Inp_MaxRisk / MathMax(Inp_MaxPositions, 3);
   riskPct = MathMin(riskPct, maxRiskPerPos);
   
   // Calculate based on equity
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double riskAmount = equity * riskPct / 100.0;
   
   // Calculate lot size
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double lots = 0;
   if(tickValue > 0 && tickSize > 0 && point > 0 && slPips > 0)
   {
      lots = riskAmount / (slPips * 10 * point * tickValue / tickSize);
      lots *= adaptParams.lotMultiplier;
      
      // Get lot constraints
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      
      // Check margin requirement
      double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK); // Use ASK for calculation
      double marginRequired = 0;
      
      if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lots, price, marginRequired))
      {
         // Ensure we have enough free margin (keep 30% buffer)
         double maxAffordable = freeMargin * 0.7;
         if(marginRequired > maxAffordable && maxAffordable > 0)
         {
            lots = lots * (maxAffordable / marginRequired);
         }
      }
      
      // Round to valid lot size
      if(stepLot > 0)
         lots = MathFloor(lots / stepLot) * stepLot;
      
      lots = MathMax(minLot, MathMin(maxLot, lots));
      
      // Final margin safety check
      if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lots, price, marginRequired))
      {
         if(marginRequired > freeMargin * 0.8)
         {
            lots = minLot; // Fallback to minimum
         }
      }
   }
   else
   {
      lots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   }
   
   return lots;
}

//+------------------------------------------------------------------+
//| Trade transaction handler                                         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result)
{
   // Track closed positions for performance
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(HistoryDealSelect(trans.deal))
      {
         long dealEntry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
         if(dealEntry == DEAL_ENTRY_OUT) // Position closed
         {
            double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
            bool isWin = (profit > 0);
            
            // Record in performance tracker
            g_perfTracker.RecordTrade(profit, isWin);
            
            // Get performance summary
            PerformanceMetrics metrics;
            g_memory.GetPerformance(metrics);
            
            Print((isWin ? "✓ WIN: " : "✗ LOSS: "), 
                  DoubleToString(profit, 2), 
                  " | Trades: ", metrics.totalTrades,
                  " | WR: ", DoubleToString(metrics.winRate * 100, 1), "%",
                  " | PF: ", DoubleToString(metrics.profitFactor, 2),
                  " | Profit: ", DoubleToString(metrics.totalProfit, 2));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Timer function - periodic tasks                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Save memory periodically
   if(g_memory != NULL)
      g_memory.Save();
}
