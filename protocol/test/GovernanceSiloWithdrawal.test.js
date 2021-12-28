const hre = require("hardhat")
const { BN, expectRevert } = require("@openzeppelin/test-helpers")
const { deploy } = require('../scripts/deploy.js')
const { upgradeWithNewFacets } = require('../scripts/diamond.js')
const { expect } = require('chai')
const { printTestCrates, printCrates, print } = require('./utils/print.js')
const { parseJson, incrementTime } = require('./utils/helpers.js')
const { MIN_PLENTY_BASE, ZERO_ADDRESS, MAX_UINT256 } = require('./utils/constants.js')

// Set the test data
const [columns, tests] = parseJson('./coverage_data/siloGovernance.json')
var startTest = 0
var numberTests = tests.length-startTest
// numberTests = 1

const users = ['userAddress', 'user2Address', 'ownerAddress', 'otherAddress']

async function propose(user,g,bip,p=0) {
  return await g.connect(user).propose(bip.diamondCut, bip.initFacetAddress, bip.functionCall, p)
}

let user,user2,user3,owner;
let userAddress, ownerAddress, user2Address, user3Address;
let seasonTimestamp;

describe('Governance', function () {

  before(async function () {
    [owner,user,user2,user3] = await ethers.getSigners();
    userAddress = user.address;
    user2Address = user2.address;
    user3Address = user3.address;
    const contracts = await deploy("Test", false, true);
    ownerAddress = contracts.account;
    this.diamond = contracts.beanstalkDiamond;
    this.season = await ethers.getContractAt('MockSeasonFacet', this.diamond.address);
    this.governance = await ethers.getContractAt('MockGovernanceFacet', this.diamond.address);
    this.silo = await ethers.getContractAt('MockSiloFacet', this.diamond.address);
    this.pair = await ethers.getContractAt('MockUniswapV2Pair', contracts.pair);
    this.bean = await ethers.getContractAt('MockToken', contracts.bean);
    this.diamondLoupeFacet = await ethers.getContractAt('DiamondLoupeFacet', this.diamond.address)
    console.log(await this.governance.activeBips());

    this.empty = {
      diamondCut: [],
      initFacetAddress: ZERO_ADDRESS,
      functionCall: '0x'
    }

    this.bip = await upgradeWithNewFacets ({
      diamondAddress: this.diamond.address,
      facetNames: ['MockUpgradeFacet'],
      selectorsToRemove: [],
      initFacetName: 'MockUpgradeInitDiamond',
      initArgs: [],
      object: true,
      verbose: false,
    })

    await this.bean.mint(userAddress, '1000000');
    await this.bean.mint(user2Address, '1000000');
    await this.bean.mint(user3Address, '1000000');
    await this.bean.connect(user).approve(this.governance.address, '100000000000');
    await this.bean.connect(owner).approve(this.governance.address, '100000000000');
  });

  beforeEach(async function () {
    await this.season.resetAccount(userAddress)
    await this.season.resetAccount(user2Address)
    await this.season.resetAccount(user3Address)
    await this.season.resetAccount(ownerAddress)
    await this.season.resetState();
    await this.season.siloSunrise(0);
    await this.silo.depositSiloAssetsE(userAddress, '500', '1000000');
    await this.silo.depositSiloAssetsE(ownerAddress, '500', '1000000');
  });

  describe('vote and withdraw', function () {
    beforeEach(async function () {
      await propose(owner, this.governance, this.bip);
      await propose(owner, this.governance, this.bip);
      await propose(owner, this.governance, this.bip);
      await propose(owner, this.governance, this.bip);
      await propose(owner, this.governance, this.bip);

      await this.governance.connect(user).vote(1);

      await this.silo.withdrawSiloAssetsE(userAddress, '500', '500000');
    });

    it('sets vote counter correctly', async function () {
      expect(await this.governance.rootsFor(0)).to.be.equal(await this.silo.balanceOfRoots(ownerAddress));
      expect(await this.governance.rootsFor(1)).to.be.equal(await this.silo.totalRoots());
      expect(await this.governance.rootsFor(2)).to.be.equal(await this.silo.balanceOfRoots(ownerAddress));
      expect(await this.governance.rootsFor(3)).to.be.equal(await this.silo.balanceOfRoots(ownerAddress));
    });

    it('removes the stalk correctly from silo after one withdrawal', async function () {
      expect(await this.silo.balanceOfStalk(userAddress)).to.eq('500000');
    })

    it('roots and stalk are correct after one deposit and withdrawal', async function () {
      await this.silo.depositSiloAssetsE(userAddress, '500', '1000000');
      await this.silo.withdrawSiloAssetsE(userAddress, '500', '1000000');
      expect(await this.silo.balanceOfStalk(userAddress)).to.eq('500000');
    })

    it('roots and stalk are correct after many deposits and withdrawals', async function () {
      await this.silo.depositSiloAssetsE(userAddress, '500', '1000000');
      await this.silo.depositSiloAssetsE(userAddress, '1000', '1000000');
      await this.silo.withdrawSiloAssetsE(userAddress, '500', '500000');
      await this.silo.withdrawSiloAssetsE(userAddress, '500', '500000');
      await this.silo.withdrawSiloAssetsE(userAddress, '500', '500000');
      expect(await this.governance.rootsFor(1)).to.be.equal(await this.silo.totalRoots());
      expect(await this.silo.balanceOfStalk(userAddress)).to.eq('1000000');
    })

    it('roots and stalk are correct after proposer withdraws under the min required for a bip', async function () {
      await this.silo.withdrawSiloAssetsE(ownerAddress, '500', '500000');
      expect(await this.silo.balanceOfStalk(userAddress)).to.eq('500000');
      expect(await this.governance.rootsFor(0)).to.be.equal(await this.silo.balanceOfRoots(ownerAddress));
    })

    it('roots are correct after supply increases', async function () {
      await this.season.siloSunrise(1000000);
      expect(await this.governance.rootsFor(1)).to.be.equal(await this.silo.totalRoots());
    })

    it('is active', async function () {
      activeBips = await this.governance.activeBips();
      expect(activeBips[0]).to.eq(0);
      expect(activeBips[1]).to.eq(1);
      expect(activeBips[2]).to.eq(2);
      expect(activeBips[3]).to.eq(3);
    });

    it('records vote in voteList', async function () {
      expect(await this.governance.voted(userAddress, 1)).to.equal(true);
    });

  });
});