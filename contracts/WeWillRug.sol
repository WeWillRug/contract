// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "https://github.com/pancakeswap/pancake-smart-contracts/blob/master/projects/exchange-protocol/contracts/interfaces/IPancakeRouter02.sol";
import "https://github.com/pancakeswap/pancake-smart-contracts/blob/master/projects/exchange-protocol/contracts/interfaces/IPancakePair.sol";
import "https://github.com/pancakeswap/pancake-smart-contracts/blob/master/projects/exchange-protocol/contracts/interfaces/IPancakeFactory.sol";

error PoolDoesNotExist();
error VotingTimeExcceded();
error TokenRuggedAlready();
error PairDoesNotExist();
error YouDidNotBet();
error VotingHasNotEnded();
error TokenDidRugYouCanotClaim();

contract WeWillRug is AutomationCompatibleInterface, ReentrancyGuard {
    enum Options {
        WillRug,
        WillNotRug
    }

    struct Pool {
        uint256 id;
        uint256 totalParticipants;
        uint256 totalWERUGForWillRug;
        uint256 totalWERUGForWillNotRug;
        uint256 totalWERUG;
        uint256 timeCreated;
        address pairAddress;
        address tokenA;
        address tokenB;
        bool ruged;
    }

    struct Bet {
        uint256 amount;
        bool willRug;
    }

    mapping(uint256 => Pool) public pools;
    mapping(address => mapping(uint256 => Bet)) usersToBet;

    uint256 maxVotingPeriod = 1 hours;
    uint256 betEnding = 24 hours;
    uint256 poolCounter;
    uint256 teamPercent = 5;

    IERC20 public WERUG;
    IUniswapV2Router02 public uniswapRouter;
    string[] exchanges = ["uniswap", "pankeswap"];

    constructor(address _WERUG, address _uniswapRouter) {
        WERUG = IERC20(_WERUG);
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    }

    modifier itExist(uint256 _poolId) {
        Pool storage pool = pools[_poolId];
        if (pool.pairAddress == address(0)) {
            revert PoolDoesNotExist();
        }
        _;
    }

    function createBetPool(address _tokenA, address _tokenB, string memory _exchange) public {
        Pool storage pool = pools[poolCounter];

        // if()

        address pairAddress = IUniswapV2Factory(uniswapRouter.factory()).getPair(_tokenA, _tokenB);
        if (pairAddress == address(0)) {
            revert PairDoesNotExist();
        }
        pool.id = poolCounter;
        pool.pairAddress = pairAddress;
        pool.tokenA = _tokenA;
        pool.timeCreated = block.timestamp;

        poolCounter++;
    }

    function claim(uint256 _poolId, address beneficiary) public nonReentrant itExist(_poolId) {
        Pool storage pool = pools[_poolId];
        Bet storage userBet = usersToBet[msg.sender][_poolId];
        if (userBet.amount <= 0) {
            revert YouDidNotBet();
        }

        // Check if pool reward can be claim yet

        if (pool.ruged == false) {
            if (pool.timeCreated + maxVotingPeriod >= block.timestamp) {
                revert VotingHasNotEnded();
            }
        } else if (pool.ruged == true) {
            if (userBet.willRug == true) {
                uint256 amountBet = userBet.amount;
                uint256 estimate = calculateEstimatePayout(pool.totalWERUG, amountBet);
                WERUG.transfer(beneficiary, estimate);
            } else {
                revert TokenDidRugYouCanotClaim();
            }
        }

        // if(pool.ruged)
        // if(pool.timeCreated)
    }

    function calculateEstimatePayout(
        uint256 _totalWERUG,
        uint256 _userWERUG
    ) public view returns (uint256 estimate) {
        uint256 percentage = (_userWERUG / _totalWERUG) * (100 - teamPercent);
        estimate = (_totalWERUG * percentage) / 100;
    }

    function bet(uint256 _poolId, bool willRug, uint256 amount) public itExist(_poolId) {
        Pool storage pool = pools[_poolId];
        Bet storage userBet = usersToBet[msg.sender][_poolId];
        if (pool.timeCreated + maxVotingPeriod <= block.timestamp) {
            revert VotingTimeExcceded();
        }

        if (pool.ruged == true) {
            revert TokenRuggedAlready();
        }

        if (userBet.amount > 0) {
            revert YouDidNotBet();
        }

        WERUG.transferFrom(msg.sender, address(this), amount);

        userBet.amount = amount;
        userBet.willRug = willRug;

        if (willRug) {
            pool.totalWERUGForWillRug = pool.totalWERUGForWillRug + amount;
        } else {
            pool.totalWERUGForWillNotRug = pool.totalWERUGForWillNotRug + amount;
        }
    }

    function checkUpkeep(
        bytes memory /*checkData*/
    ) public view override returns (bool upKeepNeeded, bytes memory /* performData */) {
        upKeepNeeded = true;
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        uint256 counter;
        Pool[] memory activePools = new Pool[](counter);
        for (uint i = 0; i < poolCounter; i++) {
            Pool storage pool = pools[i];
            if (pool.ruged == false) {
                if (pool.timeCreated + maxVotingPeriod >= block.timestamp) {
                    activePools[counter] = pool;
                    counter++;
                }
            }
        }
        for (uint i = 0; i < activePools.length; i++) {
            bool ruged = hasRuged(activePools[i]);
        }
    }

    function hasRuged(Pool memory pool) public returns (bool) {
        (uint256 reserveA, uint256 reserveB) = getUniswapLiquidity(pool.tokenA, pool.tokenB);
    }

    function getUniswapLiquidity(
        address _tokenA,
        address _tokenB
    ) public view returns (uint256 reserveA, uint256 reserveB) {
        address pairAddress = IUniswapV2Factory(uniswapRouter.factory()).getPair(_tokenA, _tokenB);
        if (pairAddress == address(0)) {
            revert PairDoesNotExist();
        }
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        (reserveA, reserveB, ) = pair.getReserves();
    }

    function getPancakeswapLiquidity(
        address _tokenA,
        address _tokenB
    ) public view returns (uint256 reserveA, uint256 reserveB) {
        address pairAddress = IPancakeFactory(pancakeRouter.factory()).getPair(_tokenA, _tokenB);
        require(pairAddress != address(0), "Pair does not exist");

        IPancakePair pair = IPancakePair(pairAddress);
        (reserveA, reserveB) = pair.getReserves();
    }
}
