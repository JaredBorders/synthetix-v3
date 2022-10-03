// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../storage/NodeFactoryStorage.sol";
import "../interfaces/external/IPyth.sol";

library PythNodeLibrary {
    function process(NodeFactoryStorage.NodeData[] memory, bytes memory parameters)
        internal
        view
        returns (NodeFactoryStorage.NodeData memory)
    {
        (IPyth pyth, bytes32 priceFeedId) = abi.decode(parameters, (IPyth, bytes32));
        PythStructs.Price memory pythPrice = pyth.getPrice(priceFeedId);

        // TODO: use confidence score to determine volatility and liquidity scores
        return NodeFactoryStorage.NodeData(pythPrice.price, pythPrice.publishTime, 0, 0);
    }
}
