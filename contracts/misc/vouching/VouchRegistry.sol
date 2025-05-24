// // Define datastructures

// struct Vouch {
//     address voucher;
//     uint256 timestamp;
//     bool revoked;
// }

// mapping(address => Vouch[]) private vouchHistory;

// // voucher => vouchee => bool (has vouched and not revoked)
// mapping(address => mapping(address => bool)) private hasVouched;

// // revoked vouches can be tracked within Vouch.revoked flag

// // Track number of valid vouches for each person
// mapping(address => uint256) public validVouchCount;

// // Track the number of required vouches per new vouchee
// mapping(address => uint256) public requiredVouches;

// //Implement vounching logic
// function vouch(address vouchee) external {
//     require(vouchee != msg.sender, "Cannot vouch for yourself");
//     require(!hasVouched[msg.sender][vouchee], "Already vouched for this person");

//     // If it's the first time we see this vouchee, assign required vouches dynamically
//     if (requiredVouches[vouchee] == 0) {
//         // Calculate required vouches for new user based on number of people already vouched for
//         // For example: requiredVouches = number of people already vouched + 1
//         requiredVouches[vouchee] = getNextRequiredVouches();
//     }

//     // Register the vouch
//     hasVouched[msg.sender][vouchee] = true;
//     vouchHistory[vouchee].push(Vouch(msg.sender, block.timestamp, false));

//     validVouchCount[vouchee]++;

//     // Optionally emit event
//     emit Vouched(msg.sender, vouchee, validVouchCount[vouchee], requiredVouches[vouchee]);
// }

// // Calculate required vouches dynamically based on number of people already vouched
// function getNextRequiredVouches() internal view returns (uint256) {
//     // For example, total number of unique vouchees so far:
//     uint256 totalVouchees = totalVoucheesCount();
//     // Threshold increases by 1 every new user after the first two
//     if (totalVouchees < 2) {
//         return 2; // first 2 users require 2 vouches
//     }
//     return totalVouchees + 1;
// }

// function totalVoucheesCount() public view returns (uint256) {
//     // This requires tracking all vouchees in an array or set, which is not shown yet
// }

// // Implement Revoke Vouch
// event VouchRevoked(address indexed voucher, address indexed vouchee);

// function revokeVouch(address vouchee) external {
//     require(hasVouched[msg.sender][vouchee], "No existing vouch found");

//     Vouch[] storage vouches = vouchHistory[vouchee];
//     bool found = false;

//     // Find the vouch from msg.sender and revoke it
//     for (uint256 i = 0; i < vouches.length; i++) {
//         if (vouches[i].voucher == msg.sender && !vouches[i].revoked) {
//             vouches[i].revoked = true;
//             found = true;
//             break;
//         }
//     }
//     require(found, "Vouch already revoked or not found");

//     hasVouched[msg.sender][vouchee] = false;
//     validVouchCount[vouchee] = validVouchCount[vouchee] > 0 ? validVouchCount[vouchee] - 1 : 0;

//     emit VouchRevoked(msg.sender, vouchee);
// }

// // Query Trust Score
// function getTrustScore(address person) public view returns (uint256) {
//     return validVouchCount[person];
// }

// // Get Vouch History
// function getVouchHistory(address person) public view returns (Vouch[] memory) {
//     return vouchHistory[person];
// }

// // Soulbound Token Integration (Basic Example)
// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// contract SoulVouch is ERC721 {
//     mapping(address => bool) public hasSoulVouch;

//     constructor() ERC721("SoulVouch", "SVOUCH") {}

//     function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
//         require(from == address(0) || to == address(0), "SoulVouch: non-transferable");
//         super._beforeTokenTransfer(from, to, tokenId);
//     }

//     function mintSoulVouch(address to) internal {
//         require(!hasSoulVouch[to], "Already has soul vouch");
//         uint256 tokenId = uint256(uint160(to)); // unique tokenId based on address
//         _mint(to, tokenId);
//         hasSoulVouch[to] = true;
//     }
// }

// revie and debug later

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract VouchRegistry is ERC721 {
    struct Vouch {
        address voucher;
        uint256 timestamp;
        bool revoked;
    }

    // voucher => vouchee => bool (has vouched and not revoked)
    mapping(address => mapping(address => bool)) private hasVouched;

    // vouchee => list of vouches
    mapping(address => Vouch[]) private vouchHistory;

    // person => number of valid vouches
    mapping(address => uint256) public validVouchCount;

    // person => how many vouches are required
    mapping(address => uint256) public requiredVouches;

    // Track unique vouchees for calculating next required vouches
    address[] private voucheeList;
    mapping(address => bool) private isVoucheeTracked;

    // Track who has received a SoulVouch token
    mapping(address => bool) public hasSoulVouch;

    event Vouched(address indexed voucher, address indexed vouchee, uint256 current, uint256 required);
    event VouchRevoked(address indexed voucher, address indexed vouchee);

    constructor() ERC721("SoulVouch", "SVOUCH") {}

    function vouch(address vouchee) external {
        require(vouchee != msg.sender, "Cannot vouch for yourself");
        require(!hasVouched[msg.sender][vouchee], "Already vouched");

        if (!isVoucheeTracked[vouchee]) {
            voucheeList.push(vouchee);
            isVoucheeTracked[vouchee] = true;
        }

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

    function getTrustScore(address person) external view returns (uint256) {
        return validVouchCount[person];
    }

    function getVouchHistory(address person) external view returns (Vouch[] memory) {
        return vouchHistory[person];
    }

    function getNextRequiredVouches() internal view returns (uint256) {
        uint256 total = voucheeList.length;
        if (total < 2) {
            return 2;
        }
        return total + 1;
    }

    function totalVoucheesCount() external view returns (uint256) {
        return voucheeList.length;
    }

    // Disable transfers to make SoulVouch non-transferable (soulbound)
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        require(from == address(0) || to == address(0), "SoulVouch: non-transferable");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function mintSoulVouch(address to) internal {
        require(!hasSoulVouch[to], "Already has soul vouch");
        uint256 tokenId = uint256(uint160(to));
        _mint(to, tokenId);
        hasSoulVouch[to] = true;
    }
}
