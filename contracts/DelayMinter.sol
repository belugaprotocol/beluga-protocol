pragma solidity 0.5.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "./Governable.sol";
import "./interfaces/IBeluga.sol";

/*
*   This contract is to ensure our users will not get exit-scammed
*   while retaining the possibility of providing new rewards.
*
*   The governance has to announce the minting first and wait for the
*   `duration`. Only after that `duration` is passed, can the governance
*   create new rewards.
*
*   The usage of this contract itself does not mean it is free from exit-scam.
*   Thus we provide some guidance for the user on how to check.
*
*   User due diligence guide:
*     [1] DelayMinter has to be the owner of BELUGA
*
*     [2] The duration of all DelayMinters should be set to a reasonable time.
*         The numbers reported are in seconds.
*
*
*   Only then, the users are free from exit scams.
*
*/

contract DelayMinter is Governable {
  using SafeMath for uint256;

  struct MintingAnnouncement{
    address target;
    uint256 amount;
    uint256 timeToMint;
  }

  address public token;
  uint256 public delay;

  uint256 public nextId;

  // Announcements[_id] returns Minting announcement struct
  mapping (uint256 => MintingAnnouncement) announcements;

  event MintingAnnounced(uint256 id, address target, uint256 _amount, uint256 timeActive);

  event CancelMinting(uint256 id);

  constructor(address _storage, address _token, uint256 _delay)
  Governable(_storage) public {
    token = _token;
    require(token != address(0), "DelayMinter: Token not set");
    delay = _delay;
    require(delay != 0, "DelayMinter: Delay not set");
    nextId = 0;
  }

  // Mints tokens to the target
  function announceMint(address _target, uint256 _amount) public onlyGovernance {
    require(_target != address(0), "DelayMinter: Target cannot be 0x0 address");
    require(_amount != 0, "DelayMinter: Amount should be greater than 0");

    uint256 timeToMint = block.timestamp + delay;
    // Set the new minting announcement
    announcements[nextId] = MintingAnnouncement(
      _target,
      _amount,
      timeToMint
    );
    emit MintingAnnounced(nextId, _target, _amount, timeToMint);
    // Overflow is unlikely to happen
    // furthermore, we can reuse the id even if it overflowed.
    nextId++;
  }

  // Governance can only mint if it is already announced and the delay has passed
  function executeMint(uint256 _id) public onlyGovernance {
    address target = announcements[_id].target;
    uint256 amount = announcements[_id].amount; // now this is the total amount

    require(target != address(0), "Delay Minter: Minting needs to be first announced");
    require(amount != 0, "Delay Minter: Amount should be greater than 0");
    require(block.timestamp >= announcements[_id].timeToMint, "Delay Minter: Cannot mint yet");

    IBeluga(token).mint(target, amount);

    // Clear out so that it prevents governance from reusing the announcement
    // it also saves gas and we can reuse the announcements even if the id overflowed
    delete announcements[_id];
  }

  function cancelMint(uint256 _id) public onlyGovernance {
    require(announcements[_id].target != address(0), "Delay Minter: Minting needs to be first announced");
    require(announcements[_id].amount != 0, "Delay Minter: Amount should be greater than 0");
    delete announcements[_id];
    emit CancelMinting(_id);
  }

  // Allows for the minting keys to be burnt, this should be performed
  // as soon as 5m BELUGA is minted in as per BLIP 1.
  function renounceMinting() public onlyGovernance {
    IBeluga(token).renounceOwnership();
  }
}