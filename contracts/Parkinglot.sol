pragma solidity >=0.4.22 <0.6.0;

import "./SafeMath.sol";

contract Parkinglot {
    using SafeMath for uint;
    struct Checkpoint {
        uint128 fromBlock;
        uint128 value;
  	}

    address parkedCar;      // Address of the currently parked car
    uint256 arrivaltime;    // Time when the currently parked car started parking
    bool inUse;             // Indicate whether lot is currently available or in use
    uint256 pricepersec;    // Cost for parking is calculated in seconds * pricepersec
    string public tokenName;// Name of the parkinglot

    mapping (address => Checkpoint[]) public balances;
    mapping (address => mapping (address => uint256)) public allowanceTo;
    // rewards are the accumulated incomes, which token holders can withdraw
    mapping (address => uint) public rewards;

    /* When income arrives it is not directly added to the rewards of the token
    holders, beause this would potentially cost tons of gas. Therefore incomes
    are tracked and each user can cash his rewards asychroneously, when he wants
    it. This means, he only pays gas for handling incomes which are relevant to
    him. */
    Checkpoint[] public incomes;
    mapping (address => uint) internal incomesApplied;

    Checkpoint[] internal totalSupplyHistory;

    /// @notice Creates new Parkinglot with _name and assigns the totalSupply of tokens to the creator
    /// @param _name The name of the parkinglot
    /// @param _totalSupply The number of tokens to be generated
    /// @param _pricepersec The price per second which cars need to pay for parking on this lot
    constructor(string memory _name, uint _totalSupply, uint256 _pricepersec) public {
      tokenName = _name;
      lot_owner = tx.origin;
        pricepersec = _pricepersec;
      generateTokens(msg.sender, _totalSupply);
    }

    /// @notice Car starts parking
    /// @return True if everything went fine.
    function setArrival() public returns (bool) {
        require(!inUse);
        require(msg.sender.balance>600, "Insufficient funding");
        inUse = true;
        parkedCar = msg.sender;
        arrivaltime = now;
        return true;
    }

    /* Note:
      I removed this function because we dont have a classic owner anymore, but
      rather many token holders. Implementing a voting mechanism for all kinds
      of desicions is probably overkill. pricepersec will stay static.
    function setPricepersec(bytes32 _lot, uint _pps) public {
        require(parkinglots[_lot].inUse == false, "Parking lot currently in use!");
        require(parkinglots[_lot].lot_owner == msg.sender, "Ownership invalid!");
        parkinglots[_lot].pricepersec = _pps;
    }
    */

    /// @notice Payments are forwarded to the pay function
    function () external payable {
      revert();
    }

    /// @notice Pay for parking fees. Value is stored for token holders to claim.
    function pay() public payable returns (bool) {
      require(msg.sender == parkedCar, "Wrong ownership!");
      uint parkingPrice = (block.timestamp - arrivaltime) * pricepersec;
      require(msg.value >= parkingPrice);
      updateValueAtNow(incomes, parkingPrice.div(totalSupply()));
      msg.sender.transfer(msg.value - parkingPrice);
      parkedCar = address(0);
      inUse = false;
      return true;
    }

    /// @notice Incomes are applied for the specified address.
    ///         This is a necessary step before being able to withdraw money.
    /// @param _for The address for which incomes are applied.
    function applyIncomes(address _for) public {
        if (incomesApplied[_for] != incomes.length-1) {
            uint incomesAppliedHelper;
            incomesApplied[_for] = incomes.length-1;
            uint trxValue;
            for (uint i = incomesAppliedHelper; i < incomes.length; i++) {
                trxValue = trxValue.add(uint(incomes[i].value).mul(getValueAt(balances[_for], incomes[i].fromBlock)));
            }
            rewards[_for] = rewards[_for].add(trxValue);
        }
    }

    /// @notice Allows anyone to withdraw stored value from contract.
    /// @param amount how much should be withdrawn in Wei
    function withdraw(uint amount) public {
        applyIncomes();
        require(rewards[msg.sender] > amount);
        rewards[msg.sender] = rewards[msg.sender].sub(amount);
        msg.sender.send(amount);
    }

    /// @notice Token transfer method
    /// @param _to Send tokens to that address
    /// @param _value Transfer this many tokens
    function transfer(address _to, uint _value) public returns (bool success) {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    /// @notice Allow someone else to spend the msg.senders tokens
    /// @param _spender The person who will be allowed to spend the msg.senders tokens
    /// @param _value How many coins the _spender is allowed to spend in the name of the msg.sender
    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowanceTo[msg.sender][_spender] = _value;
        return true;
    }

    /// @notice Query the current allowance from the specified _owner to the _spender
    /// @param _owner Person who gave the allowance.
    /// @param _spender Person who is allowed to spend some of the _owners tokens
    /// @return The amount _spender is allowed to spend from _owner
    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowanceTo[_owner][_spender];
    }

    /// @notice Queries the balance of `_owner`
    /// @param _owner The address from which the balance will be retrieved
    /// @return The balance of _owner
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balanceOfAt(_owner, block.number);
    }

    /// @notice Queries the current totalSupply of tokens
    /// @return The current totalSupply of tokens
    function totalSupply() public view returns (uint256 _totalSupply) {
        return totalSupplyAt(block.number);
    }

    /// @notice Spend coins from another address (through allowance)
    /// @param _from The address which is currently holding the coins and gave an allowance to the msg.sender
    /// @param _to The target address for the transfer
    /// @param _value The number tokens to be send
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_value <= allowanceTo[_from][msg.sender]);     // Check allowance

        allowanceTo[_from][msg.sender] = allowanceTo[_from][msg.sender].sub(_value);
        _transfer(_from, _to, _value);
        return true;
    }

    /// @notice Internal token transfer method
    /// @param _from Current token holders
    /// @param _to Target of transaction
    /// @param _value Amount of tokens to be transferred
    function _transfer(address _from, address _to, uint _value) internal {
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_to != address(0x0));
        // Check if the sender has enough
        uint previousBalanceFrom = balanceOfAt(_from, block.number);
        require(previousBalanceFrom >= _value);
        // Save this for an assertion in the future
        uint previousBalances = balanceOfAt(_from, block.number).add(balanceOfAt(_to,block.number));
        // Subtract from the sender
        updateValueAtNow(balances[_from], previousBalanceFrom.sub(_value));
        // Add the same to the recipient
        uint previousBalanceTo = balanceOfAt(_to, block.number);
        updateValueAtNow(balances[_to], previousBalanceTo.add(_value));
        // Asserts are used to use static analysis to find bugs in your code. They should never fail
        assert(balanceOf(_from) + balanceOf(_to) == previousBalances);
    }

    /// @dev Queries the balance of `_owner` at a specific `_blockNumber`
    /// @param _owner The address from which the balance will be retrieved
    /// @param _blockNumber The block number when the balance is queried
    /// @return The balance at `_blockNumber`
    function balanceOfAt(address _owner, uint _blockNumber) public view returns (uint) {
        // This will return the expected balance during normal situations
        return getValueAt(balances[_owner], _blockNumber);
    }

    /// @notice Total amount of tokens at a specific `_blockNumber`.
    /// @param _blockNumber The block number when the totalSupply is queried
    /// @return The total amount of tokens at `_blockNumber`
    function totalSupplyAt(uint _blockNumber) public view returns(uint) {
        // This will return the expected totalSupply during normal situations
        return getValueAt(totalSupplyHistory, _blockNumber);
    }

    /// @dev `getValueAt` retrieves the number of tokens at a given block number
    /// @param checkpoints The history of values being queried
    /// @param _block The block number to retrieve the value at
    /// @return The number of tokens being queried
    function getValueAt(Checkpoint[] storage checkpoints, uint _block) internal view returns (uint) {
        if (checkpoints.length == 0)
            return 0;

        // Shortcut for the actual value
        if (_block >= checkpoints[checkpoints.length-1].fromBlock)
            return checkpoints[checkpoints.length-1].value;
        if (_block < checkpoints[0].fromBlock)
            return 0;

        // Binary search of the value in the array
        uint min = 0;
        uint max = checkpoints.length-1;
        while (max > min) {
            uint mid = (max + min + 1) / 2;
            if (checkpoints[mid].fromBlock<=_block) {
                min = mid;
            } else {
                max = mid-1;
            }
        }
        return checkpoints[min].value;
    }

    /// @notice Generates `_amount` tokens that are assigned to `_owner`
    /// @param _owner The address that will be assigned the new tokens
    /// @param _amount The quantity of tokens generated
    /// @return True if the tokens are generated correctly
    function generateTokens(address _owner, uint _amount) internal returns (bool) {
        uint curTotalSupply = totalSupply();
        require(curTotalSupply + _amount >= curTotalSupply); // Check for overflow
        uint previousBalanceTo = balanceOf(_owner);
        require(previousBalanceTo + _amount >= previousBalanceTo); // Check for overflow
        updateValueAtNow(totalSupplyHistory, curTotalSupply + _amount);
        updateValueAtNow(balances[_owner], previousBalanceTo + _amount);
        return true;
    }

    /// @dev `updateValueAtNow` used to update the `balances` map and the
    ///  `totalSupplyHistory`
    /// @param checkpoints The history of data being updated
    /// @param _value The new number of tokens
    function updateValueAtNow(Checkpoint[] storage checkpoints, uint _value) internal {
        if ((checkpoints.length == 0) || (checkpoints[checkpoints.length - 1].fromBlock < block.number)) {
            Checkpoint storage newCheckPoint = checkpoints[checkpoints.length++];
            newCheckPoint.fromBlock = uint128(block.number);
            newCheckPoint.value = uint128(_value);
        } else {
            Checkpoint storage oldCheckPoint = checkpoints[checkpoints.length - 1];
            oldCheckPoint.value = uint128(_value);
        }
    }

}
