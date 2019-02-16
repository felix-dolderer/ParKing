pragma solidity >=0.4.22 <0.6.0;

/* TODO Liste:
 * Tokenization für Parkplatz.
 */

import "./ParKing.sol";

contract Car {

  struct Proposal {
    address payable to;
    uint amount;
    uint8 approvals;
    bool denied;
  }

  ParKing parking;
  address car_owner;
  Proposal prop;

  constructor (address _parking) public {
    parking = Parking(_parking);
  }

  function spend (address payable _to, uint256 _amount) public {
    if (msg.sender == _to && msg.sender == address(parking))) {
      _to.send(_amount);
      resetProposal();
      return;
    } else {
      prop.to = _to;
      prop.amount = _amount;
    }
  }

  function resetProposal () internal {
    prop.to = address(0);
    prop.amount = 0;
    prop.approvals = 0;
    prop.denied = false;
  }

  function voteProposal (bool _vote) public {
    require(!denied);

    address lot_owner = parking.parkedCars[address(this)].lot_owner;

    if(msg.sender == car_owner) {
      if (_vote){
        uint8 newApprovals = prop.approvals + 2;
        require(newApprovals > prop.approvals);
        prop.approvals += 2;
      } else {
        prop.denied = true;
      }

    } else if(msg.sender == lot_owner) {
      if (_vote) {
        uint8 newApprovals = prop.approvals + 3;
        require(newApprovals > prop.approvals);
        prop.approvals += 3;
      } else {
        prop.denied = true;
      }
    }

    if (prop.approvals == 5) {
      address payable propTo = prop.to;
      uint propAmount = propAmount;
      resetProposal();
      propTo.send(propAmount);
    }
  }
}
