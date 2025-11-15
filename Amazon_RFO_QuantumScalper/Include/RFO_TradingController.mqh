//+------------------------------------------------------------------+
//|                                    RFO_TradingController.mqh      |
//| Royal Flush Optimization controller for all trading decisions     |
//| Evolves decision genomes based on trading performance             |
//+------------------------------------------------------------------+
#property strict

#include "RFO_DecisionGenome.mqh"

//+------------------------------------------------------------------+
//| RFO Trading Controller - Central decision management              |
//+------------------------------------------------------------------+
class CRFO_TradingController
{
private:
   // Population management
   CDecisionGenome* m_deck[];          // Main population (2x popSize)
   CDecisionGenome* m_hand[];          // Current generation offspring
   CDecisionGenome* m_bestGenome;      // Current best genome
   
   int m_popSize;                      // Population size
   int m_deckSize;                     // Sectors per gene dimension
   double m_dealerBluff;               // Mutation probability
   
   // Evolution tracking
   int m_generation;
   int m_tradesThisGen;
   int m_tradesPerGeneration;
   
   // Performance tracking for fitness
   double m_recentProfits[];
   bool m_recentWins[];
   int m_recentCount;
   int m_recentIndex;
   
   // Initialization state
   bool m_initialized;
   bool m_firstGeneration;
   
public:
   CRFO_TradingController()
   {
      m_popSize = 50;
      m_deckSize = 1000;
      m_dealerBluff = 0.03;
      m_tradesPerGeneration = 20;
      m_generation = 0;
      m_tradesThisGen = 0;
      m_recentCount = 10;
      m_recentIndex = 0;
      m_initialized = false;
      m_firstGeneration = true;
      
      ArrayResize(m_recentProfits, m_recentCount);
      ArrayResize(m_recentWins, m_recentCount);
      ArrayFill(m_recentProfits, 0, m_recentCount, 0.0);
      
      m_bestGenome = new CDecisionGenome(m_deckSize);
   }
   
   ~CRFO_TradingController()
   {
      // Clean up population
      for(int i = 0; i < ArraySize(m_deck); i++)
      {
         if(CheckPointer(m_deck[i]) == POINTER_DYNAMIC)
            delete m_deck[i];
      }
      
      for(int i = 0; i < ArraySize(m_hand); i++)
      {
         if(CheckPointer(m_hand[i]) == POINTER_DYNAMIC)
            delete m_hand[i];
      }
      
      if(CheckPointer(m_bestGenome) == POINTER_DYNAMIC)
         delete m_bestGenome;
   }
   
   // Initialize RFO controller
   bool Initialize(int popSize = 50, int deckSize = 1000, double mutationProb = 0.03, int tradesPerGen = 20)
   {
      m_popSize = popSize;
      m_deckSize = deckSize;
      m_dealerBluff = mutationProb;
      m_tradesPerGeneration = tradesPerGen;
      
      // Create initial population
      ArrayResize(m_hand, m_popSize);
      ArrayResize(m_deck, m_popSize * 2);
      
      // Initialize hand (current generation)
      for(int i = 0; i < m_popSize; i++)
      {
         m_hand[i] = new CDecisionGenome(m_deckSize);
      }
      
      // Initialize deck (extended population for selection)
      for(int i = 0; i < m_popSize * 2; i++)
      {
         m_deck[i] = new CDecisionGenome(m_deckSize);
      }
      
      // Set initial best genome to first random genome
      m_bestGenome.CopyFrom(m_hand[0]);
      
      m_initialized = true;
      m_firstGeneration = true;
      
      Print("▼ RFO Trading Controller Initialized");
      Print("  Population: ", m_popSize, " | Sectors: ", m_deckSize, " | Mutation: ", m_dealerBluff * 100, "%");
      Print("  Evolution cycle: Every ", m_tradesPerGeneration, " trades");
      
      return true;
   }
   
   // Get current best decision genome
   CDecisionGenome* GetBestGenome()
   {
      return m_bestGenome;
   }
   
   // Record trade result and update fitness
   void RecordTradeResult(double profit, bool isWin)
   {
      // Store in recent history
      m_recentProfits[m_recentIndex] = profit;
      m_recentWins[m_recentIndex] = isWin;
      m_recentIndex = (m_recentIndex + 1) % m_recentCount;
      
      m_tradesThisGen++;
      
      // Calculate current fitness
      double newFitness = CalculateFitness();
      m_bestGenome.fitness = newFitness;
      
      Print("♦ Trade recorded | Profit: ", DoubleToString(profit, 2), 
            " | Win: ", (isWin ? "YES" : "NO"), 
            " | Fitness: ", DoubleToString(newFitness, 4),
            " | Trades this gen: ", m_tradesThisGen);
      
      // Check if we should evolve
      if(m_tradesThisGen >= m_tradesPerGeneration)
      {
         EvolvePopulation();
         m_tradesThisGen = 0;
         m_generation++;
      }
   }
   
   // Calculate fitness from recent trading performance
   double CalculateFitness()
   {
      double totalProfit = 0;
      int wins = 0;
      int totalTrades = 0;
      
      for(int i = 0; i < m_recentCount; i++)
      {
         if(m_recentProfits[i] != 0 || m_recentWins[i])
         {
            totalProfit += m_recentProfits[i];
            if(m_recentWins[i]) wins++;
            totalTrades++;
         }
      }
      
      if(totalTrades == 0) return 0.0;
      
      double winRate = (double)wins / totalTrades;
      double avgProfit = totalProfit / totalTrades;
      
      // Fitness = combination of win rate and profit
      // Emphasize profitability over win rate
      double fitness = (winRate * 0.3 + (avgProfit > 0 ? 1.0 : 0.0) * 0.7) * MathAbs(avgProfit);
      
      return fitness;
   }
   
   // Evolution cycle - create new generation
   void EvolvePopulation()
   {
      Print("═══════════════════════════════════════════════════════════");
      Print("▼ RFO EVOLUTION CYCLE - Generation ", m_generation + 1);
      Print("═══════════════════════════════════════════════════════════");
      
      if(m_firstGeneration)
      {
         // First generation: just copy hands to deck
         for(int i = 0; i < m_popSize; i++)
         {
            m_deck[i].CopyFrom(m_hand[i]);
            m_deck[i].fitness = CalculateFitness();
         }
         m_firstGeneration = false;
      }
      else
      {
         // Add current hands to deck (second half)
         for(int i = 0; i < m_popSize; i++)
         {
            m_deck[m_popSize + i].CopyFrom(m_hand[i]);
            m_deck[m_popSize + i].fitness = CalculateFitness();
         }
      }
      
      // Sort deck by fitness (best first)
      SortDeckByFitness();
      
      // Update best genome
      m_bestGenome.CopyFrom(m_deck[0]);
      
      Print("  Best Fitness: ", DoubleToString(m_deck[0].fitness, 4));
      Print("  Worst Fitness: ", DoubleToString(m_deck[m_popSize * 2 - 1].fitness, 4));
      
      // Create new generation through crossover and mutation
      for(int i = 0; i < m_popSize; i++)
      {
         // Select parent (bias towards better genomes)
         double rnd = ((double)MathRand() / 32767.0);
         rnd = rnd * rnd; // Square for stronger selection pressure
         int parentIdx = (int)(rnd * m_popSize);
         if(parentIdx >= m_popSize) parentIdx = m_popSize - 1;
         
         // Select opponent for crossover
         rnd = ((double)MathRand() / 32767.0);
         rnd = rnd * rnd;
         int opponentIdx = (int)(rnd * m_popSize);
         if(opponentIdx >= m_popSize) opponentIdx = m_popSize - 1;
         
         // Copy parent
         m_hand[i].CopyFrom(m_deck[parentIdx]);
         
         // Crossover with opponent
         m_hand[i].CrossoverWith(m_deck[opponentIdx]);
         
         // Mutation ("dealer bluff")
         m_hand[i].Mutate(m_dealerBluff);
      }
      
      // Keep best genome in first position (elitism)
      m_hand[0].CopyFrom(m_bestGenome);
      
      Print("  New generation created with ", m_popSize, " genomes");
      Print("  Elitism: Best genome preserved");
      Print("═══════════════════════════════════════════════════════════");
   }
   
   // Sort deck by fitness (descending - best first)
   void SortDeckByFitness()
   {
      // Simple bubble sort (population is small)
      for(int i = 0; i < m_popSize * 2 - 1; i++)
      {
         for(int j = i + 1; j < m_popSize * 2; j++)
         {
            if(m_deck[j].fitness > m_deck[i].fitness)
            {
               // Swap
               CDecisionGenome* temp = m_deck[i];
               m_deck[i] = m_deck[j];
               m_deck[j] = temp;
            }
         }
      }
   }
   
   // Get statistics
   int GetGeneration() { return m_generation; }
   int GetTradesThisGeneration() { return m_tradesThisGen; }
   double GetBestFitness() { return m_bestGenome.fitness; }
   
   // Check if initialized
   bool IsInitialized() { return m_initialized; }
};
