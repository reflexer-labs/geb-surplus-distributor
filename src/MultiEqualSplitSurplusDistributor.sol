pragma solidity 0.6.7;

abstract contract SAFEEngineLike {
    function transferInternalCoins(bytes32,address,address,uint256) virtual external;
    function coinBalance(bytes32,address) virtual public view returns (uint256);
}
abstract contract SystemCoinLike {
    function balanceOf(address) virtual public view returns (uint256);
    function approve(address, uint256) virtual public returns (uint256);
    function transfer(address,uint256) virtual public returns (bool);
}
abstract contract CoinJoinLike {
    function coinName() virtual public view returns (bytes32);
    function systemCoin() virtual public view returns (address);
    function join(address, uint256) virtual external;
}

contract MultiEqualSplitSurplusDistributor {
    // --- Vars ---
    // Addresses that will receive surplus
    address[]      public receiverAccounts;

    // The SAFEEngine contract
    SAFEEngineLike public safeEngine;
    // The system coin ERC20 contract
    SystemCoinLike public systemCoin;
    // The CoinJoin contract
    CoinJoinLike   public coinJoin;

    constructor(
      address safeEngine_,
      address coinJoin_,
      address[] memory receiverAccounts_
    ) public {
        require(address(CoinJoinLike(coinJoin_).systemCoin()) != address(0), "MultiEqualSplitSurplusDistributor/null-system-coin");
        require(receiverAccounts_.length > 0, "MultiEqualSplitSurplusDistributor/null-receiver-account-list");

        for (uint i = 0; i < receiverAccounts_.length; i++) {
            require(receiverAccounts_[i] != address(0), "MultiEqualSplitSurplusDistributor/null-receiver");
        }

        receiverAccounts = receiverAccounts_;
        safeEngine       = SAFEEngineLike(safeEngine_);
        coinJoin         = CoinJoinLike(coinJoin_);
        systemCoin       = SystemCoinLike(coinJoin.systemCoin());

        systemCoin.approve(address(coinJoin), uint(-1));
    }

    // --- Boolean Logic ---
    function both(bool x, bool y) internal pure returns (bool z) {
        assembly{ z := and(x, y)}
    }

    // --- Math ---
    function subtract(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "MultiEqualSplitSurplusDistributor/sub-uint-uint-underflow");
    }
    function multiply(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "MultiEqualSplitSurplusDistributor/multiply-uint-uint-overflow");
    }

    // --- Utils ---
    /*
    * @notify Internal util that joins all ERC20 coins this contract has inside the SAFEEngine
    */
    function joinAllCoins() internal {
        if (systemCoin.balanceOf(address(this)) > 0) {
          coinJoin.join(address(this), systemCoin.balanceOf(address(this)));
        }
    }
    /*
    * @notify Equally split all system coins this contract has to all receiverAccounts
    */
    function distributeSurplus() external {
        joinAllCoins();
        uint256 totalSurplus        = safeEngine.coinBalance(coinJoin.coinName(), address(this));
        uint256 splitSurplusPortion = totalSurplus / receiverAccounts.length;

        if (both(totalSurplus > 0, splitSurplusPortion > 0)) {
          for (uint i = 0; i < receiverAccounts.length; i++) {
            if (i < subtract(receiverAccounts.length, 1)) {
              safeEngine.transferInternalCoins(coinJoin.coinName(), address(this), receiverAccounts[i], splitSurplusPortion);
              totalSurplus = subtract(totalSurplus, splitSurplusPortion);
            } else {
              safeEngine.transferInternalCoins(coinJoin.coinName(), address(this), receiverAccounts[i], totalSurplus);
            }
          }
        }
    }
}
