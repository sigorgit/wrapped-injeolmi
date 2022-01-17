pragma solidity ^0.5.6;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be aplied to your functions to restrict their use to
 * the owner.
 */
contract Ownable {
    address payable private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address payable) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * > Note: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address payable newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address payable newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IInjeolmiSender {

    event SetSigner(address indexed signer);
    event SendOverHorizon(address indexed sender, uint256 indexed toChain, address indexed receiver, uint256 sendId, uint256 amount);
    event ReceiveOverHorizon(address indexed receiver, uint256 indexed fromChain, address indexed sender, uint256 sendId, uint256 amount);

    function signer() external view returns (address);
    function sendOverHorizon(uint256 toChain, address receiver, uint256 amount) external returns (uint256 sendId);
    function sended(address sender, uint256 toChain, address receiver, uint256 sendId) external view returns (uint256 amount);
    function sendCount(address sender, uint256 toChain, address receiver) external view returns (uint256);
    function receiveOverHorizon(uint256 fromChain, address sender, uint256 sendId, uint256 amount, bytes calldata signature) external;
    function received(address receiver, uint256 fromChain, address sender, uint256 sendId) external view returns (bool);
}

interface IInjeolmi {

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract InjeolmiSender is Ownable, IInjeolmiSender {

    IInjeolmi public injeolmi;
    address public signer;

    mapping(address => mapping(uint256 => mapping(address => uint256[]))) public sended;
    mapping(address => mapping(uint256 => mapping(address => mapping(uint256 => bool)))) public received;

    constructor(IInjeolmi _injeolmi, address _signer) public {
        injeolmi = _injeolmi;
        signer = _signer;
    }

    function setSigner(address _signer) onlyOwner external {
        signer = _signer;
        emit SetSigner(_signer);
    }

    function sendOverHorizon(uint256 toChain, address receiver, uint256 amount) public returns (uint256) {
        injeolmi.transferFrom(msg.sender, address(this), amount);
        
        uint256[] storage sendedAmounts = sended[msg.sender][toChain][receiver];
        uint256 sendId = sendedAmounts.length;
        sendedAmounts.push(amount);
        
        emit SendOverHorizon(msg.sender, toChain, receiver, sendId, amount);
        return sendId;
    }

    function sendCount(address sender, uint256 toChain, address receiver) external view returns (uint256) {
        return sended[sender][toChain][receiver].length;
    }

    function receiveOverHorizon(uint256 fromChain, address sender, uint256 sendId, uint256 amount, bytes memory signature) public {

        require(signature.length == 65, "invalid signature length");
        require(!received[msg.sender][fromChain][sender][sendId]);

        uint256 toChain = 8217;
        bytes32 hash = keccak256(abi.encodePacked(msg.sender, fromChain, toChain, sender, sendId, amount));
        bytes32 message = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        require(
            uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0,
            "invalid signature 's' value"
        );
        require(v == 27 || v == 28, "invalid signature 'v' value");

        require(ecrecover(message, v, r, s) == signer);

        injeolmi.transfer(msg.sender, amount);

        received[msg.sender][fromChain][sender][sendId] = true;
        emit ReceiveOverHorizon(msg.sender, fromChain, sender, sendId, amount);
    }
}