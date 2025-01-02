import React, { useState } from "react";
import { ultimateABI, ultimateAddress } from "./abi/constants"; // Import the Ultimate contract ABI and address
import "./App.css";
const ethers = require("ethers");
const App = () => {
  const [account, setAccount] = useState(null);
  const [message, setMessage] = useState("");
  const [amount, setAmount] = useState("");
  const [targetChain, setTargetChain] = useState("");

  // Connect Wallet
  const connectWallet = async () => {
    if (window.ethereum) {
      try {
        const provider = new ethers.BrowserProvider(window.ethereum);
        const accounts = await provider.send("eth_requestAccounts", []);
        setAccount(accounts[0]);
      } catch (error) {
        console.error("Error connecting wallet:", error);
      }
    } else {
      alert("MetaMask is not installed!");
    }
  };

  // Mint cETH
  const mintCETH = async () => {
    if (!amount || isNaN(amount) || parseFloat(amount) <= 0) {
      alert("Please enter a valid ETH amount to mint cETH!");
      return;
    }

    try {
      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const contract = new ethers.Contract(
        ultimateAddress,
        ultimateABI,
        signer
      );

      const tx = await contract.mintCETH({ value: ethers.parseEther(amount) });
      await tx.wait();
      alert("cETH minted successfully!");
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

      const tx = await contract.enterMarket();
      await tx.wait();
      alert("Market entered successfully!");
    } catch (error) {
      console.error("Error entering market:", error);
    }
  };

  // Borrow DAI
  const borrowDAI = async () => {
    if (!amount || isNaN(amount) || parseFloat(amount) <= 0) {
      alert("Please enter a valid amount to borrow DAI!");
      return;
    }

    try {
      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const contract = new ethers.Contract(
        ultimateAddress,
        ultimateABI,
        signer
      );

      const tx = await contract.borrowDAI(ethers.parseUnits(amount, 18)); // Assuming DAI has 18 decimals
      await tx.wait();
      alert("DAI borrowed successfully!");
    } catch (error) {
      console.error("Error borrowing DAI:", error);
    }
  };

  // Initiate Cross-Chain Operation
  const initiateCrossChainOperation = async () => {
    if (!targetChain || !message) {
      alert(
        "Please enter a target chain and data for the cross-chain operation!"
      );
      return;
    }

    try {
      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const contract = new ethers.Contract(
        ultimateAddress,
        ultimateABI,
        signer
      );

      const data = ethers.utils.hexlify(ethers.utils.toUtf8Bytes(message)); // Convert message to bytes
      const tx = await contract.initiateCrossChainOperation(targetChain, data);
      await tx.wait();
      alert("Cross-chain operation initiated successfully!");
    } catch (error) {
      console.error("Error initiating cross-chain operation:", error);
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
          <input
            type="text"
            placeholder="Amount in ETH"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
          />
          <button onClick={mintCETH}>Mint cETH</button>
        </div>

        <div>
          <h2>Enter Market</h2>
          <button onClick={enterMarket}>Enter Market</button>
        </div>

        <div>
          <h2>Borrow DAI</h2>
          <input
            type="text"
            placeholder="Amount of DAI"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
          />
          <button onClick={borrowDAI}>Borrow DAI</button>
        </div>

        <div>
          <h2>Initiate Cross-Chain Operation</h2>
          <input
            type="text"
            placeholder="Target Chain Address"
            value={targetChain}
            onChange={(e) => setTargetChain(e.target.value)}
          />
          <textarea
            placeholder="Message/Data for Cross-Chain Operation"
            value={message}
            onChange={(e) => setMessage(e.target.value)}
          />
          <button onClick={initiateCrossChainOperation}>
            Initiate Cross-Chain
          </button>
        </div>
      </header>
    </div>
  );
};

export default App;
