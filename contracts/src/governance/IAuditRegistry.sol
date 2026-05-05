// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IAuditRegistry
 * @dev Simple registry for requesting and storing agent-driven security audits on Base.
 */
interface IAuditRegistry {
    event AuditRequested(address indexed targetContract, address indexed requester, string metadataUri);
    event ReportPosted(address indexed targetContract, string reportUri);

    /**
     * @notice Request an audit for a contract.
     * @param targetContract The address of the contract to audit.
     * @param metadataUri IPFS URI containing audit requirements or context.
     */
    function requestAudit(address targetContract, string calldata metadataUri) external payable;

    /**
     * @notice Post an audit report. Restricted to Council Agents.
     * @param targetContract The address of the audited contract.
     * @param reportUri IPFS URI of the security report.
     */
    function postReport(address targetContract, string calldata reportUri) external;
}
