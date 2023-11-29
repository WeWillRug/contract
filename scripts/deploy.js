// import { ethers } from "hardhat";
const { ethers } = require("hardhat")
async function deploy() {
    const Mintyplex = await ethers.deployContract("Mintyplex")

    await Mintyplex.waitForDeployment()

    console.log(`Mintyplex deployed to ${Mintyplex.target}`)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
deploy().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
