// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
error Lottery_NotEnoughEth();
error Lottery_TransactionFailed();
error Lottery__NotOpen();
error Lottery_UpKeepNotNeeded(uint balance ,uint players,uint state);
import '@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol';
import '@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol';
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
contract Lottery is  VRFConsumerBaseV2, AutomationCompatibleInterface{
    enum LotteryState{ 
        OPEN,
        CALCULATING_WINNER
    }
    

    event Lotteryenter(address indexed player);
    event requestLotteryWinenr(uint indexed requestId);
    event WinnerPicked(address indexed winner);

    uint private immutable i_entranceFee;
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_keyHash;
    uint64 private immutable i_subscriptionID ;
    uint8 private constant REQUEST_CONFIRMATIONS =3;
    uint32 private immutable i_callbackGasLimit ;
    uint8 private constant NUM_WORDS =1;
    uint private s_lastTime;
    uint private immutable i_timelapse;
    address private s_recentWinner;
    LotteryState private s_state;

    constructor(address vrfCoordinator,uint entrancefee,bytes32 keyHash,uint64 subscriptionID,uint32 callbackGasLimit,uint interval) VRFConsumerBaseV2(vrfCoordinator){
        i_entranceFee = entrancefee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_keyHash = keyHash;
        i_subscriptionID =subscriptionID;
        i_callbackGasLimit =callbackGasLimit;
        s_state = LotteryState.OPEN;
        i_timelapse = interval;
        s_lastTime = block.timestamp;
    }

    function checkUpkeep (bytes memory) public override returns(bool upKeepNeeded,bytes memory){
        bool isOpen = (s_state == LotteryState.OPEN);
        bool enoughPlayers = s_players.length > 0;
        bool hasBalance  = address(this).balance >0;
        bool timePassed = ((block.timestamp - s_lastTime) >= i_timelapse );
         upKeepNeeded =(isOpen && enoughPlayers && hasBalance && timePassed);
        return (upKeepNeeded,abi.encode(0));

    }

    function enterlottery()  payable public{
        if(msg.value <i_entranceFee){
            revert Lottery_NotEnoughEth();
        }
        if(s_state != LotteryState.OPEN){
            revert Lottery__NotOpen();
        }
        s_players.push(payable(msg.sender));
        emit Lotteryenter(msg.sender);
    }

    function performUpkeep (bytes calldata ) external override{
        (bool upKeepNeeded, ) = checkUpkeep("");
        if(!upKeepNeeded){
            revert Lottery_UpKeepNotNeeded(address(this).balance , s_players.length, uint(s_state));
        }
        s_state = LotteryState.CALCULATING_WINNER;
       uint requestId = i_vrfCoordinator.requestRandomWords(
            i_keyHash,
            i_subscriptionID,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit requestLotteryWinenr(requestId);
        
    }
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords)  internal override {
        uint8 indexOfWinner = uint8(_randomWords[0] % s_players.length);
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_state = LotteryState.OPEN;
        s_players = new address payable[](0);
        s_lastTime = block.timestamp;
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if(!success){
            revert Lottery_TransactionFailed();
        }
        emit WinnerPicked(recentWinner);

    }
    function getEntranceFees() public view  returns (uint ) {
        return i_entranceFee;
    }
    
    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getLotteryState() public view  returns (LotteryState) {
        return s_state;
    }
    function getNum_Words() public pure  returns (uint ) {
        return NUM_WORDS;
    }
    function getLastTimeStamp() public view  returns (uint ) {
        return s_lastTime;
    }
    function getPlayersLength() public view  returns (uint ) {
        return s_players.length;
    }
    function getRequestConfirmation() public pure  returns (uint ) {
        return REQUEST_CONFIRMATIONS;
    }
    
}