//SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

library Position {
    struct Info {
        // the info regarding the lower and upper ticks corresponding to a position are encoded in the poisition id itself
        uint128 liquidity;
        // int24 tickLower;
        // int24 tickUpper;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    function get(
        mapping(bytes32 => Info) storage self,
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (Info storage position) {
        position = self[
            // since the parameters are fixed sized, abi.encodepacked will have no collisions.
            keccak256(abi.encodePacked(owner, tickLower, tickUpper))
        ];
    }

    // create position
    // collection fees to update position
    // remove their position
    // add more liquidity to their position

    // to collect the accumulated fees to the position
    function update(
        Info storage self,
        uint128 liquidityDelta,
        uint128 feeGrowthInside0X128,
        uint128 feeGrowthInside1X128
    ) internal {
        Info memory _self = self;
        uint128 liquidityNext;
        if (liquidityDelta == 0) {
            require(_self.liquidity != 0, "no poke");
            liquidityNext = _self.liquidity; // uselesss line
        } else {
            liquidityNext = _self.liquidity + liquidityDelta;
        }

        uint128 tokensOwed0 = (feeGrowthInside0X128 -
            _self.feeGrowthInside0LastX128) * _self.liquidity;
        uint128 tokensOwed1 = (feeGrowthInside1X128 -
            _self.feeGrowthInside1LastX128) * _self.liquidity;

        if (liquidityDelta != 0) {
            self.liquidity = liquidityNext;
        }

        self.feeGrowthInside0LastX128 = feeGrowthInside0X128;
        self.feeGrowthInside1LastX128 = feeGrowthInside1X128;
        if (tokensOwed0 > 0 || tokensOwed > 0) {
            self.tokensOwed0 += tokensOwed0;
            self.tokensOwed1 += tokensOwed1;
        }
    }
}
