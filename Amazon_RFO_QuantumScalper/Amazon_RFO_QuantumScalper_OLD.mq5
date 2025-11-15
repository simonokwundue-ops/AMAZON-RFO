//+------------------------------------------------------------------+
//|                                  Amazon_RFO_QuantumScalper.mq5   |
//|                     Quantum Multi-Position Scalping System        |
//|                    with Self-Optimization & Persistent Memory     |
//+------------------------------------------------------------------+
#property copyright "Amazon RFO Project"
#property link      "https://github.com/simonokwundue-ops/AMAZON-RFO"
#property version   "1.00"
#property strict
#property description "Quantum-style rapid scalping with multiple micro-positions"
#property description "Self-optimizing system with persistent memory"
#property description "Different strategies for different market regimes"

#include "Include/PersistentMemory.mqh"
#include "Include/MarketRegime.mqh"
#include "Include/PositionManager.mqh"
#include "Include/PerformanceTracker.mqh"
#include "Include/QuantumScalper_Core.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

// === BASIC SETTINGS ===
input group "=== Basic Risk Settings ==="
input double   Inp_BaseRisk          = 0.5;      // Base Risk per Position (%)
input double   Inp_MaxRisk           = 3.0;      // Maximum Total Risk (%)
input int      Inp_Magic             = 789456;   // Magic Number

// === QUANTUM SCALPER SETTINGS ===
input group "=== Quantum Scalper Settings ==="
input int      Inp_QuantumAnalyses   = 5;        // Number of Quantum Analyses per Tick
input int      Inp_MaxPositions      = 3;        // Maximum Simultaneous Positions
input double   Inp_MinTPPips         = 5.0;      // Minimum TP (pips)
input double   Inp_MaxTPPips         = 30.0;     // Maximum TP (pips)
input double   Inp_MinSLPips         = 3.0;      // Minimum SL (pips)
input double   Inp_MaxSLPips         = 20.0;     // Maximum SL (pips)
input bool     Inp_UseTrailing       = true;     // Use Trailing Stop
input double   Inp_TrailStepPips     = 2.0;      // Trail Step (pips)

// === MARKET REGIME SETTINGS ===
input group "=== Market Regime Settings ==="
input bool     Inp_AdaptToRegime     = true;     // Adapt to Market Regime
input ENUM_TIMEFRAMES Inp_RegimeTF   = PERIOD_M5; // Regime Detection Timeframe

// === RECOVERY SETTINGS ===
input group "=== Recovery Settings ==="
input bool     Inp_UseRecovery       = true;     // Use Recovery After Losses
input int      Inp_LossesForRecovery = 3;        // Losses to Trigger Recovery
input bool     Inp_UseHedging        = true;     // Use Hedging in Recovery

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
CMarketRegime* g_regime = NULL;
CPositionManager* g_posManager = NULL;
CPerformanceTracker* g_perfTracker = NULL;
CQuantumScalper* g_quantum = NULL;

datetime g_lastBarTime = 0;
int g_barsSinceLastTrade = 0;

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
   
   // Initialize market regime detector
   g_regime = new CMarketRegime(Inp_RegimeTF);
   
   // Initialize position manager
   g_posManager = new CPositionManager(_Symbol, Inp_MaxPositions);
   g_posManager.SetTPSLRanges(Inp_MinTPPips, Inp_MaxTPPips, Inp_MinSLPips, Inp_MaxSLPips);
   
   // Initialize performance tracker
   g_perfTracker = new CPerformanceTracker(g_memory);
   
   // Initialize quantum scalper
   g_quantum = new CQuantumScalper();
   if(!g_quantum.Init())
   {
      Print("Failed to initialize quantum scalper");
      return INIT_FAILED;
   }
   
   // Display startup information
   Print("╔════════════════════════════════════════════════════════════════╗");
   Print("║        AMAZON RFO QUANTUM SCALPER - INITIALIZED               ║");
   Print("╠════════════════════════════════════════════════════════════════╣");
   Print("║ Symbol: ", _Symbol, " | Magic: ", Inp_Magic);
   Print("║ Max Positions: ", Inp_MaxPositions, " | Quantum Analyses: ", Inp_QuantumAnalyses);
   Print("║ Self-Optimization: ", (Inp_SelfOptimize ? "ENABLED" : "DISABLED"));
   Print("║ ", g_perfTracker.GetPerformanceSummary());
   Print("╚════════════════════════════════════════════════════════════════╝");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Save persistent memory
   if(g_memory != NULL)
   {
      g_memory.Save();
      Print("Persistent memory saved");
      delete g_memory;
   }
   
   // Clean up objects
   if(g_regime != NULL) delete g_regime;
   if(g_posManager != NULL) delete g_posManager;
   if(g_perfTracker != NULL) delete g_perfTracker;
   if(g_quantum != NULL) delete g_quantum;
   
   Print("╔════════════════════════════════════════════════════════════════╗");
   Print("║        AMAZON RFO QUANTUM SCALPER - SHUTDOWN                  ║");
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
   
   // Update position manager and trail stops
   if(Inp_UseTrailing)
      g_posManager.TrailAllPositions();
   
   // Check if can open new positions
   if(!g_posManager.CanOpenPosition()) return;
   if(g_barsSinceLastTrade < Inp_MinBarsBetween) return;
   
   // === MARKET REGIME DETECTION ===
   double regimeStrength = 0;
   ENUM_MARKET_REGIME currentRegime = g_regime.DetectRegime(regimeStrength);
   
   // Update regime in memory
   RegimeMemory regimeMem;
   g_memory.GetRegime(regimeMem);
   regimeMem.currentRegime = currentRegime;
   regimeMem.regimeStrength = regimeStrength;
   g_memory.SetRegime(regimeMem);
   
   // Get regime-adapted parameters
   double regimeTPMult, regimeSLMult, regimeAggr;
   int regimeMaxPos;
   g_regime.GetRegimeParameters(currentRegime, regimeTPMult, regimeSLMult, regimeMaxPos, regimeAggr);
   
   if(Inp_AdaptToRegime)
   {
      g_posManager.SetMaxPositions(regimeMaxPos);
   }
   
   // Check entry timing based on regime
   if(!g_regime.IsGoodEntryTiming(currentRegime)) return;
   
   // === QUANTUM ANALYSIS ===
   QuantumAnalysis analyses[];
   g_quantum.PerformQuantumAnalysis(analyses, Inp_QuantumAnalyses);
   
   // Get consensus from quantum analyses
   double consensusSignal, consensusConfidence;
   bool shouldTrade;
   g_quantum.GetConsensus(analyses, consensusSignal, consensusConfidence, shouldTrade);
   
   if(!shouldTrade) return;
   
   // === RECOVERY STRATEGY ===
   int consecutiveLosses = g_memory.GetConsecutiveLosses();
   double riskReduction = 1.0;
   double tpIncrease = 1.0;
   bool useHedge = false;
   
   if(Inp_UseRecovery && consecutiveLosses >= Inp_LossesForRecovery)
   {
      g_regime.GetRecoveryStrategy(consecutiveLosses, riskReduction, tpIncrease, useHedge);
      Print("♦ Recovery mode active: Losses=", consecutiveLosses, 
            " RiskRed=", DoubleToString(riskReduction, 2),
            " TPInc=", DoubleToString(tpIncrease, 2));
      
      // Apply hedging if needed
      if(useHedge && Inp_UseHedging)
      {
         double hedgeLots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         g_posManager.HedgePositions(hedgeLots);
      }
   }
   
   // === GET ADAPTIVE PARAMETERS ===
   AdaptiveParameters adaptParams;
   g_memory.GetParameters(adaptParams);
   
   // Determine trade direction first (needed for margin calculation)
   int tradeType = -1;
   if(consensusSignal > 0)
      tradeType = ORDER_TYPE_BUY;
   else if(consensusSignal < 0)
      tradeType = ORDER_TYPE_SELL;
   
   if(tradeType < 0) return; // No valid signal
   
   // Calculate final TP/SL
   double volatility = analyses[0].volatility; // Use first analysis volatility
   double tpPips, slPips;
   g_posManager.CalculateDynamicTPSL(volatility, 
                                    regimeTPMult * adaptParams.tpMultiplier * tpIncrease,
                                    regimeSLMult * adaptParams.slMultiplier,
                                    tpPips, slPips);
   
   // Calculate lot size with margin awareness
   double riskPct = Inp_BaseRisk * adaptParams.riskLevel * riskReduction;
   
   // Get current open positions count
   int openPositions = g_posManager.GetPositionCount();
   
   // Adjust risk based on open positions to prevent margin exhaustion
   if(openPositions > 0)
   {
      // Reduce risk per position as more positions open
      double positionFactor = 1.0 / (1.0 + openPositions * 0.3);
      riskPct *= positionFactor;
   }
   
   // Absolute limit per position considering max positions
   double maxRiskPerPos = Inp_MaxRisk / MathMax(Inp_MaxPositions, 3);
   riskPct = MathMin(riskPct, maxRiskPerPos);
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   
   // Use equity instead of balance for more realistic risk calculation
   double riskAmount = equity * riskPct / 100.0;
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double lots = 0;
   if(tickValue > 0 && tickSize > 0 && point > 0 && slPips > 0)
   {
      // Calculate lots based on risk
      lots = riskAmount / (slPips * 10 * point * tickValue / tickSize);
      lots *= adaptParams.lotMultiplier;
      
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      
      // Check margin requirement for this lot size
      double price = (tradeType == ORDER_TYPE_BUY) ? 
                     SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                     SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      double marginRequired = 0;
      if(OrderCalcMargin(tradeType == ORDER_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                        _Symbol, lots, price, marginRequired))
      {
         // Ensure we have enough free margin (keep 30% buffer)
         double maxAffordable = freeMargin * 0.7;
         if(marginRequired > maxAffordable && maxAffordable > 0)
         {
            // Reduce lot size to fit available margin
            lots = lots * (maxAffordable / marginRequired);
         }
      }
      
      if(stepLot > 0)
         lots = MathFloor(lots / stepLot) * stepLot;
      
      lots = MathMax(minLot, MathMin(maxLot, lots));
      
      // Final margin check
      if(OrderCalcMargin(tradeType == ORDER_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                        _Symbol, lots, price, marginRequired))
      {
         if(marginRequired > freeMargin * 0.8) // Don't use more than 80% of free margin
         {
            lots = minLot; // Fallback to minimum
         }
      }
   }
   else
   {
      lots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   }
   
   // === OPEN POSITION ===
   string comment = StringFormat("QS_%s_C%.2f", 
                                 g_regime.GetRegimeName(currentRegime),
                                 consensusConfidence);
   
   bool success = g_posManager.OpenPosition(tradeType, lots, tpPips, slPips, comment);
   
   if(success)
   {
      g_barsSinceLastTrade = 0;
      Print("✓ Position opened: ", (tradeType == ORDER_TYPE_BUY ? "BUY" : "SELL"),
            " | Lots: ", DoubleToString(lots, 2),
            " | TP: ", DoubleToString(tpPips, 1), " pips",
            " | SL: ", DoubleToString(slPips, 1), " pips",
            " | Conf: ", DoubleToString(consensusConfidence, 2),
            " | Regime: ", g_regime.GetRegimeName(currentRegime));
   }
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
            
            Print((isWin ? "✓ WIN: " : "✗ LOSS: "), 
                  DoubleToString(profit, 2), " | ",
                  g_perfTracker.GetPerformanceSummary());
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
