// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

// q invalid initialization of the `Ownable` contract ???
contract Pot is Ownable {
    error Pot__RewardNotFound();
    error Pot__InsufficientFunds();
    error Pot__StillOpenForClaim();

    address[] private i_players; // q should be immutable, no ?
    uint256[] private i_rewards; // q should be immutable, no ?
    address[] private claimants;
    uint256 private immutable i_totalRewards;
    uint256 private i_deployedAt; // @audit should not be immutable since we are going to update it once the contest is closed
    IERC20 private immutable i_token;
    mapping(address => uint256) private playersToRewards; // e mapping that shows each player what reward they have
    uint256 private remainingRewards;
    uint256 private constant managerCutPercent = 10;

    // e we expect to have same number of players and rewards and then map them together [players[i] => rewards[i]
    // @audit - we don't have a check for the length of the players and rewards arrays so that could break the contracts
    // @audit - we don't check if the total rewards are equal to the sum of the rewards array, so we can pass any totalRewards, which can lead to arithmetic underflow/overflow
    constructor(address[] memory players, uint256[] memory rewards, IERC20 token, uint256 totalRewards)
        Ownable(msg.sender)
    {
        i_players = players;
        i_rewards = rewards;
        i_token = token;
        i_totalRewards = totalRewards;
        remainingRewards = totalRewards;
        i_deployedAt = block.timestamp;

        // i_token.transfer(address(this), i_totalRewards);

        // @audit-gas - could be used local `players` variable instead of `i_players` for the loop
        for (uint256 i = 0; i < players.length; i++) {
            // @audit-gas - could be used local rewards variable instead of `i_rewards` for the loop
            playersToRewards[players[i]] = rewards[i];
        }
    }

    // q could be `external` instead of `public`
    // @follow-up we are following CEI pattern (seems ok)
    function claimCut() public {
        address player = msg.sender;
        uint256 reward = playersToRewards[player];
        if (reward <= 0) {
            revert Pot__RewardNotFound();
        }
        playersToRewards[player] = 0;
        remainingRewards -= reward;
        claimants.push(player);
        _transferReward(player, reward);
    }

    // [player1, player2, player3]
    // [10, 15, 12]
    // totalRewards = 37

    // [player1] => 10 -> totalRewards = 27
    // [player3] => 12 -> totalRewards = 15

    // e when closing contest after 90 days, the contest manager will get 10% of the remaining rewards and the rest will be divided equally between the players
    // q possible reentracy issue, because we are not updating neither the remainingRewards nor the i_deployedAt after the first call
    // @audit since the owner of this contract is the ContestManager, contestManager would not be able to actually claim the managerCut
    function closePot(address manager) external onlyOwner {
        if (block.timestamp - i_deployedAt < 90 days) {
            revert Pot__StillOpenForClaim();
        }
        if (remainingRewards > 0) {
            // @audit - we should use some precision in order to calculate the managerCut because this way we can lose some rewards due to solidity floor division
            uint256 managerCut = remainingRewards / managerCutPercent;
            // i_deployedAt = block.timestamp;
            i_token.transfer(manager, managerCut);

            // @audit - should be distrubuted through the `cliamants` array instead of `players` array
            uint256 claimantCut = (remainingRewards - managerCut) / i_players.length; // (15 - 1.5) / 3 = 4.5
            // we can do a memory copy of `claimants` array and then iterate over it
            address[] memory _claimants = claimants;
            for (uint256 i = 0; i < _claimants.length; i++) {
                _transferReward(_claimants[i], claimantCut);
            }
        }
    }

    function _transferReward(address player, uint256 reward) internal {
        i_token.transfer(player, reward);
    }

    function getToken() public view returns (IERC20) {
        return i_token;
    }

    function checkCut(address player) public view returns (uint256) {
        return playersToRewards[player];
    }

    function getRemainingRewards() public view returns (uint256) {
        return remainingRewards;
    }
}
