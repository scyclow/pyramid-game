


export const CONTRACTS = {
  PyramidGame: {
    addr: {
      local: '0x8464135c8F25Da09e49BC8782676a84730C318bC',
      sepolia: '0x3b0E151c9be53B6316Ef7E7B7A18FF2713C6D609',
      base: ''
    },
    abi: [
      'event Contribution(address indexed sender, uint256 amount)',
      'event Distribution(address indexed recipient, uint256 amount)',
      'function contribute() external payable',
      'function claimLeadership() external',
      'function addToLeaderContributionBalance(uint256 tokenId, uint256 tokenAmount) external',
      'function outstandingContributions(address contributor) public view returns (uint256)',
      'function leaders() external view returns (address)',
      'function balanceOf(address account) public view returns (uint256)',
      'function transfer(address to, uint256 amount) public returns (bool)',
      'function approve(address spender, uint256 amount) public returns (bool)',
      'function allowance(address owner, address spender) public view returns (uint256)',
      'function transferFrom(address from, address to, uint256 amount) public returns (bool)',
      'function totalSupply() public view returns (uint256)',
      'function TOKENS_PER_ETH() public view returns (uint256)'
    ]
  },
  PyramidGameLeaders: {
    addr: {
      local: '0x8398bCD4f633C72939F9043dB78c574A91C99c0A',
      sepolia: '',
      base: ''
    },
    abi: [
      'event MetadataUpdate(uint256 _tokenId)',
      'function ownerOf(uint256 tokenId) external view returns (address)',
      'function tokenURI(uint256 tokenId) external view returns (string)',
      'function contributions(uint256 tokenId) external view returns (uint256)',
      'function contributionTotal() external view returns (uint256)',
      'function totalSupply() external view returns (uint256)',
      'function lowestLeader() external view returns (uint256 tokenId, uint256 amount)',
      'function setRecipient(uint256 tokenId, address recipient) external',
      'function balanceOf(address owner) external view returns (uint256)'
    ]
  },
  PyramidGameWallet: {
    addr: {
      local: '0x02299a3DcaB0938d0544130D054Bcbfb32B588C3',
      sepolia: '',
      base: ''
    },
    abi: []
  }
}

