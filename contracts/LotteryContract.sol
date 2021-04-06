// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <=0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
pragma experimental ABIEncoderV2;

//Rules:
// Every 10 min lottery will be announced
// Minimum ether value will be used for lottery
// 50% will go to social cause.
// with every annonced lottery, participant will get native token

contract LotteryContract is ERC20 {
    using SafeMath for uint256;
    mapping(address => uint256) private _currentLotNumber;
    uint256 private _defaultLotteryPrice;
    uint256 private _maxAnnounceTimeInSeconds;
    uint8 private _defaultMaxWinners;
    uint256 private _totalLotteries;
    uint256 private _tokenCount;
    mapping(uint256 => address) _tokenAddress;
    mapping(address => bool) hasToken;
    event LotteryBought(
        uint256 currentParticipant,
        uint256 lotteryAmount,
        address participant
    );
    event WinnersList(Participant[] winner);
    event Reward(address to, uint256 amount, address token);
    struct Participant {
        address participant;
        uint256 winningAmout;
    }
    struct LotteryLot {
        uint256 totalFund;
        Participant[] participants;
        uint256 lotteryStartedTime;
        // mapping(address => bool) participated;
    }

    struct LotterieForSpecificToken {
        mapping(uint256 => LotteryLot) lots;
    }
    mapping(address => LotterieForSpecificToken) private lotteryForToken;

    constructor(
        uint256 defaultLotteryPrice,
        uint64 maxAnnounceTimeInSeconds,
        uint8 defaultMaxWinners,
        string memory name,
        string memory symbole
    ) ERC20(name, symbole) {
        _mint(msg.sender, 10000000 * (10**decimals()));
        _defaultLotteryPrice = defaultLotteryPrice;
        _maxAnnounceTimeInSeconds = maxAnnounceTimeInSeconds;
        _defaultMaxWinners = defaultMaxWinners;
        _totalLotteries = 1;
        _tokenCount = 0;
    }

    function buyLottery(address token) external {
        ERC20 tokenContract = ERC20(token);
        checkRules(token);
        if (!hasToken[token]) {
            _tokenCount = _tokenCount.add(1);
            _tokenAddress[_tokenCount] = token;
            hasToken[token] = true;
        }
        uint256 lotteryAmount = _defaultLotteryPrice;
        lotteryAmount = lotteryAmount * (10**tokenContract.decimals()); // multiply by decimals
        // require(
        //     !lotteryForToken[token].lots[_currentLotNumber[token]].participated[
        //         _msgSender()
        //     ],
        //     "user has already participated in current lot"
        // );
        require(lotteryAmount > 0, "lottery amount must be greater than zero");
        tokenContract.transferFrom(_msgSender(), address(this), lotteryAmount);

        lotteryForToken[token].lots[_currentLotNumber[token]]
            .totalFund = lotteryForToken[token].lots[_currentLotNumber[token]]
            .totalFund
            .add(lotteryAmount);

        lotteryForToken[token].lots[_currentLotNumber[token]].participants.push(
            Participant(_msgSender(), 0)
        );
        // lotteryForToken[token].lots[_currentLotNumber[token]].participated[
        //     _msgSender()
        // ] = true;
        uint256 participantsNumber =
            lotteryForToken[token].lots[_currentLotNumber[token]]
                .participants
                .length;
        emit LotteryBought(participantsNumber, lotteryAmount, _msgSender());
    }

    function checkRules(address token) public {
        if (_currentLotNumber[token] == 0) {
            _currentLotNumber[token] = 1; // set initial lottery number if its first lot for token
        }
        if (
            lotteryForToken[token].lots[_currentLotNumber[token]]
                .lotteryStartedTime == 0
        ) {
            lotteryForToken[token].lots[_currentLotNumber[token]]
                .lotteryStartedTime = block.timestamp; // set initial lottery time if its first lot for token
        }

        // lottery result rule
        if (
            lotteryForToken[token].lots[_currentLotNumber[token]]
                .lotteryStartedTime +
                _maxAnnounceTimeInSeconds <=
            block.timestamp ||
            lotteryForToken[token].lots[_currentLotNumber[token]]
                .participants
                .length >=
            _defaultMaxWinners
        ) {
            pickWinner(token);

            _currentLotNumber[token] = _currentLotNumber[token].add(1);
            _totalLotteries = _totalLotteries.add(1);
        }
    }

    function random(address token) private view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.difficulty,
                        block.timestamp,
                        lotteryForToken[token].lots[_currentLotNumber[token]]
                            .participants
                            .length
                    )
                )
            );
    }

    // Participant[] _participants;

    function pickWinner(address token) private {
        Participant[] memory _participants =
            lotteryForToken[token].lots[_currentLotNumber[token]].participants;
        // Participant[] memory _afterResult;
        uint256 participantsNumber = _participants.length;
        uint256 totalRemainFund =
            lotteryForToken[token].lots[_currentLotNumber[token]].totalFund;
        ERC20 tokenContract = ERC20(token);
        if (participantsNumber == 1) {
            // if only one participant refund all amount
            address currentWinnersAddress =
                _participants[participantsNumber - 1].participant;
            tokenContract.transfer(currentWinnersAddress, totalRemainFund);
            lotteryForToken[token].lots[_currentLotNumber[token]].participants[
                participantsNumber - 1
            ] = Participant(currentWinnersAddress, totalRemainFund);
            totalRemainFund = 0;
        }
        while (participantsNumber > 0 && totalRemainFund > 0) {
            uint256 winingAmountForCurrentParticipant =
                random(token) % (totalRemainFund + 1);
            totalRemainFund = totalRemainFund.sub(
                winingAmountForCurrentParticipant
            );
            uint256 randomWinner = random(token) % participantsNumber;
            address currentWinnersAddress =
                _participants[randomWinner].participant;
            tokenContract.transfer(
                currentWinnersAddress,
                winingAmountForCurrentParticipant
            );
            lotteryForToken[token].lots[_currentLotNumber[token]].participants[
                participantsNumber - 1
            ] = Participant(
                currentWinnersAddress,
                winingAmountForCurrentParticipant
            );
            participantsNumber = participantsNumber.sub(1);
            _participants = removeWinner(
                randomWinner,
                _participants,
                participantsNumber
            );
        }
        payNativeTokenToLotteryAnnouncer(); //give reward to announcer.
        sendRemainBalanceToAnnouncer(token, totalRemainFund);
        emit WinnersList(
            lotteryForToken[token].lots[_currentLotNumber[token]].participants
        );
    }

    function removeWinner(
        uint256 winner,
        Participant[] memory _participants,
        uint256 swapWith
    ) private pure returns (Participant[] memory) {
        Participant[] memory swap = _participants;
        swap[winner] = swap[swapWith];
        return swap;
    }

    function getTotalTokenCount() external view returns (uint256) {
        return _tokenCount;
    }

    function getToken(uint256 number) external view returns (address) {
        return _tokenAddress[number];
    }

    function getCurrentLotteryNumber(address token)
        external
        view
        returns (uint256)
    {
        return _currentLotNumber[token];
    }

    function getDetails(address token, uint256 lotteryNumber)
        external
        view
        returns (
            uint256 totalFund,
            uint256 totalParticipants,
            Participant[] memory participants,
            uint256 lotteryStartedTime
        )
    {
        totalFund = lotteryForToken[token].lots[lotteryNumber].totalFund;
        totalParticipants = lotteryForToken[token].lots[lotteryNumber]
            .participants
            .length;
        participants = lotteryForToken[token].lots[lotteryNumber].participants;
        lotteryStartedTime = lotteryForToken[token].lots[lotteryNumber]
            .lotteryStartedTime;
    }

    function payNativeTokenToLotteryAnnouncer() private {
        uint256 maxReward = 500 * (10**decimals());
        uint8 halving = uint8(_totalLotteries / 200000); // Inflation every 200000 lottery
        _mint(msg.sender, maxReward >> halving); // reward native token to announcer,which will halv every 200000 lottery
        emit Reward(msg.sender, maxReward >> halving, address(this));
    }

    function sendRemainBalanceToAnnouncer(address token, uint256 remainAmount)
        private
    {
        ERC20 tokenContract = ERC20(token);
        tokenContract.transfer(msg.sender, remainAmount); // remaining amount to lottery announcer
        emit Reward(msg.sender, remainAmount, token);
    }
}

// TODO: announcer also get current token's remaing 10%
// store new token
// test for remain balance and token distribution and done :)
