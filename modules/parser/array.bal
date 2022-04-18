import toml.lexer;

# Process the rules after '[' or ','.
#
# + state - Current parser state  
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
# + state - Current parser state  
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
