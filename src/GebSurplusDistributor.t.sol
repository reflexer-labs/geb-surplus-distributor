pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./GebSurplusDistributor.sol";

contract GebSurplusDistributorTest is DSTest {
    GebSurplusDistributor distributor;

    function setUp() public {
        distributor = new GebSurplusDistributor();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
