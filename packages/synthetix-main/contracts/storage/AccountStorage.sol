//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@synthetixio/core-contracts/contracts/utils/SetUtil.sol";

contract AccountStorage {
    struct AccountStore {
        bool initialized;
    }

    function _accountStore() internal pure returns (AccountStore storage store) {
        assembly {
            // bytes32(uint(keccak256("io.synthetix.snx.account")) - 1)
            store.slot := 0xc8ca6284657224e913ed6965e10e3e3b51a0642aff2bbaaae02f526ca2fe92c7
        }
    }
}
