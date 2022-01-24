import ballerina/lang.'int;
import ballerina/lang.'boolean;

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
            self.lexer.lexeme = "";
            self.lexer.state = EXPRESSION_KEY;

            self.currentToken = check self.lexer.getToken();

            match self.currentToken.token {
                UNQUOTED_KEY|BASIC_STRING|LITERAL_STRING => {
                    map<anydata> output = check self.keyValue(
                        self.tomlObject.hasKey(self.currentToken.value),
                        self.tomlObject);
                    string tomlKey = output.keys()[0];
                    self.tomlObject[tomlKey] = output[tomlKey];
                    self.lexer.state = EXPRESSION_KEY;
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
    # key_value -> key '=' value.
    # The 'dotted-key' is being called recursively. 
    # At the terminal, a value is assigned to the last key, 
    # and nested under the previous key's map if exists.
    #
    # + alreadyExists - There is an existing value for the previous key.
    # + structure - The structure for the previous key. Null if there is no value.
    # + return - Returns the structure after assigning the value.
    private function keyValue(boolean alreadyExists, map<anydata>? structure) returns map<anydata>|error {
        string tomlKey = self.currentToken.value;
        self.nextToken = check self.lexer.getToken();

        match self.nextToken.token {
            DOT => {
                check self.checkMultipleTokens([UNQUOTED_KEY, BASIC_STRING, LITERAL_STRING], "Expected a key after '.'", true);

                map<anydata> value = check self.keyValue(
                    // If the structure exists and already assigned a value that is not a table,
                    // Then it is invalid to assign a value to it or nested to it.
                    (structure is map<anydata> ? (<map<anydata>>structure).hasKey(tomlKey) : structure != () && alreadyExists),
                    structure[tomlKey] is map<anydata> ? <map<anydata>?>structure[tomlKey] : ()
                    );
                return self.buildInternalTable(tomlKey, value, structure);
            }

            KEY_VALUE_SEPERATOR => {
                self.lexer.state = EXPRESSION_VALUE;
                check self.checkMultipleTokens([ // TODO: add the remaning values
                    BASIC_STRING,
                    LITERAL_STRING,
                    INTEGER,
                    BOOLEAN
                ], "Expected a value after '='");

                if (structure is map<anydata> ? (<map<anydata>>structure).hasKey(tomlKey) : structure != () ? alreadyExists : true && alreadyExists) {
                    return self.generateError("Duplicate key '" + tomlKey + "'");
                } else {
                    return self.buildInternalTable(tomlKey, check self.getProcessedValue(), structure);
                }
            }
            _ => {
                return self.generateError("Expected a '.' or a '=' after a key");
            }
        }
    }

    # Cast the token to the respective Ballerina type.
    #
    # + return - returns the Ballerian type  
    private function getProcessedValue() returns anydata|ParsingError {
        match self.currentToken.token {
            BASIC_STRING|LITERAL_STRING => {
                return self.currentToken.value;
            }
            INTEGER => {
                return self.processTypeCastingError('int:fromString(self.currentToken.value));
            }
            BOOLEAN => {
                return self.processTypeCastingError('boolean:fromString(self.currentToken.value));
            }
        }
    }

    # Check errors during type casting to Ballerina types.
    #
    # + value - Value to be type casted.
    # + return - Value as a Ballerina data type  
    private function processTypeCastingError(anydata|error value) returns anydata|ParsingError {
        // Check if the type casting has any errors
        if value is error {
            return self.generateError("Invalid value for assignment");
        }

        // Returns the value on success
        return value;
    }

    # Constructs the internal table of the TOML object.
    #
    # + tomlKey - New key of the TOML object  
    # + tomlValue - Value of the key  
    # + structure - Already existing internal table
    # + return - Constructed inner table. 
    private function buildInternalTable(string tomlKey, anydata tomlValue, map<anydata>? structure) returns map<anydata> {

        // Creates a new structure and add the key value
        if (structure == ()) {
            map<anydata> returnValue = {};
            returnValue[tomlKey] = tomlValue;
            return returnValue;
        }
        
        // Add the key to the existing strcuture
        else {
            structure[tomlKey] = tomlValue;
            return structure;
        }
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
