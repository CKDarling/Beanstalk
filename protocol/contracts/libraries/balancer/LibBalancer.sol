/*
 SPDX-License-Identifier: MIT
*/

pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import "../../interfaces/balancer/IVault.sol";
import "../../interfaces/IBean.sol";
import "../LibAppStorage.sol";
import "../LibClaim.sol";

/**
 * @author Publius
 * @title Balancer Library handles swapping, adding and removing LP on Balancer for Beanstalk.
**/
library LibBalancer {
    
    // Join and Exit Enums for UserData Request
    // In order to preserve backwards compatibility, make sure new join and exit kinds are added at the end of the enum.
    enum JoinKind { INIT, EXACT_TOKENS_IN_FOR_BPT_OUT, TOKEN_IN_FOR_EXACT_BPT_OUT, ALL_TOKENS_IN_FOR_EXACT_BPT_OUT }
    enum ExitKind {
        EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
        EXACT_BPT_IN_FOR_TOKENS_OUT,
        BPT_IN_FOR_EXACT_TOKENS_OUT,
        MANAGEMENT_FEE_TOKENS_OUT // for ManagedPool
    }

    struct AddBalancerLiquidity {
        uint256 minLPReceived;
        uint256 beanAmount;
        uint256 stalkAmount;
        uint256 seedAmount;
    }

    // Balancer Request Struct
    struct JoinPoolRequest {
        IAsset[] assets;
        uint256[] maxAmountsIn;
        bytes userData;
        bool fromInternalBalance;
    }

    using SafeMath for uint256;

    // Weighted Pool Userdata Encoding Functions
    function joinInit(uint256[] memory amountIn) internal returns (bytes memory userData) {
        userData = abi.encode(JoinKind.INIT, amountIn);
    }

    /**
    * Encodes the userData parameter for joining a WeightedPool with exact token inputs
    * @param amountsIn - the amounts each of token to deposit in the pool as liquidity
    * @param minimumBPT - the minimum acceptable BPT to receive in return for deposited tokens
    */
    function joinExactTokensInForBPTOut(uint256[] memory amountsIn, uint256 minimumBPT) internal returns (bytes memory userData) {
        userData = abi.encode(JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, amountsIn, minimumBPT);
    }

    /**
    * Encodes the userData parameter for joining a WeightedPool with a single token to receive an exact amount of BPT
    * @param bptAmountOut - the amount of BPT to be minted
    * @param enterTokenIndex - the index of the token to be provided as liquidity
    */
    function joinTokenInForExactBPTOut(uint256 bptAmountOut, uint256 enterTokenIndex) internal returns (bytes memory userData) {
        userData = abi.encode(JoinKind.TOKEN_IN_FOR_EXACT_BPT_OUT, bptAmountOut, enterTokenIndex);
    }

    /**
    * Encodes the userData parameter for joining a WeightedPool proportionally to receive an exact amount of BPT
    * @param bptAmountOut - the amount of BPT to be minted
    */
    function joinAllTokensInForExactBPTOut(uint256 bptAmountOut) internal returns (bytes memory userData) {
        userData = abi.encode(JoinKind.ALL_TOKENS_IN_FOR_EXACT_BPT_OUT, bptAmountOut);
    }

    /**
    * Encodes the userData parameter for exiting a WeightedPool by removing a single token in return for an exact amount of BPT
    * @param bptAmountIn - the amount of BPT to be burned
    * @param exitTokenIndex - the index of the token to removed from the pool
    */
    function exitExactBPTInForOneTokenOut (uint256 bptAmountIn, uint256 exitTokenIndex) internal returns (bytes memory userData) {
        userData = abi.encode(ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT, bptAmountIn, exitTokenIndex);   
    }

    /**
    * Encodes the userData parameter for exiting a WeightedPool by removing tokens in return for an exact amount of BPT
    * @param bptAmountIn - the amount of BPT to be burned
    */
    function exitExactBPTInForTokensOut (uint256 bptAmountIn) internal returns (bytes memory userData) {
        userData = abi.encode(ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT, bptAmountIn);
    }


    /**
    * Encodes the userData parameter for exiting a WeightedPool by removing exact amounts of tokens
    * @param amountsOut - the amounts of each token to be withdrawn from the pool
    * @param maxBPTAmountIn - the minimum acceptable BPT to burn in return for withdrawn tokens
    */
    function exitBPTInForExactTokensOut (uint256[] memory amountsOut, uint256 maxBPTAmountIn) internal returns (bytes memory userData) {
        userData = abi.encode(ExitKind.BPT_IN_FOR_EXACT_TOKENS_OUT, amountsOut, maxBPTAmountIn);
    }

    function exitForManagementFees() internal returns (bytes memory userData) {
        userData = abi.encode(ExitKind.MANAGEMENT_FEE_TOKENS_OUT);
    }
    
    // Balancer Internal functions
    function _buildPoolRequest(
        IAsset[] memory assets, 
        uint256[] memory maxAmountsIn, 
        bytes memory userData,
        bool fromInternalBalance
    ) 
        internal 
        returns (IVault.JoinPoolRequest memory request) 
    {
        request.assets = assets;
        request.maxAmountsIn = maxAmountsIn;
        request.userData = userData;
        request.fromInternalBalance = fromInternalBalance;
    }

    function _addLiquidityExactTokensInForBPTOut (
        AddBalancerLiquidity memory al,
        bytes32 poolId
    ) 
        internal
        returns (uint256 lpAdded)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();

        IAsset[] memory assets;
        assets[0] = IAsset(s.seedContract);
        assets[1] = IAsset(address(this));
        assets[2] = IAsset(s.c.bean);

        uint256[] memory maxAmountsIn;
        maxAmountsIn[0] = 2**256 - 1;
        maxAmountsIn[1] = 2**256 - 1;
        maxAmountsIn[2] = 2**256 - 1;

        uint256[] memory amountIn;
        amountIn[0] = al.seedAmount;
        amountIn[0] = al.stalkAmount;
        amountIn[0] = al.beanAmount;

        IVault.JoinPoolRequest memory request = _buildPoolRequest(
            assets, maxAmountsIn, 
            joinExactTokensInForBPTOut(amountIn, al.minLPReceived), 
            false
        );

        lpAdded = IERC20(s.beanSeedStalk3Pair.poolAddress).balanceOf(address(this));

        // Recipient of LP Tokens is Always the Silo
        IVault(s.balancerVault).joinPool(
            poolId, 
            msg.sender, 
            address(this), 
            request
        );

        lpAdded = IERC20(s.beanSeedStalk3Pair.poolAddress).balanceOf(address(this)).sub(lpAdded);
    }
}