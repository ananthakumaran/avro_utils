defmodule AvroUtils.Records do
  @moduledoc false
  require Record

  Record.defrecord(:avro_record_type, [
    :name,
    :namespace,
    :doc,
    :aliases,
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
end
