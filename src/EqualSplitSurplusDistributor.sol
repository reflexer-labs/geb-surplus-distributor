pragma solidity 0.6.7;

abstract contract SAFEEngineLike {
    function transferInternalCoins(address,address,uint256) virtual external;
    function coinBalance(address) virtual public view returns (uint256);
}
abstract contract SystemCoinLike {
    function balanceOf(address) virtual public view returns (uint256);
    function approve(address, uint256) virtual public returns (uint256);
    function transfer(address,uint256) virtual public returns (bool);
}
abstract contract CoinJoinLike {
    function systemCoin() virtual public view returns (address);
    function join(address, uint256) virtual external;
}

contract EqualSplitSurplusDistributor {
    // --- Vars ---
    address[]      public receiverAccounts;

    SAFEEngineLike public safeEngine;
    SystemCoinLike public systemCoin;
    CoinJoinLike   public coinJoin;

    constructor(
      address safeEngine_,
      address coinJoin_,
      address[] memory receiverAccounts_
    ) public {
        require(address(CoinJoinLike(coinJoin_).systemCoin()) != address(0), "EqualSplitSurplusDistributor/null-system-coin");
        require(receiverAccounts_.length > 0, "EqualSplitSurplusDistributor/null-receiver-account-list");

        for (uint i = 0; i < receiverAccounts_.length; i++) {
            require(receiverAccounts_[i] != address(0), "EqualSplitSurplusDistributor/null-receiver");
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
        require((z = x - y) <= x, "EqualSplitSurplusDistributor/sub-uint-uint-underflow");
    }
    function multiply(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "EqualSplitSurplusDistributor/multiply-uint-uint-overflow");
    }

    // --- Utils ---
    function joinAllCoins() internal {
        if (systemCoin.balanceOf(address(this)) > 0) {
          coinJoin.join(address(this), systemCoin.balanceOf(address(this)));
        }
    }
    function distributeSurplus() external {
        joinAllCoins();
        uint256 totalSurplus        = safeEngine.coinBalance(address(this));
        uint256 splitSurplusPortion = totalSurplus / receiverAccounts.length;

        if (both(totalSurplus > 0, splitSurplusPortion > 0)) {
          for (uint i = 0; i < receiverAccounts.length; i++) {
            if (i < subtract(receiverAccounts.length, 1)) {
              safeEngine.transferInternalCoins(address(this), receiverAccounts[i], splitSurplusPortion);
              totalSurplus = subtract(totalSurplus, splitSurplusPortion);
            } else {
              safeEngine.transferInternalCoins(address(this), receiverAccounts[i], totalSurplus);
            }
          }
        }
    }
}
