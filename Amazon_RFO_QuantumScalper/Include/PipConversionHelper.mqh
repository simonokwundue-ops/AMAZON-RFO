//+------------------------------------------------------------------+
//|                                         PipConversionHelper.mqh  |
//|                                    Amazon RFO Quantum Scalper    |
//|                         Currency Pair Aware Pip/Point Calculator |
//+------------------------------------------------------------------+
#property copyright "Amazon RFO Quantum Scalper"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Pip/Point Conversion Helper                                       |
//| Handles currency pair-specific pip calculations                  |
//| Supports 4-digit and 5-digit brokers                            |
//| Handles JPY pairs, metals (XAU, XAG), crypto, CFDs              |
//+------------------------------------------------------------------+
class CPipConversionHelper
{
private:
   string m_symbol;
   int m_digits;
   double m_point;
   double m_pipSize;
   bool m_isPipBased;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CPipConversionHelper(string symbol = "")
   {
      m_symbol = (symbol == "") ? _Symbol : symbol;
      Initialize();
   }
   
   //+------------------------------------------------------------------+
   //| Initialize for symbol                                            |
   //+------------------------------------------------------------------+
   void Initialize(string symbol = "")
   {
      if(symbol != "")
         m_symbol = symbol;
         
      m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      m_point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      // Determine if this is a pip-based pair (most forex) or point-based (JPY, metals)
      m_isPipBased = IsPipBasedPair(m_symbol);
      
      // Calculate pip size
      if(m_isPipBased)
      {
         // For most forex pairs: 1 pip = 10 points (5-digit) or 1 point (4-digit)
         if(m_digits == 5 || m_digits == 3)
            m_pipSize = m_point * 10.0;
         else
            m_pipSize = m_point;
      }
      else
      {
         // For JPY pairs and some metals: 1 pip = 1 point typically
         m_pipSize = m_point;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check if pair uses pip-based convention                         |
   //+------------------------------------------------------------------+
   bool IsPipBasedPair(string symbol)
   {
      // JPY pairs use 2 decimal places typically (pips = points)
      if(StringFind(symbol, "JPY") >= 0)
         return false;
         
      // Metals like XAU, XAG often use different convention
      if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "XAG") >= 0)
         return true;  // Treat as pip-based with 5 decimals
         
      // Most forex pairs are pip-based
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get pip value for given lot size                                |
   //+------------------------------------------------------------------+
   double GetPipValue(double lotSize, string symbol = "")
   {
      if(symbol == "")
         symbol = m_symbol;
         
      // Calculate tick value
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      
      if(tickSize == 0)
         return 0;
         
      // Pip value = (tick value / tick size) * pip size * lot size
      double pipValue = (tickValue / tickSize) * GetPipSize(symbol) * lotSize;
      
      return pipValue;
   }
   
   //+------------------------------------------------------------------+
   //| Get point value for given lot size                              |
   //+------------------------------------------------------------------+
   double GetPointValue(double lotSize, string symbol = "")
   {
      if(symbol == "")
         symbol = m_symbol;
         
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      
      if(tickSize == 0)
         return 0;
         
      double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double pointValue = (tickValue / tickSize) * pointSize * lotSize;
      
      return pointValue;
   }
   
   //+------------------------------------------------------------------+
   //| Convert money to pips                                           |
   //+------------------------------------------------------------------+
   double MoneyToPips(double money, double lotSize, string symbol = "")
   {
      if(symbol == "")
         symbol = m_symbol;
         
      double pipValue = GetPipValue(lotSize, symbol);
      
      if(pipValue == 0)
         return 0;
         
      return money / pipValue;
   }
   
   //+------------------------------------------------------------------+
   //| Convert pips to money                                           |
   //+------------------------------------------------------------------+
   double PipsToMoney(double pips, double lotSize, string symbol = "")
   {
      if(symbol == "")
         symbol = m_symbol;
         
      double pipValue = GetPipValue(lotSize, symbol);
      return pips * pipValue;
   }
   
   //+------------------------------------------------------------------+
   //| Convert points to pips                                          |
   //+------------------------------------------------------------------+
   double PointsToPips(double points, string symbol = "")
   {
      if(symbol == "")
         symbol = m_symbol;
         
      double pipSize = GetPipSize(symbol);
      double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      if(pointSize == 0)
         return 0;
         
      return points * (pointSize / pipSize);
   }
   
   //+------------------------------------------------------------------+
   //| Convert pips to points                                          |
   //+------------------------------------------------------------------+
   double PipsToPoints(double pips, string symbol = "")
   {
      if(symbol == "")
         symbol = m_symbol;
         
      double pipSize = GetPipSize(symbol);
      double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      if(pipSize == 0)
         return 0;
         
      return pips * (pipSize / pointSize);
   }
   
   //+------------------------------------------------------------------+
   //| Get pip size for symbol                                         |
   //+------------------------------------------------------------------+
   double GetPipSize(string symbol = "")
   {
      if(symbol == "" || symbol == m_symbol)
         return m_pipSize;
         
      // Calculate for different symbol
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      bool isPipBased = IsPipBasedPair(symbol);
      
      if(isPipBased)
      {
         if(digits == 5 || digits == 3)
            return point * 10.0;
         else
            return point;
      }
      else
      {
         return point;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get digits for symbol                                           |
   //+------------------------------------------------------------------+
   int GetDigits(string symbol = "")
   {
      if(symbol == "")
         return m_digits;
      return (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   }
   
   //+------------------------------------------------------------------+
   //| Get point size for symbol                                       |
   //+------------------------------------------------------------------+
   double GetPointSize(string symbol = "")
   {
      if(symbol == "")
         return m_point;
      return SymbolInfoDouble(symbol, SYMBOL_POINT);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate distance in pips between two prices                   |
   //+------------------------------------------------------------------+
   double PriceDistanceInPips(double price1, double price2, string symbol = "")
   {
      if(symbol == "")
         symbol = m_symbol;
         
      double pipSize = GetPipSize(symbol);
      if(pipSize == 0)
         return 0;
         
      return MathAbs(price1 - price2) / pipSize;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate price from pips distance                              |
   //+------------------------------------------------------------------+
   double AddPipsToPrice(double price, double pips, bool isBuy, string symbol = "")
   {
      if(symbol == "")
         symbol = m_symbol;
         
      double pipSize = GetPipSize(symbol);
      double priceChange = pips * pipSize;
      
      if(isBuy)
         return price + priceChange;
      else
         return price - priceChange;
   }
   
   //+------------------------------------------------------------------+
   //| Normalize price to symbol digits                                |
   //+------------------------------------------------------------------+
   double NormalizePrice(double price, string symbol = "")
   {
      if(symbol == "")
         symbol = m_symbol;
         
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      return NormalizeDouble(price, digits);
   }
   
   //+------------------------------------------------------------------+
   //| Normalize pips value                                            |
   //+------------------------------------------------------------------+
   double NormalizePips(double pips)
   {
      return NormalizeDouble(pips, 1);  // 1 decimal for pips
   }
   
   //+------------------------------------------------------------------+
   //| Get symbol name                                                  |
   //+------------------------------------------------------------------+
   string GetSymbol() { return m_symbol; }
};
//+------------------------------------------------------------------+
