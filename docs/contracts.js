


export const CONTRACTS = {
  PyramidGame: {
    addr: {
      local: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
      sepolia: '0x3b0E151c9be53B6316Ef7E7B7A18FF2713C6D609',
      base: ''
    },
    abi: [
      'event Contribution(address indexed sender, uint256 amount)',
      'event Distribution(address indexed recipient, uint256 amount)',
      'function leaders(uint256) external view returns (address)',
      'function contributions(address) external view returns (uint256)',
      'function isLeader(address) public view returns (bool)'
    ]
  },

}

