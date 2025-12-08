// SPDX-License-Identifier: MIT

/*

  _____                           _     _
 |  __ \                         (_)   | |
 | |__) |   _ _ __ __ _ _ __ ___  _  __| |
 |  ___/ | | | '__/ _` | '_ ` _ \| |/ _` |
 | |   | |_| | | | (_| | | | | | | | (_| |
 |_|    \__, |_|  \__,_|_| |_| |_|_|\__,_|
    _______/ |
  / ________/
 | |  __  __ _ _ __ ___   ___
 | | |_ |/ _` | '_ ` _ \ / _ \
 | |__| | (_| | | | | | |  __/
  \_____|\__,_|_| |_| |_|\___|



by steviep.eth
2025


*/


import "./Dependencies.sol";

pragma solidity ^0.8.30;


/// @title Pyramid Game
/// @author steviep.eth
/// @notice A pyramid scheme game in which all ETH sent to the contract is split among the top previous senders.
/// Two phases take place when an ETH contribution is made to the Pyramid Game contract: DISTRIBUTION and RECACHING.
/// The DISTRIBUTION phase splits the contribution among the Leaders.
/// This split is proportional, based on how much Leaders have directly or indirectly contributed.
/// The RECACHING phase then recalculates the contribution totals and determines the new Leaders.
/// Leadership is managed by a LEADER NFT, which can be transfered to another address.
/// The LEADER NFT is automatically transferred upon Leadership recalculation if necessary.
/// Contribution amounts are managed by an ERC-20 token, $PYRAMID.
/// New $PYRAMID is minted to contributors when they fail to become a Leader, and when former Leaders are kicked off the Leader Board.
/// $PYRAMID is burned when a contributor becomes a Leader.
/// The total circulating $PYRAMID supply equals the total historical ETH contributions made, minus the sum of all contributions associated with current Leaders.
contract PyramidGame is ERC20 {
  uint8 constant public SLOTS = 12;
  uint8 constant public INVALID_SLOT = SLOTS + 1;

  uint256 constant public TOKENS_PER_ETH = 100_000;

  PyramidGameLeaders public leaders;
  PyramidGameWallet public wallet;
  address[] public children;
  bool private initialized;

  event Contribution(address indexed sender, uint256 amount);
  event Distribution(address indexed recipient, uint256 amount);
  event ChildPyramidDeployed(address indexed childAddress, address indexed deployer, uint256 initialAmount);

  constructor(uint256 initialAmount, string[4] memory colors) ERC20("Pyramid Game", "PYRAMID") {
    initialize(msg.sender, initialAmount, colors);
  }

  /// @notice Initialize the Pyramid Game instance
  /// @dev Can only be called once. Called by constructor for normal deployments, or manually for proxy clones
  /// @param deployer The address that will receive the first leader NFT
  /// @param initialAmount The initial contribution amount for token 0
  /// @param colors Array of 4 hex color strings for the NFTs
  function initialize(address deployer, uint256 initialAmount, string[4] memory colors) public {
    require(!initialized, "Already initialized");
    initialized = true;
    leaders = new PyramidGameLeaders(deployer, SLOTS, initialAmount, colors);
    wallet = new PyramidGameWallet(address(this), payable(address(leaders)));
  }


  ////// CONTRIBUTIONS

  /// @notice View a participant's direct and indirect contributions
  function outstandingContributions(address contributor) public view returns (uint256) {
    return balanceOf(contributor) / TOKENS_PER_ETH;
  }


  /// @notice All sends to the contract trigger contribution functionality. There is no difference
  /// between doing this and calling `contribute`.
  receive () external payable {
    _contribute();
  }

  /// @notice Explicitly make a contribution. There is no difference between calling this function and sending to the contract.
  function contribute() external payable {
    _contribute();
  }

  /// @notice Claims Leadership role for the caller if they have amassed enough $PYRAMID.
  function claimLeadership() external {
    _reorg(msg.sender, 0);
  }


  /// @notice Allows existing leaders to burn $PYRAMID and increment their LEADER token's contribution balance
  function addToLeaderContributionBalance(uint256 tokenId, uint256 tokenAmount) external {
    _burn(msg.sender, tokenAmount);
    leaders.incrementContributionBalance(tokenId, tokenAmount / TOKENS_PER_ETH);
  }


  /// @dev Force a distribution if the contract accrues a balance. This may occur if
  /// distributions are directly or indirectly forwarded back to the contract.
  function forceDistribution() external ignoreReentry {
    _distribute(address(this).balance);
  }



  ////// INTERNAL


  /// @dev Reentry is ignored instead of disallowed in order to safeguard against recursive
  /// distributions. Sending a LEADER token to the Pyramid Game contract (or setting it as a recipient)
  /// would otherwise lead to an infinite loop. Throwing an error in this case would completely brick all
  /// contributions. Any balance accrued by the contract from failed reentries can be manually
  /// distributed through `forceDistribution`.
  function _contribute() internal ignoreReentry {
    uint8 senderIsLeaderTokenId = _distribute(msg.value);

    if (senderIsLeaderTokenId != INVALID_SLOT) {
      leaders.incrementContributionBalance(uint256(senderIsLeaderTokenId), msg.value);
    } else {
      _reorg(msg.sender, msg.value);
    }

    emit Contribution(msg.sender, msg.value);
  }


  /// @dev Given the cached Leaders: calculate the total contribution amounts, determine each
  /// Leader's percentage of the sum, and distribute the original contribution proportionally.
  function _distribute(uint256 amount) internal returns (uint8) {
    uint8 senderIsLeaderTokenId = INVALID_SLOT;
    uint256 contributionTotal = leaders.contributionTotal();

    for (uint8 ix; ix < SLOTS; ix++) {
      if (!leaders.exists(ix)) return senderIsLeaderTokenId;
      if (leaders.ownerOf(ix) == msg.sender) {
        senderIsLeaderTokenId = ix;
      }

      uint256 amountToTransfer = (amount * leaders.contributions(ix)) / contributionTotal;
      address recipient = leaders.recipientOf(ix);

      bool distributionSuccessful =  _safeTransferETH(recipient, amountToTransfer);

      if (distributionSuccessful) {
        emit Distribution(recipient, amountToTransfer);
      }
    }

    return senderIsLeaderTokenId;
  }


  /// @dev After the distribution has been made, recalculate the leaderboard.
  function _reorg(address contributor, uint256 contributionAmount) internal {
    if (leaders.totalSupply() < SLOTS) {
      leaders.mint(contributor, contributionAmount);
    } else {
      (uint256 tokenId, uint256 leaderAmount) = leaders.lowestLeader();
      uint256 senderContributions = outstandingContributions(contributor) + contributionAmount;
      if (senderContributions > leaderAmount) {
        _replaceLowestLeader(tokenId, contributor, leaderAmount, senderContributions);
      } else {
        _mint(contributor, contributionAmount * TOKENS_PER_ETH);
      }
    }
  }

  /// @dev Find the leader with the lowest total contribution amount and replace them with the sender.
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



  ////// CHILD PYRAMID DEPLOYMENT

  /// @notice Deploy a minimal proxy clone of this Pyramid Game
  /// @dev Uses EIP-1167 minimal proxy pattern - the clone will delegate all calls to this contract's code
  /// @dev msg.value is used to initialize the child's first leader and contribute to the parent pyramid
  /// @param colors Array of 4 hex color strings for the child pyramid's NFTs
  /// @return clone The address of the newly deployed minimal proxy
  function deployChildPyramidGame(
    string[4] memory colors
  ) external payable returns (address payable clone) {
    // Create EIP-1167 minimal proxy that delegates to this contract
    bytes20 targetBytes = bytes20(address(this));
    assembly {
      // Get free memory pointer
      let cloneContract := mload(0x40)

      // Store first part of proxy bytecode (initialization + runtime header)
      mstore(cloneContract, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)

      // Store the implementation address (this contract)
      mstore(add(cloneContract, 0x14), targetBytes)

      // Store second part of proxy bytecode (runtime footer)
      mstore(add(cloneContract, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)

      // Deploy the proxy contract (55 bytes total)
      clone := create(0, cloneContract, 0x37)
    }
    require(clone != address(0), "Clone deployment failed");

    require(msg.value > 0, 'Must send ETH to deploy child');

    // Initialize the clone (it will create its own leaders and wallet)
    PyramidGame(clone).initialize(msg.sender, msg.value, colors);

    // Get child's wallet and have it contribute to parent
    PyramidGameWallet childWallet = PyramidGame(clone).wallet();
    childWallet.contributeToParent{value: msg.value}();

    children.push(clone);
    emit ChildPyramidDeployed(clone, msg.sender, msg.value);
  }

  /// @notice Get the total number of child pyramids
  /// @return The count of child pyramids
  function totalChildren() external view returns (uint256) {
    return children.length;
  }


  ////// TOKEN REDIRECTION TO WALLET

  /// @notice Redirect received ERC721 to wallet
  function onERC721Received(address, address, uint256 tokenId, bytes calldata) external returns(bytes4) {
    IERC721(msg.sender).transferFrom(address(this), address(wallet), tokenId);
    return this.onERC721Received.selector;
  }

  /// @notice Sweep any ERC20 tokens to wallet
  function sweepERC20(address token) external {
    uint256 balance = IERC20(token).balanceOf(address(this));
    if (balance > 0) {
      IERC20(token).transfer(address(wallet), balance);
    }
  }

}


/// @title Pyramid Game Wallet
/// @author steviep.eth
/// @notice Wallet contract that executes transactions approved by majority of leaders
contract PyramidGameWallet {
  PyramidGame public pyramidGame;
  PyramidGameLeaders public leaders;
  uint8 public immutable SLOTS;

  mapping(uint256 => bool) public nonceUsed;

  event TransactionExecuted(address indexed target, uint256 nonce);

  constructor(address _pyramidGame, address payable _leaders) {
    pyramidGame = PyramidGame(payable(_pyramidGame));
    leaders = PyramidGameLeaders(_leaders);
    SLOTS = pyramidGame.SLOTS();
  }


  /// @notice Contribute to the parent pyramid on behalf of the child
  /// @dev This allows the child pyramid's wallet to accumulate tokens in the parent
  function contributeToParent() external payable {
    pyramidGame.contribute{value: msg.value}();
  }

  /// @notice Execute a transaction if signed by majority of leaders
  /// @param target The contract to call
  /// @param value The ETH value to send with the call
  /// @param data The call data
  /// @param txNonce The nonce for this transaction
  /// @param leaderTokenIds Array of leader token IDs voting
  /// @param signatures Array of signatures from leader token owners (in same order as leaderTokenIds)
  function executeLeaderTransaction(
    address target,
    uint256 value,
    bytes calldata data,
    uint256 txNonce,
    uint256[] calldata leaderTokenIds,
    bytes[] calldata signatures
  ) external {
    require(!nonceUsed[txNonce], 'Nonce already used');
    require(leaderTokenIds.length == signatures.length, 'Array length mismatch');
    require(leaderTokenIds.length > SLOTS / 2, 'Insufficient votes');

    bytes32 messageHash = keccak256(abi.encode(target, value, data, txNonce));
    bytes32 ethSignedMessageHash = keccak256(abi.encodePacked('\x19Ethereum Signed Message:\n32', messageHash));

    // Verify each signature corresponds to the owner of the leader token
    for (uint256 i = 0; i < leaderTokenIds.length; i++) {
      address signer = recoverSigner(ethSignedMessageHash, signatures[i]);
      require(leaders.ownerOf(leaderTokenIds[i]) == signer, 'Invalid signature');
    }

    nonceUsed[txNonce] = true;

    (bool success, ) = target.call{value: value}(data);
    require(success, 'Transaction failed');

    emit TransactionExecuted(target, txNonce);
  }

  /// @dev Recover signer from signature
  function recoverSigner(bytes32 ethSignedMessageHash, bytes memory signature) internal pure returns (address) {
    require(signature.length == 65, 'Invalid signature length');

    bytes32 r;
    bytes32 s;
    uint8 v;

    assembly {
      r := mload(add(signature, 32))
      s := mload(add(signature, 64))
      v := byte(0, mload(add(signature, 96)))
    }

    return ecrecover(ethSignedMessageHash, v, r, s);
  }


  // BOILERPLATE


  receive() external payable {}
  fallback() external payable {}

  function onERC721Received(address, address, uint256, bytes calldata) external pure returns(bytes4) {
    return this.onERC721Received.selector;
  }

  function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
    return this.onERC1155Received.selector;
  }

  function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) external pure returns (bytes4) {
    return this.onERC1155BatchReceived.selector;
  }
}


/// @title Pyramid Game
/// @author steviep.eth
/// @notice NFT contract that manages the Leader Board for Pyramid Game.
contract PyramidGameLeaders is ERC721 {
  address public root;
  uint256 public contributionTotal;
  uint256 public totalSupply = 1;
  uint256 public SLOTS;
  string[4] public colors;

  mapping(uint256 => address) public recipientOf;
  mapping(uint256 => uint256) public contributions;

  constructor(address deployer, uint256 slots, uint256 initialAmount, string[4] memory _colors) ERC721("Pyramid Game Leader", "LEADER"){
    root = msg.sender;
    SLOTS = slots;
    colors = _colors;

    _mint(deployer, 0);
    incrementContributionBalance(0, initialAmount);
  }


  receive () external payable {
    (bool success, ) = payable(root).call{ value: msg.value }(new bytes(0));
    success;
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



  /// SET RECIPIENTS

  /// @notice Allows the owner of a LEADER token to forward all Pyramid Game ETH to another address.
  function setRecipient(uint256 tokenId, address recipient) external {
    require(ownerOf(tokenId) == msg.sender, 'Only token owner can perform this action');
    recipientOf[tokenId] = recipient;
  }

  /// @dev Clear the recipient address on token transfer.
  function _beforeTokenTransfer(address, address to, uint256 tokenId) internal virtual override {
    recipientOf[tokenId] = to;
  }


  /// ONLY THE PYRAMID GAME CONTRACT CAN TAKE THESE ACTIONS

  modifier onlyRoot {
    require(msg.sender == root, 'Only the root address can perform this action');
    _;
  }

  function incrementContributionBalance(uint256 tokenId, uint256 incrementAmount) public onlyRoot {
    contributions[tokenId] += incrementAmount;
    contributionTotal += incrementAmount;

    emit MetadataUpdate(tokenId);
  }

  function mint(address recipient, uint256 incrementAmount) external onlyRoot {
    require(totalSupply < SLOTS);
    _mint(recipient, totalSupply);
    incrementContributionBalance(totalSupply, incrementAmount);
    totalSupply += 1;
  }

  function reorg(uint256 tokenId, address recipient, uint256 incrementAmount) external onlyRoot {
    incrementContributionBalance(tokenId, incrementAmount);
    _transfer(ownerOf(tokenId), recipient, tokenId);
  }


  /// METADATA

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
    string memory color0 = colors[0];
    string memory color1 = colors[1];
    string memory color2 = colors[2];
    string memory color3 = colors[3];

    string[2][12] memory colorPairs = [
      [color0, color1],
      [color2, color1],
      [color3, color1],

      [color2, color0],
      [color3, color0],
      [color1, color0],

      [color3, color2],
      [color1, color2],
      [color0, color2],

      [color1, color3],
      [color0, color3],
      [color2, color3]
    ];


    return string.concat(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 487 487">'
        '<style>*{stroke:', colorPairs[tokenId][0],';fill:', colorPairs[tokenId][1],'}</style>'
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