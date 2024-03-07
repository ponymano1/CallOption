// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/CallOption.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Token is ERC20Permit { 
    constructor(string memory name, string memory symbol, uint256 amount) ERC20(name, symbol) ERC20Permit(name) {
        _mint(msg.sender, amount);
    }
}
  

contract CallOptionTest is Test {
    using SafeERC20 for IERC20;
    CallOption option;
    IERC20 underlyingAsset;
    IERC20 token;
    address admin;
    address issuer;
    address tester1;
    address tester2;

    function setUp() public {
        admin = makeAddr("admin");
        issuer = makeAddr("issuer");
        tester1 = makeAddr("tester1");
        tester2 = makeAddr("tester2");
        console.log("setup issuer:", issuer);
        vm.startPrank(admin);
        {
            underlyingAsset = new Token("A", "A", 10000 ether);
            token = new Token("U", "U", 10000 ether);
            option = new CallOption(address(underlyingAsset), address(token), 2 ether, block.timestamp + 100, block.timestamp + 30, issuer);
            underlyingAsset.safeTransfer(address(issuer), 1000 ether);
            token.safeTransfer(address(tester1), 1000 ether);

        }
        vm.stopPrank();
        
    }

    function issueOption() public {
        console.log("issuer:",issuer);
        vm.startPrank(issuer);
        {
            underlyingAsset.approve(address(option), 100 ether);
            option.issueOption(100);
            assertEq(option.balanceOf(issuer), 100);
        }
        vm.stopPrank();
    }

    function test_exerciseOption() public {
        issueOption();
        vm.startPrank(issuer);
        {
            IERC20(option).safeTransfer(tester1, 10);
        }
        vm.stopPrank();
        vm.startPrank(tester1);
        {
            vm.warp(block.timestamp + 40);

            uint256 balanceBeforeUnderlying = underlyingAsset.balanceOf(tester1);
            uint256 balanceBeforeToken = token.balanceOf(tester1);
            uint256 issuerBalanceBefore = token.balanceOf(issuer);
            token.approve(address(option), 100 ether);
            option.exerciseOption(10);
            uint256 balanceAfterUnderlying = underlyingAsset.balanceOf(tester1);
            uint256 balanceAfterToken = token.balanceOf(tester1);
            uint256 issuerBalanceAfter = token.balanceOf(issuer);
            assertEq(balanceAfterUnderlying - balanceBeforeUnderlying, 10 * 1 ether);
            assertEq(balanceBeforeToken - balanceAfterToken,   10 * 2 ether);
            assertEq(issuerBalanceAfter - issuerBalanceBefore, 10 * 2 ether);
        }
        vm.stopPrank();

        
    }


}
