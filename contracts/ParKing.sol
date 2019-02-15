pragma solidity >=0.4.22 <0.6.0;

contract ParKing {

    struct Parkinglot {
        address car; //vom parkenden Auto
        address payable lot_owner;
        uint256 arrivaltime;
        bool inUse;
        uint256 pricepersec;
    }

    mapping(bytes32 => Parkinglot) public parkinglots;
    bytes32[] public userAddresses;

    function setOwnership(bytes32 _lot, address payable _owner) public {
        require(parkinglots[_lot].lot_owner == address(0) || parkinglots[_lot].lot_owner == msg.sender, "Ownership invalid!");
        parkinglots[_lot].lot_owner = _owner;
    }

    function setPricepersec(bytes32 _lot, uint _pps) public {
        require(parkinglots[_lot].inUse == false, "Parking lot currently in use!");
        require(parkinglots[_lot].lot_owner == msg.sender, "Ownership invalid!");
        parkinglots[_lot].pricepersec = _pps;
    }

    function setArrival(bytes32 _lot, address _car) public {
        require(_car.balance>600, "Insufficient funding");
        parkinglots[_lot].car = _car;
        parkinglots[_lot].arrivaltime = now;
    }

    function setDeparture(bytes32 _lot) public payable { //only then the poller goes down
        require(msg.sender == parkinglots[_lot].car, "Wrong ownership!");
        require(msg.value >= (block.timestamp - parkinglots[_lot].arrivaltime) * parkinglots[_lot].pricepersec);
        parkinglots[_lot].lot_owner.transfer(block.timestamp - parkinglots[_lot].arrivaltime * parkinglots[_lot].pricepersec);
    }
    
}