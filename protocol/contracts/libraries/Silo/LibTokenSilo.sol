/**
 * SPDX-License-Identifier: MIT
**/

pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "../LibAppStorage.sol";

/**
 * @author Publius
 * @title Lib Token Silo
**/
library LibTokenSilo {

    using SafeMath for uint256;
    using SafeMath for uint112;
    
    event TokenDeposit(address indexed token, address indexed account, uint256 season, uint256 amount, uint256 bdv);

    function incrementDepositedToken(address token, uint256 amount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.siloBalances[IERC20(token)].deposited = s.siloBalances[IERC20(token)].deposited.add(amount);
    }

    function decrementDepositedToken(address token, uint256 amount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.siloBalances[IERC20(token)].deposited = s.siloBalances[IERC20(token)].deposited.sub(amount);
    }

    function addDeposit(address token, address account, uint32 _s, uint256 amount, uint256 bdv) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.a[account].deposits[IERC20(token)][_s].tokens += uint112(amount);
        s.a[account].deposits[IERC20(token)][_s].bdv += uint112(bdv);
        emit TokenDeposit(token, msg.sender, _s, amount, bdv);
    }

    function removeDeposit(address token, address account, uint32 id, uint256 amount)
        internal
        returns (uint256, uint256) 
    {
        if (token == address(0)) return removeLegacyLPDeposit(account, id, amount);
        AppStorage storage s = LibAppStorage.diamondStorage();
        (uint256 crateAmount, uint256 crateBase) = tokenDeposit(token, account, id);
        require(crateAmount >= amount, "Silo: Crate balance too low.");
        if (amount < crateAmount) {
            uint112 base = uint112(amount.mul(crateBase).div(crateAmount));
            s.a[account].deposits[IERC20(token)][id].tokens -= uint112(amount);
            s.a[account].deposits[IERC20(token)][id].bdv -= base;
            return (amount, base);
        } else {
            delete s.a[account].deposits[IERC20(token)][id];
            return (crateAmount, crateBase);
        }
    }

    function removeLegacyLPDeposit(address account, uint32 id, uint256 amount)
        internal
        returns (uint256, uint256) 
    {
        AppStorage storage s = LibAppStorage.diamondStorage();
        require(id <= s.season.current, "Silo: Future crate.");
        (uint256 crateAmount, uint256 crateBase) = tokenDeposit(s.c.pair, account, id);
        require(crateAmount >= amount, "Silo: Crate balance too low.");
        require(crateAmount > 0, "Silo: Crate empty.");
        if (amount < crateAmount) {
            uint256 base = amount.mul(crateBase).div(crateAmount);
            s.a[account].lp.deposits[id] -= amount;
            s.a[account].lp.depositSeeds[id] -= base;
            return (amount, base);
        } else {
            delete s.a[account].lp.deposits[id];
            delete s.a[account].lp.depositSeeds[id];
            return (crateAmount, crateBase);
        }
    }

    function tokenDeposit(address token, address account, uint32 id) internal view returns (uint256, uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (token == address(0)) return (s.a[account].lp.deposits[id], s.a[account].lp.depositSeeds[id]/4);
        return (s.a[account].deposits[IERC20(token)][id].tokens, s.a[account].deposits[IERC20(token)][id].bdv);
    }

    function beanDenominatedValue(address token, uint256 amount) internal returns (uint256 bdv) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        bytes memory myFunctionCall = abi.encodeWithSelector(s.siloFunctions[token], token, amount);
        (bool success, bytes memory data) = address(this).delegatecall(myFunctionCall);
        require(success, "Silo: Bean denominated value failed.");
        assembly { bdv := mload(add(data, add(0x20, 0))) }
    }

    function tokenWithdrawal(address token, address account, uint32 id) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (token == address(0)) return s.a[account].lp.withdrawals[id];
        return s.a[account].withdrawals[IERC20(token)][id];
    }
}