// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract LeaseContract {
    enum PropertyType {
        House,
        Shop
    }

    enum ConfirmationType {
        none,
        confirm,
        reject
    }

    struct Complaint {
        address complainant;
        address whoAbout;
        uint256 propertyIndex;
        string description;
        ConfirmationType confirmed;
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
        uint256 duration;
        address terminationRequester;
        string terminationReason;
        uint256 terminationRequestTime;
    }

    uint256 public propertiesLength;

    mapping(uint256 => PropertyInfo) public properties;
    mapping(address => Complaint) public complaints;

    address public owner;
    address[] public managers;

    constructor() {
        propertiesLength = 0;
        owner = msg.sender;
        managers.push(msg.sender);
    }

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

        Complaint memory complaint = complaints[msg.sender];

        require(
            complaint.confirmed != ConfirmationType.reject,
            "You are banned from adding new properties"
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

    function terminateLease(
        uint256 propertyIndex,
        string memory reason
    ) external onlyTenant(propertyIndex) {
        PropertyInfo storage property = properties[propertyIndex];

        require(property.leaseInfo.isActive, "Lease is not active");

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
        string memory description
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
        address complainant,
        bool confirmation
    ) external onlyManager {
        require(propertyIndex < propertiesLength, "Invalid property index");

        Complaint storage complaint = complaints[complainant];

        complaint.confirmed = confirmation
            ? ConfirmationType.confirm
            : ConfirmationType.reject;
    }

    function setManager(address managerAddress) external onlyOwner {
        // Sözleşme sahibi (owner), yeni bir yönetici ekleyebilir
        require(managerAddress != address(0), "Invalid manager address");
        require(!isManager(managerAddress), "Address is already a manager");
        managers.push(managerAddress);
    }

    function removeManager(address managerAddress) external onlyOwner {
        // Sözleşme sahibi (owner), bir yöneticiyi kaldırabilir
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

    function getAllProperties() public view returns (PropertyInfo[] memory) {
        PropertyInfo[] memory _properties = new PropertyInfo[](
            propertiesLength
        );

        for (uint256 i = 0; i < propertiesLength; i++) {
            _properties[i] = properties[i];
        }

        return _properties;
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only contract owner can perform this action"
        );
        _;
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

    modifier onlyManager() {
        require(isManager(msg.sender), "Only managers can perform this action");
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
    event ComplaintReported(
        address indexed complainant,
        address indexed whoAbout,
        uint256 propertyIndex,
        string propertyAddress,
        string description,
        address tenantAddress,
        address propertyOwner
    );

    event TerminationRequested(
        address indexed requesterAddress,
        uint256 propertyIndex,
        string propertyAddress,
        string ownerName,
        string tenantName,
        string reason
    );
}
