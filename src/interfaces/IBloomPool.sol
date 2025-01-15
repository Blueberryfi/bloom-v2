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

/**
 * @title IBloomPool
 * @notice Interface for Bloom V2's Pool
 */
interface IBloomPool {
    /*///////////////////////////////////////////////////////////////
                            Structs
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Struct representing the collateral backed by a TBY.
     * @param assetAmount The amount of underlying asset collateral.
     * @param currentRwaAmount The amount of rwa asset collateral at the current time.
     * @param originalRwaAmount The amount of rwa asset collateral at the start of the TBY (will only be set at the end of the TBYs maturity for accounting purposes)
     */
    struct TbyCollateral {
        uint128 assetAmount;
        uint128 currentRwaAmount;
        uint128 originalRwaAmount;
    }

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
    event OrderFilled(address indexed account, address indexed borrower, uint256 amount);

    /**
     * @notice Emitted when a user kills a lend order.
     * @param account The address of the user who created the lend order.
     * @param amount The amount of underlying assets returned to the user.
     */
    event OpenOrderKilled(address indexed account, uint256 amount);

    /**
     * @notice Emitted when a borrower borrows from a borrow module.
     * @param borrower The address of the borrower who borrowed.
     * @param tbyId The id of the TBY that was borrowed.
     * @param lCollateral The amount of lender collateral borrowed.
     * @param bCollateral The amount of borrower collateral posted to execute the transaction.
     */
    event Borrowed(address indexed borrower, uint256 indexed tbyId, uint256 lCollateral, uint256 bCollateral);

    /**
     * @notice Emitted when a borrower repays a TBY.
     * @param tbyId The id of the TBY that was repaid.
     * @param account The address of the account that repaid the loan.
     * @param rwaAmount The amount of RWA assets repaid.
     * @param assetAmount The amount of underlying assets received after repaying the RWA.
     * @param endRwaCollateral The amount of RWA collateral backed by the TBY after repaying the RWA.
     * @param endAssetCollateral The amount of underlying asset collateral backed by the TBY after repaying the RWA.
     */
    event Repaid(
        uint256 indexed tbyId,
        address indexed account,
        uint256 rwaAmount,
        uint256 assetAmount,
        uint256 endRwaCollateral,
        uint256 endAssetCollateral
    );

    /**
     * @notice Emitted when a Lender redeems their share of rewards from a TBY.
     * @param account The address of the lender redeeming.
     * @param id The unique identifier of the TBY being redeemed.
     * @param amount The amount of rewards being redeemed.
     */
    event LenderRedeemed(address indexed account, uint256 indexed id, uint256 amount);

    /**
     * @notice Emitted when a Borrower redeems their share of rewards from a TBY.
     * @param account The address of the borrower redeeming.
     * @param id The unique identifier of the TBY being redeemed.
     * @param amount The amount of rewards being redeemed.
     */
    event BorrowerRedeemed(address indexed account, uint256 indexed id, uint256 amount);

    /*///////////////////////////////////////////////////////////////
                            Write Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Opens a lend order for a user.
     * @dev Underlying assets will be transferred when executing the function.
     * @dev Users have the right at anytime to cancel their lend order and withdraw their assets.
     * @param amount Amount of underlying assets to lend.
     */
    function lendOrder(uint256 amount) external;

    /**
     * @notice Borrow lenders funds to purchase an RWA asset.
     * @dev Depending on which borrowModule is inputed, there might be additional KYC requirements to interact with this function.
     * @param lenders An array of lender addresses who have open lend orders.
     * @param module The address of the borrowModule that will be used to execute the RWA token purchase.
     * @param amount The amount of underlying assets that the borrower is borrowering.
     * @return tbyId The TBY Id that was minted to lenders.
     * @return lCollateral Total amount of lender collateral borrowed.
     * @return bCollateral Total amount of borrower collateral posted to execute the transaction.
     */
    function borrow(address[] memory lenders, address module, uint256 amount)
        external
        payable
        returns (uint256 tbyId, uint256 lCollateral, uint256 bCollateral);

    /**
     * @notice Repays all borrowed funds + collateral for a given TBY.
     * @dev This function is a permissionless function that can be called by anyone. Due to positions being stored in the borrowModule,
     *      borrower repayments can be executed by anyone.
     * @dev This function will automatically repay the maximum amount possible for a given tbyId.
     * @param tbyId The id of the TBY to repay.
     */
    function repay(uint256 tbyId) external;

    /**
     * @notice Redeem the lender's share of rewards generated from the TBY at its maturity.
     * @dev Rewards generated from TBYs are only claimable by the holder of the TBY at maturity.
     * @param id The id of the TBY to redeem.
     * @param amount The amount of TBYs to redeem.
     * @return reward The amount of rewards for the lender.
     */
    function redeemLender(uint256 id, uint256 amount) external returns (uint256 reward);

    /**
     * @notice Redeem the borrowers's share of rewards generated from the TBY at its maturity.
     * @dev Rewards generated from TBYs are only claimable by the holder of the TBY at maturity.
     * @param id The id of the TBY to redeem.
     * @return reward The amount of rewards for the borrower.
     */
    function redeemBorrower(uint256 id) external returns (uint256 reward);

    /**
     * @notice Allows users to cancel their open lend order and withdraw their underlying assets.
     * @param amount The amount of underlying assets to remove from your order.
     */
    function killOpenOrder(uint256 amount) external;

    /*///////////////////////////////////////////////////////////////
                            View Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the address of the underlying asset of the pool.
    function asset() external view returns (address);

    /// @notice Returns the number of decimals of the underlying asset.
    function assetDecimals() external view returns (uint8);

    /// @notice Returns the current total depth of open orders.
    function openDepth() external view returns (uint256);

    /**
     * @notice Returns the total amount of underlying assets in open orders for a users account.
     * @param account The address of the user to get the number of open orders for.
     */
    function amountOpen(address account) external view returns (uint256);

    /// @notice The minimum size of an order.
    function minOrderSize() external view returns (uint256);

    /// @notice Returns the last minted TBY id.
    function lastMintedId() external view returns (uint256);

    /// @notice Returns whether a given address is a borrowModule.
    function isBorrowModule(address module) external view returns (bool);

    /// @notice Returns the address of the borrowModule for a given TBY id.
    function tbyModule(uint256 id) external view returns (address);
}
