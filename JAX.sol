// SPDX-License-Identifier: Unlicensed

/**

    If you made it this far analyzing my CA guts, you must be a real DEGEN. So let me introduce myself.
    I am CYBERJAX – a badass cybernetic panda with shades who enjoys rum, cigars, plays poker, loves fast cars, and bullies other memes (only stupid ones tho). 
    Don't be shy, my friend. Join the crew and get ready to JAX up your crypto game with CYBERJAX!

    Website: www.cyberjax.xyz

**/
pragma solidity 0.8.25;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() external view virtual override returns (string memory) {
        return _name;
    }

    function symbol() external view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() external view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() external view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) external virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    function _createSupply(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _setOwner(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() external virtual onlyOwner {
        _setOwner(address(0));
    }

    function transferOwnership(address newOwner) external virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

contract CYBERJAX is ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 public uniswapV2Router;
    address public immutable uniswapV2Pair;
    uint256 public payoutTaxAtAmount = 450000 * (10**18);
    uint256 public maxBuy = 15000000 * (10**18);
    uint256 public totalTax = 1;
    mapping (address => bool) public isTaxesExempt;
    address payable public taxWallet = payable(0x1E3A96fe8783775c06c8a8eD93DAE5d3d39Dcbcc);

    event PaidOutTaxes(uint256 contract_token_balance);
    
    bool private inSwapping;
    modifier lockTheSwap {
        inSwapping = true;
        _;
        inSwapping = false;
    }

    constructor() ERC20("CYBERJAX", "JAX") {

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;

        isTaxesExempt[owner()] = true;
        isTaxesExempt[taxWallet] = true;
        isTaxesExempt[address(this)] = true;
        
        _createSupply(owner(), 1000000000 * (10**18));

    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != address(0), "JAX: transfer from the zero address");
        require(to != address(0), "JAX: transfer to the zero address");

        if(amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if(from == uniswapV2Pair && !isTaxesExempt[to]) { // ONLY MAX WALLET FOR BUYING, SELLING ALWAYS WORKS
            uint256 token_receiver = balanceOf(to);
            require(token_receiver.add(amount) <= maxBuy, "JAX: Exceeds maximum wallet amount");
        }
        
        uint256 contract_token_balance = balanceOf(address(this));
        bool overMinTokenBalance = contract_token_balance >= payoutTaxAtAmount;
       
        if(to == uniswapV2Pair && overMinTokenBalance && !inSwapping) { // ONLY PAYOUT TAXES WHEN SELLING AND OVER MIN AMOUNT TO PAYOUT
            payoutTaxes(contract_token_balance);
        }

        if((to == uniswapV2Pair && !isTaxesExempt[from]) || (from == uniswapV2Pair && !isTaxesExempt[to])) { // ONLY DEDUCT FEES WHILE BUYING/SELLING
            uint256 taxes = amount.mul(totalTax).div(100);
            amount = amount.sub(taxes);
            super._transfer(from, address(this), taxes); 
        }

        super._transfer(from, to, amount);

    }

    function payoutTaxes(uint256 contract_token_balance) private lockTheSwap {
        swapTokensForETH(contract_token_balance);
        taxWallet.transfer(address(this).balance);
        emit PaidOutTaxes(contract_token_balance);
    }

    function swapTokensForETH(uint256 tokenAmount) private {

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        if(allowance(address(this), address(uniswapV2Router)) < tokenAmount) {
          _approve(address(this), address(uniswapV2Router), ~uint256(0));
        }

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
        
    }

    receive() external payable {}

}
