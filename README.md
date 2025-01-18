

# CCIP Liquidation Protector

The **CCIP Liquidation Protector** is a cross-chain solution designed to protect users from liquidation on lending protocols (e.g., Compound V2 on Ethereum) by pulling liquidity from another chain (e.g., Arbitrum via Aave V3). The system uses **Chainlink CCIP** (Cross-Chain Interoperability Protocol) to request and receive tokens across different networks securely.

## Table of Contents

- [CCIP Liquidation Protector](#ccip-liquidation-protector)
  - [Table of Contents](#table-of-contents)
  - [1. Overview](#1-overview)
  - [2. Core Components](#2-core-components)
    - [**LPSC (Liquidation Protection Smart Contract)**](#lpsc-liquidation-protection-smart-contract)
    - [**LPSCVault**](#lpscvault)
    - [**LPSCRegistry**](#lpscregistry)
    - [**MonitorCompoundV2**](#monitorcompoundv2)
  - [3. Architecture Diagram](#3-architecture-diagram)
  - [4. Getting Started](#4-getting-started)
    - [4.1 Prerequisites](#41-prerequisites)
    - [4.2 Installation](#42-installation)
  - [5. Running Tests](#5-running-tests)
    - [5.1 Setting Up RPC URLs](#51-setting-up-rpc-urls)
    - [5.2 Running Local Fork Tests](#52-running-local-fork-tests)
    - [5.3 Debugging and Logs](#53-debugging-and-logs)
    - [5.4 Example Commands](#54-example-commands)
  - [6. Usage and Examples](#6-usage-and-examples)
  - [7. Security and Considerations](#7-security-and-considerations)
  - [8. License](#8-license)
    - [**Happy Building!**](#happy-building)

---

## 1. Overview

**CCIP Liquidation Protector** provides an automated way to bring funds from a “liquidity chain” (Arbitrum with Aave V3) to a “debt chain” (Ethereum Mainnet with Compound V2) when a user’s position is at risk of liquidation.

- **On Ethereum (Debt Chain):**  
  A `MonitorCompoundV2` contract checks if the user’s Compound position is underwater. If it is, it sends a **CCIP request** to Arbitrum.

- **On Arbitrum (Liquidity Chain):**  
  An `LPSC` (liquidation protection smart contract) receives the request, ensures there are enough funds (pulling from an Aave vault if necessary), and sends the required amount back to Ethereum via **CCIP**.

- **Result:**  
  The user’s position on Compound can be topped up, preventing liquidation.

---

## 2. Core Components

### **LPSC (Liquidation Protection Smart Contract)**

- **Inherits**: 
  - `CCIPReceiver` to handle incoming CCIP messages from Ethereum.  
  - `LPSCVault` for vault interactions (withdraw from Aave).
- **Responsibilities**:  
  1. Receives cross-chain message from the debt chain (MonitorCompoundV2).  
  2. Checks the requested token and amount.  
  3. If needed, calls `withdrawFromVault` (from `LPSCVault`) to make sure there’s enough liquidity.  
  4. Uses **Chainlink CCIP** again to reply back with tokens to the original sender (on Ethereum).

### **LPSCVault**

- **Purpose**:  
  Manages liquidity on Arbitrum, specifically integrates with Aave V3.  
- **Key Functions**:
  - `withdrawFromVault(token, amount)`: Withdraws from Aave if `LPSC` has insufficient funds to meet a cross-chain request.

### **LPSCRegistry**

- **Purpose**:  
  Holds mappings of token addresses across different chains (e.g., the address of “ETHx” on Ethereum vs. Arbitrum).  
- **Usage**:  
  Allows `LPSC` to map an incoming token address from Ethereum to its corresponding address on Arbitrum, ensuring correct bridging.

### **MonitorCompoundV2**

- **Inherits**:  
  - `AutomationCompatibleInterface` (Chainlink Keepers) to automatically check user positions.  
  - `CCIPReceiver` to handle the cross-chain reply from `LPSC`.  
- **Responsibilities**:  
  1. Monitors user’s Compound V2 position.  
  2. If there’s a shortfall, it sends a CCIP request to `LPSC` on Arbitrum.  
  3. On receiving the reply (tokens to repay debt), it can repay the user’s position on Compound.  

---

## 3. Architecture Diagram

```
 Ethereum (Debt Chain)                        Arbitrum (Liquidity Chain)
 --------------------                         --------------------------
      [User + CompoundV2]                           [Aave V3]
              |  (Check shortfall)                         ^
              v                                            |
   [MonitorCompoundV2]  -- CCIP request -->   [LPSC + LPSCVault]
              ^                                            |
              |            <-- CCIP reply --                |
              ----------------------------------------------
```

1. `MonitorCompoundV2` detects shortfall and sends CCIP request.  
2. `LPSC` receives request, withdraws from `LPSCVault` if needed, sends back tokens.  
3. `MonitorCompoundV2` uses returned tokens to repay or top up the user’s Compound position.

---

## 4. Getting Started

### 4.1 Prerequisites

- **Node.js** (v14 or higher recommended)
- **Foundry (forge)** or **Hardhat** (this example uses Foundry)
- **Git** for version control
- Accounts or private keys to fork & interact with mainnet/Arbitrum

### 4.2 Installation

1. **Clone the Repository**  
   ```bash
   git clone https://github.com/smartcontractkit/ccip-liquidation-protector.git
   cd ccip-liquidation-protector
   ```
2. **Install Foundry** (if not already installed)  
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```
3. **Set Up Environment**  
   Make sure you have environment variables or direct URLs set for your mainnet and Arbitrum RPC endpoints (e.g., Alchemy or Infura).

4. **Install Dependencies**  
   Inside the project folder:
   ```bash
   forge install
   ```

---

Here’s the updated **test instructions** section of the README, rewritten to guide users to set up their `.env` file for RPC URLs and run tests using Foundry. This section now explicitly references the `.env` setup step and incorporates the provided `.env.example`.

---

## 5. Running Tests

The codebase includes a suite of **Foundry** tests that simulate both on-chain logic and cross-chain flows using Chainlink's **CCIPLocalSimulatorFork** for local cross-chain testing.

### 5.1 Setting Up RPC URLs

Before running the tests, ensure you set up the required RPC URLs for Ethereum Mainnet and Arbitrum in a `.env` file. Use the provided `.env.example` as a template:

1. Copy the `.env.example` file to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Update the placeholders in the `.env` file with your **Alchemy** or **Infura** API keys:
   ```dotenv
   ARBITRUM_RPC_URL=https://arb-mainnet.g.alchemy.com/v2/YOUR_API_KEY
   ETH_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
   ```

   Replace `YOUR_API_KEY` with your actual API keys for **Alchemy** or **Infura**.

3. Export the `.env` variables so Foundry can access them:
   ```bash
   source .env
   ```

---

### 5.2 Running Local Fork Tests

With the `.env` variables set up(see .evv.example for referance), you can now run the test suite. These tests use the RPC URLs to create Ethereum and Arbitrum forks locally.

 

1. **Run all tests:**
   ```bash
   forge test 
   ```

2. **Example Tests:**
   - **`FullFlowTest.sol`**: Simulates the entire cross-chain liquidation protection flow.
   - **`MonitorTest.sol`**: Verifies the `MonitorCompoundV2` logic (checking shortfall, sending CCIP requests).
   - **`CompoundBasicTest.sol`**: Focuses on the core Compound mechanics like mint, borrow, and repay.
   - **`LPSCTestWithSimulator.sol`**: Tests the CCIP interaction between Ethereum and Arbitrum using a local simulator.

---

### 5.3 Debugging and Logs

For more detailed logs during test execution, increase the verbosity with `-vvvv`:
```bash
forge test --fork-url $ETH_RPC_URL --fork-url $ARBITRUM_RPC_URL -vvvv
```

This outputs additional details like transaction traces and state changes, making it easier to debug complex flows.

---

### 5.4 Example Commands

- **Run only a specific test file**:
  ```bash
  forge test -vv --match-path test/FullFlowTest.sol
  ```

- **Run a specific test function**:
  ```bash
  forge test  -vv --match-test testMonitorLiquidationFlow
  ```

---



## 6. Usage and Examples

1. **Deploying LPSC** on Arbitrum:
   - You can deploy it directly with your router address (Chainlink CCIP) and a reference to an Aave pool to manage liquidity.

2. **Deploying MonitorCompoundV2** on Ethereum:
   - Point it to the Compound Comptroller and the relevant cToken addresses.  
   - Provide your user’s address so it knows who to protect.

3. **Configuring LPSCRegistry**:
   - Map any tokens you expect to handle cross-chain. For example, if your token is “ETHx” on mainnet and “ETHx” on Arbitrum, store that in the registry so LPSC can do lookups.

4. **Performing a Mock Liquidation Check**:
   - Use the `MonitorCompoundV2.checkUpkeep()` function to see if your user is in shortfall. If yes, it calls `performUpkeep()` to send a CCIP message.

---

## 7. Security and Considerations

1. **Access Control**  
   - `onlyRouterOrOwner` in `LPSC` ensures only the Chainlink CCIP router or the contract owner can trigger certain functions.  
   - Ensure you consider additional role-based restrictions if needed (e.g., pausing functionality).

2. **Token Approvals**  
   - `MonitorCompoundV2` and `LPSC` both approve the CCIP router to spend tokens. This is essential for bridging but should be carefully managed.  
   - Confirm that no arbitrary addresses get infinite approvals.

3. **Reentrancy and Upgrades**  
   - Consider adding reentrancy guards if your project expands.  
   - For production, you might use upgradeable contracts; ensure that your cross-chain logic is upgrade-safe.

4. **Testing on Real Networks**  
   - The local simulator is great for rapid iteration. However, always run tests on testnets (Goerli, Arbitrum Goerli, etc.) if possible, to ensure your CCIP flows and addresses are configured correctly.

---

## 8. License

This project is licensed under the [MIT License](LICENSE). Feel free to use, modify, and distribute this code. If you make improvements, consider submitting a pull request to help the community!

---

### **Happy Building!**

If you have any questions or issues, please open an issue in the [GitHub repository](https://github.com/smartcontractkit/ccip-liquidation-protector) or reach out to the Chainlink community on [Discord](https://discord.gg/chainlink).  