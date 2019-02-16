pragma solidity >=0.4.22 <0.6.0;

import "./Parkinglot.sol";

contract ParKing {

    mapping(bytes32 => Parkinglot) public parkinglots;
    mapping(address => Parkinglot) public parkedCars;

    function createLot(bytes32 _lot, uint256 _pricepersec) {
      parkinglots[_log] = new Parkinglot(_pricepersec);
    }

    function setArrival(bytes32 _lot) {
      require(parkinglots[_lot].setArrival());
      parkedCars[msg.sender] = parkinglots[_lot];
    }

    function setDeparture(bytes32 _lot) public payable { //only then the poller goes down
      require(parkinglots[_lot].pay.value(msg.value));
      parkedCars[msg.sender] = address(0);
    }

}
