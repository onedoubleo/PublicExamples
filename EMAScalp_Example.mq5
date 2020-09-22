//+------------------------------------------------------------------+
//|                                           EMAScalp_Example.mq5 |
//|                                                  Stephen Carmody |
//|                                                                  |
//+------------------------------------------------------------------+

#property copyright "Stephen Carmody"
#property link      "https://github.com/onedoubleo/mql5_examples"
#property version   "1.00"

//
//Very Basic Example showing implementation of EMA Scalping Strategy 
//Script will place buy/sell depending on crossover of the EMA lines. 
//No account handling, position checks or other good managemnt practices are not used in this example
//

//Trading Handler
#include <Trade\Trade.mqh>
CTrade trade;

//MA & Trade Settings
input int FastMA = 50; //Fast MA Period
input int SlowMA = 150; //Slow MA pERIOS
input int SLPoints = 1000; //Stop Loss Points
input int TPPoints = 500;//Take Profile Points
input double Lots = 0.01; //Beginning Lot Size

bool     buy_open=false,sell_open=false;
MqlRates          rates[];
MqlDateTime       trade_time;
bool newBar = false;

int OnInit()
{
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   newBar = isNewBar();
   if(newBar==true){
      int positions = PositionsTotal();
      MqlRates PriceArray[];
      ArraySetAsSeries(PriceArray, true);
      int Data =  CopyRates(Symbol(),Period(),0,3,PriceArray);
      double Ask=NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
      double Bid=NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);
      static datetime Old_Time;
      static datetime Trade_Time[1];
      datetime New_Time[1];
      bool IsNewBar=false;
      static int NewBarCounter;
      int copied =CopyTime(_Symbol,_Period,0,1,New_Time);
      if(positions == 0 ){
         string EnterSignal = CrossOverEntrySignal();
         if(EnterSignal == "buy"){
            trade.Buy(Lots,_Symbol,Ask,(Ask-SLPoints * _Point),(Ask+TPPoints * _Point),"Scalp Buy");            
            buy_open=true;
         }
         if(EnterSignal =="sell"){
            trade.Sell(Lots,_Symbol,Bid,(Ask+(SLPoints * _Point)),(Ask-TPPoints * _Point),"Scalp Sell");
            sell_open = true;  
         } 
      }
      if(positions == 1){
         //Check the exit signal
         string SlowExit = CrossOverExitSignal();      
            if(buy_open==true && SlowExit == "buyexit"){
               trade.PositionClose(_Symbol,5);
               buy_open = false;
            }
            if(sell_open==true && SlowExit =="sellexit"){
               trade.PositionClose(_Symbol,5);
               sell_open = false;
            }  
      }
    }
  }
//+------------------------------------------------------------------+

//Checks for EMA Scalping Exit Signal
string CrossOverExitSignal()
{
   string signal = "";
   double myFastArray[],mySlowArray[];
   int fastDef = iMA(_Symbol,_Period,FastMA,0,MODE_EMA,PRICE_CLOSE);
   int slowDef = iMA(_Symbol,_Period,SlowMA,0,MODE_EMA,PRICE_CLOSE);
   ArraySetAsSeries(myFastArray,true);
   ArraySetAsSeries(mySlowArray,true);
   CopyBuffer(fastDef,0,0,3,myFastArray);
   CopyBuffer(slowDef,0,0,3,mySlowArray);
   if(myFastArray[1] < mySlowArray[1] && myFastArray[0] > mySlowArray[0]){
      signal = "sellexit";
   }
   if(myFastArray[0] > mySlowArray[0] && myFastArray[1] < mySlowArray[1]){
      signal = "buyexit";
   }
   return signal;
}
//Checks for EMA Scalping Entry Signal
string CrossOverEntrySignal()
{
   string signal = "";
   double myFastArray[],mySlowArray[];
   int fastDef = iMA(_Symbol,_Period,FastMA,0,MODE_EMA,PRICE_CLOSE);
   int slowDef = iMA(_Symbol,_Period,SlowMA,0,MODE_EMA,PRICE_CLOSE);
   ArraySetAsSeries(myFastArray,true);
   ArraySetAsSeries(mySlowArray,true);
   CopyBuffer(fastDef,0,0,3,myFastArray);
   CopyBuffer(slowDef,0,0,3,mySlowArray);
   if(myFastArray[0] > mySlowArray[0] && myFastArray[1] < mySlowArray[1]){
      signal = "buy";
      double ema_gap = myFastArray[0]-mySlowArray[0];
      string output = DoubleToString(ema_gap);
      PrintFormat("EMA Gap: %s",output);
   }
   if(myFastArray[1] > mySlowArray[1] && myFastArray[0] < mySlowArray[0]){
      signal = "sell";
      double ema_gap = myFastArray[0]-mySlowArray[0];
      string output = DoubleToString(ema_gap);
      PrintFormat("EMA Gap: %s",output);
   }
   return signal;
}
//Checks for new Candle
bool isNewBar()
{
   static datetime last_time = 0;
   datetime lastbar_time=SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);
   if(last_time==0)
     {
      last_time=lastbar_time;
      return(false);
     }
   if(last_time!=lastbar_time)
     {
      last_time=lastbar_time;
      return(true);
     }
   return(false);
}