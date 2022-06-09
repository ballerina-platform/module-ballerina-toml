import toml.lexer;

# Handles the grammar production of creating or retrieving an object 
# for the key and assign the value to the latest key.
# The latest key is nested under the previous key's map if exists.
#
# + state - Current parser state
# + structure - The structure for the previous key. Null if there is no value.
# + return - Returns the structure after assigning the value.
function keyValue(ParserState state, map<json> structure) returns map<json>|ParsingError {
    // Validate the first key
    check verifyKey(state, structure);
    [string, map<json>][] dottedTableStack = [[state.currentToken.value, structure]];
    check checkToken(state);

    // Check and validate the dotted key 
    map<json> parentStructure;
    string parentKey;
    while state.currentToken.token == lexer:DOT {
        // Expects another key after the dot
        check checkToken(state, [lexer:UNQUOTED_KEY, lexer:BASIC_STRING, lexer:LITERAL_STRING]);

        // Update the buffered key
        state.bufferedKey += "." + state.currentToken.value;

        // Obtain the parent structure of the current key
        [parentKey, parentStructure] = dottedTableStack[dottedTableStack.length() - 1];

        // Obtain the structure which the current key exists and push it to the stack
        map<json> newStructure = parentStructure[parentKey] is map<json> ? <map<json>>parentStructure[parentKey] : {};
        check verifyKey(state, newStructure);
        dottedTableStack.push([state.currentToken.value, newStructure]);

        check checkToken(state);
    }

    // There should be '=' after the key
    if state.currentToken.token != lexer:KEY_VALUE_SEPARATOR {
        return generateExpectError(state, [lexer:DOT, lexer:KEY_VALUE_SEPARATOR], lexer:UNQUOTED_KEY);
    }

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

    // Obtain the current structure 
    string currentKey;
    map<json> currentStructure;
    [currentKey, currentStructure] = dottedTableStack.pop();

    if state.currentToken.token == lexer:INLINE_TABLE_OPEN {
        state.definedInlineTables.push(state.bufferedKey);

        // Existing tables cannot be overwritten by inline tables
        if currentStructure[currentKey] is map<json> {
            return generateDuplicateError(state, state.bufferedKey);
        }
    }

    // Assign the value to key
    currentStructure[currentKey] = check dataValue(state);
    map<json> prevStructure;

    // Construct the dotted key structure if exists
    while dottedTableStack.length() > 0 {
        prevStructure = currentStructure;
        [currentKey, currentStructure] = dottedTableStack.pop();
        currentStructure[currentKey] = prevStructure;
    }

    return currentStructure;
}

# Generate any TOML data value.
#
# + state - Current parser state
# + return - If success, returns the formatted data value. Else, an error.
function dataValue(ParserState state) returns json|ParsingError {
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
            check checkEmptyInteger(state);
            returnData = check processTypeCastingError(state, int:fromHexString(state.currentToken.value));
        }
        lexer:BINARY => {
            check checkEmptyInteger(state);
            returnData = check processInteger(state, 2);
        }
        lexer:OCTAL => {
            check checkEmptyInteger(state);
            returnData = check processInteger(state, 8);
        }
        lexer:INFINITY => {
            returnData = state.currentToken.value[0] == "+" ? float:Infinity : -float:Infinity;
        }
        lexer:NAN => {
            returnData = float:NaN;
        }
        lexer:BOOLEAN => {
            returnData = check processTypeCastingError(state, boolean:fromString(state.currentToken.value));
        }
        lexer:OPEN_BRACKET => {
            returnData = check array(state);

            // Static arrays cannot be redefined by the array tables.
            state.reserveKey();
        }
        lexer:INLINE_TABLE_OPEN => {
            returnData = check inlineTable(state);

            // Inline tables cannot be redefined by the standard tables.
            state.reserveKey();
        }
        _ => { // Latter primitive data types
            returnData = state.currentToken.value;
        }
    }
    return returnData;
}

# Evaluates an integer of a different base
#
# + state - Current parser state
# + numberSystem - Number system of the value
# + return - Processed integer. Error if there is a string.
function processInteger(ParserState state, int numberSystem) returns int|ParsingError {
    int value = 0;
    int power = 1;
    int length = state.currentToken.value.length() - 1;
    foreach int i in 0 ... length {
        value += <int>(check processTypeCastingError(state, 'int:fromString(state.currentToken.value[length - i]))) * power;
        power *= numberSystem;
    }
    return value;
}

# Check if the digits are empty.
#
# + state - Current parser state
# + return - An error on empty digits
function checkEmptyInteger(ParserState state) returns GrammarError? {
    if state.currentToken.value.length() == 0 {
        return generateGrammarError(state, "Digits cannot be empty");
    }
}
