defmodule AvroUtils.Transformer do
  import AvroUtils
  require Record

  defmodule InvalidType do
    defexception message: "invalid type", field: nil
  end

  @spec to_big_query(:avro.record_type(), term) :: term
  def to_big_query(type, value)
      when Record.is_record(type, :avro_record_type) and is_map(value) do
    value = transform_record(type, value)
    {:ok, value}
  rescue
    error in [InvalidType] -> {:error, error}
  end

  def transform_record(type, value)
      when Record.is_record(type, :avro_record_type) do
    if is_map(value) do
      Enum.flat_map(avro_record_type(type, :fields), fn field ->
        transform_field(field, Map.get(value, avro_record_field(field, :name)))
      end)
      |> Enum.into(%{})
    else
      raise InvalidType,
        message: "expected record type, found #{inspect(type)}",
        field: type
    end
  end

  def transform_field(field, value) when is_nil(value) do
    type = avro_record_field(field, :type)

    if nullable?(type) do
      []
    else
      raise InvalidType,
        message: "expected non nullable type, found nil",
        field: field
    end
  end

  def transform_field(field, value) do
    [
      {avro_record_field(field, :name),
       transform_type(field, avro_record_field(field, :type), value)}
    ]
  end

  defp transform_type(field, type, value) when Record.is_record(type, :avro_primitive_type) do
    custom_properties = :avro.get_custom_props(type)
    bq_transform = :proplists.get_value("bq.transform", custom_properties)
    logical_type = :proplists.get_value("logicalType", custom_properties)

    transform_primitive_type(
      field,
      avro_primitive_type(type, :name),
      logical_type,
      bq_transform,
      value
    )
  end

  defp transform_type(field, type, value) when Record.is_record(type, :avro_enum_type) do
    symbols = avro_enum_type(type, :symbols)

    cond do
      not is_binary(value) ->
        raise InvalidType,
          message: "expected string type, found #{inspect(value)}",
          field: field

      value not in symbols ->
        raise InvalidType,
          message: "expected to be one of #{Enum.join(symbols, ", ")}, found #{value}",
          field: field

      true ->
        value
    end
  end

  defp transform_type(field, type, value) when Record.is_record(type, :avro_fixed_type) do
    if is_binary(value) do
      value
    else
      raise InvalidType,
        message: "expected binary type, found #{inspect(value)}",
        field: field
    end
  end

  defp transform_type(field, type, value) when Record.is_record(type, :avro_array_type) do
    item_type = avro_array_type(type, :type)

    cond do
      Record.is_record(item_type, :avro_array_type) ->
        raise InvalidType, message: "nested array type is not supported", field: field

      not is_list(value) ->
        raise InvalidType,
          message: "expected array type, found #{inspect(value)}",
          field: field

      true ->
        Enum.map(value, fn value -> transform_type(field, item_type, value) end)
    end
  end

  defp transform_type(field, type, value) when Record.is_record(type, :avro_map_type) do
    value_type = avro_map_type(type, :type)

    cond do
      not is_map(value) ->
        raise InvalidType,
          message: "expected map type, found #{inspect(value)}",
          field: field

      true ->
        Enum.map(value, fn {key, value} ->
          cond do
            not is_binary(key) ->
              raise InvalidType,
                message: "expected map keys to be string type, found #{inspect(key)}",
                field: field

            true ->
              %{"key" => key, "value" => transform_type(field, value_type, value)}
          end
        end)
    end
  end

  defp transform_type(_field, type, value) when Record.is_record(type, :avro_record_type) do
    transform_record(type, value)
  end

  defp transform_type(field, type, value) when Record.is_record(type, :avro_union_type) do
    types = :avro_union.get_types(type)
    non_nullable = non_nullable_types(types)

    cond do
      length(types) == 1 ->
        transform_type(field, hd(types), value)

      length(non_nullable) == 1 ->
        transform_type(field, hd(non_nullable), value)

      true ->
        raise InvalidType, message: "unsupported union type"
    end
  end

  defp non_nullable_types(types) do
    Enum.reject(types, fn type ->
      Record.is_record(type, :avro_primitive_type) && avro_primitive_type(type, :name) == "null"
    end)
  end

  defp nullable?(type) do
    if Record.is_record(type, :avro_union_type) do
      types = :avro_union.get_types(type)

      Enum.any?(types, fn type ->
        Record.is_record(type, :avro_primitive_type) && avro_primitive_type(type, :name) == "null"
      end)
    else
      false
    end
  end

  defp transform_primitive_type(_, "string", _, "any_to_json", value),
    do: Jason.encode!(value)

  defp transform_primitive_type(_, "int", "date", _, value) when is_integer(value),
    do: Date.to_string(Date.add(~D[1970-01-01], value))

  defp transform_primitive_type(_, "int", "time-millis", _, value) when is_integer(value),
    do: Time.to_string(Time.add(~T[00:00:00], value, :millisecond))

  defp transform_primitive_type(_, "long", "time-micros", _, value) when is_integer(value),
    do: Time.to_string(Time.add(~T[00:00:00], value, :microsecond))

  defp transform_primitive_type(_, "long", "timestamp-millis", _, value) when is_integer(value),
    do: DateTime.from_unix!(value, :millisecond) |> DateTime.to_iso8601()

  defp transform_primitive_type(_, "long", "timestamp-micros", _, value) when is_integer(value),
    do: DateTime.from_unix!(value, :microsecond) |> DateTime.to_iso8601()

  defp transform_primitive_type(_, "boolean", _, _, value) when is_boolean(value), do: value
  defp transform_primitive_type(_, "string", _, _, value) when is_binary(value), do: value
  defp transform_primitive_type(_, "int", _, _, value) when is_integer(value), do: value
  defp transform_primitive_type(_, "long", _, _, value) when is_integer(value), do: value

  defp transform_primitive_type(_, "float", _, _, value)
       when is_integer(value) or is_float(value),
       do: value

  defp transform_primitive_type(_, "double", _, _, value)
       when is_integer(value) or is_float(value),
       do: value

  defp transform_primitive_type(field, type, _, _, value) do
    raise InvalidType,
      message: "expected #{type} type, found #{inspect(value)}",
      field: field
  end
end