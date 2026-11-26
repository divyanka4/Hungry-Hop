# Delivery Promise and Measurement

Applies to: all HungryHop orders

## Delivery classes

HungryHop has two delivery classes. Each order carries its class in `delivery_class` and the promise shown at checkout in `promised_minutes`: a 10 minute promise, or a 30, 35, 40 or 45 minute promise.

## When the promise clock starts

The promise clock starts when the restaurant **accepts** the order (the `accepted` event), not when the customer places it. Time spent waiting for the restaurant to accept is not counted.

## Minutes past promise

Minutes past promise = (delivered time minus accepted time) in minutes, minus `promised_minutes`. A negative value means the food arrived early. Use the full timestamps, seconds included, and do not round before you compare with a threshold.

## Late thresholds by class

Each delivery class has its own lateness threshold and its own coupon, written in its own compensation SOP. Never apply one class's threshold to the other class.

## Cancelled orders

A cancelled order has no delivery time, so it is never late. Refunds for cancelled orders are covered by the cancellations SOP.
