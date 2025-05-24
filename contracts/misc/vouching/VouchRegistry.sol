// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// Using OpenZeppelin ERC721 & ERC721Enumerable
import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract VouchRegistry is ERC721, ERC721Enumerable {
    struct Vouch {
        address voucher;
        uint256 timestamp;
        bool revoked;
    }

    // Mapping to track if a voucher has vouched for a vouchee
    mapping(address => mapping(address => bool)) private hasVouched;

    // Vouch history for each vouchee
    mapping(address => Vouch[]) private vouchHistory;

    // Valid (non-revoked) vouch counts
    mapping(address => uint256) public validVouchCount;

    // Required number of vouches for each person
    mapping(address => uint256) public requiredVouches;

    // Track unique vouchees and whether they're tracked
    address[] private voucheeList;
    mapping(address => bool) private isVoucheeTracked;

    // Tracks whether someone has received their SoulVouch NFT
    mapping(address => bool) public hasSoulVouch;

    // Events
    event Vouched(address indexed voucher, address indexed vouchee, uint256 current, uint256 required);
    event VouchRevoked(address indexed voucher, address indexed vouchee);

    constructor() ERC721("SoulVouch", "SVOUCH") {}

    /// @notice Vouch for someone, increasing their trust score
    function vouch(address vouchee) external {
        require(vouchee != msg.sender, "Cannot vouch for yourself");
        require(!hasVouched[msg.sender][vouchee], "Already vouched");

        // Track vouchee
        if (!isVoucheeTracked[vouchee]) {
            voucheeList.push(vouchee);
            isVoucheeTracked[vouchee] = true;
        }

        // Set required vouches if first time
        if (requiredVouches[vouchee] == 0) {
            requiredVouches[vouchee] = getNextRequiredVouches();
        }

        hasVouched[msg.sender][vouchee] = true;
        vouchHistory[vouchee].push(Vouch(msg.sender, block.timestamp, false));
        validVouchCount[vouchee]++;

        emit Vouched(msg.sender, vouchee, validVouchCount[vouchee], requiredVouches[vouchee]);

        if (validVouchCount[vouchee] >= requiredVouches[vouchee] && !hasSoulVouch[vouchee]) {
            mintSoulVouch(vouchee);
        }
    }

    /// @notice Revoke a vouch
    function revokeVouch(address vouchee) external {
        require(hasVouched[msg.sender][vouchee], "No vouch to revoke");

        Vouch[] storage vouches = vouchHistory[vouchee];
        bool found = false;

        for (uint256 i = 0; i < vouches.length; i++) {
            if (vouches[i].voucher == msg.sender && !vouches[i].revoked) {
                vouches[i].revoked = true;
                found = true;
                break;
            }
        }

        require(found, "Vouch already revoked");

        hasVouched[msg.sender][vouchee] = false;

        if (validVouchCount[vouchee] > 0) {
            validVouchCount[vouchee]--;
        }

        emit VouchRevoked(msg.sender, vouchee);
    }

    /// @notice Returns a person's current trust score
    function getTrustScore(address person) external view returns (uint256) {
        return validVouchCount[person];
    }

    /// @notice Returns all vouches for a person
    function getVouchHistory(address person) external view returns (Vouch[] memory) {
        return vouchHistory[person];
    }

    /// @dev Defines dynamic logic to increase required vouches
    function getNextRequiredVouches() internal view returns (uint256) {
        uint256 total = voucheeList.length;
        return total < 2 ? 2 : total + 1;
    }

    /// @notice Total number of people who have been vouched for
    function totalVoucheesCount() external view returns (uint256) {
        return voucheeList.length;
    }

    /// @dev Mints a non-transferable SoulVouch NFT
    function mintSoulVouch(address to) internal {
        require(!hasSoulVouch[to], "Already has soul vouch");
        uint256 tokenId = uint256(uint160(to)); // Deterministic tokenId
        _mint(to, tokenId);
        hasSoulVouch[to] = true;
    }

    /// @dev Makes SoulVouch non-transferable (soulbound)
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        address from = _ownerOf(tokenId);
        require(from == address(0) || to == address(0), "SoulVouch: non-transferable");
        return super._update(to, tokenId, auth);
    }

    /// @dev Required to resolve multiple inheritance
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// ✅ FIX: Override to resolve diamond inheritance from ERC721 & ERC721Enumerable
    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        ERC721Enumerable._increaseBalance(account, value);
    }
}
