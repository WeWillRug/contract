// test/MintyplexDomains.test.js

const { ethers, waffle } = require("hardhat")
const { expect } = require("chai")
const { parseEther } = ethers.utils

const TLD = "mtpx"

describe("MintyplexDomains", function () {
    let contract
    let owner
    let addr1
    let addr2

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners()
        await deployments.fixture(["mintyplexDomains"])
        contract = await ethers.getContract("MintyplexDomains", owner)
    })

    it("Should register a valid domain", async function () {
        const name = "israel0x"
        const numberOfYears = 1
        const price = parseEther("6.99") // 6.99 ZETA
        await contract.connect(addr1).register(name, numberOfYears, { value: price })
        const domain = await contract.getDomainDetailsFromName(name)
        console.log(domain.name)
        expect(domain.owner).to.equal(addr1.address)
        expect(domain.name).to.equal(`${name}.${TLD}`)
        expect(domain.expiry).to.be.above(0)
    })

      it("Should not register an invalid domain", async function () {
        const invalidName = "inv@.;p=0=l&i#d";
        const numberOfYears = 1;
        const price = parseEther("6.99"); // 6.99 ZETA
        await expect(
          contract
            .connect(addr1)
            .register(invalidName, numberOfYears, { value: price })
        ).to.be.revertedWith("Invalid domain name");
      });

    it("Should transfer domain ownership", async function () {
        const name = "mydomain"
        const numberOfYears = 1
        const price = parseEther("6.99") // 6.99 ZETA
        await contract.connect(addr1).register(name, numberOfYears, { value: price })
        await contract.connect(addr1).transferDomain(name, addr2.address)
        const domain = await contract.getDomainDetailsFromName(name)
        expect(domain.owner).to.equal(addr2.address)
    })
})
