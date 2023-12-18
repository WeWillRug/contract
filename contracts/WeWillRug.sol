// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

interface IPancakeRouter01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);
}

interface IPancakeRouter02 is IPancakeRouter01 {}

interface IPancakeFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IPancakePair {
    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}
// import "https://github.com/pancakeswap/pancake-smart-contracts/blob/master/projects/exchange-protocol/contracts/interfaces/IPancakeRouter02.sol";
// import "https://github.com/pancakeswap/pancake-smart-contracts/blob/master/projects/exchange-protocol/contracts/interfaces/IPancakePair.sol";

// import "https://github.com/pancakeswap/pancake-smart-contracts/blob/master/projects/exchange-protocol/contracts/interfaces/IPancakeFactory.sol";

error PoolDoesNotExist();
error VotingTimeExcceded();
error TokenRuggedAlready();
error PairDoesNotExist();
error YouDidNotBet();
error VotingHasNotEnded();
error TokenDidRugYouCanotClaim();
error InvalidExchange();

contract WeWillRug is AutomationCompatibleInterface, ReentrancyGuard, Ownable {
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
        string exchange;
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
    uint256 MINIMUMLIQUDITY_WETH = 300000000 * 10 ** 18;
    uint256 MINIMUMLIQUDITY_USDT = 100;
    uint256 MINIMUMLIQUDITY_TOKEN = 100;

    IERC20 public WERUG;
    IUniswapV2Router02 public uniswapRouter;
    IPancakeRouter02 public pancakeRouter;

    string[] exchanges = ["uniswap", "pancakeswap"];

    constructor(address _WERUG, address _uniswapRouter, address _pancakeRouter){
        WERUG = IERC20(_WERUG);
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        pancakeRouter = IPancakeRouter02(_pancakeRouter);

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

        //Check is exchange valid
        bool validExchange = isExchangeValid(_exchange);

        if (!validExchange) {
            revert InvalidExchange();
        }

        pool.id = poolCounter;
        pool.pairAddress = pairAddress;
        pool.tokenA = _tokenA;
        pool.timeCreated = block.timestamp;
        pool.exchange = "";

        poolCounter++;
    }

    function isExchangeValid(string memory _exchange) public view returns (bool) {
        for (uint256 i = 0; i < exchanges.length; i++) {
            if (
                keccak256(abi.encodePacked(exchanges[i])) == keccak256(abi.encodePacked(_exchange))
            ) {
                return true;
            }
        }
        return false;
    }

    function claim(uint256 _poolId, address beneficiary) public nonReentrant itExist(_poolId) {
        Pool storage pool = pools[_poolId];
        Bet storage userBet = usersToBet[msg.sender][_poolId];
        if (userBet.amount <= 0) {
            revert YouDidNotBet();
        }

        if (pool.ruged == false && userBet.willRug == false) {
            if (pool.timeCreated + maxVotingPeriod >= block.timestamp) {
                revert VotingHasNotEnded();
            }
            uint256 totalForWERUG = pool.totalWERUGForWillNotRug;
            _claim(pool, userBet, beneficiary, totalForWERUG);
        } else if (pool.ruged == true && userBet.willRug == true) {
            uint256 totalForWERUG = pool.totalWERUGForWillRug;
            _claim(pool, userBet, beneficiary, totalForWERUG);
        }
    }

    function _claim(
        Pool memory pool,
        Bet memory userBet,
        address beneficiary,
        uint256 totalForWERUG
    ) private {
        uint256 amountBet = userBet.amount;
        uint256 estimate = calculateEstimatePayout(pool.totalWERUG, totalForWERUG, amountBet);
        WERUG.transfer(beneficiary, estimate);
    }

    function calculateEstimatePayout(
        uint256 _totalWERUG,
        uint256 _totalForWERUG,
        uint256 _userWERUG
    ) public view returns (uint256 estimate) {
        uint256 percentage = (_userWERUG / _totalForWERUG) * (100 - teamPercent);
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
        if (poolCounter > 0) {
            upKeepNeeded = true;
        } else if (poolCounter <= 0) {
            upKeepNeeded = false;
        }
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        uint256 counter;
        Pool[] memory activePools = new Pool[](counter);
        for (uint i = 0; i < poolCounter; i++) {
            Pool storage pool = pools[i];
            if (pool.ruged == false) {
                if (pool.timeCreated + betEnding >= block.timestamp) {
                    activePools[counter] = pool;
                    counter++;
                }
            }
        }
        for (uint i = 0; i < activePools.length; i++) {
            bool ruged = hasRuged(activePools[i]);
            uint256 teamTax = activePools[i].totalWERUG * (teamPercent / 100);
            if (ruged) {
                activePools[i].ruged = true;
                WERUG.transfer( Ownable.owner() , teamTax);
                }else if(activePools[i].timeCreated + betEnding <= block.timestamp) {
                WERUG.transfer( Ownable.owner() , teamTax);
                }
        }
    }

    function hasRuged(Pool memory pool) public view returns (bool _hasRuged) {
        uint256 reserveA;
        uint256 reserveB;

        if (
            keccak256(abi.encodePacked(pool.exchange)) == keccak256(abi.encodePacked(exchanges[0]))
        ) {
            (reserveA, reserveB) = getUniswapLiquidity(pool.tokenA, pool.tokenB);
        } else if (
            keccak256(abi.encodePacked(pool.exchange)) == keccak256(abi.encodePacked(exchanges[1]))
        ) {
            (reserveA, reserveB) = getPancakeswapLiquidity(pool.tokenA, pool.tokenB);
        }

        IERC20Metadata tokenA = IERC20Metadata(pool.tokenA);
        uint256 _MINIMUMLIQUDITY_TOKEN = MINIMUMLIQUDITY_TOKEN * 10 ** tokenA.decimals();

        if (reserveA <= _MINIMUMLIQUDITY_TOKEN){
            _hasRuged = true;
            } else if (reserveA > _MINIMUMLIQUDITY_TOKEN){
                _hasRuged = false;
            }
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
        if (pairAddress == address(0)) {
            revert PairDoesNotExist();
        }
        IPancakePair pair = IPancakePair(pairAddress);
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        reserveA = uint256(reserve0);
        reserveB = uint256(reserve1);
    }
}
