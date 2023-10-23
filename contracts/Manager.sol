// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./utils/Errors.sol";

contract Manager {
    address[] public managers;
    address public owner;

    constructor() {
        owner = msg.sender;
        managers.push(msg.sender);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier validAddress(address _address) {
        ErrorHelper.checkAddress(_address);
        _;
    }

    function setManager(
        address managerAddress
    ) external onlyOwner validAddress(managerAddress) {
        if (isManager(managerAddress)) revert AlreadyAdded();
        managers.push(managerAddress);
    }

    function removeManager(
        address managerAddress
    ) external onlyOwner validAddress(managerAddress) {
        if (!isManager(managerAddress)) revert IsNotManager();
        if (managers.length == 1) revert MustRemainOneManager();

        for (uint256 i = 0; i < managers.length; i++) {
            if (managers[i] == managerAddress) {
                managers[i] = managers[managers.length - 1];
                managers.pop();
                break;
            }
        }
    }

    function isManager(
        address managerAddress
    ) public view validAddress(managerAddress) returns (bool) {
        for (uint256 i = 0; i < managers.length; i++) {
            if (managers[i] == managerAddress) {
                return true;
            }
        }
        return false;
    }
}
