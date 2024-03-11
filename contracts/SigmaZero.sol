// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

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

    enum WageringStyle {
        Single,
        Group
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
        uint value;
        uint settledValue;
    }

    mapping(uint => Bet) public bets;
    mapping(uint => Bettor[]) public firstBettorsGroupByBetIndex;
    mapping(uint => Bettor[]) public secondBettorsGroupByBetIndex;
    mapping(uint => mapping(address => bool)) public isBettorParticipated;
    mapping(uint => mapping(address => bool)) public hasClaimedReward;

    event BetPlaced(
        address indexed initiator,
        address tokenAddress,
        BetType betType,
        uint wager,
        uint32 duration,
        uint indexed betIndex,
        uint value,
        uint auxiliaryValue,
        bytes32 option,
        WageringStyle wageringStyle,
        uint64 startDateTime
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
        bool isFirstGroupWinner,
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

    event RewardsClaimed(
        address bettor, 
        uint amount
    );

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function placeBet(
        address tokenAddress,
        uint32 duration,
        BetType betType,
        uint wager,
        uint value,
        uint auxiliaryValue,
        bytes32 option,
        uint64 startDateTime,
        WageringStyle wageringStyle
    ) external payable {
        betCount++;

        bets[betCount] = Bet({
            initiator: msg.sender,
            firstBettorsGroupPool: msg.value,
            secondBettorsGroupPool: 0,
            tokenAddress: tokenAddress,
            duration: duration,
            startDateTime: startDateTime,
            betType: betType,
            status: BetStatus.Initiated,
            value: 0,
            settledValue: 0
        });

        firstBettorsGroupByBetIndex[betCount].push(
            Bettor({bettor: msg.sender, wager: wager})
        );

        isBettorParticipated[betCount][msg.sender] = true;

        emit BetPlaced(
            msg.sender, 
            tokenAddress, 
            betType, 
            wager, 
            duration, 
            betCount, 
            value,
            auxiliaryValue,
            option,
            wageringStyle,
            startDateTime
        );
    }

    function setBetValue(
        uint betIndex,
        uint value
    ) external onlyAdmin betExists(betIndex) betInitiated(betIndex) {
        Bet storage bet = bets[betIndex];
        bet.value = value;
        bet.status = BetStatus.Approved;

        emit BetApproved(betIndex, bet.initiator, bet.betType);
    }

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
        require(!isBettorParticipated[betIndex][msg.sender], "Bettor already participated");

        Bettor memory bettor = Bettor({bettor: msg.sender, wager: wager});

        if (bettingGroup == 1) {
            firstBettorsGroupByBetIndex[betIndex].push(bettor);
            bet.firstBettorsGroupPool += wager;
        } else {
            secondBettorsGroupByBetIndex[betIndex].push(bettor);
            bet.secondBettorsGroupPool += wager;
        }

        isBettorParticipated[betIndex][msg.sender] = true;

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

        bet.status = BetStatus.Settled;
        bet.settledValue = value;

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

        for (uint i = 0; i < winners.length; i++) {
            Bettor memory bettor = winners[i];
            address payable bettorAddress = payable(bettor.bettor);
            uint payout = ((bettor.wager * pool) / selfPool) + bettor.wager;
            bool sent = bettorAddress.send(payout);

            if(sent) {
                hasClaimedReward[betIndex][bettor.bettor] = true;
            }
            payouts[i] = payout;
        }

        Bettor[] memory firstBettorsGroup = firstBettorsGroupByBetIndex[
            betIndex
        ];
        Bettor[] memory secondBettorsGroup = secondBettorsGroupByBetIndex[
            betIndex
        ];

        emit BetSettled(
            betIndex,
            bet.initiator,
            isFirstGroupWinner,
            firstBettorsGroup,
            secondBettorsGroup,
            bet.betType,
            winners,
            payouts
        );
    }

    function calculateBettorRewards(address sender, uint betIndex) internal view returns (uint) {
        Bet storage bet = bets[betIndex];
        bool isFirstGroupWinner = bet.settledValue >= bet.value;
        uint selfPool = isFirstGroupWinner ? bet.firstBettorsGroupPool : bet.secondBettorsGroupPool;
        uint pool = isFirstGroupWinner ? bet.secondBettorsGroupPool : bet.firstBettorsGroupPool;

        Bettor[] storage winners = isFirstGroupWinner ? firstBettorsGroupByBetIndex[betIndex] : secondBettorsGroupByBetIndex[betIndex];

        for (uint i = 0; i < winners.length; i++) {
            Bettor storage bettor = winners[i];

            if(bettor.bettor == sender) {
                uint payout = ((bettor.wager * pool) / selfPool) + bettor.wager;
                return payout;
            }
        }

        return 0;
    }

    function claimRewards(uint betIndex) external {
        require(bets[betIndex].status == BetStatus.Settled, "Bet is not settled");
        require(isBettorParticipated[betIndex][msg.sender], "Bettor did not participate");
        require(!hasClaimedReward[betIndex][msg.sender], "Reward already claimed");

        uint rewardAmount = calculateBettorRewards(msg.sender, betIndex);
        require(rewardAmount > 0, "No rewards to claim");

        bool sent = payable(msg.sender).send(rewardAmount);
        require(sent, "Failed to send reward");
        hasClaimedReward[betIndex][msg.sender] = true;
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
