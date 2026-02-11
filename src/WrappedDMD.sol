// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.33;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract WrappedDMD is ERC20Permit {
    error DMDTransferFailed();

    /// @dev Equivalent to `deposit()`.
    receive() external payable {
        deposit();
    }

    constructor() ERC20("Wrapped DMD", "WDMD") ERC20Permit("WDMD") {}

    /// @dev Deposits `amount` DMD of the caller and mints `amount` WDMD to the caller.
    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }

    /// @dev Burns `amount` WDMD of the caller and sends `amount` DMD to the caller.
    function withdraw(uint256 amount) public {
        _burn(msg.sender, amount);

        assembly ("memory-safe") {
            // Transfer the DMD and check if it succeeded or not.
            if iszero(call(gas(), caller(), amount, codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, 0x61c34e08) // `DMDTransferFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }
}
