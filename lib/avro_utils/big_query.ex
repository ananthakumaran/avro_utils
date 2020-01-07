defmodule AvroUtils.BigQuery do
  import AvroUtils.Records
  require Record

  @type schema :: map

  defmodule UnsupportedType do
    defexception message: "unsupported type"
    @type t :: %__MODULE__{message: binary}
  end

  @doc """
  Converts avro record to BigQuery table schema

  ### Options

  `all_fields_nullable` (boolean) - Whether to consider all fields nullable. Defaults to `false`.
  """
  @spec to_schema(:avro.record_type(), Keyword.t()) ::
          {:ok, schema} | {:error, UnsupportedType.t()}
  def to_schema(type, options \\ []) when Record.is_record(type, :avro_record_type) do
    schema = build_record(type, options)
    {:ok, schema}
  rescue
    error in [UnsupportedType] -> {:error, error}
  end

  defp build_record(type, options) do
    %{"fields" => Enum.map(avro_record_type(type, :fields), &build_field(&1, options))}
  end

  defp build_field(field, options) do
    Map.merge(
      %{
        "name" => avro_record_field(field, :name),
        "mode" => default_mode(options)
      },
      build_type(avro_record_field(field, :type), options)
    )
  end

  defp build_type(type, _options) when Record.is_record(type, :avro_primitive_type) do
    custom_properties = :avro.get_custom_props(type)
    bq_transform = :proplists.get_value("bq.transform", custom_properties)
    logical_type = :proplists.get_value("logicalType", custom_properties)

    case {avro_primitive_type(type, :name), logical_type, bq_transform} do
      {"null", _, _} -> raise UnsupportedType, message: "null type is not supported"
      {"boolean", _, _} -> %{"type" => "BOOLEAN"}
      {"int", "date", _} -> %{"type" => "DATE"}
      {"int", "time-millis", _} -> %{"type" => "TIME"}
      {"int", _, _} -> %{"type" => "INTEGER"}
      {"long", "time-micros", _} -> %{"type" => "TIME"}
      {"long", "timestamp-millis", _} -> %{"type" => "TIMESTAMP"}
      {"long", "timestamp-micros", _} -> %{"type" => "TIMESTAMP"}
      {"long", _, _} -> %{"type" => "INTEGER"}
      {"float", _, _} -> %{"type" => "FLOAT"}
      {"double", _, _} -> %{"type" => "FLOAT"}
      {"bytes", _, _} -> %{"type" => "BYTES"}
      {"string", _, "iso8601_to_timestamp"} -> %{"type" => "TIMESTAMP"}
      {"string", _, _} -> %{"type" => "STRING"}
    end
  end

  defp build_type(type, _options) when Record.is_record(type, :avro_enum_type) do
    %{"type" => "STRING"}
  end

  defp build_type(type, _options) when Record.is_record(type, :avro_fixed_type) do
    %{"type" => "BYTES"}
  end

  defp build_type(type, options) when Record.is_record(type, :avro_array_type) do
    item_type = avro_array_type(type, :type)

    if Record.is_record(item_type, :avro_array_type) do
      raise UnsupportedType, message: "nested array type is not supported"
    else
      Map.merge(%{"mode" => "REPEATED"}, build_type(item_type, options))
    end
  end

  defp build_type(type, options) when Record.is_record(type, :avro_map_type) do
    value_type = avro_map_type(type, :type)

    %{
      "mode" => "REPEATED",
      "type" => "RECORD",
      "fields" => [
        %{"type" => "STRING", "mode" => "REQUIRED", "name" => "key"},
        Map.merge(
          %{"name" => "value", "mode" => default_mode(options)},
          build_type(value_type, options)
        )
      ]
    }
  end

  defp build_type(type, options) when Record.is_record(type, :avro_record_type) do
    Map.merge(%{"type" => "RECORD"}, build_record(type, options))
  end

  defp build_type(type, options) when Record.is_record(type, :avro_union_type) do
    types = :avro_union.get_types(type)
    non_nullable = non_nullable_types(types)

    cond do
      length(types) == 1 ->
        build_type(hd(types), options)

      length(non_nullable) == 1 ->
        Map.merge(%{"mode" => "NULLABLE"}, build_type(hd(non_nullable), options))

      true ->
        raise UnsupportedType, message: "unsupported union type"
    end
  end

  defp non_nullable_types(types) do
    Enum.reject(types, fn type ->
      Record.is_record(type, :avro_primitive_type) && avro_primitive_type(type, :name) == "null"
    end)
  end

  defp default_mode(options) do
    if Keyword.get(options, :all_fields_nullable) do
      "NULLABLE"
    else
      "REQUIRED"
    end
  end
end
