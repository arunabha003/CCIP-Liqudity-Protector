import React, { useState } from "react";
import {
  monitorABI,
  monitorAddress,
  ultimateABI,
  ultimateAddress,
} from "./abi/constants";
import "./App.css";
const ethers = require("ethers");

const App = () => {
  const [account, setAccount] = useState("");
  const [message, setMessage] = useState("");
  const [amount, setAmount] = useState("");
  const [targetChain, setTargetChain] = useState("");
  const [provider, setProvider] = useState(null); // Store the provider
  const [signer, setSigner] = useState(null); // Store the signer

  const connectWallet = async () => {
    if (window.ethereum) {
      try {
        const provider = new ethers.BrowserProvider(window.ethereum);
        setProvider(provider); // Store the provider
        const accounts = await provider.send("eth_requestAccounts", []);
        setAccount(accounts[0]);

        const signer = await provider.getSigner();
        setSigner(signer); // Store the signer
      } catch (error) {
        console.error("Error connecting wallet:", error);
      }
    } else {
      alert("MetaMask is not installed!");
    }
  };

  const mintCETH = async () => {
    if (!signer) {
      // Check if signer exists
      alert("Please connect your wallet first.");
      return;
    }
    try {
      const contract = new ethers.Contract(
        ultimateAddress,
        ultimateABI,
        signer
      );
      console.log("contract", contract);
      const tx = await contract.mintCETH({ value: ethers.parseEther("10") });
      await tx.wait();
      console.log("tx", tx);
      console.log("account", account);
      const tx1 = await contract.getCETHBalance(ultimateAddress);
      console.log(tx1);
    } catch (error) {
      console.error("Error minting cETH:", error);
    }
  };

  // Enter Market
  const enterMarket = async () => {
    try {
      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const contract = new ethers.Contract(
        ultimateAddress,
        ultimateABI,
        signer
      );

      const tx1 = await contract.enterMarket();
      console.log(tx1);
      alert("Market entered successfully!");
    } catch (error) {
      console.error("Error entering market:", error);
    }
  };
  const checkLiquidity = async () => {
    try {
      const contract = new ethers.Contract(
        ultimateAddress,
        ultimateABI,
        signer
      );
      const [liquidity, shortfall] = await contract.calculateLiquidity(
        ultimateAddress
      );
      console.log("Liquidity:", liquidity);
      console.log("Shortfall:", shortfall);
      return { liquidity, shortfall };
    } catch (error) {
      console.error("Error checking liquidity:", error);
    }
  };

  // Borrow DAI
  const borrowDAI = async () => {
    try {
      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const contract = new ethers.Contract(
        ultimateAddress,
        ultimateABI,
        signer
      );

      const tx = await contract.borrowDAI(ethers.parseEther("0.01"));
      // await tx.wait();
      // const tx1 = await contract.getCDAIBalance(ultimateAddress);
      // console.log(tx1);
      console.log(tx);
      const daibalaance = await contract.getDAIBalance(ultimateAddress);
      console.log(daibalaance);
      alert("DAI borrowed successfully!");
    } catch (error) {
      console.error("Error borrowing DAI:", error);
    }
  };

  // Initiate Cross-Chain Operation
  const checkupkeep = async () => {
    try {
      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const contract = new ethers.Contract(monitorAddress, monitorABI, signer);

      // const [upkeepNeeded, performData] = await contract.checkUpkeep("0x");
      // console.log("Upkeep needed:", upkeepNeeded);
      // console.log("Perform data:", performData);
      const result = await contract.checkUpkeep("0x");
      console.log("Raw result from checkUpkeep:", result);
      // Access the tuple properties
      const upkeepNeeded = result[0];
      const performData = result[1];

      console.log("Upkeep needed:", upkeepNeeded);
      console.log("Perform data:", performData);
    } catch (error) {
      console.error("Error initiating cross-chain operation:", error);
    }
  };
  const switchToArbitrum = async () => {
    try {
      await window.ethereum.request({
        method: "wallet_switchEthereumChain",
        params: [{ chainId: "0xA4B1" }], // Chain ID for Arbitrum One
      });
    } catch (switchError) {
      // If the chain is not added to MetaMask, add it
      if (switchError.code === 4902) {
        try {
          await window.ethereum.request({
            method: "wallet_addEthereumChain",
            params: [
              {
                chainId: "0xA4B1",
                chainName: "Arbitrum One",
                rpcUrls: ["https://arb1.arbitrum.io/rpc"],
                blockExplorerUrls: ["https://arbiscan.io"],
                nativeCurrency: {
                  name: "ETH",
                  symbol: "ETH",
                  decimals: 18,
                },
              },
            ],
          });
        } catch (addError) {
          console.error("Error adding Arbitrum One:", addError);
        }
      } else {
        console.error("Error switching to Arbitrum:", switchError);
      }
    }
  };
  return (
    <div className="App">
      <header className="App-header">
        <h1>Ultimate Contract DApp</h1>
        {account ? (
          <p>Connected as: {account}</p>
        ) : (
          <button onClick={connectWallet}>Connect Wallet</button>
        )}
        <div>
          <h2>Mint cETH</h2>

          <button onClick={mintCETH}>Mint cETH</button>
        </div>
        <div>
          <h2>Enter Market</h2>
          <button onClick={enterMarket}>Enter Market</button>
        </div>
        <div>
          <h2>check liquidity</h2>
          <button onClick={checkLiquidity}>CHekc liquidity</button>
        </div>

        <div>
          <h2>Borrow DAI</h2>

          <button onClick={borrowDAI}>Borrow DAI</button>
        </div>
        <div>
          <h2>switchToArbitrum</h2>
          <button onClick={switchToArbitrum}>switchToArbitrum</button>
        </div>
        <div>
          <h2>check upkeep</h2>
          <button onClick={checkupkeep}>check upkeep</button>
        </div>
      </header>
    </div>
  );
};

export default App;
