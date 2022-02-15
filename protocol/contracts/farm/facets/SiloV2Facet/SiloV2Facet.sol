/*
 * SPDX-License-Identifier: MIT
*/

pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import "./TokenSilo.sol";

/*
 * @author Publius
 * @title Silo handles depositing and withdrawing Beans and LP, and updating the Silo.
*/
contract SiloV2Facet is TokenSilo {

    event BeanAllocation(address indexed account, uint256 beans);

    using SafeMath for uint256;
    using SafeMath for uint32;

    /*
     * Generic
     */

    function deposit(address token, uint256 amount, UpdateSettings calldata settings) external {
        if (!settings.toInternalBalance) IERC20(token).transferFrom(msg.sender, address(this), amount);
        else LibUserBalance._increaseInternalBalance(msg.sender, IERC20(token), amount);
        _deposit(token, amount, settings.partialUpdateSilo);
    }

    function withdraw(address token, uint32[] calldata seasons, uint256[] calldata amounts, bool partialUpdateSilo) public {
        _withdraw(partialUpdateSilo, token, seasons, amounts);
    }

    function claimWithdrawals(address[] calldata tokens, uint32[] calldata seasons) public {
        for (uint256 i = 0; i < tokens.length; i++) {
            claimWithdrawal(tokens[i], seasons[i]);
        }
    }
    
    function claimWithdrawal(address token, uint32 season, bool fromInternalBalance) public returns (uint256 amount) {
        amount = removeTokenWithdrawal(msg.sender, token, season);
        if (fromInternalBalance) 
        IERC20(token).transfer(msg.sender, amount);
        emit ClaimWithdrawal(msg.sender, token, season, amount);
    }

    function whitelistToken(address token, bytes4 selector, uint32 stalk, uint32 seeds) external {
        require(msg.sender == address(this), "Silo: Only Beanstalk can whitelist tokens.");
        s.ss[token].selector = selector;
        s.ss[token].stalk = stalk;
        s.ss[token].seeds = seeds;
    }
}