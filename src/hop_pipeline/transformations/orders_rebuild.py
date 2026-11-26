# R2 - rebuild orders: one row per order_id, earliest event_ts per event type.
# Clean orders land in hop.silver.orders; broken orders land in hop.silver.orders_quarantine
# with failed_rules listing every quarantine rule the order breaks (Q-A, Q-B, Q-C, Q-D).
from pyspark import pipelines as dp
from pyspark.sql import functions as F
from pyspark.sql import Window

_EVENT_TYPES = ["placed", "accepted", "picked_up", "delivered", "cancelled"]


def _reference_with_flag(table, key):
    return spark.read.table(table).select(key).distinct().withColumn(f"_{key}_known", F.lit(True))


def _rebuild():
    ev = spark.read.table("order_events_dedup").withColumn("ts", F.to_timestamp("event_ts"))

    # earliest event row per (order_id, event_type); deterministic tie-break on event_id
    w = Window.partitionBy("order_id", "event_type").orderBy(F.col("ts"), F.col("event_id"))
    first = ev.withColumn("rn", F.row_number().over(w)).filter(F.col("rn") == 1)

    counts = ev.groupBy("order_id").pivot("event_type").count()
    for c in _EVENT_TYPES:
        if c not in counts.columns:
            counts = counts.withColumn(c, F.lit(0).cast("long"))
        else:
            counts = counts.withColumn(c, F.coalesce(F.col(c), F.lit(0).cast("long")))

    placed = first.filter("event_type = 'placed'").select(
        "order_id", "customer_id", "restaurant_id", "zone_id", "delivery_class",
        "promised_minutes", "order_value", "platform", F.col("ts").alias("placed_ts"),
    )
    accepted = first.filter("event_type = 'accepted'").select("order_id", F.col("ts").alias("accepted_ts"))
    picked = first.filter("event_type = 'picked_up'").select("order_id", "rider_id", F.col("ts").alias("picked_up_ts"))
    delivered = first.filter("event_type = 'delivered'").select(
        "order_id", F.col("rider_id").alias("rider_from_delivered"), F.col("ts").alias("delivered_ts"),
    )
    cancelled = first.filter("event_type = 'cancelled'").select(
        "order_id", "cancelled_by", F.col("ts").alias("cancelled_ts"),
    )

    # start from the full order universe so orders without a placed event are kept (and quarantined)
    base = (
        counts
        .join(placed, "order_id", "left")
        .join(accepted, "order_id", "left")
        .join(picked, "order_id", "left")
        .join(delivered, "order_id", "left")
        .join(cancelled, "order_id", "left")
    )

    # rider comes from the picked_up event, or from the delivered event when there was no pickup
    base = base.withColumn("rider_id", F.coalesce(F.col("rider_id"), F.col("rider_from_delivered"))).drop("rider_from_delivered")

    base = (
        base
        .join(_reference_with_flag("hop.raw.customers", "customer_id"), "customer_id", "left")
        .join(_reference_with_flag("hop.raw.restaurants_cdc", "restaurant_id"), "restaurant_id", "left")
        .join(_reference_with_flag("hop.raw.zones", "zone_id"), "zone_id", "left")
        .join(_reference_with_flag("hop.raw.riders", "rider_id"), "rider_id", "left")
    )

    qa = (
        F.col("customer_id").isNull() | F.col("_customer_id_known").isNull()
        | F.col("restaurant_id").isNull() | F.col("_restaurant_id_known").isNull()
        | F.col("zone_id").isNull() | F.col("_zone_id_known").isNull()
        | (F.col("rider_id").isNotNull() & F.col("_rider_id_known").isNull())
    )
    qb = (F.coalesce(F.col("delivered"), F.lit(0)) + F.coalesce(F.col("cancelled"), F.lit(0))) != 1
    qc = (
        (F.col("accepted_ts") < F.col("placed_ts"))
        | (F.col("picked_up_ts") < F.col("accepted_ts"))
        | (F.col("delivered_ts") < F.col("picked_up_ts"))
    )
    qd = (
        F.col("order_value").isNull() | (F.col("order_value") <= 0)
        | ~F.col("delivery_class").isin("instant", "standard")
        | (F.col("delivery_class") == "instant") & ((F.col("promised_minutes").isNull()) | (F.col("promised_minutes") != 10))
        | (F.col("delivery_class") == "standard") & (
            F.col("promised_minutes").isNull()
            | ~F.col("promised_minutes").cast("int").isin(30, 35, 40, 45)
        )
    )

    status = F.when(F.col("delivered_ts").isNotNull(), F.lit("delivered")).otherwise(F.lit("cancelled"))
    failed_rules = F.array_compact(
        F.array(
            F.when(qa, F.lit("Q-A")),
            F.when(qb, F.lit("Q-B")),
            F.when(qc, F.lit("Q-C")),
            F.when(qd, F.lit("Q-D")),
        )
    )

    return (
        base
        .withColumn("status", status)
        .withColumn("failed_rules", failed_rules)
        .drop("_customer_id_known", "_restaurant_id_known", "_zone_id_known", "_rider_id_known",
              "placed", "accepted", "picked_up", "delivered", "cancelled")
    )


@dp.materialized_view(name="orders", comment="Clean rebuilt orders, one row per order_id")
def orders():
    return (
        _rebuild()
        .filter(F.size("failed_rules") == 0)
        .select(
            "order_id", "status", "customer_id", "restaurant_id", "zone_id",
            "delivery_class", F.col("promised_minutes").cast("int").alias("promised_minutes"),
            F.col("order_value").cast("double").alias("order_value"), "platform", "rider_id",
            "cancelled_by", "placed_ts", "accepted_ts", "picked_up_ts", "delivered_ts", "cancelled_ts",
        )
    )


@dp.materialized_view(name="orders_quarantine", comment="Orders that break quarantine rules, with the list of failed rules")
def orders_quarantine():
    return (
        _rebuild()
        .filter(F.size("failed_rules") > 0)
        .select("order_id", "failed_rules")
    )

