import toml.lexer;

# Handles the rule: key -> simple-key | dotted-key
# key_value -> key '=' value.
# The 'dotted-key' is being called recursively. 
# At the terminal, a value is assigned to the last key, 
# and nested under the previous key's map if exists.
#
# + state - Current parser state
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
            structure[tomlKey] = check keyValue(state, structure[tomlKey] is map<json> ? <map<json>>structure[tomlKey] : {});
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

            if state.currentToken.token == lexer:INLINE_TABLE_OPEN {
                state.definedInlineTables.push(state.bufferedKey);

                // Existing tables cannot be overwritten by inline tables
                if structure[tomlKey] is map<json> {
                    return generateDuplicateError(state, state.bufferedKey);
                }
            }

            structure[tomlKey] = check dataValue(state);
            return structure;
        }
        _ => {
            return generateExpectError(state, [lexer:DOT, lexer:KEY_VALUE_SEPARATOR], lexer:UNQUOTED_KEY);
        }
    }
}

# Generate any TOML data value.
#
# + state - Current parser state
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
            if !state.isArrayTable {
                state.addTableKey(state.currentTableKey.length() == 0 ? state.bufferedKey : state.currentTableKey + "." + state.bufferedKey);
                state.bufferedKey = "";
            }
        }
        lexer:INLINE_TABLE_OPEN => {
            returnData = check inlineTable(state);

            // Inline tables cannot be redefined by the standard tables.
            if !state.isArrayTable {
                state.addTableKey(state.currentTableKey.length() == 0 ? state.bufferedKey : state.currentTableKey + "." + state.bufferedKey);
                state.bufferedKey = "";
            }
        }
        _ => { // Latter primitive data types
            returnData = state.currentToken.value;
        }
    }
    return returnData;
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
