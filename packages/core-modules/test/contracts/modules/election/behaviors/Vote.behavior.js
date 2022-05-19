const { ethers } = hre;
const assert = require('assert/strict');
const assertBn = require('@synthetixio/core-js/utils/assertions/assert-bignumber');
const assertRevert = require('@synthetixio/core-js/utils/assertions/assert-revert');
const {
  takeSnapshot,
  restoreSnapshot,
  fastForwardTo,
} = require('@synthetixio/core-js/utils/hardhat/rpc');
const { ElectionPeriod } = require('../helpers/election-helper');
const { findEvent } = require('@synthetixio/core-js/utils/ethers/events');

module.exports = function (getElectionModule, getVotePower) {
  describe('Votes', function () {
    let candidate1, candidate2, candidate3, candidate4;
    let voter1, voter2, voter3, voter4, voter5, voter6, voter7, voter8;

    let ballot1, ballot2, ballot3;

    let receipt;

    let ElectionModule;

    let snapshotId;

    before('take snapshot', async function () {
      snapshotId = await takeSnapshot(ethers.provider);
    });

    after('restore snapshot', async function () {
      await restoreSnapshot(snapshotId, ethers.provider);
    });

    before('identify signers', async () => {
      const users = await ethers.getSigners();

      [candidate1, candidate2, candidate3, candidate4] = users;
      [, , , , voter1, voter2, voter3, voter4, voter5, voter6, voter7, voter8] = users;
    });

    before('retrieve the election module', async function () {
      ElectionModule = await getElectionModule();
    });

    describe('when entering the nomiantion period', function () {
      before('fast forward', async function () {
        await fastForwardTo(await ElectionModule.getNominationPeriodStartDate(), ethers.provider);
      });

      it('shows that the current period is Nomination', async function () {
        assertBn.equal(await ElectionModule.getCurrentPeriod(), ElectionPeriod.Nomination);
      });

      describe('when nominations exist', function () {
        before('nominate', async function () {
          await ElectionModule.connect(candidate1).nominate();
          await ElectionModule.connect(candidate2).nominate();
          await ElectionModule.connect(candidate3).nominate();
          await ElectionModule.connect(candidate4).nominate();
        });

        describe('when entering the election period', function () {
          before('fast forward', async function () {
            await fastForwardTo(await ElectionModule.getVotingPeriodStartDate(), ethers.provider);
          });

          it('shows that the current period is Vote', async function () {
            assertBn.equal(await ElectionModule.getCurrentPeriod(), ElectionPeriod.Vote);
          });

          describe('when issuing invalid votes', function () {
            describe('when voting with zero candidates', function () {
              it('reverts', async function () {
                await assertRevert(ElectionModule.cast([]), 'NoCandidates');
              });
            });

            describe('when voting candidates that are not nominated', function () {
              it('reverts', async function () {
                await assertRevert(
                  ElectionModule.cast([candidate1.address, candidate2.address, voter1.address]),
                  'NotNominated'
                );
              });
            });

            describe('when voting duplicate candidates', function () {
              it('reverts', async function () {
                await assertRevert(
                  ElectionModule.cast([candidate1.address, candidate2.address, candidate1.address]),
                  'DuplicateCandidates'
                );
              });
            });
          });

          it('can retrieve user vote power', async function () {
            const epochIndex = await ElectionModule.getEpochIndex();

            assertBn.equal(
              await ElectionModule.getVotePower(voter1.address),
              await getVotePower(voter1.address, epochIndex)
            );
            assertBn.equal(
              await ElectionModule.getVotePower(voter2.address),
              await getVotePower(voter2.address, epochIndex)
            );
            assertBn.equal(
              await ElectionModule.getVotePower(voter3.address),
              await getVotePower(voter3.address, epochIndex)
            );
          });

          describe('before issuing valid votes', function () {
            it('reflects users that have not voted', async function () {
              assert.equal(await ElectionModule.hasVoted(voter1.address), false);
              assert.equal(await ElectionModule.hasVoted(voter2.address), false);
              assert.equal(await ElectionModule.hasVoted(voter3.address), false);
              assert.equal(await ElectionModule.hasVoted(voter4.address), false);
            });

            describe('when attempting to withdraw a vote that does not exist', function () {
              it('reverts', async function () {
                await assertRevert(ElectionModule.withdrawVote(), 'VoteNotCasted');
              });
            });
          });

          describe('when issuing valid votes', function () {
            before('form ballots', async function () {
              ballot1 = {
                candidates: [candidate1.address],
                voters: [],
                id: await ElectionModule.calculateBallotId([candidate1.address]),
                votes: ethers.BigNumber.from(0),
              };
              ballot2 = {
                candidates: [candidate2.address, candidate4.address],
                voters: [],
                id: await ElectionModule.calculateBallotId([
                  candidate2.address,
                  candidate4.address,
                ]),
                votes: ethers.BigNumber.from(0),
              };
              ballot3 = {
                candidates: [candidate3.address],
                voters: [],
                id: await ElectionModule.calculateBallotId([candidate3.address]),
                votes: ethers.BigNumber.from(0),
              };
            });

            async function findAndRemovePreviousVote(voter) {
              const epochIndex = await ElectionModule.getEpochIndex();

              const ballot = [ballot1, ballot2, ballot3].find((ballot) =>
                ballot.voters.includes(voter.address)
              );

              if (ballot) {
                ballot.votes = ballot.votes.sub(await getVotePower(voter.address, epochIndex));
              }
            }

            async function cast(voter, ballot) {
              await findAndRemovePreviousVote(voter);

              const epochIndex = await ElectionModule.getEpochIndex();

              const tx = await ElectionModule.connect(voter).cast(ballot.candidates);
              receipt = await tx.wait();

              ballot.votes = ballot.votes.add(await getVotePower(voter.address, epochIndex));

              ballot.voters.push(voter.address);
            }

            before('vote', async function () {
              await cast(voter1, ballot1);
              await cast(voter2, ballot2);
              await cast(voter3, ballot1);
              await cast(voter4, ballot1);
              await cast(voter5, ballot2);
            });

            it('reflects users that have voted', async function () {
              assert.equal(await ElectionModule.hasVoted(voter1.address), true);
              assert.equal(await ElectionModule.hasVoted(voter2.address), true);
              assert.equal(await ElectionModule.hasVoted(voter3.address), true);
              assert.equal(await ElectionModule.hasVoted(voter4.address), true);
              assert.equal(await ElectionModule.hasVoted(voter5.address), true);
              assert.equal(await ElectionModule.hasVoted(voter6.address), false);
              assert.equal(await ElectionModule.hasVoted(voter7.address), false);
              assert.equal(await ElectionModule.hasVoted(voter8.address), false);
            });

            it('emitted a VoteRecorded event', async function () {
              const event = findEvent({ receipt, eventName: 'VoteRecorded' });

              assert.ok(event);
              assert.equal(event.args.voter, voter5.address);
              assert.equal(event.args.ballotId, ballot2.id);
              assert.deepEqual(event.args.votePower, await getVotePower(voter5.address, await ElectionModule.getEpochIndex()));
              assertBn.equal(event.args.epochIndex, 0);
            });

            it('can retrieve the corresponding ballot that users voted on', async function () {
              assert.equal(await ElectionModule.getBallotVoted(voter1.address), ballot1.id);
              assert.equal(await ElectionModule.getBallotVoted(voter2.address), ballot2.id);
              assert.equal(await ElectionModule.getBallotVoted(voter3.address), ballot1.id);
              assert.equal(await ElectionModule.getBallotVoted(voter4.address), ballot1.id);
              assert.equal(await ElectionModule.getBallotVoted(voter5.address), ballot2.id);
            });

            it('can retrieve ballot votes', async function () {
              assert.deepEqual(await ElectionModule.getBallotVotes(ballot1.id), ballot1.votes);
              assert.deepEqual(await ElectionModule.getBallotVotes(ballot2.id), ballot2.votes);
              assert.deepEqual(await ElectionModule.getBallotVotes(ballot3.id), ballot3.votes);
            });

            it('can retrive ballot candidates', async function () {
              assert.deepEqual(
                await ElectionModule.getBallotCandidates(ballot1.id),
                ballot1.candidates
              );
              assert.deepEqual(
                await ElectionModule.getBallotCandidates(ballot2.id),
                ballot2.candidates
              );
            });

            it('will retrieve no candidates for ballots that where not voted on', async function () {
              assert.deepEqual(await ElectionModule.getBallotCandidates(ballot3.id), []);
            });

            describe('when users change their vote', function () {
              before('change vote', async function () {
                await cast(voter5, ballot3);
              });

              it('emitted VoteWithdrawn and VoteRecorded events', async function () {
                let event;

                event = findEvent({ receipt, eventName: 'VoteWithdrawn' });
                assert.ok(event);
                assert.equal(event.args.voter, voter5.address);
                assert.equal(event.args.ballotId, ballot2.id);
                assert.deepEqual(event.args.votePower, await getVotePower(voter5.address, await ElectionModule.getEpochIndex()));
                assertBn.equal(event.args.epochIndex, 0);

                event = findEvent({ receipt, eventName: 'VoteRecorded' });
                assert.ok(event);
                assert.equal(event.args.voter, voter5.address);
                assert.equal(event.args.ballotId, ballot3.id);
                assert.deepEqual(event.args.votePower, await getVotePower(voter5.address, await ElectionModule.getEpochIndex()));
                assertBn.equal(event.args.epochIndex, 0);
              });

              it('can retrieve the corresponding ballot that users voted on', async function () {
                assert.equal(await ElectionModule.getBallotVoted(voter5.address), ballot3.id);
              });

              it('can retrieve ballot votes', async function () {
                assert.deepEqual(await ElectionModule.getBallotVotes(ballot1.id), ballot1.votes);
                assert.deepEqual(await ElectionModule.getBallotVotes(ballot2.id), ballot2.votes);
                assert.deepEqual(await ElectionModule.getBallotVotes(ballot3.id), ballot3.votes);
              });

              it('can retrive ballot candidates', async function () {
                assert.deepEqual(
                  await ElectionModule.getBallotCandidates(ballot3.id),
                  ballot3.candidates
                );
              });
            });

            describe('when users withdraw their vote', function () {
              before('withdraw vote', async function () {
                const tx = await ElectionModule.connect(voter4).withdrawVote();
                receipt = await tx.wait();

                findAndRemovePreviousVote(voter4);
              });

              it('emitted a VoteWithdrawn event', async function () {
                const event = findEvent({ receipt, eventName: 'VoteWithdrawn' });
                assert.ok(event);
                assert.equal(event.args.voter, voter4.address);
                assert.equal(event.args.ballotId, ballot1.id);
                assert.deepEqual(event.args.votePower, await getVotePower(voter4.address, await ElectionModule.getEpochIndex()));
                assertBn.equal(event.args.epochIndex, 0);
              });

              it('can retrieve the corresponding ballot that users voted on', async function () {
                assert.equal(
                  await ElectionModule.getBallotVoted(voter4.address),
                  '0x0000000000000000000000000000000000000000000000000000000000000000'
                );
              });

              it('shows that the user has not voted', async function () {
                assert.equal(await ElectionModule.hasVoted(voter4.address), false);
              });

              it('can retrieve ballot votes', async function () {
                assert.deepEqual(await ElectionModule.getBallotVotes(ballot1.id), ballot1.votes);
                assert.deepEqual(await ElectionModule.getBallotVotes(ballot2.id), ballot2.votes);
                assert.deepEqual(await ElectionModule.getBallotVotes(ballot3.id), ballot3.votes);
              });
            });
          });
        });
      });
    });
  });
};
