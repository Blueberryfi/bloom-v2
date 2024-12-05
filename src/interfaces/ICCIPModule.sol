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

interface ICCIPModule {
    /*///////////////////////////////////////////////////////////////
                                Enums
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Enum representing the type of message being sent.
     * @param BORROW The message type for a borrow message.
     * @param REPAY The message type for a repay message.
     */
    enum MessageType {
        BORROW,
        REPAY
    }

    /*///////////////////////////////////////////////////////////////
                                Structs
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Struct representing encoded data for a CCIP message.
     * @param messageId The ID of the message being sent.
     * @param messageType The type of message being sent.
     * @param borrower The address of the borrower sending the message.
     * @param assetAmount The amount of asset being borrowed or repaid.
     * @param rwaAmount The amount of RWA being purchased or repaid.
     */
    struct CCIPMessageData {
        uint256 messageId;
        MessageType messageType;
        address borrower;
        uint256 assetAmount;
        uint256 rwaAmount;
    }

    /**
     * @notice Struct representing the gas limits for a CCIP message.
     * @param borrowGasLimit The gas limit for a borrow message.
     * @param repayGasLimit The gas limit for a repay message.
     */
    struct CCIPGasLimits {
        uint128 borrowGasLimit;
        uint128 repayGasLimit;
    }
}
