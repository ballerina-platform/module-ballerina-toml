import ballerina/test;

const ORIGIN_FILE_PATH = "toml/tests/resources/";

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

# Assert if the key and value is properly set in the TOML object.
#
# + toml - TOML object to be asserted  
# + key - Expected key  
# + value - Expected value of the key  
function assertKey(map<any> toml, string key, string value) {
    test:assertTrue(toml.hasKey(key));
    test:assertEquals(<string>toml[key], value);
}

# Assert if an parsing error is generated during the parsing
#
# + text - If isFile is set, file path else TOML string  
# + isFile - If set, reads the TOML file. default = false.  
function assertParsingError(string text, boolean isFile = false) {
    map<any>|error toml = isFile ? readFile(ORIGIN_FILE_PATH + text + ".toml") : read(text);
    test:assertTrue(toml is ParsingError);
}

# Assertions to validate the values of the TOML object.  
class AssertKey {
    private map<any> toml;

    # Init the AssertKey class.
    #
    # + text - If isFile is set, file path else TOML string  
    # + isFile - If set, reads the TOML file. default = false.    
    function init(string text, boolean isFile = false) returns error? {
        self.toml = isFile ? check readFile(ORIGIN_FILE_PATH + text + ".toml") : check read(text);
    }

    function hasKey(string tomlKey, anydata tomlValue) returns AssertKey {
        test:assertTrue(self.toml.hasKey(tomlKey));
        test:assertEquals(<string>self.toml[tomlKey], tomlValue);
        return self;
    }

    function close() {
        return;
    }
}
