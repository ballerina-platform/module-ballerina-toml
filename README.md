# Ballerina TOML Parser

![Build](https://github.com/nipunayf/module-ballerina-toml/actions/workflows/ci.yml/badge.svg)

Ballerina TOML Parser provides APIs to convert a TOML configuration file to `map<json>`, and vice-versa. Since the parser is following LL(1) grammar, it follows a non-recursive predictive parsing algorithm which operates in a linear time complexity.

## Compatibility

| Language  | Version                        |
| --------- | ------------------------------ |
| Ballerina | Ballerina 2201.0.0 (Swan Lake) |
| TOML      | 1.0                            |

The parser follows the grammar rules particularized in the [TOML specification 1.0](https://toml.io/en/v1.0.0).

### Parsing a TOML Document

 The module supports to parse either a TOML file or a TOML string.

```ballerina
// Parsing a TOML file
map<json>|toml:Error toml = readFile("path/to/file.toml");

// Parsing a TOML string
map<json>|toml:Error toml = readString(string
    `bool = true
    int = 1
    float = 1.1`);
```

By default, the package parses offset date time into `time.Utc`. This can be skipped by disabling the `parseOffsetDateTime`.

### Writing to a TOML Document

Any `map<json>` structure containing the [supported data types](#Supported-Data-Types) can be converted to a TOML document. The package can either convert the document to an array of strings or write to a TOML file.

```ballerina
map<json> toml = {
        "str": "string",
        "float": 0.01,
        "inline": {
            "boolean": false
        }
    };

// Covert the TOML content to an array of strings
string[]|toml:Error stringResult = writeString(toml);
if result is toml:Error {
    log:printError("Failed to write the TOML document.", error = result);
}

// Write the TOML content into a file
toml:Error? fileResult = writeFile("path/to/file.toml", toml);
if fileResult is toml:Error {
    log:printError("Failed to write the TOML document.", error = result);
}
```

The respective TOML document of the `map<json>` structure is created as shown as below.

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
| Float                                       | `ballerina.lang.decimal`        |
| Infinity                                    | `ballerina.lang.float.Infinity` |
| NaN                                         | `ballerina.lang.float.NaN`      |
| Unquoted, Basic and Literal Strings         | `ballerina.lang.string`         |
| Boolean                                     | `ballerina.lang.boolean`        |
| Array                                       | `json[]`                        |
| Table                                       | `map<json>`                     |
| Offset Date-Time                            | `ballerina.time.Utc`            |
| Local Date-Time, Local Date, and Local Time | `ballerina.lang.string`         |

## Example

The following example illustrates on how a TOML content is converted to a Ballerina record and write it back after processing it.

```ballerina
import ballerina/io;
import nipunayf/toml;

type Package record {|
    string name;
    record {|int major; int minor; int patch;|} 'version;
|};

public function main() returns error? {
    // Read the TOML content into a map<json>
    map<json> result = check toml:readString(string
        `name = "toml"
        
        [version]
        major = 0
        minor = 1
        patch = 3`);

    Package packageToml = check result.fromJsonWithType();

    // Update the version 
    packageToml.'version.minor += 1;
    packageToml.'version.patch = 0;

    // Convert map<json> into TOML content
    io:println(toml:writeString(packageToml));
}
```