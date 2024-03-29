// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

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
    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);
}

interface IPancakePair {
    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
}
// import "https://github.com/pancakeswap/pancake-smart-contracts/blob/master/projects/exchange-protocol/contracts/interfaces/IPancakeRouter02.sol";
// import "https://github.com/pancakeswap/pancake-smart-contracts/blob/master/projects/exchange-protocol/contracts/interfaces/IPancakePair.sol";

// import "https://github.com/pancakeswap/pancake-smart-contracts/blob/master/projects/exchange-protocol/contracts/interfaces/IPancakeFactory.sol";

error PoolDoesNotExist();
error VotingTimeExcceded();
error TokenRuggedAlready();
error PairDoesNotExist();
error YouDidNotBet();
error BetHasNotEnded();
error TokenDidRugYouCanotClaim();
error InvalidExchange();
error UpKeepNotNeeded();

contract WeWillRug is AutomationCompatibleInterface, ReentrancyGuard, Ownable {
    using SafeMath for uint256;

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
    mapping(address => mapping(uint256 => Bet)) public usersToBet;

    uint256 public maxVotingPeriod = 1 hours;
    uint256 public betEnding = 24 hours;
    uint256 public poolCounter;
    uint256 public teamPercent = 5;
    uint256 MINIMUMLIQUDITY_WETH = 300000000 * 10**18;
    uint256 MINIMUMLIQUDITY_USDT = 100;
    uint256 MINIMUMLIQUDITY_TOKEN = 100;

    IERC20 public WERUG;
    IUniswapV2Router02 public uniswapRouter;
    IPancakeRouter02 public pancakeRouter;

    string[] exchanges = ["uniswap", "pancakeswap"];

    constructor(
        address _WERUG,
        address _uniswapRouter,
        address _pancakeRouter
    ) {
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

    function createBetPool(
        address _tokenA,
        address _tokenB,
        string memory _exchange
    ) public {
        Pool storage pool = pools[poolCounter];

        address pairAddress = IUniswapV2Factory(uniswapRouter.factory())
            .getPair(_tokenA, _tokenB);
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
        pool.tokenB = _tokenB;
        pool.timeCreated = block.timestamp;
        pool.exchange = _exchange;

        poolCounter++;
    }

    function isExchangeValid(string memory _exchange)
        public
        view
        returns (bool)
    {
        for (uint256 i = 0; i < exchanges.length; i++) {
            if (
                keccak256(abi.encodePacked(exchanges[i])) ==
                keccak256(abi.encodePacked(_exchange))
            ) {
                return true;
            }
        }
        return false;
    }

    function claim(uint256 _poolId, address beneficiary)
        public
        nonReentrant
        itExist(_poolId)
    {
        Pool storage pool = pools[_poolId];
        Bet storage userBet = usersToBet[msg.sender][_poolId];
        if (userBet.amount <= 0) {
            revert YouDidNotBet();
        }

        if (pool.ruged == false && userBet.willRug == false) {
            if (pool.timeCreated + betEnding >= block.timestamp) {
                revert BetHasNotEnded();
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
        uint256 estimate = calculateEstimatePayout(
            pool.totalWERUG,
            totalForWERUG,
            amountBet
        );
        WERUG.transfer(beneficiary, estimate);
    }

    function calculateEstimatePayout(
        uint256 _totalWERUG,
        uint256 _totalForWERUG,
        uint256 _userWERUG
    ) public pure returns (uint256 estimate) {
        uint256 percentage = _userWERUG.mul(100).div(_totalForWERUG);
        uint256 userAmount = _totalWERUG.mul(percentage).div(100);
        estimate = userAmount.mul(100 - 5).div(100);
    }

    function bet(
        uint256 _poolId,
        bool willRug,
        uint256 amount
    ) public itExist(_poolId) {
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
        pool.totalWERUG = pool.totalWERUG + amount;
        pool.totalParticipants += 1;

        if (willRug) {
            pool.totalWERUGForWillRug = pool.totalWERUGForWillRug + amount;
        } else {
            pool.totalWERUGForWillNotRug =
                pool.totalWERUGForWillNotRug +
                amount;
        }
    }

    function checkUpkeep(
        bytes memory /*checkData*/
    )
        public
        view
        override
        returns (
            bool upKeepNeeded,
            bytes memory /* performData */
        )
    {
        if (poolCounter > 0) {
            upKeepNeeded = true;
        } else if (poolCounter <= 0) {
            upKeepNeeded = false;
        }
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        bool _upkeepNeeded = false;

        for (uint256 i = 0; i < poolCounter; i++) {
            Pool storage pool = pools[i];
            uint256 tax = teamTax(pool);

            if (pool.ruged == false) {
                if (pool.timeCreated + betEnding >= block.timestamp) {
                    bool ruged = hasRuged(pool);
                    if (ruged) {
                        _upkeepNeeded = true;
                        pool.ruged = true;
                        if (pool.totalWERUG > 0) {
                            WERUG.transfer(Ownable.owner(), tax);
                        }
                    }
                } else if (pool.timeCreated + betEnding <= block.timestamp) {
                    if (pool.totalWERUG > 0) {
                        _upkeepNeeded = true;
                        WERUG.transfer(Ownable.owner(), tax);
                    }
                }
            }
        }
        if (_upkeepNeeded == false) {
            revert UpKeepNotNeeded();
        }
    }

    function checkTeamTax(uint256 _poolId) public view returns (uint256 tax) {
        Pool storage pool = pools[_poolId];
        tax = teamTax(pool);
    }

    function teamTax(Pool memory pool) internal view returns (uint256 tax) {
        tax = pool.totalWERUG.mul(teamPercent).div(100);
    }

    function checkRug(uint256 _poolId) public view returns (bool rug) {
        Pool storage pool = pools[_poolId];
        rug = hasRuged(pool);
    }

    function hasRuged(Pool memory pool) internal view returns (bool _hasRuged) {
        uint256 reserveA;
        uint256 reserveB;

        if (
            keccak256(abi.encodePacked(pool.exchange)) ==
            keccak256(abi.encodePacked(exchanges[0]))
        ) {
            (reserveA, reserveB) = getUniswapLiquidity(
                pool.tokenA,
                pool.tokenB
            );
        } else if (
            keccak256(abi.encodePacked(pool.exchange)) ==
            keccak256(abi.encodePacked(exchanges[1]))
        ) {
            (reserveA, reserveB) = getPancakeswapLiquidity(
                pool.tokenA,
                pool.tokenB
            );
        }

        IERC20Metadata tokenA = IERC20Metadata(pool.tokenA);
        uint256 _MINIMUMLIQUDITY_TOKEN = MINIMUMLIQUDITY_TOKEN *
            10**tokenA.decimals();

        if (reserveA <= _MINIMUMLIQUDITY_TOKEN) {
            _hasRuged = true;
        } else if (reserveA > _MINIMUMLIQUDITY_TOKEN) {
            _hasRuged = false;
        }
    }

    function getUniswapLiquidity(address _tokenA, address _tokenB)
        public
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        address pairAddress = IUniswapV2Factory(uniswapRouter.factory())
            .getPair(_tokenA, _tokenB);
        if (pairAddress == address(0)) {
            reserveA = 0;
            reserveB = 0;
        }
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        (reserveA, reserveB, ) = pair.getReserves();
    }

    function getPancakeswapLiquidity(address _tokenA, address _tokenB)
        public
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        address pairAddress = IPancakeFactory(pancakeRouter.factory()).getPair(
            _tokenA,
            _tokenB
        );
        if (pairAddress == address(0)) {
            reserveA = 0;
            reserveB = 0;
        }
        IPancakePair pair = IPancakePair(pairAddress);
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        reserveA = uint256(reserve0);
        reserveB = uint256(reserve1);
    }
}
