pragma solidity 0.6.7;

import "ds-test/test.sol";
import "geb/multi/MultiSAFEEngine.sol";
import "geb/shared/Coin.sol";
import {MultiCoinJoin} from "geb/shared/BasicTokenAdapters.sol";

import "../MultiEqualSplitSurplusDistributor.sol";

abstract contract Hevm {
    function warp(uint256) virtual public;
}
contract MultiEqualSplitSurplusDistributorTest is DSTest {
    Hevm hevm;

    MultiSAFEEngine safeEngine;
    Coin systemCoin;
    MultiCoinJoin coinJoin;
    MultiEqualSplitSurplusDistributor distributor;

    bytes32 coinName = "BAI";

    address[] receivers;

    // --- Utils ---
    function rad(uint x) internal view returns (uint z) {
        z = x * 10**27;
    }

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        safeEngine  = new MultiSAFEEngine();
        systemCoin  = new Coin("Coin", "COIN", 99);
        coinJoin    = new MultiCoinJoin(coinName, address(safeEngine), address(systemCoin));

        safeEngine.initializeCoin(coinName, uint(-1));

        systemCoin.addAuthorization(address(coinJoin));
        safeEngine.createUnbackedDebt(coinName, address(0), address(this), rad(1000 ether));

        safeEngine.approveSAFEModification(coinName, address(coinJoin));
        coinJoin.exit(address(this), 100 ether);
    }

    function test_setup() public {
        receivers.push(address(0x1));
        receivers.push(address(0x2));

        distributor = new MultiEqualSplitSurplusDistributor(address(safeEngine), address(coinJoin), receivers);

        assertEq(address(distributor.safeEngine()), address(safeEngine));
        assertEq(address(distributor.systemCoin()), address(systemCoin));
        assertEq(address(distributor.coinJoin()), address(coinJoin));

        assertEq(distributor.receiverAccounts(0), address(0x1));
        assertEq(distributor.receiverAccounts(1), address(0x2));

        assertEq(systemCoin.balanceOf(address(this)), 100 ether);
        assertEq(systemCoin.allowance(address(distributor), address(coinJoin)), uint(-1));
    }
    function test_no_surplus() public {
        receivers.push(address(0x1));
        receivers.push(address(0x2));

        distributor = new MultiEqualSplitSurplusDistributor(address(safeEngine), address(coinJoin), receivers);
        distributor.distributeSurplus();

        assertEq(systemCoin.balanceOf(address(distributor)), 0);
        assertEq(safeEngine.coinBalance(coinName, address(this)), rad(900 ether));
        assertEq(safeEngine.coinBalance(coinName, address(distributor)), 0);
        assertEq(safeEngine.coinBalance(coinName, address(0x1)), 0);
        assertEq(safeEngine.coinBalance(coinName, address(0x2)), 0);
    }
    function test_not_enough_surplus() public {
        receivers.push(address(0x1));
        receivers.push(address(0x2));
        receivers.push(address(0x3));

        distributor = new MultiEqualSplitSurplusDistributor(address(safeEngine), address(coinJoin), receivers);
        safeEngine.createUnbackedDebt(coinName, address(0), address(distributor), 2);

        distributor.distributeSurplus();

        assertEq(systemCoin.balanceOf(address(distributor)), 0);
        assertEq(safeEngine.coinBalance(coinName, address(this)), rad(900 ether));
        assertEq(safeEngine.coinBalance(coinName, address(distributor)), 2);
        assertEq(safeEngine.coinBalance(coinName, address(0x1)), 0);
        assertEq(safeEngine.coinBalance(coinName, address(0x2)), 0);
        assertEq(safeEngine.coinBalance(coinName, address(0x3)), 0);
    }
    function test_unevenly_distributed_surplus() public {
        receivers.push(address(0x1));
        receivers.push(address(0x2));
        receivers.push(address(0x3));

        distributor = new MultiEqualSplitSurplusDistributor(address(safeEngine), address(coinJoin), receivers);
        safeEngine.createUnbackedDebt(coinName, address(0), address(distributor), 7);

        distributor.distributeSurplus();

        assertEq(systemCoin.balanceOf(address(distributor)), 0);
        assertEq(safeEngine.coinBalance(coinName, address(this)), rad(900 ether));
        assertEq(safeEngine.coinBalance(coinName, address(distributor)), 0);
        assertEq(safeEngine.coinBalance(coinName, address(0x1)), 2);
        assertEq(safeEngine.coinBalance(coinName, address(0x2)), 2);
        assertEq(safeEngine.coinBalance(coinName, address(0x3)), 3);
    }
    function test_evenly_distributed_surplus() public {
        receivers.push(address(0x1));
        receivers.push(address(0x2));
        receivers.push(address(0x3));

        distributor = new MultiEqualSplitSurplusDistributor(address(safeEngine), address(coinJoin), receivers);
        safeEngine.createUnbackedDebt(coinName, address(0), address(distributor), rad(300 ether));

        distributor.distributeSurplus();

        assertEq(systemCoin.balanceOf(address(distributor)), 0);
        assertEq(safeEngine.coinBalance(coinName, address(this)), rad(900 ether));
        assertEq(safeEngine.coinBalance(coinName, address(distributor)), 0);
        assertEq(safeEngine.coinBalance(coinName, address(0x1)), rad(100 ether));
        assertEq(safeEngine.coinBalance(coinName, address(0x2)), rad(100 ether));
        assertEq(safeEngine.coinBalance(coinName, address(0x3)), rad(100 ether));
    }
    function test_external_coin_balance_unevenly_distributed_surplus() public {
        receivers.push(address(0x1));
        receivers.push(address(0x2));
        receivers.push(address(0x3));

        distributor = new MultiEqualSplitSurplusDistributor(address(safeEngine), address(coinJoin), receivers);
        safeEngine.createUnbackedDebt(coinName, address(0), address(distributor), rad(300 ether));

        systemCoin.transfer(address(distributor), 50 ether);
        distributor.distributeSurplus();

        assertEq(systemCoin.balanceOf(address(distributor)), 0);
        assertEq(safeEngine.coinBalance(coinName, address(this)), rad(900 ether));
        assertEq(safeEngine.coinBalance(coinName, address(distributor)), 0);
        assertEq(safeEngine.coinBalance(coinName, address(0x1)), rad(350 ether) / 3);
        assertEq(safeEngine.coinBalance(coinName, address(0x2)), rad(350 ether) / 3);
        assertEq(safeEngine.coinBalance(coinName, address(0x3)), rad(350 ether) / 3 + rad(350 ether) % 3);
    }
}
