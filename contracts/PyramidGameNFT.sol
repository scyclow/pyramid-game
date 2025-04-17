// SPDX-License-Identifier: MIT


import "./Dependencies.sol";
import "hardhat/console.sol";

pragma solidity ^0.8.28;

contract PyramidGameNFT is ERC20 {
  uint8 constant public SLOTS = 12;
  uint8 constant public INVALID_SLOT = SLOTS + 1;

  uint256 constant public TOKENS_PER_ETH = 100000;

  PyramidGameLeaders public leaders;

  event Contribution(address indexed sender, uint256 amount);
  event Distribution(address indexed recipient, uint256 amount);

  constructor() ERC20("Pyramid Game Contributions", "PYRAMID") {
    leaders = new PyramidGameLeaders(msg.sender, SLOTS);
  }

  receive () external payable {
    _contribute();
  }

  function contribute() external payable {
    _contribute();
  }


  function _contribute() private ignoreReentry {
    uint8 senderIsLeaderTokenId = _distribute(msg.value);

    if (senderIsLeaderTokenId != INVALID_SLOT) {
      leaders.incrementContribution(uint256(senderIsLeaderTokenId), msg.value);
    } else {
      _reCache(msg.sender, msg.value);
    }

    emit Contribution(msg.sender, msg.value);

  }

  function claimLeadership() external {
    _reCache(msg.sender, 0);
  }



  function _distribute(uint256 amount) private returns (uint8) {
    uint256 sum = leaders.contributionTotal();

    uint8 senderIsLeaderTokenId = INVALID_SLOT;

    for (uint8 ix; ix < SLOTS; ix++) {
      if (!leaders.exists(ix)) return senderIsLeaderTokenId;
      if (leaders.ownerOf(ix) == msg.sender) {
        senderIsLeaderTokenId = ix;
      }

      uint256 amountToTransfer = (amount * leaders.contributions(ix)) / sum;
      address recipient = leaders.recipientOf(ix);



      bool distributionMade =  _safeTransferETH(recipient, amountToTransfer);

      if (distributionMade) {
        emit Distribution(recipient, amountToTransfer);
      }
    }

    return senderIsLeaderTokenId;
  }

  function _reCache(address contributor, uint256 contributionAmount) private {
    if (leaders.totalSupply() < SLOTS) {
      leaders.mint(contributor, contributionAmount);
    } else {
      (uint256 tokenId, uint256 leaderAmount) = leaders.lowestLeader();
      uint256 senderContributions = contributions(contributor) + contributionAmount;
      if (senderContributions > leaderAmount) {
        _replaceLowestLeader(tokenId, contributor, leaderAmount, senderContributions);
      } else {
        _mint(contributor, contributionAmount * TOKENS_PER_ETH);
      }
    }
  }

  function _replaceLowestLeader(uint256 tokenId, address contributor, uint256 leaderAmount, uint256 senderContributions) private {
    _mint(leaders.ownerOf(tokenId), leaderAmount * TOKENS_PER_ETH);
    leaders.reorg(tokenId, contributor, senderContributions - leaderAmount);
    _burn(contributor, balanceOf(contributor));
  }

  function addToLeaderContributions(uint256 tokenId, uint256 tokenAmount) external {
    _burn(msg.sender, tokenAmount);
    leaders.incrementContribution(tokenId, tokenAmount / TOKENS_PER_ETH);

  }

  function contributions(address contributor) public view returns (uint256) {
    return balanceOf(contributor) / TOKENS_PER_ETH;
  }


  /**
   * @notice Transfer ETH and return the success status.
   * @dev This function only forwards 30,000 gas to the callee.
   */
  function _safeTransferETH(address to, uint256 value) internal returns (bool) {
    (bool success, ) = to.call{ value: value, gas: 60_000 }(new bytes(0));
    return success;
  }



  bool transient locked;
  modifier ignoreReentry {
    if (locked) return;
    locked = true;
    _;
    locked = false;
  }

}


contract PyramidGameLeaders is ERC721 {
  address public root;
  uint256 public contributionTotal;
  uint256 public totalSupply = 1;
  uint256 public SLOTS;

  mapping(uint256 => uint256) public contributions;
  mapping(uint256 => address) public recipientOf;

  constructor(address deployer, uint256 slots) ERC721("Pyramid Game Leaders", "PYRAMID"){
    root = msg.sender;
    SLOTS = slots;

    _mint(deployer, 0);
    incrementContribution(0, 0.01 ether);
  }

  function exists(uint256 tokenId) external view returns (bool) {
    return _exists(tokenId);
  }

  modifier onlyRoot {
    require(msg.sender == root);
    _;
  }

  function incrementContribution(uint256 tokenId, uint256 incrementAmount) public onlyRoot {
    contributions[tokenId] += incrementAmount;
    contributionTotal += incrementAmount;
    emit MetadataUpdate(tokenId);
  }

  function mint(address recipient, uint256 incrementAmount) external onlyRoot {
    require(totalSupply < SLOTS);
    _mint(recipient, totalSupply);
    incrementContribution(totalSupply, incrementAmount);
    totalSupply += 1;
  }

  function reorg(uint256 tokenId, address recipient, uint256 incrementAmount) external onlyRoot {
    incrementContribution(tokenId, incrementAmount);
    _transfer(ownerOf(tokenId), recipient, tokenId);
  }


  function lowestLeader() external view returns (uint256, uint256) {
    uint256 lowestLeaderIx = 0;
    uint256 lowestLeaderAmount = contributions[0];


    for (uint256 ix = 1; ix < SLOTS; ix++) {
      if (contributions[ix] < lowestLeaderAmount) {
        lowestLeaderIx = ix;
        lowestLeaderAmount = contributions[lowestLeaderIx];
      }
    }

    return (lowestLeaderIx, lowestLeaderAmount);
  }


  function setRecipient(uint256 tokenId, address recipient) external {
    require(ownerOf(tokenId) == msg.sender);
    recipientOf[tokenId] = recipient;
  }


  function _beforeTokenTransfer(address, address to, uint256 tokenId) internal virtual override {
    recipientOf[tokenId] = to;
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    return 'TODO';
  }


  event MetadataUpdate(uint256 _tokenId);
  event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721) returns (bool) {
    // ERC2981 & ERC4906
    return interfaceId == bytes4(0x2a55205a) || interfaceId == bytes4(0x49064906) || super.supportsInterface(interfaceId);
  }
}