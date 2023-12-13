const { ethers, network } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()

    log("--------------------------")
    const args = []
    const WERUG = await deploy("WERUG", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })
    log("--------------------------")
    console.log(`WERUG Deployed at:${WERUG.address}`)
}

module.exports.tags = ["all", "WERUG"]
