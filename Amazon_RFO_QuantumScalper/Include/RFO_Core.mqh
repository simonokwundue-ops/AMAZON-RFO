//+------------------------------------------------------------------+
//|                                                  RFO_Core.mqh    |
//| Self-contained Royal Flush Optimization core for MQL5            |
//+------------------------------------------------------------------+
#property strict

// Lightweight utilities
double __rnd01() { return (double)MathRand()/32767.0; }
int    __rndInt(int n) { if(n<=1) return 0; return (int)MathFloor(__rnd01()*n); }

// Structure for a single "hand" (agent)
struct S_RFO_Agent
{
  double card[];      // real card values (phenotype)
  double f;           // fitness
  int    cardRanks[]; // sector ranks (genotype)

  void Init(int coords)
  {
    ArrayResize(cardRanks, coords);
    ArrayResize(card,      coords);
    f = -DBL_MAX;
  }
};

// Core RFO class (standalone, no external base classes)
class CRFO
{
public:
  // Parameters
  int    popSize;      // population size
  int    deckSize;     // number of sectors per dimension
  double dealerBluff;  // mutation probability [0..1]

  // Problem definition
  int    coords;       // number of coordinates (decision variables)
  double rangeMin[];
  double rangeMax[];
  double rangeStep[];

  // Internal containers
  S_RFO_Agent deck[];     // 2*pop deck for selection
  S_RFO_Agent tempDeck[]; // temp for sorting
  S_RFO_Agent hand[];     // current generation offspring

  // Best solution tracking
  double bestF;
  double bestCard[];

  // Lifecycle state
  bool   initialized;
  bool   dealtOnce;

  // Construction ----------------------------------------------------
  CRFO(): popSize(50), deckSize(1000), dealerBluff(0.03), coords(0), bestF(-DBL_MAX), initialized(false), dealtOnce(false)
  {
    MathSrand((uint)TimeLocal());
  }

  bool Init(const double &minP[], const double &maxP[], const double &stepP[],
            const int coordsP, const int popSizeP=50, const int deckSizeP=1000, const double bluffP=0.03)
  {
    if(coordsP<=0 || popSizeP<=0 || deckSizeP<=0) return false;
    coords      = coordsP;
    popSize     = popSizeP;
    deckSize    = deckSizeP;
    dealerBluff = bluffP;

    ArrayResize(rangeMin,  coords);
    ArrayResize(rangeMax,  coords);
    ArrayResize(rangeStep, coords);
    for(int i=0;i<coords;i++)
    {
      rangeMin[i]  = minP[i];
      rangeMax[i]  = maxP[i];
      rangeStep[i] = stepP[i];
      if(rangeMax[i] < rangeMin[i]) { double t=rangeMax[i]; rangeMax[i]=rangeMin[i]; rangeMin[i]=t; }
      if(rangeStep[i] <= 0) rangeStep[i] = (rangeMax[i]-rangeMin[i])/deckSize;
    }

    ArrayResize(hand, popSize);
    for(int i=0;i<popSize;i++) hand[i].Init(coords);

    ArrayResize(deck, popSize*2);
    ArrayResize(tempDeck, popSize*2);
    for(int i=0;i<popSize*2;i++)
    {
      deck[i].Init(coords);
      tempDeck[i].Init(coords);
    }

    ArrayResize(bestCard, coords);
    bestF = -DBL_MAX;
    dealtOnce = false;
    initialized = true;
    return true;
  }

  // Start or progress one generation: prepares hand[] cards
  void StartGeneration()
  {
    if(!initialized) return;
    if(!dealtOnce)
    {
      // Initial random hands
      for(int i=0;i<popSize;i++)
      {
        for(int c=0;c<coords;c++)
        {
          hand[i].cardRanks[c] = __rndInt(deckSize);
          hand[i].card[c]      = DealCard(hand[i].cardRanks[c], c);
          hand[i].card[c]      = SnapToRange(hand[i].card[c], c);
        }
      }
      dealtOnce = true;
      return;
    }

    Evolution();
  }

  // Caller evaluates each candidate i and calls SetFitness(i,f)
  void SetFitness(int i, double f)
  {
    if(i<0 || i>=popSize) return;
    hand[i].f = f;
  }

  // After all fitness values are set, finish generation (selection + sort)
  void FinishGeneration()
  {
    if(!initialized) return;

    // Update best
    for(int i=0;i<popSize;i++)
    {
      if(hand[i].f > bestF)
      {
        bestF = hand[i].f;
        ArrayCopy(bestCard, hand[i].card, 0, 0, WHOLE_ARRAY);
      }
    }

    // Merge into deck second half
    for(int i=0;i<popSize;i++)
      deck[popSize+i] = hand[i];

    // Sort by fitness descending
    sortDeckDesc(deck, popSize*2);

    // Keep top popSize in the first half implicitly via deck
  }

  // Accessors -------------------------------------------------------
  int Candidates() const { return popSize; }

  // Fill out with current candidate i (phenotype)
  void GetCandidate(const int i, double &out[])
  {
    if(i<0 || i>=popSize) return;
    ArrayResize(out, coords);
    for(int c=0;c<coords;c++) out[c] = hand[i].card[c];
  }

  double BestFitness() const { return bestF; }
  void   BestParams(double &out[])
  {
    ArrayResize(out, coords);
    ArrayCopy(out, bestCard, 0, 0, WHOLE_ARRAY);
  }

private:
  // Three-point crossover with rank mutation
  void Evolution()
  {
    int cutPoints = 3;
    int tempCuts[]; ArrayResize(tempCuts, cutPoints);
    int finalCuts[]; ArrayResize(finalCuts, cutPoints+2);

    for(int i=0;i<popSize;i++)
    {
      // Tournament-biased opponent (square probability)
      double rnd = __rnd01(); rnd *= rnd;
      int opponent = (int)MathFloor(rnd * (popSize));
      if(opponent>=popSize) opponent = popSize-1;

      // Copy base from elite deck (first half is the elite from previous sort or initial zeroes)
      hand[i] = deck[i];

      // Random cuts
      for(int j=0;j<cutPoints;j++) tempCuts[j] = __rndInt(coords);
      ArraySort(tempCuts);
      // Add borders
      finalCuts[0] = 0;
      for(int j=0;j<cutPoints;j++) finalCuts[j+1] = tempCuts[j];
      finalCuts[cutPoints+1] = coords-1;

      // Starting point for exchange
      int startPoint = (__rnd01()<0.5?0:1);
      for(int j=startPoint;j<cutPoints+2;j+=2)
      {
        if(j<cutPoints+1)
        {
          for(int k=finalCuts[j]; k<finalCuts[j+1]; k++)
            hand[i].cardRanks[k] = deck[opponent].cardRanks[k];
        }
      }

      // Bluff (mutation)
      ShuffleRanks(hand[i].cardRanks);

      // Decode ranks to phenotype
      for(int c=0;c<coords;c++)
      {
        hand[i].card[c] = DealCard(hand[i].cardRanks[c], c);
        hand[i].card[c] = SnapToRange(hand[i].card[c], c);
      }
    }
  }

  // Convert rank to real within sector with random offset
  double DealCard(int rank, int suit)
  {
    if(rank<0) rank = 0;
    if(rank>=deckSize) rank = deckSize-1;
    double suitRange = (rangeMax[suit]-rangeMin[suit]) / (double)deckSize;
    return rangeMin[suit] + ((double)rank + __rnd01())*suitRange;
  }

  // Snap to [min,max] and to step if provided
  double SnapToRange(double v, int suit)
  {
    double lo = rangeMin[suit];
    double hi = rangeMax[suit];
    if(v<lo) v=lo; if(v>hi) v=hi;
    double st = rangeStep[suit];
    if(st>0)
    {
      double k = MathRound((v-lo)/st);
      v = lo + k*st;
      if(v<lo) v=lo; if(v>hi) v=hi;
    }
    return v;
  }

  void ShuffleRanks(int &ranks[])
  {
    for(int i=0;i<coords;i++)
    {
      if(__rnd01() < dealerBluff)
        ranks[i] = __rndInt(deckSize);
    }
  }

  // Simple in-place sort by f descending
  void sortDeckDesc(S_RFO_Agent &arr[], int n)
  {
    // Insertion sort (n is small: 2*popSize)
    for(int i=1;i<n;i++)
    {
      S_RFO_Agent key = arr[i];
      int j = i-1;
      while(j>=0 && arr[j].f < key.f)
      {
        arr[j+1] = arr[j];
        j--;
      }
      arr[j+1] = key;
    }
  }
};
