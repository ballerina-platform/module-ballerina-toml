import ballerina/test;

@test:Config {}
function testFullLineComment() returns error? {
    Lexer lexer = setLexerString("# someComment");
    check assertToken(lexer, EOL);
}

@test:Config {}
function testEOLComment() returns error? {
    Lexer lexer = setLexerString("someKey = \"someValue\" # someComment");
    check assertToken(lexer, EOL, 7);
}

@test:Config {}
function testMultipleWhiteSpaces() returns error? {
    Lexer lexer = setLexerString("  ");
    check assertToken(lexer, WHITESPACE);
    check assertToken(lexer, EOL);
}

@test:Config {}
function testUnquotedKey() returns error? {
    Lexer lexer = setLexerString("somekey = \"Some Value\"");
    check assertToken(lexer, UNQUOTED_KEY, lexeme = "somekey");
}

@test:Config {}
function testUnquotedKeyWithInvalidChar() {
    Lexer lexer = setLexerString("some$value = 1");
    assertLexicalError(lexer);
}

@test:Config {}
function testKeyValueSeperator() returns error? {
    Lexer lexer = setLexerString("somekey = 1");
    check assertToken(lexer, WHITESPACE, 2);
    check assertToken(lexer, KEY_VALUE_SEPERATOR);
    check assertToken(lexer, WHITESPACE);
}

@test:Config {}
function testBasicString() returns error? {
    Lexer lexer = setLexerString("someKey = \"someValue\"");
    check assertToken(lexer, BASIC_STRING, 5, "someValue");
}

# Returns a new lexer with the configured line for testing
#
# + line - Testing TOML string
# + return - Configured lexer  
function setLexerString(string line) returns Lexer {
    Lexer lexer = new Lexer();
    lexer.line = line;
    return lexer;
}

# Assert the token at the given index
#
# + lexer - Testing lexer  
# + assertingToken - Expected TOML token  
# + index - Index of the targetted token (default = 0) 
# + lexeme - Expected lexeme of the token (optional)
# + return - Returns an lexical error if unsuccessful
function assertToken(Lexer lexer, TOMLToken assertingToken, int index = 0, string lexeme = "") returns error? {
    Token token = check getToken(lexer, index);

    test:assertEquals(token.token, assertingToken);

    if (lexeme != "") {
        test:assertEquals(token.value, lexeme);
    }
}

# Assert if a lexical error is generated during the tokenization
#
# + lexer - Testing lexer 
# + index - Index of the targetted token (defualt = 0)
function assertLexicalError(Lexer lexer, int index = 0) {
    Token|error token = getToken(lexer, index);
    test:assertTrue(token is LexicalError);
}

# Obtian the token at the given index
#
# + lexer - Testing lexer
# + index - Index of the targetted token
# + return - If success, returns the token. Else a Lexical Error.  
function getToken(Lexer lexer, int index) returns Token|error {
    Token token;

    if (index == 0) {
        token = check lexer.getToken();
    } else {
        foreach int i in 0 ... index - 1 {
            token = check lexer.getToken();
        }
    }

    return token;
}
