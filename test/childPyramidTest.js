const { expect } = require('chai')
const { ethers } = require('hardhat')

const toETH = amt => ethers.utils.parseEther(String(amt))
const txValue = amt => ({ value: toETH(amt) })
const ethVal = n => Number(ethers.utils.formatEther(n))

let PyramidGame, PyramidGameLeaders, signers, PG, PGL

describe('PyramidGame Child Deployment', () => {
  beforeEach(async () => {
    signers = await ethers.getSigners()

    const PyramidGameFactory = await ethers.getContractFactory('PyramidGame', signers[0])
    const PyramidGameLeadersFactory = await ethers.getContractFactory('PyramidGameLeaders', signers[0])

    const initialAmount = ethers.utils.parseEther('0.01')
    const colors = ['#000', '#46ff5a', '#283fff', '#ff1b1b']

    PyramidGame = await PyramidGameFactory.deploy(initialAmount, colors)
    await PyramidGame.deployed()
    PyramidGameLeaders = await PyramidGameLeadersFactory.attach(
      await PyramidGame.leaders()
    )

    PG = (s) => PyramidGame.connect(s)
    PGL = (s) => PyramidGameLeaders.connect(s)
  })

  describe('deployChildPyramidGame', () => {
    it('deploys a minimal proxy clone', async () => {
      const colors = ['#FF0000', '#00FF00', '#0000FF', '#FFFF00']

      // Check initial state
      expect(await PyramidGame.totalChildren()).to.equal(0)

      // Deploy child with ETH
      const tx = await PG(signers[1]).deployChildPyramidGame(colors, { value: toETH(0.05) })
      const receipt = await tx.wait()

      // Check event was emitted
      const event = receipt.events.find(e => e.event === 'ChildPyramidDeployed')
      expect(event).to.not.be.undefined
      expect(event.args.deployer).to.equal(signers[1].address)

      const childAddress = event.args.childAddress

      // Verify child was added to array
      expect(await PyramidGame.totalChildren()).to.equal(1)
      expect(await PyramidGame.children(0)).to.equal(childAddress)
    })

    it('deploys multiple children and tracks them all', async () => {
      const colors = ['#000', '#46ff5a', '#283fff', '#ff1b1b']

      // Deploy three children
      const tx1 = await PG(signers[0]).deployChildPyramidGame(colors, { value: toETH(0.01) })
      const receipt1 = await tx1.wait()
      const child1 = receipt1.events.find(e => e.event === 'ChildPyramidDeployed').args.childAddress

      const tx2 = await PG(signers[1]).deployChildPyramidGame(colors, { value: toETH(0.01) })
      const receipt2 = await tx2.wait()
      const child2 = receipt2.events.find(e => e.event === 'ChildPyramidDeployed').args.childAddress

      const tx3 = await PG(signers[2]).deployChildPyramidGame(colors, { value: toETH(0.01) })
      const receipt3 = await tx3.wait()
      const child3 = receipt3.events.find(e => e.event === 'ChildPyramidDeployed').args.childAddress

      // Verify all children are tracked
      expect(await PyramidGame.totalChildren()).to.equal(3)
      expect(await PyramidGame.children(0)).to.equal(child1)
      expect(await PyramidGame.children(1)).to.equal(child2)
      expect(await PyramidGame.children(2)).to.equal(child3)

      // Verify each child is unique
      expect(child1).to.not.equal(child2)
      expect(child2).to.not.equal(child3)
      expect(child1).to.not.equal(child3)
    })

    it('child wallet receives parent tokens when deployed with ETH', async () => {
      const colors = ['#000', '#46ff5a', '#283fff', '#ff1b1b']

      // Deploy child with ETH - this initializes child AND contributes to parent
      const tx = await PG(signers[0]).deployChildPyramidGame(colors, { value: toETH(1) })
      const receipt = await tx.wait()
      const childAddress = receipt.events.find(e => e.event === 'ChildPyramidDeployed').args.childAddress

      // Connect to child
      const PyramidGameFactory = await ethers.getContractFactory('PyramidGame')
      const childPyramid = PyramidGameFactory.attach(childAddress)

      // Get child's wallet
      const childWalletAddress = await childPyramid.wallet()

      // Check that child's wallet has tokens/NFT in the parent (this PyramidGame)
      const parentLeadersAddress = await PyramidGame.leaders()
      const PyramidGameLeadersFactory = await ethers.getContractFactory('PyramidGameLeaders')
      const parentLeaders = PyramidGameLeadersFactory.attach(parentLeadersAddress)

      // Child wallet should own a leader token in parent (since 1 ETH > 0.01 ETH initial)
      expect(await parentLeaders.balanceOf(childWalletAddress)).to.be.greaterThan(0)
    })
  })
})
