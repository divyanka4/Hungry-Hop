-- R6 — Star schema in hop.analytics + mv_orders metric view.
-- Dates span the frozen data window 2026-06-01..2026-08-31 (never current_date).

-- 1) Dimensions -----------------------------------------------------------------

CREATE OR REPLACE TABLE hop.analytics.dim_date AS
SELECT
  s.d                                         AS `date`,
  year(s.d)                                   AS `year`,
  quarter(s.d)                                AS `quarter`,
  month(s.d)                                 AS `month`,
  date_format(s.d, 'MMMM')                   AS month_name,
  dayofweek(s.d)                             AS day_of_week,
  dayofweek(s.d) IN (1, 7)                   AS is_weekend
FROM (SELECT explode(sequence(to_date('2026-06-01'), to_date('2026-08-31'), interval 1 day)) AS d) s;

-- contact-free customer attributes only (email/phone stay masked in hop.raw)
CREATE OR REPLACE TABLE hop.analytics.dim_customer AS
SELECT customer_id, city AS customer_city, tier AS customer_tier
FROM hop.raw.customers;

CREATE OR REPLACE TABLE hop.analytics.dim_zone AS
SELECT zone_id, zone_type
FROM hop.raw.zones;

-- current (open) restaurant version from the SCD2 history
CREATE OR REPLACE TABLE hop.analytics.dim_restaurant AS
SELECT
  restaurant_id,
  name AS restaurant_name,
  cuisine,
  zone_id AS restaurant_zone_id,
  rating AS restaurant_rating,
  is_active AS restaurant_is_active
FROM hop.silver.dim_restaurant_scd2
WHERE __END_AT IS NULL;

-- platform and cancelled_by live in silver (the 25-column gold contract excludes them)
CREATE OR REPLACE TABLE hop.analytics.fact_orders
CLUSTER BY (placed_date, delivery_class)
AS
SELECT
  g.order_id, g.customer_id, g.delivery_zone_id AS zone_id, g.restaurant_id, g.rider_id,
  g.status, g.delivery_class, s.platform, g.placed_date,
  g.placed_ts, g.accepted_ts, g.picked_up_ts, g.delivered_ts, g.cancelled_ts, s.cancelled_by,
  g.promised_minutes, g.order_value, g.placed_to_accepted_minutes, g.prep_minutes,
  g.actual_minutes, g.minutes_past_promise, g.restaurant_rating_at_order
FROM hop.gold.orders_enriched g
LEFT JOIN (SELECT order_id, platform, cancelled_by FROM hop.silver.orders) s
  ON g.order_id = s.order_id;

-- 3) Informational PK / FK constraints -------------------------------------------

-- CTAS leaves columns nullable; PK columns must be NOT NULL before constraints.
ALTER TABLE hop.analytics.dim_date        ALTER COLUMN `date`         SET NOT NULL;
ALTER TABLE hop.analytics.dim_customer    ALTER COLUMN customer_id    SET NOT NULL;
ALTER TABLE hop.analytics.dim_zone        ALTER COLUMN zone_id        SET NOT NULL;
ALTER TABLE hop.analytics.dim_restaurant ALTER COLUMN restaurant_id  SET NOT NULL;
ALTER TABLE hop.analytics.fact_orders     ALTER COLUMN order_id       SET NOT NULL;

ALTER TABLE hop.analytics.dim_date      ADD CONSTRAINT pk_dim_date      PRIMARY KEY (`date`);
ALTER TABLE hop.analytics.dim_customer  ADD CONSTRAINT pk_dim_customer  PRIMARY KEY (customer_id);
ALTER TABLE hop.analytics.dim_zone      ADD CONSTRAINT pk_dim_zone      PRIMARY KEY (zone_id);
ALTER TABLE hop.analytics.dim_restaurant ADD CONSTRAINT pk_dim_restaurant PRIMARY KEY (restaurant_id);
ALTER TABLE hop.analytics.fact_orders   ADD CONSTRAINT pk_fact_orders   PRIMARY KEY (order_id);

ALTER TABLE hop.analytics.fact_orders ADD CONSTRAINT fk_fact_customer   FOREIGN KEY (customer_id)   REFERENCES hop.analytics.dim_customer (customer_id);
ALTER TABLE hop.analytics.fact_orders ADD CONSTRAINT fk_fact_zone       FOREIGN KEY (zone_id)       REFERENCES hop.analytics.dim_zone (zone_id);
ALTER TABLE hop.analytics.fact_orders ADD CONSTRAINT fk_fact_restaurant FOREIGN KEY (restaurant_id) REFERENCES hop.analytics.dim_restaurant (restaurant_id);
ALTER TABLE hop.analytics.fact_orders ADD CONSTRAINT fk_fact_date       FOREIGN KEY (placed_date)  REFERENCES hop.analytics.dim_date (`date`);

-- 4) Metric view ------------------------------------------------------------------
-- Join keys are unique in every dim (verified before the rely assertions).

CREATE OR REPLACE VIEW hop.analytics.mv_orders
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
source: hop.analytics.fact_orders
comment: HungryHop order metrics over the R6 star schema
joins:
  - name: dim_date
    source: hop.analytics.dim_date
    on: source.placed_date = dim_date.`date`
    rely:
      at_most_one_match: true
  - name: dim_customer
    source: hop.analytics.dim_customer
    on: source.customer_id = dim_customer.customer_id
    rely:
      at_most_one_match: true
  - name: dim_zone
    source: hop.analytics.dim_zone
    on: source.zone_id = dim_zone.zone_id
    rely:
      at_most_one_match: true
  - name: dim_restaurant
    source: hop.analytics.dim_restaurant
    on: source.restaurant_id = dim_restaurant.restaurant_id
    rely:
      at_most_one_match: true
dimensions:
  - name: placed_date
    expr: source.placed_date
  - name: placed_month
    expr: DATE_TRUNC('month', source.placed_date)
  - name: delivery_class
    expr: source.delivery_class
  - name: status
    expr: source.status
  - name: platform
    expr: source.platform
  - name: customer_city
    expr: dim_customer.customer_city
  - name: customer_tier
    -- R8: reads dim_customer.tier (duplicate of customer_tier added for benchmark SQL compatibility)
    expr: dim_customer.tier
  - name: zone_type
    expr: dim_zone.zone_type
  - name: zone_city
    expr: dim_zone.city
  - name: restaurant_name
    expr: dim_restaurant.restaurant_name
  - name: is_weekend
    expr: dim_date.is_weekend
measures:
  - name: order_count
    expr: COUNT(1)
  - name: delivered_orders
    expr: COUNT(1) FILTER (WHERE status = 'delivered')
  - name: cancelled_orders
    expr: COUNT(1) FILTER (WHERE status = 'cancelled')
  - name: deliver_rate
    expr: (COUNT(1) FILTER (WHERE status = 'delivered')) / COUNT(1)
  - name: total_order_value
    expr: SUM(order_value)
  - name: avg_order_value
    expr: SUM(order_value) / COUNT(1)
  - name: avg_actual_minutes
    expr: AVG(actual_minutes)
  - name: late_orders
    expr: COUNT(1) FILTER (WHERE status = 'delivered' AND minutes_past_promise > 0)
  - name: late_rate
    expr: (COUNT(1) FILTER (WHERE status = 'delivered' AND minutes_past_promise > 0))
      / (COUNT(1) FILTER (WHERE status = 'delivered'))
  - name: avg_minutes_past_promise
    expr: AVG(minutes_past_promise)
$$;

-- 5) R8 — benchmark alignment (hop.raw/landing/genie_benchmarks.json) ---------------
-- Ground-truth SQL expects surrogate-key columns and dim_zone.city / dim_date
-- date_key+month_start / dim_customer.tier. All ADD COLUMN + backfill, no rewrites.

ALTER TABLE hop.analytics.dim_zone       ADD COLUMN city STRING;
ALTER TABLE hop.analytics.dim_zone       ADD COLUMN zone_sk STRING;
MERGE INTO hop.analytics.dim_zone t USING hop.raw.zones s ON t.zone_id = s.zone_id
WHEN MATCHED THEN UPDATE SET t.city = s.city, t.zone_sk = s.zone_id;

ALTER TABLE hop.analytics.dim_date       ADD COLUMN date_key INT;
ALTER TABLE hop.analytics.dim_date       ADD COLUMN month_start DATE;
UPDATE hop.analytics.dim_date SET date_key = CAST(date_format(`date`, 'yyyyMMdd') AS INT),
                                 month_start = DATE_TRUNC('MONTH', `date`);

ALTER TABLE hop.analytics.dim_customer   ADD COLUMN customer_sk STRING;
UPDATE hop.analytics.dim_customer SET customer_sk = customer_id;
ALTER TABLE hop.analytics.dim_customer   ADD COLUMN tier STRING;   -- ground truth uses c.tier
UPDATE hop.analytics.dim_customer SET tier = customer_tier;

ALTER TABLE hop.analytics.dim_restaurant ADD COLUMN restaurant_sk STRING;
UPDATE hop.analytics.dim_restaurant SET restaurant_sk = restaurant_id;

ALTER TABLE hop.analytics.fact_orders    ADD COLUMN placed_date_key INT;
ALTER TABLE hop.analytics.fact_orders    ADD COLUMN customer_sk STRING;
ALTER TABLE hop.analytics.fact_orders    ADD COLUMN zone_sk STRING;
ALTER TABLE hop.analytics.fact_orders    ADD COLUMN restaurant_sk STRING;
UPDATE hop.analytics.fact_orders SET
  placed_date_key = CAST(date_format(placed_date, 'yyyyMMdd') AS INT),
  customer_sk = customer_id, zone_sk = zone_id, restaurant_sk = restaurant_id;

-- Verification (all 13,152 rows carry every new column; all 10 ground-truth SQLs ran):
--   SELECT COUNT(*), COUNT(placed_date_key), COUNT(zone_sk), COUNT(customer_sk),
--          COUNT(restaurant_sk) FROM hop.analytics.fact_orders;
--   => 13152 / 13152 / 13152 / 13152 / 13152
--   All 10 ground-truth queries in genie_benchmarks.json execute unchanged.
