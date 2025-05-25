// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// Removed import for Ownable, as we are implementing custom ownership

contract MyToken is
    ERC20 // Removed Ownable from inheritance list
{
    address public owner; // State variable to store the contract owner

    // Modifier to restrict functions to only the contract owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    // Constructor initializes ERC20 base contract and sets the contract owner
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        owner = msg.sender; // Set the deployer as the owner
    }

    /**
     * @notice Mint new tokens, only accessible by the owner of the contract.
     * @dev Can be used to mint tokens to a specified address
     * @param to Address to receive minted tokens.
     * @param amount Amount of tokens to mint.
     */
    function mint(address to, uint256 amount) public onlyOwner {
        require(to != address(0), "MyToken: mint to the zero address");
        require(amount > 0, "MyToken: amount must be greater than zero");
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens, only accessible by the owner of the contract.
     * @dev Allows the owner to burn tokens from a specific address.
     * @param account Address from which the tokens will be burned.
     * @param amount Amount of tokens to burn.
     */
    function burn(address account, uint256 amount) public onlyOwner {
        require(account != address(0), "MyToken: burn from the zero address");
        require(amount > 0, "MyToken: amount must be greater than zero");
        _burn(account, amount);
    }
}
