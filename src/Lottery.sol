pragma solidity ^0.8.13;
import {console} from "forge-std/console.sol";

contract Lottery{
    
    mapping(address => bool)[] public participant;
    mapping(address => uint) public to_give;
    mapping(uint => address[])[] public picked_history;
    mapping(uint => uint)[] public picked_people;
    // 페이즈별로 숫자마다 가변배열 만들어서 뽑은사람주소 기록
    uint16 public winningNumber;
    uint private current_phase;
    uint private state; // 0 == not start, 1 == in phase
    uint private start_time;

    function buy(uint number) external payable{
        require(msg.value == 0.1 ether, "You can buy only 0.1 ehter");
        if (state == 0)
        {
            state = 1;
            participant.push();
            start_time = block.timestamp;
            picked_history.push();
            picked_people.push();
        }
        else {
            require(block.timestamp < start_time + 24 hours, "nonono");
        }   
        require(participant[current_phase][msg.sender] == false, "Cant duplicate!");
        participant[current_phase][msg.sender] = true;
        if (picked_history[current_phase][number].length == 0)
            picked_history[current_phase][number].push();
        ++picked_people[current_phase][number];
        picked_history[current_phase][number].push(msg.sender);
    }
    function draw() external {
        require(start_time + 24 hours <= block.timestamp, "draw after 24hours when phase started ");
        require(state == 1, "must in phase");
        winningNumber = uint16(uint256(keccak256(abi.encode(block.timestamp))));
        uint winner = picked_people[current_phase][winningNumber];
        if (winner > 0)
        {
            uint money = address(this).balance / winner;
            uint len = picked_history[current_phase][winningNumber].length;
            for (uint i = 0; i < len; ++i)
                to_give[picked_history[current_phase][winningNumber][i]] += money;
        }
        state = 0;
        ++current_phase;
    }
    function claim() external{
        require(block.timestamp >= start_time + 24 hours, "Cant claim while in phase");
        if (to_give[msg.sender] > 0)
        {
            msg.sender.call{value: to_give[msg.sender]}("");
            to_give[msg.sender] = 0;
        }
    }
}


// 같은 페이즈내에 중복구입 불가
// 한 페이즈는 24시간 제한
// 페이즈가 끝나야 draw가 가능
// 맵핑을 2단계로해서 숫자에 누가 참여했는지 
// draw실행 시 당첨숫자 뽑고 해당 숫자에 참여한사람들의 어드레스를 to_give에 추가 및 분배금 작성
// claim시 to_give에 있는만큼 보내주고 0으로 만들기
// 드로우 하고 새로운 바이어 나타나면 새로운페이즈 시작이라 그전에 참가기록이 의미가없어지는데 어케하지


// 1. 참여한사람들의 목록을 가변배열로 만든 후, draw 시에 확인하면서 참여자목록 맵핑 내용 지우기
// 2. 참여자목록 맵핑을 배열로 만들어서 페이즈마다 쌓기
// 어차피 참여는 해당페이즈만 가능하니까 2번을 하는게 맞는거같기도 하고, 연산량도 적은거같기도.


// 페이즈 진행중에는 보상을 못꺼내간다->클레임되지 않은것들이 이월되지는 않게, 찾아갈수있게.