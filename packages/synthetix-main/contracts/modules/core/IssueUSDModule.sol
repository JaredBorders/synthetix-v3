//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/IIssueUSDModule.sol";

import "@synthetixio/core-modules/contracts/storage/AssociatedSystem.sol";

import "../../storage/Account.sol";
import "../../storage/Pool.sol";
import "../../storage/CollateralConfiguration.sol";

contract IssueUSDModule is IIssueUSDModule {
    using AccountRBAC for AccountRBAC.Data;
    using AssociatedSystem for AssociatedSystem.Data;
    using Pool for Pool.Data;
    using CollateralConfiguration for CollateralConfiguration.Data;
    using Vault for Vault.Data;
    using VaultEpoch for VaultEpoch.Data;
    using Distribution for Distribution.Data;

    error InsufficientDebt(int currentDebt);
    error PermissionDenied(uint128 accountId, bytes32 permission, address target);

    bytes32 private constant _USD_TOKEN = "USDToken";

    function mintUsd(
        uint128 accountId,
        uint128 poolId,
        address collateralType,
        uint amount
    ) external override onlyWithPermission(accountId, AccountRBAC._MINT_PERMISSION) {
        // check if they have sufficient c-ratio to mint that amount
        Pool.Data storage pool = Pool.load(poolId);

        int debt = pool.updateAccountDebt(collateralType, accountId);

        (, uint collateralValue) = pool.currentAccountCollateral(collateralType, accountId);

        int newDebt = debt + int(amount);

        require(newDebt > debt, "Incorrect new debt");

        if (newDebt > 0) {
            CollateralConfiguration.load(collateralType).verifyCollateralRatio(uint(newDebt), collateralValue);
        }

        VaultEpoch.Data storage epoch = Pool.load(poolId).vaults[collateralType].currentEpoch();

        epoch.consolidatedDebtDist.updateActorValue(bytes32(uint(accountId)), newDebt);
        pool.recalculateVaultCollateral(collateralType);
        require(int(amount) == int128(int(amount)), "Incorrect amount specified");
        AssociatedSystem.load(_USD_TOKEN).asToken().mint(msg.sender, amount);

        emit UsdMinted(accountId, poolId, collateralType, amount, msg.sender);
    }

    function burnUsd(
        uint128 accountId,
        uint128 poolId,
        address collateralType,
        uint amount
    ) external override {
        Pool.Data storage pool = Pool.load(poolId);
        int debt = pool.updateAccountDebt(collateralType, accountId);

        if (debt < 0) {
            // user shouldn't be able to burn more usd if they already have negative debt
            revert InsufficientDebt(debt);
        }

        if (debt < int(amount)) {
            amount = uint(debt);
        }

        AssociatedSystem.load(_USD_TOKEN).asToken().burn(msg.sender, amount);

        VaultEpoch.Data storage epoch = Pool.load(poolId).vaults[collateralType].currentEpoch();

        epoch.consolidatedDebtDist.updateActorValue(bytes32(uint(accountId)), debt - int(amount));
        pool.recalculateVaultCollateral(collateralType);

        emit UsdBurned(accountId, poolId, collateralType, amount, msg.sender);
    }

    modifier onlyWithPermission(uint128 accountId, bytes32 permission) {
        if (!Account.load(accountId).rbac.authorized(permission, msg.sender)) {
            revert PermissionDenied(accountId, permission, msg.sender);
        }

        _;
    }
}