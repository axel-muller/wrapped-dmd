// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.33;

contract MockReceiver {
    bool public receiveAllowed;

    receive() external payable {
        require(receiveAllowed);
    }

    constructor() {
        receiveAllowed = true;
    }

    function toggleReceive(bool allowed) external {
        receiveAllowed = allowed;
    }
}
