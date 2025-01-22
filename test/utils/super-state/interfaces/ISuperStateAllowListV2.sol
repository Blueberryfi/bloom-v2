// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface ISuperStateAllowListV2 {
    type EntityId is uint256;

    function setEntityAllowedForFund(EntityId entityId, string calldata fundSymbol, bool isAllowed) external;
    function setEntityIdForAddress(EntityId entityId, address addr) external;
}
