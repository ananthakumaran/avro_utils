defmodule AvroUtils.TransformerTest do
  use ExUnit.Case
  use ExUnitProperties
  alias AvroUtils.Transformer

  test "schema" do
    pairs =
      File.read!(Path.join(__DIR__, "../../fixture/schema.json"))
      |> Jason.decode!()

    for %{"avro" => avro, "transforms" => transforms} <- pairs do
      for %{"from" => from, "to" => to} <- transforms do
        {:ok, transformed} =
          Transformer.to_big_query(:avro.decode_schema(Jason.encode!(avro)), from)

        assert transformed == to
      end
    end
  end
end
