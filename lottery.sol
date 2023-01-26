//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/// @notice Thrown when transfer of tokens at ERC20 `tokenAddress` fails
error DEX__TokenTransferFailed(address tokenAddress);

contract LotteryLUNAToken {
    // Libraries
    using SafeERC20 for IERC20;
    using Address for address;

    uint256 public ticketPrice = 25000000;
    uint256 public undoDecimal = 3;
    uint256 public constant maxTickets = 1000; // maximum tickets per lottery
    uint256 public constant maxTicketsAllow = 25; // maximum tickets each player can get in the lottery
    uint256 public ticketProject = 15000; // commission for project
    uint256 public ticketStaking = 29000; // commission for staking
    uint256 public ticketPot = 5000; // commission for the weekly jackpot
    uint256 public ticketDev = 1000; // dev comission for the project
    uint256 public constant duration = 1440 minutes; // The duration set for the lottery
    address private project_wallet = 0x77b23578264b6e2F6db8A7C66617D611331F6C11;
    address private staking_wallet = 0x2D153748ECC69D3591dFB7F84209cEdddED134fE;
    address private pot_wallet = 0xB69648Aff6CDE0179f6a9B11978f87b6bfB6f926;
    address private dev_wallet = 0x38028bF3d6856360A4D421c4D0DC3599e3aC09eb;
    uint256 public expiration; // Timeout in case That the lottery was not carried out.
    address public lotteryOperator; // the crator of the lottery
    uint256 public operatorTotalProject = 0; // the total commission balance
    uint256 public operatorTotalStaking = 0; // the total commission for staking
    uint256 public operatorTotalPot = 0; // the total commission for jackpot
    uint256 public operatorTotalDev = 0; // the total commission for the dev
    address public lastWinner; // the last winner of the lottery
    uint256 public lastWinnerAmount; // the last winner amount of the lottery
    uint256 public lotteryId; // get lotteryID

    mapping(address => uint256) public winnings; // maps the winners to there winnings
    address[] public tickets; //array of purchased Tickets

    event Received(address, uint256);
    
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
    // modifier to check if caller is the lottery operator
    modifier isOperator() {
        require(
            (msg.sender == lotteryOperator),
            "Caller is not the lottery operator"
        );
        _;
    }
    // modifier to check if caller is a winner
    modifier isWinner() {
        require(IsWinner(), "Caller is not a winner");
        _;
    }
    // modifier to check if caller is the lottery operator
    modifier isOwnable() {
        require(
            (msg.sender == lotteryOperator),
            "Only owner can change ownership"
        );
        _;
    }
    constructor() {
        lotteryOperator = msg.sender;
        expiration = block.timestamp + duration;
        lotteryId = 1;
    }
    //transfer ownership of the contract
    function transferOwnership(address _newOwner) public {
        require(msg.sender == lotteryOperator);
        lotteryOperator = _newOwner;  
    }
    // return all the tickets
    function getTickets() public view returns (address[] memory) {
        return tickets;
    }
    //get user balance
    function getBalance(address _tokenAddress) public view returns (uint256) {
        IERC20 _token = IERC20(_tokenAddress);
        return _token.balanceOf(msg.sender);
    }
    //get winnings for user address
    function getWinningsForAddress(address addr) public view returns (uint256) {
        return winnings[addr];
    }
    //get lottery ID
    function getLotteryId() public view returns(uint256) {
        return lotteryId;
    }
    //buytickets for LTT
    function BuyTickets(
        address _tokenAddress,
        uint256 _numOfTicketsToBuy
    ) public {
        require(
            _numOfTicketsToBuy <= RemainingTickets(),
            "Not enough tickets available."
        );
        IERC20 _token = IERC20(_tokenAddress);
        uint256 _tokenDecimal = IERC20Metadata(_tokenAddress).decimals();
        uint256 _totalCost = _numOfTicketsToBuy * (ticketPrice * (10 ** (_tokenDecimal - undoDecimal)));
        require(getBalance(_tokenAddress) >= _totalCost, "Not enough balance");

        for (uint256 i = 0; i < _numOfTicketsToBuy; i++) {
            tickets.push(msg.sender);
        }
        if (!_token.transferFrom(msg.sender, lotteryOperator, _totalCost))
            revert DEX__TokenTransferFailed(address(_token));
    }
    //let's draw a winner
    function DrawWinnerTicket() public isOperator {
        require(tickets.length > 0, "No tickets were purchased");

        bytes32 blockHash = blockhash(block.number - tickets.length);
        uint256 randomNumber = uint256(
            keccak256(abi.encodePacked(block.timestamp, blockHash))
        );
        uint256 winningTicket = randomNumber % tickets.length;
        address winner = tickets[winningTicket];
        lastWinner = winner;
        winnings[winner] += (tickets.length * ticketPrice) / 2;
        lastWinnerAmount = winnings[winner];
        operatorTotalProject += (tickets.length * ticketPrice) * ticketProject / 100;
        operatorTotalStaking += (tickets.length * ticketPrice) * ticketStaking / 100;
        operatorTotalPot += (tickets.length * ticketPrice) * ticketPot / 100;
        operatorTotalDev += (tickets.length * ticketPrice) * ticketDev / 100;
        delete tickets;
        expiration = block.timestamp + duration;
        lotteryId++;
    }
    //let's restart the draw
    function restartDraw() public isOperator {
        require(tickets.length == 0, "Cannot Restart Draw as Draw is in play");
        delete tickets;
        expiration = block.timestamp + duration;
    }
    //let's check winner amount
    function checkWinningsAmount() public view returns (uint256) {
        address payable winner = payable(msg.sender);
        uint256 reward2Transfer = winnings[winner];
        return reward2Transfer;
    }
    //withdraw winner winnings
    function WithdrawWinnings() public isWinner {
        address payable winner = payable(msg.sender);
        uint256 reward2Transfer = winnings[winner];
        winnings[winner] = 0;
        winner.transfer(reward2Transfer);

        address payable operator = payable(dev_wallet);
        uint256 dev2Transfer = operatorTotalDev;
        operatorTotalDev = 0;
        operator.transfer(dev2Transfer);
    }
    //withdraw project fees
    function WithdrawProject() public isOperator {
        address payable operator = payable(project_wallet);
        uint256 project2Transfer = operatorTotalProject;
        operatorTotalProject = 0;
        operator.transfer(project2Transfer);
    }
    //withdraw staking fees
    function WithdrawStaking() public isOperator {
        address payable operator = payable(staking_wallet);
        uint256 staking2Transfer = operatorTotalStaking;
        operatorTotalStaking = 0;
        operator.transfer(staking2Transfer);
    }
    //withdraw jackpot fees
    function WithdrawPot() public isOperator {
        address payable operator = payable(pot_wallet);
        uint256 pot2Transfer = operatorTotalPot;
        operatorTotalPot = 0;
        operator.transfer(pot2Transfer);
    }
    //let's refund all tickets and payments
    function RefundAll() public {
        require(block.timestamp >= expiration, "the lottery not expired yet");
        for (uint256 i = 0; i < tickets.length; i++) {
            address payable to = payable(tickets[i]);
            tickets[i] = address(0);
            to.transfer(ticketPrice);
        }
        delete tickets;
    }
    //Is a winner?
    function IsWinner() public view returns (bool) {
        return winnings[msg.sender] > 0;
    }
    //current winning reward
    function CurrentWinningReward() public view returns (uint256) {
        return tickets.length * ticketPrice;
    }
    //tickets left in the lottery
    function RemainingTickets() public view returns (uint256) {
        return maxTickets - tickets.length;
    }
    //set expiration time
    function setExpireTime(uint256 _time) public isOperator {
        expiration = _time;
    }
}