/**
 * SPDX-License-Identifier: MIT
**/

pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

// Need Another Interface because Balancer extends ERC20 in a lot of interfaces 
// import "@balancer-labs/v2-vault/contracts/interfaces/IVault.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "../LibAppStorage.sol";

/**
 * @author Publius
 * @title Lib Token Silo
**/
library LibTokenSilo {

    using SafeMath for uint32;
    using SafeMath for uint256;
    using SafeMath for uint112;
    
    event TokenDeposit(address indexed account, address indexed token, uint256 season, uint256 amount, uint256 bdv);

    function deposit(address account, address token, uint32 _s, uint256 amount) internal returns (uint256 bdv) {
        bdv = LibTokenSilo.beanDenominatedValue(token, amount);
        depositWithBDV(account, token, _s, amount, bdv);
    }

    function depositWithBDV(address account, address token, uint32 _s, uint256 amount, uint256 bdv) internal {
        require(bdv > 0, "Silo: No Beans under Token.");
        addDeposit(account, token, _s, amount, bdv);
    }

    function incrementDepositedToken(address token, uint256 amount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.siloBalances[IERC20(token)].deposited = s.siloBalances[IERC20(token)].deposited.add(amount);
    }

    function addDeposit(address account, address token, uint32 _s, uint256 amount, uint256 bdv) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.a[account].deposits[IERC20(token)][_s].tokens += uint112(amount);
        s.a[account].deposits[IERC20(token)][_s].bdv += uint112(bdv);

        // Increment Deposited Token Total
        s.siloBalances[IERC20(token)].deposited = s.siloBalances[IERC20(token)].deposited.add(amount);
        emit TokenDeposit(account, token, _s, amount, bdv);
    }

    function decrementDepositedToken(address token, uint256 amount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.siloBalances[IERC20(token)].deposited = s.siloBalances[IERC20(token)].deposited.sub(amount);
    }

    function removeDeposit(address account, address token, uint32 id, uint256 amount)
        internal
        returns (uint256, uint256) 
    {
        AppStorage storage s = LibAppStorage.diamondStorage();
        (uint256 crateAmount, uint256 crateBase) = tokenDeposit(account, token, id);
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

    function tokenDeposit(address account, address token, uint32 id) internal view returns (uint256, uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return (s.a[account].deposits[IERC20(token)][id].tokens, s.a[account].deposits[IERC20(token)][id].bdv);
    }

    function beanDenominatedValue(address token, uint256 amount) internal returns (uint256 bdv) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        bytes memory myFunctionCall = abi.encodeWithSelector(s.ss[token].selector, token, amount);
        (bool success, bytes memory data) = address(this).delegatecall(myFunctionCall);
        require(success, "Silo: Bean denominated value failed.");
        assembly { bdv := mload(add(data, add(0x20, 0))) }
    }

    function _buildBalancerPoolRequest() internal returns (JoinPoolRequest memory request) {

    }

    function addBalancerLiquidity (address poolAddress, 
        bytes32 poolId,
        address sender,
        address recipient,
        JoinPoolRequest memory request
    ) 
        internal
    {
        AppStorage storage s = LibAppStorage.diamondStorage();
        bytes memory myFunctionCall = abi.encodeWithSelector(
            s.poolDepositFunctions[poolAddress],
            poolId, sender, recipient, request
        );
        (bool success, bytes memory data) = address(this).delegatecall(myFunctionCall);
        require(success, "Silo: Bean denominated value failed.");
        assembly { bdv := mload(add(data, add(0x20, 0))) }
    }

    function tokenWithdrawal(address account, address token, uint32 id) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.a[account].withdrawals[IERC20(token)][id];
    }
}
