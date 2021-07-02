pragma solidity ^0.4.24;

/**
 * @dev SafeMath
 * Math operations with safety checks that throw on error
 * https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/math/SafeMath.sol
 */
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}
/**
 * @dev Interface of the KIP-13 standard, as defined in the
 * [KIP-13](http://kips.klaytn.com/KIPs/kip-13-interface_query_standard).
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others.
 *
 * For an implementation, see `KIP13`.
 */
interface IKIP13 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
/**
 * @dev Interface of the KIP7 standard as defined in the KIP. Does not include
 * the optional functions; to access them see `KIP7Metadata`.
 * See http://kips.klaytn.com/KIPs/kip-7-fungible_token
 */
contract IKIP7 is IKIP13 {
    function totalSupply() public view returns (uint256);
    function balanceOf(address account) public view returns (uint256);
    function decimals() public view returns (uint8);
    function transfer(address recipient, uint256 amount) public returns (bool);
    function allowance(address owner, address spender) public view returns (uint256);
    function approve(address spender, uint256 amount) public returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool);
    function safeTransfer(address recipient, uint256 amount, bytes memory data) public;
    function safeTransfer(address recipient, uint256 amount) public;
    function safeTransferFrom(address sender, address recipient, uint256 amount, bytes memory data) public;
    function safeTransferFrom(address sender, address recipient, uint256 amount) public;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
/**
 * @dev Implementation of the `IKIP13` interface.
 *
 * Contracts may inherit from this and call `_registerInterface` to declare
 * their support of an interface.
 */
contract KIP13 is IKIP13 {
    bytes4 private constant _INTERFACE_ID_KIP13 = 0x01ffc9a7;
    mapping(bytes4 => bool) private _supportedInterfaces;

    constructor () internal {
        _registerInterface(_INTERFACE_ID_KIP13);
    }

    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        return _supportedInterfaces[interfaceId];
    }

    function _registerInterface(bytes4 interfaceId) internal {
        require(interfaceId != 0xffffffff, "KIP13: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
    }
}

contract IKIP7Receiver {
    function onKIP7Received(address _operator, address _from, uint256 _amount, bytes memory _data) public returns (bytes4);
}
// ----------------------------------------------------------------------------
// @title KIP7
// ----------------------------------------------------------------------------
contract KIP7 is KIP13, IKIP7 {
    using SafeMath for uint256;

    struct LockInfo {
        uint8 tokenType;
        uint256 amount;
        uint256 distributedTime;
        uint8 lockUpPeriodMonth;
        uint256 lastUnlockTimestamp;
        uint256 unlockAmountPerCount;
        uint256 unlockCount;
    }
    
    uint256 internal _totalSupply;
    uint8 private _decimals = 18;
    
    mapping(address => uint256) internal _balances;
    mapping(address => mapping (address => uint256)) internal _allowances;

    mapping(address => uint8) internal _cardioWallet;
    mapping(address => LockInfo) internal _lockedInfo;

    bytes4 private constant _KIP7_RECEIVED = 0x9d188c22;
    bytes4 private constant _INTERFACE_ID_KIP7 = 0x65787371;

    constructor() public {
        // Crowd Sale Wallet
        _cardioWallet[0xAb388B7E9bB7C9DB8858DbACACCC667d4Cf5D390] = 1;
        // Ecosystem Activation
        _cardioWallet[0x596C53c1d24F1BA7F7Fb38c2676F7673378150c9] = 2;
        // Team & Advisors
        _cardioWallet[0x5Ea976A033aE4473faA7beaAe4A9CCFFD6075FCc] = 3;
        // Team & Advisors
        _cardioWallet[0x9Cd9A5fad80707005a3835bEc9F68A892e256108] = 4;
        // Business Development
        _cardioWallet[0x3F6B9a3b0682E3A8Cda81eeE78d4E9D53E4FbC24] = 5;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function increaseApproval(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(amount));
        return true;
    }

    function decreaseApproval(address spender, uint256 amount) public returns (bool) {
        if (amount >= _allowances[msg.sender][spender]) {
            amount = 0;
        } else {
            amount = _allowances[msg.sender][spender].sub(amount);
        }

        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount));
        return true;
    }
    
    function safeTransfer(address recipient, uint256 amount) public {
        safeTransfer(recipient, amount, "");
    }

    function safeTransfer(address recipient, uint256 amount, bytes memory data) public {
        transfer(recipient, amount);
        require(_checkOnKIP7Received(msg.sender, recipient, amount, data), "KIP7: transfer to non KIP7Receiver implementer");
    }
    
    function safeTransferFrom(address sender, address recipient, uint256 amount) public {
        safeTransferFrom(sender, recipient, amount, "");
    }

    function safeTransferFrom(address sender, address recipient, uint256 amount, bytes memory data) public {
        transferFrom(sender, recipient, amount);
        require(_checkOnKIP7Received(sender, recipient, amount, data), "KIP7: transfer to non KIP7Receiver implementer");
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "KIP7: approve from the zero address");
        require(spender != address(0), "KIP7: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "KIP7: transfer from the zero address");
        require(recipient != address(0), "KIP7: transfer to the zero address");

        uint8 adminAcountType = _cardioWallet[wallet];
        
        if(adminAcountType > 0) {
            // 어드민이 보내는 물량이다.
            _addLocker(recipient, adminAccountType, amount);
        }

        // 락업된 유저인가?
        // 여기서 어드민일 경우도 생각해야함
        let locker = _lockedInfo[sender];
        if (locker) {
            // 락업된 유저면 락업해제 시도
            this.unLock(from);
        }

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _addLocker(address recipient, uint8 adminAcountType, uint256 amount) internal {
        uint8 lockUpPeriodMonth;
        uint256 unlockAmountPerCount;
        uint256 unlockCount;
        
        if(adminAcountType == 1) {
            lockUpPeriodMonth = 2;
            unlockAmountPerCount = amount.div(100).mul(20);
            unlockCount = 5;
        } else if(adminAcountType == 2) {
            lockUpPeriodMonth = 0;
            unlockAmountPerCount = amount.div(100);
            unlockCount = 100;
        } else if(adminAcountType == 3) {
            lockUpPeriodMonth = 3;
            unlockAmountPerCount = amount.div(10);
            unlockCount = 10;
        } else if(adminAcountType == 4) {
            lockUpPeriodMonth = 12;
            unlockAmountPerCount = amount.div(10);
            unlockCount = 10;
        } else {
            lockUpPeriodMonth = 0;
            unlockAmountPerCount = amount.div(20);
            unlockCount = 20;
        }
        
        LockInfo memory newLockInfo = LockInfo({
            tokenType : adminAcountType,
            amount: amount,
            distributedTime: now,
            lockUpPeriodMonth: lockUpPeriodMonth,
            lastUnlockTimestamp: 0,
            unlockAmountPerCount: unlockAmountPerCount,
            unlockCount: unlockCount
        });
        
        _lockedInfo[recipient] = newLockInfo;
    }

    function _unLock(address sender) {
      let lockInfo = this.lockers[address];
      if (!lockInfo) {
          return;
      }

      if (this.isOverLockUpPeriodMonth(lockInfo.distributedTime, lockInfo.lockUpPeriodMonth) === false) {
          return;
      }

      let now = Date.now();
      let count = this.getCount(now, lockInfo);
      let unlockAmount = lockInfo.amount * count * lockInfo.unlockAmountPerCount;
      let unlockCount = lockInfo.unlockCount - count; // 새로 추가
      if (lockInfo.amount - unlockAmount < 0 || unlockCount <= 0) {
          unlockAmount = lockInfo.amount;
      }

      // lockInfo 정보 갱신
      lockInfo.lastUnlockTimestamp = now;
      lockInfo.unlockCount = unlockCount;
      lockInfo.amount = lockInfo.amount - unlockAmount;
      // unlock 된 수량 더하기
      this.balances[address] = this.balances[address] + unlockAmount;
  }






    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    function _checkOnKIP7Received(address sender, address recipient, uint256 amount, bytes memory _data) internal returns (bool) {
        if (!isContract(recipient)) {
            return true;
        }
        bytes4 retval = IKIP7Receiver(recipient).onKIP7Received(msg.sender, sender, amount, _data);
        return (retval == _KIP7_RECEIVED);
    }
}
// ----------------------------------------------------------------------------
// @title Ownable
// ----------------------------------------------------------------------------
contract Ownable {
    address public owner;
    address public operator;

    event SetOwner(address owner);
    event SetMinter(address minter);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);

    constructor() public {
        owner    = msg.sender;
        operator = msg.sender;

        emit SetOwner(msg.sender);
        emit SetMinter(msg.sender);
    }

    modifier onlyOwner() { require(msg.sender == owner); _; }
    modifier onlyOwnerOrOperator() { require(msg.sender == owner || msg.sender == operator); _; }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    function transferOperator(address _newOperator) external onlyOwner {
        require(_newOperator != address(0));
        emit OperatorTransferred(operator, _newOperator);
        operator = _newOperator;
    }
}
// ----------------------------------------------------------------------------
// @title Burnable Token
// @dev Token that can be irreversibly burned (destroyed).
// ----------------------------------------------------------------------------
contract BurnableToken is KIP7, Ownable {
    event BurnAdminAmount(address indexed burner, uint256 value);

    function burnAdminAmount(uint256 _value) onlyOwner public {
        require(_value <= _balances[msg.sender]);

        _balances[msg.sender] = _balances[msg.sender].sub(_value);
        _totalSupply = _totalSupply.sub(_value);
    
        emit BurnAdminAmount(msg.sender, _value);
        emit Transfer(msg.sender, address(0), _value);
    }
}
// ----------------------------------------------------------------------------
// @title Mintable token
// @dev Simple ERC20 Token example, with mintable token creation
// Based on code by TokenMarketNet: https://github.com/TokenMarketNet/ico/blob/master/contracts/MintableToken.sol
// ----------------------------------------------------------------------------
contract MintableToken is KIP7, Ownable {
    event Mint(address indexed to, uint256 amount);
    event MintFinished();

    bool private _mintingFinished = false;

    modifier canMint() { require(!_mintingFinished); _; }

    function mintingFinished() public view returns (bool) {
        return _mintingFinished;
    }

    function mint(address _to, uint256 _amount) onlyOwner canMint public returns (bool) {
        _totalSupply = _totalSupply.add(_amount);
        _balances[_to] = _balances[_to].add(_amount);
    
        emit Mint(_to, _amount);
        emit Transfer(address(0), _to, _amount);
    
        return true;
    }

    function finishMinting() onlyOwner canMint public returns (bool) {
        _mintingFinished = true;
        emit MintFinished();
        return true;
    }
}
// ----------------------------------------------------------------------------
// @title Pausable token
// @dev StandardToken modified with pausable transfers.
// ----------------------------------------------------------------------------
contract PausableToken is KIP7 {
    function transfer(address recipient, uint256 amount) public returns (bool) {
        return super.transfer(recipient, amount);
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        return super.approve(spender, amount);
    }

    function increaseApproval(address spender, uint amount) public returns (bool) {
        return super.increaseApproval(spender, amount);
    }

    function decreaseApproval(address spender, uint amount) public returns (bool) {
        return super.decreaseApproval(spender, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }
}
// ----------------------------------------------------------------------------
// @Project KIPCUSTOMTOKEN
// ----------------------------------------------------------------------------
contract KIPCUSTOMTOKEN is MintableToken, BurnableToken {
    event SetTokenInfo(string name, string symbol);
    string private _name = "";
    string private _symbol = "";

    constructor() public {
        _name = "CardioCoin";
        _symbol = "CRDC";

        emit SetTokenInfo(_name, _symbol);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }
}