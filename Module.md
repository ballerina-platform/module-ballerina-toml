# Ballerina TOML Parser

`Ballerina TOML Parser` converts a TOML configuration file to the Ballerina type of `map<json>`, and vice-versa.     

Initially, import the `nipuanyf/toml` into the Ballerina project.

```ballerina
import nipunayf/toml;
```

Currently, the module supports to both read and write a TOML document.

## Compatibility

| Language  | Version                        |
| --------- | ------------------------------ |
| Ballerina | Ballerina 2201.0.0 (Swan Lake) |
| TOML      | 1.0                            |

The parser follows the grammar rules particularized in the [TOML specification 1.0](https://toml.io/en/v1.0.0).

### Parsing a TOML Document

Since the parser is following LL(1) grammar, it follows a non-recursive predictive parsing algorithm which operates in a linear time complexity. The module supports to parse either a TOML file or a TOML string.

```ballerina
// Parsing a TOML file
map<json>|error toml = read("path/to/file.toml");
```

```ballerina
// Parsing a TOML string
map<json>|error toml = readString("outer.inner = 1");
```

### Writing to a TOML Document

Any `map<json>` structure containing the [supported data types](#Supported-Data-Types) can be converted to a TOML document. 

```ballerina
map<json> toml = {
        "str": "string",
        "float": 0.01,
        "inline": {
            "boolean": false
        }
    };
error? result = write("path/to/file.toml", toml);
if (result is error) {
    log:printError("Failed to write the TOML document.", 'error = result);
}
```

The TOML document of the `map<json>` structure is created as shown as below.

```toml
str = "string"
float = 0.01
inline.boolean = false
```

The following options can be set to further format the output TOML file.

| Option                      | Default | Description                                                                                                                                  |
| --------------------------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `int indentationPolicy`     | `2`     | The number of whitespaces considered to a indent. An indentation is made once a standard or an array table is defined under the current one. |
| `boolean allowedDottedKeys` | `true`  | If set, dotted keys are used instead of standard tables.                                                                                     |

Consider the `map<json>` structure of  `{table: key = "value"}`. The output TOML document of this can be diverted based on the `allowedDottedKeys` property as follow.

```toml
table.key = "value" # allowedDottedKeys = true

# allowedDottedKeys = false
[table]
key = "value"
```

## Supported Data Types

The following TOML primitives are mapped to the Ballerina types as follow.

| TOML                                        | Ballerina                       |
| ------------------------------------------- | ------------------------------- |
| Integer                                     | `ballerina.lang.int`            |
| Float                                       | `ballerina.lang.float`          |
| Infinity                                    | `ballerina.lang.float.Infinity` |
| NaN                                         | `ballerina.lang.float.NaN`      |
| Unquoted, Basic and Literal Strings         | `ballerina.lang.string`         |
| Boolean                                     | `ballerina.lang.boolean`        |
| Array                                       | `json[]`                        |
| Table                                       | `map<json>`                     |
| Offset Date-Time                            | `ballerina.time.Utc`            |
| Local Date-Time, Local Date, and Local Time | `ballerina.lang.string`         |

## Error Handling

The module generates following three types of errors.

| Errors        | Description                                                                                 |
| ------------- | ------------------------------------------------------------------------------------------- |
| Lexical Error | Generated when there is an invalid character for the token's lexeme.                        |
| Parsing Error | Generated when the token sequence does not mach with the grammar.                           |
| Writing Error | Generated when there is an issue during the conversion from `map<json>` to a TOML document. |