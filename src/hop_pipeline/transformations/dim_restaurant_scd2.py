# R3 - SCD Type 2 restaurant history.
# The CDC feed arrives out of order; Auto CDC sequences on op_ts and keeps full history
# with __START_AT / __END_AT (open version has an empty __END_AT).
from pyspark import pipelines as dp
from pyspark.sql import functions as F


@dp.temporary_view(name="restaurant_changes")
def restaurant_changes():
    return (
        spark.readStream.table("hop.raw.restaurants_cdc")
        .withColumn("op_ts", F.to_timestamp("op_ts"))
        .withColumn("rating", F.col("rating").cast("double"))
        .withColumn("is_active", F.col("is_active").cast("boolean"))
    )


dp.create_streaming_table(
    name="dim_restaurant_scd2",
    comment="Restaurant history, SCD Type 2 keyed on restaurant_id, sequenced by op_ts",
)

dp.create_auto_cdc_flow(
    target="dim_restaurant_scd2",
    source="restaurant_changes",
    keys=["restaurant_id"],
    sequence_by="op_ts",
    except_column_list=["op"],
    stored_as_scd_type=2,
)
