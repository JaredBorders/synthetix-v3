//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import "@synthetixio/core-contracts/contracts/utils/DecimalMath.sol";
import "@synthetixio/core-contracts/contracts/interfaces/IERC20.sol";
import "../interfaces/external/IMarket.sol";
import "../interfaces/IMarketManagerModule.sol";
import "../interfaces/IAssociateDebtModule.sol";
import "../interfaces/IMarketCollateralModule.sol";

contract MockMarket is IMarket {
    using DecimalMath for uint256;

    uint256 private _reportedDebt;
    uint256 private _locked;
    uint256 private _price;

    address private _proxy;
    uint128 private _marketId;

    function initialize(address proxy, uint128 marketId, uint256 initialPrice) external {
        _proxy = proxy;
        _marketId = marketId;
        _price = initialPrice;
    }

    function callAssociateDebt(
        uint128 poolId,
        address collateralType,
        uint128 accountId,
        uint256 amount
    ) external {
        IAssociateDebtModule(_proxy).associateDebt(
            _marketId,
            poolId,
            collateralType,
            accountId,
            amount
        );
    }

    function buySynth(uint256 amount) external {
        _reportedDebt += amount;
        uint256 toDeposit = amount.divDecimal(_price);
        IMarketManagerModule(_proxy).depositMarketUsd(_marketId, msg.sender, toDeposit);
    }

    function sellSynth(uint256 amount) external {
        _reportedDebt -= amount;
        uint256 toDeposit = amount.divDecimal(_price);
        IMarketManagerModule(_proxy).withdrawMarketUsd(_marketId, msg.sender, toDeposit);
    }

    function setReportedDebt(uint256 newReportedDebt) external {
        _reportedDebt = newReportedDebt;
    }

    function setLocked(uint256 newLocked) external {
        _locked = newLocked;
    }

    function reportedDebt(uint128) external view override returns (uint256) {
        return _reportedDebt;
    }

    function name(uint128) external pure override returns (string memory) {
        return "MockMarket";
    }

    function locked(uint128) external view override returns (uint256) {
        return _locked;
    }

    function setPrice(uint256 newPrice) external {
        _price = newPrice;
    }

    function price() external view returns (uint256) {
        return _price;
    }

    function deposit(address collateralType, uint256 amount) external {
        IERC20(collateralType).transferFrom(msg.sender, address(this), amount);
        IERC20(collateralType).approve(_proxy, amount);
        IMarketCollateralModule(_proxy).depositMarketCollateral(_marketId, collateralType, amount);
    }

    function withdraw(address collateralType, uint256 amount) external {
        IMarketCollateralModule(_proxy).withdrawMarketCollateral(_marketId, collateralType, amount);
        IERC20(collateralType).transfer(msg.sender, amount);
    }

    function name(uint256) external pure returns (string memory) {
        return "Mock Market";
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165) returns (bool) {
        return
            interfaceId == type(IMarket).interfaceId ||
            interfaceId == this.supportsInterface.selector;
    }
}
