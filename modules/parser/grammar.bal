import toml.lexer;
import ballerina/lang.'boolean;
import ballerina/lang.'float;
import ballerina/lang.'int;

# Handles the rule: key -> simple-key | dotted-key
# key_value -> key '=' value.
# The 'dotted-key' is being called recursively. 
# At the terminal, a value is assigned to the last key, 
# and nested under the previous key's map if exists.
#
# + structure - The structure for the previous key. Null if there is no value.
# + return - Returns the structure after assigning the value.
function keyValue(ParserState state, map<json> structure) returns map<json>|ParsingError|lexer:LexicalError {
    string tomlKey = state.currentToken.value;
    check verifyKey(state, structure, tomlKey);
    check verifyTableKey(state, state.currentTableKey == "" ? state.bufferedKey : state.currentTableKey + "." + state.bufferedKey);
    check checkToken(state);

    match state.currentToken.token {
        lexer:DOT => { // Process dotted keys
            check checkToken(state, [lexer:UNQUOTED_KEY, lexer:BASIC_STRING, lexer:LITERAL_STRING]);
            state.bufferedKey += "." + state.currentToken.value;
            map<json> value = check keyValue(state, structure[tomlKey] is map<json> ? <map<json>>structure[tomlKey] : {});
            structure[tomlKey] = value;
            return structure;
        }

        lexer:KEY_VALUE_SEPARATOR => { // Process value assignment
            state.updateLexerContext(lexer:EXPRESSION_VALUE);

            check checkToken(state, [
                lexer:BASIC_STRING,
                lexer:LITERAL_STRING,
                lexer:MULTILINE_BASIC_STRING_DELIMITER,
                lexer:MULTILINE_LITERAL_STRING_DELIMITER,
                lexer:DECIMAL,
                lexer:BINARY,
                lexer:OCTAL,
                lexer:HEXADECIMAL,
                lexer:INFINITY,
                lexer:NAN,
                lexer:OPEN_BRACKET,
                lexer:BOOLEAN,
                lexer:INLINE_TABLE_OPEN
            ]);

            // Existing tables cannot be overwritten by inline tables
            if (state.currentToken.token == lexer:INLINE_TABLE_OPEN && structure[tomlKey] is map<json>) {
                return generateError(state, check formatErrorMessage(2, value = state.bufferedKey));
            }

            structure[tomlKey] = check dataValue(state);
            return structure;
        }
        _ => {
            return generateError(state, check formatErrorMessage(1, [lexer:DOT, lexer:KEY_VALUE_SEPARATOR], lexer:UNQUOTED_KEY));
        }
    }
}

# Generate any TOML data value.
#
# + return - If success, returns the formatted data value. Else, an error.
function dataValue(ParserState state) returns json|lexer:LexicalError|ParsingError {
    json returnData;
    match state.currentToken.token {
        lexer:MULTILINE_BASIC_STRING_DELIMITER => {
            returnData = check multiBasicString(state);
        }
        lexer:MULTILINE_LITERAL_STRING_DELIMITER => {
            returnData = check multiLiteralString(state);
        }
        lexer:DECIMAL => {
            returnData = check number(state, "");
        }
        lexer:HEXADECIMAL => {
            returnData = check processTypeCastingError(state, 'int:fromHexString(state.currentToken.value));
        }
        lexer:BINARY => {
            returnData = check processInteger(state, 2);
        }
        lexer:OCTAL => {
            returnData = check processInteger(state, 8);
        }
        lexer:INFINITY => {
            returnData = state.currentToken.value[0] == "+" ? 'float:Infinity : -'float:Infinity;
        }
        lexer:NAN => {
            returnData = 'float:NaN;
        }
        lexer:BOOLEAN => {
            returnData = check processTypeCastingError(state, 'boolean:fromString(state.currentToken.value));
        }
        lexer:OPEN_BRACKET => {
            returnData = check array(state);

            // Static arrays cannot be redefined by the array tables.
            if (!state.isArrayTable) {
                state.definedTableKeys.push(state.currentTableKey.length() == 0 ? state.bufferedKey : state.currentTableKey + "." + state.bufferedKey);
                state.bufferedKey = "";
            }
        }
        lexer:INLINE_TABLE_OPEN => {
            returnData = check inlineTable(state);

            // Inline tables cannot be redefined by the standard tables.
            if (!state.isArrayTable) {
                state.definedTableKeys.push(state.currentTableKey.length() == 0 ? state.bufferedKey : state.currentTableKey + "." + state.bufferedKey);
                state.bufferedKey = "";
            }
        }
        _ => { // Latter primitive data types
            returnData = state.currentToken.value;
        }
    }
    return returnData;
}

# Process the rules after '[' or ','.
#
# + tempArray - Recursively constructing array
# + return - Completed array on success. An error if the grammar rules are not met.
function array(ParserState state, json[] tempArray = []) returns json[]|lexer:LexicalError|ParsingError {

    check checkToken(state, [
        lexer:BASIC_STRING,
        lexer:LITERAL_STRING,
        lexer:MULTILINE_BASIC_STRING_DELIMITER,
        lexer:MULTILINE_LITERAL_STRING_DELIMITER,
        lexer:DECIMAL,
        lexer:HEXADECIMAL,
        lexer:OCTAL,
        lexer:BINARY,
        lexer:INFINITY,
        lexer:NAN,
        lexer:BOOLEAN,
        lexer:OPEN_BRACKET,
        lexer:CLOSE_BRACKET,
        lexer:INLINE_TABLE_OPEN,
        lexer:EOL
    ]);

    match state.currentToken.token {
        lexer:EOL => {
            check state.initLexer(check formatErrorMessage(1, lexer:CLOSE_BRACKET, lexer:OPEN_BRACKET));
            return array(state, tempArray);
        }
        lexer:CLOSE_BRACKET => { // If the array ends with a ','
            return tempArray;
        }
        _ => { // Array value
            tempArray.push(check dataValue(state));
            return arrayValue(state, tempArray);
        }
    }
}

# Process the rules after an array value.
#
# + tempArray - Recursively constructing array
# + return - Completed array on success. An error if the grammar rules are not met.
function arrayValue(ParserState state, json[] tempArray = []) returns json[]|lexer:LexicalError|ParsingError {
    lexer:TOMLToken prevToken;

    if (state.tokenConsumed) {
        prevToken = lexer:DECIMAL;
        state.tokenConsumed = false;
    } else {
        prevToken = state.currentToken.token;
        check checkToken(state);
    }

    match state.currentToken.token {
        lexer:EOL => {
            check state.initLexer("Expected ']' or ',' after an array value");
            return arrayValue(state, tempArray);
        }
        lexer:CLOSE_BRACKET => {
            return tempArray;
        }
        lexer:SEPARATOR => {
            return array(state, tempArray);
        }
        _ => {
            return generateError(state, check formatErrorMessage(1, [lexer:EOL, lexer:CLOSE_BRACKET, lexer:SEPARATOR], prevToken));
        }
    }
}

# Process the grammar rules of inline tables.
#
# + tempTable - Recursively constructing inline table
# + isStart - True if the function is being called for the first time.
# + return - Map structure representing the table on success. Else, an error if the grammar rules are not met.
function inlineTable(ParserState state, map<json> tempTable = {}, boolean isStart = true) returns map<json>|lexer:LexicalError|ParsingError {
    state.updateLexerContext(lexer:EXPRESSION_KEY);
    check checkToken(state, [
        lexer:UNQUOTED_KEY,
        lexer:BASIC_STRING,
        lexer:LITERAL_STRING,
        isStart ? lexer:INLINE_TABLE_CLOSE : lexer:DUMMY
    ]);

    // This is unreachable after a separator.
    // This condition is only available to create an empty table.
    if (state.currentToken.token == lexer:INLINE_TABLE_CLOSE) {
        return tempTable;
    }

    // Add the key value to the inline table.
    map<json> newTable = check keyValue(state, tempTable.clone());

    if (state.tokenConsumed) {
        state.tokenConsumed = false;
    } else {
        check checkToken(state, [lexer:SEPARATOR, lexer:INLINE_TABLE_CLOSE]);
    }

    // Calls the method recursively to add new key values.
    if (state.currentToken.token == lexer:SEPARATOR) {
        return check inlineTable(state, newTable, false);
    }

    return newTable;
}

# Process the grammar rules for initializing the standard table.
# Sets a new current structure, so the succeeding key values are added to it.
#
# + structure - Mapping of the parent key
# + keyName - Recursively constructing the table key name
# + return - An error if the grammar rules are not met or any duplicate values.
function standardTable(ParserState state, map<json> structure, string keyName = "") returns lexer:LexicalError|ParsingError|() {

    // Verifies the current key
    string tomlKey = state.currentToken.value;
    state.keyStack.push(tomlKey);
    check verifyKey(state, structure, tomlKey);

    check checkToken(state);

    match state.currentToken.token {
        lexer:DOT => { // Build the dotted key
            check checkToken(state, [lexer:UNQUOTED_KEY, lexer:BASIC_STRING, lexer:LITERAL_STRING]);
            return check standardTable(state, structure[tomlKey] is map<json> ? <map<json>>structure[tomlKey] : {}, keyName + tomlKey + ".");
        }

        lexer:CLOSE_BRACKET => { // Initialize the current structure

            // Check if the table key is already defined.
            string tableKeyName = keyName + tomlKey;
            check verifyTableKey(state, tableKeyName);
            state.definedTableKeys.push(tableKeyName);
            state.currentTableKey = tableKeyName;

            // Cannot define a standard table for an already defined array table.
            if (structure.hasKey(tomlKey) && !(structure[tomlKey] is map<json>)) {
                return generateError(state, check formatErrorMessage(2, value = tableKeyName));
            }

            state.currentStructure = structure[tomlKey] is map<json> ? <map<json>>structure[tomlKey] : {};
            return;
        }
    }

}

# Process the grammar rules of initializing an array table.
#
# + structure - Mapping of the parent key
# + keyName - Recursively constructing the table key name
# + return - An error if the grammar rules are not met or any duplicate values. 
function arrayTable(ParserState state, map<json> structure, string keyName = "") returns lexer:LexicalError|ParsingError|() {

    // Verifies the current key
    string tomlKey = state.currentToken.value;
    state.keyStack.push(tomlKey);
    check verifyKey(state, structure, tomlKey);

    check checkToken(state);

    match state.currentToken.token {
        lexer:DOT => { // Build the dotted key
            check checkToken(state, [lexer:UNQUOTED_KEY, lexer:BASIC_STRING, lexer:LITERAL_STRING]);
            return check arrayTable(state, structure[tomlKey] is map<json> ? <map<json>>structure[tomlKey] : {}, tomlKey + ".");
        }

        lexer:ARRAY_TABLE_CLOSE => { // Initialize the current structure

            // Check if there is an static array or a standard table key already defined.
            check verifyTableKey(state, keyName + tomlKey);

            // Cannot define an array table for already defined standard table.
            if (structure.hasKey(tomlKey) && !(structure[tomlKey] is json[])) {
                return generateError(state, check formatErrorMessage(2, value = keyName + tomlKey));
            }

            // An array table always create a new object.
            state.currentStructure = {};
            return;
        }
    }
}
