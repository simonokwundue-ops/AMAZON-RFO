//+------------------------------------------------------------------+
//|                                           PersistentMemory.mqh   |
//| Persistent memory system that survives EA and terminal restarts  |
//+------------------------------------------------------------------+
#property strict

// Memory structure for performance tracking
struct PerformanceMetrics
{
   int    totalTrades;
   int    winningTrades;
   int    losingTrades;
   double totalProfit;
   double totalLoss;
   double avgWin;
   double avgLoss;
   double winRate;
   double profitFactor;
   double sharpeRatio;
   datetime lastUpdate;
};

// Memory structure for adaptive parameters
struct AdaptiveParameters
{
   double tpMultiplier;      // TP distance multiplier
   double slMultiplier;      // SL distance multiplier
   double lotMultiplier;     // Lot size multiplier
   double aggressiveness;    // Trading aggressiveness 0-1
   double riskLevel;         // Risk level 0-1
   int    maxSimultaneous;   // Max simultaneous positions
   datetime lastOptimization;
};

// Market regime memory
struct RegimeMemory
{
   int    currentRegime;     // 0=ranging, 1=trending, 2=volatile
   double regimeStrength;    // 0-1
   int    consecutiveLosses; // Track losses for recovery
   datetime regimeChange;
};

// Main persistent memory class
class CPersistentMemory
{
private:
   string m_dataFile;
   PerformanceMetrics m_performance;
   AdaptiveParameters m_params;
   RegimeMemory m_regime;
   
   // RFO genome memory for self-optimization
   double m_rfoGenome[];
   int m_genomeSize;
   
public:
   CPersistentMemory(string symbol = "")
   {
      if(symbol == "") symbol = _Symbol;
      // Create unique filename per symbol
      m_dataFile = "QuantumScalper_" + symbol + "_Memory.bin";
      m_genomeSize = 300;
      ArrayResize(m_rfoGenome, m_genomeSize);
      
      // Initialize defaults
      InitDefaults();
   }
   
   // Initialize with default values
   void InitDefaults()
   {
      m_performance.totalTrades = 0;
      m_performance.winningTrades = 0;
      m_performance.losingTrades = 0;
      m_performance.totalProfit = 0;
      m_performance.totalLoss = 0;
      m_performance.avgWin = 0;
      m_performance.avgLoss = 0;
      m_performance.winRate = 0;
      m_performance.profitFactor = 0;
      m_performance.sharpeRatio = 0;
      m_performance.lastUpdate = 0;
      
      m_params.tpMultiplier = 1.5;
      m_params.slMultiplier = 1.0;
      m_params.lotMultiplier = 0.5; // Start conservative
      m_params.aggressiveness = 0.3; // More conservative
      m_params.riskLevel = 0.4; // Reduced risk level
      m_params.maxSimultaneous = 3; // Fewer positions to start
      m_params.lastOptimization = 0;
      
      m_regime.currentRegime = 0;
      m_regime.regimeStrength = 0.5;
      m_regime.consecutiveLosses = 0;
      m_regime.regimeChange = 0;
      
      // Initialize RFO genome with random values
      for(int i = 0; i < m_genomeSize; i++)
         m_rfoGenome[i] = (MathRand() / 32767.0) * 2.0 - 1.0; // Range [-1, 1]
   }
   
   // Load memory from disk
   bool Load()
   {
      int handle = FileOpen(m_dataFile, FILE_READ | FILE_BIN | FILE_COMMON);
      if(handle == INVALID_HANDLE)
      {
         Print("PersistentMemory: No existing memory file, starting fresh");
         return false;
      }
      
      // Read performance metrics
      FileReadStruct(handle, m_performance);
      
      // Read adaptive parameters
      FileReadStruct(handle, m_params);
      
      // Read regime memory
      FileReadStruct(handle, m_regime);
      
      // Read genome size and array
      int savedSize = FileReadInteger(handle);
      if(savedSize > 0)
      {
         m_genomeSize = savedSize;
         ArrayResize(m_rfoGenome, m_genomeSize);
         for(int i = 0; i < m_genomeSize; i++)
            m_rfoGenome[i] = FileReadDouble(handle);
      }
      
      FileClose(handle);
      Print("PersistentMemory: Successfully loaded memory - Trades: ", m_performance.totalTrades,
            " WinRate: ", DoubleToString(m_performance.winRate * 100, 2), "%");
      return true;
   }
   
   // Save memory to disk
   bool Save()
   {
      int handle = FileOpen(m_dataFile, FILE_WRITE | FILE_BIN | FILE_COMMON);
      if(handle == INVALID_HANDLE)
      {
         Print("PersistentMemory: Failed to save memory - Error: ", GetLastError());
         return false;
      }
      
      // Write performance metrics
      FileWriteStruct(handle, m_performance);
      
      // Write adaptive parameters
      FileWriteStruct(handle, m_params);
      
      // Write regime memory
      FileWriteStruct(handle, m_regime);
      
      // Write genome
      FileWriteInteger(handle, m_genomeSize);
      for(int i = 0; i < m_genomeSize; i++)
         FileWriteDouble(handle, m_rfoGenome[i]);
      
      FileClose(handle);
      return true;
   }
   
   // Update performance after trade
   void UpdatePerformance(double profit, bool isWin)
   {
      m_performance.totalTrades++;
      
      if(isWin)
      {
         m_performance.winningTrades++;
         m_performance.totalProfit += profit;
         
         // Update average win
         m_performance.avgWin = (m_performance.avgWin * (m_performance.winningTrades - 1) + profit) 
                                 / m_performance.winningTrades;
      }
      else
      {
         m_performance.losingTrades++;
         m_performance.totalLoss += MathAbs(profit);
         
         // Update average loss
         m_performance.avgLoss = (m_performance.avgLoss * (m_performance.losingTrades - 1) + MathAbs(profit)) 
                                  / m_performance.losingTrades;
                                  
         m_regime.consecutiveLosses++;
      }
      
      // Reset consecutive losses on win
      if(isWin) m_regime.consecutiveLosses = 0;
      
      // Calculate win rate
      m_performance.winRate = (double)m_performance.winningTrades / m_performance.totalTrades;
      
      // Calculate profit factor
      if(m_performance.totalLoss > 0)
         m_performance.profitFactor = m_performance.totalProfit / m_performance.totalLoss;
      
      m_performance.lastUpdate = TimeCurrent();
      
      // Auto-save every 5 trades
      if(m_performance.totalTrades % 5 == 0)
         Save();
   }
   
   // Get performance metrics
   void GetPerformance(PerformanceMetrics &perf) { perf = m_performance; }
   
   // Get adaptive parameters
   void GetParameters(AdaptiveParameters &params) { params = m_params; }
   
   // Set adaptive parameters
   void SetParameters(const AdaptiveParameters &params) 
   { 
      m_params = params;
      Save();
   }
   
   // Get regime memory
   void GetRegime(RegimeMemory &regime) { regime = m_regime; }
   
   // Set regime memory
   void SetRegime(const RegimeMemory &regime) 
   { 
      m_regime = regime;
      if(regime.currentRegime != m_regime.currentRegime)
         m_regime.regimeChange = TimeCurrent();
   }
   
   // Get RFO genome
   void GetGenome(double &genome[])
   {
      ArrayResize(genome, m_genomeSize);
      ArrayCopy(genome, m_rfoGenome);
   }
   
   // Update RFO genome
   void UpdateGenome(const double &genome[])
   {
      int size = ArraySize(genome);
      if(size > 0)
      {
         m_genomeSize = size;
         ArrayResize(m_rfoGenome, m_genomeSize);
         ArrayCopy(m_rfoGenome, genome);
      }
   }
   
   // Check if we should trigger optimization (every 20 trades)
   bool ShouldOptimize()
   {
      return (m_performance.totalTrades > 0 && m_performance.totalTrades % 20 == 0);
   }
   
   // Get total trades count
   int GetTotalTrades() { return m_performance.totalTrades; }
   
   // Get win rate
   double GetWinRate() { return m_performance.winRate; }
   
   // Get profit factor
   double GetProfitFactor() { return m_performance.profitFactor; }
   
   // Get consecutive losses
   int GetConsecutiveLosses() { return m_regime.consecutiveLosses; }
};
