// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Lottery.sol";

contract LotteryTest is Test {
    Lottery public lottery;
    uint256 received_msg_value;
    function setUp() public {
       lottery = new Lottery();
       received_msg_value = 0;
       vm.deal(address(this), 100 ether);
       vm.deal(address(1), 100 ether);
       vm.deal(address(2), 100 ether);
       vm.deal(address(3), 100 ether);
    }

    function testGoodBuy() public {
        lottery.buy{value: 0.1 ether}(0);
    }

    function testInsufficientFunds1() public {
        vm.expectRevert();
        lottery.buy(0); // buy할 때 송금이 이루어져야 함
    }

    function testInsufficientFunds2() public {
        vm.expectRevert(); // buy에서 음수가 안되게 해야하나 언더플로가 안되게 해야하나?
        lottery.buy{value: 0.1 ether - 1}(0);
    }

    function testInsufficientFunds3() public {
        vm.expectRevert(); // ether와 int 계산이 어떻게 이뤄지는지 확인
        lottery.buy{value: 0.1 ether + 1}(0);
    }

    function testNoDuplicate() public {
        lottery.buy{value: 0.1 ether}(0);
        vm.expectRevert();
        lottery.buy{value: 0.1 ether}(0); //중복구입을 막는다??
    }

    function testSellPhaseFullLength() public {
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours - 1); // 누군가 구입을 하면 그때부터 페이즈가 24시간내에서 진행되는것으로 보임, 기준시간은 블럭 타임스탬프
        vm.prank(address(1));
        lottery.buy{value: 0.1 ether}(0);
    }

    function testNoBuyAfterPhaseEnd() public {
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours);
        vm.expectRevert();
        vm.prank(address(1));
        lottery.buy{value: 0.1 ether}(0);
    }

    function testNoDrawDuringSellPhase() public {
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours - 1); // 말그대로 페이즈 진행 내에는 추첨금지
        vm.expectRevert();
        lottery.draw();
    }

    function testNoClaimDuringSellPhase() public {
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours - 1);
        vm.expectRevert();
        lottery.claim(); // 페이즈 진행 중이니까 보상도 못꺼내감
    }

    function testDraw() public {
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours);
        lottery.draw(); 
    }

    function getNextWinningNumber() private returns (uint16) {
        uint256 snapshotId = vm.snapshot();
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        uint16 winningNumber = lottery.winningNumber(); // 당첨숫자 변수
        vm.revertTo(snapshotId);
        return winningNumber;
    }

    function testClaimOnWin() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber);  // buy의 인자는 추첨 번호인듯
        vm.warp(block.timestamp + 24 hours);
        uint256 expectedPayout = address(lottery).balance;
        lottery.draw();
        lottery.claim();
        assertEq(received_msg_value, expectedPayout); //당첨자가 모인거 전부 들고가는듯
    }

    function testNoClaimOnLose() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber + 1); vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        lottery.claim();
        assertEq(received_msg_value, 0);  // 클레임이 못맞췃다고 리버트같은거 시키지않는듯
    }

    function testNoDrawDuringClaimPhase() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber); vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        lottery.claim();
        vm.expectRevert();
        lottery.draw();   // 페이즈 끝나고 새로 풀이 열리기 전에는 드로우 리버트
    }

    function testRollover() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber + 1); vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        lottery.claim();

        winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber); vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        lottery.claim();  // 못맞춘거 이월되어서 다음에 맞춘사람에게 전부 정상적으로 가는지 확인
        assertEq(received_msg_value, 0.2 ether);
    }

    function testSplit() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber);
        vm.prank(address(1));
        lottery.buy{value: 0.1 ether}(winningNumber);
        vm.deal(address(1), 0);
        vm.warp(block.timestamp + 24 hours);
        lottery.draw();

        lottery.claim();
        assertEq(received_msg_value, 0.1 ether);

        vm.prank(address(1));
        lottery.claim();
        assertEq(address(1).balance, 0.1 ether);   //맞춘사람들에게 보상이 나눠서 들어오는지 확인
    }

    receive() external payable {
        received_msg_value = msg.value;
    }
}