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
     * @param amount The amount of underlying assets returned to the user.
     */
    event OrderKilled(address indexed account, uint256 amount);

    /**
     * @notice Emitted when idle capital is increased.
     * @param account Address of the borrowers account who's idle capital is increased.
     * @param amount Amount of idle capital increased.
     */
    event IdleCapitalIncreased(address indexed account, uint256 amount);

    /**
     * @notice Emitted when idle capital is decreased.
     * @param account Address of the borrowers account who's idle capital is decreased.
     * @param amount Amount of idle capital decreased.
     */
    event IdleCapitalDecreased(address indexed account, uint256 amount);

    /**
     * @notice Emitted when idle capital is withdrawn from the system.
     * @param account Address of the borrowers account who's idle capital is withdrawn.
     * @param amount Amount of idle capital withdrawn.
     */
    event IdleCapitalWithdrawn(address indexed account, uint256 amount);

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
     * @notice Allows users to cancel their open lend order and withdraw their underlying assets.
     * @param amount The amount of underlying assets to remove from your order.
     */
    function killOpenOrder(uint256 amount) external;

    /**
     * @notice Allows users to cancel their match lend orders and withdraw their underlying assets.
     * @dev If an order is matched by multiple borrowers, borrower matches must be closed fully in a LIFO manner.
     * @param amount The amount of underlying assets to remove from your order.
     * @return totalRemoved The total amount of underlying assets removed from the order.
     */
    function killMatchOrder(uint256 amount) external returns (uint256 totalRemoved);

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
     * @return The matched order details in the form of a MatchOrder struct.
     */
    function matchedOrder(address account, uint256 index) external view returns (MatchOrder memory);

    /**
     * @notice Returns the total amount of underlying assets in open orders for a users account.
     * @param account The address of the user to get the number of open orders for.
     */
    function amountOpen(address account) external view returns (uint256);

    /**
     * @notice Returns the total amount of underlying assets in matched orders for a users account.
     * @param account The address of the user to get the number of open orders for.
     */
    function amountMatched(address account) external view returns (uint256 amount);

    /**
     * @notice Returns the number of matched orders for a users account.
     * @param account The address of the user to get the number of matched orders for.
     */
    function matchedOrderCount(address account) external view returns (uint256);

    /**
     * @notice Returns the idle capital of the borrower.
     * @param account Address of the borrower to query idle capital.
     * @return The idle capital of the borrower.
     */
    function idleCapital(address account) external view returns (uint256);

    /**
     * @notice Decreases the idle capital of the borrower.
     * @param amount Amount of idle capital to withdraw.
     */
    function withdrawIdleCapital(uint256 amount) external;
}
