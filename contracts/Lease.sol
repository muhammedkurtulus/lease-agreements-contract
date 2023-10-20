// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract LeaseContract {
    enum PropertyType {
        House,
        Shop
    }

    struct PropertyInfo {
        string propertyAddress;
        address owner;
        PropertyType propertyType;
        string ownerName;
        LeaseInfo leaseInfo;
        bool isListed;
    }

    struct LeaseInfo {
        address tenantAddress;
        string tenantName;
        uint256 startDate;
        uint256 endDate;
        bool isActive;
        uint256 durationDays;
        address terminationRequester;
        string terminationReason;
    }

    uint256 public propertiesLength;

    mapping(uint256 => PropertyInfo) public properties;

    constructor() {
        propertiesLength = 0;
    }

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

    modifier notTerminationRequester(uint256 propertyIndex) {
        require(
            properties[propertyIndex].leaseInfo.terminationRequester !=
                msg.sender,
            "Termination requester cannot perform this action"
        );
        _;
    }

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
    event IssueReported(
        address indexed tenantAddress,
        uint256 propertyIndex,
        string propertyAddress,
        string tenantName,
        string issueDescription
    );

    event TerminationRequested(
        address indexed requesterAddress,
        uint256 propertyIndex,
        string propertyAddress,
        string ownerName,
        string tenantName,
        string reason
    );

    function addProperty(
        string memory propertyAddress,
        PropertyType propertyType,
        string memory ownerName
    ) external {
        require(
            propertyType == PropertyType.House ||
                propertyType == PropertyType.Shop,
            "Invalid property type"
        );

        PropertyInfo storage property = properties[propertiesLength];
        property.isListed = true;
        property.owner = msg.sender;
        property.propertyType = propertyType;
        property.ownerName = ownerName;
        property.propertyAddress = propertyAddress;
        property.leaseInfo.isActive = false;

        propertiesLength++;
    }

    function unlistProperty(
        uint256 propertyIndex
    ) external onlyPropertyOwner(propertyIndex) {
        require(
            properties[propertyIndex].leaseInfo.tenantAddress == address(0),
            "Property cannot be removed while leased"
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
        string memory tenantName,
        uint256 durationDays
    ) external onlyPropertyOwner(propertyIndex) {
        require(durationDays > 0, "Invalid lease duration");
        require(tenantAddress != msg.sender, "Owner cannot be tenant");

        PropertyInfo storage property = properties[propertyIndex];

        require(
            property.leaseInfo.tenantAddress == address(0),
            "Lease is already started"
        );

        property.leaseInfo.tenantAddress = tenantAddress;
        property.leaseInfo.tenantName = tenantName;
        property.leaseInfo.durationDays = durationDays;
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
            (property.leaseInfo.durationDays * 1 days);
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

    function terminateLease(
        uint256 propertyIndex,
        string memory reason
    ) external onlyPropertyOwner(propertyIndex) {
        PropertyInfo storage property = properties[propertyIndex];

        require(
            property.leaseInfo.isActive,
            "Lease is not active"
        );

        emit LeaseEnded(
            property.leaseInfo.tenantAddress,
            msg.sender,
            propertyIndex,
            property.leaseInfo.startDate,
            block.timestamp,
            property.propertyType,
            property.propertyAddress,
            property.ownerName,
            property.leaseInfo.tenantName,
            reason
        );

        property.leaseInfo.tenantAddress = address(0);
        property.leaseInfo.tenantName = "";
        property.leaseInfo.startDate = 0;
        property.leaseInfo.endDate = 0;
        property.leaseInfo.isActive = false;
    }

    function requestTermination(
        uint256 propertyIndex,
        string memory reason
    ) external {
        PropertyInfo storage property = properties[propertyIndex];

        require(
            property.leaseInfo.isActive,
            "Termination request can only be made for an active lease"
        );
        require(
            property.leaseInfo.tenantAddress == msg.sender ||
                property.owner == msg.sender,
            "Only tenant or owner can request termination"
        );

        property.leaseInfo.terminationRequester = msg.sender;
        property.leaseInfo.terminationReason = reason;

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
    ) external notTerminationRequester(propertyIndex) {
        PropertyInfo storage property = properties[propertyIndex];

        require(
            property.leaseInfo.tenantAddress == msg.sender ||
                property.owner == msg.sender,
            "Only tenant or owner can request termination"
        );

        require(
            property.leaseInfo.terminationRequester != address(0),
            "Termination is not requested"
        );

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

    function reportIssue(
        uint256 propertyIndex,
        string memory issueDescription
    ) external {
        PropertyInfo memory property = properties[propertyIndex];

        emit IssueReported(
            property.leaseInfo.tenantAddress,
            propertyIndex,
            property.propertyAddress,
            property.leaseInfo.tenantName,
            issueDescription
        );
    }

    function getAllProperties() public view returns (PropertyInfo[] memory) {
        PropertyInfo[] memory _properties = new PropertyInfo[](
            propertiesLength
        );

        for (uint256 i = 0; i < propertiesLength; i++) {
            _properties[i] = properties[i];
        }

        return _properties;
    }
}
