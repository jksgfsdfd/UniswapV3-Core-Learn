// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

abstract contract NoDelegateCall {
    address private immutable original;

    constructor() {
        original = address(this);
    }

    // since original is immutable, its value is stored in code itself. Hence no other contract can manipulate this check when making a delegatecall.
    function checkNotDelegateCall() private view {
        require(address(this) == original);
    }

    // the address check is not inlined in the modifier becase it would result in the bytes corresponding to 'original' being added to every function that uses this modifier. hence creating a function that performs this check saves gas.
    modifier noDelegateCall() {
        checkNotDelegateCall();
        _;
    }
}
