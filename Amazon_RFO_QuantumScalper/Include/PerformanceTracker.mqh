//+------------------------------------------------------------------+
//|                                        PerformanceTracker.mqh    |
//| Track performance and trigger self-optimization                  |
//+------------------------------------------------------------------+
#property strict

#include "PersistentMemory.mqh"
#include "RFO_Core.mqh"

// Self-optimization using RFO
class CPerformanceTracker
{
private:
   CPersistentMemory* m_memory;
   CRFO m_optimizer;
   
   // Optimization parameters (what we optimize)
   int m_coords;
   double m_rangeMin[];
   double m_rangeMax[];
   double m_rangeStep[];
   
   // Track recent performance for optimization
   double m_recentProfits[];
   int m_recentCount;
   
   bool m_optimizerInitialized;
   
public:
   CPerformanceTracker(CPersistentMemory* memory)
   {
      m_memory = memory;
      m_recentCount = 20; // Track last 20 trades
      ArrayResize(m_recentProfits, m_recentCount);
      ArrayFill(m_recentProfits, 0, m_recentCount, 0);
      
      m_optimizerInitialized = false;
      InitializeOptimizer();
   }
   
   // Initialize RFO optimizer for parameters
   void InitializeOptimizer()
   {
      // We optimize 6 parameters:
      // [0] tpMultiplier [0.8 - 3.0]
      // [1] slMultiplier [0.5 - 2.0]
      // [2] lotMultiplier [0.5 - 2.0]
      // [3] aggressiveness [0.0 - 1.0]
      // [4] riskLevel [0.0 - 1.0]
      // [5] maxSimultaneous [2 - 10]
      
      m_coords = 6;
      ArrayResize(m_rangeMin, m_coords);
      ArrayResize(m_rangeMax, m_coords);
      ArrayResize(m_rangeStep, m_coords);
      
      m_rangeMin[0] = 0.8;  m_rangeMax[0] = 3.0;  m_rangeStep[0] = 0.1;  // tpMultiplier
      m_rangeMin[1] = 0.5;  m_rangeMax[1] = 2.0;  m_rangeStep[1] = 0.1;  // slMultiplier
      m_rangeMin[2] = 0.5;  m_rangeMax[2] = 2.0;  m_rangeStep[2] = 0.1;  // lotMultiplier
      m_rangeMin[3] = 0.0;  m_rangeMax[3] = 1.0;  m_rangeStep[3] = 0.05; // aggressiveness
      m_rangeMin[4] = 0.0;  m_rangeMax[4] = 1.0;  m_rangeStep[4] = 0.05; // riskLevel
      m_rangeMin[5] = 2.0;  m_rangeMax[5] = 10.0; m_rangeStep[5] = 1.0;  // maxSimultaneous
      
      if(m_optimizer.Init(m_rangeMin, m_rangeMax, m_rangeStep, m_coords, 50, 512, 0.04))
      {
         m_optimizerInitialized = true;
         
         // Load genome from memory if available
         double genome[];
         m_memory.GetGenome(genome);
         if(ArraySize(genome) > 0)
         {
            Print("PerformanceTracker: Loaded genome from persistent memory");
         }
         
         Print("PerformanceTracker: Optimizer initialized successfully");
      }
      else
      {
         Print("PerformanceTracker: Failed to initialize optimizer");
      }
   }
   
   // Record a trade result
   void RecordTrade(double profit, bool isWin)
   {
      // Shift array and add new profit
      for(int i = m_recentCount - 1; i > 0; i--)
         m_recentProfits[i] = m_recentProfits[i - 1];
      
      m_recentProfits[0] = profit;
      
      // Update persistent memory
      m_memory.UpdatePerformance(profit, isWin);
      
      // Check if we should optimize
      if(m_memory.ShouldOptimize())
      {
         Print("▼ Performance milestone reached: ", m_memory.GetTotalTrades(), " trades");
         OptimizeParameters();
      }
   }
   
   // Perform self-optimization using RFO
   void OptimizeParameters()
   {
      if(!m_optimizerInitialized)
      {
         Print("PerformanceTracker: Optimizer not initialized, skipping optimization");
         return;
      }
      
      Print("♠ Starting self-optimization based on recent performance...");
      
      // Get current performance metrics
      PerformanceMetrics perf;
      m_memory.GetPerformance(perf);
      
      // Calculate recent performance score
      double recentScore = CalculateRecentScore();
      
      Print("♠ Current metrics: WinRate=", DoubleToString(perf.winRate * 100, 2), 
            "% ProfitFactor=", DoubleToString(perf.profitFactor, 2),
            " RecentScore=", DoubleToString(recentScore, 3));
      
      // Run RFO optimization cycles
      int optimizationCycles = 30;
      double bestFitness = -DBL_MAX;
      double bestParams[];
      
      for(int cycle = 0; cycle < optimizationCycles; cycle++)
      {
         m_optimizer.StartGeneration();
         int candidates = m_optimizer.Candidates();
         
         for(int i = 0; i < candidates; i++)
         {
            double candidate[];
            m_optimizer.GetCandidate(i, candidate);
            
            // Evaluate fitness of this parameter set
            double fitness = EvaluateParameterSet(candidate, perf, recentScore);
            m_optimizer.SetFitness(i, fitness);
            
            if(fitness > bestFitness)
            {
               bestFitness = fitness;
               ArrayResize(bestParams, ArraySize(candidate));
               ArrayCopy(bestParams, candidate);
            }
         }
         
         m_optimizer.FinishGeneration();
      }
      
      // Apply best parameters found
      if(ArraySize(bestParams) > 0)
      {
         ApplyOptimizedParameters(bestParams);
         Print("♠ Optimization complete. New fitness: ", DoubleToString(bestFitness, 4));
         
         // Save genome to persistent memory
         double genome[];
         m_optimizer.BestParams(genome);
         m_memory.UpdateGenome(genome);
         m_memory.Save();
      }
   }
   
   // Calculate recent performance score
   double CalculateRecentScore()
   {
      double totalProfit = 0;
      double avgProfit = 0;
      int positiveCount = 0;
      
      for(int i = 0; i < m_recentCount; i++)
      {
         totalProfit += m_recentProfits[i];
         if(m_recentProfits[i] > 0) positiveCount++;
      }
      
      avgProfit = totalProfit / m_recentCount;
      double winRate = (double)positiveCount / m_recentCount;
      
      // Combine profit and win rate
      return (avgProfit * 0.6) + (winRate * 0.4);
   }
   
   // Evaluate fitness of a parameter set
   double EvaluateParameterSet(const double &params[], 
                               const PerformanceMetrics &perf,
                               double recentScore)
   {
      // Extract parameters
      double tpMult = params[0];
      double slMult = params[1];
      double lotMult = params[2];
      double aggr = params[3];
      double risk = params[4];
      double maxPos = params[5];
      
      // Fitness components
      
      // 1. Risk-reward ratio (prefer higher TP/SL ratio)
      double rrRatio = tpMult / slMult;
      double rrScore = MathMin(1.0, rrRatio / 3.0); // Normalize to [0, 1]
      
      // 2. Balance (not too aggressive, not too conservative)
      double balanceScore = 1.0 - MathAbs(aggr - 0.5) * 2.0;
      
      // 3. Recent performance alignment
      double performanceScore = recentScore;
      if(performanceScore < 0) performanceScore = 0;
      if(performanceScore > 1) performanceScore = 1;
      
      // 4. Historical win rate bonus
      double winRateScore = perf.winRate;
      
      // 5. Profit factor bonus
      double pfScore = 0;
      if(perf.profitFactor > 0)
         pfScore = MathMin(1.0, perf.profitFactor / 2.0);
      
      // 6. Position management (moderate position count preferred)
      double posScore = 1.0 - MathAbs(maxPos - 5.0) / 8.0;
      if(posScore < 0) posScore = 0;
      
      // Weighted combination
      double fitness = 
         rrScore * 0.25 +
         balanceScore * 0.15 +
         performanceScore * 0.30 +
         winRateScore * 0.15 +
         pfScore * 0.10 +
         posScore * 0.05;
      
      return fitness;
   }
   
   // Apply optimized parameters
   void ApplyOptimizedParameters(const double &params[])
   {
      AdaptiveParameters adaptParams;
      m_memory.GetParameters(adaptParams);
      
      adaptParams.tpMultiplier = params[0];
      adaptParams.slMultiplier = params[1];
      adaptParams.lotMultiplier = params[2];
      adaptParams.aggressiveness = params[3];
      adaptParams.riskLevel = params[4];
      adaptParams.maxSimultaneous = (int)params[5];
      adaptParams.lastOptimization = TimeCurrent();
      
      m_memory.SetParameters(adaptParams);
      
      Print("♠ Applied optimized parameters:");
      Print("   TP Multiplier: ", DoubleToString(adaptParams.tpMultiplier, 2));
      Print("   SL Multiplier: ", DoubleToString(adaptParams.slMultiplier, 2));
      Print("   Lot Multiplier: ", DoubleToString(adaptParams.lotMultiplier, 2));
      Print("   Aggressiveness: ", DoubleToString(adaptParams.aggressiveness, 2));
      Print("   Risk Level: ", DoubleToString(adaptParams.riskLevel, 2));
      Print("   Max Simultaneous: ", adaptParams.maxSimultaneous);
   }
   
   // Get performance summary string
   string GetPerformanceSummary()
   {
      PerformanceMetrics perf;
      m_memory.GetPerformance(perf);
      
      return StringFormat("Trades: %d | WR: %.1f%% | PF: %.2f | Profit: %.2f",
                         perf.totalTrades,
                         perf.winRate * 100.0,
                         perf.profitFactor,
                         perf.totalProfit - perf.totalLoss);
   }
};
