// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../../contracts/misc/vouching/VouchRegistry.sol";

contract VouchRegistryTest is Test {
    VouchRegistry _vouchRegistry; // Changed variable name to follow convention
    address _alice = address(1); // Changed to _alice
    address _bob = address(2); // Changed to _bob
    address _charlie = address(3); // Changed to _charlie

    function setUp() public {
        // Note: The constructor of VouchRegistry now requires Chainlink parameters.
        // For testing, you might need to mock these or provide dummy values.
        // Example: new VouchRegistry(address(0), "jobId", 0, address(0));
        // For a full-fledged test, consider mocking Chainlink interactions.
        _vouchRegistry = new VouchRegistry(address(0), "dummyJobId", 0, address(0));
    }

    function testVouchingAndMinting() public {
        vm.prank(_alice); // Changed to _alice
        _vouchRegistry.vouch(_bob); // Changed to _bob

        vm.prank(_charlie); // Changed to _charlie
        _vouchRegistry.vouch(_bob); // Changed to _bob

        // _bob should now have the SoulVouch NFT (2 vouches = default threshold)
        assertTrue(_vouchRegistry.hasSoulVouch(_bob)); // Changed to _bob
        uint256 tokenId = uint256(uint160(_bob)); // Changed to _bob
        assertEq(_vouchRegistry.ownerOf(tokenId), _bob); // Changed to _bob
    }

    function testRevokeVouch() public {
        vm.prank(_alice); // Changed to _alice
        _vouchRegistry.vouch(_bob); // Changed to _bob

        vm.prank(_alice); // Changed to _alice
        _vouchRegistry.revokeVouch(_bob); // Changed to _bob

        // Trust score should be 0
        uint256 score = _vouchRegistry.getTrustScore(_bob); // Changed to _bob
        assertEq(score, 0);
    }
}
