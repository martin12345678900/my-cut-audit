// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ContestManager} from "../src/ContestManager.sol";
import {Test, console} from "lib/forge-std/src/Test.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
import {Pot} from "../src/Pot.sol";

contract TestMyCut is Test {
    address conMan;
    address player1 = makeAddr("player1");
    address player2 = makeAddr("player2");
    // address player3 = makeAddr("player3");
    // address[] players = [player1, player2, player3];
    address[] players = [player1, player2];
    uint256 public constant STARTING_USER_BALANCE = 1000 ether;
    ERC20Mock weth;
    address contest;
    address[] totalContests;
    uint256[] rewards = [3, 1];
    address user = makeAddr("user");
    uint256 totalRewards = 4;

    function setUp() public {
        vm.startPrank(user);
        // DeployContestManager deploy = new DeployContestManager();
        conMan = address(new ContestManager());
        weth = new ERC20Mock("WETH", "WETH", msg.sender, 1000e8);
        // console.log("WETH Address: ", address(weth));
        // console.log("Test Address: ", address(this));
        console.log("User Address: ", user);
        // (conMan) = deploy.run();
        console.log("Contest Manager Address 1: ", address(conMan));
        vm.stopPrank();
    }

    modifier mintAndApproveTokens() {
        console.log("Minting tokens to: ", user);
        vm.startPrank(user);
        ERC20Mock(weth).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(weth).approve(conMan, STARTING_USER_BALANCE);
        console.log("Approved tokens to: ", address(conMan));
        vm.stopPrank();
        _;
    }

    function testCanCreatePot() public mintAndApproveTokens {
        console.log("Contest Manager Owner: ", ContestManager(conMan).owner());
        console.log("msg.sender: ", msg.sender);
        vm.startPrank(user);
        contest = ContestManager(conMan).createContest(players, rewards, IERC20(ERC20Mock(weth)), 4);
        totalContests = ContestManager(conMan).getContests();
        vm.stopPrank();
        assertEq(totalContests.length, 1);
    }

    function testCanFundPot() public mintAndApproveTokens {
        vm.startPrank(user);
        contest = ContestManager(conMan).createContest(players, rewards, IERC20(ERC20Mock(weth)), 4);
        ContestManager(conMan).fundContest(0);
        vm.stopPrank();
        assertEq(ERC20Mock(weth).balanceOf(contest), 4);
    }

    function testCanClaimCut() public mintAndApproveTokens {
        vm.startPrank(user);
        contest = ContestManager(conMan).createContest(players, rewards, IERC20(ERC20Mock(weth)), 4);
        ContestManager(conMan).fundContest(0);
        vm.stopPrank();
        // player balance before
        uint256 balanceBefore = ERC20Mock(weth).balanceOf(player1);
        vm.startPrank(player1);
        Pot(contest).claimCut();
        vm.stopPrank();
        // player balance after
        uint256 balanceAfter = ERC20Mock(weth).balanceOf(player1);
        assert(balanceAfter > balanceBefore);
    }

    function testCantClaimCut() public mintAndApproveTokens {
        vm.startPrank(user);
        contest = ContestManager(conMan).createContest(players, rewards, IERC20(ERC20Mock(weth)), 4);
        ContestManager(conMan).fundContest(0);
        vm.stopPrank();
        // player balance before
        uint256 balanceBefore = ERC20Mock(weth).balanceOf(player1);

        address randomPlayer = makeAddr("randomPlayer");
        vm.startPrank(randomPlayer);
        Pot(contest).claimCut();
        vm.stopPrank();

        uint256 balanceAfter = ERC20Mock(weth).balanceOf(randomPlayer);
        assert(balanceAfter > balanceBefore);
    }

    function testCantCloseContestEarly() public mintAndApproveTokens {
        vm.startPrank(user);
        contest = ContestManager(conMan).createContest(players, rewards, IERC20(ERC20Mock(weth)), 4);
        ContestManager(conMan).fundContest(0);
        vm.expectRevert();
        ContestManager(conMan).closeContest(contest);
        vm.stopPrank();
    }

    function testGetRemainingRewards() public mintAndApproveTokens {
        vm.startPrank(user);
        contest = ContestManager(conMan).createContest(players, rewards, IERC20(ERC20Mock(weth)), 4);
        ContestManager(conMan).fundContest(0);
        vm.stopPrank();

        vm.startPrank(player1);
        Pot(contest).claimCut();
        vm.stopPrank();

        uint256 remainingRewards = Pot(contest).getRemainingRewards();
        assert(remainingRewards < 4);
    }

    function testGetTotalRewards() public mintAndApproveTokens {
        vm.startPrank(user);
        contest = ContestManager(conMan).createContest(players, rewards, IERC20(ERC20Mock(weth)), 4);
        ContestManager(conMan).fundContest(0);
        vm.stopPrank();

        uint256 rewardsSum = ContestManager(conMan).getContestTotalRewards(contest);
        assertEq(rewardsSum, 4);
    }

    function testCanAddMultipleContests() public mintAndApproveTokens {
        vm.startPrank(user);
        contest = ContestManager(conMan).createContest(players, rewards, IERC20(ERC20Mock(weth)), 4);
        ContestManager(conMan).fundContest(0);
        contest = ContestManager(conMan).createContest(players, rewards, IERC20(ERC20Mock(weth)), 4);
        ContestManager(conMan).fundContest(1);
        vm.stopPrank();

        address[] memory contests = ContestManager(conMan).getContests();
        uint256 totalBalance = 0;
        for (uint256 i = 0; i < contests.length; i++) {
            totalBalance += ERC20Mock(weth).balanceOf(contests[i]);
        }
        console.log("Total Balance: ", totalBalance);
        assertEq(totalBalance, 8);
    }

    function testCanGetContests() public mintAndApproveTokens {
        vm.startPrank(user);
        contest = ContestManager(conMan).createContest(players, rewards, IERC20(ERC20Mock(weth)), 4);
        ContestManager(conMan).fundContest(0);
        contest = ContestManager(conMan).createContest(players, rewards, IERC20(ERC20Mock(weth)), 4);
        ContestManager(conMan).fundContest(1);
        vm.stopPrank();

        address[] memory contests = ContestManager(conMan).getContests();
        assertEq(contests.length, 2);
    }

    function testCanCloseContest() public mintAndApproveTokens {
        vm.startPrank(user);
        contest = ContestManager(conMan).createContest(players, rewards, IERC20(ERC20Mock(weth)), 4);
        ContestManager(conMan).fundContest(0);
        vm.stopPrank();

        vm.startPrank(player1);
        Pot(contest).claimCut();
        vm.stopPrank();
        vm.startPrank(player2);
        Pot(contest).claimCut();
        vm.stopPrank();

        vm.warp(91 days);

        vm.startPrank(user);
        ContestManager(conMan).closeContest(contest);
        vm.stopPrank();
    }

    function testUnclaimedRewardDistribution() public mintAndApproveTokens {
        vm.startPrank(user);
        rewards = [500, 500];
        totalRewards = 1000;
        contest = ContestManager(conMan).createContest(players, rewards, IERC20(ERC20Mock(weth)), totalRewards);
        ContestManager(conMan).fundContest(0);
        vm.stopPrank();

        vm.startPrank(player1);
        Pot(contest).claimCut();
        vm.stopPrank();

        uint256 claimantBalanceBefore = ERC20Mock(weth).balanceOf(player1);

        vm.warp(91 days);

        vm.startPrank(user);
        ContestManager(conMan).closeContest(contest);
        vm.stopPrank();

        uint256 claimantBalanceAfter = ERC20Mock(weth).balanceOf(player1);

        assert(claimantBalanceAfter > claimantBalanceBefore);
    }

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
}
