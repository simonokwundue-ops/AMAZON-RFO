# Amazon RFO Quantum Scalper - Complete Documentation

## Table of Contents
1. [Overview](#overview)
2. [Key Features](#key-features)
3. [Architecture](#architecture)
4. [Installation](#installation)
5. [Configuration](#configuration)
6. [How It Works](#how-it-works)
7. [Self-Optimization](#self-optimization)
8. [Market Regime Adaptation](#market-regime-adaptation)
9. [Recovery Strategies](#recovery-strategies)
10. [Persistent Memory](#persistent-memory)
11. [Performance Tracking](#performance-tracking)
12. [Troubleshooting](#troubleshooting)

---

## Overview

The Amazon RFO Quantum Scalper is an advanced MetaTrader 5 Expert Advisor that implements a quantum-style rapid scalping system. Unlike traditional EAs that make decisions based on single analysis, this system performs **multiple rapid analyses simultaneously** (like quantum superposition) and reaches decisions through consensus.

### Philosophy
- **Not focused on precision** but on **recovery after losses**
- **Multiple micro-positions** opened simultaneously
- **Closest possible TP/SL** distances for rapid scalping
- **Self-optimizing** based on actual performance
- **Different strategies** for different market regimes

---

## Key Features

### 1. Quantum-Style Analysis
- Performs 5 independent analyses per tick by default
- Each analysis includes quantum noise (small random variation)
- Decisions made by consensus voting
- Continuously evolving using RFO algorithm

### 2. Multi-Position Management
- Opens multiple micro-positions simultaneously
- Each position independently managed
- Dynamic trailing stops
- Closes fastest on profit, extends if trend continues

### 3. Self-Optimization
- Automatically optimizes parameters every 20 trades
- Uses RFO algorithm to find optimal settings
- Learns from wins and losses
- Adapts to changing market conditions

### 4. Persistent Memory
- Performance data survives EA restart
- Memory survives MT5 terminal restart
- Genome data preserved for continuous learning
- Stored in Common folder (cross-EA accessible)

### 5. Market Regime Detection
- Detects 3 regimes: Ranging, Trending, Volatile
- Adapts TP/SL based on regime
- Adjusts position count per regime
- Different entry strategies per regime

### 6. Recovery System
- Tracks consecutive losses
- Reduces risk after losses
- Increases TP after losses
- Activates hedging in severe drawdown

---

## Architecture

### File Structure
```
Amazon RFO/
├── Amazon_RFO_QuantumScalper.mq5    # Main EA file
├── QuantumScalper_Core.mqh           # Quantum analysis engine
├── PersistentMemory.mqh              # Persistent memory system
├── MarketRegime.mqh                  # Market regime detection
├── PositionManager.mqh               # Multi-position management
├── PerformanceTracker.mqh            # Performance tracking & optimization
├── RFO_Core.mqh                      # RFO algorithm implementation
├── Amazon_RFO_QuantumScalper.ini     # Configuration file
└── Amazon_RFO_QuantumScalper.set     # Preset file
```

### Dependencies
All dependencies are **self-contained** in the directory:
- Standard MQL5 libraries only: `<Trade/Trade.mqh>`
- No external DLLs required
- No internet connectivity required
- All custom libraries included

---

## Installation

### Step 1: Copy Files
Copy the entire `Amazon RFO` directory to:
```
C:\Users\User\AppData\Roaming\MetaQuotes\Terminal\<TERMINAL_ID>\MQL5\Experts\
```

Replace `<TERMINAL_ID>` with your actual terminal ID (e.g., `D0E8209F77C8CF37AD8BF550E51FF075`).

### Step 2: Compile
1. Open MetaEditor
2. Navigate to the `Amazon RFO` folder
3. Open `Amazon_RFO_QuantumScalper.mq5`
4. Press F7 or click Compile
5. Ensure no errors (warnings are OK)

### Step 3: Attach to Chart
1. Open MT5
2. Open a chart (M1, M5, or M15 recommended)
3. Drag `Amazon_RFO_QuantumScalper` from Navigator to chart
4. Configure settings (or use defaults)
5. Enable AutoTrading

---

## Configuration

### Basic Risk Settings
- **BaseRisk (1.0%)**: Risk per position as percentage of balance
- **MaxRisk (5.0%)**: Maximum total risk across all positions
- **Magic (789456)**: Unique identifier for this EA's trades

### Quantum Scalper Settings
- **QuantumAnalyses (5)**: Number of analyses per tick (2-10 recommended)
- **MaxPositions (5)**: Maximum simultaneous positions (3-10 recommended)
- **MinTPPips/MaxTPPips**: TP range in pips (dynamic calculation)
- **MinSLPips/MaxSLPips**: SL range in pips (dynamic calculation)
- **UseTrailing**: Enable dynamic trailing stops
- **TrailStepPips**: Distance for trailing (2-5 recommended)

### Market Regime Settings
- **AdaptToRegime**: Enable regime-based adaptation
- **RegimeTF**: Timeframe for regime detection (M5 recommended)

### Recovery Settings
- **UseRecovery**: Enable recovery after losses
- **LossesForRecovery (3)**: Consecutive losses to trigger recovery
- **UseHedging**: Enable hedging in recovery mode

### Self-Optimization
- **SelfOptimize**: Enable automatic optimization
- **OptimizeEvery (20)**: Optimize every N trades

### Advanced Settings
- **Slippage (3)**: Maximum slippage in points
- **MaxSpread (3.0)**: Maximum spread in pips
- **MinBarsBetween (1)**: Minimum bars between position openings

---

## How It Works

### Quantum Analysis Process
1. **Market State Calculation**: Analyzes M1, M5, M15 timeframes
2. **Multiple Analyses**: Performs 5 independent analyses with quantum noise
3. **RFO Evolution**: Each analysis uses evolved RFO parameters
4. **Consensus Building**: Aggregates signals and confidence
5. **Voting**: Majority vote determines if trade should open

### Position Opening
1. Check if can open new position (max not reached)
2. Check spread and timing
3. Detect market regime
4. Perform quantum analyses
5. Get consensus from analyses
6. Apply recovery adjustments if needed
7. Calculate dynamic TP/SL based on volatility
8. Calculate lot size based on risk
9. Open position with optimal parameters

### Position Management
1. **Dynamic Trailing**: Trails stop as position becomes profitable
2. **Independent Management**: Each position managed separately
3. **Fast Close**: Closes at TP quickly
4. **Trend Extension**: If trend continues, allows further profit
5. **Automatic Close**: Closes at SL if market reverses

---

## Self-Optimization

### How It Works
Every 20 trades, the EA:
1. Calculates recent performance metrics
2. Runs RFO optimization for 30 cycles
3. Evaluates parameter combinations based on:
   - Risk-reward ratio
   - Balance between aggression and conservation
   - Recent performance alignment
   - Historical win rate
   - Profit factor
4. Applies best parameter set found
5. Saves to persistent memory

### Optimized Parameters
- **tpMultiplier**: TP distance multiplier (0.8-3.0)
- **slMultiplier**: SL distance multiplier (0.5-2.0)
- **lotMultiplier**: Lot size multiplier (0.5-2.0)
- **aggressiveness**: Trading aggressiveness (0.0-1.0)
- **riskLevel**: Risk level (0.0-1.0)
- **maxSimultaneous**: Max simultaneous positions (2-10)

---

## Market Regime Adaptation

### Regime Types

#### 1. Ranging Market
- **Detection**: ADX < 20, low volatility
- **Strategy**: Tight TP (1.2x), tight SL (0.8x), more positions (7)
- **Logic**: Capitalize on small oscillations

#### 2. Trending Market
- **Detection**: ADX > 25, directional movement
- **Strategy**: Wide TP (2.0x), tight SL (0.7x), fewer positions (4)
- **Logic**: Ride trends, cut losses quickly

#### 3. Volatile Market
- **Detection**: High ATR, wide Bollinger Bands
- **Strategy**: Moderate TP (1.5x), wide SL (1.3x), fewer positions (3)
- **Logic**: Protect against whipsaws

### Adaptation Benefits
- **Automatic Strategy Switching**: No manual intervention needed
- **Regime-Specific Parameters**: Optimal for each condition
- **Risk Management**: Reduces positions in dangerous conditions

---

## Recovery Strategies

### Tier 1: 1-2 Consecutive Losses
- Continue normal operation
- No adjustments needed

### Tier 2: 3 Consecutive Losses
- Reduce risk by 30%
- Increase TP by 30%
- More conservative approach

### Tier 3: 4-5 Consecutive Losses
- Reduce risk by 50%
- Increase TP by 50%
- Activate hedging consideration

### Tier 4: 6+ Consecutive Losses
- Reduce risk by 70%
- Double TP targets
- Activate hedging
- Ultra-conservative mode

### Hedging
When activated:
- Opens opposite positions to net exposure
- Locks in current equity
- Allows market to settle
- Gradually unwinds as market stabilizes

---

## Persistent Memory

### What is Saved
1. **Performance Metrics**:
   - Total trades
   - Win/loss counts
   - Total profit/loss
   - Win rate, profit factor
   - Average win/loss

2. **Adaptive Parameters**:
   - TP/SL multipliers
   - Lot multipliers
   - Aggressiveness levels
   - Max simultaneous positions

3. **Regime Memory**:
   - Current regime
   - Regime strength
   - Consecutive losses
   - Last regime change

4. **RFO Genome**:
   - 300 genes (floating point values)
   - Evolved over time
   - Represents learned behavior

### File Location
```
C:\Users\User\AppData\Roaming\MetaQuotes\Terminal\Common\Files\
QuantumScalper_<SYMBOL>_Memory.bin
```

### Persistence Benefits
- **Continuous Learning**: Never loses progress
- **Terminal Restart Safe**: Memory survives crashes
- **EA Update Safe**: Upgrade without losing learning
- **Cross-Instance**: Can share learning across charts

---

## Performance Tracking

### Metrics Tracked
- **Total Trades**: Lifetime trade count
- **Win Rate**: Percentage of winning trades
- **Profit Factor**: Ratio of gross profit to gross loss
- **Average Win/Loss**: Average size of wins and losses
- **Sharpe Ratio**: Risk-adjusted returns
- **Consecutive Losses**: Current loss streak

### Reports
Automatic reports printed to Expert log:
- After each trade (win/loss and stats)
- After each optimization (parameter changes)
- On EA start (summary of past performance)
- On EA shutdown (final statistics)

### Performance Summary Format
```
Trades: 150 | WR: 58.7% | PF: 1.45 | Profit: +1,234.56
```

---

## Troubleshooting

### EA Not Opening Positions
**Check:**
1. AutoTrading enabled in MT5
2. Spread within MaxSpread limit
3. MaxPositions not already reached
4. MinBarsBetween requirement met
5. Expert log for messages

### Persistent Memory Not Loading
**Solutions:**
1. Check Common folder exists
2. Verify file permissions
3. Check for file corruption
4. Delete .bin file to start fresh

### Self-Optimization Not Running
**Check:**
1. SelfOptimize = true in settings
2. At least 20 trades completed
3. Check Expert log for optimization messages
4. Verify RFO initialized successfully

### High Drawdown
**Actions:**
1. Reduce BaseRisk parameter
2. Reduce MaxPositions parameter
3. Enable recovery system
4. Check if market conditions suitable
5. Review recent trades in log

### Compilation Errors
**Solutions:**
1. Ensure all .mqh files in same directory
2. Verify RFO_Core.mqh exists
3. Check MQL5 version (build 2600+)
4. Clear MetaEditor cache

### Positions Not Trailing
**Check:**
1. UseTrailing = true
2. Positions profitable enough (50% of minTP)
3. TrailStepPips appropriate for symbol
4. Check Expert log for trail messages

---

## Best Practices

### 1. Initial Setup
- Start with default settings
- Test on demo account first
- Allow 20 trades for first optimization
- Monitor performance closely

### 2. Timeframe Selection
- **M1**: Ultra-aggressive, high frequency
- **M5**: Balanced, good for most conditions
- **M15**: Conservative, fewer trades

### 3. Symbol Selection
- Works best on major forex pairs (EUR/USD, GBP/USD, etc.)
- Ensure tight spreads (< 2 pips)
- Adequate liquidity essential
- Avoid exotic pairs initially

### 4. Risk Management
- Start with 0.5-1.0% BaseRisk
- Never exceed 5% MaxRisk
- Monitor consecutive losses
- Reduce risk in volatile periods

### 5. Monitoring
- Check Expert log daily
- Review optimization reports
- Monitor win rate trends
- Watch for regime changes

---

## Advanced Topics

### Customizing Quantum Analyses
Increase QuantumAnalyses (5-10) for:
- More thorough analysis
- Higher computational cost
- Potentially better decisions
- More CPU usage

### Adjusting Recovery Aggression
Modify in MarketRegime.mqh:
```cpp
void GetRecoveryStrategy(int consecutiveLosses, ...)
{
    // Customize recovery tiers here
}
```

### Custom Market Regimes
Add new regimes in MarketRegime.mqh:
```cpp
enum ENUM_MARKET_REGIME
{
    REGIME_RANGING = 0,
    REGIME_TRENDING = 1,
    REGIME_VOLATILE = 2,
    REGIME_CUSTOM = 3  // Add here
};
```

---

## Support & Development

### Future Enhancements
- Additional market regime types
- Machine learning integration
- Multi-symbol capability
- Web dashboard for monitoring
- Email/mobile notifications

### Contributing
This is an open project. Contributions welcome:
- Bug reports
- Feature suggestions
- Code improvements
- Documentation updates

---

## Disclaimer

Trading forex carries a high level of risk and may not be suitable for all investors. The high degree of leverage can work against you as well as for you. Before deciding to trade forex you should carefully consider your investment objectives, level of experience, and risk appetite. The possibility exists that you could sustain a loss of some or all of your initial investment. Therefore, you should not invest money that you cannot afford to lose.

This EA is provided as-is without warranty. Past performance is not indicative of future results. Always test on demo account before live trading.

---

## Version History

### v1.00 (Current)
- Initial release
- Quantum analysis engine
- Multi-position management
- Self-optimization system
- Persistent memory
- Market regime adaptation
- Recovery strategies

---

## Contact

For questions, issues, or suggestions:
- GitHub: https://github.com/simonokwundue-ops/AMAZON-RFO
- Create an issue on GitHub for support

---

**Happy Trading! 📈**
