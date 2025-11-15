//+------------------------------------------------------------------+
//|                                        RFO_DecisionGenome.mqh    |
//| Decision Genome Structure for RFO-controlled trading             |
//| Represents complete trading decision logic as evolved genome      |
//+------------------------------------------------------------------+
#property strict

// Total genes in decision genome
#define GENOME_SIZE 26

// Gene index definitions for clarity
enum E_GeneIndex
{
   // Signal Strategy Weights (0-5)
   GENE_WEIGHT_MA = 0,
   GENE_WEIGHT_RSI = 1,
   GENE_WEIGHT_BB = 2,
   GENE_WEIGHT_MACD = 3,
   GENE_WEIGHT_SESSION = 4,
   GENE_WEIGHT_CANDLE = 5,
   
   // Entry Timing (6-8)
   GENE_MIN_SIGNAL_SCORE = 6,
   GENE_CONFIRM_DELAY = 7,
   GENE_MULTI_SIGNAL_BONUS = 8,
   
   // Position Sizing (9-12)
   GENE_LOT_MULTIPLIER = 9,
   GENE_CONFIDENCE_SCALING = 10,
   GENE_REGIME_ADJUSTMENT = 11,
   GENE_RISK_PER_POSITION = 12,
   
   // TP/SL Placement (13-16)
   GENE_TP_ATR_MULT = 13,
   GENE_SL_ATR_MULT = 14,
   GENE_TP_REGIME_ADJ = 15,
   GENE_SL_REGIME_ADJ = 16,
   
   // Trailing Control (17-19)
   GENE_TRAIL_ACTIVATION = 17,
   GENE_TRAIL_BUFFER = 18,
   GENE_TRAIL_STEP_MULT = 19,
   
   // Recovery Actions (20-22)
   GENE_HEDGE_TRIGGER = 20,
   GENE_HEDGE_RATIO = 21,
   GENE_RECOVERY_AGGR = 22,
   
   // Multi-Position Logic (23-25)
   GENE_MAX_POSITIONS = 23,
   GENE_POSITION_SPACING = 24,
   GENE_CORRELATION_TOL = 25
};

//+------------------------------------------------------------------+
//| Decision Genome - Complete trading logic encoded as genes        |
//+------------------------------------------------------------------+
class CDecisionGenome
{
private:
   double m_phenotype[GENOME_SIZE];  // Real decision values
   int    m_genotype[GENOME_SIZE];   // Sector ranks (for RFO evolution)
   
   double m_rangeMin[GENOME_SIZE];   // Min value per gene
   double m_rangeMax[GENOME_SIZE];   // Max value per gene
   int    m_deckSize;                // Sectors per dimension
   
public:
   double fitness;                   // Trading performance fitness
   
   CDecisionGenome(int deckSize = 1000)
   {
      m_deckSize = deckSize;
      fitness = -DBL_MAX;
      InitializeRanges();
      RandomizeGenome();
   }
   
   // Initialize valid ranges for each gene
   void InitializeRanges()
   {
      // Signal Strategy Weights (0-5): [0.0-2.0]
      for(int i = 0; i <= 5; i++)
      {
         m_rangeMin[i] = 0.0;
         m_rangeMax[i] = 2.0;
      }
      
      // Entry Timing
      m_rangeMin[GENE_MIN_SIGNAL_SCORE] = 0.5; m_rangeMax[GENE_MIN_SIGNAL_SCORE] = 0.9;
      m_rangeMin[GENE_CONFIRM_DELAY] = 0.0; m_rangeMax[GENE_CONFIRM_DELAY] = 5.0;
      m_rangeMin[GENE_MULTI_SIGNAL_BONUS] = 0.0; m_rangeMax[GENE_MULTI_SIGNAL_BONUS] = 0.3;
      
      // Position Sizing
      m_rangeMin[GENE_LOT_MULTIPLIER] = 0.3; m_rangeMax[GENE_LOT_MULTIPLIER] = 2.0;
      m_rangeMin[GENE_CONFIDENCE_SCALING] = 0.5; m_rangeMax[GENE_CONFIDENCE_SCALING] = 1.5;
      m_rangeMin[GENE_REGIME_ADJUSTMENT] = 0.7; m_rangeMax[GENE_REGIME_ADJUSTMENT] = 1.3;
      m_rangeMin[GENE_RISK_PER_POSITION] = 0.3; m_rangeMax[GENE_RISK_PER_POSITION] = 1.5;
      
      // TP/SL Placement
      m_rangeMin[GENE_TP_ATR_MULT] = 1.0; m_rangeMax[GENE_TP_ATR_MULT] = 4.0;
      m_rangeMin[GENE_SL_ATR_MULT] = 0.5; m_rangeMax[GENE_SL_ATR_MULT] = 2.0;
      m_rangeMin[GENE_TP_REGIME_ADJ] = 0.7; m_rangeMax[GENE_TP_REGIME_ADJ] = 1.5;
      m_rangeMin[GENE_SL_REGIME_ADJ] = 0.7; m_rangeMax[GENE_SL_REGIME_ADJ] = 1.5;
      
      // Trailing Control
      m_rangeMin[GENE_TRAIL_ACTIVATION] = 50.0; m_rangeMax[GENE_TRAIL_ACTIVATION] = 90.0;
      m_rangeMin[GENE_TRAIL_BUFFER] = 10.0; m_rangeMax[GENE_TRAIL_BUFFER] = 50.0;
      m_rangeMin[GENE_TRAIL_STEP_MULT] = 0.5; m_rangeMax[GENE_TRAIL_STEP_MULT] = 2.0;
      
      // Recovery Actions
      m_rangeMin[GENE_HEDGE_TRIGGER] = 10.0; m_rangeMax[GENE_HEDGE_TRIGGER] = 30.0;
      m_rangeMin[GENE_HEDGE_RATIO] = 0.3; m_rangeMax[GENE_HEDGE_RATIO] = 0.8;
      m_rangeMin[GENE_RECOVERY_AGGR] = 0.2; m_rangeMax[GENE_RECOVERY_AGGR] = 0.8;
      
      // Multi-Position Logic
      m_rangeMin[GENE_MAX_POSITIONS] = 2.0; m_rangeMax[GENE_MAX_POSITIONS] = 10.0;
      m_rangeMin[GENE_POSITION_SPACING] = 1.0; m_rangeMax[GENE_POSITION_SPACING] = 10.0;
      m_rangeMin[GENE_CORRELATION_TOL] = 0.3; m_rangeMax[GENE_CORRELATION_TOL] = 0.9;
   }
   
   // Randomize genome (initial population or mutation)
   void RandomizeGenome()
   {
      for(int i = 0; i < GENOME_SIZE; i++)
      {
         m_genotype[i] = (int)(MathRand() % m_deckSize);
         m_phenotype[i] = GenotypeToPheno type(i, m_genotype[i]);
      }
   }
   
   // Convert genotype (sector rank) to phenotype (real value)
   double GenotypeToPhenotype(int geneIndex, int rank)
   {
      double sectorSize = (m_rangeMax[geneIndex] - m_rangeMin[geneIndex]) / m_deckSize;
      double randomOffset = ((double)MathRand() / 32767.0);
      return m_rangeMin[geneIndex] + (randomOffset + rank) * sectorSize;
   }
   
   // Get gene value (phenotype)
   double GetGene(int index)
   {
      if(index < 0 || index >= GENOME_SIZE) return 0.0;
      return m_phenotype[index];
   }
   
   // Get genotype (for crossover/mutation)
   int GetGenotype(int index)
   {
      if(index < 0 || index >= GENOME_SIZE) return 0;
      return m_genotype[index];
   }
   
   // Set genotype (from crossover)
   void SetGenotype(int index, int rank)
   {
      if(index < 0 || index >= GENOME_SIZE) return;
      m_genotype[index] = rank;
      m_phenotype[index] = GenotypeToPhenotype(index, rank);
   }
   
   // Mutate genome (RFO "bluff")
   void Mutate(double probability)
   {
      for(int i = 0; i < GENOME_SIZE; i++)
      {
         if(((double)MathRand() / 32767.0) < probability)
         {
            m_genotype[i] = (int)(MathRand() % m_deckSize);
            m_phenotype[i] = GenotypeToPhenotype(i, m_genotype[i]);
         }
      }
   }
   
   // Copy genome from another
   void CopyFrom(const CDecisionGenome &other)
   {
      for(int i = 0; i < GENOME_SIZE; i++)
      {
         m_genotype[i] = other.m_genotype[i];
         m_phenotype[i] = other.m_phenotype[i];
      }
      fitness = other.fitness;
   }
   
   // Perform 3-point crossover with another genome
   void CrossoverWith(const CDecisionGenome &partner)
   {
      // RFO 3-point crossover
      int cutPoints[3];
      cutPoints[0] = (int)(MathRand() % GENOME_SIZE);
      cutPoints[1] = (int)(MathRand() % GENOME_SIZE);
      cutPoints[2] = (int)(MathRand() % GENOME_SIZE);
      
      // Sort cut points
      for(int i = 0; i < 2; i++)
      {
         for(int j = i + 1; j < 3; j++)
         {
            if(cutPoints[i] > cutPoints[j])
            {
               int temp = cutPoints[i];
               cutPoints[i] = cutPoints[j];
               cutPoints[j] = temp;
            }
         }
      }
      
      // Alternating exchange
      bool takeFromPartner = ((MathRand() % 2) == 0);
      int segment = 0;
      
      for(int i = 0; i < GENOME_SIZE; i++)
      {
         // Check if we crossed a cut point
         if(segment < 3 && i >= cutPoints[segment])
         {
            takeFromPartner = !takeFromPartner;
            segment++;
         }
         
         if(takeFromPartner)
         {
            m_genotype[i] = partner.m_genotype[i];
            m_phenotype[i] = partner.m_phenotype[i];
         }
      }
   }
   
   // Get decision values by category for easy access
   
   double GetStrategyWeight(int strategyId)
   {
      if(strategyId < 1 || strategyId > 6) return 1.0;
      return m_phenotype[GENE_WEIGHT_MA + (strategyId - 1)];
   }
   
   double GetMinSignalScore() { return m_phenotype[GENE_MIN_SIGNAL_SCORE]; }
   int GetConfirmDelay() { return (int)m_phenotype[GENE_CONFIRM_DELAY]; }
   double GetMultiSignalBonus() { return m_phenotype[GENE_MULTI_SIGNAL_BONUS]; }
   
   double GetLotMultiplier() { return m_phenotype[GENE_LOT_MULTIPLIER]; }
   double GetConfidenceScaling() { return m_phenotype[GENE_CONFIDENCE_SCALING]; }
   double GetRegimeAdjustment() { return m_phenotype[GENE_REGIME_ADJUSTMENT]; }
   double GetRiskPerPosition() { return m_phenotype[GENE_RISK_PER_POSITION]; }
   
   double GetTPATRMultiplier() { return m_phenotype[GENE_TP_ATR_MULT]; }
   double GetSLATRMultiplier() { return m_phenotype[GENE_SL_ATR_MULT]; }
   double GetTPRegimeAdj() { return m_phenotype[GENE_TP_REGIME_ADJ]; }
   double GetSLRegimeAdj() { return m_phenotype[GENE_SL_REGIME_ADJ]; }
   
   double GetTrailActivation() { return m_phenotype[GENE_TRAIL_ACTIVATION]; }
   double GetTrailBuffer() { return m_phenotype[GENE_TRAIL_BUFFER]; }
   double GetTrailStepMult() { return m_phenotype[GENE_TRAIL_STEP_MULT]; }
   
   double GetHedgeTrigger() { return m_phenotype[GENE_HEDGE_TRIGGER]; }
   double GetHedgeRatio() { return m_phenotype[GENE_HEDGE_RATIO]; }
   double GetRecoveryAggr() { return m_phenotype[GENE_RECOVERY_AGGR]; }
   
   int GetMaxPositions() { return (int)m_phenotype[GENE_MAX_POSITIONS]; }
   double GetPositionSpacing() { return m_phenotype[GENE_POSITION_SPACING]; }
   double GetCorrelationTol() { return m_phenotype[GENE_CORRELATION_TOL]; }
};
