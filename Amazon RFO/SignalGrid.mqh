//+------------------------------------------------------------------+
//|                                           SignalGrid.mqh          |
//|                     Signal Grid & Strategy Scoring System         |
//+------------------------------------------------------------------+

// Signal structure
struct Signal
{
   int strategyID;           // 1=MA, 2=RSI, 3=BB, 4=MACD, 5=Session, 6=Candle
   string strategyName;
   string symbol;
   double score;             // 0.0 to 1.0
   int direction;            // 1=BUY, -1=SELL
   double slPips;
   double tpPips;
   string justification;
   datetime timestamp;
   bool isValid;
};

// Strategy base class
class CStrategy
{
protected:
   string m_name;
   int m_id;
   bool m_enabled;
   string m_allowedRegimes[];
   
public:
   CStrategy(string name, int id)
   {
      m_name = name;
      m_id = id;
      m_enabled = true;
   }
   
   virtual ~CStrategy() {}
   
   void SetAllowedRegimes(string &regimes[])
   {
      ArrayCopy(m_allowedRegimes, regimes);
   }
   
   bool IsAllowedInRegime(string regime)
   {
      if(ArraySize(m_allowedRegimes) == 0) return true;
      
      for(int i = 0; i < ArraySize(m_allowedRegimes); i++)
      {
         if(m_allowedRegimes[i] == regime) return true;
      }
      return false;
   }
   
   // Override in derived classes
   virtual Signal Analyze(string symbol, ENUM_TIMEFRAMES tf, string currentRegime) { Signal s; s.isValid = false; return s; }
   
   string GetName() { return m_name; }
   int GetID() { return m_id; }
};

// Signal Grid Manager
class CSignalGrid
{
private:
   CStrategy* m_strategies[];
   double m_minScore;
   int m_maxSignalsPerTick;
   
public:
   CSignalGrid()
   {
      m_minScore = 0.65;
      m_maxSignalsPerTick = 3;
   }
   
   ~CSignalGrid()
   {
      for(int i = 0; i < ArraySize(m_strategies); i++)
      {
         if(CheckPointer(m_strategies[i]) == POINTER_DYNAMIC)
            delete m_strategies[i];
      }
      ArrayFree(m_strategies);
   }
   
   void AddStrategy(CStrategy* strategy)
   {
      int size = ArraySize(m_strategies);
      ArrayResize(m_strategies, size + 1);
      m_strategies[size] = strategy;
   }
   
   void SetMinScore(double score) { m_minScore = score; }
   void SetMaxSignalsPerTick(int max) { m_maxSignalsPerTick = max; }
   
   // Analyze all strategies and return valid signals
   int GetSignals(Signal &signals[], string symbol, ENUM_TIMEFRAMES tf, string currentRegime)
   {
      Signal tempSignals[];
      ArrayResize(tempSignals, 0);
      
      // Analyze each strategy
      for(int i = 0; i < ArraySize(m_strategies); i++)
      {
         if(m_strategies[i] == NULL) continue;
         
         // Check if strategy is allowed in current regime
         if(!m_strategies[i].IsAllowedInRegime(currentRegime)) continue;
         
         Signal sig = m_strategies[i].Analyze(symbol, tf, currentRegime);
         
         // Add valid signals that meet minimum score
         if(sig.isValid && sig.score >= m_minScore)
         {
            int size = ArraySize(tempSignals);
            ArrayResize(tempSignals, size + 1);
            tempSignals[size] = sig;
         }
      }
      
      // Sort by score (highest first)
      SortSignalsByScore(tempSignals);
      
      // Return top signals up to max
      int count = MathMin(ArraySize(tempSignals), m_maxSignalsPerTick);
      ArrayResize(signals, count);
      for(int i = 0; i < count; i++)
      {
         signals[i] = tempSignals[i];
      }
      
      return count;
   }
   
   int GetStrategyCount() { return ArraySize(m_strategies); }
   
private:
   void SortSignalsByScore(Signal &signals[])
   {
      int n = ArraySize(signals);
      for(int i = 0; i < n - 1; i++)
      {
         for(int j = 0; j < n - i - 1; j++)
         {
            if(signals[j].score < signals[j + 1].score)
            {
               Signal temp = signals[j];
               signals[j] = signals[j + 1];
               signals[j + 1] = temp;
            }
         }
      }
   }
};
