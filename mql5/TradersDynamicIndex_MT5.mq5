//+------------------------------------------------------------------+
//|                                     TradersDynamicIndex_MQL5.mq5 |
//|                                                  Stephen Carmody |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Stephen Carmody"
#property link      "https://www.mql5.com/en/users/onedoubleo"
#property version   "1.00"

#property indicator_separate_window
#property indicator_buffers 6
#property indicator_plots   5
#property indicator_level1 34
#property indicator_level2 50
#property indicator_level3 10
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT
#property indicator_levelwidth 1
#property indicator_color1 clrMediumBlue
#property indicator_label1 "VB High"
#property indicator_type1  DRAW_LINE
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID
#property indicator_color2 clrYellow
#property indicator_label2 "Market Base Line"
#property indicator_type2  DRAW_LINE
#property indicator_width2 2
#property indicator_style2 STYLE_SOLID
#property indicator_color3 clrMediumBlue
#property indicator_label3 "VB Low"
#property indicator_type3  DRAW_LINE
#property indicator_width3 1
#property indicator_style3 STYLE_SOLID
#property indicator_color4 clrGreen
#property indicator_label4 "RSI Price Line"
#property indicator_type4  DRAW_LINE
#property indicator_width4 2
#property indicator_style4 STYLE_SOLID
#property indicator_color5 clrRed
#property indicator_label5 "Trade Signal Line"
#property indicator_type5  DRAW_LINE
#property indicator_width5 2
#property indicator_style5 STYLE_SOLID

input group "---Indicator Variables---"
input int Volatility_Band = 34; // Bollinger Volatility Band: 20-40
input double StdDev = 1.6185; //Bollinger Standard Deviations: 1-3
input int RSI_Period = 13; // RSI Period: 8-25
input int RSI_Price_Line = 2; //RSI Price (Fast) Line Period
input int Trade_Signal_Line = 7; //RSI Signal (Slow) Line MA Period
input int Upper_RSI_Level = 68; //The Overbought Level
input int Lower_RSI_Level = 32; //The Oversold Level

input group "---Indicator Settings---"
input ENUM_MA_METHOD Trade_Signal_Type = MODE_SMA;//Signal Line MA Method
input ENUM_MA_METHOD RSI_Price_Type = MODE_SMA; //RSI Price Line MA Method
input ENUM_APPLIED_PRICE RSI_Price = PRICE_CLOSE; //RSI Price Used for Calulcation
input bool UseAlerts = false; //Alerts - Disable if not using on chart


double RSIBuf[], UpZone[], MdZone[], DnZone[], MaBuf[], MbBuf[];

int MaxPeriod = 0;
int AlertPlayedonBar = 0;
int TDI_handle;
int RSI_handle;

//#property indicator_level3 Upper_RSI_Level;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
{
   IndicatorSetDouble(INDICATOR_LEVELVALUE,2,Upper_RSI_Level);
   IndicatorSetDouble(INDICATOR_LEVELVALUE,0,Lower_RSI_Level);
   IndicatorSetString(INDICATOR_SHORTNAME, "TDI(" + IntegerToString(RSI_Period) + "," + IntegerToString(Volatility_Band) + "," + IntegerToString(RSI_Price_Line) + "," + IntegerToString(Trade_Signal_Line) +  ")");

   SetIndexBuffer(0, UpZone, INDICATOR_DATA);
   SetIndexBuffer(1, MdZone, INDICATOR_DATA);
   SetIndexBuffer(2, DnZone, INDICATOR_DATA);
   SetIndexBuffer(3, MaBuf, INDICATOR_DATA);
   SetIndexBuffer(4, MbBuf, INDICATOR_DATA);
   SetIndexBuffer(5, RSIBuf, INDICATOR_CALCULATIONS);
   
   ArraySetAsSeries(UpZone, true);
   ArraySetAsSeries(MdZone, true);
   ArraySetAsSeries(DnZone, true);
   ArraySetAsSeries(MaBuf, true);
   ArraySetAsSeries(MbBuf, true);
   ArraySetAsSeries(RSIBuf, true);
   
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, 0);

   IndicatorSetInteger(INDICATOR_DIGITS, Digits());
   
 	RSI_handle = iRSI(Symbol(), Period(), RSI_Period, RSI_Price);
   
   MaxPeriod = Volatility_Band + RSI_Period;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, MaxPeriod);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, MaxPeriod);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, MaxPeriod);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, MaxPeriod + RSI_Price_Line);
   PlotIndexSetInteger(4, PLOT_DRAW_BEGIN, MaxPeriod + Trade_Signal_Line);
   Comment(StringFormat("TDI Values:\nVB High: %G\nVB Low: %G\nMarket Line: %G\nSignal Line: %G\nRSI Line: %G\n",0,0,0,0,0));
}


void OnDeinit(const int reason){
   Comment("");
}


//+------------------------------------------------------------------+
//| Traders Dynamic Index                                            |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double& price[]
)
{
   double MA, RSI[];
   ArrayResize(RSI, Volatility_Band);

   int i;
   int counted_bars = prev_calculated;

   // Too few bars to work with.
   if (rates_total < MaxPeriod) return(0);

   i = rates_total - counted_bars;
   if (i > rates_total - MaxPeriod - 1) i = rates_total - MaxPeriod - 1;
 
 	int RSI_bars = CopyBuffer(RSI_handle, 0, 0, rates_total, RSIBuf);
 	if (RSI_bars == -1) return(0);
	
	// Calculate BB on RSI.
   while (i >= 0) 
   {
      MA = 0;
      for (int x = i; x < i + Volatility_Band; x++)
      {
         RSI[x - i] = RSIBuf[x];
         MA += RSIBuf[x] / Volatility_Band;
      }
      double SD = StdDev * StDev(RSI, Volatility_Band);
      UpZone[i] = MA + SD;
      DnZone[i] = MA - SD;
      MdZone[i] = (UpZone[i] + DnZone[i]) / 2;
   	i--;
   }

   i = rates_total - counted_bars;
   if (i > rates_total - MaxPeriod - 1) i = rates_total - MaxPeriod - 1;
 
   // Calculate MAs of RSI.
   while (i >= 0)
   {
      MaBuf[i] = iMAOnArray(RSIBuf, 0, RSI_Price_Line, 0, RSI_Price_Type, i);
      MbBuf[i] = iMAOnArray(RSIBuf, 0, Trade_Signal_Line, 0, Trade_Signal_Type, i);
   	i--;
   }
   
   if ((MbBuf[0] > MdZone[0]) && (MbBuf[1] <= MdZone[1]) && (UseAlerts == true) && (AlertPlayedonBar != 0)) 
   {
      Alert("Bullish cross");
      PlaySound("alert.wav");
      AlertPlayedonBar = rates_total;
   }
   if ((MbBuf[0] < MdZone[0]) && (MbBuf[1] >= MdZone[1]) && (UseAlerts == true) && (AlertPlayedonBar != 0))
   {
      Alert("Bearish cross");
      PlaySound("alert.wav");
      AlertPlayedonBar = rates_total;
   }
   Comment(StringFormat("TDI Values:\nVB High: %G\nVB Low: %G\nMarket Line: %G\nSignal Line: %G\nRSI Line: %G\n",UpZone[0],DnZone[0],MdZone[0],MbBuf[0],MaBuf[0]));
   return(rates_total);
}

// Standard Deviation function.
double StDev(double& Data[], int Per)
{
	return(MathSqrt(Variance(Data, Per)));
}

// Math Variance function.
double Variance(double& Data[], int Per)
{
	double sum = 0, ssum = 0;
	for (int i = 0; i < Per; i++)
	{
		sum += Data[i];
		ssum += MathPow(Data[i], 2);
	}
	return((ssum * Per - sum * sum) / (Per * (Per - 1)));
}


double iMAOnArray(double &Array[], int total, int iMAPeriod, int ma_shift, ENUM_MA_METHOD ma_method, int Shift)
{
	double buf[];
	if ((total > 0) && (total <= iMAPeriod)) return(0);
	if (total == 0) total = ArraySize(Array);
	if (ArrayResize(buf, total) < 0) return(0);
	
	switch(ma_method)
	{
		// Simplified SMA. No longer works with ma_shift parameter.
		case MODE_SMA:
		{
			double sum = 0;
			for (int i = Shift; i < Shift + iMAPeriod; i++)
				sum += Array[i] / iMAPeriod;
			return(sum);
		}
		case MODE_EMA:
		{
			double pr = 2.0 / (iMAPeriod + 1);
			int pos = total - 2;
			while (pos >= 0)
			{
				if (pos == total - 2) buf[pos + 1] = Array[pos + 1];
				buf[pos] = Array[pos] * pr + buf[pos + 1] * (1 - pr);
				pos--;
			}
			return(buf[Shift + ma_shift]);
		}
		case MODE_SMMA:
		{
			double sum = 0;
			int i, k, pos;
			pos = total - iMAPeriod;
			while (pos >= 0)
			{
				if (pos == total - iMAPeriod)
				{
					for (i = 0, k = pos; i < iMAPeriod; i++, k++)
					{
						sum += Array[k];
						buf[k] = 0;
					}
				}
				else sum = buf[pos + 1] * (iMAPeriod - 1) + Array[pos];
				buf[pos] = sum / iMAPeriod;
				pos--;
			}
			return(buf[Shift + ma_shift]);
		}
		case MODE_LWMA:
		{
			double sum = 0.0, lsum = 0.0;
			double price;
			int i, weight = 0, pos = total - 1;
			for (i = 1; i <= iMAPeriod; i++, pos--)
			{
				price = Array[pos];
				sum += price * i;
				lsum += price;
				weight += i;
			}
			pos++;
			i = pos + iMAPeriod;
			while (pos >= 0)
			{
				buf[pos] = sum / weight;
				if (pos == 0) break;
				pos--;
				i--;
				price = Array[pos];
				sum = sum - lsum + price * iMAPeriod;
				lsum -= Array[i];
				lsum += price;
			}
			return(buf[Shift + ma_shift]);
		}
		default: return(0);
	}
	return(0);
}
//+------------------------------------------------------------------+