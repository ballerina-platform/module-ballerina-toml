type ParsingError distinct error;

class Parser {
    # Input TOML lines
    private string[] lines;
    private int numLines;

    # Output TOML object
    private map<anydata> tomlObject;

    # Current token
    private Token currentToken;

    # Next token
    private Token nextToken;

    # Lexical analyzer tool for getting the tokens
    private Lexer lexer;

    function init(string[] lines) {
        self.lines = lines;
        self.numLines = lines.length() - 1;
        self.tomlObject = {};
        self.lexer = new Lexer();
        self.currentToken = {token: DUMMY};
        self.nextToken = {token: DUMMY};
    }

    # Generates a map object for the TOML document.
    # Initally, considers the predictions for the 'expression'
    #
    # + return - If success, map object for the TOMl document. 
    # Else, a lexical or a parser error. 
    public function parse() returns map<anydata>|error {

        // Iterating each document line
        foreach int i in 0 ... self.numLines {
            self.lexer.line = self.lines[i];
            self.lexer.index = 0;
            self.lexer.lineNumber = i;

            self.currentToken = check self.lexer.getToken();

            match self.currentToken.token {
                UNQUOTED_KEY|BASIC_STRING|LITERAL_STRING => {
                    map<anydata> output = check self.keyValue(self.tomlObject.hasKey(self.currentToken.value));
                    string tomlKey = output.keys()[0];
                    self.tomlObject[tomlKey] = output[tomlKey];
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
    # + isNextToken - If flag set, obtains the next token. Else, calls the lexer for new token.
    # + return - Parsing error if not found
    private function checkToken(TOMLToken assertedToken, string errorMessage, boolean isNextToken = false) returns error? {
        self.currentToken = check self.lexer.getToken();

        if (self.currentToken.token != assertedToken) {
            return self.generateError(errorMessage);
        }
    }

    # Assert the next lexer token with multiple predicted tokens.
    #
    # + assertedTokens - Predicted tokens  
    # + errorMessage - Parsing error if expected token not found  
    # + isNextToken - If flag set, obtains the next token. Else, calls the lexer for new token.
    # + return - Parsing error if not found
    private function checkMultipleTokens(TOMLToken[] assertedTokens, string errorMessage, boolean isNextToken = false) returns error? {
        // self.currentToken = isNextToken ? self.nextToken : check self.lexer.getToken();
        self.currentToken = check self.lexer.getToken();

        if (assertedTokens.indexOf(self.currentToken.token) == ()) {
            return self.generateError(errorMessage);
        }
    }

    # Handles the rule: key -> simple-key | dotted-key
    #
    # + alreadyExists - Parameter Description
    # + return - Return Value Description
    private function keyValue(boolean alreadyExists) returns map<anydata>|error {
        string tomlKey = self.currentToken.value;
        self.nextToken = check self.lexer.getToken();

        match self.nextToken.token {
            DOT => {
                check self.checkMultipleTokens([UNQUOTED_KEY, BASIC_STRING, LITERAL_STRING], "Expected a key after '.'", true);
                map<anydata> value = check self.keyValue(self.tomlObject.hasKey(self.currentToken.value) && alreadyExists);
                map<anydata> returnValue = {};
                returnValue[tomlKey] = value;
                return returnValue;
            }
            KEY_VALUE_SEPERATOR => {
                check self.checkMultipleTokens([ // TODO: add the remaning values
                    BASIC_STRING,
                    LITERAL_STRING
                ], "Expected a value after '='");

                if (alreadyExists) {
                    return self.generateError("Duplicate key '" + tomlKey + "'");
                } else {
                    map<anydata> returnValue = {};
                    returnValue[tomlKey] = self.currentToken.value;
                    return returnValue;
                }
            }
            _ => {
                return self.generateError("Expected a '.' or a '=' after a key");
            }
        }
    }

    // # Checks the rule key_value -> key ws '=' ws value.
    // # Builds a key value of the TOML object.
    // #
    // # + return - Parsing error  

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
