module nft::render_fee_rule;
use sui::transfer_policy::{
Self,
TransferPolicy,
TransferPolicyCap,
TransferRequest};
use sui::coin::{Self, Coin};
use sui::sui::SUI;





const ERR_INSUFFICIENT_PAYMENT: u64 = 4;
// Rule witness type
public struct RenderFeeRule has drop {}

// Configuration for the rule
public struct RenderFeeConfig has store, drop {
fee_amount: u64 // Authorized domain for the image service
}



public fun add_rule<T>(
policy: &mut TransferPolicy<T>,
cap: &TransferPolicyCap<T>,
fee_amount: u64,
) {
transfer_policy::add_rule(RenderFeeRule {}, policy, cap, RenderFeeConfig {
    fee_amount
});
}

public fun pay<T>(
policy: &mut TransferPolicy<T>,
request: &mut TransferRequest<T>,
payment: Coin<SUI>,
) {
let config: &RenderFeeConfig = transfer_policy::get_rule(RenderFeeRule{},policy);
    

// Verify payment
assert!(coin::value(&payment) >= config.fee_amount, ERR_INSUFFICIENT_PAYMENT);

transfer_policy::add_to_balance(RenderFeeRule {}, policy, payment);
// Verify image URL domain

// Mark request as paid
transfer_policy::add_receipt( RenderFeeRule {}, request);
}
