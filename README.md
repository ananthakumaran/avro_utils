# AvroUtils

Utility library to convert struct to BigQuery compatible json based on avro
schema

### Avro Type Conversion

#### Primitive Types

| Avro    | BigQuery      |
--------------------------
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

| Avro    | BigQuery      |
--------------------------
| record | RECORD                                                              |
| enum   | STRING                                                              |
| array  | REPEATED                                                            |
| map    | REAPEATED RECORD with key and value                                 |
| union  | only supports union with max 2 options and max 1 non nullable type. |
| fixed  | BYTES                                                               |

#### Logical Types

| Avro    | BigQuery      |
--------------------------
| time-millis      | TIME      |
| time-micros      | TIME      |
| timestamp-millis | TIMESTAMP |
| timestamp-micros | TIMESTAMP |


#### bq.transform

| Avro                 | BigQuery  |
------------------------------------
| any_to_json          | STRING    |
| iso8601_to_timestamp | TIMESTAMP |


