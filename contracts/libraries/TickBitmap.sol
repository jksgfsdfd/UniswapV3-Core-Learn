// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "./BitMath.sol";

/// @title TickBitmaps are used to store tick initialization data for the ticks.
/// @notice Since ticks are int24 and the max size for uint is 32bytes, the tick bitmap will be a mapping of int16 => uint256. Each bit in uint256 will store whether the corresponding tick is initialized or not

library TickBitmap {
    // returns the position of the tick in the bitmap
    function position(
        int24 tick
    ) private pure returns (int16 wordPos, uint8 bitPos) {
        wordPos = int16(tick >> 8);
        bitPos = uint8(uint24(tick % 256));
    }

    function flipTick(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing
    ) internal {
        // in the bitmap, since we will store only the valid ticks, we will map them to multiples of the tickspacing ie. each normal tick is mapped to tick/tickspacing
        require(tick % tickSpacing == 0);
        (int16 wordPos, uint8 bitPos) = position(tick / tickSpacing);
        uint256 mask = 1 << bitPos;
        // xoring with 1 flips the bit
        self[wordPos] ^= mask;
    }

    // returns the closest initialized tick that is within the word the tickbitmap. so this would scan max 256 adjacent ticks. but since only valid ticks are stored in the bitmap, it will correspond to 256 * tickspacing max range in the actual tick number. if we want the closest tick which is less than the current tick, lte should be set to true.
    function nextInitializedTickWithinOneWord(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing,
        bool lte
    ) internal view returns (int24 next, bool initialized) {
        int24 compressed = tick / tickSpacing;

        // if the tick is a negative invalid tick, we will take the previous tick ie. if tickspacing is 4 and the tick is -3, we will take -4 as the tick which will correspond to -1 in the bitmap
        if (tick < 0 && tick % tickSpacing != 0) compressed--;

        if (lte) {
            (int16 wordPos, uint8 bitPos) = position(compressed);
            // setting all 1's from the given tick to the right
            // why not (1 << (bitPos + 1)) - 1
            uint256 mask = (1 << bitPos) - 1 + (1 << bitPos);
            uint256 masked = self[wordPos] & mask;

            // checks if atleast one tick less than or equal to current tick is initialized within this word
            initialized = masked != 0;
            // in uniswap it is mentioned that 'overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick' . need to find out what this is?
            // if no tick is initialized then we would take the right most tick
            next = initialized
                ? (compressed -
                    int24(
                        uint24(bitPos - BitMath.mostSignificantBit(masked))
                    )) * tickSpacing
                : (compressed - int24(uint24(bitPos))) * tickSpacing;
        } else {
            // since we want an initialized tick greater than current, we will check from the next valid tick
            (int16 wordPos, uint8 bitPos) = position(compressed + 1);
            // setting all 1's from the next tick to the left
            uint256 mask = ~((1 << bitPos) - 1);
            uint256 masked = self[wordPos] & mask;

            // if there are no initialized ticks to the left of the current tick, return leftmost in the word
            initialized = masked != 0;

            next = initialized
                ? (compressed +
                    1 +
                    int24(
                        uint24(BitMath.leastSignificantBit(masked) - bitPos)
                    )) * tickSpacing
                : (compressed + 1 + int24(uint24(type(uint8).max - bitPos))) *
                    tickSpacing;
        }
    }
}
