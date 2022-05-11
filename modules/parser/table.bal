import toml.lexer;

# Process the grammar rules of inline tables.
#
# + state - Current parser state
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
# + state - Current parser state
# + structure - Mapping of the parent key
# + keyName - Recursively constructing the table key name
# + return - An error if the grammar rules are not met or any duplicate values.
function standardTable(ParserState state, map<json> structure, string keyName = "") returns lexer:LexicalError|ParsingError|() {

    // Verifies the current key
    string tomlKey = state.currentToken.value;
    string tomlKeyRepresent = getTomlKey(state);
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
            check verifyTableKey(state, keyName + tomlKeyRepresent);
            state.addTableKey(tableKeyName);
            state.currentTableKey = tableKeyName;

            // Cannot define a standard table for an already defined array table.
            if (structure.hasKey(tomlKey) && !(structure[tomlKey] is map<json>)) {
                return generateError(state, formateDuplicateErrorMessage(tableKeyName));
            }

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
function arrayTable(ParserState state, map<json> structure, string keyName = "") returns lexer:LexicalError|ParsingError|() {

    // Verifies the current key
    string tomlKey = state.currentToken.value;
    string tomlKeyRepresent = getTomlKey(state);
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
            check verifyTableKey(state, keyName + tomlKeyRepresent);
            state.addTableKey(keyName + tomlKey);

            // Cannot define an array table for already defined standard table.
            if (structure.hasKey(tomlKey) && !(structure[tomlKey] is json[])) {
                return generateError(state, formateDuplicateErrorMessage(keyName + tomlKey));
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
# + key - Key to be verified in the structure  
# + return - Error, if there already exists a primitive value.
function verifyKey(ParserState state, map<json>? structure, string key) returns ParsingError? {
    if (structure is map<json>) {
        map<json> castedStructure = <map<json>>structure;
        if (castedStructure.hasKey(key) && !(castedStructure[key] is json[] || castedStructure[key] is map<json>)) {
            return generateError(state, formateDuplicateErrorMessage(state.bufferedKey, "values"));
        }
    }
}

# TOML allows only once to define a standard key table.
# This function checks if the table key name already exists.
#
# + state - Current parser state
# + tableKeyName - Table key name to be checked
# + return - An error if the key already exists.  
function verifyTableKey(ParserState state, string tableKeyName) returns ParsingError? {
    if (state.definedTableKeys.indexOf(tableKeyName) != ()
        || state.tempTableKeys.indexOf(tableKeyName) != ()) {
        return generateError(state, formateDuplicateErrorMessage(tableKeyName, "table key"));
    }
}

function getTomlKey(ParserState state) returns string {
    if state.currentToken.token == lexer:BASIC_STRING {
        return string `\"${state.currentToken.value}\"`;
    }
    if state.currentToken.token == lexer:LITERAL_STRING {
        return string `'${state.currentToken.value}'`;
    }
    return state.currentToken.value;
}
