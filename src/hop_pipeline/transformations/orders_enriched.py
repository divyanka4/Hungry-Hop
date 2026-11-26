# R4 - policy-free gold orders_enriched: facts only, no decisions.
# Each order is joined to the restaurant version in force at placed_ts (SCD2 temporal join).
# NEVER add is_late, late, late_threshold_minutes, eligible, is_eligible, fault,
# compensation, compensation_type, coupon_amount, refund_amount, amount or reason_code here.
from pyspark import pipelines as dp
from pyspark.sql import functions as F


@dp.materialized_view(name="hop.gold.orders_enriched", comment="Policy-free gold orders enriched with customer, zone and restaurant facts")
# Reference pipeline datasets by their in-pipeline names so the dependency graph
# links this MV to `orders` and `dim_restaurant_scd2` (fully-qualified reads are
# treated as external tables and can refresh against stale snapshots).
def orders_enriched():
    orders = spark.read.table("orders")

    customers = (
        spark.read.table("hop.raw.customers")
        .select(
            "customer_id",
            F.col("city").alias("customer_city"),
            F.col("tier").alias("customer_tier"),
        )
    )
    zones = spark.read.table("hop.raw.zones").select(
        F.col("zone_id").alias("_zone_key"), F.col("zone_type").alias("zone_type"),
    )
    restaurants = spark.read.table("dim_restaurant_scd2").select(
        "restaurant_id", "name", "zone_id", "rating", "__START_AT", "__END_AT",
    )

    enriched = (
        orders
        .join(customers, "customer_id", "left")
        .join(zones, orders["zone_id"] == zones["_zone_key"], "left")
        .join(
            restaurants,
            (orders["restaurant_id"] == restaurants["restaurant_id"])
            & (restaurants["__START_AT"] <= orders["placed_ts"])
            & (restaurants["__END_AT"].isNull() | (restaurants["__END_AT"] > orders["placed_ts"])),
            "left",
        )
    )

    secs = lambda a, b: (F.unix_timestamp(F.col(a)) - F.unix_timestamp(F.col(b))).cast("double") / 60.0

    return enriched.select(
        orders["order_id"],
        "status",
        "delivery_class",
        F.col("promised_minutes").cast("int").alias("promised_minutes"),
        F.col("order_value").cast("double").alias("order_value"),
        "customer_id",
        "customer_city",
        "customer_tier",
        orders["zone_id"].alias("delivery_zone_id"),
        "zone_type",
        orders["restaurant_id"].alias("restaurant_id"),
        restaurants["name"].alias("restaurant_name"),
        restaurants["zone_id"].alias("restaurant_zone_id"),
        restaurants["rating"].alias("restaurant_rating_at_order"),
        "rider_id",
        "placed_ts",
        "accepted_ts",
        "picked_up_ts",
        "delivered_ts",
        "cancelled_ts",
        F.to_date("placed_ts").alias("placed_date"),
        secs("accepted_ts", "placed_ts").alias("placed_to_accepted_minutes"),
        secs("picked_up_ts", "accepted_ts").alias("prep_minutes"),
        secs("delivered_ts", "accepted_ts").alias("actual_minutes"),
        (secs("delivered_ts", "accepted_ts") - F.col("promised_minutes").cast("double")).alias("minutes_past_promise"),
    )
