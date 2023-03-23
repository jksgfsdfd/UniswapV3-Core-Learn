//SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./TickMath.sol";

library Tick {
    struct Info {
        uint128 liquidityGross;
        // amount of liquidity to be added or subtracted when crossing this tick
        int128 liquidityNet;
        //
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
        int56 tickCumulativeOutside;
        uint160 secondsPerLiquidityOutsideX128;
        uint32 secondsOutside;
        bool initialized;
    }

    function tickSpacingToMaxLiquidityPerTick(
        int24 tickSpacing
    ) internal pure returns (uint128) {
        // finding the min and max ticks divisible by tickspacing
        // why is the total liquidity capped to uint128.max?
        int24 minTick = (TickMath.MIN_TICK / tickSpacing) * tickSpacing;
        int24 maxTick = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
        uint24 numTicks = uint24((maxTick - minTick) / tickSpacing) + 1;
        return type(uint128).max / numTicks;
    }

    // whenever the current tick passes a tick, it updates its feeOutside. this can be thought of as a gatekeeper checking the amounts whenever a person passes the gate.
    function getFeeGrowthInside(
        mapping(int24 => Tick.info) storage self,
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    )
        internal
        view
        returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
    {
        Info storage lower = tickLower[self];
        Info storage upper = tickUpper[self];

        uint256 feeGrowthBelow0X128;
        uint256 feeGrowthBelow1X128;

        if (tickCurrent >= tickLower) {
            feeGrowthBelow0X128 = lower.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = lower.feeGrowthOutside1X128;
        } else {
            feeGrowthBelow0X128 =
                feeGrowthGlobal0X128 -
                lower.feeGrowthOutside0X128;
            feeGrowthBelow1X128 =
                feeGrowthGlobal1X128 -
                lower.feeGrowthOutside1X128;
        }

        uint256 feeGrowthAbove0X128;
        uint256 feeGrowthAbove1X128;

        if (tickCurrent <= tickUpper) {
            feeGrowthAbove0X128 = upper.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = upper.feeGrowthOutside1X128;
        } else {
            feeGrowthAbove0X128 =
                feeGrowthGlobal0X128 -
                upper.feeGrowthOutside0X128;
            feeGrowthAbove1X128 =
                feeGrowthGlobal1X128 -
                upper.feeGrowthOutside1X128;
        }

        feeGrowthInside0X128 =
            feeGrowthGlobal0X128 -
            (feeGrowthAbove0X128 + feeGrowthBelow0X128);
        feeGrowthInside1X128 =
            feeGrowthGlobal1X128 -
            (feeGrowthAbove1X128 + feeGrowthBelow1X128);
    }

    function clear(
        mapping(int24 => Tick.info) storage self,
        int24 tick
    ) internal {
        delete self[tick];
    }

    function cross(
        mapping(int24 => Tick.info) storage self,
        int24 tick,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        uint160 secondsPerLiquidityCumulativeX128,
        int56 tickCumulative,
        uint32 time
    ) internal returns (int128 liquidityNet) {
        Tick.info storage info = self[tick];
        // update the (feeGrowth + secondsPerLiquidity + tickCumulative + seconds ) outside
        info.feeGrowthOutside0X128 =
            feeGrowthOutside0X128 -
            info.feeGrowthOutside0X128;
        info.feeGrowthOutside1X128 =
            feeGrowthOutside1X128 -
            info.feeGrowthOutside1X128;
        info.secondsPerLiquidityOutsideX128 =
            secondsPerLiquidityCumulativeX128 -
            info.secondsPerLiquidityOutsideX128;
        info.tickCumulativeOutside =
            tickCumulativeInside -
            info.tickCumulativeOutside;
        info.secondsOutside = time - info.secondsOutside;
        liquidityNet = info.liquidityNet;
    }

    function update(
        mapping(int24 => Tick.info) storage self,
        int24 tick,
        int24 tickCurrent,
        int128 liquidityDelta,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        uint160 secondsPerLiquidityCumulativeX128,
        int56 tickCumulative,
        uint32 time,
        bool upper,
        uint128 maxLiquidity
    ) internal returns (bool flipped) {
        Tick.info storage info = self[tick];

        uint128 liquidityGrossBefore = info.liquidityGross;
        uint128 liquidityGrossAfter = liquidityGrossBefore + liquidityDelta;

        require(liquidityGrossAfter <= maxLiquidity, "liquidity overflow");

        flipped = (liquidityGrossBefore == 0) != (liquidityGrossAfter == 0);

        if (liquidityGrossBefore == 0) {
            // assume that all activity was below the current tick
            if (tick <= tickCurrent) {
                info.feeGrowthOutside0X128 = feeGrowthGlobal0X128;
                info.feeGrowthOutside1X128 = feeGrowthGlobal1X128;
                info
                    .secondsPerLiquidityOutsideX128 = secondsPerLiquidityCumulativeX128;
                info.tickCumulativeOutside = tickCumulative;
                info.secondsOutside = time;
            }
            info.initialized = true;
        }

        info.liquidityGross = liquidityGrossAfter;

        // add liquidity net
    }
}
