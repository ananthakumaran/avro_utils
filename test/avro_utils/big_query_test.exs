defmodule AvroUtils.BigQueryTest do
  use ExUnit.Case
  use ExUnitProperties
  alias AvroUtils.BigQuery

  test "schema" do
    pairs =
      File.read!(Path.join(__DIR__, "../../fixture/schema.json"))
      |> Jason.decode!()

    for %{"avro" => avro, "bq" => bq} <- pairs do
      assert BigQuery.to_schema(:avro.decode_schema(Jason.encode!(avro))) == {:ok, bq}
    end
  end

  property "nesting" do
    check all schema <- avro_record() do
      {:ok, _schema} = BigQuery.to_schema(:avro.decode_schema(Jason.encode!(schema)))
    end
  end

  defp avro_record() do
    fixed_map(%{
      "type" => constant("record"),
      "name" => name(),
      "fields" => uniq_list_of(avro_field(), min_length: 1, max_length: 5)
    })
  end

  defp avro_field() do
    fixed_map(%{
      "name" => name(),
      "type" => avro_type()
    })
  end

  defp avro_type(options \\ []) do
    frequency([
      {3, primitive_type(options)},
      {1, logical_type(options)},
      {1, complex_type(options)}
    ])
  end

  defp primitive_type(options) do
    optionals =
      if Keyword.get(options, :null, false) do
        [avro_null()]
      else
        []
      end

    one_of(
      optionals ++
        [
          avro_boolean(),
          avro_int(),
          avro_long(),
          avro_float(),
          avro_double(),
          avro_bytes(),
          avro_string()
        ]
    )
  end

  defp logical_type(_) do
    one_of([
      avro_date(),
      avro_millis(),
      avro_micros(),
      avro_timestamp_millis(),
      avro_timestamp_micros()
    ])
  end

  defp complex_type(options) do
    lazy(fn ->
      optionals =
        if Keyword.get(options, :union, true) do
          [avro_union()]
        else
          []
        end

      optionals =
        if Keyword.get(options, :array, true) do
          optionals ++ [avro_array()]
        else
          optionals
        end

      one_of(optionals ++ [avro_record(), avro_enum(), avro_map(), avro_fixed()])
    end)
  end

  def avro_null(), do: constant(%{"type" => "null"})
  def avro_boolean(), do: constant(%{"type" => "boolean"})
  def avro_int(), do: constant(%{"type" => "int"})
  def avro_long(), do: constant(%{"type" => "long"})
  def avro_float(), do: constant(%{"type" => "float"})
  def avro_double(), do: constant(%{"type" => "double"})
  def avro_bytes(), do: constant(%{"type" => "bytes"})
  def avro_string(), do: constant(%{"type" => "string"})

  def avro_date(), do: constant(%{"type" => "int", "logicalType" => "date"})
  def avro_millis(), do: constant(%{"type" => "int", "logicalType" => "time-millis"})
  def avro_micros(), do: constant(%{"type" => "long", "logicalType" => "time-micros"})

  def avro_timestamp_millis(),
    do: constant(%{"type" => "int", "logicalType" => "timestamp-millis"})

  def avro_timestamp_micros(),
    do: constant(%{"type" => "int", "logicalType" => "timestamp-micros"})

  def avro_enum() do
    fixed_map(%{
      "type" => constant("enum"),
      "name" => name(),
      "symbols" => uniq_list_of(name(), min_length: 1, max_length: 5)
    })
  end

  def avro_array() do
    fixed_map(%{
      "type" => constant("array"),
      "items" => avro_type(array: false)
    })
  end

  def avro_map() do
    fixed_map(%{
      "type" => constant("map"),
      "values" => avro_type()
    })
  end

  def avro_fixed() do
    fixed_map(%{
      "type" => constant("fixed"),
      "name" => name(),
      "size" => positive_integer()
    })
  end

  def avro_union() do
    map({boolean(), avro_type(union: false)}, fn {nullable?, union} ->
      if nullable? do
        [%{"type" => "null"}, union]
      else
        [union]
      end
    end)
  end

  defp name() do
    Randex.stream(~r/[A-Za-z_][A-Za-z0-9_]{1,8}/, mod: Randex.Generator.StreamData)
  end

  defp lazy(callback) do
    StreamData.sized(fn _size ->
      callback.()
    end)
  end
end
