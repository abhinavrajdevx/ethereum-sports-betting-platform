#!/bin/bash

# Create directory structure
mkdir -p src/components
mkdir -p src/contexts
mkdir -p src/hooks
mkdir -p src/pages
mkdir -p src/types
mkdir -p src/utils

# Create utils files
cat > src/utils/constants.ts << 'EOF'
// src/utils/constants.ts

export const CONTRACT_ADDRESS = "YOUR_CONTRACT_ADDRESS";

// You need to paste the ABI here
export const CONTRACT_ABI = [];

// Bet status mapping
export const BET_STATUS = {
  OPEN: 0,
  CLOSED: 1,
  RESOLVED_FOR: 2,
  RESOLVED_AGAINST: 3,
  CANCELLED: 4
};

export const BET_STATUS_LABELS = {
  0: "Open",
  1: "Closed",
  2: "Resolved (For)",
  3: "Resolved (Against)",
  4: "Cancelled"
};

// Network configuration
export const SUPPORTED_NETWORKS = {
  // Ethereum Mainnet
  1: {
    name: "Ethereum Mainnet",
    currency: "ETH",
    explorer: "https://etherscan.io"
  },
  // Goerli Testnet
  5: {
    name: "Goerli Testnet",
    currency: "ETH",
    explorer: "https://goerli.etherscan.io"
  },
  // Add other networks as needed
};
EOF

cat > src/utils/helpers.ts << 'EOF'
// src/utils/helpers.ts

import { ethers } from "ethers";

export const shortenAddress = (address: string): string => {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
};

export const formatEther = (wei: string | number): string => {
  return ethers.utils.formatEther(wei.toString());
};

export const parseEther = (ether: string): ethers.BigNumber => {
  return ethers.utils.parseEther(ether);
};

export const formatBetAmount = (amount: string | number): string => {
  const formatted = formatEther(amount);
  // Format with 4 decimal places
  return (+formatted).toFixed(4);
};

export const calculateOdds = (forAmount: string, againstAmount: string): { forOdds: string, againstOdds: string } => {
  const forValue = ethers.BigNumber.from(forAmount);
  const againstValue = ethers.BigNumber.from(againstAmount);
  
  if (forValue.isZero() && againstValue.isZero()) {
    return { forOdds: "1.00", againstOdds: "1.00" };
  }
  
  if (forValue.isZero()) {
    return { forOdds: "∞", againstOdds: "1.00" };
  }
  
  if (againstValue.isZero()) {
    return { forOdds: "1.00", againstOdds: "∞" };
  }
  
  const totalAmount = forValue.add(againstValue);
  const forOdds = totalAmount.mul(1000).div(forValue).toNumber() / 1000;
  const againstOdds = totalAmount.mul(1000).div(againstValue).toNumber() / 1000;
  
  return {
    forOdds: forOdds.toFixed(2),
    againstOdds: againstOdds.toFixed(2)
  };
};
EOF

# Create types file
cat > src/types/index.ts << 'EOF'
// src/types/index.ts

export interface Bet {
  id: number;
  title: string;
  description: string;
  imageUrl: string;
  totalAmountFor: string;
  totalAmountAgainst: string;
  status: number;
  creator: string;
}

export interface UserBet {
  forAmount: string;
  againstAmount: string;
}

export interface NetworkConfig {
  name: string;
  currency: string;
  explorer: string;
}

export interface Web3ContextState {
  account: string | null;
  isOwner: boolean;
  chainId: number | null;
  provider: any;
  signer: any;
  contract: any;
  loading: boolean;
  connectWallet: () => Promise<void>;
  disconnectWallet: () => void;
}
EOF

# Create context file
cat > src/contexts/Web3Context.tsx << 'EOF'
// src/contexts/Web3Context.tsx

import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { ethers } from 'ethers';
import { Web3ContextState } from '../types';
import { CONTRACT_ADDRESS, CONTRACT_ABI } from '../utils/constants';

const initialState: Web3ContextState = {
  account: null,
  isOwner: false,
  chainId: null,
  provider: null,
  signer: null,
  contract: null,
  loading: false,
  connectWallet: async () => {},
  disconnectWallet: () => {},
};

const Web3Context = createContext<Web3ContextState>(initialState);

export const useWeb3 = () => useContext(Web3Context);

interface Web3ProviderProps {
  children: ReactNode;
}

export const Web3Provider: React.FC<Web3ProviderProps> = ({ children }) => {
  const [state, setState] = useState<Web3ContextState>(initialState);

  // Initialize provider from window.ethereum
  useEffect(() => {
    const init = async () => {
      if (window.ethereum) {
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        setState(prev => ({ ...prev, provider }));
        
        // Listen for chain changes
        window.ethereum.on('chainChanged', (chainId: string) => {
          window.location.reload();
        });
        
        // Listen for account changes
        window.ethereum.on('accountsChanged', (accounts: string[]) => {
          if (accounts.length === 0) {
            disconnectWallet();
          } else {
            setState(prev => ({ ...prev, account: accounts[0] }));
            checkIfOwner(accounts[0], provider);
          }
        });
        
        // Check if already connected
        try {
          const accounts = await provider.listAccounts();
          if (accounts.length > 0) {
            const signer = provider.getSigner();
            const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
            const network = await provider.getNetwork();
            
            setState(prev => ({
              ...prev,
              account: accounts[0],
              signer,
              contract,
              chainId: network.chainId,
              loading: false
            }));
            
            checkIfOwner(accounts[0], provider);
          }
        } catch (error) {
          console.error("Failed to initialize Web3:", error);
        }
      }
    };
    
    init();
    
    return () => {
      if (window.ethereum) {
        window.ethereum.removeAllListeners('chainChanged');
        window.ethereum.removeAllListeners('accountsChanged');
      }
    };
  }, []);
  
  const checkIfOwner = async (account: string, provider: ethers.providers.Web3Provider) => {
    try {
      const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, provider);
      const owner = await contract.owner();
      setState(prev => ({ ...prev, isOwner: account.toLowerCase() === owner.toLowerCase() }));
    } catch (error) {
      console.error("Failed to check if owner:", error);
    }
  };
  
  const connectWallet = async () => {
    if (!window.ethereum) {
      alert("Please install MetaMask to use this application");
      return;
    }
    
    setState(prev => ({ ...prev, loading: true }));
    
    try {
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      await provider.send("eth_requestAccounts", []);
      
      const signer = provider.getSigner();
      const account = await signer.getAddress();
      const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
      const network = await provider.getNetwork();
      
      setState(prev => ({
        ...prev,
        account,
        signer,
        contract,
        chainId: network.chainId,
        loading: false
      }));
      
      checkIfOwner(account, provider);
    } catch (error) {
      console.error("Failed to connect wallet:", error);
      setState(prev => ({ ...prev, loading: false }));
    }
  };
  
  const disconnectWallet = () => {
    setState({
      ...initialState,
      provider: state.provider,
      connectWallet,
      disconnectWallet
    });
  };
  
  return (
    <Web3Context.Provider 
      value={{ 
        ...state, 
        connectWallet, 
        disconnectWallet 
      }}
    >
      {children}
    </Web3Context.Provider>
  );
};
EOF

# Create hooks
cat > src/hooks/useContract.ts << 'EOF'
// src/hooks/useContract.ts

import { useState } from 'react';
import { ethers } from 'ethers';
import { useWeb3 } from '../contexts/Web3Context';
import { Bet, UserBet } from '../types';

const useContract = () => {
  const { contract, account } = useWeb3();
  const [loading, setLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  // Clear error
  const clearError = () => setError(null);

  // Create a new bet (owner only)
  const createBet = async (title: string, description: string, imageUrl: string) => {
    clearError();
    setLoading(true);
    
    try {
      const tx = await contract.createBet(title, description, imageUrl);
      await tx.wait();
      return true;
    } catch (err: any) {
      console.error('Error creating bet:', err);
      setError(err.message || 'Failed to create bet');
      return false;
    } finally {
      setLoading(false);
    }
  };

  // Place a bet
  const placeBet = async (betId: number, isFor: boolean, amount: string) => {
    clearError();
    setLoading(true);
    
    try {
      const tx = await contract.placeBet(betId, isFor, {
        value: ethers.utils.parseEther(amount)
      });
      await tx.wait();
      return true;
    } catch (err: any) {
      console.error('Error placing bet:', err);
      setError(err.message || 'Failed to place bet');
      return false;
    } finally {
      setLoading(false);
    }
  };

  // Close a bet (owner only)
  const closeBet = async (betId: number) => {
    clearError();
    setLoading(true);
    
    try {
      const tx = await contract.closeBet(betId);
      await tx.wait();
      return true;
    } catch (err: any) {
      console.error('Error closing bet:', err);
      setError(err.message || 'Failed to close bet');
      return false;
    } finally {
      setLoading(false);
    }
  };

  // Resolve a bet (owner only)
  const resolveBet = async (betId: number, forWon: boolean) => {
    clearError();
    setLoading(true);
    
    try {
      const tx = await contract.resolveBet(betId, forWon);
      await tx.wait();
      return true;
    } catch (err: any) {
      console.error('Error resolving bet:', err);
      setError(err.message || 'Failed to resolve bet');
      return false;
    } finally {
      setLoading(false);
    }
  };

  // Cancel a bet (owner only)
  const cancelBet = async (betId: number) => {
    clearError();
    setLoading(true);
    
    try {
      const tx = await contract.cancelBet(betId);
      await tx.wait();
      return true;
    } catch (err: any) {
      console.error('Error canceling bet:', err);
      setError(err.message || 'Failed to cancel bet');
      return false;
    } finally {
      setLoading(false);
    }
  };

  // Withdraw winnings
  const withdrawWinnings = async (betId: number) => {
    clearError();
    setLoading(true);
    
    try {
      const tx = await contract.withdrawWinnings(betId);
      await tx.wait();
      return true;
    } catch (err: any) {
      console.error('Error withdrawing winnings:', err);
      setError(err.message || 'Failed to withdraw winnings');
      return false;
    } finally {
      setLoading(false);
    }
  };

  // Owner withdraw
  const ownerWithdraw = async (amount: string) => {
    clearError();
    setLoading(true);
    
    try {
      const tx = await contract.ownerWithdraw(ethers.utils.parseEther(amount));
      await tx.wait();
      return true;
    } catch (err: any) {
      console.error('Error withdrawing owner balance:', err);
      setError(err.message || 'Failed to withdraw');
      return false;
    } finally {
      setLoading(false);
    }
  };

  // Get all bets
  const getAllBets = async (): Promise<Bet[]> => {
    clearError();
    setLoading(true);
    
    try {
      const betCount = await contract.betCount();
      const bets: Bet[] = [];
      
      for (let i = 0; i < betCount; i++) {
        const bet = await contract.bets(i);
        bets.push({
          id: bet.id.toNumber(),
          title: bet.title,
          description: bet.description,
          imageUrl: bet.imageUrl,
          totalAmountFor: bet.totalAmountFor.toString(),
          totalAmountAgainst: bet.totalAmountAgainst.toString(),
          status: bet.status,
          creator: bet.creator
        });
      }
      
      return bets;
    } catch (err: any) {
      console.error('Error getting all bets:', err);
      setError(err.message || 'Failed to get bets');
      return [];
    } finally {
      setLoading(false);
    }
  };

  // Get bet details
  const getBetDetails = async (betId: number): Promise<Bet | null> => {
    clearError();
    setLoading(true);
    
    try {
      const bet = await contract.bets(betId);
      return {
        id: bet.id.toNumber(),
        title: bet.title,
        description: bet.description,
        imageUrl: bet.imageUrl,
        totalAmountFor: bet.totalAmountFor.toString(),
        totalAmountAgainst: bet.totalAmountAgainst.toString(),
        status: bet.status,
        creator: bet.creator
      };
    } catch (err: any) {
      console.error(`Error getting bet ${betId} details:`, err);
      setError(err.message || 'Failed to get bet details');
      return null;
    } finally {
      setLoading(false);
    }
  };

  // Get user bet amounts
  const getUserBetAmount = async (betId: number, address?: string): Promise<UserBet | null> => {
    clearError();
    setLoading(true);
    
    try {
      const userAddress = address || account;
      
      if (!userAddress) {
        throw new Error("No address specified");
      }
      
      const result = await contract.getUserBetAmount(betId, userAddress);
      return {
        forAmount: result.forAmount.toString(),
        againstAmount: result.againstAmount.toString()
      };
    } catch (err: any) {
      console.error(`Error getting user bet amount for bet ${betId}:`, err);
      setError(err.message || 'Failed to get user bet amount');
      return null;
    } finally {
      setLoading(false);
    }
  };

  // Get contract info
  const getContractInfo = async () => {
    clearError();
    setLoading(true);
    
    try {
      const [owner, platformFee, totalContractBalance, ownerBalance] = await Promise.all([
        contract.owner(),
        contract.platformFee(),
        contract.totalContractBalance(),
        contract.ownerBalance()
      ]);
      
      return {
        owner,
        platformFee: platformFee.toString(),
        totalContractBalance: totalContractBalance.toString(),
        ownerBalance: ownerBalance.toString()
      };
    } catch (err: any) {
      console.error('Error getting contract info:', err);
      setError(err.message || 'Failed to get contract info');
      return null;
    } finally {
      setLoading(false);
    }
  };

  return {
    loading,
    error,
    clearError,
    createBet,
    placeBet,
    closeBet,
    resolveBet,
    cancelBet,
    withdrawWinnings,
    ownerWithdraw,
    getAllBets,
    getBetDetails,
    getUserBetAmount,
    getContractInfo
  };
};

export default useContract;
EOF

# Create components
cat > src/components/LoadingSpinner.tsx << 'EOF'
// src/components/LoadingSpinner.tsx

import React from 'react';

const LoadingSpinner: React.FC = () => {
  return (
    <div className="flex justify-center items-center">
      <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-blue-500"></div>
    </div>
  );
};

export default LoadingSpinner;
EOF

cat > src/components/WalletConnectButton.tsx << 'EOF'
// src/components/WalletConnectButton.tsx

import React from 'react';
import { useWeb3 } from '../contexts/Web3Context';
import { shortenAddress } from '../utils/helpers';
import LoadingSpinner from './LoadingSpinner';

const WalletConnectButton: React.FC = () => {
  const { account, loading, connectWallet, disconnectWallet } = useWeb3();

  return (
    <div>
      {account ? (
        <div className="flex items-center space-x-2">
          <span className="px-4 py-2 bg-gray-100 text-gray-800 rounded-md">
            {shortenAddress(account)}
          </span>
          <button 
            onClick={disconnectWallet}
            className="px-4 py-2 text-sm bg-red-500 hover:bg-red-600 text-white rounded-md transition-colors"
          >
            Disconnect
          </button>
        </div>
      ) : (
        <button 
          onClick={connectWallet}
          disabled={loading}
          className="px-6 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-md transition-colors disabled:bg-blue-400"
        >
          {loading ? <LoadingSpinner /> : "Connect Wallet"}
        </button>
      )}
    </div>
  );
};

export default WalletConnectButton;
EOF

cat > src/components/Header.tsx << 'EOF'
// src/components/Header.tsx

import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import WalletConnectButton from './WalletConnectButton';
import { useWeb3 } from '../contexts/Web3Context';

const Header: React.FC = () => {
  const { account, isOwner } = useWeb3();
  const location = useLocation();

  const navLinks = [
    { name: 'Home', path: '/' },
    { name: 'My Bets', path: '/my-bets', requiresAuth: true },
  ];
  
  if (isOwner) {
    navLinks.push({ name: 'Create Bet', path: '/create-bet' });
    navLinks.push({ name: 'Owner Dashboard', path: '/owner-dashboard' });
  }

  return (
    <header className="bg-gray-900 text-white shadow-md">
      <div className="container mx-auto px-4 py-4">
        <div className="flex justify-between items-center">
          <div className="flex items-center">
            <Link to="/" className="text-xl font-bold mr-8 flex items-center">
              <span className="text-blue-400">Bet</span>Chain
            </Link>
            
            <nav className="hidden md:flex">
              <ul className="flex space-x-8">
                {navLinks.map((link) => {
                  if (link.requiresAuth && !account) return null;
                  
                  return (
                    <li key={link.path}>
                      <Link 
                        to={link.path} 
                        className={`hover:text-blue-400 transition-colors ${
                          location.pathname === link.path ? 'text-blue-400' : ''
                        }`}
                      >
                        {link.name}
                      </Link>
                    </li>
                  );
                })}
              </ul>
            </nav>
          </div>
          
          <WalletConnectButton />
        </div>
      </div>
    </header>
  );
};

export default Header;
EOF

cat > src/components/Layout.tsx << 'EOF'
// src/components/Layout.tsx

import React, { ReactNode } from 'react';
import Header from './Header';

interface LayoutProps {
  children: ReactNode;
}

const Layout: React.FC<LayoutProps> = ({ children }) => {
  return (
    <div className="min-h-screen flex flex-col bg-gray-50">
      <Header />
      <main className="flex-grow container mx-auto px-4 py-8">
        {children}
      </main>
      <footer className="bg-gray-900 text-white py-6">
        <div className="container mx-auto px-4 text-center">
          <p>&copy; {new Date().getFullYear()} BetChain Platform</p>
        </div>
      </footer>
    </div>
  );
};

export default Layout;
EOF

cat > src/components/BetCard.tsx << 'EOF'
// src/components/BetCard.tsx

import React from 'react';
import { Link } from 'react-router-dom';
import { Bet } from '../types';
import { formatBetAmount, calculateOdds } from '../utils/helpers';
import { BET_STATUS_LABELS } from '../utils/constants';

interface BetCardProps {
  bet: Bet;
}

const BetCard: React.FC<BetCardProps> = ({ bet }) => {
  const { id, title, imageUrl, totalAmountFor, totalAmountAgainst, status } = bet;
  const { forOdds, againstOdds } = calculateOdds(totalAmountFor, totalAmountAgainst);
  
  // Calculate total pool
  const totalPool = (
    parseFloat(formatBetAmount(totalAmountFor)) + 
    parseFloat(formatBetAmount(totalAmountAgainst))
  ).toFixed(4);

  return (
    <div className="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow">
      <div className="relative">
        <img 
          src={imageUrl || '/default-bet-image.jpg'} 
          alt={title} 
          className="w-full h-48 object-cover"
          onError={(e) => {
            e.currentTarget.src = '/default-bet-image.jpg';
          }}
        />
        <div className="absolute top-2 right-2 px-2 py-1 text-xs font-semibold rounded bg-gray-800 text-white">
          {BET_STATUS_LABELS[status]}
        </div>
      </div>
      
      <div className="p-4">
        <h3 className="text-lg font-semibold mb-2">{title}</h3>
        
        <div className="grid grid-cols-2 gap-4 mb-4 text-sm">
          <div>
            <p className="text-gray-500">For</p>
            <p className="font-medium">{formatBetAmount(totalAmountFor)} ETH</p>
            <p className="text-blue-600">Odds: {forOdds}x</p>
          </div>
          <div>
            <p className="text-gray-500">Against</p>
            <p className="font-medium">{formatBetAmount(totalAmountAgainst)} ETH</p>
            <p className="text-blue-600">Odds: {againstOdds}x</p>
          </div>
        </div>
        
        <div className="flex justify-between items-center">
          <div className="text-sm">
            <span className="text-gray-500">Total Pool:</span>
            <span className="ml-2 font-semibold">{totalPool} ETH</span>
          </div>
          
          <Link 
            to={`/bet/${id}`} 
            className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm rounded-md transition-colors"
          >
            View Details
          </Link>
        </div>
      </div>
    </div>
  );
};

export default BetCard;
EOF

cat > src/components/BetDetail.tsx << 'EOF'
// src/components/BetDetail.tsx

import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Bet, UserBet } from '../types';
import { formatBetAmount, calculateOdds } from '../utils/helpers';
import { BET_STATUS, BET_STATUS_LABELS } from '../utils/constants';
import { useWeb3 } from '../contexts/Web3Context';
import useContract from '../hooks/useContract';
import PlaceBetForm from './PlaceBetForm';
import LoadingSpinner from './LoadingSpinner';

interface BetDetailProps {
  betId: number;
}

const BetDetail: React.FC<BetDetailProps> = ({ betId }) => {
  const navigate = useNavigate();
  const { account, isOwner } = useWeb3();
  const { loading, error, getBetDetails, getUserBetAmount, closeBet, resolveBet, cancelBet, withdrawWinnings } = useContract();
  
  const [bet, setBet] = useState<Bet | null>(null);
  const [userBet, setUserBet] = useState<UserBet | null>(null);
  const [odds, setOdds] = useState({ forOdds: '0', againstOdds: '0' });
  const [actionLoading, setActionLoading] = useState(false);
  const [showPlaceBetForm, setShowPlaceBetForm] = useState(false);
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  useEffect(() => {
    const fetchData = async () => {
      const betData = await getBetDetails(betId);
      if (betData) {
        setBet(betData);
        setOdds(calculateOdds(betData.totalAmountFor, betData.totalAmountAgainst));
        
        if (account) {
          const userBetData = await getUserBetAmount(betId);
          setUserBet(userBetData);
        }
      }
    };
    
    fetchData();
  }, [betId, account, refreshTrigger]);

  const handleRefresh = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  const handleCloseBet = async () => {
    setActionLoading(true);
    try {
      await closeBet(betId);
      handleRefresh();
    } finally {
      setActionLoading(false);
    }
  };

  const handleResolveBet = async (forWon: boolean) => {
    setActionLoading(true);
    try {
      await resolveBet(betId, forWon);
      handleRefresh();
    } finally {
      setActionLoading(false);
    }
  };

  const handleCancelBet = async () => {
    setActionLoading(true);
    try {
      await cancelBet(betId);
      handleRefresh();
    } finally {
      setActionLoading(false);
    }
  };

  const handleWithdrawWinnings = async () => {
    setActionLoading(true);
    try {
      await withdrawWinnings(betId);
      handleRefresh();
    } finally {
      setActionLoading(false);
    }
  };

  const canWithdraw = () => {
    if (!bet || !userBet) return false;
    
    const hasBet = 
      Number(userBet.forAmount) > 0 || 
      Number(userBet.againstAmount) > 0;
    
    const isResolved = 
      bet.status === BET_STATUS.RESOLVED_FOR || 
      bet.status === BET_STATUS.RESOLVED_AGAINST || 
      bet.status === BET_STATUS.CANCELLED;
    
    return hasBet && isResolved;
  };

  if (loading) {
    return (
      <div className="flex justify-center items-center h-64">
        <LoadingSpinner />
      </div>
    );
  }

  if (error) {
    return (
      <div className="text-center p-8">
        <p className="text-red-600 mb-4">{error}</p>
        <button 
          onClick={() => navigate('/')} 
          className="px-4 py-2 bg-blue-600 text-white rounded-md"
        >
          Go Back Home
        </button>
      </div>
    );
  }

  if (!bet) {
    return (
      <div className="text-center p-8">
        <p className="text-lg mb-4">Bet not found</p>
        <button 
          onClick={() => navigate('/')} 
          className="px-4 py-2 bg-blue-600 text-white rounded-md"
        >
          Go Back Home
        </button>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg shadow-md overflow-hidden">
      <div className="relative h-64">
        <img 
          src={bet.imageUrl || '/default-bet-image.jpg'} 
          alt={bet.title} 
          className="w-full h-full object-cover"
          onError={(e) => {
            e.currentTarget.src = '/default-bet-image.jpg';
          }}
        />
        <div className="absolute top-4 right-4 px-3 py-1 text-sm font-semibold rounded-full bg-gray-800 text-white">
          {BET_STATUS_LABELS[bet.status]}
        </div>
      </div>
      
      <div className="p-6">
        <h1 className="text-2xl font-bold mb-4">{bet.title}</h1>
        <p className="text-gray-700 mb-6">{bet.description}</p>
        
        <div className="grid md:grid-cols-2 gap-6 mb-8">
          <div className="bg-blue-50 p-4 rounded-lg">
            <h3 className="font-semibold text-lg mb-2">For</h3>
            <p className="mb-1">Amount: {formatBetAmount(bet.totalAmountFor)} ETH</p>
            <p className="mb-1">Odds: {odds.forOdds}x</p>
            {userBet && Number(userBet.forAmount) > 0 && (
              <p className="text-green-600 font-medium">Your bet: {formatBetAmount(userBet.forAmount)} ETH</p>
            )}
          </div>
          
          <div className="bg-red-50 p-4 rounded-lg">
            <h3 className="font-semibold text-lg mb-2">Against</h3>
            <p className="mb-1">Amount: {formatBetAmount(bet.totalAmountAgainst)} ETH</p>
            <p className="mb-1">Odds: {odds.againstOdds}x</p>
            {userBet && Number(userBet.againstAmount) > 0 && (
              <p className="text-green-600 font-medium">Your bet: {formatBetAmount(userBet.againstAmount)} ETH</p>
            )}
          </div>
        </div>
        
        {account ? (
          <div className="border-t pt-6">
            {bet.status === BET_STATUS.OPEN && (
              <div className="flex justify-center">
                {showPlaceBetForm ? (
                  <PlaceBetForm 
                    betId={betId} 
                    onSuccess={handleRefresh} 
                    onCancel={() => setShowPlaceBetForm(false)} 
                  />
                ) : (
                  <button
                    onClick={() => setShowPlaceBetForm(true)}
                    className="px-6 py-2 bg-green-600 hover:bg-green-700 text-white rounded-md transition-colors"
                  >
                    Place Bet
                  </button>
                )}
              </div>
            )}
            
            {canWithdraw() && (
              <div className="mt-4 text-center">
                <button
                  onClick={handleWithdrawWinnings}
                  disabled={actionLoading}
                  className="px-6 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-md transition-colors disabled:bg-purple-400"
                >
                  {actionLoading ? <LoadingSpinner /> : "Withdraw Winnings"}
                </button>
              </div>
            )}
            
            {isOwner && (
              <div className="mt-8 border-t pt-6">
                <h3 className="text-lg font-semibold mb-4">Owner Actions</h3>
                <div className="flex flex-wrap gap-4">
                  {bet.status === BET_STATUS.OPEN && (
                    <button
                      onClick={handleCloseBet}
                      disabled={actionLoading}
                      className="px-4 py-2 bg-yellow-600 hover:bg-yellow-700 text-white rounded-md transition-colors disabled:bg-yellow-400"
                    >
                      Close Betting
                    </button>
                  )}
                  
                  {(bet.status === BET_STATUS.OPEN || bet.status === BET_STATUS.CLOSED) && (
                    <>
                      <button
                        onClick={() => handleResolveBet(true)}
                        disabled={actionLoading}
                        className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-md transition-colors disabled:bg-blue-400"
                      >
                        Resolve "For" Won
                      </button>
                      
                      <button
                        onClick={() => handleResolveBet(false)}
                        disabled={actionLoading}
                        className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-md transition-colors disabled:bg-red-400"
                      >
                        Resolve "Against" Won
                      </button>
                      
                      <button
                        onClick={handleCancelBet}
                        disabled={actionLoading}
                        className="px-4 py-2 bg-gray-600 hover:bg-gray-700 text-white rounded-md transition-colors disabled:bg-gray-400"
                      >
                        Cancel Bet
                      </button>
                    </>
                  )}
                </div>
              </div>
            )}
          </div>
        ) : (
          <div className="text-center py-4 bg-gray-50 rounded-lg">
            <p className="mb-2">Connect your wallet to place bets</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default BetDetail;
EOF

cat > src/components/PlaceBetForm.tsx << 'EOF'
// src/components/PlaceBetForm.tsx

import React, { useState } from 'react';
import useContract from '../hooks/useContract';
import LoadingSpinner from './LoadingSpinner';

interface PlaceBetFormProps {
  betId: number;
  onSuccess: () => void;
  onCancel: () => void;
}

const PlaceBetForm: React.FC<PlaceBetFormProps> = ({ betId, onSuccess, onCancel }) => {
  const { placeBet, loading, error } = useContract();
  const [amount, setAmount] = useState<string>('');
  const [isFor, setIsFor] = useState<boolean>(true);
  const [formError, setFormError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);

    if (!amount || parseFloat(amount) <= 0) {
      setFormError('Please enter a valid amount');
      return;
    }

    try {
      const result = await placeBet(betId, isFor, amount);
      if (result) {
        onSuccess();
      }
    } catch (err: any) {
      setFormError(err.message || 'Failed to place bet');
    }
  };

  return (
    <div className="w-full max-w-md bg-white rounded-lg p-6 shadow-md">
      <h3 className="text-lg font-semibold mb-4">Place Your Bet</h3>
      
      <form onSubmit={handleSubmit}>
        <div className="mb-4">
          <label className="block text-gray-700 text-sm font-medium mb-2">
            Bet Position
          </label>
          <div className="flex space-x-4">
            <button
              type="button"
              onClick={() => setIsFor(true)}
              className={`flex-1 py-2 px-4 rounded-md focus:outline-none transition-colors ${
                isFor 
                  ? 'bg-blue-500 text-white' 
                  : 'bg-gray-200 text-gray-800 hover:bg-gray-300'
              }`}
            >
              For
            </button>
            <button
              type="button"
              onClick={() => setIsFor(false)}
              className={`flex-1 py-2 px-4 rounded-md focus:outline-none transition-colors ${
                !isFor 
                  ? 'bg-blue-500 text-white' 
                  : 'bg-gray-200 text-gray-800 hover:bg-gray-300'
              }`}
            >
              Against
            </button>
          </div>
        </div>
        
        <div className="mb-6">
          <label htmlFor="amount" className="block text-gray-700 text-sm font-medium mb-2">
            Amount (ETH)
          </label>
          <div className="mt-1 relative rounded-md shadow-sm">
            <input
              type="number"
              id="amount"
              placeholder="0.0"
              step="0.01"
              min="0"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="block w-full pr-12 p-2 sm:text-sm border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"
            />
            <div className="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
              <span className="text-gray-500 sm:text-sm">ETH</span>
            </div>
          </div>
        </div>
        
        {(error || formError) && (
          <div className="mb-4 p-2 bg-red-100 text-red-700 rounded-md">
            {error || formError}
          </div>
        )}
        
        <div className="flex space-x-4">
          <button
            type="button"
            onClick={onCancel}
            className="flex-1 py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            disabled={loading}
          >
            Cancel
          </button>
          <button
            type="submit"
            className="flex-1 py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:bg-blue-400"
            disabled={loading}
          >
            {loading ? <LoadingSpinner /> : 'Confirm Bet'}
          </button>
        </div>
      </form>
    </div>
  );
};

export default PlaceBetForm;
EOF

cat > src/components/CreateBetForm.tsx << 'EOF'
// src/components/CreateBetForm.tsx

import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import useContract from '../hooks/useContract';
import LoadingSpinner from './LoadingSpinner';

const CreateBetForm: React.FC = () => {
  const navigate = useNavigate();
  const { createBet, loading, error } = useContract();
  
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [imageUrl, setImageUrl] = useState('');
  const [formErrors, setFormErrors] = useState<Record<string, string>>({});

  const validateForm = (): boolean => {
    const errors: Record<string, string> = {};
    
    if (!title.trim()) {
      errors.title = 'Title is required';
    }
    
    if (!description.trim()) {
      errors.description = 'Description is required';
    }
    
    setFormErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!validateForm()) {
      return;
    }
    
    try {
      const success = await createBet(title, description, imageUrl);
      
      if (success) {
        navigate('/');
      }
    } catch (err) {
      console.error('Error creating bet:', err);
    }
  };

  return (
    <div className="bg-white rounded-lg shadow-md p-6">
      <h2 className="text-2xl font-bold mb-6">Create New Bet</h2>
      
      <form onSubmit={handleSubmit}>
        <div className="mb-4">
          <label htmlFor="title" className="block text-gray-700 font-medium mb-2">
            Title *
          </label>
          <input
            type="text"
            id="title"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className={`w-full p-2 border rounded-md focus:ring-blue-500 focus:border-blue-500 ${
              formErrors.title ? 'border-red-500' : 'border-gray-300'
            }`}
            placeholder="e.g., Will BTC reach $100k by end of year?"
          />
          {formErrors.title && (
            <p className="mt-1 text-red-500 text-sm">{formErrors.title}</p>
          )}
        </div>
        
        <div className="mb-4">
          <label htmlFor="description" className="block text-gray-700 font-medium mb-2">
            Description *
          </label>
          <textarea
            id="description"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            rows={4}
            className={`w-full p-2 border rounded-md focus:ring-blue-500 focus:border-blue-500 ${
              formErrors.description ? 'border-red-500' : 'border-gray-300'
            }`}
            placeholder="Provide clear details about the bet and conditions..."
          />
          {formErrors.description && (
            <p className="mt-1 text-red-500 text-sm">{formErrors.description}</p>
          )}
        </div>
        
        <div className="mb-6">
          <label htmlFor="imageUrl" className="block text-gray-700 font-medium mb-2">
            Image URL
          </label>
          <input
            type="text"
            id="imageUrl"
            value={imageUrl}
            onChange={(e) => setImageUrl(e.target.value)}
            className="w-full p-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"
            placeholder="https://example.com/image.jpg"
          />
          <p className="mt-1 text-gray-500 text-sm">
            Leave empty to use default image
          </p>
        </div>
        
        {error && (
          <div className="mb-4 p-3 bg-red-100 text-red-700 rounded-md">
            {error}
          </div>
        )}
        
        <div className="flex justify-end">
          <button
            type="button"
            onClick={() => navigate('/')}
            className="px-4 py-2 mr-4 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={loading}
            className="px-6 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:bg-blue-400"
          >
            {loading ? <LoadingSpinner /> : 'Create Bet'}
          </button>
        </div>
      </form>
    </div>
  );
};

export default CreateBetForm;
EOF

# Create pages
cat > src/pages/HomePage.tsx << 'EOF'
// src/pages/HomePage.tsx

import React, { useState, useEffect } from 'react';
import BetCard from '../components/BetCard';
import LoadingSpinner from '../components/LoadingSpinner';
import useContract from '../hooks/useContract';
import { Bet } from '../types';
import { BET_STATUS } from '../utils/constants';

const HomePage: React.FC = () => {
  const { getAllBets, loading, error } = useContract();
  const [bets, setBets] = useState<Bet[]>([]);
  const [filter, setFilter] = useState<number | null>(null);

  useEffect(() => {
    const fetchBets = async () => {
      const allBets = await getAllBets();
      setBets(allBets);
    };
    
    fetchBets();
  }, []);

  const filteredBets = filter === null
    ? bets
    : bets.filter(bet => bet.status === filter);

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-3xl font-bold mb-2">Available Bets</h1>
        <p className="text-gray-600">Browse and place your bets on various events</p>
      </div>
      
      <div className="mb-6">
        <div className="flex flex-wrap gap-2">
          <button
            onClick={() => setFilter(null)}
            className={`px-4 py-2 rounded-md text-sm ${
              filter === null
                ? 'bg-blue-600 text-white'
                : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
            }`}
          >
            All Bets
          </button>
          <button
            onClick={() => setFilter(BET_STATUS.OPEN)}
            className={`px-4 py-2 rounded-md text-sm ${
              filter === BET_STATUS.OPEN
                ? 'bg-blue-600 text-white'
                : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
            }`}
          >
            Open
          </button>
          <button
            onClick={() => setFilter(BET_STATUS.CLOSED)}
            className={`px-4 py-2 rounded-md text-sm ${
              filter === BET_STATUS.CLOSED
                ? 'bg-blue-600 text-white'
                : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
            }`}
          >
            Closed
          </button>
          <button
            onClick={() => setFilter(BET_STATUS.RESOLVED_FOR)}
            className={`px-4 py-2 rounded-md text-sm ${
              filter === BET_STATUS.RESOLVED_FOR
                ? 'bg-blue-600 text-white'
                : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
            }`}
          >
            Resolved (For)
          </button>
          <button
            onClick={() => setFilter(BET_STATUS.RESOLVED_AGAINST)}
            className={`px-4 py-2 rounded-md text-sm ${
              filter === BET_STATUS.RESOLVED_AGAINST
                ? 'bg-blue-600 text-white'
                : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
            }`}
          >
            Resolved (Against)
          </button>
          <button
            onClick={() => setFilter(BET_STATUS.CANCELLED)}
            className={`px-4 py-2 rounded-md text-sm ${
              filter === BET_STATUS.CANCELLED
                ? 'bg-blue-600 text-white'
                : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
            }`}
          >
            Cancelled
          </button>
        </div>
      </div>
      
      {loading ? (
        <div className="flex justify-center items-center py-12">
          <LoadingSpinner />
        </div>
      ) : error ? (
        <div className="p-4 bg-red-100 text-red-700 rounded-md">
          {error}
        </div>
      ) : filteredBets.length === 0 ? (
        <div className="text-center py-12">
          <p className="text-lg text-gray-600">No bets found</p>
          {filter !== null && (
            <button
              onClick={() => setFilter(null)}
              className="mt-2 text-blue-600 hover:text-blue-800"
            >
              View all bets
            </button>
          )}
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredBets.map((bet) => (
            <BetCard key={bet.id} bet={bet} />
          ))}
        </div>
      )}
    </div>
  );
};

export default HomePage;
EOF

cat > src/pages/BetDetailsPage.tsx << 'EOF'
// src/pages/BetDetailsPage.tsx

import React from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import BetDetail from '../components/BetDetail';

const BetDetailsPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  
  if (!id || isNaN(Number(id))) {
    return (
      <div className="text-center p-8">
        <p className="text-lg mb-4">Invalid bet ID</p>
        <button 
          onClick={() => navigate('/')} 
          className="px-4 py-2 bg-blue-600 text-white rounded-md"
        >
          Go Back Home
        </button>
      </div>
    );
  }
  
  return (
    <div>
      <div className="mb-4">
        <button 
          onClick={() => navigate('/')}
          className="flex items-center text-blue-600 hover:text-blue-800"
        >
          <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-1" viewBox="0 0 20 20" fill="currentColor">
            <path fillRule="evenodd" d="M9.707 14.707a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 1.414L7.414 9H15a1 1 0 110 2H7.414l2.293 2.293a1 1 0 010 1.414z" clipRule="evenodd" />
          </svg>
          Back to All Bets
        </button>
      </div>
      
      <BetDetail betId={Number(id)} />
    </div>
  );
};

export default BetDetailsPage;
EOF

cat > src/pages/CreateBetPage.tsx << 'EOF'
// src/pages/CreateBetPage.tsx

import React, { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import CreateBetForm from '../components/CreateBetForm';
import { useWeb3 } from '../contexts/Web3Context';

const CreateBetPage: React.FC = () => {
  const { account, isOwner } = useWeb3();
  const navigate = useNavigate();
  
  useEffect(() => {
    if (account && !isOwner) {
      navigate('/');
    }
  }, [account, isOwner, navigate]);
  
  if (!account) {
    return (
      <div className="text-center py-12">
        <p className="text-lg mb-4">Please connect your wallet to continue</p>
      </div>
    );
  }
  
  if (!isOwner) {
    return (
      <div className="text-center py-12">
        <p className="text-lg mb-4">Only the owner can create bets</p>
        <button 
          onClick={() => navigate('/')} 
          className="px-4 py-2 bg-blue-600 text-white rounded-md"
        >
          Go Back Home
        </button>
      </div>
    );
  }
  
  return (
    <div>
      <div className="mb-4">
        <button 
          onClick={() => navigate('/')}
          className="flex items-center text-blue-600 hover:text-blue-800"
        >
          <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-1" viewBox="0 0 20 20" fill="currentColor">
            <path fillRule="evenodd" d="M9.707 14.707a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 1.414L7.414 9H15a1 1 0 110 2H7.414l2.293 2.293a1 1 0 010 1.414z" clipRule="evenodd" />
          </svg>
          Back to All Bets
        </button>
      </div>
      
      <CreateBetForm />
    </div>
  );
};

export default CreateBetPage;
EOF

cat > src/pages/MyBetsPage.tsx << 'EOF'
// src/pages/MyBetsPage.tsx

import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import BetCard from '../components/BetCard';
import LoadingSpinner from '../components/LoadingSpinner';
import { useWeb3 } from '../contexts/Web3Context';
import useContract from '../hooks/useContract';
import { Bet, UserBet } from '../types';

const MyBetsPage: React.FC = () => {
  const navigate = useNavigate();
  const { account } = useWeb3();
  const { getAllBets, getUserBetAmount, loading, error } = useContract();
  
  const [myBets, setMyBets] = useState<Bet[]>([]);
  const [loadingBets, setLoadingBets] = useState<boolean>(true);
  
  useEffect(() => {
    if (!account) {
      return;
    }
    
    const fetchMyBets = async () => {
      setLoadingBets(true);
      
      try {
        const allBets = await getAllBets();
        const betsWithUserParticipation = [];
        
        for (const bet of allBets) {
          const userBet = await getUserBetAmount(bet.id);
          
          if (userBet && (Number(userBet.forAmount) > 0 || Number(userBet.againstAmount) > 0)) {
            betsWithUserParticipation.push(bet);
          }
        }
        
        setMyBets(betsWithUserParticipation);
      } catch (err) {
        console.error('Error fetching my bets:', err);
      } finally {
        setLoadingBets(false);
      }
    };
    
    fetchMyBets();
  }, [account]);
  
  if (!account) {
    return (
      <div className="text-center py-12">
        <p className="text-lg mb-4">Please connect your wallet to view your bets</p>
      </div>
    );
  }
  
  return (
    <div>
      <div className="mb-8">
        <h1 className="text-3xl font-bold mb-2">My Bets</h1>
        <p className="text-gray-600">View all the bets you've participated in</p>
      </div>
      
      {loading || loadingBets ? (
        <div className="flex justify-center items-center py-12">
          <LoadingSpinner />
        </div>
      ) : error ? (
        <div className="p-4 bg-red-100 text-red-700 rounded-md">
          {error}
        </div>
      ) : myBets.length === 0 ? (
        <div className="text-center py-12">
          <p className="text-lg text-gray-600 mb-4">You haven't placed any bets yet</p>
          <button 
            onClick={() => navigate('/')} 
            className="px-6 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
          >
            Browse Bets
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {myBets.map((bet) => (
            <BetCard key={bet.id} bet={bet} />
          ))}
        </div>
      )}
    </div>
  );
};

export default MyBetsPage;
EOF

cat > src/pages/OwnerDashboardPage.tsx << 'EOF'
// src/pages/OwnerDashboardPage.tsx

import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import LoadingSpinner from '../components/LoadingSpinner';
import { useWeb3 } from '../contexts/Web3Context';
import useContract from '../hooks/useContract';
import { formatEther, parseEther } from '../utils/helpers';

const OwnerDashboardPage: React.FC = () => {
  const navigate = useNavigate();
  const { account, isOwner } = useWeb3();
  const { getContractInfo, ownerWithdraw, loading, error } = useContract();
  
  const [contractInfo, setContractInfo] = useState<{
    owner: string;
    platformFee: string;
    totalContractBalance: string;
    ownerBalance: string;
  } | null>(null);
  
  const [withdrawAmount, setWithdrawAmount] = useState<string>('');
  const [withdrawLoading, setWithdrawLoading] = useState<boolean>(false);
  const [withdrawError, setWithdrawError] = useState<string | null>(null);
  
  useEffect(() => {
    if (!account || !isOwner) {
      return;
    }
    
    const fetchContractInfo = async () => {
      const info = await getContractInfo();
      setContractInfo(info);
    };
    
    fetchContractInfo();
    
    // Refresh every 30 seconds
    const intervalId = setInterval(fetchContractInfo, 30000);
    return () => clearInterval(intervalId);
  }, [account, isOwner]);
  
  const handleWithdraw = async () => {
    if (!withdrawAmount || parseFloat(withdrawAmount) <= 0) {
      setWithdrawError('Please enter a valid amount');
      return;
    }
    
    if (contractInfo && parseFloat(withdrawAmount) > parseFloat(formatEther(contractInfo.ownerBalance))) {
      setWithdrawError('Insufficient owner balance');
      return;
    }
    
    setWithdrawLoading(true);
    setWithdrawError(null);
    
    try {
      await ownerWithdraw(withdrawAmount);
      
      // Refresh contract info
      const info = await getContractInfo();
      setContractInfo(info);
      
      // Reset withdraw amount
      setWithdrawAmount('');
    } catch (err: any) {
      setWithdrawError(err.message || 'Failed to withdraw');
    } finally {
      setWithdrawLoading(false);
    }
  };
  
  useEffect(() => {
    if (account && !isOwner) {
      navigate('/');
    }
  }, [account, isOwner, navigate]);
  
  if (!account) {
    return (
      <div className="text-center py-12">
        <p className="text-lg mb-4">Please connect your wallet to continue</p>
      </div>
    );
  }
  
  if (!isOwner) {
    return (
      <div className="text-center py-12">
        <p className="text-lg mb-4">Only the owner can access this page</p>
        <button 
          onClick={() => navigate('/')} 
          className="px-4 py-2 bg-blue-600 text-white rounded-md"
        >
          Go Back Home
        </button>
      </div>
    );
  }
  
  return (
    <div>
      <div className="mb-8">
        <h1 className="text-3xl font-bold mb-2">Owner Dashboard</h1>
        <p className="text-gray-600">Manage your betting platform</p>
      </div>
      
      {loading ? (
        <div className="flex justify-center items-center py-12">
          <LoadingSpinner />
        </div>
      ) : error ? (
        <div className="p-4 bg-red-100 text-red-700 rounded-md mb-6">
          {error}
        </div>
      ) : contractInfo ? (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-10">
          <div className="bg-white rounded-lg shadow-md p-6">
            <h3 className="text-lg font-semibold mb-4">Platform Fee</h3>
            <p className="text-3xl font-bold">{contractInfo.platformFee}%</p>
          </div>
          
          <div className="bg-white rounded-lg shadow-md p-6">
            <h3 className="text-lg font-semibold mb-4">Total Contract Balance</h3>
            <p className="text-3xl font-bold">{formatEther(contractInfo.totalContractBalance)} ETH</p>
          </div>
          
          <div className="bg-white rounded-lg shadow-md p-6">
            <h3 className="text-lg font-semibold mb-4">Owner Balance</h3>
            <p className="text-3xl font-bold">{formatEther(contractInfo.ownerBalance)} ETH</p>
          </div>
        </div>
      ) : null}
      
      <div className="bg-white rounded-lg shadow-md p-6">
        <h2 className="text-xl font-bold mb-4">Withdraw Owner Balance</h2>
        
        <div className="flex flex-col md:flex-row items-stretch md:items-end gap-4">
          <div className="flex-grow">
            <label htmlFor="withdrawAmount" className="block text-gray-700 text-sm font-medium mb-2">
              Amount (ETH)
            </label>
            <div className="mt-1 relative rounded-md shadow-sm">
              <input
                type="number"
                id="withdrawAmount"
                placeholder="0.0"
                step="0.01"
                min="0"
                value={withdrawAmount}
                onChange={(e) => setWithdrawAmount(e.target.value)}
                className="block w-full pr-12 p-2 sm:text-sm border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"
              />
              <div className="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
                <span className="text-gray-500 sm:text-sm">ETH</span>
              </div>
            </div>
            {contractInfo && (
              <p className="mt-1 text-sm text-gray-500">
                Available: {formatEther(contractInfo.ownerBalance)} ETH
              </p>
            )}
          </div>
          
          <button
            onClick={handleWithdraw}
            disabled={withdrawLoading || !withdrawAmount || parseFloat(withdrawAmount) <= 0}
            className="px-6 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-md transition-colors disabled:bg-blue-400"
          >
            {withdrawLoading ? <LoadingSpinner /> : 'Withdraw'}
          </button>
        </div>
        
        {withdrawError && (
          <div className="mt-4 p-3 bg-red-100 text-red-700 rounded-md">
            {withdrawError}
          </div>
        )}
      </div>
      
      <div className="mt-8">
        <button 
          onClick={() => navigate('/create-bet')} 
          className="inline-flex items-center px-6 py-3 bg-green-600 hover:bg-green-700 text-white rounded-md transition-colors"
        >
          <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-2" viewBox="0 0 20 20" fill="currentColor">
            <path fillRule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clipRule="evenodd" />
          </svg>
          Create New Bet
        </button>
      </div>
    </div>
  );
};

export default OwnerDashboardPage;
EOF

# Create App files
cat > src/App.tsx << 'EOF'
// src/App.tsx

import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { Web3Provider } from './contexts/Web3Context';
import Layout from './components/Layout';
import HomePage from './pages/HomePage';
import BetDetailsPage from './pages/BetDetailsPage';
import CreateBetPage from './pages/CreateBetPage';
import MyBetsPage from './pages/MyBetsPage';
import OwnerDashboardPage from './pages/OwnerDashboardPage';

const App: React.FC = () => {
  return (
    <Web3Provider>
      <Router>
        <Layout>
          <Routes>
            <Route path="/" element={<HomePage />} />
            <Route path="/bet/:id" element={<BetDetailsPage />} />
            <Route path="/create-bet" element={<CreateBetPage />} />
            <Route path="/my-bets" element={<MyBetsPage />} />
            <Route path="/owner-dashboard" element={<OwnerDashboardPage />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </Layout>
      </Router>
    </Web3Provider>
  );
};

export default App;
EOF

cat > src/main.tsx << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.tsx'
import './index.css'

// Add ethers to the window type
declare global {
  interface Window {
    ethereum: any;
  }
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF

cat > src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  background-color: #f9fafb;
}

code {
  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New',
    monospace;
}
EOF

# Create tailwind config
cat > tailwind.config.js << 'EOF'
/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
EOF

cat > README.md << 'EOF'
# Betting Platform Frontend

This project is a React.js frontend for the BettingPlatform smart contract.

## Features

- Browse all available bets
- Connect your Ethereum wallet
- Place bets on various events
- View your betting history
- Withdraw winnings from resolved bets
- Owner dashboard for platform management
- Create new bets (owner only)
- Resolve or cancel bets (owner only)

## Setup Instructions

1. Install dependencies:

```bash
npm install ethers@5.7.2 react-router-dom