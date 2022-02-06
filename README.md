# Ballerina TOML Parser

![Build](https://github.com/nipunayf/module-ballerina-toml/actions/workflows/ci.yml/badge.svg)

`Ballerina TOML Parser` converts a TOML configuration file to the Ballerina type of `map<anydata>`, and vice-versa.     

## Compatibility

| Language  | Version                        |
| --------- | ------------------------------ |
| Ballerina | Ballerina 2201.0.0 (Swan Lake) |
| TOML      | 1.0                            |

## API Guide

Initially, import the `nipuanyf/toml` into the Ballerina project.

```ballerina
import nipunayf/toml;
```

Currently, the module supports to both parse and write a TOML document. 

### Parsing a TOML Document

Since the parser is following LL(1) grammar, it follows a non-recursive predictive parsing algorithm. Thus, it operates in a linear time complexity. The module supports to parse either a TOML file or a TOML string.

```ballerina
// Parsing a TOML file
map<anydata>|error toml = readFile("path/to/file.toml");
```

```ballerina
// Parsing a TOML string
map<anydata>|error toml = read("outer.inner = 1");
```

For instance, we can convert the parsed TOML document to JSON and create a `.json` file to view the converted structure.

```ballerina
if (toml is map<anydata>) {
    // If successful, conver the TOML structure to JSON and write it.
    io:fileWriteJson("myfile.json", toml.toJson());
} else {
    // Print the error on failure.
    log:printError("Failed to parse.", 'error = toml);
}
```

Once it is processed, the output JSON file can be shown as below.

```json
{
    "outer": {
        "inner": 1
}
```

### Writing to a TOML Document

Any `map<anydata>` structure containing the [supported data types](#Supported-Data-Types) can be converted to a TOML document. 

```ballerina
map<anydata> toml = {
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

The TOML document of the `map<anydata>` structure can be shown as below.

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

Consider the `map<anydata>` structure of  `{table: key = "value"}`. The output TOML document of this can be diverted based on the `allowedDottedKeys` property as follow.

```toml
table.key = "value" # allowedDottedKeys = true

# allowedDottedKeys = false
[table]
key = "value"
```

## Supported Data Types

TOML primitives are mapped to the Ballerina types as follow.

| TOML                                        | Ballerina                        |
| ------------------------------------------- | -------------------------------- |
| Integer                                     | `ballerina.lang.'int`            |
| Float                                       | `ballerina.lang.'float`          |
| Infinity                                    | `ballerina.lang.'float.Infinity` |
| NaN                                         | `ballerina.lang.'float.NaN`      |
| Unquoted, Basic and Literal Strings         | `ballerina.lang.'string`         |
| Boolean                                     | `ballerina.lang.'boolean`        |
| Array                                       | `anydata[]`                      |
| Table                                       | `map<anydata>`                   |
| Offset Date-Time                            | `ballerina.time.Utc`             |
| Local Date-Time, Local Date, and Local Time | `ballerina.lang.'string`         |

## Error Handling

The module contains three main types of errors

| Errors        | Description                                                                                    |
| ------------- | ---------------------------------------------------------------------------------------------- |
| Lexical Error | Generated when there is an invalid character for the token's lexeme.                           |
| Parsing Error | Generated when the token sequence does not mach with the grammar.                              |
| Writing Error | Generated when there is an issue during the conversion from `map<anydata>` to a TOML document. |