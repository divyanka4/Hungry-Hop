# Membership Tiers and Coupon Scaling

Applies to: all HungryHop customers

## Membership tiers

Every customer is on one of three tiers: `free`, `hop_plus` (paid monthly) or `hop_pro` (paid yearly). The tier is stored on the customer record.

## Coupon multipliers

A late-delivery coupon is the base coupon times the tier multiplier: `free` **x1**, `hop_plus` **x1.5**, `hop_pro` **x2**.

## When the multiplier applies

The multiplier applies only when the restaurant or the rider is at fault. When the fault is unknown (issue code `OTHER`), the customer gets the base coupon with no multiplier.

## Customer fault

When the customer is at fault (issue code `CUSTOMER_UNAVAILABLE`), there is no coupon and no refund, whatever the tier.
