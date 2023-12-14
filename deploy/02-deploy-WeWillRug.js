const { ethers, network } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()

    log("--------------------------")
    const WERUG = "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6"
    const IUniswapV2Router02 = "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6"
    const IPancakeRouter02 = "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6"

    const args = [WERUG, IUniswapV2Router02, IPancakeRouter02]
    const WeWillRug = await deploy("WeWillRug", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })
    log("--------------------------")
    console.log(`WeWillRug Deployed at:${WeWillRug.address}`)
}

module.exports.tags = ["all", "WeWillRug"]
