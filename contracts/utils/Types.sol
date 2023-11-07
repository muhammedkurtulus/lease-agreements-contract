// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

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
    uint256 complaintIndex;
    uint256 propertyIndex;
    string description;
    ConfirmationType confirmed;
}

struct PropertyInfo {
    uint256 propertyIndex;
    string propertyAddress;
    address owner;
    PropertyType propertyType;
    string ownerName;
    LeaseInfo leaseInfo;
    bool isListed;
}

struct LeaseInfo {
    address tenantAddress;
    address initiatorAddress;
    string tenantName;
    uint256 startDate;
    uint256 endDate;
    bool isActive;
    uint256 duration;
    address terminationRequester;
    string terminationReason;
    uint256 terminationRequestTime;
}
