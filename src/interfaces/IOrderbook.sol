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
     * @param amount The amount of underlying assets filled in the order.
     */
    event OrderFilled(
        address indexed account,
        address indexed borrower,
        uint256 amount
    );

    /**
     * @notice Emitted when a user kills a lend order.
     * @param account The address of the user who created the lend order.
     * @param id The unique identifier of the lend order.
     * @param amount The amount of underlying assets returned to the user.
     */
    event OrderKilled(address indexed account, uint256 id, uint256 amount);

    /**
     * @notice Emitted when the borrowers leverage amount is updated
     * @param leverageBps The updated leverage amount for the borrower.
     */
    event LeverageBpsSet(uint256 leverageBps);

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
     * @param order Address of the lend order to fill.
     * @param amount The maximum amount of underlying assets to fill orders with.
     * @return filled The total amount of underlying assets filled.
     */
    function fillOrder(
        address order,
        uint256 amount
    ) external returns (uint256 filled);

    /**
     * @notice Allows borrowers to fill lend orders with a specified amount of underlying assets.
     * @dev Borrowers can only fill orders if they have passed KYC verification.
     * @param orders An array of order addresses to fill.
     * @param amount The maximum amount of underlying assets to fill orders with.
     * @return filled The total amount of underlying assets filled.
     */
    function fillOrders(
        address[] calldata orders,
        uint256 amount
    ) external returns (uint256 filled);

    /**
     * @notice Allows users to cancel their lend orders and withdraw their underlying assets.
     * @param orderId The unique identifier of the lend order.
     * @param amount The amount of underlying assets to remove from your order.
     */
    function killOrder(uint256 orderId, uint256 amount) external;

    /**
     * @notice Updates the leverage value for future borrower fills
     * @param leverageBps Updated leverage Bips
     */
    function setLeverageBps(uint256 leverageBps) external;

    /// @notice Returns the current leverage value for the borrower
    function leverageBps() external view returns (uint256);
}
