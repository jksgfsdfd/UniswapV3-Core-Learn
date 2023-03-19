//SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/IUniswapV3Factory.sol";
import "./NoDelegateCall.sol";
import "./UniswapV3Pool.sol";
import "./UniswapV3PoolDeployer.sol";

contract UniswapV3Factory is
    IUniswapV3Factory,
    NoDelegateCall,
    UniswapV3PoolDeployer
{
    // more volatile the pair, higher the fee , higher the tickspacing
    mapping(uint24 => int24) public override feeAmountTickSpacing;

    mapping(address => mapping(address => mapping(uint24 => address)))
        public
        override getPool;

    constructor() {
        feeAmountTickSpacing[500] = 10;
        emit FeeAmountEnabled(500, 10);
        feeAmountTickSpacing[3000] = 60;
        emit FeeAmountEnabled(3000, 60);
        feeAmountTickSpacing[10000] = 200;
        emit FeeAmountEnabled(10000, 200);
    }

    // why is fee uint24?
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external override noDelegateCall returns (address pool) {
        require(tokenA != tokenB, "Same token");
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "Zero address");
        int24 tickSpacing = feeAmountTickSpacing[fee];
        require(tickSpacing != 0, "Fee Not Enabled");
        require(
            getPool[token0][token1][fee] == address(0),
            "Pool Already Present"
        );
        // the deployment is done without passing any constructor arguments. the pool contract will get the needed values by making a call to the deployer or could have been this contract. it is mentioned this method is more efficient that passing in the constructor arguments since that will make the create2 address calculation little more complex. will have to check the gas usage in both case.
        pool = deploy(address(this), token0, token1, fee, tickSpacing);
        getPool[token0][token1][fee] = pool;
        // won't creating a function for getting the pool that sorts the tokens be better? it is mentioned that this is a deliberate choice to avoid the cost of comparing addresses
        getPool[token1][token0][fee] = pool;
        emit PoolCreated(token0, token1, fee, tickSpacing, pool);
    }

    function setOwner(address _owner) external override {
        require(msg.sender == owner, "Not authorized");
        emit OwnerChanged(owner, _owner);
        _owner = owner;
    }

    // why public in uniswap?
    function enableFeeAmount(uint24 fee, int24 tickSpacing) external override {
        require(msg.sender == owner, "Not authorized");
        require(fee < 1000000, "Should be less than 100%");
        // to write
        require(feeAmountTickSpacing[fee] == 0, "Fee already enabled");
        feeAmountTickSpacing[fee] = tickSpacing;
        emit FeeAmountEnabled(fee, tickSpacing);
    }
}
