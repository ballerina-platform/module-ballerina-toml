import ballerina/time;

# Constructs the key value pairs for the current table
#
# + structure - Current table
# + tableKey - Current table key
# + whitespace - Indentation for the current table
# + return - An error on failure
function processStructure(State state, map<anydata> structure, string tableKey, string whitespace) returns error? {
    string[] keys = structure.keys();

    // List of array tables to be created
    [string, anydata[]][] arrayTables = [];

    // List of standard tables to be created
    [string, map<anydata>][] standardTables = [];

    // Traverse all the keys .
    foreach string key in keys {
        anydata value = structure[key];

        // This structure should be processed at the end of this depth level.
        // Builds both dotted keys or standard tables.
        if (value is map<anydata>) {
            check processTable(state, value, constructTableKey(tableKey, key), standardTables, whitespace);
            continue;
        }

        // Procss UTC time
        if (value is time:Utc) {
            state.output.push(whitespace + key + " = " + time:utcToString(<time:Utc>value));
            continue;
        }

        // This structure should be processed at the end of this depth level.
        // Builds both inline arrays or array tables.
        if (value is anydata[]) {
            check processArray(state, key, value, tableKey, arrayTables, whitespace);
            continue;
        }

        state.output.push(whitespace + key + " = " + check processPrimitiveValue(value));
    }

    // Construct the array tables
    if (arrayTables.length() > 0) {
        string newWhitespace = tableKey.length() == 0 ? whitespace : whitespace + state.indent;
        foreach [string, anydata[]] arrayTable in arrayTables {
            foreach anydata arrayObject in arrayTable[1] {
                state.output.push("");
                state.output.push(newWhitespace + "[[" + arrayTable[0] + "]]");
                check processStructure(state, <map<anydata>>arrayObject, arrayTable[0], newWhitespace);
            }
        }
    }

    // Construct the standard tables
    if (standardTables.length() > 0) {
        string newWhitespace = tableKey.length() == 0 ? whitespace : whitespace + state.indent;
        foreach [string, map<anydata>] standardTable in standardTables {
            state.output.push("");
            state.output.push(newWhitespace + "[" + standardTable[0] + "]");
            check processStructure(state, standardTable[1], standardTable[0], newWhitespace);
        }
    }
}

# Generate the TOML equivalent of the given Ballerina type.
#
# + value - Value to converted
# + return - Converted string on success. Else, an error.
function processPrimitiveValue(anydata value) returns string|error {
    if (value is string) {
        return "\"" + value + "\"";
    }

    if (value == 'float:Infinity) {
        return "+inf";
    }

    if (value == -'float:Infinity) {
        return "-inf";
    }

    if (value == 'float:NaN) {
        return "nan";
    }

    if (value is int || value is float || value is boolean || value is map<anydata>) {
        return value.toString();
    }

    return generateError("Unknown data type to process");
}

# Creates an inline array if there is at least one primitive value.
# Else, add it to the queue to create an array table.
#
# + key - Key of the array  
# + value - Values of the array  
# + tableKey - Current table key
# + arrayTables - List of array tables under the current table  
# + whitespace - Indentation of the current table
# + return - An error on failure
function processArray(State state, string key, anydata[] value, string tableKey, [string, anydata[]][] arrayTables, string whitespace) returns error? {
    // Check if all the array values are object
    boolean isAllObject = value.reduce(function(boolean assertion, anydata arrayValue) returns boolean {
        return assertion && arrayValue is map<anydata>;
    }, true);

    // Construct an array table
    if (isAllObject) {
        arrayTables.push([constructTableKey(tableKey, key), value]);
        return;
    }

    // Construct an inline array
    state.output.push(key + " = [");
    value.forEach(arrayValue => state.output.push(whitespace + state.indent + check processPrimitiveValue(arrayValue) + ","));
    state.output.push("]");
}

# Creates a dotted key if there is only one value.
# Else, add it to the queue to create a standard table.
#
# + structure - Current table
# + tableKey - Current table key  
# + standardTables - List of standard tables under the current table  
# + whitespace - Indentation of the current table
# + return - An error on failure
function processTable(State state, map<anydata> structure, string tableKey, [string, map<anydata>][] standardTables, string whitespace) returns error? {
    // Check if there are more than one value nested to it.
    if (structure.length() == 1) {
        string firstKey = structure.keys()[0];
        if (structure[firstKey] is map<anydata>) {
            check processTable(state, <map<anydata>>structure[firstKey], constructTableKey(tableKey, firstKey), standardTables, whitespace);
        } else {
            if (state.allowDottedKeys) {
                state.output.push(whitespace + constructTableKey(tableKey, firstKey) + " = " + check processPrimitiveValue(structure[firstKey]));
            }
                else {
                standardTables.push([tableKey, structure]);
            }
        }
        return;
    }

    // If there are more than two values, construct a standard table.
    standardTables.push([tableKey, structure]);
}

# Creates the dotted key for the new table.
#
# + parentKey - Key of the parent table
# + currentKey - Key of the current table
# + return - Dotted key representing the current table
function constructTableKey(string parentKey, string currentKey) returns string {
    return parentKey == "" ? currentKey : parentKey + "." + currentKey;
}