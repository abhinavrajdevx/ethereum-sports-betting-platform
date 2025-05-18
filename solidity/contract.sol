/**
 *Submitted for verification at polygonscan.com on 2025-05-17
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title BettingPlatform
 * @dev Allows owner to create bets, users to place bets, and distributes winnings
 */
contract BettingPlatform {
    address public owner;
    uint256 public platformFee = 10; // 10% fee
    uint256 public totalContractBalance;
    uint256 public ownerBalance;
    uint256 public betCount;

    enum BetStatus { OPEN, CLOSED, RESOLVED_FOR, RESOLVED_AGAINST, CANCELLED }

    struct Bet {
        uint256 id;
        string title;
        string description;
        string imageUrl;
        uint256 totalAmountFor;
        uint256 totalAmountAgainst;
        BetStatus status;
        address creator;
        mapping(address => uint256) betsFor;
        mapping(address => uint256) betsAgainst;
        mapping(address => bool) hasWithdrawn;
    }

    mapping(uint256 => Bet) public bets;
    
    event BetCreated(uint256 indexed betId, string title, address creator);
    event BetPlaced(uint256 indexed betId, address indexed bettor, uint256 amount, bool isFor);
    event BetResolved(uint256 indexed betId, BetStatus result);
    event Withdrawal(address indexed user, uint256 amount);
    event OwnerWithdrawal(uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier betExists(uint256 _betId) {
        require(_betId < betCount, "Bet does not exist");
        _;
    }

    modifier betIsOpen(uint256 _betId) {
        require(bets[_betId].status == BetStatus.OPEN, "Bet is not open");
        _;
    }

    constructor() {
        owner = msg.sender;
        betCount = 0;
    }

    /**
     * @dev Create a new bet
     * @param _title Title of the bet
     * @param _description Description of the bet
     * @param _imageUrl URL to an image representing the bet
     */
    function createBet(string memory _title, string memory _description, string memory _imageUrl) 
        external 
        onlyOwner 
        returns (uint256) 
    {
        uint256 betId = betCount;
        
        Bet storage newBet = bets[betId];
        newBet.id = betId;
        newBet.title = _title;
        newBet.description = _description;
        newBet.imageUrl = _imageUrl;
        newBet.status = BetStatus.OPEN;
        newBet.creator = msg.sender;
        
        emit BetCreated(betId, _title, msg.sender);
        
        betCount++;
        return betId;
    }

    /**
     * @dev Place a bet for or against
     * @param _betId ID of the bet
     * @param _isFor True if betting for, false if betting against
     */
    function placeBet(uint256 _betId, bool _isFor) 
        external 
        payable 
        betExists(_betId) 
        betIsOpen(_betId) 
    {
        require(msg.value > 0, "Bet amount must be greater than 0");
        
        Bet storage bet = bets[_betId];
        
        if (_isFor) {
            bet.betsFor[msg.sender] += msg.value;
            bet.totalAmountFor += msg.value;
        } else {
            bet.betsAgainst[msg.sender] += msg.value;
            bet.totalAmountAgainst += msg.value;
        }
        
        totalContractBalance += msg.value;
        
        emit BetPlaced(_betId, msg.sender, msg.value, _isFor);
    }

    /**
     * @dev Close betting for a specific bet
     * @param _betId ID of the bet to close
     */
    function closeBet(uint256 _betId) 
        external 
        onlyOwner 
        betExists(_betId) 
        betIsOpen(_betId) 
    {
        bets[_betId].status = BetStatus.CLOSED;
    }

    /**
     * @dev Resolve a bet and determine winners
     * @param _betId ID of the bet to resolve
     * @param _forWon True if "for" won, false if "against" won
     */
    function resolveBet(uint256 _betId, bool _forWon) 
        external 
        onlyOwner 
        betExists(_betId) 
    {
        Bet storage bet = bets[_betId];
        require(bet.status == BetStatus.OPEN || bet.status == BetStatus.CLOSED, "Bet already resolved");
        
        if (_forWon) {
            bet.status = BetStatus.RESOLVED_FOR;
        } else {
            bet.status = BetStatus.RESOLVED_AGAINST;
        }
        
        uint256 totalAmount = bet.totalAmountFor + bet.totalAmountAgainst;
        uint256 fee = (totalAmount * platformFee) / 100;
        ownerBalance += fee;
        
        emit BetResolved(_betId, bet.status);
    }

    /**
     * @dev Cancel a bet and allow everyone to withdraw their original amount
     * @param _betId ID of the bet to cancel
     */
    function cancelBet(uint256 _betId) 
        external 
        onlyOwner 
        betExists(_betId) 
    {
        Bet storage bet = bets[_betId];
        require(bet.status == BetStatus.OPEN || bet.status == BetStatus.CLOSED, "Bet already resolved");
        
        bet.status = BetStatus.CANCELLED;
        emit BetResolved(_betId, BetStatus.CANCELLED);
    }

    /**
     * @dev Withdraw winnings from a resolved bet
     * @param _betId ID of the resolved bet
     */
    function withdrawWinnings(uint256 _betId) 
        external 
        betExists(_betId) 
    {
        Bet storage bet = bets[_betId];
        require(bet.status == BetStatus.RESOLVED_FOR || 
                bet.status == BetStatus.RESOLVED_AGAINST || 
                bet.status == BetStatus.CANCELLED, 
                "Bet not resolved yet");
        
        require(!bet.hasWithdrawn[msg.sender], "Already withdrawn");
        
        uint256 amountToWithdraw = 0;
        
        if (bet.status == BetStatus.CANCELLED) {
            // If cancelled, return original bet amount
            amountToWithdraw = bet.betsFor[msg.sender] + bet.betsAgainst[msg.sender];
        } else if (bet.status == BetStatus.RESOLVED_FOR && bet.betsFor[msg.sender] > 0) {
            // If bet FOR and FOR won
            uint256 totalBetAmount = bet.totalAmountFor + bet.totalAmountAgainst;
            uint256 prizePot = (totalBetAmount * (100 - platformFee)) / 100;
            amountToWithdraw = (bet.betsFor[msg.sender] * prizePot) / bet.totalAmountFor;
        } else if (bet.status == BetStatus.RESOLVED_AGAINST && bet.betsAgainst[msg.sender] > 0) {
            // If bet AGAINST and AGAINST won
            uint256 totalBetAmount = bet.totalAmountFor + bet.totalAmountAgainst;
            uint256 prizePot = (totalBetAmount * (100 - platformFee)) / 100;
            amountToWithdraw = (bet.betsAgainst[msg.sender] * prizePot) / bet.totalAmountAgainst;
        }
        
        require(amountToWithdraw > 0, "No winnings to withdraw");
        
        bet.hasWithdrawn[msg.sender] = true;
        totalContractBalance -= amountToWithdraw;
        
        (bool success, ) = payable(msg.sender).call{value: amountToWithdraw}("");
        require(success, "Withdrawal failed");
        
        emit Withdrawal(msg.sender, amountToWithdraw);
    }

    /**
     * @dev Owner withdraws fees
     * @param _amount Amount to withdraw
     */
    function ownerWithdraw(uint256 _amount) 
        external 
        onlyOwner 
    {
        require(_amount <= ownerBalance, "Insufficient owner balance");
        
        ownerBalance -= _amount;
        totalContractBalance -= _amount;
        
        (bool success, ) = payable(owner).call{value: _amount}("");
        require(success, "Withdrawal failed");
        
        emit OwnerWithdrawal(_amount);
    }

    /**
     * @dev Get detailed bet information
     * @param _betId ID of the bet
     */
    function getBetDetails(uint256 _betId) 
        external 
        view 
        betExists(_betId) 
        returns (
            string memory title,
            string memory description,
            string memory imageUrl,
            uint256 totalAmountFor,
            uint256 totalAmountAgainst,
            BetStatus status
        ) 
    {
        Bet storage bet = bets[_betId];
        return (
            bet.title,
            bet.description,
            bet.imageUrl,
            bet.totalAmountFor,
            bet.totalAmountAgainst,
            bet.status
        );
    }

    /**
     * @dev Get user's bet amount
     * @param _betId ID of the bet
     * @param _bettor Address of the bettor
     */
    function getUserBetAmount(uint256 _betId, address _bettor) 
        external 
        view 
        betExists(_betId) 
        returns (uint256 forAmount, uint256 againstAmount) 
    {
        Bet storage bet = bets[_betId];
        return (bet.betsFor[_bettor], bet.betsAgainst[_bettor]);
    }
}