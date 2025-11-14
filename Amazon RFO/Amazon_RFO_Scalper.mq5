//+------------------------------------------------------------------+
//|                                       Amazon_RFO_Scalper.mq5     |
//|         RFO Scalper with Dual Flask Integration                  |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

CTrade trade;

//--- Risk and control inputs
input double Inp_MinRisk       = 0.50;
input double Inp_MaxRisk       = 5.0;
input double Inp_SL_Pips       = 100.0;
input double Inp_TP_Pips       = 200.0;
input int    Inp_CooldownSeconds = 60;
input double Inp_MaxSpreadPips = 3.0;

//--- RFO adaptive layer inputs
input int    RFO_PopSize      = 300;
input double RFO_BluffProb    = 0.03;
input double RFO_EntryThresh  = 0.25;
input double RFO_ExitThresh   = -0.35;
input double RFO_LearningRate = 0.10;
string       RFO_File         = "Amazon_RFO_State.bin";

//--- Global state
int hATR_M15, hMA_M15, hRSI_M15, hMACD_M15;
int hATR_M5,  hMA_M5,  hRSI_M5;
int hATR_M1,  hMA_M1,  hRSI_M1;
datetime lastTrade = 0;

double  rfoFitness[];
bool    rfoInit = false;

//+------------------------------------------------------------------+
//| Initialize indicator handles and load RFO state                  |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- initialize indicator handles
   hATR_M15 = iATR(_Symbol, PERIOD_M15, 14);
   hMA_M15  = iMA(_Symbol, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE);
   hRSI_M15 = iRSI(_Symbol, PERIOD_M15, 14, PRICE_CLOSE);
   hMACD_M15= iMACD(_Symbol, PERIOD_M15, 12, 26, 9, PRICE_CLOSE);

   hATR_M5  = iATR(_Symbol, PERIOD_M5, 14);
   hMA_M5   = iMA(_Symbol, PERIOD_M5, 20, 0, MODE_EMA, PRICE_CLOSE);
   hRSI_M5  = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);

   hATR_M1  = iATR(_Symbol, PERIOD_M1, 14);
   hMA_M1   = iMA(_Symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
   hRSI_M1  = iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);

   if(hATR_M15==INVALID_HANDLE||hMA_M15==INVALID_HANDLE||hRSI_M15==INVALID_HANDLE||hMACD_M15==INVALID_HANDLE||
      hATR_M5==INVALID_HANDLE ||hMA_M5==INVALID_HANDLE ||hRSI_M5==INVALID_HANDLE ||
      hATR_M1==INVALID_HANDLE ||hMA_M1==INVALID_HANDLE ||hRSI_M1==INVALID_HANDLE)
      return INIT_FAILED;

   //--- initialize RFO memory
   MathSrand((uint)TimeLocal());
   int fh = FileOpen(RFO_File, FILE_READ|FILE_BIN);
   if(fh!=INVALID_HANDLE)
     {
      int sz=FileSize(fh)/sizeof(double);
      ArrayResize(rfoFitness,sz);
      FileReadArray(fh,rfoFitness,0,sz);
      FileClose(fh);
      rfoInit=true;
      Print("♣ RFO memory loaded (",sz," genomes).");
     }
   else
     {
      ArrayResize(rfoFitness,RFO_PopSize);
      for(int i=0;i<RFO_PopSize;i++)
         rfoFitness[i]=((double)MathRand()/32767.0-0.5);
      rfoInit=true;
      Print("♣ RFO memory initialized fresh.");
     }

   Print("✅ Amazon RFO Scalper initialized.");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Main tick logic                                                  |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- early exit check (RFO protective logic)
   if(PositionSelect(_Symbol))
     {
      double rfoScore=CalculateRFOScore();
      long type=PositionGetInteger(POSITION_TYPE);
      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double bid =SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double ask =SymbolInfoDouble(_Symbol,SYMBOL_ASK);

      bool close=false;
      if(type==POSITION_TYPE_BUY  && rfoScore<RFO_ExitThresh && bid>open-Inp_SL_Pips*_Point/2)
         close=true;
      if(type==POSITION_TYPE_SELL && rfoScore>-RFO_ExitThresh && ask<open+Inp_SL_Pips*_Point/2)
         close=true;

      if(close)
        {
         Print("♣ RFO exit signal: ",DoubleToString(rfoScore,2));
         trade.PositionClose(_Symbol);
         return;
        }
     }

   //--- cooldown and spread control
   if(lastTrade!=0 && (TimeCurrent()-lastTrade)<Inp_CooldownSeconds)
      return;
   double spreadPips=(SymbolInfoDouble(_Symbol,SYMBOL_ASK)-SymbolInfoDouble(_Symbol,SYMBOL_BID))/_Point;
   if(spreadPips>Inp_MaxSpreadPips)
      return;

   //--- fetch indicator data
   double ma_m15[],rsi_m15[],macd_m15[];
   double ma_m5[],rsi_m5[];
   double ma_m1[],rsi_m1[];

   if(CopyBuffer(hMA_M15,0,0,1,ma_m15)<=0 || CopyBuffer(hRSI_M15,0,0,1,rsi_m15)<=0 || CopyBuffer(hMACD_M15,0,0,1,macd_m15)<=0) return;
   if(CopyBuffer(hMA_M5,0,0,1,ma_m5)<=0  || CopyBuffer(hRSI_M5,0,0,1,rsi_m5)<=0) return;
   if(CopyBuffer(hMA_M1,0,0,1,ma_m1)<=0  || CopyBuffer(hRSI_M1,0,0,1,rsi_m1)<=0) return;

   double price=SymbolInfoDouble(_Symbol,SYMBOL_BID);

   //--- indicator consensus (flexible scoring)
   double m15_score = 0;
   double m5_score = 0;
   double m1_score = 0;
   
   // M15 scoring
   if(price>ma_m15[0]) m15_score += 0.4;
   if(macd_m15[0]>0) m15_score += 0.3;
   if(rsi_m15[0]<70 && rsi_m15[0]>30) m15_score += 0.3;
   if(price<ma_m15[0]) m15_score -= 0.4;
   if(macd_m15[0]<0) m15_score -= 0.3;
   
   // M5 scoring
   if(price>ma_m5[0]) m5_score += 0.5;
   if(rsi_m5[0]<65 && rsi_m5[0]>35) m5_score += 0.5;
   if(price<ma_m5[0]) m5_score -= 0.5;
   
   // M1 scoring
   if(price>ma_m1[0]) m1_score += 0.5;
   if(rsi_m1[0]<60 && rsi_m1[0]>40) m1_score += 0.5;
   if(price<ma_m1[0]) m1_score -= 0.5;
   
   double techScore = (m15_score * 0.5) + (m5_score * 0.3) + (m1_score * 0.2);
   
   int signal=0;
   if(techScore > 0.3) signal = 1;
   else if(techScore < -0.3) signal = -1;

   //--- compute RFO score
   double rfoScore=CalculateRFOScore();

   //--- combine signals (70% RFO + 30% technical)
   double combined = 0.7*rfoScore + 0.3*techScore;
   if(combined > 0.15)      signal = 1;
   else if(combined < -0.15) signal = -1;
   else                      signal = 0;

   if(signal==0) return; // neutral decision

   //--- internal confidence based on signal strength
   double confidence = MathMin(1.0, MathAbs(combined) * 2.0);

   //--- apply adaptive risk modulation
   double baseRiskPct = Inp_MinRisk + (Inp_MaxRisk-Inp_MinRisk) * confidence;
   double adj = 1.0 + rfoScore * 0.15;
   adj = MathMax(0.9, MathMin(1.1, adj));
   double riskPct = baseRiskPct * adj;

   //--- lot calculation and execution
   double lots=CalcLots(Inp_SL_Pips,riskPct);
   bool sent=false;
   if(signal==1)
     {
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      sent=trade.Buy(lots,_Symbol,ask,
                     ask-Inp_SL_Pips*_Point,
                     ask+Inp_TP_Pips*_Point,
                     StringFormat("RFO_SCALP:%.2f",confidence));
     }
   else if(signal==-1)
     {
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      sent=trade.Sell(lots,_Symbol,bid,
                      bid+Inp_SL_Pips*_Point,
                      bid-Inp_TP_Pips*_Point,
                      StringFormat("RFO_SCALP:%.2f",confidence));
     }

   if(sent)
     {
      lastTrade=TimeCurrent();
      Print("✅ Trade sent. RFO=",DoubleToString(rfoScore,2),
            " TechScore=",DoubleToString(techScore,2),
            " Combined=",DoubleToString(combined,2),
            " Confidence=",DoubleToString(confidence,2),
            " Risk=",DoubleToString(riskPct,2),"%");
     }
}

//+------------------------------------------------------------------+
//| RFO adaptive scoring                                             |
//+------------------------------------------------------------------+
double CalculateRFOScore()
{
   if(!rfoInit) return 0.0;

   double ma_m1[], rsi_m1[];
   if(CopyBuffer(hMA_M1,0,0,1,ma_m1)<=0 || CopyBuffer(hRSI_M1,0,0,1,rsi_m1)<=0)
      return 0.0;

   double price=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double marketState=(price-ma_m1[0])/ma_m1[0] - (rsi_m1[0]-50)/50.0;

   for(int i=0;i<ArraySize(rfoFitness);i++)
     {
      double shift=((double)MathRand()/32767.0-0.5)*0.05;
      if((double)MathRand()/32767.0<RFO_BluffProb) shift*=-2;
      rfoFitness[i]=(1.0-RFO_LearningRate)*rfoFitness[i] +
                    RFO_LearningRate*(marketState+shift);
      rfoFitness[i]=MathMax(-1.0,MathMin(1.0,rfoFitness[i]));
     }

   double mean=0;
   for(int i=0;i<ArraySize(rfoFitness);i++) mean+=rfoFitness[i];
   return mean/ArraySize(rfoFitness);
}



//+------------------------------------------------------------------+
//| Lot calculation                                                  |
//+------------------------------------------------------------------+
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
   if(stepLot>0.0)
      lots=MathFloor(lots/stepLot)*stepLot;
   lots=MathMax(minLot,MathMin(maxLot,lots));

   return NormalizeDouble(lots,2);
}

//+------------------------------------------------------------------+
//| Save RFO memory on deinit                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(ArraySize(rfoFitness)>0)
     {
      int f=FileOpen(RFO_File,FILE_WRITE|FILE_BIN);
      if(f!=INVALID_HANDLE)
        {
         FileWriteArray(f,rfoFitness,0,ArraySize(rfoFitness));
         FileClose(f);
        }
     }
   Print("♣ RFO state saved. Goodbye.");
}
//+------------------------------------------------------------------+