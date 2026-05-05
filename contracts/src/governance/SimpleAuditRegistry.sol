// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IAuditRegistry.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SimpleAuditRegistry
 * @dev Implementation of IAuditRegistry for Base Mainnet.
 */
contract SimpleAuditRegistry is IAuditRegistry, Ownable {
    mapping(address => string) public latestReports;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function requestAudit(address targetContract, string calldata metadataUri) external payable override {
        emit AuditRequested(targetContract, msg.sender, metadataUri);
    }

    function postReport(address targetContract, string calldata reportUri) external override onlyOwner {
        latestReports[targetContract] = reportUri;
        emit ReportPosted(targetContract, reportUri);
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
