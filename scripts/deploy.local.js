
const toETH = amt => ethers.utils.parseEther(String(amt))
const txValue = amt => ({ value: toETH(amt) })

async function main() {
  const signers = await ethers.getSigners()

  const PyramidGameFactory = await ethers.getContractFactory('PyramidGame', signers[1])
  const PyramidGame = await PyramidGameFactory.deploy(txValue(0.01))
  await PyramidGame.deployed()

  const PG = (s) => PyramidGame.connect(signers[s])

  // Create 12 leaders with varying contributions
  // signer[1] has 0.01 ETH from deployment (lowest)
  await PG(2).contribute(txValue(0.5))
  await PG(3).contribute(txValue(0.6))
  await PG(4).contribute(txValue(0.7))
  await PG(5).contribute(txValue(0.8))
  await PG(6).contribute(txValue(0.9))
  await PG(7).contribute(txValue(1.0))
  await PG(8).contribute(txValue(1.1))
  await PG(9).contribute(txValue(1.2))
  await PG(10).contribute(txValue(1.3))
  await PG(11).contribute(txValue(1.4))
  await PG(12).contribute(txValue(1.5))
  await PG(13).contribute(txValue(1.6))

  // signer[0] contributes 0.5 ETH - gets PYRAMID tokens (not a leader yet)
  await PG(0).contribute(txValue(0.4))

  // Now signer[0] has 0.5 ETH worth of PYRAMID
  // Lowest leader (signer[1]) has 0.01 ETH
  // signer[0] can now claim leadership to replace signer[1]

  await signers[0].sendTransaction({
    to: '0x8D55ccAb57f3Cba220AB3e3F3b7C9F59529e5a65',
    ...txValue(10)
  })

  const leadersAddr = await PyramidGame.leaders()
  const walletAddr = await PyramidGame.wallet()

  console.log('PyramidGame:', PyramidGame.address)
  console.log('PyramidGameLeaders:', leadersAddr)
  console.log('PyramidGameWallet:', walletAddr)
  console.log('\nGame State:')
  console.log('- signer[0] has 0.5 ETH in PYRAMID tokens')
  console.log('- Lowest leader (signer[1]) has 0.01 ETH')
  console.log('- signer[0] can claim leadership!')
}


main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });