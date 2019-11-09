defmodule AvroUtils.BigQueryTest do
  use ExUnit.Case
  alias AvroUtils.BigQuery

  test "schema" do
    pairs =
      File.read!(Path.join(__DIR__, "../../fixture/schema.json"))
      |> Jason.decode!()

    for %{"avro" => avro, "bq" => bq} <- pairs do
      assert BigQuery.to_schema(:avro.decode_schema(Jason.encode!(avro))) == bq
    end
  end
end
