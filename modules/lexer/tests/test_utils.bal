import ballerina/test;

# Returns a new lexer with the configured line for testing
#
# + testingLine - Testing TOML string  
# + lexerState - The state for the lexer to be initialized with
# + return - Originated lexer state for testing
function setLexerString(string testingLine, Context lexerState = EXPRESSION_KEY) returns LexerState {
    LexerState state = new ();
    state.line = testingLine;
    state.context = lexerState;
    return state;
}

# Assert the token at the given index
#
# + state - Lexer state configured for testing  
# + assertingToken - Expected TOML token  
# + currentIndex - Index of the targeted token (default = 0)  
# + lexeme - Expected lexeme of the token (optional)
# + return - Returns an lexical error if unsuccessful
function assertToken(LexerState state, TOMLToken assertingToken, int currentIndex = 0, string lexeme = "") returns error? {
    Token token = check getToken(state, currentIndex);

    test:assertEquals(token.token, assertingToken);

    if (lexeme != "") {
        test:assertEquals(token.value, lexeme);
    }
}

# Assert if a lexical error is generated during the tokenization
#
# + tomlString - String to generate a Lexer token  
# + currentIndex - Index of the targeted token (default = 0)
function assertLexicalError(string tomlString, int currentIndex = 0) {
    Token|error token = getToken(setLexerString(tomlString), currentIndex);
    test:assertTrue(token is LexicalError);
}

# Obtain the token at the given index
#
# + state - Lexer state configured for testing  
# + currentIndex - Index of the targeted token
# + return - If success, returns the token. Else a Lexical Error.
function getToken(LexerState state, int currentIndex) returns Token|error {
    LexerState updatedState = state;
    Token token;

    if (currentIndex == 0) {
        updatedState = check scan(state);
        token = updatedState.getToken();
    } else {
        foreach int i in 0 ... currentIndex - 1 {
            updatedState = check scan(updatedState);
            token = updatedState.getToken();
        }
    }

    return token;
}
