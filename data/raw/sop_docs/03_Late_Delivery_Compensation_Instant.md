# Late Delivery Compensation

Applies to: Instant orders (10 minute promise) only

## Overview

This SOP says when an Instant order counts as late and which coupon the customer gets. A twin SOP with the same headings uses different numbers for the other delivery class, so always check the Applies to line first.

## When an order counts as late

An Instant order is **late** when it is delivered **more than 5 minutes** past its promise (minutes past promise greater than 5), measured from the `accepted` event. Exactly 5 minutes or less is on time.

## Coupon amount

A late Instant order earns a base coupon of **Rs 40**. The base coupon is then scaled by the customer's membership tier when the restaurant or the rider is at fault.

## When no coupon is given

There is no coupon when the customer is at fault, and no coupon when the Instant order was on time. A cancelled Instant order gets a refund, never a coupon.

## How the coupon is issued

The coupon goes into the customer's HungryHop wallet within 24 hours and can be used for 30 days on any order.
