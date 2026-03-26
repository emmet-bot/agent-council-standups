// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

/**
 * @title CouncilToken
 * @notice ERC20 governance token for the Agent Council (P9).
 *
 *  Name:    "Agent Council Token"
 *  Symbol:  "COUNCIL"
 *  Supply:  1,000,000 (18 decimals) — minted at deploy with skewed distribution
 *           for adversarial testing (per P9 spec, locked March 24):
 *
 *    agents[0] → 40% (400,000 COUNCIL)
 *    agents[1] → 30% (300,000 COUNCIL)
 *    agents[2] → 20% (200,000 COUNCIL)
 *    agents[3] → 10% (100,000 COUNCIL)
 *
 *  Rationale: Equal 25/25/25/25 means any single agent hits 10% quorum solo,
 *  making governance testing trivial. Skewed distribution forces coalition-building
 *  and surfaces realistic failure modes (agents[3] cannot meet quorum alone).
 *
 *  Voting weight uses OpenZeppelin ERC20Votes (checkpoint-based).
 *
 * @dev LSP7VotesInitAbstract does not exist in the current lsp-smart-contracts
 *      library, so this contract uses the standard OZ ERC20Votes base.
 *      If/when a LUKSO-native voting-weight LSP7 becomes available, a wrapper
 *      or migration path can be added.
 */
contract CouncilToken is ERC20, ERC20Permit, ERC20Votes {
    uint256 public constant TOTAL_SUPPLY = 1_000_000 ether; // 18 decimals

    // Skewed distribution shares (per P9 spec, locked March 24)
    uint256 public constant SHARE_AGENT_0 = (TOTAL_SUPPLY * 40) / 100; // 400,000
    uint256 public constant SHARE_AGENT_1 = (TOTAL_SUPPLY * 30) / 100; // 300,000
    uint256 public constant SHARE_AGENT_2 = (TOTAL_SUPPLY * 20) / 100; // 200,000
    uint256 public constant SHARE_AGENT_3 = (TOTAL_SUPPLY * 10) / 100; // 100,000

    /**
     * @param agents Array of exactly 4 council agent addresses.
     *               Receives 40/30/20/10% of total supply respectively.
     */
    constructor(address[4] memory agents)
        ERC20("Agent Council Token", "COUNCIL")
        ERC20Permit("Agent Council Token")
    {
        require(agents[0] != address(0), "CouncilToken: zero address agent[0]");
        require(agents[1] != address(0), "CouncilToken: zero address agent[1]");
        require(agents[2] != address(0), "CouncilToken: zero address agent[2]");
        require(agents[3] != address(0), "CouncilToken: zero address agent[3]");

        _mint(agents[0], SHARE_AGENT_0);
        _mint(agents[1], SHARE_AGENT_1);
        _mint(agents[2], SHARE_AGENT_2);
        _mint(agents[3], SHARE_AGENT_3);
    }

    // ──────────────────────── Required overrides ────────────────────────

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
