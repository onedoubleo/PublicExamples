//+------------------------------------------------------------------+
//|                                           TrailingSL_Example.mq5 |
//|                                                  Stephen Carmody |
//|                                                                  |
//+------------------------------------------------------------------+

#property copyright "Stephen Carmody"
#property link      "https://github.com/onedoubleo/mql5_examples"
#property version   "1.00"


//
//Very Basic Example showing implementation of Trailing Stop Loss
//Expert will randomly select buy/sell randomly if no orders open
//If price on tick is higher/lower than SL_Gap then the SL will be updated
//


//Inputs
input double   Lots=0.01;
input double   sl_points = 1000;
input double   sl_gap = 750;
input double   tp_points = 750;

//Trading handler
#include<Trade\Trade.mqh>
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+


int OnInit()
{
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   int positions = PositionsTotal();
   MqlRates PriceArray[];
   ArraySetAsSeries(PriceArray, true);
   int Data =  CopyRates(Symbol(),Period(),0,3,PriceArray);
   double Ask=NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   double Bid=NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);
   int tick_lag = 0;
   int tick_count = 0;
   bool pos_open = false;
   if(positions == 0){
      if(pos_open == false){
         double random = rand();
         if(random < (32767/2)){
            trade.Buy(Lots,_Symbol,Ask,(Ask-sl_points * _Point),(Ask+tp_points * _Point),"Random Buy");
            pos_open = true;
         }else{
            trade.Sell(Lots,_Symbol,Bid,(Ask+(sl_points * _Point)),(Ask-tp_points * _Point),"Random Sell");
            pos_open = true;
         }
      }else{
         tick_count++;
         if(tick_count > tick_lag){
            pos_open = false;
            tick_count = 0;
         }
      }
   }else{   
      ulong ticket  = PositionGetTicket(0); 
      double cur_sl = PositionGetDouble(POSITION_SL);
      double cur_tp = PositionGetDouble(POSITION_TP);
      double new_sl = 0.0;
      double profit = PositionGetDouble(POSITION_PROFIT);
      if(profit > 0.0){
         if( PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
            //If the price is within the gap to the price and greater than the profit point
            if((Bid - cur_sl) > (sl_gap * _Point) ){
               new_sl = Bid - (sl_gap*_Point);
               trade.PositionModify(ticket,new_sl,cur_tp);
            }
         }else{
            if((cur_sl - Ask) > (sl_gap * _Point) ){
               new_sl = Ask + (sl_gap*_Point);
               trade.PositionModify(ticket,new_sl,cur_tp);
            }
         }
      }        
   }
}
//+------------------------------------------------------------------+
