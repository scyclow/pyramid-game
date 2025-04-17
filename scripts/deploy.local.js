
const toETH = amt => ethers.utils.parseEther(String(amt))
const txValue = amt => ({ value: toETH(amt) })

async function main() {
  const signers = await ethers.getSigners()

  const PyramidGameFactory = await ethers.getContractFactory('PyramidGame', signers[0])
  const PyramidGame = await PyramidGameFactory.deploy()
  await PyramidGame.deployed()

  const PG = (s) => PyramidGame.connect(signers[s])



  await PG(0).contribute(txValue(0.99))

  for (let i = 1; i< 10; i++) await PG(i).contribute(txValue(i + 1))

  console.log(`PyramidGame:`, PyramidGame.address)
}


main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });