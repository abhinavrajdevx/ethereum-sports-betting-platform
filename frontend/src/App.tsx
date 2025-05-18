import React, { useState, useEffect, useCallback } from "react";
import { ethers } from "ethers";

const EnhancedBettingPlatform = () => {
  // States
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);
  const [contract, setContract] = useState(null);
  const [account, setAccount] = useState("");
  const [isOwner, setIsOwner] = useState(false);
  const [contractOwner, setContractOwner] = useState("");
  const [platformFee, setPlatformFee] = useState(0);
  const [ownerBalance, setOwnerBalance] = useState(0);
  const [totalContractBalance, setTotalContractBalance] = useState(0);
  
  // UI states
  const [darkMode, setDarkMode] = useState(false);
  const [activeTab, setActiveTab] = useState("bets");
  
  // Bet states
  const [bets, setBets] = useState([]);
  const [filteredBets, setFilteredBets] = useState([]);
  const [selectedBet, setSelectedBet] = useState(null);
  const [betAmount, setBetAmount] = useState("");
  const [betSide, setBetSide] = useState(true); // true for "For", false for "Against"
  const [loading, setLoading] = useState(false);
  const [userBets, setUserBets] = useState({ forAmount: 0, againstAmount: 0 });
  
  // Create bet states
  const [newBetTitle, setNewBetTitle] = useState("");
  const [newBetDescription, setNewBetDescription] = useState("");
  const [newBetImageUrl, setNewBetImageUrl] = useState("");
  
  // Filter states
  const [searchTerm, setSearchTerm] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [sortBy, setSortBy] = useState("newest");
  
  // User stats
  const [userStats, setUserStats] = useState({
    totalBetsPlaced: 0,
    totalAmountBet: 0,
    totalWinnings: 0,
    activeBets: [],
    pastBets: [],
  });
  
  // Notification states
  const [errorMessage, setErrorMessage] = useState("");
  const [successMessage, setSuccessMessage] = useState("");
  
  // Contract details
  const contractAddress = "0x7E5d671d4E209D8335fc6992E3fa90D654942900";
  
  // ABI from your contract
  const contractABI = [
    { inputs: [], stateMutability: "nonpayable", type: "constructor" },
    {
      anonymous: false,
      inputs: [
        {
          indexed: true,
          internalType: "uint256",
          name: "betId",
          type: "uint256",
        },
        {
          indexed: false,
          internalType: "string",
          name: "title",
          type: "string",
        },
        {
          indexed: false,
          internalType: "address",
          name: "creator",
          type: "address",
        },
      ],
      name: "BetCreated",
      type: "event",
    },
    {
      anonymous: false,
      inputs: [
        {
          indexed: true,
          internalType: "uint256",
          name: "betId",
          type: "uint256",
        },
        {
          indexed: true,
          internalType: "address",
          name: "bettor",
          type: "address",
        },
        {
          indexed: false,
          internalType: "uint256",
          name: "amount",
          type: "uint256",
        },
        { indexed: false, internalType: "bool", name: "isFor", type: "bool" },
      ],
      name: "BetPlaced",
      type: "event",
    },
    {
      anonymous: false,
      inputs: [
        {
          indexed: true,
          internalType: "uint256",
          name: "betId",
          type: "uint256",
        },
        {
          indexed: false,
          internalType: "enum BettingPlatform.BetStatus",
          name: "result",
          type: "uint8",
        },
      ],
      name: "BetResolved",
      type: "event",
    },
    {
      anonymous: false,
      inputs: [
        {
          indexed: false,
          internalType: "uint256",
          name: "amount",
          type: "uint256",
        },
      ],
      name: "OwnerWithdrawal",
      type: "event",
    },
    {
      anonymous: false,
      inputs: [
        {
          indexed: true,
          internalType: "address",
          name: "user",
          type: "address",
        },
        {
          indexed: false,
          internalType: "uint256",
          name: "amount",
          type: "uint256",
        },
      ],
      name: "Withdrawal",
      type: "event",
    },
    {
      inputs: [],
      name: "betCount",
      outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
      stateMutability: "view",
      type: "function",
    },
    {
      inputs: [{ internalType: "uint256", name: "", type: "uint256" }],
      name: "bets",
      outputs: [
        { internalType: "uint256", name: "id", type: "uint256" },
        { internalType: "string", name: "title", type: "string" },
        { internalType: "string", name: "description", type: "string" },
        { internalType: "string", name: "imageUrl", type: "string" },
        { internalType: "uint256", name: "totalAmountFor", type: "uint256" },
        {
          internalType: "uint256",
          name: "totalAmountAgainst",
          type: "uint256",
        },
        {
          internalType: "enum BettingPlatform.BetStatus",
          name: "status",
          type: "uint8",
        },
        { internalType: "address", name: "creator", type: "address" },
      ],
      stateMutability: "view",
      type: "function",
    },
    {
      inputs: [{ internalType: "uint256", name: "_betId", type: "uint256" }],
      name: "cancelBet",
      outputs: [],
      stateMutability: "nonpayable",
      type: "function",
    },
    {
      inputs: [{ internalType: "uint256", name: "_betId", type: "uint256" }],
      name: "closeBet",
      outputs: [],
      stateMutability: "nonpayable",
      type: "function",
    },
    {
      inputs: [
        { internalType: "string", name: "_title", type: "string" },
        { internalType: "string", name: "_description", type: "string" },
        { internalType: "string", name: "_imageUrl", type: "string" },
      ],
      name: "createBet",
      outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
      stateMutability: "nonpayable",
      type: "function",
    },
    {
      inputs: [{ internalType: "uint256", name: "_betId", type: "uint256" }],
      name: "getBetDetails",
      outputs: [
        { internalType: "string", name: "title", type: "string" },
        { internalType: "string", name: "description", type: "string" },
        { internalType: "string", name: "imageUrl", type: "string" },
        { internalType: "uint256", name: "totalAmountFor", type: "uint256" },
        {
          internalType: "uint256",
          name: "totalAmountAgainst",
          type: "uint256",
        },
        {
          internalType: "enum BettingPlatform.BetStatus",
          name: "status",
          type: "uint8",
        },
      ],
      stateMutability: "view",
      type: "function",
    },
    {
      inputs: [
        { internalType: "uint256", name: "_betId", type: "uint256" },
        { internalType: "address", name: "_bettor", type: "address" },
      ],
      name: "getUserBetAmount",
      outputs: [
        { internalType: "uint256", name: "forAmount", type: "uint256" },
        { internalType: "uint256", name: "againstAmount", type: "uint256" },
      ],
      stateMutability: "view",
      type: "function",
    },
    {
      inputs: [],
      name: "owner",
      outputs: [{ internalType: "address", name: "", type: "address" }],
      stateMutability: "view",
      type: "function",
    },
    {
      inputs: [],
      name: "ownerBalance",
      outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
      stateMutability: "view",
      type: "function",
    },
    {
      inputs: [{ internalType: "uint256", name: "_amount", type: "uint256" }],
      name: "ownerWithdraw",
      outputs: [],
      stateMutability: "nonpayable",
      type: "function",
    },
    {
      inputs: [
        { internalType: "uint256", name: "_betId", type: "uint256" },
        { internalType: "bool", name: "_isFor", type: "bool" },
      ],
      name: "placeBet",
      outputs: [],
      stateMutability: "payable",
      type: "function",
    },
    {
      inputs: [],
      name: "platformFee",
      outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
      stateMutability: "view",
      type: "function",
    },
    {
      inputs: [
        { internalType: "uint256", name: "_betId", type: "uint256" },
        { internalType: "bool", name: "_forWon", type: "bool" },
      ],
      name: "resolveBet",
      outputs: [],
      stateMutability: "nonpayable",
      type: "function",
    },
    {
      inputs: [],
      name: "totalContractBalance",
      outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
      stateMutability: "view",
      type: "function",
    },
    {
      inputs: [{ internalType: "uint256", name: "_betId", type: "uint256" }],
      name: "withdrawWinnings",
      outputs: [],
      stateMutability: "nonpayable",
      type: "function",
    },
  ];

  // Connect to wallet and contract
  const connectWallet = async () => {
    try {
      setLoading(true);
      setErrorMessage("");

      if (!window.ethereum) {
        setErrorMessage("Please install MetaMask to use this application");
        setLoading(false);
        return;
      }

      // Request account access
      const accounts = await window.ethereum.request({
        method: "eth_requestAccounts",
      });
      const account = accounts[0];
      setAccount(account);

      // Create ethers provider and signer
      const provider = new ethers.BrowserProvider(window.ethereum);
      setProvider(provider);

      const signer = await provider.getSigner();
      setSigner(signer);

      // Create contract instance
      const contract = new ethers.Contract(
        contractAddress,
        contractABI,
        signer
      );
      setContract(contract);

      // Check if user is owner
      const ownerAddress = await contract.owner();
      setContractOwner(ownerAddress);
      setIsOwner(ownerAddress.toLowerCase() === account.toLowerCase());

      // Get platform fee
      const fee = await contract.platformFee();
      setPlatformFee(fee.toString());

      // Get owner balance
      const balance = await contract.ownerBalance();
      setOwnerBalance(ethers.formatEther(balance));

      // Get total contract balance
      const totalBalance = await contract.totalContractBalance();
      setTotalContractBalance(ethers.formatEther(totalBalance));

      // Load bets
      await loadBets(contract);

      // Load user stats
      await loadUserStats(contract, account);

      setSuccessMessage("Wallet connected successfully!");
      setLoading(false);

      // Listen for account changes
      window.ethereum.on("accountsChanged", handleAccountsChanged);
      window.ethereum.on("chainChanged", () => window.location.reload());
    } catch (error) {
      console.error("Error connecting wallet:", error);
      setErrorMessage("Failed to connect wallet: " + error.message);
      setLoading(false);
    }
  };

  // Handle account changes
  const handleAccountsChanged = async (accounts) => {
    if (accounts.length === 0) {
      // User disconnected wallet
      setAccount("");
      setIsOwner(false);
      return;
    }
    
    const account = accounts[0];
    setAccount(account);
    
    if (contract) {
      const ownerAddress = await contract.owner();
      setIsOwner(ownerAddress.toLowerCase() === account.toLowerCase());
      await loadUserStats(contract, account);
    }
  };

  // Load bets from the contract
  const loadBets = async (contractInstance) => {
    try {
      setLoading(true);
      const contract = contractInstance || contract;
      if (!contract) return;

      const betCount = await contract.betCount();
      const betsArray = [];

      for (let i = 0; i < betCount.toString(); i++) {
        try {
          const betDetails = await contract.getBetDetails(i);
          const bet = await contract.bets(i); // Get additional bet info

          betsArray.push({
            id: i,
            title: betDetails[0],
            description: betDetails[1],
            imageUrl: betDetails[2],
            totalAmountFor: ethers.formatEther(betDetails[3]),
            totalAmountAgainst: ethers.formatEther(betDetails[4]),
            status: betDetails[5],
            creator: bet.creator,
            createdAt: new Date().getTime() - (i * 86400000), // Mock creation time for sorting
          });
        } catch (error) {
          console.error(`Error loading bet ${i}:`, error);
        }
      }

      setBets(betsArray);
      applyFilters(betsArray, searchTerm, statusFilter, sortBy);
      setLoading(false);
    } catch (error) {
      console.error("Error loading bets:", error);
      setErrorMessage("Failed to load bets: " + error.message);
      setLoading(false);
    }
  };

  // Load user betting stats
  const loadUserStats = async (contractInstance, userAddress) => {
    try {
      const contract = contractInstance || contract;
      if (!contract || !userAddress) return;

      const betCount = await contract.betCount();
      const activeBets = [];
      const pastBets = [];
      let totalAmountBet = ethers.parseEther("0");
      let totalWinnings = ethers.parseEther("0");
      let totalBetsPlaced = 0;

      for (let i = 0; i < betCount.toString(); i++) {
        try {
          const betDetails = await contract.getBetDetails(i);
          const userBetAmount = await contract.getUserBetAmount(i, userAddress);
          const forAmount = userBetAmount[0];
          const againstAmount = userBetAmount[1];

          if (forAmount.toString() !== "0" || againstAmount.toString() !== "0") {
            totalBetsPlaced++;
            totalAmountBet = totalAmountBet + forAmount + againstAmount;

            const betInfo = {
              id: i,
              title: betDetails[0],
              status: betDetails[5],
              forAmount: ethers.formatEther(forAmount),
              againstAmount: ethers.formatEther(againstAmount),
              totalAmountFor: ethers.formatEther(betDetails[3]),
              totalAmountAgainst: ethers.formatEther(betDetails[4]),
            };

            // Determine if bet is active or past
            if (parseInt(betDetails[5]) <= 1) { // OPEN or CLOSED
              activeBets.push(betInfo);
            } else { // RESOLVED or CANCELLED
              pastBets.push(betInfo);
            }

            // Mock calculation for winnings - in a real app, you'd track this from events
            if (parseInt(betDetails[5]) === 2 && forAmount.toString() !== "0") { // RESOLVED_FOR
              totalWinnings = totalWinnings + (forAmount * 2n); // Simplified winnings calculation
            } else if (parseInt(betDetails[5]) === 3 && againstAmount.toString() !== "0") { // RESOLVED_AGAINST
              totalWinnings = totalWinnings + (againstAmount * 2n); // Simplified winnings calculation
            }
          }
        } catch (error) {
          console.error(`Error loading user stats for bet ${i}:`, error);
        }
      }

      setUserStats({
        totalBetsPlaced,
        totalAmountBet: ethers.formatEther(totalAmountBet),
        totalWinnings: ethers.formatEther(totalWinnings),
        activeBets,
        pastBets,
      });
    } catch (error) {
      console.error("Error loading user stats:", error);
    }
  };

  // Apply filters and sorting to bets
  const applyFilters = useCallback((betsArray, search, status, sort) => {
    let filtered = [...betsArray];

    // Apply search filter
    if (search) {
      filtered = filtered.filter(bet => 
        bet.title.toLowerCase().includes(search.toLowerCase()) ||
        bet.description.toLowerCase().includes(search.toLowerCase())
      );
    }

    // Apply status filter
    if (status !== "all") {
      filtered = filtered.filter(bet => {
        if (status === "open") return parseInt(bet.status) === 0;
        if (status === "closed") return parseInt(bet.status) === 1;
        if (status === "resolved") return parseInt(bet.status) === 2 || parseInt(bet.status) === 3;
        if (status === "cancelled") return parseInt(bet.status) === 4;
        return true;
      });
    }

    // Apply sorting
    if (sort === "newest") {
      filtered.sort((a, b) => b.createdAt - a.createdAt);
    } else if (sort === "oldest") {
      filtered.sort((a, b) => a.createdAt - b.createdAt);
    } else if (sort === "highest-value") {
      filtered.sort((a, b) => {
        const totalA = parseFloat(a.totalAmountFor) + parseFloat(a.totalAmountAgainst);
        const totalB = parseFloat(b.totalAmountFor) + parseFloat(b.totalAmountAgainst);
        return totalB - totalA;
      });
    }

    setFilteredBets(filtered);
  }, []);

  // Update filters when deps change
  useEffect(() => {
    applyFilters(bets, searchTerm, statusFilter, sortBy);
  }, [bets, searchTerm, statusFilter, sortBy, applyFilters]);

  // Select a bet to view details
  const selectBet = async (betId) => {
    try {
      setLoading(true);
      setErrorMessage("");

      const betDetails = await contract.getBetDetails(betId);
      const userBetAmount = await contract.getUserBetAmount(betId, account);
      const bet = await contract.bets(betId); // Get additional bet info

      setSelectedBet({
        id: betId,
        title: betDetails[0],
        description: betDetails[1],
        imageUrl: betDetails[2],
        totalAmountFor: ethers.formatEther(betDetails[3]),
        totalAmountAgainst: ethers.formatEther(betDetails[4]),
        status: betDetails[5],
        creator: bet.creator,
      });

      setUserBets({
        forAmount: ethers.formatEther(userBetAmount[0]),
        againstAmount: ethers.formatEther(userBetAmount[1]),
      });

      setLoading(false);
    } catch (error) {
      console.error("Error selecting bet:", error);
      setErrorMessage("Failed to load bet details: " + error.message);
      setLoading(false);
    }
  };

  // Place a bet
  const placeBet = async () => {
    if (!selectedBet || !betAmount || parseFloat(betAmount) <= 0) {
      setErrorMessage("Please select a bet and enter a valid amount");
      return;
    }

    try {
      setLoading(true);
      setErrorMessage("");

      const amountInWei = ethers.parseEther(betAmount);
      const tx = await contract.placeBet(selectedBet.id, betSide, {
        value: amountInWei,
      });
      
      // Show pending message
      setSuccessMessage("Transaction pending... Please wait");
      
      await tx.wait();

      // Refresh data
      await selectBet(selectedBet.id);
      await loadBets();
      await loadUserStats(contract, account);
      
      setBetAmount("");

      setSuccessMessage(
        `Bet placed successfully! ${betAmount} ETH on ${
          betSide ? "For" : "Against"
        }`
      );
      setLoading(false);
    } catch (error) {
      console.error("Error placing bet:", error);
      setErrorMessage("Failed to place bet: " + error.message);
      setLoading(false);
    }
  };

  // Withdraw winnings
  const withdrawWinnings = async (betId) => {
    const id = betId !== undefined ? betId : (selectedBet ? selectedBet.id : null);
    
    if (id === null) {
      setErrorMessage("Please select a bet first");
      return;
    }

    try {
      setLoading(true);
      setErrorMessage("");

      const tx = await contract.withdrawWinnings(id);
      
      // Show pending message
      setSuccessMessage("Withdrawal transaction pending... Please wait");
      
      await tx.wait();

      // Refresh data
      if (selectedBet && selectedBet.id === id) {
        await selectBet(id);
      }
      await loadBets();
      await loadUserStats(contract, account);
      
      setSuccessMessage("Winnings withdrawn successfully!");
      setLoading(false);
    } catch (error) {
      console.error("Error withdrawing winnings:", error);
      setErrorMessage("Failed to withdraw winnings: " + error.message);
      setLoading(false);
    }
  };

  // Create a new bet
  const createNewBet = async () => {
    if (!newBetTitle || !newBetDescription) {
      setErrorMessage("Please provide a title and description for the bet");
      return;
    }

    try {
      setLoading(true);
      setErrorMessage("");

      const tx = await contract.createBet(
        newBetTitle,
        newBetDescription,
        newBetImageUrl || "" // Optional image URL
      );
      
      // Show pending message
      setSuccessMessage("Creating bet... Please wait");
      
      await tx.wait();

      // Clear form
      setNewBetTitle("");
      setNewBetDescription("");
      setNewBetImageUrl("");

      // Refresh bets
      await loadBets();
      
      setSuccessMessage("Bet created successfully!");
      setLoading(false);
      setActiveTab("bets"); // Switch to bets tab
    } catch (error) {
      console.error("Error creating bet:", error);
      setErrorMessage("Failed to create bet: " + error.message);
      setLoading(false);
    }
  };

  // Close a bet
  const closeBet = async (betId) => {
    try {
      setLoading(true);
      setErrorMessage("");

      const tx = await contract.closeBet(betId);
      
      // Show pending message
      setSuccessMessage("Closing bet... Please wait");
      
      await tx.wait();

      // Refresh data
      if (selectedBet && selectedBet.id === betId) {
        await selectBet(betId);
      }
      await loadBets();
      
      setSuccessMessage("Bet closed successfully!");
      setLoading(false);
    } catch (error) {
      console.error("Error closing bet:", error);
      setErrorMessage("Failed to close bet: " + error.message);
      setLoading(false);
    }
  };

  // Cancel a bet
  const cancelBet = async (betId) => {
    try {
      setLoading(true);
      setErrorMessage("");

      const tx = await contract.cancelBet(betId);
      
      // Show pending message
      setSuccessMessage("Cancelling bet... Please wait");
      
      await tx.wait();

      // Refresh data
      if (selectedBet && selectedBet.id === betId) {
        await selectBet(betId);
      }
      await loadBets();
      
      setSuccessMessage("Bet cancelled successfully!");
      setLoading(false);
    } catch (error) {
      console.error("Error cancelling bet:", error);
      setErrorMessage("Failed to cancel bet: " + error.message);
      setLoading(false);
    }
  };

  // Resolve a bet
  const resolveBet = async (betId, forWon) => {
    try {
      setLoading(true);
      setErrorMessage("");

      const tx = await contract.resolveBet(betId, forWon);
      
      // Show pending message
      setSuccessMessage(`Resolving bet in favor of ${forWon ? "FOR" : "AGAINST"}... Please wait`);
      
      await tx.wait();

      // Refresh data
      if (selectedBet && selectedBet.id === betId) {
        await selectBet(betId);
      }
      await loadBets();
      
      setSuccessMessage(`Bet resolved successfully! ${forWon ? "FOR" : "AGAINST"} side won.`);
      setLoading(false);
    } catch (error) {
      console.error("Error resolving bet:", error);
      setErrorMessage("Failed to resolve bet: " + error.message);
      setLoading(false);
    }
  };

  // Owner withdraw
  const handleOwnerWithdraw = async (amount) => {
    if (!amount || parseFloat(amount) <= 0 || parseFloat(amount) > parseFloat(ownerBalance)) {
      setErrorMessage("Please enter a valid amount to withdraw");
      return;
    }

    try {
      setLoading(true);
      setErrorMessage("");

      const amountInWei = ethers.parseEther(amount);
      const tx = await contract.ownerWithdraw(amountInWei);
      
      // Show pending message
      setSuccessMessage("Withdrawal transaction pending... Please wait");
      
      await tx.wait();

      // Refresh owner balance
      const balance = await contract.ownerBalance();
      setOwnerBalance(ethers.formatEther(balance));

      // Refresh total contract balance
      const totalBalance = await contract.totalContractBalance();
      setTotalContractBalance(ethers.formatEther(totalBalance));
      
      setSuccessMessage("Funds withdrawn successfully!");
      setLoading(false);
    } catch (error) {
      console.error("Error withdrawing funds:", error);
      setErrorMessage("Failed to withdraw funds: " + error.message);
      setLoading(false);
    }
  };

  // Get status text
  const getStatusText = (status) => {
    const statusMap = {
      0: "Open",
      1: "Closed",
      2: "Resolved For",
      3: "Resolved Against",
      4: "Cancelled",
    };
    return statusMap[status] || "Unknown";
  };

  // Get status color
  const getStatusColor = (status) => {
    const statusColorMap = {
      0: "text-green-600 bg-green-100", // Open
      1: "text-yellow-600 bg-yellow-100", // Closed
      2: "text-blue-600 bg-blue-100", // Resolved For
      3: "text-red-600 bg-red-100", // Resolved Against
      4: "text-gray-600 bg-gray-100", // Cancelled
    };
    return statusColorMap[status] || "text-gray-600 bg-gray-100";
  };

  // Helper to determine if user can withdraw
  const canWithdraw = (betId) => {
    if (betId !== undefined) {
      // Find bet in user stats
      const bet = [...userStats.activeBets, ...userStats.pastBets].find(b => b.id === betId);
      if (!bet) return false;
      
      // Status 2 = RESOLVED_FOR, 3 = RESOLVED_AGAINST, 4 = CANCELLED
      const resolvedStatuses = [2, 3, 4];
      
      return (
        resolvedStatuses.includes(parseInt(bet.status)) &&
        (parseFloat(bet.forAmount) > 0 || parseFloat(bet.againstAmount) > 0)
      );
    }
    
    if (!selectedBet) return false;

    // Status 2 = RESOLVED_FOR, 3 = RESOLVED_AGAINST, 4 = CANCELLED
    const resolvedStatuses = [2, 3, 4];

    // Check if bet is resolved and user has placed bets
    return (
      resolvedStatuses.includes(parseInt(selectedBet.status)) &&
      (parseFloat(userBets.forAmount) > 0 || parseFloat(userBets.againstAmount) > 0)
    );
  };

  // Calculate odds and potential winnings
  const calculateOdds = () => {
    if (!selectedBet) return { forOdds: "-", againstOdds: "-", potentialWinnings: 0 };

    const forAmount = parseFloat(selectedBet.totalAmountFor);
    const againstAmount = parseFloat(selectedBet.totalAmountAgainst);
    const totalPool = forAmount + againstAmount;
    
    // Calculate odds (simplified)
    let forOdds = "-";
    let againstOdds = "-";
    
    if (forAmount > 0) {
      forOdds = (totalPool / forAmount).toFixed(2);
    }
    
    if (againstAmount > 0) {
      againstOdds = (totalPool / againstAmount).toFixed(2);
    }
    
    // Calculate potential winnings based on current bet amount and side
    let potentialWinnings = 0;
    const betAmountValue = parseFloat(betAmount) || 0;
    
    if (betAmountValue > 0) {
      const fee = platformFee / 100;
      const prizePot = totalPool * (1 - fee) + betAmountValue;
      
      if (betSide) { // Betting FOR
        const newForAmount = forAmount + betAmountValue;
        potentialWinnings = (betAmountValue / newForAmount) * prizePot;
      } else { // Betting AGAINST
        const newAgainstAmount = againstAmount + betAmountValue;
        potentialWinnings = (betAmountValue / newAgainstAmount) * prizePot;
      }
    }
    
    return {
      forOdds,
      againstOdds,
      potentialWinnings: potentialWinnings.toFixed(4),
    };
  };

  // Calculate the odds dynamically
  const { forOdds, againstOdds, potentialWinnings } = calculateOdds();

  // Toggle dark mode
  const toggleDarkMode = () => {
    setDarkMode(!darkMode);
    // In a real app, you'd apply dark mode classes to body or container
  };

  // Get theme class based on dark mode
  const getThemeClass = (lightClass, darkClass) => {
    return darkMode ? darkClass : lightClass;
  };

  return (
    <div className={`min-h-screen ${getThemeClass("bg-gray-50", "bg-gray-900")} transition-colors duration-200`}>
      <div className={`container mx-auto p-4 max-w-6xl`}>
        {/* Header */}
        <div className={`${getThemeClass("bg-gradient-to-r from-blue-500 to-purple-600", "bg-gradient-to-r from-blue-800 to-purple-900")} p-6 rounded-lg shadow-lg mb-6`}>
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-3xl font-bold text-white mb-2">
                DecentralBet Platform
              </h1>
              <p className="text-white text-opacity-80">
                Place bets on various events and win ETH
              </p>
            </div>
            <button
              onClick={toggleDarkMode}
              className="p-2 rounded-full bg-white bg-opacity-20 text-white hover:bg-opacity-30 transition-colors duration-200"
            >
              {darkMode ? "🌞" : "🌙"}
            </button>
          </div>
        </div>

        {/* Wallet Connection */}
        <div className={`mb-8 ${getThemeClass("", "text-white")}`}>
          {!account ? (
            <button
              onClick={connectWallet}
              disabled={loading}
              className={`${getThemeClass("bg-blue-600 hover:bg-blue-700", "bg-blue-700 hover:bg-blue-800")} text-white font-bold py-3 px-6 rounded-lg transition duration-200 w-full md:w-auto`}
            >
              {loading ? "Connecting..." : "Connect Wallet"}
            </button>
          ) : (
            <div className={`flex flex-col md:flex-row justify-between items-start md:items-center ${getThemeClass("bg-white", "bg-gray-800")} p-4 rounded-lg shadow-md`}>
              <div>
                <span className={`font-semibold ${getThemeClass("text-gray-800", "text-white")}`}>Connected:</span>
                <span className={`ml-2 ${getThemeClass("text-gray-700", "text-gray-300")} text-sm md:text-base`}>
                  {account.substring(0, 6)}...
                  {account.substring(account.length - 4)}
                </span>
                {isOwner && (
                  <span className="ml-2 px-2 py-1 bg-purple-100 text-purple-800 text-xs font-semibold rounded-full">
                    Owner
                  </span>
                )}
              </div>
              <div className="flex gap-2 mt-3 md:mt-0">
                <button
                  onClick={() => loadBets()}
                  disabled={loading}
                  className={`${getThemeClass("bg-gray-200 hover:bg-gray-300 text-gray-800", "bg-gray-700 hover:bg-gray-600 text-white")} font-medium py-1 px-3 rounded text-sm transition duration-200`}
                >
                  Refresh
                </button>
                {account && (
                  <button
                    onClick={() => {
                      setAccount("");
                      setIsOwner(false);
                      setContract(null);
                      setSigner(null);
                      setProvider(null);
                      setSuccessMessage("Wallet disconnected");
                    }}
                    className={`${getThemeClass("bg-red-100 hover:bg-red-200 text-red-800", "bg-red-900 hover:bg-red-800 text-white")} font-medium py-1 px-3 rounded text-sm transition duration-200`}
                  >
                    Disconnect
                  </button>
                )}
              </div>
            </div>
          )}
        </div>

        {/* Alerts */}
        {errorMessage && (
          <div
            className={`${getThemeClass("bg-red-100 border-l-4 border-red-500 text-red-700", "bg-red-900 border-l-4 border-red-500 text-white")} p-4 mb-4 rounded`}
            role="alert"
          >
            <p>{errorMessage}</p>
            <button
              onClick={() => setErrorMessage("")}
              className="ml-auto text-red-500 hover:text-red-700"
            >
              ×
            </button>
          </div>
        )}

        {successMessage && (
          <div
            className={`${getThemeClass("bg-green-100 border-l-4 border-green-500 text-green-700", "bg-green-900 border-l-4 border-green-500 text-white")} p-4 mb-4 rounded flex justify-between items-center`}
            role="alert"
          >
            <p>{successMessage}</p>
            <button
              onClick={() => setSuccessMessage("")}
              className="ml-auto text-green-500 hover:text-green-700"
            >
              ×
            </button>
          </div>
        )}

        {/* Main Content */}
        {account && (
          <>
            {/* Navigation Tabs */}
            <div className="mb-6">
              <div className={`flex border-b ${getThemeClass("border-gray-200", "border-gray-700")}`}>
                <button
                  onClick={() => setActiveTab("bets")}
                  className={`py-2 px-4 font-medium ${
                    activeTab === "bets"
                      ? getThemeClass("text-blue-600 border-b-2 border-blue-600", "text-blue-400 border-b-2 border-blue-400")
                      : getThemeClass("text-gray-500 hover:text-gray-700", "text-gray-400 hover:text-gray-300")
                  }`}
                >
                  All Bets
                </button>
                <button
                  onClick={() => setActiveTab("profile")}
                  className={`py-2 px-4 font-medium ${
                    activeTab === "profile"
                      ? getThemeClass("text-blue-600 border-b-2 border-blue-600", "text-blue-400 border-b-2 border-blue-400")
                      : getThemeClass("text-gray-500 hover:text-gray-700", "text-gray-400 hover:text-gray-300")
                  }`}
                >
                  My Profile
                </button>
                {isOwner && (
                  <button
                    onClick={() => setActiveTab("create")}
                    className={`py-2 px-4 font-medium ${
                      activeTab === "create"
                        ? getThemeClass("text-blue-600 border-b-2 border-blue-600", "text-blue-400 border-b-2 border-blue-400")
                        : getThemeClass("text-gray-500 hover:text-gray-700", "text-gray-400 hover:text-gray-300")
                    }`}
                  >
                    Create Bet
                  </button>
                )}
                {isOwner && (
                  <button
                    onClick={() => setActiveTab("admin")}
                    className={`py-2 px-4 font-medium ${
                      activeTab === "admin"
                        ? getThemeClass("text-blue-600 border-b-2 border-blue-600", "text-blue-400 border-b-2 border-blue-400")
                        : getThemeClass("text-gray-500 hover:text-gray-700", "text-gray-400 hover:text-gray-300")
                    }`}
                  >
                    Admin Panel
                  </button>
                )}
              </div>
            </div>

            {/* All Bets Tab */}
            {activeTab === "bets" && (
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                {/* Bet List with Filters */}
                <div className="col-span-1">
                  <div className={`${getThemeClass("bg-white", "bg-gray-800")} p-4 rounded-lg shadow-md h-full`}>
                    <h2 className={`text-xl font-semibold mb-4 ${getThemeClass("text-gray-800", "text-white")} border-b pb-2`}>
                      Available Bets
                    </h2>

                    {/* Search and Filters */}
                    <div className="mb-4 space-y-3">
                      <input
                        type="text"
                        placeholder="Search bets..."
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        className={`w-full p-2 ${getThemeClass("border border-gray-300 bg-white", "border border-gray-600 bg-gray-700 text-white")} rounded-md`}
                      />
                      
                      <div className="grid grid-cols-2 gap-2">
                        <select
                          value={statusFilter}
                          onChange={(e) => setStatusFilter(e.target.value)}
                          className={`p-2 ${getThemeClass("border border-gray-300 bg-white", "border border-gray-600 bg-gray-700 text-white")} rounded-md`}
                        >
                          <option value="all">All Statuses</option>
                          <option value="open">Open</option>
                          <option value="closed">Closed</option>
                          <option value="resolved">Resolved</option>
                          <option value="cancelled">Cancelled</option>
                        </select>
                        
                        <select
                          value={sortBy}
                          onChange={(e) => setSortBy(e.target.value)}
                          className={`p-2 ${getThemeClass("border border-gray-300 bg-white", "border border-gray-600 bg-gray-700 text-white")} rounded-md`}
                        >
                          <option value="newest">Newest</option>
                          <option value="oldest">Oldest</option>
                          <option value="highest-value">Highest Value</option>
                        </select>
                      </div>
                    </div>

                    {loading && <p className={`${getThemeClass("text-gray-500", "text-gray-400")}`}>Loading bets...</p>}

                    {!loading && filteredBets.length === 0 && (
                      <p className={`${getThemeClass("text-gray-500", "text-gray-400")}`}>No bets match your criteria.</p>
                    )}

                    <div className="space-y-3 max-h-96 overflow-y-auto">
                      {filteredBets.map((bet) => (
                        <div
                          key={bet.id}
                          onClick={() => selectBet(bet.id)}
                          className={`p-3 rounded-md cursor-pointer transition duration-200 ${
                            selectedBet && selectedBet.id === bet.id
                              ? getThemeClass("bg-blue-100 border-blue-500 border", "bg-blue-900 border-blue-500 border")
                              : getThemeClass("hover:bg-gray-100 border border-gray-200", "hover:bg-gray-700 border border-gray-600")
                          }`}
                        >
                          <h3 className={`font-medium ${getThemeClass("text-gray-800", "text-white")}`}>{bet.title}</h3>
                          <div className="flex justify-between text-sm mt-2">
                            <span className={`px-2 py-1 rounded-full ${getStatusColor(bet.status)}`}>
                              {getStatusText(bet.status)}
                            </span>
                            <span className={`${getThemeClass("text-gray-600", "text-gray-400")}`}>#{bet.id}</span>
                          </div>
                          <div className="flex justify-between text-sm mt-2">
                            <span className={`${getThemeClass("text-gray-600", "text-gray-400")}`}>
                              {(parseFloat(bet.totalAmountFor) + parseFloat(bet.totalAmountAgainst)).toFixed(2)} ETH
                            </span>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>

                {/* Bet Details and Actions */}
                <div className="col-span-2">
                  {selectedBet ? (
                    <div className={`${getThemeClass("bg-white", "bg-gray-800")} p-4 rounded-lg shadow-md`}>
                      <h2 className={`text-2xl font-semibold mb-2 ${getThemeClass("text-gray-800", "text-white")}`}>
                        {selectedBet.title}
                      </h2>
                      <p className={`${getThemeClass("text-gray-600", "text-gray-400")} mb-4`}>{selectedBet.description}</p>

                      {selectedBet.imageUrl && (
                        <img
                          src={selectedBet.imageUrl}
                          alt={selectedBet.title}
                          className="w-full h-48 object-cover rounded-md mb-4"
                        />
                      )}

                      <div className="grid grid-cols-2 gap-4 mb-6">
                        <div className={`${getThemeClass("bg-blue-50", "bg-blue-900")} p-3 rounded-md`}>
                          <p className={`text-sm ${getThemeClass("text-blue-600", "text-blue-300")} font-medium`}>
                            Total For
                          </p>
                          <p className={`text-xl font-bold ${getThemeClass("text-blue-700", "text-blue-200")}`}>
                            {selectedBet.totalAmountFor} ETH
                          </p>
                          {parseFloat(userBets.forAmount) > 0 && (
                            <p className="text-sm mt-1">
                              Your bet: {userBets.forAmount} ETH
                            </p>
                          )}
                          <p className={`text-sm ${getThemeClass("text-blue-600", "text-blue-300")} mt-2`}>
                            Odds: {forOdds}x
                          </p>
                        </div>
                        <div className={`${getThemeClass("bg-red-50", "bg-red-900")} p-3 rounded-md`}>
                          <p className={`text-sm ${getThemeClass("text-red-600", "text-red-300")} font-medium`}>
                            Total Against
                          </p>
                          <p className={`text-xl font-bold ${getThemeClass("text-red-700", "text-red-200")}`}>
                            {selectedBet.totalAmountAgainst} ETH
                          </p>
                          {parseFloat(userBets.againstAmount) > 0 && (
                            <p className="text-sm mt-1">
                              Your bet: {userBets.againstAmount} ETH
                            </p>
                          )}
                          <p className={`text-sm ${getThemeClass("text-red-600", "text-red-300")} mt-2`}>
                            Odds: {againstOdds}x
                          </p>
                        </div>
                      </div>

                      <div className="mb-4">
                        <p className={`font-medium mb-2 ${getThemeClass("text-gray-700", "text-gray-300")}`}>
                          Status:{" "}
                          <span className={`font-normal px-2 py-1 rounded-full ${getStatusColor(selectedBet.status)}`}>
                            {getStatusText(selectedBet.status)}
                          </span>
                        </p>
                        <p className={`font-medium mb-2 ${getThemeClass("text-gray-700", "text-gray-300")}`}>
                          Created by:{" "}
                          <span className={`font-normal ${getThemeClass("text-gray-600", "text-gray-400")}`}>
                            {selectedBet.creator === account ? "You" : 
                             `${selectedBet.creator.substring(0, 6)}...${selectedBet.creator.substring(selectedBet.creator.length - 4)}`}
                            {selectedBet.creator.toLowerCase() === contractOwner.toLowerCase() && " (Owner)"}
                          </span>
                        </p>
                        <p className={`font-medium mb-2 ${getThemeClass("text-gray-700", "text-gray-300")}`}>
                          Platform Fee:{" "}
                          <span className={`font-normal ${getThemeClass("text-gray-600", "text-gray-400")}`}>
                            {platformFee}%
                          </span>
                        </p>
                      </div>

                      {/* Owner Actions */}
                      {isOwner && parseInt(selectedBet.status) <= 1 && (
                        <div className={`${getThemeClass("bg-yellow-50", "bg-yellow-900")} p-4 rounded-lg mb-4`}>
                          <h3 className={`text-lg font-medium mb-2 ${getThemeClass("text-yellow-800", "text-yellow-300")}`}>
                            Owner Actions
                          </h3>
                          <div className="flex flex-wrap gap-2">
                            {parseInt(selectedBet.status) === 0 && (
                              <button
                                onClick={() => closeBet(selectedBet.id)}
                                disabled={loading}
                                className={`${getThemeClass("bg-yellow-200 hover:bg-yellow-300 text-yellow-800", "bg-yellow-800 hover:bg-yellow-700 text-yellow-200")} py-1 px-3 rounded-md text-sm font-medium`}
                              >
                                Close Betting
                              </button>
                            )}
                            <button
                              onClick={() => cancelBet(selectedBet.id)}
                              disabled={loading}
                              className={`${getThemeClass("bg-red-200 hover:bg-red-300 text-red-800", "bg-red-800 hover:bg-red-700 text-red-200")} py-1 px-3 rounded-md text-sm font-medium`}
                            >
                              Cancel Bet
                            </button>
                            <button
                              onClick={() => resolveBet(selectedBet.id, true)}
                              disabled={loading}
                              className={`${getThemeClass("bg-blue-200 hover:bg-blue-300 text-blue-800", "bg-blue-800 hover:bg-blue-700 text-blue-200")} py-1 px-3 rounded-md text-sm font-medium`}
                            >
                              Resolve FOR
                            </button>
                            <button
                              onClick={() => resolveBet(selectedBet.id, false)}
                              disabled={loading}
                              className={`${getThemeClass("bg-purple-200 hover:bg-purple-300 text-purple-800", "bg-purple-800 hover:bg-purple-700 text-purple-200")} py-1 px-3 rounded-md text-sm font-medium`}
                            >
                              Resolve AGAINST
                            </button>
                          </div>
                        </div>
                      )}

                      {/* Place Bet Form */}
                      {parseInt(selectedBet.status) === 0 && (
                        <div className={`border-t ${getThemeClass("border-gray-200", "border-gray-700")} pt-4 mt-4`}>
                          <h3 className={`text-lg font-medium mb-4 ${getThemeClass("text-gray-800", "text-white")}`}>
                            Place Your Bet
                          </h3>
                          <div className="flex flex-col md:flex-row gap-4 mb-4">
                            <div className="flex-grow">
                              <label className={`block text-sm font-medium ${getThemeClass("text-gray-700", "text-gray-300")} mb-1`}>
                                Amount (ETH)
                              </label>
                              <input
                                type="number"
                                min="0.001"
                                step="0.001"
                                value={betAmount}
                                onChange={(e) => setBetAmount(e.target.value)}
                                placeholder="0.0"
                                className={`w-full p-2 ${getThemeClass("border border-gray-300", "border border-gray-600 bg-gray-700 text-white")} rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500`}
                              />
                            </div>
                            <div className="w-full md:w-1/3">
                              <label className={`block text-sm font-medium ${getThemeClass("text-gray-700", "text-gray-300")} mb-1`}>
                                Bet on
                              </label>
                              <select
                                value={betSide ? "for" : "against"}
                                onChange={(e) => setBetSide(e.target.value === "for")}
                                className={`w-full p-2 ${getThemeClass("border border-gray-300", "border border-gray-600 bg-gray-700 text-white")} rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500`}
                              >
                                <option value="for">For</option>
                                <option value="against">Against</option>
                              </select>
                            </div>
                          </div>
                          
                          {parseFloat(betAmount) > 0 && (
                            <div className={`mb-4 p-3 ${getThemeClass("bg-green-50 text-green-800", "bg-green-900 text-green-200")} rounded-md`}>
                              <p className="font-medium">Betting Summary:</p>
                              <p className="mt-1">
                                {betAmount} ETH on {betSide ? "FOR" : "AGAINST"}
                              </p>
                              <p className="mt-1">
                                Potential winnings: ~{potentialWinnings} ETH
                              </p>
                              <p className="text-xs mt-2">
                                Note: Actual winnings may vary based on subsequent bets.
                              </p>
                            </div>
                          )}
                          
                          <button
                            onClick={placeBet}
                            disabled={
                              loading || !betAmount || parseFloat(betAmount) <= 0
                            }
                            className={`w-full ${getThemeClass("bg-green-600 hover:bg-green-700", "bg-green-700 hover:bg-green-600")} text-white font-bold py-2 px-4 rounded-md transition duration-200 disabled:bg-gray-400 disabled:cursor-not-allowed`}
                          >
                            {loading ? "Processing..." : "Place Bet"}
                          </button>
                        </div>
                      )}

                      {/* Withdraw Button */}
                      {canWithdraw() && (
                        <div className={`border-t ${getThemeClass("border-gray-200", "border-gray-700")} pt-4 mt-4`}>
                          <h3 className={`text-lg font-medium mb-4 ${getThemeClass("text-gray-800", "text-white")}`}>
                            Withdraw Winnings
                          </h3>
                          <button
                            onClick={() => withdrawWinnings()}
                            disabled={loading}
                            className={`w-full ${getThemeClass("bg-purple-600 hover:bg-purple-700", "bg-purple-700 hover:bg-purple-600")} text-white font-bold py-2 px-4 rounded-md transition duration-200 disabled:bg-gray-400 disabled:cursor-not-allowed`}
                          >
                            {loading ? "Processing..." : "Withdraw Winnings"}
                          </button>
                        </div>
                      )}
                    </div>
                  ) : (
                    <div className={`${getThemeClass("bg-white", "bg-gray-800")} p-6 rounded-lg shadow-md text-center`}>
                      <svg
                        className={`mx-auto h-16 w-16 ${getThemeClass("text-gray-400", "text-gray-500")}`}
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                        />
                      </svg>
                      <h3 className={`mt-2 text-lg font-medium ${getThemeClass("text-gray-900", "text-white")}`}>
                        No bet selected
                      </h3>
                      <p className={`mt-1 ${getThemeClass("text-gray-500", "text-gray-400")}`}>
                        Select a bet from the list to view details and place bets.
                      </p>
                    </div>
                  )}
                </div>
              </div>
            )}
            
            {/* User Profile Tab */}
            {activeTab === "profile" && (
              <div className={`${getThemeClass("bg-white", "bg-gray-800")} p-4 rounded-lg shadow-md`}>
                <h2 className={`text-2xl font-semibold mb-6 ${getThemeClass("text-gray-800", "text-white")}`}>
                  My Profile
                </h2>
                
                {/* User Stats */}
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
                  <div className={`${getThemeClass("bg-blue-50", "bg-blue-900")} p-4 rounded-lg`}>
                    <h3 className={`text-lg font-medium ${getThemeClass("text-blue-700", "text-blue-200")}`}>
                      Total Bets Placed
                    </h3>
                    <p className={`text-2xl font-bold ${getThemeClass("text-blue-800", "text-blue-100")}`}>
                      {userStats.totalBetsPlaced}
                    </p>
                  </div>
                  <div className={`${getThemeClass("bg-green-50", "bg-green-900")} p-4 rounded-lg`}>
                    <h3 className={`text-lg font-medium ${getThemeClass("text-green-700", "text-green-200")}`}>
                      Total Amount Bet
                    </h3>
                    <p className={`text-2xl font-bold ${getThemeClass("text-green-800", "text-green-100")}`}>
                      {userStats.totalAmountBet} ETH
                    </p>
                  </div>
                  <div className={`${getThemeClass("bg-purple-50", "bg-purple-900")} p-4 rounded-lg`}>
                    <h3 className={`text-lg font-medium ${getThemeClass("text-purple-700", "text-purple-200")}`}>
                      Total Winnings
                    </h3>
                    <p className={`text-2xl font-bold ${getThemeClass("text-purple-800", "text-purple-100")}`}>
                      {userStats.totalWinnings} ETH
                    </p>
                  </div>
                </div>
                
                {/* Active Bets */}
                <div className="mb-8">
                  <h3 className={`text-xl font-semibold mb-4 ${getThemeClass("text-gray-800", "text-white")}`}>
                    My Active Bets
                  </h3>
                  
                  {userStats.activeBets.length === 0 ? (
                    <p className={`${getThemeClass("text-gray-500", "text-gray-400")}`}>
                      You don't have any active bets.
                    </p>
                  ) : (
                    <div className="overflow-x-auto">
                      <table className={`min-w-full ${getThemeClass("bg-white", "bg-gray-800")} border ${getThemeClass("border-gray-200", "border-gray-700")}`}>
                        <thead className={`${getThemeClass("bg-gray-50", "bg-gray-700")}`}>
                          <tr>
                            <th className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")} font-medium text-left`}>Bet</th>
                            <th className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")} font-medium text-left`}>Status</th>
                            <th className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")} font-medium text-left`}>For Amount</th>
                            <th className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")} font-medium text-left`}>Against Amount</th>
                            <th className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")} font-medium text-left`}>Actions</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-200">
                          {userStats.activeBets.map((bet) => (
                            <tr key={bet.id} className={`${getThemeClass("hover:bg-gray-50", "hover:bg-gray-700")}`}>
                              <td className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")}`}>
                                <button
                                  onClick={() => selectBet(bet.id)}
                                  className={`${getThemeClass("text-blue-600 hover:text-blue-800", "text-blue-400 hover:text-blue-300")} underline`}
                                >
                                  {bet.title}
                                </button>
                              </td>
                              <td className={`py-2 px-4`}>
                                <span className={`px-2 py-1 rounded-full text-xs ${getStatusColor(bet.status)}`}>
                                  {getStatusText(bet.status)}
                                </span>
                              </td>
                              <td className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")}`}>
                                {parseFloat(bet.forAmount) > 0 ? `${bet.forAmount} ETH` : "-"}
                              </td>
                              <td className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")}`}>
                                {parseFloat(bet.againstAmount) > 0 ? `${bet.againstAmount} ETH` : "-"}
                              </td>
                              <td className={`py-2 px-4`}>
                                {canWithdraw(bet.id) && (
                                  <button
                                    onClick={() => withdrawWinnings(bet.id)}
                                    disabled={loading}
                                    className={`${getThemeClass("bg-purple-600 hover:bg-purple-700", "bg-purple-700 hover:bg-purple-600")} text-white text-xs py-1 px-2 rounded`}
                                  >
                                    Withdraw
                                  </button>
                                )}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}
                </div>
                
                {/* Past Bets */}
                <div>
                  <h3 className={`text-xl font-semibold mb-4 ${getThemeClass("text-gray-800", "text-white")}`}>
                    My Bet History
                  </h3>
                  
                  {userStats.pastBets.length === 0 ? (
                    <p className={`${getThemeClass("text-gray-500", "text-gray-400")}`}>
                      You don't have any past bets.
                    </p>
                  ) : (
                    <div className="overflow-x-auto">
                      <table className={`min-w-full ${getThemeClass("bg-white", "bg-gray-800")} border ${getThemeClass("border-gray-200", "border-gray-700")}`}>
                        <thead className={`${getThemeClass("bg-gray-50", "bg-gray-700")}`}>
                          <tr>
                            <th className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")} font-medium text-left`}>Bet</th>
                            <th className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")} font-medium text-left`}>Result</th>
                            <th className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")} font-medium text-left`}>For Amount</th>
                            <th className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")} font-medium text-left`}>Against Amount</th>
                            <th className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")} font-medium text-left`}>Actions</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-200">
                          {userStats.pastBets.map((bet) => (
                            <tr key={bet.id} className={`${getThemeClass("hover:bg-gray-50", "hover:bg-gray-700")}`}>
                              <td className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")}`}>
                                <button
                                  onClick={() => selectBet(bet.id)}
                                  className={`${getThemeClass("text-blue-600 hover:text-blue-800", "text-blue-400 hover:text-blue-300")} underline`}
                                >
                                  {bet.title}
                                </button>
                              </td>
                              <td className={`py-2 px-4`}>
                                <span className={`px-2 py-1 rounded-full text-xs ${getStatusColor(bet.status)}`}>
                                  {getStatusText(bet.status)}
                                </span>
                              </td>
                              <td className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")}`}>
                                {parseFloat(bet.forAmount) > 0 ? `${bet.forAmount} ETH` : "-"}
                              </td>
                              <td className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")}`}>
                                {parseFloat(bet.againstAmount) > 0 ? `${bet.againstAmount} ETH` : "-"}
                              </td>
                              <td className={`py-2 px-4`}>
                                {canWithdraw(bet.id) && (
                                  <button
                                    onClick={() => withdrawWinnings(bet.id)}
                                    disabled={loading}
                                    className={`${getThemeClass("bg-purple-600 hover:bg-purple-700", "bg-purple-700 hover:bg-purple-600")} text-white text-xs py-1 px-2 rounded`}
                                  >
                                    Withdraw
                                  </button>
                                )}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}
                </div>
              </div>
            )}
            
            {/* Create Bet Tab (Owner Only) */}
            {activeTab === "create" && isOwner && (
              <div className={`${getThemeClass("bg-white", "bg-gray-800")} p-4 rounded-lg shadow-md`}>
                <h2 className={`text-2xl font-semibold mb-6 ${getThemeClass("text-gray-800", "text-white")}`}>
                  Create New Bet
                </h2>
                
                <div className="space-y-4">
                  <div>
                    <label className={`block text-sm font-medium ${getThemeClass("text-gray-700", "text-gray-300")} mb-1`}>
                      Title*
                    </label>
                    <input
                      type="text"
                      value={newBetTitle}
                      onChange={(e) => setNewBetTitle(e.target.value)}
                      placeholder="Enter a descriptive title"
                      className={`w-full p-2 ${getThemeClass("border border-gray-300", "border border-gray-600 bg-gray-700 text-white")} rounded-md`}
                    />
                  </div>
                  
                  <div>
                    <label className={`block text-sm font-medium ${getThemeClass("text-gray-700", "text-gray-300")} mb-1`}>
                      Description*
                    </label>
                    <textarea
                      value={newBetDescription}
                      onChange={(e) => setNewBetDescription(e.target.value)}
                      placeholder="Provide a detailed description of the bet"
                      rows={4}
                      className={`w-full p-2 ${getThemeClass("border border-gray-300", "border border-gray-600 bg-gray-700 text-white")} rounded-md`}
                    />
                  </div>
                  
                  <div>
                    <label className={`block text-sm font-medium ${getThemeClass("text-gray-700", "text-gray-300")} mb-1`}>
                      Image URL (optional)
                    </label>
                    <input
                      type="text"
                      value={newBetImageUrl}
                      onChange={(e) => setNewBetImageUrl(e.target.value)}
                      placeholder="Enter an image URL"
                      className={`w-full p-2 ${getThemeClass("border border-gray-300", "border border-gray-600 bg-gray-700 text-white")} rounded-md`}
                    />
                  </div>
                  
                  <button
                    onClick={createNewBet}
                    disabled={loading || !newBetTitle || !newBetDescription}
                    className={`w-full ${getThemeClass("bg-green-600 hover:bg-green-700", "bg-green-700 hover:bg-green-600")} text-white font-bold py-2 px-4 rounded-md transition duration-200 disabled:bg-gray-400 disabled:cursor-not-allowed mt-4`}
                  >
                    {loading ? "Creating..." : "Create Bet"}
                  </button>
                </div>
              </div>
            )}
            
            {/* Admin Panel (Owner Only) */}
            {activeTab === "admin" && isOwner && (
              <div className={`${getThemeClass("bg-white", "bg-gray-800")} p-4 rounded-lg shadow-md`}>
                <h2 className={`text-2xl font-semibold mb-6 ${getThemeClass("text-gray-800", "text-white")}`}>
                  Admin Panel
                </h2>
                
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  {/* Platform Stats */}
                  <div className={`${getThemeClass("bg-gray-50", "bg-gray-700")} p-4 rounded-lg`}>
                    <h3 className={`text-lg font-medium mb-4 ${getThemeClass("text-gray-800", "text-gray-200")}`}>
                      Platform Statistics
                    </h3>
                    
                    <ul className="space-y-2">
                      <li className="flex justify-between">
                        <span className={`${getThemeClass("text-gray-600", "text-gray-400")}`}>Total Bets:</span>
                        <span className={`font-medium ${getThemeClass("text-gray-800", "text-white")}`}>{bets.length}</span>
                      </li>
                      <li className="flex justify-between">
                        <span className={`${getThemeClass("text-gray-600", "text-gray-400")}`}>Platform Fee:</span>
                        <span className={`font-medium ${getThemeClass("text-gray-800", "text-white")}`}>{platformFee}%</span>
                      </li>
                      <li className="flex justify-between">
                        <span className={`${getThemeClass("text-gray-600", "text-gray-400")}`}>Total Contract Balance:</span>
                        <span className={`font-medium ${getThemeClass("text-gray-800", "text-white")}`}>{totalContractBalance} ETH</span>
                      </li>
                      <li className="flex justify-between">
                        <span className={`${getThemeClass("text-gray-600", "text-gray-400")}`}>Owner Balance:</span>
                        <span className={`font-medium ${getThemeClass("text-gray-800", "text-white")}`}>{ownerBalance} ETH</span>
                      </li>
                    </ul>
                  </div>
                  
                  {/* Owner Withdrawal */}
                  <div className={`${getThemeClass("bg-purple-50", "bg-purple-900")} p-4 rounded-lg`}>
                    <h3 className={`text-lg font-medium mb-4 ${getThemeClass("text-purple-800", "text-purple-200")}`}>
                      Withdraw Owner Fees
                    </h3>
                    
                    <div className="space-y-4">
                      <p className={`${getThemeClass("text-purple-700", "text-purple-300")}`}>
                        Available balance: {ownerBalance} ETH
                      </p>
                      
                      <div>
                        <label className={`block text-sm font-medium ${getThemeClass("text-purple-700", "text-purple-300")} mb-1`}>
                          Amount (ETH)
                        </label>
                        <input
                          type="number"
                          min="0.001"
                          step="0.001"
                          max={ownerBalance}
                          placeholder="Enter amount to withdraw"
                          className={`w-full p-2 ${getThemeClass("border border-purple-300", "border border-purple-700 bg-purple-800 text-white")} rounded-md`}
                          id="withdrawAmount"
                        />
                      </div>
                      
                      <button
                        onClick={() => {
                          const amount = document.getElementById("withdrawAmount").value;
                          handleOwnerWithdraw(amount);
                        }}
                        disabled={loading || parseFloat(ownerBalance) <= 0}
                        className={`w-full ${getThemeClass("bg-purple-600 hover:bg-purple-700", "bg-purple-700 hover:bg-purple-600")} text-white font-bold py-2 px-4 rounded-md transition duration-200 disabled:bg-gray-400 disabled:cursor-not-allowed`}
                      >
                        {loading ? "Processing..." : "Withdraw"}
                      </button>
                    </div>
                  </div>
                  
                  {/* Bet Management */}
                  <div className={`md:col-span-2 ${getThemeClass("bg-blue-50", "bg-blue-900")} p-4 rounded-lg`}>
                    <h3 className={`text-lg font-medium mb-4 ${getThemeClass("text-blue-800", "text-blue-200")}`}>
                      Bet Management
                    </h3>
                    
                    <div className="overflow-x-auto">
                      <table className={`min-w-full ${getThemeClass("bg-white", "bg-gray-800")} border ${getThemeClass("border-gray-200", "border-gray-700")}`}>
                        <thead className={`${getThemeClass("bg-gray-50", "bg-gray-700")}`}>
                          <tr>
                            <th className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")} font-medium text-left`}>ID</th>
                            <th className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")} font-medium text-left`}>Title</th>
                            <th className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")} font-medium text-left`}>Status</th>
                            <th className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")} font-medium text-left`}>Total Value</th>
                            <th className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")} font-medium text-left`}>Actions</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-200">
                          {bets.map((bet) => (
                            <tr key={bet.id} className={`${getThemeClass("hover:bg-gray-50", "hover:bg-gray-700")}`}>
                              <td className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")}`}>
                                {bet.id}
                              </td>
                              <td className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")}`}>
                                <button
                                  onClick={() => selectBet(bet.id)}
                                  className={`${getThemeClass("text-blue-600 hover:text-blue-800", "text-blue-400 hover:text-blue-300")} underline`}
                                >
                                  {bet.title}
                                </button>
                              </td>
                              <td className={`py-2 px-4`}>
                                <span className={`px-2 py-1 rounded-full text-xs ${getStatusColor(bet.status)}`}>
                                  {getStatusText(bet.status)}
                                </span>
                              </td>
                              <td className={`py-2 px-4 ${getThemeClass("text-gray-700", "text-gray-300")}`}>
                                {(parseFloat(bet.totalAmountFor) + parseFloat(bet.totalAmountAgainst)).toFixed(4)} ETH
                              </td>
                              <td className={`py-2 px-4`}>
                                <div className="flex gap-1">
                                  {parseInt(bet.status) === 0 && (
                                    <button
                                      onClick={() => closeBet(bet.id)}
                                      className={`${getThemeClass("bg-yellow-100 hover:bg-yellow-200 text-yellow-800", "bg-yellow-900 hover:bg-yellow-800 text-yellow-200")} text-xs py-1 px-2 rounded`}
                                    >
                                      Close
                                    </button>
                                  )}
                                  {parseInt(bet.status) <= 1 && (
                                    <>
                                      <button
                                        onClick={() => resolveBet(bet.id, true)}
                                        className={`${getThemeClass("bg-blue-100 hover:bg-blue-200 text-blue-800", "bg-blue-900 hover:bg-blue-800 text-blue-200")} text-xs py-1 px-2 rounded`}
                                      >
                                        For
                                      </button>
                                      <button
                                        onClick={() => resolveBet(bet.id, false)}
                                        className={`${getThemeClass("bg-red-100 hover:bg-red-200 text-red-800", "bg-red-900 hover:bg-red-800 text-red-200")} text-xs py-1 px-2 rounded`}
                                      >
                                        Against
                                      </button>
                                      <button
                                        onClick={() => cancelBet(bet.id)}
                                        className={`${getThemeClass("bg-gray-100 hover:bg-gray-200 text-gray-800", "bg-gray-900 hover:bg-gray-800 text-gray-200")} text-xs py-1 px-2 rounded`}
                                      >
                                        Cancel
                                      </button>
                                    </>
                                  )}
                                </div>
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
};

export default EnhancedBettingPlatform;