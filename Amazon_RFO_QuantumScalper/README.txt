# Amazon RFO Quantum Scalper - Ready for Deployment

## Directory Structure

This is a self-contained MQL5 Expert Advisor package ready for deployment.

```
Amazon_RFO_QuantumScalper/
├── Amazon_RFO_QuantumScalper.mq5    (Main EA - compile this)
├── Amazon_RFO_QuantumScalper.set    (Preset configuration)
├── Amazon_RFO_QuantumScalper.ini    (Configuration reference)
└── Include/                          (Helper modules)
    ├── QuantumScalper_Core.mqh      (Quantum analysis engine)
    ├── PersistentMemory.mqh         (Memory system)
    ├── MarketRegime.mqh             (Regime detection)
    ├── PositionManager.mqh          (Position management)
    ├── PerformanceTracker.mqh       (Self-optimization)
    └── RFO_Core.mqh                 (RFO algorithm)
```

## Installation

### Step 1: Copy Directory
Copy the entire `Amazon_RFO_QuantumScalper` folder to:
```
C:\Users\User\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\
```

Final location should be:
```
C:\Users\User\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\Amazon_RFO_QuantumScalper\
```

### Step 2: Compile
1. Open MetaEditor (F4 in MT5)
2. Navigate to: `Experts` → `Amazon_RFO_QuantumScalper`
3. Open `Amazon_RFO_QuantumScalper.mq5`
4. Press F7 to compile
5. Verify: 0 errors, 0 warnings (some warnings OK)

### Step 3: Use
1. Open MT5
2. Open chart (EUR/USD recommended, M5 timeframe)
3. Drag `Amazon_RFO_QuantumScalper` from Navigator to chart
4. Enable AutoTrading
5. Monitor first 20 trades

## Features

✅ **Quantum Analysis** - 5 simultaneous analyses per tick
✅ **Multi-Position** - Up to 10 simultaneous positions
✅ **Dynamic TP/SL** - 5-30 pips TP, 3-20 pips SL
✅ **Self-Optimization** - Every 20 trades
✅ **Persistent Memory** - Survives all restarts
✅ **Market Regimes** - Ranging/Trending/Volatile adaptation
✅ **Recovery System** - 4-tier progressive recovery

## Configuration

Load the included preset file `Amazon_RFO_QuantumScalper.set` for optimized settings.

**Default Settings:**
- Base Risk: 1% per position
- Max Risk: 5% total
- Max Positions: 5
- Quantum Analyses: 5
- Self-Optimization: Every 20 trades

## Memory File

Performance data saved to:
```
C:\Users\User\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QuantumScalper_<SYMBOL>_Memory.bin
```

This file persists across EA and terminal restarts.

## Support

For complete documentation, see the main repository:
https://github.com/simonokwundue-ops/AMAZON-RFO

## Important Notes

⚠️ **Test on demo account first** (minimum 1 week)
⚠️ **Never risk more than you can afford to lose**
⚠️ **Allow 20 trades for first optimization cycle**
⚠️ **Monitor regularly, especially first few days**

## Quick Troubleshooting

**EA not compiling:**
- Ensure all files in Include folder are present
- Check MT5 build version (2600+ required)

**EA not opening positions:**
- Enable AutoTrading
- Check spread (must be < 3 pips)
- Verify not at max positions

**Memory not persisting:**
- Check Common folder permissions
- Verify file is being created

---

**Ready to deploy!** Copy this entire directory to your MT5 Experts folder.
