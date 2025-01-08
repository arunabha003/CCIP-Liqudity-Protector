pragma solidity ^0.8.19;

interface ICurvePool {
    function coins(uint256 index) external view returns (address);

    function exchange(
        int128 i, // Index of input token
        int128 j, // Index of output token
        uint256 _dx, // Amount of input token
        uint256 _min_dy // Minimum amount of output token
    ) external returns (uint256);
}
