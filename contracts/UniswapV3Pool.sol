//SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/IUniswapV3Pool.sol";
import "./NoDelegateCall.sol";
import "./libraries/Tick.sol";
import "./libraries/TickMath.sol";

contract UniswapV3Pool is IUniswapV3Pool, NoDelegateCall {
    address public immutable factory;
    address public immutable token0;
    address public immutable token1;

    // does using unit24 instead of 256 for immutable variables save gas?
    uint24 public immutable fee;
    int24 public immutable tickSpacing;
    uint128 public immutable maxLiquidityPerTick;

    struct Slot0 {
        // the current price sqrt
        uint160 sqrtPriceX96;
        // the tick corresponding to the current price
        int24 tick;
        // the index of the latest observation
        uint16 observationIndex;
        // the total num of observations being stored now. useful to run around the buffer
        uint16 observationCardinality;
        // don't know the use of this
        uint16 observationCardinalityNext;
        uint8 protocolFee;
        // don't know the use of this
        bool unlocked;
    }

    Slot0 public slot0;

    // total fee growth in the pool
    uint256 public feeGrowthGlobal0X128;
    uint256 public feeGrowthGlobal1X128;

    mapping(int24 => Tick.info) public ticks;
    mapping(int16 => uint256) public tickBitmap;
    mapping(bytes32 => Position.info) public positions;
    Oracle.observations[65535] public observations;
}
