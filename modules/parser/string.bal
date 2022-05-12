import toml.lexer;

# Process multi-line basic string.
#
# + state - Current parser state
# + return - An error if the grammar rule is not made  
function multiBasicString(ParserState state) returns lexer:LexicalError|ParsingError|string {
    state.updateLexerContext(lexer:MULTILINE_BASIC_STRING);
    string lexemeBuffer = "";
    boolean isFirstLine = true;
    boolean isEscaped = false;
    boolean newLineInEscape = false;

    // Predict the next tokens
    check checkToken(state, [
        lexer:MULTILINE_BASIC_STRING_LINE,
        lexer:MULTILINE_BASIC_STRING_ESCAPE,
        lexer:MULTILINE_BASIC_STRING_DELIMITER,
        lexer:EOL
    ]);

    // Predicting the next tokens until the end of the string.
    while (state.currentToken.token != lexer:MULTILINE_BASIC_STRING_DELIMITER) {
        match state.currentToken.token {
            lexer:MULTILINE_BASIC_STRING_LINE => { // Regular basic string
                // When escaped, spaces are ignored and returns an empty string.
                if state.currentToken.value.length() != 0 {
                    isEscaped = false;
                    newLineInEscape = false;
                    lexemeBuffer += state.currentToken.value;
                }
            }
            lexer:MULTILINE_BASIC_STRING_ESCAPE => { // Escape token
                state.updateLexerContext(lexer:MULTILINE_ESCAPE);
                isEscaped = true;
            }
            lexer:EOL => { // Processing new lines
                check state.initLexer("Expected to end the multi-line basic string");

                // New lines are detected by the escaped
                if isEscaped {
                    newLineInEscape = true;
                }

                // Ignore new lines after the escape symbol
                if !(state.lexerState.context == lexer:MULTILINE_ESCAPE
                    || (isFirstLine && lexemeBuffer.length() == 0)) {
                    lexemeBuffer += "\n";
                }
                isFirstLine = false;
            }
        }
        check checkToken(state, [
            lexer:MULTILINE_BASIC_STRING_LINE,
            lexer:MULTILINE_BASIC_STRING_ESCAPE,
            lexer:MULTILINE_BASIC_STRING_DELIMITER,
            lexer:EOL
        ]);
    }

    // The escape does not work on whitespace without new lines.
    if isEscaped && !newLineInEscape {
        return generateError(state, "Cannot escape whitespace in multiline basic string");
    }

    state.updateLexerContext(lexer:EXPRESSION_KEY);
    return lexemeBuffer;
}

# Process multi-line literal string.
#
# + state - Current parser state
# + return - An error if the grammar production is not made.  
function multiLiteralString(ParserState state) returns lexer:LexicalError|ParsingError|string {
    state.updateLexerContext(lexer:MULTILINE_LITERAL_STRING);
    string lexemeBuffer = "";
    boolean isFirstLine = true;

    // Predict the next tokens
    check checkToken(state, [
        lexer:MULTILINE_LITERAL_STRING_LINE,
        lexer:MULTILINE_LITERAL_STRING_DELIMITER,
        lexer:EOL
    ]);

    // Predicting the next tokens until the end of the string.
    while (state.currentToken.token != lexer:MULTILINE_LITERAL_STRING_DELIMITER) {
        match state.currentToken.token {
            lexer:MULTILINE_LITERAL_STRING_LINE => { // Regular literal string
                lexemeBuffer += state.currentToken.value;
            }
            lexer:EOL => { // Processing new lines    
                check state.initLexer(formatExpectErrorMessage(state.currentToken.token, lexer:MULTILINE_LITERAL_STRING_DELIMITER, lexer:MULTILINE_BASIC_STRING_DELIMITER));

                if !(isFirstLine && lexemeBuffer.length() == 0) {
                    lexemeBuffer += "\n";
                }
                isFirstLine = false;
            }
        }
        check checkToken(state, [
            lexer:MULTILINE_LITERAL_STRING_LINE,
            lexer:MULTILINE_LITERAL_STRING_DELIMITER,
            lexer:EOL
        ]);
    }

    state.updateLexerContext(lexer:EXPRESSION_KEY);
    return lexemeBuffer;
}
