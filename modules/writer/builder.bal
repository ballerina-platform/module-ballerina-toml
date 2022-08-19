import ballerina/time;

# Constructs the key value pairs for the current table.
#
# + state - Current state of the Writer  
# + structure - Current table  
# + parentTableKey - Current table key  
# + whitespace - Indentation for the current table
# + return - An error on failure
function processStructure(State state, map<json> structure, string parentTableKey, string whitespace)
    returns WritingError? {

    string[] keys = structure.keys();

    // List of both standard and array tables to created at the end.
    map<json[]|map<json>> tables = {};

    // Traverse all the keys
    foreach string key in keys {
        json value = structure[key];

        // Builds both dotted keys or standard tables.
        if value is map<json> {
            check processTable(state, value, constructTableKey(parentTableKey, key), tables, whitespace);
            continue;
        }

        // Process UTC time
        if value is time:Utc {
            state.output.push(whitespace + key + " = " + time:utcToString(<time:Utc>value));
            continue;
        }

        // Builds both inline arrays or array tables.
        if value is json[] {
            check processArray(state, key, value, parentTableKey, tables, whitespace);
            continue;
        }

        state.output.push(whitespace + key + " = " + check processPrimitiveValue(value));
    }

    // Construct the standard tables and array tables at the tail.
    if tables.length() > 0 {
        string newWhitespace = parentTableKey.length() == 0 ? whitespace : whitespace + state.indent;
        string[] tableKeys = tables.keys();
        foreach string keyItem in tableKeys {
            if tables[keyItem] is map<json> { // Construct the standard tables
                state.output.push("");
                state.output.push(newWhitespace + "[" + keyItem + "]");
                check processStructure(state, <map<json>>tables[keyItem],
                keyItem, newWhitespace);
            } else { // Construct the array tables
                json[] arrayTable = <json[]>tables[keyItem];
                foreach json arrayObject in arrayTable {
                    state.output.push("");
                    state.output.push(newWhitespace + "[[" + keyItem + "]]");
                    check processStructure(state, <map<json>>arrayObject, keyItem, newWhitespace);
                }
            }
        }
    }
}

# Generate the TOML equivalent of the given Ballerina type.
#
# + value - Value to converted
# + return - Converted string on success. Else, an error.
function processPrimitiveValue(json value) returns string|WritingError {

    // Strings are surrounded by double-quotes by default
    if value is string {
        return "\"" + value + "\"";
    }

    // Positive infinity
    if value == 'float:Infinity {
        return "+inf";
    }

    // Negative infinity
    if value == -'float:Infinity {
        return "-inf";
    }

    // Not a number
    if value == 'float:NaN {
        return "nan";
    }

    // Null objects are not allowed
    if value != () {
        return value.toString();
    }

    return generateError(string `Unknown data type '${(typeof value).toString()}:${value.toString()}' to process`);
}

# Creates an inline array if there is at least one primitive value.
# Else, add it to the queue to create an array table.
#
# + state - Current state of the Writer
# + key - Key of the array  
# + value - Values of the array  
# + tableKey - Current table key
# + tables - List of array tables under the current table  
# + whitespace - Indentation of the current table
# + return - An error on failure
function processArray(State state, string key, json[] value, string tableKey, map<json[]|map<json>> tables,
    string whitespace) returns WritingError? {

    // Check if all the array values are object
    boolean isAllObject = value.reduce(function(boolean assertion, json arrayValue) returns boolean {
        return assertion && arrayValue is map<json>;
    }, true);

    // Construct an array table
    if isAllObject {
        tables[constructTableKey(tableKey, key)] = value;
        return;
    }

    // Construct an inline array
    state.output.push(key + " = [");
    value.forEach(arrayValue =>
        state.output.push(whitespace + state.indent + check processPrimitiveValue(arrayValue) + ","));
    state.output.push("]");
}

# Creates a dotted key if there is only one value.
# Else, add it to the queue to create a standard table.
#
# + state - Current state of the Writer
# + structure - Current table
# + tableKey - Current table key  
# + tables - List of standard tables under the current table  
# + whitespace - Indentation of the current table
# + return - An error on failure
function processTable(State state, map<json> structure, string tableKey, map<json[]|map<json>> tables,
    string whitespace) returns WritingError? {
        
    // Check if there are more than one value nested to it.
    if structure.length() == 1 {
        string firstKey = structure.keys()[0];
        if structure[firstKey] is map<json> {
            check processTable(state, <map<json>>structure[firstKey], constructTableKey(tableKey, firstKey), tables, whitespace);
        } else {
            if state.allowDottedKeys {
                state.output.push(whitespace + constructTableKey(tableKey, firstKey) + " = " + check processPrimitiveValue(structure[firstKey]));
            } else {
                tables[tableKey] = structure;
            }
        }
        return;
    }

    // If there are more than two values, construct a standard table.
    tables[tableKey] = structure;
}

# Creates the dotted key for the new table.
#
# + parentKey - Key of the parent table
# + currentKey - Key of the current table
# + return - Dotted key representing the current table
function constructTableKey(string parentKey, string currentKey) returns string {
    return parentKey == "" ? currentKey : parentKey + "." + currentKey;
}
