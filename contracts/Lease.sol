// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./Manager.sol";
import "./Events.sol";
import "./Types.sol";

contract Lease is Manager, Events {
    uint256 public propertiesLength;

    mapping(uint256 => PropertyInfo) public properties;
    mapping(address => Complaint) public complaints;

    constructor() {
        propertiesLength = 0;
    }

    function addProperty(
        string calldata propertyAddress,
        PropertyType propertyType,
        string calldata ownerName
    ) external {
        require(
            propertyType == PropertyType.House ||
                propertyType == PropertyType.Shop,
            "Invalid property type"
        );

        Complaint memory complaint = complaints[msg.sender];

        require(
            complaint.confirmed != ConfirmationType.reject,
            "You are banned from adding new properties"
        );

        PropertyInfo storage property = properties[propertiesLength];
        property.propertyIndex = propertiesLength;
        property.isListed = true;
        property.owner = msg.sender;
        property.propertyType = propertyType;
        property.ownerName = ownerName;
        property.propertyAddress = propertyAddress;
        property.leaseInfo.isActive = false;

        propertiesLength++;
    }

    function getAllProperties() external view returns (PropertyInfo[] memory) {
        PropertyInfo[] memory _properties = new PropertyInfo[](
            propertiesLength
        );

        for (uint256 i = 0; i < propertiesLength; i++) {
            _properties[i] = properties[i];
        }

        return _properties;
    }

    function unlistProperty(
        uint256 propertyIndex
    ) external onlyPropertyOwner(propertyIndex) {
        require(
            properties[propertyIndex].leaseInfo.tenantAddress == address(0),
            "Property cannot be unlist while leased"
        );

        PropertyInfo storage property = properties[propertyIndex];
        property.isListed = false;

        property.leaseInfo.tenantAddress = address(0);
        property.leaseInfo.tenantName = "";
        property.leaseInfo.startDate = 0;
        property.leaseInfo.endDate = 0;
    }

    function startLease(
        uint256 propertyIndex,
        address tenantAddress,
        string calldata tenantName,
        uint256 duration
    ) external onlyPropertyOwner(propertyIndex) {
        require(duration > 0, "Lease duration must be at least 1 year");
        require(tenantAddress != msg.sender, "Owner cannot be tenant");

        Complaint memory complaint = complaints[msg.sender];

        require(
            complaint.confirmed != ConfirmationType.reject,
            "You are banned from starting new leases"
        );

        PropertyInfo storage property = properties[propertyIndex];

        require(
            property.leaseInfo.tenantAddress == address(0),
            "Lease is already started"
        );

        property.leaseInfo.tenantAddress = tenantAddress;
        property.leaseInfo.tenantName = tenantName;
        property.leaseInfo.duration = duration;
        property.leaseInfo.startDate = block.timestamp;
        property.leaseInfo.endDate = property.leaseInfo.startDate + 3 days; // 3 days for tenant to sign
    }

    function signLease(
        uint256 propertyIndex
    ) external onlyTenant(propertyIndex) {
        PropertyInfo storage property = properties[propertyIndex];

        require(
            property.leaseInfo.tenantAddress == msg.sender,
            "Only tenant can sign the lease"
        );

        require(!property.leaseInfo.isActive, "Lease is already signed");

        require(
            block.timestamp <= property.leaseInfo.endDate,
            "Lease signing period has expired"
        );

        property.leaseInfo.startDate = block.timestamp;
        property.leaseInfo.endDate =
            property.leaseInfo.startDate +
            (property.leaseInfo.duration * 52 weeks);
        property.leaseInfo.isActive = true;

        emit LeaseStarted(
            property.leaseInfo.tenantAddress,
            msg.sender,
            propertyIndex,
            property.leaseInfo.startDate,
            property.leaseInfo.endDate,
            property.propertyType,
            property.propertyAddress,
            property.ownerName,
            property.leaseInfo.tenantName
        );
    }

    function requestTermination(
        uint256 propertyIndex,
        string calldata reason
    ) external {
        PropertyInfo storage property = properties[propertyIndex];

        require(
            property.leaseInfo.tenantAddress == msg.sender ||
                property.owner == msg.sender,
            "Only tenant or owner can request termination"
        );

        require(
            property.leaseInfo.isActive,
            "Termination request can only be made for an active lease"
        );

        property.leaseInfo.terminationRequester = msg.sender;
        property.leaseInfo.terminationReason = reason;
        property.leaseInfo.terminationRequestTime = block.timestamp;

        emit TerminationRequested(
            msg.sender,
            propertyIndex,
            property.propertyAddress,
            property.ownerName,
            property.leaseInfo.tenantName,
            reason
        );
    }

    function confirmTermination(uint256 propertyIndex) external {
        PropertyInfo storage property = properties[propertyIndex];

        require(
            property.leaseInfo.terminationRequester != address(0),
            "Termination is not requested"
        );

        if (msg.sender == property.owner) {
            Complaint memory complaint = complaints[
                property.leaseInfo.tenantAddress
            ];
            require(
                property.leaseInfo.terminationRequester != msg.sender ||
                    complaint.confirmed == ConfirmationType.confirm,
                "Termination requester cannot confirm termination"
            );
        } else if (msg.sender == property.leaseInfo.tenantAddress) {
            Complaint memory complaint = complaints[property.owner];

            require(
                property.leaseInfo.terminationRequester != msg.sender ||
                    block.timestamp >=
                    property.leaseInfo.terminationRequestTime + 15 days ||
                    complaint.confirmed == ConfirmationType.confirm,
                "15 days have not passed yet"
            );
        } else if (isManager(msg.sender)) {
            require(
                block.timestamp >=
                    property.leaseInfo.terminationRequestTime + 15 days,
                "15 days have not passed yet"
            );
        } else {
            require(false, "Permission denied");
        }

        emit LeaseEnded(
            property.leaseInfo.tenantAddress,
            property.owner,
            propertyIndex,
            property.leaseInfo.startDate,
            block.timestamp,
            property.propertyType,
            property.propertyAddress,
            property.ownerName,
            property.leaseInfo.tenantName,
            property.leaseInfo.terminationReason
        );

        property.leaseInfo.tenantAddress = address(0);
        property.leaseInfo.tenantName = "";
        property.leaseInfo.startDate = 0;
        property.leaseInfo.endDate = 0;
        property.leaseInfo.isActive = false;
        property.leaseInfo.terminationRequester = address(0);
        property.leaseInfo.terminationReason = "";
    }

    function submitComplaint(
        uint256 propertyIndex,
        address whoAbout,
        string calldata description
    ) external {
        require(propertyIndex < propertiesLength, "Invalid property index");

        PropertyInfo memory property = properties[propertyIndex];

        require(
            property.leaseInfo.tenantAddress == msg.sender ||
                property.owner == msg.sender,
            "Only tenant or owner can request termination"
        );
        require(
            (whoAbout == property.owner ||
                whoAbout == property.leaseInfo.tenantAddress) &&
                whoAbout != address(0),
            "Invalid address"
        );
        require(whoAbout != msg.sender, "You cannot complain about yourself");

        Complaint storage complaint = complaints[whoAbout];

        complaint.complainant = msg.sender;
        complaint.propertyIndex = propertyIndex;
        complaint.description = description;
        complaint.whoAbout = whoAbout;

        emit ComplaintReported(
            msg.sender,
            complaint.whoAbout,
            propertyIndex,
            property.propertyAddress,
            description,
            property.leaseInfo.tenantAddress,
            property.owner
        );
    }

    function reviewComplaint(
        uint256 propertyIndex,
        address whoAbout,
        bool confirmation
    ) external onlyManager {
        require(propertyIndex < propertiesLength, "Invalid property index");

        PropertyInfo memory property = properties[propertyIndex];

        require(
            property.owner != msg.sender &&
                property.leaseInfo.tenantAddress != msg.sender,
            "Manager who is tenant or owner cannot review complaints"
        );

        Complaint storage complaint = complaints[whoAbout];

        complaint.confirmed = confirmation
            ? ConfirmationType.confirm
            : ConfirmationType.reject;
    }

    //MODIFIERS
    modifier onlyPropertyOwner(uint256 propertyIndex) {
        require(
            properties[propertyIndex].owner == msg.sender,
            "Only property owner can perform this action"
        );
        _;
    }

    modifier onlyTenant(uint256 propertyIndex) {
        require(
            properties[propertyIndex].leaseInfo.tenantAddress == msg.sender,
            "Only tenant can perform this action"
        );
        _;
    }

    modifier onlyManager() {
        require(isManager(msg.sender), "Only managers can perform this action");
        _;
    }
}
