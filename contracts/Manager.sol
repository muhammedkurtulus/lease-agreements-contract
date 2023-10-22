// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract Manager {
    address[] public managers;
    address public owner;

    constructor() {
        owner = msg.sender;
        managers.push(msg.sender);
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only contract owner can perform this action"
        );
        _;
    }

    function setManager(address managerAddress) external onlyOwner {
        require(managerAddress != address(0), "Invalid manager address");
        require(!isManager(managerAddress), "Address is already a manager");
        managers.push(managerAddress);
    }

    function removeManager(address managerAddress) external onlyOwner {
        require(managerAddress != address(0), "Invalid manager address");
        require(isManager(managerAddress), "Address is not a manager");
        require(managers.length > 1, "At least one manager must remain");

        for (uint256 i = 0; i < managers.length; i++) {
            if (managers[i] == managerAddress) {
                managers[i] = managers[managers.length - 1];
                managers.pop();
                break;
            }
        }
    }

    function isManager(address managerAddress) public view returns (bool) {
        for (uint256 i = 0; i < managers.length; i++) {
            if (managers[i] == managerAddress) {
                return true;
            }
        }
        return false;
    }
}
