// we can't have these functions in our `helper-hardhat-config`
// since these use the hardhat library
// and it would be a circular dependency
const { run } = require("hardhat")

const args = []
const contractAddress = ""
const verify = async () => {
    console.log("Verifying contract...")
    try {
        await run("verify:verify", {
            address: contractAddress,
            constructorArguments: args,
        })
    } catch (e) {
        if (e.message.toLowerCase().includes("already verified")) {
            console.log("Already verified!")
        } else {
            console.log(e)
        }
    }
}

// module.exports = {
verify()
// }
