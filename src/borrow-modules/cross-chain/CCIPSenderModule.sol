// SPDX-License-Identifier: MIT
/*
██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
*/
pragma solidity 0.8.27;

import {CCIPReceiver} from "@chainlink/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/ccip/libraries/Client.sol";
import {SafeERC20, IERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IRouterClient} from "@chainlink/ccip/interfaces/IRouterClient.sol";

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {BorrowModule} from "@bloom-v2/borrow-modules/BorrowModule.sol";
import {ICCIPModule} from "@bloom-v2/interfaces/ICCIPModule.sol";

/**
 * @title CCIPSenderModule
 * @notice A borrow module that allows for cross-chain borrowing using CCIP.
 * @dev This module still needs to be implemented for a specific protocol. Its only functionality is to send borrowed assets and messages to destination borrow modules.
 */
abstract contract CCIPSenderModule is ICCIPModule, CCIPReceiver, BorrowModule {
    using SafeERC20 for IERC20;

    /*///////////////////////////////////////////////////////////////
                                Storage    
    //////////////////////////////////////////////////////////////*/

    /// @notice The address of the CCIP router.
    IRouterClient internal immutable _ccipRouter;

    /// @notice The address of the corresponding CCIPReceiverModule.
    address internal immutable _ccipReceiver;

    /// @notice The destination chain ID for the corresponding CCIPReceiverModule.
    uint64 internal immutable _dstChainId;

    /// @notice The gas limit for the CCIP message.
    CCIPGasLimits internal _gasLimits;

    /// @notice The number of messages sent.
    uint256 internal messageCount;

    /// @notice A mapping of message IDs to CCIPMessageData.
    mapping(uint256 => CCIPMessageData) internal _pendingMessages;

    /*///////////////////////////////////////////////////////////////
                                Constructor    
    //////////////////////////////////////////////////////////////*/

    constructor(
        address bloomPool,
        address bloomOracle,
        address rwa,
        uint256 initLeverage,
        uint256 initSpread,
        uint64 dstChainId_,
        address ccipRouter_,
        address ccipReceiver_,
        address owner
    ) CCIPReceiver(ccipRouter_) BorrowModule(bloomPool, bloomOracle, rwa, initLeverage, initSpread, owner) {
        require(dstChainId_ != 0, Errors.InvalidChainId());
        require(ccipReceiver_ != address(0) || ccipRouter_ != address(0), Errors.ZeroAddress());

        _dstChainId = dstChainId_;
        _ccipRouter = IRouterClient(ccipRouter_);
        _ccipReceiver = ccipReceiver_;
    }

    /*///////////////////////////////////////////////////////////////
                            Internal Functions    
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Purchases the RWA tokens with the underlying asset collateral and stores them within the contract.
     * @dev Developers must add an implementation for _afterBorrowMessage within the child contract.
     * @param borrower The address of the borrower.
     * @param totalCollateral The total amount of collateral being swapped in.
     * @param rwaAmount The amount of RWA tokens purchased.
     * @return The amount of RWA tokens purchased.
     */
    function _purchaseRwa(address borrower, uint256 totalCollateral, uint256 rwaAmount)
        internal
        virtual
        override
        returns (uint256)
    {
        Client.EVM2AnyMessage memory message = _buildMessage(MessageType.REPAY, borrower, totalCollateral, rwaAmount);
        _sendMessage(message);

        uint256 rwaPreBalance = _rwa.balanceOf(address(this));
        _afterBorrowMessage(rwaAmount);
        uint256 rwaPostBalance = _rwa.balanceOf(address(this));

        return rwaPostBalance - rwaPreBalance;
    }

    /**
     * @notice Repays the RWA tokens to the issuer in exchange for the underlying asset collateral.
     * @dev Developers must add an implementation for _beforeRepayMessage within the child contract.
     * @param rwaAmount The amount of RWA tokens being repaid.
     * @return The amount of underlying asset collateral being received.
     */
    function _repayRwa(uint256 rwaAmount) internal virtual override returns (uint256) {
        _beforeRepayMessage(rwaAmount);
        uint256 assetAmount = _bloomOracle.getQuote(rwaAmount, address(_rwa), address(_asset));
        // Address of the borrower is irrelavent for loan repayments as this should be handle within the child contract of the ReceiverModule.
        Client.EVM2AnyMessage memory message = _buildMessage(MessageType.REPAY, address(0), assetAmount, rwaAmount);
        _sendMessage(message);

        return assetAmount;
    }

    /**
     * @notice Builds a CCIP message that can be used for either borrowing cross-chain RWA assets or repaying such loans.
     * @param msgType Either a BORROW or REPAY MessageType.
     * @param borrower The address of the borrower who is executing the transaction. Will always be address(0) on repayments.
     * @param assetAmount The amount of underlying asset either being used to purchase the RWA, or expected to be returned on repayment.
     * @param rwaAmount The amount of RWA either being purchased or repaid in the transaction.
     */
    function _buildMessage(MessageType msgType, address borrower, uint256 assetAmount, uint256 rwaAmount)
        internal
        returns (Client.EVM2AnyMessage memory)
    {
        // Create struct to store all necessary extra data for the CCIP message.
        CCIPMessageData memory ccipMsgData = CCIPMessageData({
            messageId: messageCount,
            messageType: msgType,
            borrower: borrower,
            assetAmount: assetAmount,
            rwaAmount: rwaAmount
        });

        _pendingMessages[messageCount] = ccipMsgData;

        // Encode data into bytes
        bytes memory data = abi.encode(ccipMsgData);

        // Build a CCIP EVM2AnyMessage
        return Client.EVM2AnyMessage({
            receiver: abi.encode(_ccipReceiver),
            data: data,
            tokenAmounts: _getTokensToBridge(msgType, assetAmount),
            feeToken: address(0), // address(0) is the native token setting
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV2({gasLimit: gasLimit(msgType), allowOutOfOrderExecution: false})
            )
        });
    }

    /**
     * @notice Receives the confirmation message for CCIP Messages
     * @param message The Cross-chain CCIP message in the form of a EVM2AnyMessage.
     */
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        require(
            keccak256(message.sender) == keccak256(abi.encode(_ccipReceiver))
                && message.sourceChainSelector == _dstChainId,
            Errors.InvalidSender()
        );

        CCIPMessageData memory ccipMsgData = abi.decode(message.data, (CCIPMessageData));

        uint256 messageId = ccipMsgData.messageId;

        if (messageId == _pendingMessages[messageId].messageId) {
            delete _pendingMessages[messageId];
        } else {
            revert Errors.InvalidId();
        }
    }

    /**
     * @notice Creates an array of tokens that will be bridged within the CCIP message.
     * @dev The array is in the form of a EVMTokenAmount struct.
     * @param msgType Either a BORROW or REPAY MessageType.
     * @param assetAmount The amount of underlying asset being used in the operation.
     */
    function _getTokensToBridge(MessageType msgType, uint256 assetAmount)
        internal
        view
        returns (Client.EVMTokenAmount[] memory tokenAmounts)
    {
        if (msgType == MessageType.BORROW) {
            tokenAmounts = new Client.EVMTokenAmount[](1);
            tokenAmounts[0] = Client.EVMTokenAmount({token: address(_asset), amount: assetAmount});
        } else {
            tokenAmounts = new Client.EVMTokenAmount[](0); // No tokens to send if we are repaying a loan
        }
    }

    /**
     * @notice Executes the sending the message cross-chain via the CCIP Router.
     * @param message The Cross-chain CCIP message in the form of a EVM2AnyMessage.
     */
    function _sendMessage(Client.EVM2AnyMessage memory message) internal virtual {
        uint256 fees = _ccipRouter.getFee(_dstChainId, message);
        _ccipRouter.ccipSend{value: fees}(_dstChainId, message);
        messageCount++;
    }

    /*///////////////////////////////////////////////////////////////
                            Admin Functions    
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the gas limits for each type of transaction.
     * @param borrowGasLimit_ The gas limit for borrow operations.
     * @param repayGasLimit_ The gas limit for repay operations.
     */
    function setGasLimits(uint128 borrowGasLimit_, uint128 repayGasLimit_) external onlyOwner {
        _gasLimits = CCIPGasLimits({borrowGasLimit: borrowGasLimit_, repayGasLimit: repayGasLimit_});
    }

    /*///////////////////////////////////////////////////////////////
                            View Functions    
    //////////////////////////////////////////////////////////////*/

    /// @notice The gas limit for the CCIP message.
    function gasLimit(MessageType messageType) public view returns (uint256) {
        if (messageType == MessageType.BORROW) {
            return uint256(_gasLimits.borrowGasLimit);
        } else {
            return uint256(_gasLimits.repayGasLimit);
        }
    }

    /*///////////////////////////////////////////////////////////////
                            Internal Interface    
    //////////////////////////////////////////////////////////////*/

    function _afterBorrowMessage(uint256 rwaAmount) internal virtual;

    function _beforeRepayMessage(uint256 rwaAmount) internal virtual;
}
