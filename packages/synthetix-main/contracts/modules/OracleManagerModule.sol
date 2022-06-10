//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IOracleManagerModule.sol";
import "../interfaces/IAggregatorV3Interface.sol";

/**
 * This module is intended to provide a safety system by which any participant in the synthetix
 * system, synthetix markets, or even interested outside auditing parties, can participate in a process
 * to verify oracle prices and prevent 
 * 
 * Its intended to work with any price oracle
 */
contract OracleManagerModule is IOracleManagerModule {

    /**
     * Read function to retrieve oracle price. Should be used for `view` functions associated with your contract to deliver an accurate
     * response for an estimate
     */
    function getOracleValue(address oracle, uint[] memory interestedIncidents) public view override returns (int value, Incident[] memory lastIncidents) {
        (uint result, Incident[] memory newIncidents) = _getOracleValue(oracle);

        OracleInfo[] storage info = _fundModuleStore().oracleInfo[oracle];
        Incidents[] storage currentIncidents = _fundModuleStore().incidents[oracle];

        // just do a double loop here to match last incidents (this is only supposed to be called in views, after all)
        lastIncidents = new uint[](interestedIncidents.length);
        for (uint i = 0;i < interestedIncidents.length;i++) {
            for (uint j = 0;j < newIncidents.length;j++) {
                if (interestedIncidents[i] == newIncidents[j].kind) {
                    lastIncidents[i] = newIncidents[j];
                }
            }

            lastIncidents = currentIncidents[info.lastIncidents[interestedIncidents[i]]];
        }

        value = result;
    }

    /**
     * Mutative function to retrieve oracle price. Should be used for mutative functions associated with your contract.
     */
    function probeOracleValue(address oracle, uint[] memory interestedIncidents) public override returns (int value, uint[] memory lastIncidentIds) {
        (uint result, Incident[] memory newIncidents) = _getOracleValue(oracle);

        OracleInfo[] storage info = _fundModuleStore().oracleInfo[oracle];

        if (newIncidents.length) {
            Incidents[] storage currentIncidents = _fundModuleStore().incidents[oracle];
            uint startIncidentId = currentIncidents.length;

            for (uint i = 0;i < newIncidents.length;i++) {
                currentIncidents.push(newIncidents[i]);
                info.lastIncidents[newIncidents[i].kind] = startIncidentId + i;
            }
        }

        lastIncidentIds = new uint[](interestedIncidents.length);
        for (uint i = 0;i < interestedIncidents.length;i++) {
            lastIncidentIds[i] = info.lastIncidents[interestedIncidents[i]];
        }

        value = result;
    }

    function getOracleIncident(address oracle, uint incidentId) public override view returns (Incident memory incident) {
        return _fundModuleStore().incidents[oracle][incidentId];
    }

    function _getOracleValue(address oracle) internal view returns (uint result, Incident[] memory generatedIncidents) {
        OracleInfo[] storage info = _fundModuleStore().oracleInfo[oracle];
        
        (
            uint80 latestRoundId,
            int256 latestAnswer,
            ,
            uint256 latestUpdatedAt,
        ) = IAggregatorV3Module(oracle).latestRoundData();

        int deviation;
        if (info.lastRound == roundId - 1) {
            deviation = latestAnswer - info.lastValue;
        } else {
            (
                uint80 roundId,
                int256 answer,
                ,
                uint256 updatedAt,
            ) = IAggregatorV3Module(oracle).latestRoundData();

            deviation = latestAnswer - answer;
        }

        PriceDeviationModel model;
        if (deviation > 0) {
            model = _recordPriceDeviationSample(info.up, uint(deviation));
        } else if (deviation < 0) {
            model = _recordPriceDeviationSample(info.down, uint(-deviation));
        }

        uint deviationProbability = _calculateDeviationProbability(model, deviation);

        if (deviationProbability < 1 gwei) { // TODO: constant here probably
            // TODO: add volatility incident
        }

        if (deviation > info.lastValue / 10) {
            // TODO: add Jump10Percent incident
        }

        if (latestUpdatedAt < block.timestamp) {
            // TODO: add stale incident
        }

        info.lastValue = latestAnswer;
        info.lastRound = latestRoundId;

        result = latestAnswer;
    }

    function _recordPriceDeviationSample(PriceMovementModel memory oldModel, uint deviation) internal view returns (PriceMovementModel memory newModel) {
        uint newAvg = 
            (oldModel.avg * oldModel.samples + deviation) /
            (oldModel.samples + 1);

        newModel = PriceMovementModel(
            newAvg, // avg
            oldModel.sumOfSquares + (deviation - newAvg) * (deviation - newAvg), // variance (note this is pseudo variance because we keep a running `avg` going, but its very close as long as avg stays close)
            oldModel.samples + 1
        );

        oldModel = newModel;
    }
}
