import ballerina/test;

const ORIGIN_FILE_PATH = "toml/tests/resources/";

# Returns a new lexer with the configured line for testing
#
# + line - Testing TOML string  
# + lexerState - The state for the lexer to be initialized with
# + return - Configured lexer
function setLexerString(string line, State lexerState = EXPRESSION_KEY) returns Lexer {
    Lexer lexer = new Lexer();
    lexer.line = line;
    lexer.state = lexerState;
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
# + tomlString - String to generate a Lexer token  
# + index - Index of the targetted token (defualt = 0)
function assertLexicalError(string tomlString, int index = 0) {
    Lexer lexer = setLexerString(tomlString);
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
# + text - If isFile is set, file path else TOML string.
# + isFile - If set, reads the TOML file. default = false.  
# + isLexical - If set, checks for Lexical errors. Else, checks for Parsing errors.
function assertParsingError(string text, boolean isFile = false, boolean isLexical = false) {
    map<any>|error toml = isFile ? readFile(ORIGIN_FILE_PATH + text + ".toml") : read(text);
    if (isLexical) {
        test:assertTrue(toml is LexicalError);
    } else {
        test:assertTrue(toml is ParsingError);
    }

}

# Assertions to validate the values of the TOML object.  
class AssertKey {
    private map<anydata> toml;
    private map<anydata>? innerData;
    private string[] stack;

    # Init the AssertKey class.
    #
    # + text - If isFile is set, file path else TOML string  
    # + isFile - If set, reads the TOML file. default = false.    
    function init(string text, boolean isFile = false) returns error? {
        self.toml = isFile ? check readFile(ORIGIN_FILE_PATH + text + ".toml") : check read(text);
        self.innerData = ();
        self.stack = [];
    }

    # Assert the key and value of the TOML object.
    # Recall this method to check mulitple values of the same TOML object.
    #
    # + tomlKey - Expected key of the TOML object  
    # + tomlValue - Expected value of the key. If no value is provided, value won't be checked.
    # + return - AssertKey object to reapply methods.  
    function hasKey(string tomlKey, anydata tomlValue = ()) returns AssertKey {
        map<anydata> assertedMap = self.innerData ?: self.toml;

        test:assertTrue(assertedMap.hasKey(tomlKey));

        if (tomlValue != ()) {
            test:assertEquals(<anydata>assertedMap[tomlKey], tomlValue);
        }
        return self;
    }

    # Dive into an inner key and assert the value.
    #
    # + tomlKey - Inner key
    # + return - AssertKey object to reapply methods.    
    function dive(string tomlKey) returns AssertKey {

        // If the current node is the root
        if (self.innerData == ()) {
            self.innerData = <map<anydata>?>self.toml[tomlKey];
        }

        // If the current node is nested
        else {
            self.innerData = <map<anydata?>>self.innerData[tomlKey];
        }

        self.stack.push(tomlKey);
        return self;
    }

    # Hop out from the current inner key.
    #
    # + return - Return Value Description  
    function hop() returns AssertKey {

        // If the parent node is the root
        if (self.stack.length() == 1) {
            self.innerData = ();
            _ = self.stack.pop();
            return self;
        }

        // Set the innderData to its parent map
        map<anydata>? targettedObject;
        foreach int i in 0 ... self.stack.length() - 2 {
            targettedObject = <map<anydata>?>self.toml[self.stack[i]];
            _ = self.stack.remove(i);
        }
        self.innerData = targettedObject;

        return self;
    }

    # Invoke this after finish writing the assertions.  
    function close() {
        return;
    }
}
