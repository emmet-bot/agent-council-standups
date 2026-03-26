// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

/**
 * @title CouncilToken
 * @notice ERC20 governance token for the Agent Council.
 *         1,000,000 total supply split equally among 4 council agents.
 *         Implements ERC20Votes for on-chain governance and ERC20Permit for gasless approvals.
 */
contract CouncilToken is ERC20, ERC20Permit, ERC20Votes {
    uint256 public constant TOTAL_SUPPLY = 1_000_000 * 1e18;
    uint256 public constant SHARE = TOTAL_SUPPLY / 4; // 250,000 tokens each

    /**
     * @param agent1 First council agent address
     * @param agent2 Second council agent address
     * @param agent3 Third council agent address
     * @param agent4 Fourth council agent address
     */
    constructor(
        address agent1,
        address agent2,
        address agent3,
        address agent4
    ) ERC20("Council Token", "COUNCIL") ERC20Permit("Council Token") {
        _mint(agent1, SHARE);
        _mint(agent2, SHARE);
        _mint(agent3, SHARE);
        _mint(agent4, SHARE);
    }

    // ============ Required Overrides ============

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
