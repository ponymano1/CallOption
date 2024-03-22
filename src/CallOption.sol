// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Test, console} from "forge-std/Test.sol";

/**
    * CallOption: 期权合约,看涨期权
 */
contract CallOption is ERC20Permit {
    using SafeERC20 for IERC20;
    address internal immutable _underlyingAsset;//对应的质押资产
    address internal immutable _token;//用于行权购买的质押资产的token,比如USDT
    uint256 internal _strikePrice;//行权价
    uint256 internal _expiration;//到期时间
    uint256 internal _lockBefore;//到期前锁定时间 
    uint256 constant RATIO = 1 ether;
    address _issuer;// 期权发行者
    
    error OptionExpired();
    error OptionLocked();
    error InsufficientBalance();
    error OptionNotExpired();
    error NotIssure();

    modifier OnlyIssuer() {
        if (msg.sender != _issuer) {
            revert NotIssure();
        }
        _;
    }




    constructor(address underlyingAsset_, address token_,uint256 strikePrice_, uint256 expiration_, uint256 lockBefore_, address issuer_) ERC20Permit("CallOption") ERC20("CallOption", "CALL") {
        _underlyingAsset = underlyingAsset_;
        _token = token_;
        _strikePrice = strikePrice_;
        _expiration = expiration_;
        _lockBefore = lockBefore_;
        _issuer = issuer_;
    }

    /**
     * issueOption: 发行期权
     * @param amount_ 发行数量
     * 转移资产进合约，mint出期权token
     */
    function issueOption(uint256 amount_) public  OnlyIssuer {
        IERC20(_underlyingAsset).safeTransferFrom(msg.sender, address(this), amount_ * RATIO);
        _mint(msg.sender, amount_);
    }

    /**
     * exerciseOption: 行权
     * @param amount : 行权数量
     * 1. 判断是否过期,判断是否锁定，只有在窗口期可以行权
     * 2. 判断是否有足够的期权
     * 3. 销毁期权
     * 4. 购买对应的资产
     * 5. 转移资产给行权者
     * 
     */
    function exerciseOption(uint256 amount) public {
        console.log("block.timestamp:", block.timestamp, "lockBefore:", _lockBefore);
        if (block.timestamp < _lockBefore) {
            revert OptionLocked();
        }

        if (block.timestamp > _expiration) {
            revert OptionExpired();
        }

        if (IERC20(this).balanceOf(msg.sender) < amount) {
            revert InsufficientBalance();
        }
        _burn(msg.sender, amount);
        uint256 totolCost = amount * _strikePrice;
        IERC20(_token).safeTransferFrom(msg.sender, _issuer, totolCost);
        IERC20(_underlyingAsset).safeTransfer(msg.sender, amount * RATIO);
    }

    /**
     * withdraw: 撤回抵押资产，
     * 1.判断是否过期，如果没有过期，不能withdraw
     * 2.将合约中的资产转移到发行者
     */
    function withdraw() public {
        if (block.timestamp < _expiration) {
            revert OptionNotExpired();
        }

        uint256 balance = IERC20(_underlyingAsset).balanceOf(address(this));
        IERC20(_underlyingAsset).safeTransfer(_issuer, balance);
    }
}