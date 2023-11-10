// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./Types.sol";

contract Events {
    event LeaseStarted(
        address indexed tenantAddress,
        address indexed ownerAddress,
        uint256 propertyIndex,
        uint256 startDate,
        uint256 endDate,
        PropertyType propertyType,
        string propertyAddress,
        string ownerName,
        string tenantName
    );
    event LeaseEnded(
        address indexed tenantAddress,
        address indexed ownerAddress,
        uint256 propertyIndex,
        uint256 startDate,
        uint256 endDate,
        PropertyType propertyType,
        string propertyAddress,
        string ownerName,
        string tenantName,
        string terminationReason
    );
    event ComplaintReported(
        address indexed complainant,
        address indexed whoAbout,
        uint256 propertyIndex,
        string propertyAddress,
        string description,
        address tenantAddress,
        address propertyOwner
    );

    event ComplaintConcluded(
        address indexed complainant,
        address indexed whoAbout,
        uint256 propertyIndex,
        string propertyAddress,
        string description,
        address tenantAddress,
        address propertyOwner,
        string conclusion
    );
}
