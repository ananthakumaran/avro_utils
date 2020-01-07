# AvroUtils

Utility library to convert struct to BigQuery compatible json based on avro
schema

### Avro Type Conversion

#### Primitive Types

| Avro    | BigQuery      |
|---------|---------------|
| null    | not supported |
| boolean | BOOLEAN       |
| int     | INTEGER       |
| long    | INTEGER       |
| float   | FLOAT         |
| double  | FLOAT         |
| bytes   | BYTES         |
| string  | STRING        |
|         |               |

#### Complex Types

| Avro   | BigQuery                                                            |
|--------|---------------------------------------------------------------------|
| record | RECORD                                                              |
| enum   | STRING                                                              |
| array  | REPEATED                                                            |
| map    | REAPEATED RECORD with key and value                                 |
| union  | only supports union with max 2 options and max 1 non nullable type. |
| fixed  | BYTES                                                               |

#### Logical Types

| Avro             | BigQuery  |
|------------------|-----------|
| time-millis      | TIME      |
| time-micros      | TIME      |
| timestamp-millis | TIMESTAMP |
| timestamp-micros | TIMESTAMP |


#### bq.transform

| Avro                                                                                           | BigQuery                                                            |
|------------------------------------------------------------------------------------------------|---------------------------------------------------------------------|
| `{"name": "created_at", "type": { "type": "string", "bq.transform": "iso8601_to_timestamp" }}` | `{ "mode": "REQUIRED", "name": "created_at", "type": "TIMESTAMP" }` |
| `{"name": "detail","type": { "type": "string", "bq.transform": "any_to_json" }}`               | `{ "mode": "REQUIRED", "name": "detail", "type": "STRING" }`        |

#### bq.source_name

| Avro                                                                                | BigQuery                                                        |
|-------------------------------------------------------------------------------------|-----------------------------------------------------------------|
| `{"name": "full_name","type": { "type": "string", "bq.source_name": "full-name" }}` | `{ "mode": "REQUIRED", "name": "full_name", "type": "STRING" }` |


