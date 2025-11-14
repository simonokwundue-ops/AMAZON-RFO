# Deployment Guide - Amazon RFO Quantum Scalper

## Quick Deployment Steps

### Step 1: Locate Your MT5 Terminal Directory

Your terminal directory is:
```
C:\Users\User\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\
```

### Step 2: Copy Files

1. **From this repository**, copy the entire `Amazon RFO` folder

2. **To your MT5 terminal**, paste it at:
```
C:\Users\User\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\
```

Your final structure should be:
```
C:\Users\User\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\Amazon RFO\
    ├── Amazon_RFO_QuantumScalper.mq5
    ├── QuantumScalper_Core.mqh
    ├── PersistentMemory.mqh
    ├── MarketRegime.mqh
    ├── PositionManager.mqh
    ├── PerformanceTracker.mqh
    ├── RFO_Core.mqh
    ├── Amazon_RFO_QuantumScalper.ini
    ├── Amazon_RFO_QuantumScalper.set
    ├── QUANTUM_SCALPER_DOCUMENTATION.md
    ├── README_QUANTUM_SCALPER.md
    └── (other existing files)
```

### Step 3: Compile in MetaEditor

1. Open MetaEditor (press F4 in MT5)
2. In Navigator panel, expand: `Experts` → `Amazon RFO`
3. Double-click `Amazon_RFO_QuantumScalper.mq5`
4. Press **F7** to compile
5. Check "Errors" tab at bottom - should show:
   ```
   0 error(s), 0 warning(s)
   ```
   (Some warnings are OK)

### Step 4: Attach to Chart

1. Open MT5
2. Open any chart (EUR/USD recommended for testing)
3. Set timeframe to **M5** (recommended) or M1/M15
4. In Navigator panel: `Expert Advisors` → `Amazon RFO` → drag `Amazon_RFO_QuantumScalper` to chart
5. In popup dialog:
   - Check "Allow live trading"
   - Check "Allow DLL imports" (not required but good to enable)
   - Review settings or keep defaults
   - Click OK

### Step 5: Enable AutoTrading

1. Click **AutoTrading** button in MT5 toolbar (should turn green)
2. Look for smiling face icon on chart (indicates EA is running)

### Step 6: Verify Initialization

Check "Experts" tab at bottom of MT5. You should see:
```
╔════════════════════════════════════════════════════════════════╗
║        AMAZON RFO QUANTUM SCALPER - INITIALIZED               ║
╠════════════════════════════════════════════════════════════════╣
║ Symbol: EURUSD | Magic: 789456
║ Max Positions: 5 | Quantum Analyses: 5
║ Self-Optimization: ENABLED
║ Trades: 0 | WR: 0.00% | PF: 0.00 | Profit: 0.00
╚════════════════════════════════════════════════════════════════╝
```

## Post-Deployment Checklist

### Immediate Checks
- [ ] EA shows initialized message
- [ ] AutoTrading is enabled (green button)
- [ ] Chart shows smiling face icon
- [ ] No error messages in Experts tab
- [ ] Spread is reasonable (< 3 pips)

### First Hour Monitoring
- [ ] EA opens positions when conditions met
- [ ] Positions have TP and SL set
- [ ] Trailing works (if enabled)
- [ ] No excessive position opening (should respect MinBarsBetween)

### First Day Monitoring
- [ ] Check trade results in Experts tab
- [ ] Verify different market regimes are detected
- [ ] Monitor for any repeated errors
- [ ] Check position management working correctly

### After 20 Trades
- [ ] EA should trigger self-optimization
- [ ] Check Experts tab for optimization report
- [ ] Verify persistent memory file created at:
  ```
  C:\Users\User\AppData\Roaming\MetaQuotes\Terminal\Common\Files\
  QuantumScalper_<SYMBOL>_Memory.bin
  ```

## Settings for Different Risk Profiles

### Conservative (For Small Accounts < $1000)
```
BaseRisk = 0.5%
MaxRisk = 2.5%
MaxPositions = 3
MinTPPips = 5
MaxTPPips = 20
```

### Balanced (For Medium Accounts $1000-$5000) - DEFAULT
```
BaseRisk = 1.0%
MaxRisk = 5.0%
MaxPositions = 5
MinTPPips = 5
MaxTPPips = 30
```

### Aggressive (For Larger Accounts > $5000)
```
BaseRisk = 1.5%
MaxRisk = 7.5%
MaxPositions = 7
MinTPPips = 5
MaxTPPips = 40
```

## Recommended Symbols

### Best Performance Expected:
- EUR/USD (tight spreads, good liquidity)
- GBP/USD (more volatile, wider profits)
- USD/JPY (Asian session friendly)
- AUD/USD (good for trending)

### Avoid Initially:
- Exotic pairs (USDTRY, USDZAR, etc.)
- Pairs with wide spreads (> 3 pips)
- Pairs with low liquidity
- During major news events

## Recommended Timeframes

### M1 (1-minute)
- **Pros**: Most trades, fastest execution
- **Cons**: Highest noise, most false signals
- **Best for**: Live monitoring, high-frequency trading

### M5 (5-minute) - RECOMMENDED
- **Pros**: Balanced signals, good execution
- **Cons**: Moderate trade frequency
- **Best for**: Most traders, balanced approach

### M15 (15-minute)
- **Pros**: Cleaner signals, less noise
- **Cons**: Fewer trades
- **Best for**: Conservative approach, part-time monitoring

## Monitoring Best Practices

### Daily Tasks
1. Check Experts log for any errors
2. Review trade results
3. Verify spread conditions acceptable
4. Check if regime changes logged

### Weekly Tasks
1. Review overall performance
2. Check if optimization occurred (every 20 trades)
3. Verify memory file is being saved
4. Review equity curve

### Monthly Tasks
1. Analyze win rate trends
2. Review profit factor changes
3. Check if parameters evolved appropriately
4. Consider adjusting BaseRisk if needed

## Troubleshooting Common Issues

### "Failed to initialize indicators"
**Solution**: Restart MT5 and reattach EA

### "PersistentMemory: Failed to save memory"
**Solution**: Check file permissions in Common folder

### EA not opening positions
**Check**:
1. AutoTrading enabled?
2. Spread < MaxSpread (3 pips)?
3. MaxPositions not already reached?
4. Check Experts log for specific reasons

### High drawdown early on
**Action**:
1. Reduce BaseRisk immediately
2. Reduce MaxPositions
3. Wait for at least 20 trades (first optimization)
4. Consider demo testing longer

### Memory file not persisting
**Solution**:
1. Check path: `Terminal\Common\Files\`
2. Try deleting existing .bin file
3. Restart EA to create fresh file
4. Check Windows file permissions

## Performance Expectations

### First 20 Trades (Learning Phase)
- Win rate: 40-60% (variable)
- Profit factor: 0.8-1.5 (may be below 1.0)
- Behavior: Exploring different parameters

### After First Optimization
- Win rate: 50-65%
- Profit factor: 1.2-2.0
- Behavior: More focused, better timing

### Long-term (100+ trades)
- Win rate: 55-70%
- Profit factor: 1.5-2.5+
- Behavior: Well-adapted to symbol

**Important**: These are guidelines, not guarantees. Actual results depend on market conditions, broker, and settings.

## Support

### Documentation
- Full docs: `QUANTUM_SCALPER_DOCUMENTATION.md`
- Quick start: `README_QUANTUM_SCALPER.md`

### Community
- GitHub: https://github.com/simonokwundue-ops/AMAZON-RFO
- Issues: Create issue on GitHub

## Final Reminders

⚠️ **CRITICAL WARNINGS**:
1. **Always test on demo first** (minimum 1 week)
2. **Never risk more than you can afford to lose**
3. **Forex trading carries substantial risk**
4. **Past performance does not guarantee future results**
5. **Monitor regularly, especially first few days**
6. **Keep EA and MT5 updated**
7. **Use VPS for 24/7 operation (recommended)**
8. **Backup memory file periodically**

✅ **SUCCESS FACTORS**:
1. Tight spreads (< 2 pips ideal)
2. Good broker execution
3. Stable internet connection
4. Adequate account balance
5. Patient monitoring
6. Allow EA to learn (20+ trades minimum)
7. Regular performance review

---

## Ready to Deploy?

If you've read this guide and understand the risks and requirements:

1. ✅ Copy files to correct directory
2. ✅ Compile in MetaEditor
3. ✅ Attach to chart
4. ✅ Enable AutoTrading
5. ✅ Monitor and learn

**Good luck and trade responsibly! 🚀📊💰**

---

*Last updated: November 2025*
*Version: 1.00*
