// SPDX-License-Identifier: MIT


import "./Dependencies.sol";
import "hardhat/console.sol";

pragma solidity ^0.8.28;

contract PyramidGameNFT is ERC20 {
  uint8 constant public SLOTS = 12;
  uint8 constant public INVALID_SLOT = SLOTS + 1;

  uint256 constant public TOKENS_PER_ETH = 100_000;

  PyramidGameLeaders public leaders;

  event Contribution(address indexed sender, uint256 amount);
  event Distribution(address indexed recipient, uint256 amount);

  constructor() ERC20("Pyramid Game Contribution Coin", "PYRAMID") {
    leaders = new PyramidGameLeaders(msg.sender, SLOTS);
  }

  receive () external payable {
    _contribute();
  }

  function contribute() external payable {
    _contribute();
  }

  function claimLeadership() external {
    _reorg(msg.sender, 0);
  }


  function addToLeaderContributions(uint256 tokenId, uint256 tokenAmount) external {
    _burn(msg.sender, tokenAmount);
    leaders.incrementContribution(tokenId, tokenAmount / TOKENS_PER_ETH);
  }

  function contributions(address contributor) public view returns (uint256) {
    return balanceOf(contributor) / TOKENS_PER_ETH;
  }


  /// @dev Force a distribution if the contract accrues a balance. This may occur if
  /// distributions are directly or indirectly forwarded back to the contract.
  function forceDistribution() external ignoreReentry {
    _distribute(address(this).balance);
  }


  function _contribute() internal ignoreReentry {
    uint8 senderIsLeaderTokenId = _distribute(msg.value);

    if (senderIsLeaderTokenId != INVALID_SLOT) {
      leaders.incrementContribution(uint256(senderIsLeaderTokenId), msg.value);
    } else {
      _reorg(msg.sender, msg.value);
    }

    emit Contribution(msg.sender, msg.value);
  }



  function _distribute(uint256 amount) internal returns (uint8) {
    uint256 sum = leaders.contributionTotal();

    uint8 senderIsLeaderTokenId = INVALID_SLOT;

    for (uint8 ix; ix < SLOTS; ix++) {
      if (!leaders.exists(ix)) return senderIsLeaderTokenId;
      if (leaders.ownerOf(ix) == msg.sender) {
        senderIsLeaderTokenId = ix;
      }

      uint256 amountToTransfer = (amount * leaders.contributions(ix)) / sum;
      address recipient = leaders.recipientOf(ix);

      bool distributionSuccessful =  _safeTransferETH(recipient, amountToTransfer);

      if (distributionSuccessful) {
        emit Distribution(recipient, amountToTransfer);
      }
    }

    return senderIsLeaderTokenId;
  }

  function _reorg(address contributor, uint256 contributionAmount) internal {
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

  function _replaceLowestLeader(uint256 tokenId, address contributor, uint256 leaderAmount, uint256 senderContributions) internal {
    _mint(leaders.ownerOf(tokenId), leaderAmount * TOKENS_PER_ETH);
    leaders.reorg(tokenId, contributor, senderContributions - leaderAmount);
    _burn(contributor, balanceOf(contributor));
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

  constructor(address deployer, uint256 slots) ERC721("Pyramid Game Leader Token", "PYRAMID"){
    root = msg.sender;
    SLOTS = slots;

    _mint(deployer, 0);
    incrementContribution(0, 0.01 ether);
  }


  receive () external payable {
    payable(root).call{ value: msg.value }(new bytes(0));
  }

  function exists(uint256 tokenId) external view returns (bool) {
    return _exists(tokenId);
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


  modifier onlyRoot {
    require(msg.sender == root, 'Only the root address can perform this action');
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



  function setRecipient(uint256 tokenId, address recipient) external {
    require(ownerOf(tokenId) == msg.sender, 'Only token owner can perform this action');
    recipientOf[tokenId] = recipient;
  }


  function _beforeTokenTransfer(address, address to, uint256 tokenId) internal virtual override {
    recipientOf[tokenId] = to;
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    string memory tokenString = Strings.toString(tokenId);

    bytes memory encodedSVG = abi.encodePacked(
      'data:image/svg+xml;base64,',
      Base64.encode(abi.encodePacked(rawSVG(tokenId)))
    );


    return string(abi.encodePacked(
      'data:application/json;utf8,'
      '{"name": "Pyramid Game: Leader #', tokenString,
      '", "description": "'
      '", "license": "CC0'
      '", "image": "', encodedSVG,
      '", "attributes": [{ "trait_type": "Leader Token Contributions", "value": "', Strings.toString(contributions[tokenId]), ' wei" }]'
      '}'
    ));
  }

  function rawSVG(uint256 tokenId) public view returns (string memory) {
    string memory green = '#46ff5a';
    string memory black = '#000';
    string memory blue = '#283fff';
    string memory orange = '#ff920f';

    string[2][12] memory colors = [
      [black, green],
      [blue, green],
      [orange, green],

      [blue, black],
      [orange, black],
      [green, black],

      [orange, blue],
      [green, blue],
      [black, blue],

      [green, orange],
      [black, orange],
      [blue, orange]
    ];


    return string.concat(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 487 487">'
        '<style>*{stroke:', colors[tokenId][0],';fill:', colors[tokenId][1],'}</style>'
        '<rect width="100%" height="100%" x="0" y="0" stroke-width="0"></rect>'
        '<path d="M465.001 435.5H244.995H20.5L242.75 50L465.001 435.5Z"  stroke-width="14"/>'
        '<path d="M205.5 348C216 357 227.513 359.224 243.001 359.999C293 362.5 301.001 294.999 243.001 293.499C185.001 291.999 196.5 224.5 243.001 229.998C243.001 229.998 259.5 229.998 276.5 244"  stroke-width="14" stroke-linecap="square"/>'
        '<line x1="242.5" y1="201" x2="242.5" y2="386"  stroke-width="14"/>'
      '</svg>'
    );

  }


  event MetadataUpdate(uint256 _tokenId);
  event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721) returns (bool) {
    // ERC2981 & ERC4906
    return interfaceId == bytes4(0x2a55205a) || interfaceId == bytes4(0x49064906) || super.supportsInterface(interfaceId);
  }
}