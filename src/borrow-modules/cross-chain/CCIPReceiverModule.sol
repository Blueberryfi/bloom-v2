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

import {Client} from "@chainlink/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/ccip/applications/CCIPReceiver.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IRouterClient} from "@chainlink/ccip/interfaces/IRouterClient.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";
import {ICCIPModule} from "@bloom-v2/interfaces/ICCIPModule.sol";

/**
 * @title CCIPReceiverModule
 * @notice The contract that will be deployed on destination chains to receive assets and messages from the sender module.
 * @dev This module still needs to be implemented for a specific protocol. Its only functionality is to receive borrowed assets and messages from the sender module.
 */
abstract contract CCIPReceiverModule is ICCIPModule, CCIPReceiver, Ownable {
    /*///////////////////////////////////////////////////////////////
                                Storage    
    //////////////////////////////////////////////////////////////*/

    /// @notice The address of the asset being used to purchase RWA.
    address internal immutable _asset;

    /// @notice The address of the RWA being purchased.
    address internal immutable _rwa;

    /// @notice The address of the LINK token.
    address internal immutable _linkToken;

    /// @notice The address of the corresponding CCIPSenderModule.
    address internal immutable _ccipSender;

    /// @notice The source chain ID for the corresponding CCIPSenderModule.
    uint64 internal immutable _srcChainId;

    /// @notice The gas limit for the CCIP message.
    CCIPGasLimits internal _gasLimits;

    /*///////////////////////////////////////////////////////////////
                                Constructor    
    //////////////////////////////////////////////////////////////*/

    constructor(
        address asset_,
        address rwa_,
        address linkToken_,
        uint64 srcChainId_,
        address ccipRouter,
        address ccipSender_,
        address owner_
    ) CCIPReceiver(ccipRouter) Ownable(owner_) {
        require(
            asset_ != address(0) && rwa_ != address(0) && linkToken_ != address(0) && ccipRouter != address(0)
                && ccipSender_ != address(0),
            Errors.ZeroAddress()
        );
        _srcChainId = srcChainId_;
        _ccipSender = ccipSender_;
        _asset = asset_;
        _rwa = rwa_;
        _linkToken = linkToken_;
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

    /**
     * @notice Deposits LINK into the contract.
     * @param amount The amount of LINK to deposit.
     */
    function depositLink(uint256 amount) external onlyOwner {
        IERC20(_linkToken).transferFrom(msg.sender, address(this), amount);
    }

    /**
     * @notice Withdraws LINK from the contract.
     * @param amount The amount of LINK to withdraw.
     */
    function withdrawLink(uint256 amount) external onlyOwner {
        IERC20(_linkToken).transfer(msg.sender, amount);
    }

    /*///////////////////////////////////////////////////////////////
                            Internal Functions    
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Custom receive logic that is executed by the CCIP router contract
     * @param any2EvmMessage The Any2EVMMessage struct returned by CCIP Messages
     */
    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override {
        require(
            keccak256(any2EvmMessage.sender) == keccak256(abi.encode(_ccipSender))
                && any2EvmMessage.sourceChainSelector == _srcChainId,
            Errors.InvalidSender()
        );

        _routeMessage(any2EvmMessage);
    }

    /**
     * @notice Routes the incoming Chainlink CCIP message to the proper handler function
     * @param any2EvmMessage The Any2EVMMessage struct returned by CCIP Messages
     */
    function _routeMessage(Client.Any2EVMMessage memory any2EvmMessage) internal {
        CCIPMessageData memory messageData = abi.decode(any2EvmMessage.data, (CCIPMessageData));
        if (messageData.messageType == MessageType.BORROW) {
            _handleBorrow(messageData);
        } else {
            _handleRepay(messageData);
        }
    }

    /**
     * @notice Sends a confirmation message to the CCIPSenderModule on the source chain.
     * @param message The CCIP message to be sent.
     */
    function _sendConfirmation(Client.EVM2AnyMessage memory message) internal {
        IRouterClient router = IRouterClient(i_ccipRouter);

        uint256 fees = router.getFee(_srcChainId, message);

        if (fees > IERC20(_linkToken).balanceOf(address(this))) {
            revert Errors.InsufficientBalance();
        }

        IERC20(_linkToken).approve(i_ccipRouter, fees);
        router.ccipSend(_srcChainId, message);
    }

    /**
     * @notice Executes the purchase and of the RWA token with the borrowed funds.
     * @param messageData All message data sent within the CCIP message, formatted into the CCIPMessageData struct.
     */
    function _handleBorrow(CCIPMessageData memory messageData) internal {
        IERC20 rwa_ = IERC20(_rwa);

        uint256 rwaStartingBalance = rwa_.balanceOf(address(this));
        _purchaseRwa(messageData.borrower, messageData.assetAmount, messageData.rwaAmount);
        uint256 rwaReceived = rwa_.balanceOf(address(this)) - rwaStartingBalance;

        Client.EVM2AnyMessage memory message = _buildMessage(
            messageData.messageId, MessageType.REPAY, messageData.borrower, messageData.assetAmount, rwaReceived
        );
        _sendConfirmation(message);
    }

    /**
     * @notice Executes the repayment of the loan.
     * @param messageData All message data sent within the CCIP message, formatted into the CCIPMessageData struct.
     */
    function _handleRepay(CCIPMessageData memory messageData) internal {
        IERC20 asset_ = IERC20(_asset);

        uint256 assetStartingBalance = asset_.balanceOf(address(this));
        _repayRwa(messageData.borrower, messageData.rwaAmount, messageData.assetAmount);
        uint256 assetReceived = asset_.balanceOf(address(this)) - assetStartingBalance;

        Client.EVM2AnyMessage memory message = _buildMessage(
            messageData.messageId, MessageType.REPAY, messageData.borrower, assetReceived, messageData.rwaAmount
        );
        _sendConfirmation(message);
    }

    /**
     * @notice Builds a CCIP message that can be used for either borrowing cross-chain RWA assets or repaying such loans.
     * @param messageId The ID of the message being sent.
     * @param msgType Either a BORROW or REPAY MessageType.
     * @param borrower The address of the borrower who is executing the transaction. Will always be address(0) on repayments.
     * @param assetAmount The amount of underlying asset either being used to purchase the RWA, or expected to be returned on repayment.
     * @param rwaAmount The amount of RWA either being purchased or repaid in the transaction.
     */
    function _buildMessage(
        uint256 messageId,
        MessageType msgType,
        address borrower,
        uint256 assetAmount,
        uint256 rwaAmount
    ) internal view returns (Client.EVM2AnyMessage memory) {
        // Create struct to store all necessary extra data for the CCIP message.
        CCIPMessageData memory ccipMsgData = CCIPMessageData({
            messageId: messageId,
            messageType: msgType,
            borrower: borrower,
            assetAmount: assetAmount,
            rwaAmount: rwaAmount
        });

        // Encode data into bytes
        bytes memory data = abi.encode(ccipMsgData);

        // Build a CCIP EVM2AnyMessage
        return Client.EVM2AnyMessage({
            receiver: abi.encode(_ccipSender),
            data: data,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            feeToken: _linkToken,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV2({gasLimit: gasLimit(msgType), allowOutOfOrderExecution: false})
            )
        });
    }
    /*///////////////////////////////////////////////////////////////
                            Internal Interface    
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Custom RWA purchase logic that integrators must implement within the child contract.
     * @param borrower Address of the borrower who is executing this purchase.
     * @param assetAmount The amount of assets being used to purchase the RWA token.
     * @param rwaAmount The amount of RWA the borrower is desiring to purchase.
     */
    function _purchaseRwa(address borrower, uint256 assetAmount, uint256 rwaAmount) internal virtual;

    /**
     * @notice Custom RWA repayment logic that integrators must implement within the child contract.
     * @param borrower Address of the borrower who is executing this purchase.
     * @param rwaAmount The amount of RWA the borrower is repaying.
     * @param assetAmount The amount of assets the borrower is expecting to be returned.
     */
    function _repayRwa(address borrower, uint256 rwaAmount, uint256 assetAmount) internal virtual;

    /*///////////////////////////////////////////////////////////////
                            View Functions    
    //////////////////////////////////////////////////////////////*/

    /// @notice The address of the asset being used to purchase RWA.
    function asset() external view returns (address) {
        return _asset;
    }

    /// @notice The address of the RWA being purchased.
    function rwa() external view returns (address) {
        return _rwa;
    }

    /// @notice The address of the corresponding CCIPSenderModule.
    function ccipSender() external view returns (address) {
        return _ccipSender;
    }

    /// @notice The source chain ID for the corresponding CCIPSenderModule.
    function srcChainId() external view returns (uint64) {
        return _srcChainId;
    }

    /// @notice The gas limit for the CCIP message.
    function gasLimit(MessageType messageType) public view returns (uint256) {
        if (messageType == MessageType.BORROW) {
            return uint256(_gasLimits.borrowGasLimit);
        } else {
            return uint256(_gasLimits.repayGasLimit);
        }
    }

    /*///////////////////////////////////////////////////////////////
                            General Functions    
    //////////////////////////////////////////////////////////////*/

    /// @notice Ability to receive Native currency payments
    receive() external payable {}
}
