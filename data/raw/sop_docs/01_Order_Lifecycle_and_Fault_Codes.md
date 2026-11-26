# Order Lifecycle and Fault Codes

Applies to: all HungryHop orders

## Order events

Every order is a stream of events. `placed`: the customer pays and places the order. `accepted`: the restaurant accepts it. `picked_up`: a rider collects the food. `delivered`: the rider hands the food over. `cancelled`: the order is stopped before delivery. A finished order ends with exactly one of `delivered` or `cancelled`.

## Order status

An order's status is `delivered` when it has a `delivered` event and `cancelled` when it has a `cancelled` event. Always read the event time `event_ts`, never the order in which files arrived: events can arrive days late and can be sent twice.

## Issue codes

Support agents code every ticket with one issue code: `KITCHEN_DELAY` (the food was not ready when the rider arrived), `WRONG_ITEM` (a wrong or missing item), `RIDER_DELAY` (the rider was slow or took a wrong route), `DAMAGED_IN_TRANSIT` (the food was spilled or crushed on the way), `CUSTOMER_UNAVAILABLE` (the customer could not be reached or gave a wrong address) and `OTHER` (anything else).

## Who is at fault

The issue code decides the fault. `KITCHEN_DELAY` and `WRONG_ITEM` put the fault on the **restaurant**. `RIDER_DELAY` and `DAMAGED_IN_TRANSIT` put the fault on the **rider**. `CUSTOMER_UNAVAILABLE` puts the fault on the **customer**. `OTHER` means the fault is **unknown**.

## The four facts

Every compensation decision uses exactly four facts: the fault, whether the order was delivered, whether it was late beyond the threshold of its own delivery class, and the customer's membership tier.
