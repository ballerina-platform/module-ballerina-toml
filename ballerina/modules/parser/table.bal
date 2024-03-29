// Copyright (c) 2022, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import toml.lexer;

# Process the grammar rules of inline tables.
#
# + state - Current parser state
# + tempTable - Recursively constructing inline table
# + isStart - True if the function is being called for the first time.
# + return - Map structure representing the table on success. Else, an error if the grammar rules are not met.
isolated function inlineTable(ParserState state, map<json> tempTable = {}, boolean isStart = true)
    returns map<json>|ParsingError {

    state.updateLexerContext(lexer:EXPRESSION_KEY);
    check checkToken(state, [
        lexer:UNQUOTED_KEY,
        lexer:BASIC_STRING,
        lexer:LITERAL_STRING,
        isStart ? lexer:INLINE_TABLE_CLOSE : lexer:DUMMY
    ]);

    // This is unreachable after a separator.
    // This condition is only available to create an empty table.
    if state.currentToken.token == lexer:INLINE_TABLE_CLOSE {
        return tempTable;
    }

    // Add the key value to the inline table.
    map<json> newTable = check keyValue(state, tempTable.clone());

    if state.tokenConsumed {
        state.tokenConsumed = false;
    } else {
        check checkToken(state, [lexer:SEPARATOR, lexer:INLINE_TABLE_CLOSE]);
    }

    // Calls the method recursively to add new key values.
    if state.currentToken.token == lexer:SEPARATOR {
        return check inlineTable(state, newTable, false);
    }

    return newTable;
}

# Process the grammar rules for initializing the standard table.
# Sets a new current structure, so the succeeding key value pairs are added to it.
#
# + state - Current parser state
# + structure - Mapping of the parent key
# + keyName - Recursively constructing the table key name
# + return - An error if the grammar rules are not met or any duplicate values.
isolated function standardTable(ParserState state, map<json> structure, string keyName = "") returns ParsingError|() {

    // Verifies the current key
    string tomlKey = state.currentToken.value;
    string tomlKeyRepresent = getTomlKey(state);
    state.keyStack.push(tomlKey);
    check verifyKey(state, structure);

    check checkToken(state, [lexer:DOT, lexer:CLOSE_BRACKET]);

    match state.currentToken.token {
        lexer:DOT => { // Build the dotted key
            check checkToken(state, [lexer:UNQUOTED_KEY, lexer:BASIC_STRING, lexer:LITERAL_STRING]);
            return check standardTable(state, structure[tomlKey] is map<json> ? <map<json>>structure[tomlKey] : {}, keyName + tomlKey + ".");
        }

        lexer:CLOSE_BRACKET => { // Initialize the current structure

            // Check if the table key is already defined.
            string tableKeyName = keyName + tomlKey;
            check verifyTableKey(state, keyName + tomlKeyRepresent);
            check checkExtensionOfInlineTable(state, keyName + tomlKeyRepresent);
            state.addTableKey(tableKeyName);
            state.currentTableKey = tableKeyName;

            state.currentStructure = structure[tomlKey] is map<json> ? <map<json>>structure[tomlKey] : {};
            return;
        }
    }

}

# Process the grammar rules of initializing an array table.
#
# + state - Current parser state
# + structure - Mapping of the parent key
# + keyName - Recursively constructing the table key name
# + return - An error if the grammar rules are not met or any duplicate values. 
isolated function arrayTable(ParserState state, map<json> structure, string keyName = "") returns ParsingError|() {

    // Verifies the current key
    string tomlKey = state.currentToken.value;
    string tomlKeyRepresent = getTomlKey(state);
    state.keyStack.push(tomlKey);
    check verifyKey(state, structure);

    check checkToken(state, [lexer:DOT, lexer:ARRAY_TABLE_CLOSE]);

    match state.currentToken.token {
        lexer:DOT => { // Build the dotted key
            check checkToken(state, [lexer:UNQUOTED_KEY, lexer:BASIC_STRING, lexer:LITERAL_STRING]);
            return check arrayTable(state, structure[tomlKey] is map<json> ? <map<json>>structure[tomlKey] : {}, tomlKey + ".");
        }

        lexer:ARRAY_TABLE_CLOSE => { // Initialize the current structure

            // Check if there is an static array or a standard table key already defined.
            check verifyTableKey(state, keyName + tomlKeyRepresent);
            check checkExtensionOfInlineTable(state, keyName + tomlKeyRepresent);
            state.addTableKey(keyName + tomlKey);

            // Cannot define an array table for already defined standard table.
            if structure.hasKey(tomlKey) && !(structure[tomlKey] is json[]) {
                return generateDuplicateError(state, keyName + tomlKey);
            }

            // An array table always create a new object.
            state.currentStructure = {};
            return;
        }
    }
}

# If the structure exists and already assigned a primitive value,
# then it is invalid to assign a value to it or nested to it.
#
# + state - Current parser state
# + structure - Parent key of the provided one 
# + return - Error, if there already exists a primitive value.
isolated function verifyKey(ParserState state, map<json>? structure) returns ParsingError? {
    string tomlKey = state.currentToken.value;
    if structure is map<json> {
        map<json> castedStructure = <map<json>>structure;
        if castedStructure.hasKey(tomlKey) && !(castedStructure[tomlKey] is json[] || castedStructure[tomlKey] is map<json>) {
            return generateDuplicateError(state, state.bufferedKey, "values");
        }
    }
    check verifyTableKey(state, state.currentTableKey == "" ? state.bufferedKey : state.currentTableKey + "." + state.bufferedKey);
}

# TOML allows only once to define a standard key table.
# This function checks if the table key name already exists.
#
# + state - Current parser state
# + tableKeyName - Table key name to be checked
# + return - An error if the key already exists.  
isolated function verifyTableKey(ParserState state, string tableKeyName) returns ParsingError? {
    if state.definedTableKeys.indexOf(tableKeyName) != ()
        || state.tempTableKeys.indexOf(tableKeyName) != ()
        || (!state.isArrayTable && state.definedArrayTableKeys.indexOf(tableKeyName) != ()) {
        return generateDuplicateError(state, tableKeyName, "table key");
    }
}

# Obtain the key with proper quotations if exists.
#
# + state - Current lexer state
# + return - TOML key with proper quotations
isolated function getTomlKey(ParserState state) returns string {
    if state.currentToken.token == lexer:BASIC_STRING {
        return string `\"${state.currentToken.value}\"`;
    }
    if state.currentToken.token == lexer:LITERAL_STRING {
        return string `'${state.currentToken.value}'`;
    }
    return state.currentToken.value;
}

# Check if the standard table key is an extension of array table since it is immutable.
#
# + state - Current parser state
# + tableKey - Table to check if it is valid
# + return - True if is an extension
isolated function checkExtensionOfInlineTable(ParserState state, string tableKey) returns GrammarError? {
    foreach string inlineTableKey in state.definedInlineTables {
        if tableKey.startsWith(inlineTableKey) && tableKey[inlineTableKey.length()] == "." {
            return generateGrammarError(state, "Inline tables are immutable");
        }
    }
}
