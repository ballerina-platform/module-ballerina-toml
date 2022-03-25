import ballerina/test;

# Returns a new lexer with the configured line for testing
#
# + testingLine - Testing TOML string  
# + lexerState - The state for the lexer to be initialized with
function setLexerString(string testingLine, State lexerState = EXPRESSION_KEY) {
    line = testingLine;
    state = lexerState;
    index = 0;
    lineNumber = 0;
    lexeme = "";
}

# Assert the token at the given index
#
# + assertingToken - Expected TOML token  
# + currentIndex - Index of the targeted token (default = 0) 
# + lexeme - Expected lexeme of the token (optional)
# + return - Returns an lexical error if unsuccessful
function assertToken(TOMLToken assertingToken, int currentIndex = 0, string lexeme = "") returns error? {
    Token token = check getToken(currentIndex);

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
    setLexerString(tomlString);
    Token|error token = getToken(currentIndex);
    test:assertTrue(token is LexicalError);
}

# Obtain the token at the given index
#
# + currentIndex - Index of the targeted token
# + return - If success, returns the token. Else a Lexical Error.
function getToken(int currentIndex) returns Token|error {
    Token token;

    if (currentIndex == 0) {
        token = check scan();
    } else {
        foreach int i in 0 ... currentIndex - 1 {
            token = check scan();
        }
    }

    return token;
}
