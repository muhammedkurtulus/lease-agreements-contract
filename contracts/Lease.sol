// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./Manager.sol";
import "./utils/Events.sol";
import "./utils/Types.sol";
import "./utils/Errors.sol";

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
        if (
            propertyType != PropertyType.House &&
            propertyType != PropertyType.Shop
        ) revert InvalidType();
        ErrorHelper.checkEmpty(ownerName);
        ErrorHelper.checkEmpty(propertyAddress);

        Complaint memory complaint = complaints[msg.sender];

        if (complaint.confirmed == ConfirmationType.confirm)
            revert BannedFromThisAction();

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

    function getAllComplaints() external view returns (Complaint[] memory) {
        Complaint[] memory allComplaints = new Complaint[](
            propertiesLength * 2
        );
        uint256 complaintCount = 0;

        for (uint256 i = 0; i < propertiesLength; i++) {
            address ownerAddress = properties[i].owner;
            address tenantAddress = properties[i].leaseInfo.tenantAddress;

            if (
                complaints[ownerAddress].complainant == address(0) &&
                complaints[tenantAddress].complainant == address(0)
            ) continue;

            if (complaints[tenantAddress].complainant != address(0)) {
                allComplaints[complaintCount] = complaints[tenantAddress];
                complaintCount++;
            }

            if (complaints[ownerAddress].complainant != address(0)) {
                allComplaints[complaintCount] = complaints[ownerAddress];
                complaintCount++;
            }
        }

        assembly {
            mstore(allComplaints, complaintCount)
        }

        return allComplaints;
    }

    function unlistProperty(
        uint256 propertyIndex
    ) external validIndex(propertyIndex) onlyPropertyOwner(propertyIndex) {
        if (properties[propertyIndex].isListed == false)
            revert AlreadyUnlisted();

        if (properties[propertyIndex].leaseInfo.isActive)
            revert CannotUnlistActiveLease();

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
    ) external validIndex(propertyIndex) onlyPropertyOwner(propertyIndex) {
        ErrorHelper.checkZero(duration);
        ErrorHelper.checkEmpty(tenantName);
        ErrorHelper.checkAddress(tenantAddress);

        if (tenantAddress == msg.sender) revert OwnerCannotBeTenant();

        Complaint memory complaint = complaints[msg.sender];

        if (complaint.confirmed == ConfirmationType.confirm)
            revert BannedFromThisAction();

        PropertyInfo storage property = properties[propertyIndex];

        if (properties[propertyIndex].leaseInfo.tenantAddress != address(0))
            revert AlreadyAdded();

        property.leaseInfo.tenantAddress = tenantAddress;
        property.leaseInfo.tenantName = tenantName;
        property.leaseInfo.duration = duration;
        property.leaseInfo.startDate = block.timestamp;
        property.leaseInfo.endDate = property.leaseInfo.startDate + 3 days; // 3 days for tenant to sign
    }

    function signLease(
        uint256 propertyIndex
    ) external validIndex(propertyIndex) onlyTenant(propertyIndex) {
        PropertyInfo storage property = properties[propertyIndex];

        if (property.leaseInfo.tenantAddress != msg.sender) revert OnlyTenant();

        if (property.leaseInfo.isActive) revert AlreadyActive();

        if (block.timestamp > property.leaseInfo.endDate)
            revert SignPeriodExpired();

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
    ) external validIndex(propertyIndex) {
        PropertyInfo storage property = properties[propertyIndex];

        if (
            property.leaseInfo.tenantAddress != msg.sender &&
            property.owner != msg.sender
        ) revert OnlyTenantOrPropertyOwner();

        if (!property.leaseInfo.isActive) revert OnlyActiveLease();

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

    function confirmTermination(
        uint256 propertyIndex
    ) external validIndex(propertyIndex) {
        PropertyInfo storage property = properties[propertyIndex];

        if (property.leaseInfo.terminationRequester == address(0))
            revert RequestNotExist();

        if (msg.sender == property.owner) {
            Complaint memory complaint = complaints[
                property.leaseInfo.tenantAddress
            ];

            if (
                property.leaseInfo.terminationRequester == msg.sender &&
                complaint.confirmed != ConfirmationType.confirm
            ) revert RequesterCannotConfirm();
        } else if (msg.sender == property.leaseInfo.tenantAddress) {
            Complaint memory complaint = complaints[property.owner];

            if (
                property.leaseInfo.terminationRequester == msg.sender &&
                block.timestamp <
                property.leaseInfo.terminationRequestTime + 15 days &&
                complaint.confirmed != ConfirmationType.confirm
            ) revert NotPassed15Days();
        } else if (isManager(msg.sender)) {
            if (
                block.timestamp <
                property.leaseInfo.terminationRequestTime + 15 days
            ) revert NotPassed15Days();
        } else {
            revert PermissionDenied();
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
    ) external validIndex(propertyIndex) {
        ErrorHelper.checkAddress(whoAbout);
        if (whoAbout == msg.sender) revert CannotComplainOwnself();

        PropertyInfo memory property = properties[propertyIndex];

        if (
            properties[propertyIndex].owner != msg.sender &&
            properties[propertyIndex].leaseInfo.tenantAddress != msg.sender &&
            (whoAbout != property.owner &&
                whoAbout != property.leaseInfo.tenantAddress)
        ) revert OnlyTenantOrPropertyOwner();

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
    ) external validIndex(propertyIndex) onlyManager {
        PropertyInfo memory property = properties[propertyIndex];

        if (
            property.owner == msg.sender ||
            property.leaseInfo.tenantAddress == msg.sender
        ) revert OnlyExceptYourProperty();

        Complaint storage complaint = complaints[whoAbout];

        complaint.confirmed = confirmation
            ? ConfirmationType.confirm
            : ConfirmationType.reject;
    }

    //MODIFIERS
    modifier onlyPropertyOwner(uint256 propertyIndex) {
        if (properties[propertyIndex].owner != msg.sender)
            revert OnlyPropertyOwner();
        _;
    }

    modifier onlyTenant(uint256 propertyIndex) {
        if (properties[propertyIndex].leaseInfo.tenantAddress != msg.sender)
            revert OnlyTenant();
        _;
    }

    modifier onlyManager() {
        if (!isManager(msg.sender)) revert OnlyManager();
        _;
    }

    modifier validIndex(uint256 propertyIndex) {
        ErrorHelper.checkIndex(propertyIndex, propertiesLength);
        _;
    }
}
