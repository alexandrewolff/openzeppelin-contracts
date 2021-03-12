// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./ERC20.sol";
import "../../math/SafeMath.sol";

/**
 * @dev Extension of {ERC20} that adds a cap to the supply of tokens.
 */
abstract contract ERC20Stakable is ERC20 {
    using SafeMath for uint256;

    struct Stake {
        uint256 amount;
        uint256 lastUpdate;
    }

    mapping(address => Stake) private _stakes;

    uint256 private _totalStake;
    uint256 private _ratio;
    uint256 private _minStakeTime;

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Stake();

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
     event Withdraw();

     /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
     event Slash();

    /**
     * @dev Sets the value of the `cap`. This value is immutable, it can only be
     * set once during construction.
     */
    constructor (uint256 ratio, uint256 minStakeTime) public {
        // require(rewardBasispoints > 0, "ERC20: rewardDenominator must be more than 0");

        _ratio = ratio;
        _minStakeTime = minStakeTime;
    }

    function totalStake() public view returns (uint256) {
        return _totalStake;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function stakeOf(address account) public view returns (uint256) {
        Stake storage accountStake = _stakes[msg.sender];
        uint256 secElapsed = block.timestamp - accountStake.lastUpdate; // never underflows

        return _computeInterests(accountStake.amount, _ratio, secElapsed);
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function stake(uint256 amount) public {
        require(_balances[msg.sender] >= amount, "ERC20: insufficient balance");

        Stake storage accountStake = _stakes[msg.sender];

        _updateStake(accountStake);

        _balances[msg.sender].sub(amount);
        _totalStake = _totalStake.add(amount);
        accountStake.amount = accountStake.amount.add(amount);
        
        emit Stake();
    }

    function withdraw(uint256 amount) public {
        Stake storage accountStake = _stakes[msg.sender];

        require(block.timestamp > accountStake.lastUpdate.add(_minStakeTime), "ERC20: under minimum stake time");
        require(accountStake.amount >= amount, "ERC20: insufficient stake");

        _updateStake(accountStake);

        _totalStake = _totalStake.sub(amount);
        accountStake.amount = accountStake.amount.sub(amount);
        _balances[msg.sender].add(amount);

        emit Withdraw();
    }

    function _slash(uint256 rate) internal {
        Stake storage accountStake = _stakes[msg.sender];
        accountStake.amount = accountStake.amount.sub(accountStake.amount.mul(rate).div(1e18));

        emit Slash();
    }

    function _updateStake(Stake storage accountStake) private {
        uint256 secElapsed = block.timestamp - accountStake.lastUpdate; // never underflows

        accountStake.amount = _computeInterests(accountStake.amount, _ratio, secElapsed);
        accountStake.lastUpdate = block.timestamp;
    }

    function _computeInterests(uint256 principal, uint256 ratio, uint256 sec) private pure returns (uint256) {
        while (sec > 0) {
            if (sec.mod(2) == 1) {
                principal = principal.add(principal.mul(ratio));
                sec = sec.sub(1);
            } else {
                ratio = ratio.mul(2).add(ratio.mul(ratio));
                sec = sec.div(2);
            }
        }
        
        return principal;
    }

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - minted tokens must not cause the total supply to go over the cap.
     */
    // function _slash() internal virtual override {
        
    // }
}
