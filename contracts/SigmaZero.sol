// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "hardhat/console.sol";

contract SigmaZero is AccessControl {
    uint public betCount;

    enum BetType {
        Liquidity,
        Volume,
        Price
    }

    enum BetStatus {
        Initiated,
        Approved,
        Close,
        Settled,
        Voided
    }

    struct Bettor {
        address bettor;
        uint wager;
    }

    struct Bet {
        address initiator;
        uint firstBettorsGroupPool;
        uint secondBettorsGroupPool;
        address tokenAddress;
        uint32 duration;
        uint64 startDateTime;
        BetType betType;
        BetStatus status;
        // This is the value related to the bet type: liquidity, volume, price
        uint value;
    }

    mapping(uint => Bet) public bets;
    mapping(uint => Bettor[]) public firstBettorsGroupByBetIndex;
    mapping(uint => Bettor[]) public secondBettorsGroupByBetIndex;

    event BetPlaced(
        address indexed initiator,
        BetType betType,
        uint wager,
        uint32 duration,
        uint indexed betIndex
    );

    event BettorAdded(
        address indexed bettor,
        uint indexed betIndex,
        uint wager,
        uint indexed bettingGroup
    );

    event BetSettled(
        uint indexed betIndex,
        address indexed initiator,
        Bettor[] firstBettorsGroup,
        Bettor[] secondBettorsGroup,
        BetType betType,
        Bettor[] winners,
        uint[] payouts
    );

    event BetVoided(
        uint indexed betIndex,
        address indexed initiator,
        BetType betType
    );

    event BetClosed(
        uint indexed betIndex,
        address indexed initiator,
        Bettor[] firstBettorsGroup,
        Bettor[] secondBettorsGroup,
        BetType betType
    );

    event BetApproved(
        uint indexed betIndex,
        address indexed initiator,
        BetType betType
    );

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function placeBet(
        address tokenAddress,
        uint32 duration,
        BetType betType,
        uint wager
    ) external payable {
        betCount++;

        bets[betCount] = Bet({
            initiator: msg.sender,
            firstBettorsGroupPool: msg.value,
            secondBettorsGroupPool: 0,
            tokenAddress: tokenAddress,
            duration: duration,
            startDateTime: 0,
            betType: betType,
            status: BetStatus.Initiated,
            value: 0
        });

        firstBettorsGroupByBetIndex[betCount].push(
            Bettor({bettor: msg.sender, wager: wager})
        );

        emit BetPlaced(msg.sender, betType, wager, duration, betCount);
    }

    function setBetValue(
        uint betIndex,
        uint value,
        uint64 startDateTime
    ) external onlyAdmin betExists(betIndex) betInitiated(betIndex) {
        Bet storage bet = bets[betIndex];
        bet.value = value;
        bet.status = BetStatus.Approved;
        bet.startDateTime = startDateTime;

        emit BetApproved(betIndex, bet.initiator, bet.betType);
    }

    //TODO: check if it's a good idea to allow the admin to void a bet
    function voidBet(
        uint betIndex
    )
        external
        onlyAdmin
        betExists(betIndex)
        betNotSettled(betIndex)
        betInitiated(betIndex)
    {
        Bet storage bet = bets[betIndex];

        bet.status = BetStatus.Voided;

        for (
            uint i = 0;
            i < firstBettorsGroupByBetIndex[betIndex].length;
            i++
        ) {
            Bettor memory bettor = firstBettorsGroupByBetIndex[betIndex][i];
            address payable bettorAddress = payable(bettor.bettor);
            bettorAddress.transfer(bettor.wager);
        }

        for (
            uint i = 0;
            i < secondBettorsGroupByBetIndex[betIndex].length;
            i++
        ) {
            Bettor memory bettor = secondBettorsGroupByBetIndex[betIndex][i];
            address payable bettorAddress = payable(bettor.bettor);
            bettorAddress.transfer(bettor.wager);
        }

        emit BetVoided(betIndex, bet.initiator, bet.betType);
    }

    //TODO: this is needed to set a limit to the time the users have to bet, check with client
    function closeBet(
        uint betIndex
    )
        external
        onlyAdmin
        betExists(betIndex)
        betNotExpired(betIndex)
        betApproved(betIndex)
    {
        Bet storage bet = bets[betIndex];

        bet.status = BetStatus.Close;

        emit BetClosed(
            betIndex,
            bet.initiator,
            firstBettorsGroupByBetIndex[betIndex],
            secondBettorsGroupByBetIndex[betIndex],
            bet.betType
        );
    }

    function addBettor(
        uint betIndex,
        uint bettingGroup,
        uint wager
    )
        external
        payable
        betExists(betIndex)
        betNotClosed(betIndex)
        betApproved(betIndex)
        betNotExpired(betIndex)
        betNotSettled(betIndex)
    {
        Bet storage bet = bets[betIndex];
        require(bettingGroup <= 2, "Invalid betting group");

        Bettor memory bettor = Bettor({bettor: msg.sender, wager: wager});

        if (bettingGroup == 1) {
            firstBettorsGroupByBetIndex[betIndex].push(bettor);
            bet.firstBettorsGroupPool += wager;
        } else {
            secondBettorsGroupByBetIndex[betIndex].push(bettor);
            bet.secondBettorsGroupPool += wager;
        }

        emit BettorAdded(msg.sender, betIndex, wager, bettingGroup);
    }

    function calculateResultsAndDistributeWinnings(
        uint betIndex,
        uint value
    )
        external
        onlyAdmin
        betExists(betIndex)
        betNotExpired(betIndex)
        betNotSettled(betIndex)
    {
        Bet storage bet = bets[betIndex];

        require(
            bet.status == BetStatus.Close,
            "Bet is not closed, cannot settle"
        );

        // Check which group won
        bool isFirstGroupWinner = value >= bet.value;
        Bettor[] memory winners = isFirstGroupWinner
            ? firstBettorsGroupByBetIndex[betIndex]
            : secondBettorsGroupByBetIndex[betIndex];
        uint selfPool = isFirstGroupWinner
            ? bet.firstBettorsGroupPool
            : bet.secondBettorsGroupPool;
        uint pool = isFirstGroupWinner
            ? bet.secondBettorsGroupPool
            : bet.firstBettorsGroupPool;

        uint[] memory payouts = new uint[](winners.length);
        // Perform calculations and distribute winnings
        for (uint i = 0; i < winners.length; i++) {
            Bettor memory bettor = winners[i];
            address payable bettorAddress = payable(bettor.bettor);
            uint payout = ((bettor.wager * pool) / selfPool) + bettor.wager;
            bettorAddress.transfer(payout);
            payouts[i] = payout;
        }

        bet.status = BetStatus.Settled;

        Bettor[] memory firstBettorsGroup = firstBettorsGroupByBetIndex[
            betIndex
        ];
        Bettor[] memory secondBettorsGroup = secondBettorsGroupByBetIndex[
            betIndex
        ];

        emit BetSettled(
            betIndex,
            bet.initiator,
            firstBettorsGroup,
            secondBettorsGroup,
            bet.betType,
            winners,
            payouts
        );
    }

    modifier betExists(uint betIndex) {
        require(betIndex <= betCount, "Bet does not exist");
        _;
    }

    modifier betNotSettled(uint betIndex) {
        require(
            bets[betIndex].status != BetStatus.Settled,
            "Bet is already settled"
        );
        _;
    }

    modifier betApproved(uint betIndex) {
        require(
            bets[betIndex].status == BetStatus.Approved,
            "Bet is not approved"
        );
        _;
    }

    modifier betInitiated(uint betIndex) {
        require(
            bets[betIndex].status == BetStatus.Initiated,
            "Bet is already approved"
        );
        _;
    }

    modifier betNotExpired(uint betIndex) {
        require(
            bets[betIndex].startDateTime + bets[betIndex].duration >
                block.timestamp,
            "Bet has expired"
        );
        _;
    }

    modifier betNotClosed(uint betIndex) {
        require(
            bets[betIndex].status != BetStatus.Close,
            "Bet is already closed"
        );
        _;
    }

    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Caller is not an admin"
        );
        _;
    }
}
