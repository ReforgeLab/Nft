// SPDX-License-Identifier: MIT

module nft::marketplace_rule {
    use sui::transfer_policy::{
        Self as policy,
        TransferPolicy,
        TransferPolicyCap,
        TransferRequest
    };
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    // ===================== Constants =====================

    const ERR_INSUFFICIENT_PAYMENT: u64 = 200;
    const ERR_INVALID_MARKETPLACE_FEE: u64 = 201;

    // ===================== Structs =====================

    /// Rule witness type for marketplace transactions
    public struct MarketplaceRule has drop {}

    /// Configuration for marketplace rule
    public struct MarketplaceConfig has store, drop {
        /// Fee percentage (in basis points, e.g., 250 = 2.5%)
        fee_bps: u64,
        /// Marketplace administrator address
        admin: address,
    }

    // ===================== Functions =====================

    /// Add marketplace rule to transfer policy
    public fun add_rule<T>(
        policy: &mut TransferPolicy<T>,
        cap: &TransferPolicyCap<T>,
        fee_bps: u64,
        admin: address,
    ) {
        assert!(fee_bps <= 10000, ERR_INVALID_MARKETPLACE_FEE); // Max 100%
        policy::add_rule(
            MarketplaceRule {},
            policy,
            cap,
            MarketplaceConfig { fee_bps, admin }
        );
    }

    /// Pay marketplace fee during transfer
    public fun pay_fee<T>(
        policy: &mut TransferPolicy<T>,
        request: &mut TransferRequest<T>,
        payment: Coin<SUI>,
        sale_price: u64,
        ctx: &mut TxContext,
    ) {
        let config: &MarketplaceConfig = policy::get_rule(MarketplaceRule {}, policy);
        
        // Calculate marketplace fee
        let fee_amount = (sale_price * config.fee_bps) / 10000;
        
        // Verify payment covers the fee
        assert!(coin::value(&payment) >= fee_amount, ERR_INSUFFICIENT_PAYMENT);

        // Split payment if needed
        let fee_coin = if (coin::value(&payment) == fee_amount) {
            payment
        } else {
            coin::split(&mut payment, fee_amount, ctx)
        };

        // Transfer fee to marketplace admin
        transfer::public_transfer(fee_coin, config.admin);

        // Return remaining payment to sender if any
        if (coin::value(&payment) > 0) {
            transfer::public_transfer(payment, ctx.sender());
        } else {
            coin::destroy_zero(payment);
        };

        // Mark request as paid
        policy::add_receipt(MarketplaceRule {}, request);
    }

    /// Remove marketplace rule from transfer policy
    public fun remove_rule<T>(
        policy: &mut TransferPolicy<T>,
        cap: &TransferPolicyCap<T>,
    ) {
        policy::remove_rule<T, MarketplaceRule, MarketplaceConfig>(
            policy,
            cap,
        );
    }

    /// Get marketplace configuration
    public fun get_config<T>(policy: &TransferPolicy<T>): &MarketplaceConfig {
        policy::get_rule(MarketplaceRule {}, policy)
    }
}