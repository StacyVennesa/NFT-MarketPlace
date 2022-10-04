// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NFTCollection.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFTMarketplace {
  using Counters for Counters.Counter;

  Counters.Counter public sellerCount;
  Counters.Counter public offerCount;

  mapping (uint => Offer) public offers;
  mapping(uint => Seller) public sellers;
  mapping (address => uint) public userFunds;

  NFTCollection nftCollection;

  struct Offer{
    uint offerId;
    uint id;
    address user;
    uint price;
    bool fulfilled;
    bool cancelled;
  }

  struct Seller {
    address userAddress;
    uint balance;
  }

  event offer(
    uint offerId,
    uint id,
    address user,
    uint price,
    bool fulfilled,
    bool cancelled
  );

  event OfferFilled(uint offerId, uint id, address newOwner);
  event OfferCancelled(uint offerId, uint id, address owner);
  event ClaimFunds(address user, uint amount);

  constructor(address _nftCollection) {
    nftCollection = NFTCollection(_nftCollection);
  }

  modifier offers_invariants(uint _offerId) {
    // modifier to assert that certain invariants concerning offers hold
    require(offers[_offerId].offerId == _offerId, "ensures an offer exists");
    require(offers[_offerId].fulfilled == false, "ensures that an offer has not yet been fulfiled");
    require(offers[_offerId].cancelled == false, "ensures that an offer has not been cancelled");
    _;  
  }

  modifier onlyOwner(uint _offerId){
    require(offers[_offerId].user == msg.sender, 'The offer can only be canceled by the owner');
    _;
  }

  function makeOffer(uint _id, uint _price) public returns (address){
    // ensures the caller has ownership of the nft
    require(nftCollection.ownerOf(_id) == msg.sender, "you do not own the nft you are trying to offer");
    nftCollection.transferFrom(msg.sender, address(this), _id);
    offers[offerCount.current()] = Offer(offerCount.current(), _id, msg.sender, _price, false, false);
    offerCount.increment();
    emit offer(offerCount.current(), _id, msg.sender, _price, false, false);

    return (msg.sender);
  }


  function fillOffer(uint _offerId) offers_invariants(_offerId) public payable {
    Offer storage _offer = offers[_offerId];
    require(_offer.user != msg.sender, 'The owner of the offer cannot fill it');
    require(msg.value == _offer.price, 'The Celo amount should match with the NFT Price');
    nftCollection.transferFrom(address(this), msg.sender, _offer.id);
    _offer.fulfilled = true;
    userFunds[_offer.user] += msg.value;
    sellers[sellerCount.current()].userAddress = _offer.user;
    sellers[sellerCount.current()].balance = msg.value;
    nftCollection.setTrack(msg.sender, _offer.id);
    sellerCount.increment();
    emit OfferFilled(_offerId, _offer.id, msg.sender);
  }

  function changeOfferPrice(uint _offerId, uint _price) offers_invariants(_offerId) onlyOwner(_offerId) public{
    offers[_offerId].price = _price;
  }

  function cancelOffer(uint _offerId) offers_invariants(_offerId) onlyOwner(_offerId) public {
    Offer storage _offer = offers[_offerId];
    nftCollection.transferFrom(address(this), msg.sender, _offer.id);
    _offer.cancelled = true;
    emit OfferCancelled(_offerId, _offer.id, msg.sender);
  }

  function claimFunds() public {
    require(userFunds[msg.sender] > 0, 'This user has no funds to be claimed');
    payable(msg.sender).transfer(userFunds[msg.sender]);
    emit ClaimFunds(msg.sender, userFunds[msg.sender]);
    userFunds[msg.sender] = 0;
  }

  function getSellers() public view returns (address[] memory, uint[] memory){
       address[] memory userAddress = new address[](sellerCount.current());
       uint[] memory balances = new uint[](sellerCount.current());

       for(uint i = 0; i < sellerCount.current(); i++){
           userAddress[i] = sellers[i].userAddress;
           balances[i] = sellers[i].balance;
       }
       return (userAddress, balances);
   }

  // Fallback: reverts if Celo is sent to this smart-contract by mistake
  fallback () external {
    revert();
  }
}
