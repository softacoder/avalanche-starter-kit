// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// Import OpenZeppelin ERC721 and ERC721Enumerable
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

// Chainlink imports
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

contract VouchRegistry is ERC721, ERC721Enumerable, ChainlinkClient {
    using Chainlink for Chainlink.Request;

    // Struct to track vouching data
    struct Vouch {
        address voucher;
        bool revoked;
        uint256 timestamp;
    }

    // Chainlink oracle settings
    address private _oracle;
    bytes32 private _jobId;
    uint256 private _fee;

    // Maps Chainlink request IDs to vouchee addresses
    mapping(bytes32 => address) private _requestIdToVouchee;

    // Telegram verification status for each user
    mapping(address => bool) public telegramVerified;

    // Vouch data
    mapping(address => mapping(address => bool)) private _hasVouched;
    mapping(address => Vouch[]) private _vouchHistory;
    mapping(address => uint256) public validVouchCount;
    mapping(address => uint256) public requiredVouches;
    address[] private _voucheeList;
    mapping(address => bool) private _isVoucheeTracked;
    mapping(address => bool) public hasSoulVouch;

    // Events
    event Vouched(address indexed voucher, address indexed vouchee, uint256 current, uint256 required);
    event VouchRevoked(address indexed voucher, address indexed vouchee);
    event TelegramVerificationRequested(address indexed vouchee, bytes32 requestId);
    event TelegramVerified(address indexed vouchee, bool verified);

    // Constructor
    constructor(address oracle_, string memory jobId, uint256 fee__, address linkToken)
        ERC721("SoulVouch", "SVOUCH")
    {
        _setChainlinkToken(linkToken); // Set the LINK token address for Chainlink
        _oracle = oracle_;
        _jobId = _stringToBytes32(jobId); // Convert jobId string to bytes32
        _fee = fee__; // Set the Chainlink fee (e.g., 0.1 * 10**18 for LINK)
    }

    // --- External/Public View/Pure Functions ---
    // These functions only read the contract's state and do not modify it. They are callable externally.

    // Returns a person's current trust score
    function getTrustScore(address person) external view returns (uint256) {
        return validVouchCount[person];
    }

    // Returns all vouches for a person
    function getVouchHistory(address person) external view returns (Vouch[] memory) {
        return _vouchHistory[person];
    }

    // Total number of people who have been vouched for
    function totalVoucheesCount() external view returns (uint256) {
        return _voucheeList.length;
    }

    // Required to resolve multiple inheritance for supportsInterface
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // --- External/Public Functions (Non-View/Pure) ---
    // These functions modify the contract's state and are callable externally.

    // Vouch for someone, increasing their trust score
    function vouch(address vouchee) external {
        require(vouchee != msg.sender, "Cannot vouch for yourself");
        require(!_hasVouched[msg.sender][vouchee], "Already vouched");

        // Track vouchee if not already tracked
        if (!_isVoucheeTracked[vouchee]) {
            _voucheeList.push(vouchee);
            _isVoucheeTracked[vouchee] = true;
        }

        // Set required vouches if it's the first time
        if (requiredVouches[vouchee] == 0) {
            requiredVouches[vouchee] = _getNextRequiredVouches();
        }

        _hasVouched[msg.sender][vouchee] = true;
        _vouchHistory[vouchee].push(Vouch(msg.sender, false, block.timestamp));
        validVouchCount[vouchee]++;

        emit Vouched(msg.sender, vouchee, validVouchCount[vouchee], requiredVouches[vouchee]);

        // Request Telegram verification status on-chain via Chainlink oracle
        requestTelegramVerification(vouchee);

        // Mint NFT if threshold reached or Telegram verified
        if (
            (validVouchCount[vouchee] >= requiredVouches[vouchee] || telegramVerified[vouchee])
                && !hasSoulVouch[vouchee]
        ) {
            _mintSoulVouch(vouchee);
        }
    }

    // Revoke a vouch
    function revokeVouch(address vouchee) external {
        require(_hasVouched[msg.sender][vouchee], "No vouch to revoke");

        Vouch[] storage vouches = _vouchHistory[vouchee];
        bool found = false;

        for (uint256 i = 0; i < vouches.length; i++) {
            if (vouches[i].voucher == msg.sender && !vouches[i].revoked) {
                vouches[i].revoked = true;
                found = true;
                break;
            }
        }

        require(found, "Vouch already revoked");

        _hasVouched[msg.sender][vouchee] = false;

        if (validVouchCount[vouchee] > 0) {
            validVouchCount[vouchee]--;
        }

        emit VouchRevoked(msg.sender, vouchee);
    }

    // Request Telegram verification via Chainlink oracle
    function requestTelegramVerification(address vouchee) public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(_jobId, address(this), this.fulfillTelegramVerification.selector);
        req.add("user", _toAsciiString(vouchee)); // Add user parameter (address as string)
        requestId = sendChainlinkRequestTo(_oracle, req, _fee);
        _requestIdToVouchee[requestId] = vouchee;
        emit TelegramVerificationRequested(vouchee, requestId);
    }

    // Callback function called by Chainlink oracle with verification result
    function fulfillTelegramVerification(bytes32 requestId, bool verified)
        public
        recordChainlinkFulfillment(requestId)
    {
        address vouchee = _requestIdToVouchee[requestId];
        telegramVerified[vouchee] = verified;
        emit TelegramVerified(vouchee, verified);

        // Mint SoulVouch immediately if verified and not minted
        if (verified && !hasSoulVouch[vouchee]) {
            _mintSoulVouch(vouchee);
        }
    }

    // --- Internal/Private Functions (Non-View/Pure) ---
    // These functions modify the contract's state and are only callable internally.

    // Mints a non-transferable SoulVouch NFT
    function _mintSoulVouch(address to) internal {
        require(!hasSoulVouch[to], "Already has soul vouch");
        uint256 tokenId = uint256(uint160(to)); // Deterministic tokenId
        _mint(to, tokenId);
        hasSoulVouch[to] = true;
    }

    // Make SoulVouch non-transferable (soulbound) by overriding _beforeTokenTransfer
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        // Allow minting and burning only, disallow transfers
        if (from != address(0) && to != address(0)) {
            revert("SoulVouch: non-transferable");
        }
    }

    // --- Internal/Private Functions (View/Pure) ---
    // These functions only read the contract's state or perform calculations without state access.
    // They are only callable internally.

    // Defines dynamic logic to increase required vouches
    function _getNextRequiredVouches() internal view returns (uint256) {
        uint256 total = _voucheeList.length;
        return total < 2 ? 2 : total + 1;
    }

    // Helper to convert address to string for Chainlink API parameter
    function _toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(x)) / (2 ** (8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = _char(hi);
            s[2 * i + 1] = _char(lo);
        }
        return string(s);
    }

    function _char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    // Convert string to bytes32 for jobId
    function _stringToBytes32(string memory source) internal pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }
}
