// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

interface ICETH {
    function mint() external payable;

    function borrow(uint borrowAmount) external returns (uint);

    function transfer(address dst, uint256 amount) external returns (bool);

    function liquidateBorrow(
        address borrower,
        uint repayAmount,
        address collateral
    ) external returns (uint);

    function balanceOf(address account) external view returns (uint);
}

interface ICDAI {
    function borrow(uint borrowAmount) external returns (uint);

    function liquidateBorrow(
        address borrower,
        uint repayAmount,
        address collateral
    ) external returns (uint);

    function balanceOf(address account) external view returns (uint);
}

interface IComptroller {
    function enterMarkets(
        address[] calldata cTokens
    ) external returns (uint[] memory);

    function getAccountLiquidity(
        address account
    ) external view returns (uint, uint, uint);
}

contract Ultimate {
    ICETH public cETH;
    ICDAI public cDAI;
    IComptroller public comptroller;

    event CETHMinted(address indexed user, uint amount);
    event MarketEntered(address indexed user, address market);
    event DAIBorrowed(address indexed user, uint amount);
    event CrossChainOperationInitiated(address indexed targetChain, bytes data);

    constructor(address _cETH, address _cDAI, address _comptroller) {
        cETH = ICETH(_cETH);
        cDAI = ICDAI(_cDAI);
        comptroller = IComptroller(_comptroller);
    }

    // Step 1: Minting cETH
    //the minting of ceth stores the ceth in the smart contract address remember to transfer it to the user
    function mintCETH() external payable {
        require(msg.value > 0, "No ETH sent");
        cETH.mint{value: msg.value}();
        // cETH.transfer(msg.sender, cETH.balanceOf(address(this)));
        emit CETHMinted(msg.sender, cETH.balanceOf(address(this)));
    }

    // Step 2: Entering Market
    function enterMarket() external {
        address[] memory markets = new address[](1);
        markets[0] = address(cETH);
        uint[] memory results = comptroller.enterMarkets(markets);
        require(results[0] == 0, "Entering market failed");
        emit MarketEntered(msg.sender, address(cETH));
    }

    // Step 3: Liquidity Calculation
    function calculateLiquidity(
        address user
    ) public view returns (uint liquidity, uint shortfall) {
        (uint error, uint userLiquidity, uint userShortfall) = comptroller
            .getAccountLiquidity(user);
        require(error == 0, "Error fetching liquidity");
        return (userLiquidity, userShortfall);
    }

    // Step 4: Borrowing DAI
    function borrowDAI(uint amount) external {
        (, uint shortfall) = calculateLiquidity(msg.sender);
        require(shortfall == 0, "Insufficient liquidity");
        require(cDAI.borrow(amount) == 0, "Borrowing DAI failed");

        emit DAIBorrowed(msg.sender, amount);
    }

    // Step 5: Get Balances
    function getCETHBalance(address user) external view returns (uint) {
        return cETH.balanceOf(user);
    }

    function getCDAIBalance(address user) external view returns (uint) {
        return cDAI.balanceOf(user);
    }

    function getDAIBalance(address user) external view returns (uint) {
        return
            IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F).balanceOf(user);
    }

    function getETHBalance(address user) external view returns (uint) {
        return user.balance;
    }
}
