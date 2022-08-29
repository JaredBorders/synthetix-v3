//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@synthetixio/core-contracts/contracts/utils/SetUtil.sol";

import "../utils/CurvesLibrary.sol";

contract CollateralStorage {
    struct CollateralStore {
        mapping(address => CollateralData) collateralsData; // CollateralData per collateralType (address)
        SetUtil.AddressSet collaterals; // approved collateral
        mapping(uint => SetUtil.AddressSet) depositedCollateralByAccountId;
        mapping(uint => mapping(address => DepositedCollateralData)) depositedCollateralDataByAccountId;
    }

    struct CollateralData {
        /// must be true for staking or collateral delegation
        bool enabled;
        /// accounts cannot mint sUSD if their debt brings their cratio below this value
        uint targetCRatio;
        /// accounts below the ratio specified here are immediately liquidated
        uint minimumCRatio;
        /// amount of token to award when an account is liquidated with this collateral type
        uint liquidationReward;
        /// address which reports the current price of the collateral
        address priceFeed;
        /// address which should be used for transferring this collateral
        address tokenAddress;
    }

    struct DepositedCollateralData {
        bool isSet;
        uint256 availableAmount; // adjustable (stake/unstake)
        //CurvesLibrary.PolynomialCurve escrow;
        uint[] funds;
        //StakedCollateralLock[] locks;
    }

    struct DepositedCollateralLock {
        uint256 amount; // adjustable (stake/unstake)
        uint64 lockExpirationTime; // adjustable (assign/unassign)
    }

    function _collateralStore() internal pure returns (CollateralStore storage store) {
        assembly {
            // bytes32(uint(keccak256("io.synthetix.snx.collateral")) - 1)
            store.slot := 0x83916265e1b6c4fb3d473eee2163daacb5963240b78a5853da4fe894b73780a5
        }
    }
}