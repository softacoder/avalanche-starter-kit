// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25; // Updated compiler version to satisfy the linter requirement

// import "@teleporter/registry/TeleporterRegistry.sol";
// Update the import path below to the correct location of TeleporterRegistry.sol or use the npm package if installed.
// Example using npm package (uncomment if installed via npm):
// import "@teleporter/registry/TeleporterRegistry.sol" as TeleporterRegistryModule;
import "../../../teleporter/TeleporterRegistry.sol" as TeleporterRegistryModule;
// import "@teleporter/registry/TeleporterRegistry.sol" as TeleporterRegistryModule;
// import "@teleporter/upgrades/TeleporterRegistry.sol"; // This line is commented out, so it's not affecting compilation.
import "../../../teleporter/ITeleporterReceiver.sol" as TeleporterReceiverModule;
import "./MyERC20Token.sol"; // Assuming MyERC20Token.sol exists in the same directory
import "./BridgeActions.sol"; // Assuming BridgeActions.sol exists in the same directory

contract TokenMinterReceiverOnBulletin is TeleporterReceiverModule.ITeleporterReceiver {
    // Immutable TeleporterRegistry address. Ensure this address is correct for your network.
    TeleporterRegistryModule.TeleporterRegistry public immutable teleporterRegistry =
        TeleporterRegistryModule.TeleporterRegistry(0x827364Da64e8f8466c23520d81731e94c8DDe510);
    address public tokenAddress; // Stores the address of the deployed ERC20 token

    /// @notice Receives and processes Teleporter messages.
    /// @param _sourceBlockchainID The ID of the blockchain from which the message originated.
    /// @param _originSenderAddress The address of the sender on the origin blockchain.
    /// @param message The raw message bytes containing the action type and parameters.
    function receiveTeleporterMessage(bytes32 sourceBlockchainID, address originSenderAddress, bytes calldata message)
        external
    {
        // The variables sourceBlockchainID and originSenderAddress are intentionally unused to avoid linter warnings.
        sourceBlockchainID; // Mute the linter warning for unused variable
        originSenderAddress; // Mute the linter warning for unused variable

        // Only a Teleporter Messenger registered in the registry can deliver a message.
        // This line will revert if msg.sender is not a registered Teleporter Messenger.
        teleporterRegistry.getVersionFromAddress(msg.sender);

        // Decode the action type and its associated parameters from the message.
        (BridgeAction actionType, bytes memory paramsData) = abi.decode(message, (BridgeAction, bytes));

        // Route the message based on the decoded action type.
        if (actionType == BridgeAction.createToken) {
            // If the action is to create a token, decode the token name and symbol.
            (string memory name, string memory symbol) = abi.decode(paramsData, (string, string));
            // Deploy a new MyERC20Token contract and store its address.
            tokenAddress = address(new myToken(name, symbol));
        } else if (actionType == BridgeAction.mintToken) {
            // If the action is to mint tokens, decode the recipient address and amount.
            (address recipient, uint256 amount) = abi.decode(paramsData, (address, uint256));
            // Call the mint function on the deployed token contract.
            // Ensure tokenAddress is set (i.e., createToken was called previously).
            myToken(tokenAddress).mint(recipient, amount);
        } else {
            // Revert if an unknown or invalid action type is received.
            revert("Receiver: invalid action");
        }
    }
}
