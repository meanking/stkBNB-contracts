// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC777/IERC777RecipientUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC1820RegistryUpgradeable.sol";
import "./interfaces/IFeeVault.sol";
import "./interfaces/IAddressStore.sol";
import "./interfaces/Istkbnb.sol";

contract FeeVault is IFeeVault, Initializable, IERC777RecipientUpgradeable, OwnableUpgradeable {
    IERC1820RegistryUpgradeable private constant _ERC1820_REGISTRY =
        IERC1820RegistryUpgradeable(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    /*********************
     * STATE VARIABLES
     ********************/

    /**
     * @dev addressStore: The Address Store. Used to fetch addresses of the other contracts in the system.
     */
    IAddressStore public addressStore;

    /*********************
     * EVENTS
     ********************/

    event Deposit(address from, uint256 amount);
    event Withdraw(address from, address to, uint256 amount);

    /*********************
     * ERRORS
     ********************/
    error InvalidToken();
    error TokenTransferNotAllowed(address from);
    error TokenTransferToSelfNotAllowed();
    error UnexpectedlyReceivedTokensForSomeoneElse(address to);

    /*********************
     * INIT FUNCTIONS
     ********************/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {} // solhint-disable-line no-empty-blocks

    function initialize(IAddressStore _addressStore) public initializer {
        __FeeVault_init(_addressStore);
    }

    function __FeeVault_init(IAddressStore _addressStore) internal onlyInitializing {
        // Need to call initializers for each parent without calling anything twice.
        __Context_init_unchained();
        __Ownable_init_unchained();
        // Finally, initialize this contract.
        __FeeVault_init_unchained(_addressStore);
    }

    function __FeeVault_init_unchained(IAddressStore _addressStore) internal onlyInitializing {
        addressStore = _addressStore;
        _ERC1820_REGISTRY.setInterfaceImplementer(
            address(this),
            keccak256("ERC777TokensRecipient"),
            address(this)
        );
    }

    /**
     * @dev claim: Called by a multisig account to transfer stkBNB from vault to another account.
     *
     * Requirements:
     * - Only owner can call
     */
    function claimStkBNB(address recipient, uint256 amount) external override onlyOwner {
        IStakedBNBToken(addressStore.getStkBNB()).send(recipient, amount, "");
        emit Withdraw(msg.sender, recipient, amount);
    }

    /**
     * @dev tokensReceived: hook call while tokens transfer to this contract.
     *
     * Requirements:
     * - Only accept stkBNB token.
     * - Accept minted tokens and trasfer tokens from LiquidStaking contract.
     * - Should not received tokens i.e., minted and transfer to another account.
     */
    function tokensReceived(
        address,
        address from,
        address to,
        uint256 amount,
        bytes calldata,
        bytes calldata
    ) external override {
        if (msg.sender != addressStore.getStkBNB()) {
            revert InvalidToken();
        }

        if (from != address(0) && from != addressStore.getStakePool()) {
            revert TokenTransferNotAllowed(from);
        }
        if (from == address(this)) {
            revert TokenTransferToSelfNotAllowed();
        }
        if (to != address(this)) {
            revert UnexpectedlyReceivedTokensForSomeoneElse(to);
        }
        emit Deposit(from, amount);
    }
}