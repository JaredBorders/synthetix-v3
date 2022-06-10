//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@synthetixio/core-contracts/contracts/utils/SetUtil.sol";

contract OracleManagerStorage {

    enum IncidentKind {
        Stale,
        Jump10Percent,
        Jump20Percent,
        Jump50Percent,
        Jump100Percent,
        Volatility
    }

    struct Incident {
        uint timestamp;
        IncidentKind kind;
    }

    struct PriceMovementModel {
        // average price deviation observed between current round and last
        uint128 avg;
        //  of price deviation observed between current round and last
        uint64 sumOfSquares;
        // number of samples taken (needed to calculate avg and stddev)
        uint64 samples;
    }

    // stores whatever is needed for incidents to be properly identified
    struct OracleInfo {
        // last price seen by the oracle manager
        int128 lastValue;

        // last round id seen by the oracle manager
        uint128 lastRound;

        // bell curve model of deviations going up
        PriceMovementModel up;
        // bell curve model of deviations going down
        PriceMovementModel down;

        // 
        mapping (IncidentKind => uint) lastIncidents; 
    }

    struct OracleManagerStore {
        mapping (address => OracleInfo) oracleInfo;
        mapping (address => Incident[]) incidents;
    }

    function _oracleManagerStore() internal pure returns (OracleManagerStore storage store) {
        assembly {
            // bytes32(uint(keccak256("io.synthetix.snx.oraclemanager")) - 1)
            store.slot := ;
        }
    }
}
