# R2 - one row per event_id, keeping the columns of the bronze table.
# Duplicate lines carry identical event content; keep the earliest-ingested copy deterministically.
from pyspark import pipelines as dp
from pyspark.sql import functions as F
from pyspark.sql import Window


@dp.materialized_view(name="order_events_dedup", comment="Order events deduplicated to one row per event_id")
def order_events_dedup():
    bronze = spark.read.table("hop.bronze.order_events")
    w = Window.partitionBy("event_id").orderBy(F.col("_ingest_ts"), F.col("_source_file"))
    return (
        bronze
        .withColumn("rn", F.row_number().over(w))
        .filter(F.col("rn") == 1)
        .drop("rn")
    )
