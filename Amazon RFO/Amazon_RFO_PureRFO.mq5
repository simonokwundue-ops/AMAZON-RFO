//+------------------------------------------------------------------+
//|                                             Amazon_RFO_PureRFO.mq5|
//| Pure RFO-driven decisioning (no fixed tech weights)              |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>
#include <RFO\\RFO_Core.mqh>

CTrade trade;

//--- Risk/guards
input double Inp_MinRisk          = 0.50;
input double Inp_MaxRisk          = 5.0;
input double Inp_SL_Pips          = 100.0;
input double Inp_TP_Pips          = 200.0;
input int    Inp_CooldownSeconds  = 60;
input double Inp_MaxSpreadPips    = 3.0;

//--- RFO core config
input int    RFO_PopSize          = 60;
input int    RFO_DeckSectors      = 512;
input double RFO_BluffProb        = 0.04;
input int    RFO_EvalsPerTick     = 16;

// Decision vector (coords)
// [0] dirBias [-1..1], [1] entryThresh [0..0.6], [2] exitThresh [0..0.6], [3] riskScale [0..1]

CRFO    RFO;
int     g_coords = 4;
double  g_min[];
double  g_max[];
double  g_step[];

// Minimal indicators for state
int hMA_M1, hRSI_M1;
datetime lastTrade=0;

int OnInit()
{
  hMA_M1  = iMA(_Symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
  hRSI_M1 = iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);
  if(hMA_M1==INVALID_HANDLE || hRSI_M1==INVALID_HANDLE) return INIT_FAILED;

  ArrayResize(g_min, g_coords); ArrayResize(g_max, g_coords); ArrayResize(g_step, g_coords);
  g_min[0]=-1.0; g_max[0]= 1.0; g_step[0]=0.02; // dirBias
  g_min[1]= 0.0; g_max[1]= 0.6; g_step[1]=0.01; // entryThresh
  g_min[2]= 0.0; g_max[2]= 0.6; g_step[2]=0.01; // exitThresh
  g_min[3]= 0.0; g_max[3]= 1.0; g_step[3]=0.01; // riskScale

  if(!RFO.Init(g_min,g_max,g_step,g_coords,RFO_PopSize,RFO_DeckSectors,RFO_BluffProb)) return INIT_FAILED;
  Print("[PureRFO] Init OK. Pop=",RFO_PopSize);
  return INIT_SUCCEEDED;
}

void OnTick()
{
  if(lastTrade!=0 && (TimeCurrent()-lastTrade)<Inp_CooldownSeconds) return;
  double spreadPips=(SymbolInfoDouble(_Symbol,SYMBOL_ASK)-SymbolInfoDouble(_Symbol,SYMBOL_BID))/_Point;
  if(spreadPips>Inp_MaxSpreadPips) return;

  double ma1[], rsi1[];
  if(CopyBuffer(hMA_M1,0,0,1,ma1)<=0 || CopyBuffer(hRSI_M1,0,0,1,rsi1)<=0) return;
  double price=SymbolInfoDouble(_Symbol,SYMBOL_BID);

  // Market state proxy in [-~1..~1]
  double marketState = (ma1[0]>0 ? (price-ma1[0])/ma1[0] : 0.0) - (rsi1[0]-50.0)/50.0;

  // Progress RFO
  RFO.StartGeneration();
  int evals = MathMin(RFO_EvalsPerTick, RFO.Candidates());
  double cand[];
  for(int i=0;i<evals;i++)
  {
    RFO.GetCandidate(i, cand);
    double dirBias   = cand[0];      // [-1..1]
    double entryT    = cand[1];      // [0..0.6]
    double exitT     = cand[2];      // [0..0.6]
    double riskScale = cand[3];      // [0..1]

    // Fitness: alignment between bias and state, with moderate thresholds favored
    double align = 1.0 - MathAbs((marketState>=0?1.0:-1.0) - (dirBias>=0?1.0:-1.0))/2.0; // 1 if same sign
    double confidence = MathMin(1.0, MathAbs(marketState)*2.0);
    double stability = 1.0 - 0.5*(entryT+exitT)/0.6;
    double fitness = 0.5*align + 0.3*confidence + 0.2*stability;
    RFO.SetFitness(i, fitness);
  }
  RFO.FinishGeneration();

  double best[]; RFO.BestParams(best);
  double dirBias   = best[0];
  double entryT    = best[1];
  double exitT     = best[2];
  double riskScale = best[3];

  // Pure RFO signal: state adjusted by bias
  double score = marketState + 0.25*dirBias;
  int signal=0;
  if(score >  entryT) signal=1; else if(score < -entryT) signal=-1;

  // Manage open position exits
  if(PositionSelect(_Symbol))
  {
    long type=PositionGetInteger(POSITION_TYPE);
    bool close=false;
    if(type==POSITION_TYPE_BUY  && score < -exitT) close=true;
    if(type==POSITION_TYPE_SELL && score >  exitT) close=true;
    if(close) { trade.PositionClose(_Symbol); return; }
  }

  if(signal==0) return;

  double riskPct = Inp_MinRisk + (Inp_MaxRisk-Inp_MinRisk)*MathMax(0.0,MathMin(1.0,riskScale));
  double lots = CalcLots(Inp_SL_Pips, riskPct);
  bool sent=false;
  if(signal==1)
  {
    double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
    sent=trade.Buy(lots,_Symbol,ask,
                   ask-Inp_SL_Pips*_Point,
                   ask+Inp_TP_Pips*_Point,
                   "PURE_RFO");
  }
  else if(signal==-1)
  {
    double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
    sent=trade.Sell(lots,_Symbol,bid,
                    bid+Inp_SL_Pips*_Point,
                    bid-Inp_TP_Pips*_Point,
                    "PURE_RFO");
  }
  if(sent) lastTrade=TimeCurrent();
}

double CalcLots(double slPips,double riskPct)
{
  if(slPips<=0.0) return SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
  double balance=AccountInfoDouble(ACCOUNT_BALANCE);
  double riskDollar=balance*(riskPct/100.0);
  double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
  double tickSize =SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
  double point    =SymbolInfoDouble(_Symbol,SYMBOL_POINT);
  if(tickValue<=0.0||tickSize<=0.0||point<=0.0)
    return SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
  double slPoints=slPips*point;
  double pipValuePerLot=tickValue/tickSize;
  double lots=riskDollar/(slPoints*pipValuePerLot);
  double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
  double maxLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
  double stepLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
  if(stepLot>0.0) lots=MathFloor(lots/stepLot)*stepLot;
  lots=MathMax(minLot,MathMin(maxLot,lots));
  return NormalizeDouble(lots,2);
}

void OnDeinit(const int reason)
{
  Print("[PureRFO] Deinit. BestF=",DoubleToString(RFO.BestFitness(),4));
}


