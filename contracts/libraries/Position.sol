//SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./LiquidityMath.sol";
import "./FullMath.sol";
import "./FixedPoint128.sol";

library Position {
    struct Info {
        // the info regarding the owner,lower and upper ticks of a position are encoded in the poisition id itself
        uint128 liquidity;
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

    // used to make a change to the liquidity of a poistion or to collect fees(delta = 0)
    function update(
        Info storage self,
        int128 liquidityDelta,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal {
        Info memory _self = self;
        uint128 liquidityNext;
        if (liquidityDelta == 0) {
            require(_self.liquidity != 0, "no poke");
            liquidityNext = _self.liquidity; // uselesss line
        } else {
            liquidityNext = LiquidityMath.addDelta(
                _self.liquidity,
                liquidityDelta
            );
        }

        // fullmath allows us to obtain the result of uint256*uint256/uint256
        uint128 tokensOwed0 = uint128(
            FullMath.mulDiv(
                feeGrowthInside0X128 - _self.feeGrowthInside0LastX128,
                _self.liquidity,
                FixedPoint128.Q128
            )
        );
        uint128 tokensOwed1 = uint128(
            FullMath.mulDiv(
                feeGrowthInside1X128 - _self.feeGrowthInside1LastX128,
                _self.liquidity,
                FixedPoint128.Q128
            )
        );

        if (liquidityDelta != 0) {
            self.liquidity = liquidityNext;
        }

        self.feeGrowthInside0LastX128 = feeGrowthInside0X128;
        self.feeGrowthInside1LastX128 = feeGrowthInside1X128;
        if (tokensOwed0 > 0 || tokensOwed1 > 0) {
            self.tokensOwed0 += tokensOwed0;
            self.tokensOwed1 += tokensOwed1;
        }
    }
}
