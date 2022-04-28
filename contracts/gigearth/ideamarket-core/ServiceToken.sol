// SPDX-License-Identifier: MIT
pragma solidity 0.6.9;

import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import '@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol';
import '@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol';
import '@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol';
import '@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol';
import './Ownable.sol';
import './Initializable.sol';
import '../interface/IIServiceToken.sol';

/**
 * @title ServiceToken
 * @author Alexander Schlindwein
 *
 * IdeaTokens are implementations of the ERC20 interface
 * They can be burned and minted by the owner of the contract instance which is the IdeaTokenExchange
 *
 * New instances are created using a MinimalProxy
 */
contract ServiceToken is
    IServiceToken,
    ERC1155,
    ERC1155Burnable,
    ERC1155Pausable,
    ERC1155Supply,
    ERC1155URIStorage,
    Ownable,
    Initializable
{
    mapping(address => mapping(address => uint256)) private _allowances;

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * Constructs an IdeaToken with 18 decimals
     * The constructor is called by the IdeaTokenFactory when a new token is listed
     * The owner of the contract is set to msg.sender
     *
     * @param __name The name of the token. IdeaTokenFactory will prefix the market name
     * @param owner The owner of this contract, NetworkManager
     */
    function initialize(string calldata __name, address owner) external override initializer {
        setOwnerInternal(owner);
        _decimals = 18;
        _symbol = 'IDT';
        _name = __name;
    }

    /**
     * Mints a given amount of tokens to an address
     * May only be called by the owner
     *
     * @param account The address to receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(
        address to,
        uint256 amount,
        uint256 id,
        bytes memory data
    ) external override onlyOwner {
        _mint(to, amount, id);
    }

    /**
     * Burns a given amount of tokens from an address.
     * May only be called by the owner
     *
     * @param account The address for the tokens to be burned from
     * @param amount The amount of tokens to be burned
     */
    function burn(address from, uint256 amount, uint256 id) external override onlyOwner {
        _burn(from, amount, id);
    }


    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }
}
