//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@synthetixio/core-contracts/contracts/initializable/InitializableMixin.sol";
import "../../storage/ElectionStorage.sol";

/// @dev Common utils, errors, and events to be used by any contracts that conform the ElectionModule
contract ElectionBase is ElectionStorage, InitializableMixin {
    // ---------------------------------------
    // Enums
    // ---------------------------------------

    enum ElectionPeriod {
        // Council elected and active
        Administration,
        // Accepting nominations for next election
        Nomination,
        // Accepting votes for ongoing election
        Vote,
        // Votes being counted
        Evaluation
    }

    // ---------------------------------------
    // Errors
    // ---------------------------------------

    error ElectionNotEvaluated();
    error ElectionAlreadyEvaluated();
    error AlreadyNominated();
    error NotNominated();
    error NoCandidates();
    error NoVotePower();
    error VoteNotCasted();
    error DuplicateCandidates();
    error InvalidEpochConfiguration();
    error InvalidElectionSettings();
    error NotCallableInCurrentPeriod();
    error ChangesCurrentPeriod();
    error AlreadyACouncilMember();
    error NotACouncilMember();
    error InvalidMinimumActiveMembers();

    // ---------------------------------------
    // Events
    // ---------------------------------------

    event ElectionModuleInitialized();
    event EpochStarted(uint epochIndex);
    event CouncilTokenCreated(address proxy, address implementation);
    event CouncilTokenUpgraded(address newImplementation);
    event CouncilMemberAdded(address member);
    event CouncilMemberRemoved(address member);
    event CouncilMembersDismissed(address[] members);
    event EpochScheduleUpdated(uint64 nominationPeriodStartDate, uint64 votingPeriodStartDate, uint64 epochEndDate);
    event MinimumEpochDurationsChanged(
        uint64 minNominationPeriodDuration,
        uint64 minVotingPeriodDuration,
        uint64 minEpochDuration
    );
    event MaxDateAdjustmentToleranceChanged(uint64 tolerance);
    event DefaultBallotEvaluationBatchSizeChanged(uint size);
    event NextEpochSeatCountChanged(uint8 seatCount);
    event MinimumActiveMembersChanged(uint8 minimumActiveMembers);
    event CandidateNominated(address indexed candidate);
    event NominationWithdrawn(address indexed candidate);
    event VoteRecorded(address indexed voter, bytes32 indexed ballotId, uint votePower);
    event VoteWithdrawn(address indexed voter, bytes32 indexed ballotId, uint votePower);
    event ElectionEvaluated(uint epochIndex, uint totalBallots);
    event ElectionBatchEvaluated(uint epochIndex, uint evaluatedBallots, uint totalBallots);
    event EmergencyElectionStarted();

    // ---------------------------------------
    // Helpers
    // ---------------------------------------

    /// @dev Determines the current period type according to the current time and the epoch's dates
    function _getCurrentPeriod() internal view returns (ElectionPeriod) {
        if (!_electionStore().initialized) {
            revert InitError.NotInitialized();
        }

        EpochData storage epoch = _getCurrentEpoch();

        uint64 currentTime = uint64(block.timestamp);

        if (currentTime >= epoch.endDate) {
            return ElectionPeriod.Evaluation;
        }

        if (currentTime >= epoch.votingPeriodStartDate) {
            return ElectionPeriod.Vote;
        }

        if (currentTime >= epoch.nominationPeriodStartDate) {
            return ElectionPeriod.Nomination;
        }

        return ElectionPeriod.Administration;
    }

    function _isInitialized() internal view override returns (bool) {
        return _electionStore().initialized;
    }

    function _createNewEpoch() internal virtual {
        ElectionStore storage store = _electionStore();

        store.epochs.push();
        store.elections.push();
    }

    function _getCurrentEpochIndex() internal view returns (uint) {
        return _electionStore().epochs.length - 1;
    }

    function _getCurrentEpoch() internal view returns (EpochData storage) {
        return _getEpochAtIndex(_getCurrentEpochIndex());
    }

    function _getPreviousEpoch() internal view returns (EpochData storage) {
        return _getEpochAtIndex(_getCurrentEpochIndex() - 1);
    }

    function _getEpochAtIndex(uint position) internal view returns (EpochData storage) {
        return _electionStore().epochs[position];
    }

    function _getCurrentElection() internal view returns (ElectionData storage) {
        return _getElectionAtIndex(_getCurrentEpochIndex());
    }

    function _getElectionAtIndex(uint position) internal view returns (ElectionData storage) {
        return _electionStore().elections[position];
    }

    function _getBallot(bytes32 ballotId) internal view returns (BallotData storage) {
        return _getCurrentElection().ballotsById[ballotId];
    }

    function _getBallotInEpoch(bytes32 ballotId, uint epochIndex) internal view returns (BallotData storage) {
        return _getElectionAtIndex(epochIndex).ballotsById[ballotId];
    }

    function _calculateBallotId(address[] memory candidates) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(candidates));
    }

    function _ballotExists(BallotData storage ballot) internal view returns (bool) {
        return ballot.candidates.length != 0;
    }

    function _getBallotVoted(address user) internal view returns (bytes32) {
        return _getCurrentElection().ballotIdsByAddress[user];
    }

    function _hasVoted(address user) internal view returns (bool) {
        return _getBallotVoted(user) != bytes32(0);
    }
}
