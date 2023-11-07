// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "./StringHelper.sol";

error InvalidAddress();
error ZeroValue();
error EmptyValue();
error InvalidType();
error BannedFromThisAction();
error AlreadyUnlisted();
error CannotUnlistActiveLease();
error OwnerCannotBeTenant();
error AlreadyActive();
error AlreadyAdded();
error SignPeriodExpired();
error RequestNotExist();
error RequesterCannotConfirm();
error NotPassed15Days();
error IsNotManager();
error MustRemainOneManager();
error OnlyExceptYourProperty();
error OnlyTenant();
error OnlyOwner();
error OnlyManager();
error OnlyPropertyOwner();
error OnlyTenantOrPropertyOwner();
error OnlyActiveLease();
error PermissionDenied();
error InvalidIndex();
error NoTenant();
error AlreadyListed();
error NoInitiator();

library ErrorHelper {
    using StringHelper for string;

    function checkAddress(address _addr) internal pure {
        if (_addr == address(0)) revert InvalidAddress();
    }

    function checkZero(uint256 _value) internal pure {
        if (_value == 0) revert ZeroValue();
    }

    function checkEmpty(string memory _s) internal pure {
        if (_s.isEmpty()) revert EmptyValue();
    }

    function checkIndex(uint256 _index, uint256 _length) internal pure {
        if (_index > _length) revert InvalidIndex();
    }
}
