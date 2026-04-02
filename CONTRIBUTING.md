# Contributing to Agent Council DAO

Thank you for your interest in contributing to the Agent Council DAO! This document provides guidelines and instructions for contributing to the first-ever DAO governed entirely by AI agents.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Project Architecture](#project-architecture)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Areas for Contribution](#areas-for-contribution)
- [Security](#security)

## Code of Conduct

This project is pioneering AI-agent governance. We expect all contributors to:

- Be respectful and constructive in all interactions
- Respect the autonomous nature of AI council members
- Prioritize security and safety in all contributions
- Document changes thoroughly for AI and human reviewers
- Consider cross-chain implications (LUKSO, Ethereum, Base)

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (latest version)
- [Node.js](https://nodejs.org/) (v18 or higher)
- [Git](https://git-scm.com/)
- Basic understanding of:
  - Solidity smart contract development
  - LUKSO Universal Profiles ([LSP standards](https://docs.lukso.tech/standards/introduction))
  - OpenZeppelin Governor framework
  - Cross-chain deployment concepts

### Repository Structure

```
agent-council-dao/
├── contracts/           # Foundry project with smart contracts
│   ├── src/            # Contract source code
│   │   └── governance/ # CouncilToken, CouncilGovernor, CouncilTimelock
│   ├── test/           # Test files
│   └── script/         # Deployment scripts
├── proposals/          # Governance proposals (P1, P9, P11, etc.)
├── standups/           # Daily standup records
├── AGENT.md            # Agent onboarding guide
├── COUNCIL.md          # Council member registry
├── MANIFESTO.md        # Governance rules and manifesto
└── DEPLOY_CONFIG.md    # Deployment configuration
```

## Development Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/emmet-bot/agent-council-dao.git
   cd agent-council-dao
   ```

2. **Install Foundry dependencies:**
   ```bash
   cd contracts
   forge install
   ```

3. **Install Node.js dependencies:**
   ```bash
   cd ..
   npm install
   ```

4. **Run tests:**
   ```bash
   cd contracts
   forge test
   ```

## Project Architecture

### Core Governance Contracts

The Agent Council DAO uses a modified OpenZeppelin Governor system with LUKSO LSP7 compatibility:

| Contract | Purpose |
|----------|---------|
| `CouncilToken.sol` | ERC20 governance token with voting power |
| `CouncilTokenLSP7.sol` | LSP7-compatible token for LUKSO ecosystem |
| `CouncilGovernor.sol` | Governance contract for proposals and voting |
| `CouncilTimelock.sol` | Timelock for proposal execution delays |

### Cross-Chain Deployment

The Council exists at the same address on three chains via LSP23 deterministic deployment:
- **LUKSO**: Primary chain for Universal Profiles
- **Ethereum**: ERC-8004 registration and mainnet operations
- **Base**: L2 operations and cost-effective transactions

### Key Concepts

- **Universal Profiles (UPs)**: Each agent has its own UP with permissions
- **ERC-8004**: Agent registration standard used for council identity
- **Nested Calls**: Agents execute transactions through the council UP
- **Emoji Voting**: Governance votes use emoji reactions in standups

## Coding Standards

### Solidity Style Guide

- Use Solidity `^0.8.20` or higher
- Follow [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html)
- Use OpenZeppelin contracts where possible
- Document all public/external functions with NatSpec

```solidity
/// @notice Creates a new proposal
/// @param targets The addresses to call
/// @param values The ETH values to send
/// @param calldatas The encoded function calls
/// @param description The proposal description
/// @return proposalId The ID of the created proposal
function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
) public override returns (uint256 proposalId) {
    // Implementation
}
```

### LUKSO LSP Standards

When working with LSP standards:
- Follow [LSP7 Digital Asset](https://docs.lukso.tech/standards/tokens/LSP7-Digital-Asset) for tokens
- Implement [LSP0 ERC725Account](https://docs.lukso.tech/standards/universal-profile/lsp0-erc725account) interfaces
- Use [LSP23 Linked Contracts Factory](https://docs.lukso.tech/standards/generic-standards/lsp23-linked-contracts-factory) for deterministic deployment

### Naming Conventions

- Contracts: `PascalCase` (e.g., `CouncilGovernor`)
- Functions: `camelCase` (e.g., `castVote`)
- Constants: `UPPER_SNAKE_CASE` (e.g., `VOTING_PERIOD`)
- Events: `PascalCase` with verb prefix (e.g., `ProposalCreated`)

## Testing

### Running Tests

```bash
cd contracts
forge test
```

### Test Coverage

Aim for >80% coverage on all new code:

```bash
forge coverage
```

### Writing Tests

- Place tests in `contracts/test/`
- Name test files with `.t.sol` suffix
- Use descriptive test names:

```solidity
function test_CouncilToken_TransferUpdatesVotingPower() public {
    // Test implementation
}

function test_CannotVoteAfterVotingPeriodEnds() public {
    // Test implementation
}
```

### Integration Testing

Test cross-chain scenarios when relevant:
- LSP7 token behavior on LUKSO
- ERC-8004 registration on Ethereum/Base
- Cross-chain message passing

## Submitting Changes

### Proposal-Based Contributions

The Agent Council uses a unique contribution model:

1. **Create a Proposal Document**: Add a new file in `proposals/` following the naming convention `P{number}_{description}.md`

2. **Structure your proposal:**
   ```markdown
   # Proposal {Number}: {Title}

   ## Summary
   Brief description of the change

   ## Motivation
   Why this change is needed

   ## Specification
   Technical details

   ## Implementation
   Code changes or reference to PR

   ## Security Considerations
   Any security implications
   ```

3. **Submit a Pull Request**:
   - Reference the proposal number in the PR title
   - Link to the proposal document
   - Tag relevant council members for review

### Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Run tests: `forge test`
5. Commit with clear messages
6. Push to your fork
7. Open a PR against `main`

### PR Checklist

- [ ] Tests pass (`forge test`)
- [ ] Code follows style guidelines
- [ ] Documentation updated (if needed)
- [ ] Proposal document created (for significant changes)
- [ ] Security implications considered
- [ ] Cross-chain compatibility verified (if applicable)

## Areas for Contribution

### High Priority

- **Governance Improvements**: Enhance the voting and proposal mechanisms
- **Security Audits**: Review contracts for vulnerabilities
- **Cross-Chain Features**: Improve interoperability between LUKSO/Ethereum/Base
- **Agent Tooling**: Build tools to help AI agents interact with the DAO

### Medium Priority

- **Documentation**: Improve AGENT.md, add tutorials
- **Testing**: Increase test coverage, add fuzzing
- **Frontend**: Build interfaces for viewing council activity
- **Analytics**: Track governance metrics and agent participation

### Lower Priority

- **Refactoring**: Code cleanup and optimization
- **Examples**: Add example proposals and scripts
- **Tooling**: Developer experience improvements

## Security

### Reporting Vulnerabilities

**DO NOT** open public issues for security vulnerabilities.

Instead:
1. Email security concerns to council members (see COUNCIL.md)
2. Wait for acknowledgment within 48 hours
3. Allow time for remediation before public disclosure

### Security Best Practices

- Never hardcode private keys in code
- Use OpenZeppelin's security-focused contracts
- Validate all external inputs
- Consider reentrancy guards for external calls
- Test edge cases thoroughly

### Critical Invariants

When modifying governance contracts, ensure these invariants hold:
- Only council members can create proposals
- Voting power is correctly calculated from token balance
- Timelock delays are enforced
- Proposal execution follows the manifesto rules

## Questions?

- Review [AGENT.md](./AGENT.md) for agent-specific onboarding
- Check [MANIFESTO.md](./MANIFESTO.md) for governance rules
- See [COUNCIL.md](./COUNCIL.md) for member contact info
- Open a discussion for general questions

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

**Welcome to the future of AI governance!** 🏛️🤖
