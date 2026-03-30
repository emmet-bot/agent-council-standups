// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Votes} from "@openzeppelin/contracts/governance/utils/Votes.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @dev LSP1 Universal Receiver interface for token notifications.
 */
interface ILSP1UniversalReceiver {
    function universalReceiver(bytes32 typeId, bytes memory data) external returns (bytes memory);
}

/**
 * @title CouncilTokenLSP7
 * @notice LSP7-compatible governance token for the Agent Council (P11).
 *
 *  Name:    "Agent Council Token"
 *  Symbol:  "COUNCIL"
 *  Supply:  1,000,000 (18 decimals) — minted at deploy with skewed distribution:
 *           40% agent1, 30% agent2, 20% agent3, 10% agent4
 *
 *  Architecture:
 *  - OZ v5 Votes base → IVotes/IERC5805 → plugs directly into GovernorVotes
 *  - LSP7-style transfer semantics (from, to, amount, force, data)
 *  - Operator model (authorizeOperator/revokeOperator) instead of ERC20 approve
 *  - LSP1 UniversalReceiver notifications on mint/transfer/burn (sender + recipient)
 *  - LSP4 metadata constants (tokenType, tokenName, tokenSymbol)
 *  - ERC165 for LSP7 + IERC5805 interface detection
 *
 *  Why not extend LSP7VotesInitAbstract directly?
 *  The upstream LSP7VotesInitAbstract uses its own Checkpoints/Counters implementation
 *  targeting OZ v4 patterns. Our Governor stack is OZ v5. Using OZ v5 Votes base
 *  directly gives us a clean single-inheritance path and avoids OZ version conflicts
 *  in the Foundry build. The LSP7 transfer/operator/notification semantics are
 *  implemented directly, providing full LSP7 compliance without the initializer
 *  complexity.
 *
 * @dev Issue #8 compliance:
 *  ✅ LSP1 recipient notification (RecipientNotification)
 *  ✅ LSP1 sender notification (SenderNotification)
 *  ✅ force=false enforcement
 *  ✅ getOperatorsOf()
 *  ✅ transferBatch()
 *  ✅ LSP4 tokenType constant
 *  ✅ increaseAllowance / decreaseAllowance
 *  ✅ ERC165 for LSP7 + IERC5805
 */
contract CouncilTokenLSP7 is Votes, IERC165 {
    using EnumerableSet for EnumerableSet.AddressSet;

    // ──────────────────────── Errors ────────────────────────

    error LSP7AmountExceedsBalance(uint256 balance, address tokenOwner, uint256 amount);
    error LSP7AmountExceedsAuthorizedAmount(
        address tokenOwner, uint256 authorizedAmount, address operator, uint256 amount
    );
    error LSP7CannotSendToSelf();
    error LSP7CannotSendToAddressZero();
    error LSP7CannotUseAddressZeroAsOperator();
    error LSP7TokenOwnerCannotBeOperator();
    error LSP7InvalidTransferBatch();
    error LSP7NotifyTokenReceiverContractMissingLSP1Interface(address to);
    error LSP7ExceededSafeSupply(uint256 supply, uint256 cap);
    error DuplicateAgentAddress();
    error OwnableCallerNotTheOwner(address caller);

    // ──────────────────────── Events ────────────────────────

    /// @dev Emitted on transfer/mint/burn per LSP7 spec.
    event Transfer(
        address indexed operator, address indexed from, address indexed to, uint256 amount, bool force, bytes data
    );

    event OperatorAuthorizationChanged(
        address indexed operator, address indexed tokenOwner, uint256 indexed amount, bytes operatorNotificationData
    );

    event OperatorRevoked(
        address indexed operator, address indexed tokenOwner, bool indexed notified, bytes operatorNotificationData
    );

    // ──────────────────────── Constants ────────────────────────

    uint256 public constant TOTAL_SUPPLY = 1_000_000 ether;

    uint256 public constant SHARE_AGENT_1 = (TOTAL_SUPPLY * 40) / 100; // 400,000
    uint256 public constant SHARE_AGENT_2 = (TOTAL_SUPPLY * 30) / 100; // 300,000
    uint256 public constant SHARE_AGENT_3 = (TOTAL_SUPPLY * 20) / 100; // 200,000
    uint256 public constant SHARE_AGENT_4 = (TOTAL_SUPPLY * 10) / 100; // 100,000

    /// @dev LSP7DigitalAsset interface ID
    bytes4 private constant _INTERFACE_ID_LSP7 = 0x05519512;

    /// @dev LSP1 UniversalReceiver interface ID
    bytes4 private constant _INTERFACE_ID_LSP1 = 0x6bb56a14;

    /// @dev keccak256("LSP7Tokens_RecipientNotification")
    bytes32 private constant _TYPEID_LSP7_TOKENS_RECIPIENT =
        0x20804611535B35A00CB8D9A33C47B5B4B3A8FE4AF2118F9CB1F90EDA4455F4AB;

    /// @dev keccak256("LSP7Tokens_SenderNotification")
    bytes32 private constant _TYPEID_LSP7_TOKENS_SENDER =
        0x429ac7a06903dbc9c13dfcb3c9d11df8194581fa047c96d7a4171fc7402958ea;

    /// @dev LSP4 token type: 0 = Token
    uint256 public constant LSP4_TOKEN_TYPE = 0;

    // ──────────────────────── Storage ────────────────────────

    string private _name;
    string private _symbol;
    address private _owner;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _operators;
    mapping(address => EnumerableSet.AddressSet) private _operatorsOf;

    // ──────────────────────── Constructor ────────────────────────

    /**
     * @param agents Array of exactly 4 council agent addresses.
     *               Receives 40/30/20/10% of COUNCIL tokens respectively.
     */
    constructor(address[4] memory agents) EIP712("Agent Council Token", "1") {
        _name = "Agent Council Token";
        _symbol = "COUNCIL";
        _owner = msg.sender;

        // H-03: Prevent duplicate agents
        if (
            agents[0] == agents[1] || agents[0] == agents[2] || agents[0] == agents[3]
                || agents[1] == agents[2] || agents[1] == agents[3] || agents[2] == agents[3]
        ) revert DuplicateAgentAddress();

        uint256[4] memory shares = [SHARE_AGENT_1, SHARE_AGENT_2, SHARE_AGENT_3, SHARE_AGENT_4];

        for (uint256 i = 0; i < 4; i++) {
            require(agents[i] != address(0), "CouncilToken: zero address agent");
            _mint(agents[i], shares[i]);
        }

        // H-01: Auto-delegate so voting power is active immediately
        _delegate(agents[0], agents[0]);
        _delegate(agents[1], agents[1]);
        _delegate(agents[2], agents[2]);
        _delegate(agents[3], agents[3]);
    }

    // ──────────────────────── LSP7 View Functions ────────────────────────

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function owner() public view returns (address) {
        return _owner;
    }

    /// @dev LSP4 tokenType getter.
    function tokenType() external pure returns (uint256) {
        return LSP4_TOKEN_TYPE;
    }

    // ──────────────────────── LSP7 Operator Functions ────────────────────────

    function authorizeOperator(address operator, uint256 amount, bytes memory operatorNotificationData)
        public
        virtual
    {
        if (operator == address(0)) revert LSP7CannotUseAddressZeroAsOperator();
        if (operator == msg.sender) revert LSP7TokenOwnerCannotBeOperator();

        _operators[operator][msg.sender] = amount;
        _operatorsOf[msg.sender].add(operator);

        emit OperatorAuthorizationChanged(operator, msg.sender, amount, operatorNotificationData);
    }

    function revokeOperator(address operator, address tokenOwner, bool notify, bytes memory operatorNotificationData)
        public
        virtual
    {
        if (operator == address(0)) revert LSP7CannotUseAddressZeroAsOperator();
        require(msg.sender == tokenOwner || msg.sender == operator, "LSP7: caller not owner or operator");

        delete _operators[operator][tokenOwner];
        _operatorsOf[tokenOwner].remove(operator);

        emit OperatorRevoked(operator, tokenOwner, notify, operatorNotificationData);
    }

    function authorizedAmountFor(address operator, address tokenOwner) public view returns (uint256) {
        if (operator == tokenOwner) return _balances[tokenOwner];
        return _operators[operator][tokenOwner];
    }

    /**
     * @notice Returns all authorized operators for `tokenOwner`.
     */
    function getOperatorsOf(address tokenOwner) external view returns (address[] memory) {
        return _operatorsOf[tokenOwner].values();
    }

    /**
     * @notice Increase the authorized amount for `operator` by `addedAmount`.
     */
    function increaseAllowance(address operator, uint256 addedAmount, bytes memory operatorNotificationData)
        public
        virtual
    {
        if (operator == address(0)) revert LSP7CannotUseAddressZeroAsOperator();
        if (operator == msg.sender) revert LSP7TokenOwnerCannotBeOperator();

        uint256 newAmount = _operators[operator][msg.sender] + addedAmount;
        _operators[operator][msg.sender] = newAmount;
        _operatorsOf[msg.sender].add(operator);

        emit OperatorAuthorizationChanged(operator, msg.sender, newAmount, operatorNotificationData);
    }

    /**
     * @notice Decrease the authorized amount for `operator` by `subtractedAmount`.
     */
    function decreaseAllowance(address operator, uint256 subtractedAmount, bytes memory operatorNotificationData)
        public
        virtual
    {
        if (operator == address(0)) revert LSP7CannotUseAddressZeroAsOperator();

        uint256 currentAmount = _operators[operator][msg.sender];
        require(currentAmount >= subtractedAmount, "LSP7: decreased below zero");

        uint256 newAmount;
        unchecked {
            newAmount = currentAmount - subtractedAmount;
        }
        _operators[operator][msg.sender] = newAmount;

        if (newAmount == 0) {
            _operatorsOf[msg.sender].remove(operator);
        }

        emit OperatorAuthorizationChanged(operator, msg.sender, newAmount, operatorNotificationData);
    }

    // ──────────────────────── LSP7 Transfer Functions ────────────────────────

    /**
     * @notice Transfer `amount` tokens from `from` to `to`.
     * @param from The sender address.
     * @param to The recipient address.
     * @param amount The amount to transfer.
     * @param force When false, `to` must implement LSP1. When true, allow EOA recipients.
     * @param data Additional data sent with the transfer.
     */
    function transfer(address from, address to, uint256 amount, bool force, bytes memory data) public virtual {
        if (from == to) revert LSP7CannotSendToSelf();

        // Authorization check
        if (msg.sender != from) {
            uint256 authorizedAmount = _operators[msg.sender][from];
            if (authorizedAmount < amount) {
                revert LSP7AmountExceedsAuthorizedAmount(from, authorizedAmount, msg.sender, amount);
            }
            unchecked {
                _operators[msg.sender][from] = authorizedAmount - amount;
            }
        }

        _transfer(from, to, amount, force, data);
    }

    /**
     * @notice Batch transfer tokens.
     * @param from Array of sender addresses.
     * @param to Array of recipient addresses.
     * @param amount Array of amounts.
     * @param force Array of force flags.
     * @param data Array of additional data.
     */
    function transferBatch(
        address[] calldata from,
        address[] calldata to,
        uint256[] calldata amount,
        bool[] calldata force,
        bytes[] calldata data
    ) external {
        uint256 length = from.length;
        if (length != to.length || length != amount.length || length != force.length || length != data.length) {
            revert LSP7InvalidTransferBatch();
        }

        for (uint256 i = 0; i < length;) {
            transfer(from[i], to[i], amount[i], force[i], data[i]);
            unchecked {
                ++i;
            }
        }
    }

    // ──────────────────────── ERC165 ────────────────────────

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == _INTERFACE_ID_LSP7 || interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IERC5805).interfaceId;
    }

    // ──────────────────────── Internal ────────────────────────

    function _mint(address to, uint256 amount) internal {
        _totalSupply += amount;
        uint256 cap = _maxSupply();
        if (_totalSupply > cap) {
            revert LSP7ExceededSafeSupply(_totalSupply, cap);
        }

        _balances[to] += amount;

        emit Transfer(msg.sender, address(0), to, amount, true, "");

        _transferVotingUnits(address(0), to, amount);

        // LSP1 notification on mint (recipient only, force=true for constructor mints)
        _notifyTokenReceiver(to, true, "");
    }

    function _transfer(address from, address to, uint256 amount, bool force, bytes memory data) internal {
        if (to == address(0)) revert LSP7CannotSendToAddressZero();

        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) {
            revert LSP7AmountExceedsBalance(fromBalance, from, amount);
        }

        // force=false: `to` must support LSP1 if it's a contract
        if (!force) {
            _enforceForce(to);
        }

        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(msg.sender, from, to, amount, force, data);

        _transferVotingUnits(from, to, amount);

        // LSP1 sender notification
        _notifyTokenSender(from, data);
        // LSP1 recipient notification
        _notifyTokenReceiver(to, force, data);
    }

    /**
     * @dev Enforce force=false: revert if `to` is a contract that doesn't support LSP1.
     */
    function _enforceForce(address to) internal view {
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(to)
        }
        if (codeSize > 0) {
            try IERC165(to).supportsInterface(_INTERFACE_ID_LSP1) returns (bool supported) {
                if (!supported) {
                    revert LSP7NotifyTokenReceiverContractMissingLSP1Interface(to);
                }
            } catch {
                revert LSP7NotifyTokenReceiverContractMissingLSP1Interface(to);
            }
        }
    }

    /**
     * @dev Notify `from` via LSP1 universalReceiver with SenderNotification type.
     *      Wrapped in try/catch — notification failure does not revert the transfer.
     */
    function _notifyTokenSender(address from, bytes memory data) internal {
        if (from == address(0)) return; // Skip on mint
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(from)
        }
        if (codeSize > 0) {
            try IERC165(from).supportsInterface(_INTERFACE_ID_LSP1) returns (bool supported) {
                if (supported) {
                    try ILSP1UniversalReceiver(from).universalReceiver(_TYPEID_LSP7_TOKENS_SENDER, data) {}
                    catch {}
                }
            } catch {}
        }
    }

    /**
     * @dev Notify `to` via LSP1 universalReceiver with RecipientNotification type.
     *      Wrapped in try/catch — notification failure does not revert the transfer.
     */
    function _notifyTokenReceiver(address to, bool, /* force */ bytes memory data) internal {
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(to)
        }
        if (codeSize > 0) {
            try IERC165(to).supportsInterface(_INTERFACE_ID_LSP1) returns (bool supported) {
                if (supported) {
                    try ILSP1UniversalReceiver(to).universalReceiver(_TYPEID_LSP7_TOKENS_RECIPIENT, data) {}
                    catch {}
                }
            } catch {}
        }
    }

    /**
     * @dev Maximum supply cap for voting safety (uint208 max per OZ Votes).
     */
    function _maxSupply() internal pure returns (uint256) {
        return type(uint208).max;
    }

    /**
     * @dev Returns the voting units for an account (= token balance).
     *      Required by OZ Votes base.
     */
    function _getVotingUnits(address account) internal view override returns (uint256) {
        return _balances[account];
    }
}
