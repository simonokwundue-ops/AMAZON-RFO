# Amazon RFO Quantum Scalper - Quick Start Guide

## 🚀 What Is This?

A revolutionary MetaTrader 5 Expert Advisor that implements **quantum-style rapid scalping** with:
- **Multiple micro-positions** opened simultaneously
- **Self-optimization** that learns from performance
- **Persistent memory** that survives restarts
- **Market regime adaptation** for all conditions
- **Recovery strategies** focused on bouncing back from losses

## 📦 Quick Installation

### 1. Copy Files
Copy the entire `Amazon RFO` folder to:
```
C:\Users\User\AppData\Roaming\MetaQuotes\Terminal\<YOUR_TERMINAL_ID>\MQL5\Experts\
```

### 2. Compile
- Open MetaEditor
- Open `Amazon_RFO_QuantumScalper.mq5`
- Press F7 to compile

### 3. Use
- Attach to any M1/M5/M15 chart
- Enable AutoTrading
- Let it run!

## ⚡ Key Features

### Quantum Analysis
Performs **5 simultaneous analyses** per tick, like quantum superposition, then reaches decision by consensus.

### Self-Optimizing
Automatically optimizes parameters **every 20 trades** based on actual performance.

### Persistent Memory
Your EA's learning **never resets** - survives EA changes, terminal restarts, even crashes.

### Multi-Position System
Opens **multiple micro-positions** simultaneously for diversified scalping.

### Market Regime Detection
Automatically detects and adapts to:
- **Ranging markets**: More positions, tight TP/SL
- **Trending markets**: Fewer positions, ride trends
- **Volatile markets**: Conservative approach

### Recovery After Losses
Not focused on being right, focused on **recovering after being wrong**:
- Reduces risk after losses
- Increases TP after losses
- Activates hedging in severe drawdown

## 🎯 Recommended Settings

### Conservative
```
BaseRisk = 0.5%
MaxPositions = 3
MinTPPips = 5
MaxTPPips = 20
```

### Balanced (Default)
```
BaseRisk = 1.0%
MaxPositions = 5
MinTPPips = 5
MaxTPPips = 30
```

### Aggressive
```
BaseRisk = 1.5%
MaxPositions = 7
MinTPPips = 5
MaxTPPips = 40
```

## 📊 What to Expect

### First 20 Trades
- EA learns your symbol's characteristics
- Parameters start at defaults
- Performance may vary

### After First Optimization
- EA adapts to what's working
- Parameters fine-tuned automatically
- Performance typically improves

### Long-Term
- Continuous learning and adaptation
- Better handling of different market conditions
- Self-correcting after drawdowns

## 🔧 Files Included

```
Amazon RFO/
├── Amazon_RFO_QuantumScalper.mq5          # Main EA
├── QuantumScalper_Core.mqh                # Quantum engine
├── PersistentMemory.mqh                   # Memory system
├── MarketRegime.mqh                       # Regime detection
├── PositionManager.mqh                    # Position management
├── PerformanceTracker.mqh                 # Performance & optimization
├── RFO_Core.mqh                           # RFO algorithm
├── Amazon_RFO_QuantumScalper.ini          # Configuration
├── Amazon_RFO_QuantumScalper.set          # Preset settings
├── QUANTUM_SCALPER_DOCUMENTATION.md       # Full documentation
└── README_QUANTUM_SCALPER.md              # This file
```

## 🎮 How to Use

### Step 1: Start
1. Attach EA to chart
2. Check Expert tab for initialization message
3. Verify memory loaded (or "starting fresh" if first time)

### Step 2: Monitor
Watch Expert log for:
- Position openings (✓)
- Trade results (✓ WIN / ✗ LOSS)
- Performance summary
- Optimization reports (every 20 trades)

### Step 3: Adjust (Optional)
- First 20 trades: Don't change anything
- After optimization: Review suggested changes
- Tweak risk if needed based on account size

## 📈 Performance Tracking

The EA prints performance summary after each trade:
```
Trades: 45 | WR: 62.2% | PF: 1.58 | Profit: +523.45
```

- **Trades**: Total number of closed trades
- **WR**: Win rate percentage
- **PF**: Profit factor (gross profit / gross loss)
- **Profit**: Net profit/loss

## 🛡️ Risk Management

### Built-In Protection
- Maximum spread filter (3 pips default)
- Maximum position limit (5 default)
- Dynamic stop loss based on volatility
- Automatic risk reduction after losses
- Hedging in severe drawdown

### Your Responsibility
- Set appropriate BaseRisk for your account
- Monitor during news events
- Check VPS/connection stability
- Test on demo first

## 🔄 Self-Optimization Explained

Every 20 trades, EA optimizes:
1. **TP/SL Multipliers**: Adjust target distances
2. **Lot Multiplier**: Scale position sizes
3. **Aggressiveness**: How eager to trade
4. **Risk Level**: Overall risk appetite
5. **Max Positions**: How many simultaneous

The optimization uses **RFO algorithm** (Royal Flush Optimization) to find the best parameter combination based on recent performance.

## 💾 Persistent Memory Details

### What Gets Saved
- All trade history statistics
- Current parameter settings
- Market regime information
- RFO learning genome (300 genes)
- Consecutive loss counter

### Where It's Saved
```
C:\Users\User\AppData\Roaming\MetaQuotes\Terminal\Common\Files\
QuantumScalper_<SYMBOL>_Memory.bin
```

### Benefits
- Survive EA restart
- Survive terminal restart
- Survive computer restart
- Can upgrade EA without losing learning
- Can test different timeframes while sharing learning

## 🎓 Understanding Quantum Analysis

Traditional EAs: 1 analysis → 1 decision
Quantum Scalper: 5 analyses → consensus decision

Each analysis:
1. Gets current market state (M1/M5/M15)
2. Adds quantum noise (small random variation)
3. Applies RFO-evolved parameters
4. Produces signal + confidence

Then:
- Aggregate all signals
- Calculate consensus
- Vote: majority determines action

This approach:
- More robust (not fooled by single false signal)
- More adaptive (explores multiple possibilities)
- More intelligent (learns which approaches work)

## 🌍 Market Regime Adaptation

### Ranging Market
- **Detection**: Low ADX, small ATR
- **Strategy**: Scalp small oscillations
- **Parameters**: Many positions, tight TP/SL

### Trending Market
- **Detection**: High ADX, directional moves
- **Strategy**: Ride trends longer
- **Parameters**: Fewer positions, wider TP

### Volatile Market
- **Detection**: High ATR, wide Bollinger Bands
- **Strategy**: Protect capital
- **Parameters**: Very few positions, wider SL

The EA automatically detects regime every tick and adapts instantly.

## 🩹 Recovery System

### Philosophy
Not about being right all the time.
About **recovering** after being wrong.

### How It Works
Track consecutive losses:
- **1-2 losses**: Normal operation
- **3 losses**: -30% risk, +30% TP
- **4-5 losses**: -50% risk, +50% TP, consider hedging
- **6+ losses**: -70% risk, +100% TP, activate hedging

This ensures:
- Smaller losses during drawdown
- Bigger wins to recover faster
- Protection from spiral down
- Psychological comfort

## ⚙️ Advanced Configuration

### Quantum Analyses Count
More analyses = more thorough but slower
- **3**: Fast, less thorough
- **5**: Balanced (default)
- **7-10**: Thorough, more CPU

### Trail Step
How much profit before trailing activates
- **1-2 pips**: Aggressive trailing
- **2-3 pips**: Balanced (default)
- **3-5 pips**: Conservative trailing

### Min Bars Between
Cooling period between positions
- **0**: No wait (very aggressive)
- **1**: 1 bar wait (default)
- **2-3**: Conservative, fewer trades

## 🚨 Troubleshooting

### No Positions Opening
- Check AutoTrading enabled
- Check spread (must be < 3 pips)
- Check max positions not reached
- Check Expert log for messages

### Memory Not Persisting
- Check file permissions in Common folder
- Try deleting .bin file and restarting
- Verify terminal has write access

### Poor Performance
- Wait for at least 20 trades (first optimization)
- Check symbol has tight spreads
- Ensure good broker execution
- Review market conditions (may not suit current regime)

### High Drawdown
- Reduce BaseRisk immediately
- Reduce MaxPositions
- Enable recovery system
- Consider demo testing first

## 📚 Full Documentation

See `QUANTUM_SCALPER_DOCUMENTATION.md` for complete details on:
- Architecture
- Algorithm details
- Customization options
- Advanced usage
- API reference

## 🤝 Support

- **GitHub**: https://github.com/simonokwundue-ops/AMAZON-RFO
- **Issues**: Create issue on GitHub
- **Discussions**: Use GitHub discussions

## ⚖️ Disclaimer

**Important**: Trading forex involves substantial risk of loss. This EA is provided as-is without warranty. Past performance is not indicative of future results. Always test thoroughly on demo account before live trading. Only risk capital you can afford to lose.

## 📜 License

This project is part of the Amazon RFO open-source initiative. See repository for license details.

---

## 🎯 Quick Checklist

Before going live:
- [ ] Tested on demo for at least 1 week
- [ ] Observed at least one optimization cycle (20 trades)
- [ ] Reviewed all log messages and understood them
- [ ] Set appropriate BaseRisk for account size
- [ ] Verified spread conditions are suitable
- [ ] Enabled AutoTrading
- [ ] Confirmed persistent memory is saving
- [ ] Read the full documentation
- [ ] Prepared to monitor regularly
- [ ] Ready to handle drawdowns emotionally

---

**Good luck and happy scalping! 🎲📊💰**
