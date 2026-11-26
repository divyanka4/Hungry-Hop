# Cancellations and Refunds

Applies to: cancelled HungryHop orders

## Refund rule

When an order is not delivered (it ends with a `cancelled` event) and the customer is not at fault, HungryHop refunds **100% of the order value**. The membership tier does not change a refund.

## Customer-caused cancellations

When the customer is at fault (`CUSTOMER_UNAVAILABLE`), a cancelled order gets no refund.

## Refund timeline

Refunds reach the original payment method within 5 to 7 working days. Wallet refunds arrive at once.

## Refunds and coupons together

An order gets a refund or a coupon, never both. A refund always replaces a coupon.
