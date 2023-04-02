//SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./UniswapV3Pool.sol";

contract UniswapV3PoolDeployer {
    struct PoolParameters {
        address factory;
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
    }

    // the pool contract on creation will call this function to receive its initial parameters.
    PoolParameters public parameters;

    function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    ) internal returns (address pool) {
        parameters = PoolParameters(factory, token0, token1, fee, tickSpacing);
        bytes32 salt = keccak256(abi.encode(token0, token1, fee));
        pool = address(new UniswapV3Pool{salt: salt}());
        delete parameters;
    }
}
