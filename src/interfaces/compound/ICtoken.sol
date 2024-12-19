// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.0;

interface ICToken {
    function repayBorrowBehalf(
        address borrower,
        uint256 repayAmount
    ) external returns (uint256);

    function repayBorrowBehalf(address borrower) external payable;
    function borrowBalanceStored(address account) external view returns (uint);
    function mint() external payable;
    function redeem(uint256 redeemTokens) external returns (uint256);
    function exchangeRateCurrent() external returns (uint256);
    function transfer(address dst, uint256 amount) external returns (bool);
    // function mint(uint256 mintAmount) external returns (uint256);
    function borrow(uint256 borrowAmount) external returns (uint256);
    function repayBorrow(uint256 repayAmount) external returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function borrowBalanceCurrent(address account) external returns (uint256);
    function borrowRatePerBlock() external view returns (uint256);
}
