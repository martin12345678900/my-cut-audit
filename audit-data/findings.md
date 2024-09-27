[H-1] Array Out-of-Bounds Access in Constructor

Description: In the `Pot` contract constructor, there is a potential issue when the `players[]` array passed to the contract is larger than the `rewards[]` array. The loop attempts to map each player to a reward using the `players[]` and `rewards[]` arrays. However, if the length of `players[]` exceeds `rewards[]`, the contract will attempt to access an out-of-bounds index in `rewards[]`, causing a runtime error: `array out-of-bounds access (0x32)`.

Impact: This issue can cause unexpected contract behavior or deployment failure in cases where there is a mismatch in array lengths.

Proof of Concept: 

Run the following test case inside `TestMyCut.t.sol` to reproduce the error:

```javascript
    function testCreateContestWithDifferentCountOfPlayersAndRewards() public {
        address[] memory _players = new address[](3);
        address p1 = makeAddr("p1");
        address p2 = makeAddr("p2");
        address p3 = makeAddr("p3");

        _players[0] = p1;
        _players[1] = p2;
        _players[2] = p3;

        vm.prank(user);
        vm.expectRevert();
        // array out-of-bounds access (0x32)
        contest = ContestManager(conMan).createContest(_players, rewards, IERC20(ERC20Mock(weth)), 4);
    }
```

Recommended Mitigation: Possible mitigation would be to do a check inside the constructor if the `players[]` and `reward[]` arrays have the same length.

```diff
    constructor(address[] memory players, uint256[] memory rewards, IERC20 token, uint256 totalRewards)
        Ownable(msg.sender)
    {
+       if (players.length != rewards.length) {
+           revert Pot__NotSameLength();
+       }
        i_players = players;
        i_rewards = rewards;
        i_token = token;
        i_totalRewards = totalRewards;
        remainingRewards = totalRewards;
        i_deployedAt = block.timestamp;

        // i_token.transfer(address(this), i_totalRewards);

        for (uint256 i = 0; i < i_players.length; i++) {
            playersToRewards[i_players[i]] = i_rewards[i];
        }
    }
```


[H-2] Arithmetic Underflow in `Pot::claimCut` Function Due to Incorrect `Pot::totalRewards`

Description: The `Pot::claimCut` function has a vulnerability related to the potential for arithmetic underflow. The issue arises because there is no validation in the constructor to ensure that the sum of the rewards in `rewards[]` does not exceed the `totalRewards` value passed to the constructor. If the sum of the values in `rewards[]` is greater than `totalRewards`, the `Pot::remainingRewards` variable can become negative during function execution, leading to an arithmetic underflow and a panic error: `arithmetic underflow or overflow (0x11)`.

Impact: Players will be unable to claim rewards if this occurs, making the contract unusable.

Proof of Concept: 
Run the following test case inside `TestMyCut.t.sol` to prove the issue:

```javascript
    function testContestWithLessTotalRewardsThanTotalInsideRewardsArray() mintAndApproveTokens public {
        address[] memory _players = new address[](3);
        address p1 = makeAddr("p1");
        address p2 = makeAddr("p2");
        address p3 = makeAddr("p3");

        _players[0] = p1;
        _players[1] = p2;
        _players[2] = p3;

        rewards = [100e18, 150e18, 200e18];
        totalRewards = 150e18;

        vm.startPrank(user);
        contest = ContestManager(conMan).createContest(_players, rewards, IERC20(ERC20Mock(weth)), totalRewards);
        ContestManager(conMan).fundContest(0);
        vm.stopPrank();

        vm.prank(p1);
        Pot(contest).claimCut();

        vm.prank(p2);
        vm.expectRevert();
        Pot(contest).claimCut();
    }
```

Recommended Mitigation:
- One way would be do check inside the constructor if the totalRewards passed is `>=` the rewards calculated in the `rewards[]` array.
- Another way would be to not rely at all at `totalRewards` and do the calculation of totalRewards internally inside the `Pot` contract.


[H-3] TITLE (Root Cause + Impact)

Description: In the `Pot::closePot` function, the manager cut (managerCut) is transferred to `msg.sender`, which is the `ContestManager` contract itself. This results in the `managerCut` being transferred to the `ContestManager` contract instead of the actual owner (the user who deployed the contract). The `ContestManager` contract does not provide any mechanism for transferring or withdrawing the managerCut to the actual owner, effectively locking the funds inside the contract.

Impact: The owner of the ContestManager (the user who deployed it) has no way of withdrawing the `managerCut` from the contract, resulting in a significant loss of rewards that should belong to the owner.

Proof of Concept: 
This issue could be proved by running this test case inside `TestMyCut.t.sol`.

```javascript
    function testManagerCutGoesToManagerContestContractInsteadToManagerUser() mintAndApproveTokens public {
        address[] memory _players = new address[](3);
        address p1 = makeAddr("p1");
        address p2 = makeAddr("p2");
        address p3 = makeAddr("p3");

        _players[0] = p1;
        _players[1] = p2;
        _players[2] = p3;

        rewards = [100e18, 150e18, 200e18];
        totalRewards = 450e18;

        vm.startPrank(user);
        contest = ContestManager(conMan).createContest(_players, rewards, IERC20(ERC20Mock(weth)), totalRewards);
        ContestManager(conMan).fundContest(0);
        vm.stopPrank();

        vm.prank(p1);
        Pot(contest).claimCut();

        uint256 balanceOfContestManagerContractBefore = ERC20Mock(weth).balanceOf(conMan);
        uint256 balanceOfUserBefore = ERC20Mock(weth).balanceOf(user);
 
        vm.warp(91 days);
        vm.startPrank(user);
        ContestManager(conMan).closeContest(contest);
        vm.stopPrank();

        uint256 remainingRewards = Pot(contest).getRemainingRewards();
        uint256 managerCut = remainingRewards / managerCutPercent;

        uint256 balanceOfContestManagerContractAfter = ERC20Mock(weth).balanceOf(conMan);
        uint256 balanceOfUserAfter = ERC20Mock(weth).balanceOf(user);

        // e after closing the pot, the balance of user didn't change, instead of that the balance of the contest maanger contract increased by the manager cut
        assert(balanceOfUserBefore == balanceOfUserAfter);
        assert(balanceOfContestManagerContractAfter == balanceOfContestManagerContractBefore + managerCut);
    }
```

Recommended Mitigation:
- One possible solution would be to transfer the managerCut tokens to the owner isntead of the `msg.sender` inside the `Pot::closePot` function.
- Another possible solution would be to implement a mechanism which allows the owner to withdraw the managerCut funds to himself from the `ContestManager` contract.

```diff
    function _closeContest(address contest) internal {
        Pot pot = Pot(contest);
-        pot.closePot();
+        pot.closePot(msg.sender);
    }
```

```diff
-    function closePot() external onlyOnwer {
+    function closePot(address manager) external onlyOwner {
        if (block.timestamp - i_deployedAt < 90 days) {
            revert Pot__StillOpenForClaim();
        }
        if (remainingRewards > 0) {
            uint256 managerCut = remainingRewards / managerCutPercent;
-            i_token.transfer(msg.sender, managerCut);
+            i_token.transfer(manager, managerCut);

            uint256 claimantCut = (remainingRewards - managerCut) / i_players.length; // (15 - 1.5) / 3 = 4.5
            address[] memory _claimants = claimants;
            for (uint256 i = 0; i < _claimants.length; i++) {
                _transferReward(_claimants[i], claimantCut);
            }
        }
    }
```


[H-4] Precision Loss in `Pot::closePot` `managerCut` Calculation Leading to Lost Rewards

Description: In the `Pot::closePot` function, the calculation of `managerCut` uses integer division, which results in a loss of precision due to Solidity’s truncation of decimal points. The line `uint256 managerCut = remainingRewards / managerCutPercent;` divides `remainingRewards` by `managerCutPercent` without accounting for decimal values, leading to potential loss of a portion of the rewards. This precision issue can result in a situation where some rewards remain unallocated.

Impact: Some portion of the `remainingRewards` will be lost during the division, leaving the total rewards distributed inaccurately.


Recommended Mitigation:
- To preserve precision, multiply `remainingRewards` by a precision factor (e.g., 1**18) before performing the division, and then divide the result by `managerCutPercent`. Afterward, divide by the same precision factor to ensure accurate distribution:

```javascript
uint256 constant PRECISION = 1**18;
uint256 managerCut = (remainingRewards * PRECISION) / managerCutPercent;
managerCut = managerCut / PRECISION;
```


[M-1] Repeated `Pot::closePot` Exploit Due to Lack of State Update

Description: The `Pot::closePot` function allows the contest manager to distribute the `remainingRewards` after the contest has been open for 90 days. The problem arises because the contract does not update the `i_deployedAt` or reset the `remainingRewards` after the pot is closed. This creates a vulnerability where the contest manager can fund the contest again via the `ContestManager::fundContest` function and repeatedly call `Pot::closePot` to distribute the newly funded `remainingRewards`, effectively exploiting the system to claim additional rewards.

Impact: The contest manager can repeatedly exploit the system by funding and closing the pot, claiming additional rewards for themselves and redistributing funds unfairly.

Proof of Concept:
Run the following test case inside `TestMyCut.t.sol` to prove the issue:

```javascript
    function testCanCloseContestMultipleTimes() public mintAndApproveTokens {
        address[] memory _players = new address[](3);
        address p1 = makeAddr("p1");
        address p2 = makeAddr("p2");
        address p3 = makeAddr("p3");

        _players[0] = p1;
        _players[1] = p2;
        _players[2] = p3;

        rewards = [100e18, 150e18, 200e18];
        totalRewards = 450e18;

        vm.startPrank(user);
        // create the contest
        contest = ContestManager(conMan).createContest(_players, rewards, IERC20(ERC20Mock(weth)), totalRewards);
        // fund it with 450 WETH
        ContestManager(conMan).fundContest(0);
        vm.stopPrank();

        // Player 1 claims his cut (100 WETH)
        vm.startPrank(p1);
        Pot(contest).claimCut();
        vm.stopPrank();

        // Players 3 claims his cut (200 WETH)
        vm.startPrank(p3);
        Pot(contest).claimCut();
        vm.stopPrank();
        

        // we have left 150 WETH - 15 WETH for the manager and 135 WETH for the players (135 / 3 = 45 WETH per player)
        vm.warp(91 days);
        vm.prank(user);
        ContestManager(conMan).closeContest(contest); // 630 / 3 = 210
        
        // Once we fund the contest we can close the contest multiple times since all the rewards are claimed
        vm.prank(user);
        ContestManager(conMan).fundContest(0);

        while(ERC20Mock(weth).balanceOf(contest) > Pot(contest).getRemainingRewards()) {
            vm.prank(user);
            ContestManager(conMan).closeContest(contest);
        }
    }
```

Recommended Mitigation: Possible mitigation would be to reset the state values once the contest is cloesed for the first time and if the contest manager tries to reinvoke the function to have checks(requires) that stop him from doing that.

```javascript
remainingRewards = 0;
i_deployedAt = block.timestamp;
```