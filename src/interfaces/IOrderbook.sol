// SPDX-License-Identifier: MIT
/*
██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
*/
pragma solidity ^0.8.26;

/**
 * @title IOrderbook
 * @notice Interface for the Orderbook within Bloom v2
 */
interface IOrderbook {
    /*///////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Emitted when a user creates a lend order.
     * @param account The address of the user who created the lend order.
     * @param amount The amount of underlying assets lent.
     */
    event OrderCreated(address indexed account, uint256 amount);

    /**
     * @notice Emitted when a borrower fills a lend order.
     * @param account The address of the user whos order was feeled.
     * @param borrower The address of the borrower who filled the order.
     * @param leverage The leverage amount for the borrower at the time the order was matched.
     * @param amount The amount of underlying assets filled in the order.
     */
    event OrderFilled(address indexed account, address indexed borrower, uint256 leverage, uint256 amount);

    /**
     * @notice Emitted when a user kills a lend order.
     * @param account The address of the user who created the lend order.
     * @param id The unique identifier of the lend order.
     * @param amount The amount of underlying assets returned to the user.
     */
    event OrderKilled(address indexed account, uint256 id, uint256 amount);

    /*///////////////////////////////////////////////////////////////
                                Structs
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Struct to store the details of a lend order that has been matched.
     * @param borrower The address of the borrower who filled the order.
     * @param leverage The leverage amount for the borrower at the time the order was matched.
     * @param amount The amount of underlying assets filled in the order.
     */
    struct MatchOrder {
        address borrower;
        uint256 leverage;
        uint256 amount;
    }

    /*///////////////////////////////////////////////////////////////
                                Enums
    //////////////////////////////////////////////////////////////*/

    /// @notice Enum to differentiate between the different types of orders
    enum OrderType {
        OPEN, // All open orders will have an id of 0
        MATCHED, // All matched orders will have an id of 1
        LIVE // All live orders will have a blended id of 2 and the orders start timestamp

    }

    /*///////////////////////////////////////////////////////////////
                            Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Opens a lend order for a user.
     * @dev Underlying assets will be transferred when executing the function.
     * @dev Users have the right at anytime to cancel their lend order and withdraw their assets.
     * @param amount Amount of underlying assets to lend.
     */
    function lendOrder(uint256 amount) external;

    /**
     * @notice Allows borrowers to fill lend orders with a specified amount of underlying assets.
     * @dev Borrowers can only fill orders if they have passed KYC verification.
     * @param account Address of the lend order to fill.
     * @param amount The maximum amount of underlying assets to fill orders with.
     * @return filled The total amount of underlying assets filled.
     */
    function fillOrder(address account, uint256 amount) external returns (uint256 filled);

    /**
     * @notice Allows borrowers to fill lend orders with a specified amount of underlying assets.
     * @dev Borrowers can only fill orders if they have passed KYC verification.
     * @param accounts An array of order addresses to fill.
     * @param amount The maximum amount of underlying assets to fill orders with.
     * @return filled The total amount of underlying assets filled.
     */
    function fillOrders(address[] calldata accounts, uint256 amount) external returns (uint256 filled);

    /**
     * @notice Allows users to cancel their lend orders and withdraw their underlying assets.
     * @dev If an order is matched by multiple borrowers, borrower matches must be closed fully in a LIFO manner.
     * @param orderId The unique identifier of the lend order.
     * @param amount The amount of underlying assets to remove from your order.
     * @return amountKilled The total amount of underlying assets removed from the order.
     */
    function killOrder(uint256 orderId, uint256 amount) external returns (uint256 amountKilled);

    /// @notice Returns the current leverage value for the borrower scaled to 1e4.
    function leverage() external view returns (uint256);

    /// @notice Returns the current total depth of open orders.
    function openDepth() external view returns (uint256);

    /// @notice Returns the current total depth of matched orders.
    function matchedDepth() external view returns (uint256);

    /**
     * @notice Returns the matched order details for a users account.
     * @param account The address of the user to get matched orders for.
     * @param index The index of the matched order to get.
     * @return matchOrder The matched order details in the form of a MatchOrder struct.
     */
    function matchOrder(address account, uint256 index) external view returns (MatchOrder memory matchOrder);

    /**
     * @notice Returns the number of matched orders for a users account.
     * @param account The address of the user to get the number of matched orders for.
     */
    function matchOrderCount(address account) external view returns (uint256);
}
