defmodule AvroUtils.BigQuery do
  defmodule UnsupportedType do
    defexception message: "unsupported type"
  end

  require Record

  @type schema :: term

  Record.defrecord(:avro_record_type, [
    :name,
    :namespace,
    :doc,
    :aliases,
    :fields,
    :fields,
    :fullname,
    :custom
  ])

  Record.defrecord(:avro_record_field, [
    :name,
    :doc,
    :type,
    :default,
    :order,
    :aliases
  ])

  Record.defrecord(:avro_primitive_type, [
    :name,
    :custom
  ])

  Record.defrecord(:avro_enum_type, [
    :name,
    :namespace,
    :aliases,
    :doc,
    :symbols,
    :fullname,
    :custom
  ])

  Record.defrecord(:avro_array_type, [
    :type,
    :custom
  ])

  Record.defrecord(:avro_map_type, [
    :type,
    :custom
  ])

  Record.defrecord(:avro_union_type, [
    :id2type,
    :name2id
  ])

  Record.defrecord(:avro_fixed_type, [
    :name,
    :namespace,
    :aliases,
    :size,
    :fullname,
    :custom
  ])

  @spec to_schema(:avro.record_type()) :: schema
  def to_schema(type) when Record.is_record(type, :avro_record_type) do
    %{"fields" => Enum.map(avro_record_type(type, :fields), &build_field/1)}
  end

  defp build_field(field) do
    Map.merge(
      %{
        "name" => avro_record_field(field, :name),
        "mode" => "REQUIRED"
      },
      build_type(avro_record_field(field, :type))
    )
  end

  defp build_type(type) when Record.is_record(type, :avro_primitive_type) do
    custom_properties = :avro.get_custom_props(type)
    logical_type = :proplists.get_value("logicalType", custom_properties)

    case {avro_primitive_type(type, :name), logical_type} do
      {"null", _} -> raise UnsupportedType, message: "null type is not supported"
      {"boolean", _} -> %{"type" => "BOOLEAN"}
      {"int", "date"} -> %{"type" => "DATE"}
      {"int", "time-millis"} -> %{"type" => "TIME"}
      {"int", _} -> %{"type" => "INTEGER"}
      {"long", "time-micros"} -> %{"type" => "TIME"}
      {"long", "timestamp-millis"} -> %{"type" => "TIMESTAMP"}
      {"long", "timestamp-micros"} -> %{"type" => "TIMESTAMP"}
      {"long", _} -> %{"type" => "INTEGER"}
      {"float", _} -> %{"type" => "FLOAT"}
      {"double", _} -> %{"type" => "FLOAT"}
      {"bytes", _} -> %{"type" => "BYTES"}
      {"string", _} -> %{"type" => "STRING"}
    end
  end

  defp build_type(type) when Record.is_record(type, :avro_enum_type) do
    %{"type" => "STRING"}
  end

  defp build_type(type) when Record.is_record(type, :avro_fixed_type) do
    %{"type" => "BYTES"}
  end

  defp build_type(type) when Record.is_record(type, :avro_array_type) do
    item_type = avro_array_type(type, :type)

    if Record.is_record(item_type, :avro_array_type) do
      raise UnsupportedType, message: "nested array type is not supported"
    else
      Map.merge(%{"mode" => "REPEATED"}, build_type(item_type))
    end
  end

  defp build_type(type) when Record.is_record(type, :avro_map_type) do
    value_type = avro_map_type(type, :type)

    %{
      "mode" => "REPEATED",
      "type" => "RECORD",
      "fields" => [
        %{"type" => "STRING", "mode" => "REQUIRED", "name" => "key"},
        Map.merge(%{"name" => "value", "mode" => "REQUIRED"}, build_type(value_type))
      ]
    }
  end

  defp build_type(type) when Record.is_record(type, :avro_record_type) do
    Map.merge(%{"type" => "RECORD"}, to_schema(type))
  end

  defp build_type(type) when Record.is_record(type, :avro_union_type) do
    types = :avro_union.get_types(type)
    non_nullable = non_nullable_types(types)

    cond do
      length(types) == 1 ->
        build_type(hd(types))

      length(non_nullable) == 1 ->
        Map.merge(%{"mode" => "NULLABLE"}, build_type(hd(non_nullable)))

      true ->
        raise UnsupportedType, message: "unsupported union type"
    end
  end

  defp non_nullable_types(types) do
    Enum.reject(types, fn type ->
      Record.is_record(type, :avro_primitive_type) && avro_primitive_type(type, :name) == "null"
    end)
  end
end
