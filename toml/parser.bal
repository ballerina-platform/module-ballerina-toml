type ParsingError distinct error;

class Parser {
    # Input TOML lines
    private string[] lines;
    private int numLines;

    # Output TOML object
    private map<any> tomlObject;

    # Current token
    private Token currentToken;

    # Lexical analyzer tool for getting the tokens
    private Lexer lexer;

    function init(string[] lines) {
        self.lines = lines;
        self.numLines = lines.length() - 1;
        self.tomlObject = {};
        self.lexer = new Lexer();
        self.currentToken = {token: EXPRESSION};
    }

    # Generates a map object for the TOML document.
    # Initally, considers the predictions for the 'expression'
    #
    # + return - If success, map object for the TOMl document. 
    # Else, a lexical or a parser error. 
    public function parse() returns map<any>|error {

        // Iterating each document line
        foreach int i in 0 ... self.numLines {
            self.lexer.line = self.lines[i];
            self.lexer.index = 0;
            self.lexer.lineNumber = i;

            self.currentToken = check self.lexer.getToken();

            match self.currentToken.token {
                UNQUOTED_KEY|QUOTED_KEY => {
                    check self.keyValue();
                }
            }
        }

        // Return the TOML object
        return self.tomlObject;
    }

    # Assert the next lexer token with the predicted token.
    #
    # + assertedToken - Predicted token
    # + errorMessage - Parsing error if expected token not found
    # + return - Parsing error if not found   
    private function checkToken(TOMLToken assertedToken, string errorMessage) returns error? {
        self.currentToken = check self.lexer.getToken();

        if (self.currentToken.token != assertedToken) {
            return self.generateError(errorMessage);
        }
    }

    # Assert the next lexer token with multiple predicted tokens.
    #
    # + assertedTokens - Predicted tokens
    # + errorMessage - Parsing error if expected token not found
    # + return - Parsing error if not found   
    private function checkMultipleTokens(TOMLToken[] assertedTokens, string errorMessage) returns error? {
        self.currentToken = check self.lexer.getToken();

        if (assertedTokens.indexOf(self.currentToken.token) == ()) {
            return self.generateError(errorMessage);
        }
    }

    # Checks the rule key_value -> key ws '=' ws value.
    # Builds a key value of the TOML object.
    # 
    # + return - Parsing error  
    private function keyValue() returns error? {
        string key = self.currentToken.value;

        check self.checkToken(WHITESPACE, "Expected a whitespace after a key value");
        check self.checkToken(KEY_VALUE_SEPERATOR, "Expected a '=' after a key");
        check self.checkToken(WHITESPACE, "Expected a whitespace after the '='");
        check self.checkMultipleTokens([
            BASIC_STRING,
            LITERAL_STRING
        ],
            "Expected a value after '='"
        );

        self.tomlObject[key] = self.currentToken.value;
    }

    # Generates a Parsing Error Error.
    #
    # + message - Error message
    # + return - Constructed Parsing Error message  
    private function generateError(string message) returns ParsingError {
        string text = "Parsing Error at line "
                        + self.lexer.lineNumber.toString()
                        + " index "
                        + self.lexer.index.toString()
                        + ": "
                        + message
                        + ".";
        return error ParsingError(text);
    }
}
