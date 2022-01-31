import ballerina/lang.'int;
import ballerina/lang.'boolean;

type ParsingError distinct error;

class Parser {
    # Input TOML lines
    private string[] lines;
    private int numLines;
    private int lineIndex;

    # Current token
    private Token currentToken;

    # Hold the lexemes until the final value is generated
    private string lexemeBuffer;

    # Output TOML object
    private map<anydata> tomlObject;

    # Current map structure the parser is working on
    private map<anydata> currentStructure;

    # Key stack to the current structure
    private string[] keyStack;

    # Lexical analyzer tool for getting the tokens
    private Lexer lexer;

    function init(string[] lines) {
        self.lines = lines;
        self.numLines = lines.length();
        self.lexer = new Lexer();
        self.currentToken = {token: DUMMY};
        self.tomlObject = {};
        self.currentStructure = {};
        self.keyStack = [];
        self.lineIndex = 0;
        self.lexemeBuffer = "";
    }

    # Generates a map object for the TOML document.
    # Initally, considers the predictions for the 'expression', 'table', and 'array table'
    #
    # + return - If success, map object for the TOMl document. 
    # Else, a lexical or a parser error. 
    public function parse() returns map<anydata>|error {

        // Iterating each document line
        while self.lineIndex < self.numLines {
            if (!self.initLexer(false)) {
                return self.generateError("Cannot open TOML document");
            }
            self.currentToken = check self.lexer.getToken();
            self.lexer.state = EXPRESSION_KEY;

            match self.currentToken.token {
                UNQUOTED_KEY|BASIC_STRING|LITERAL_STRING => { // Process a key value
                    map<anydata> output = check self.keyValue(self.tomlObject);

                    // Add the key-value pair to the final TOML object.
                    string tomlKey = output.keys()[0];
                    self.tomlObject[tomlKey] = output[tomlKey];

                    self.lexer.state = EXPRESSION_KEY;
                    self.lexemeBuffer = "";
                }
                OPEN_BRACKET => { // Process a standard tale
                    check self.standardTable(self.tomlObject);
                }
                DOUBLE_OPEN_BRACKET => { // Process an array table

                }
            }

            // Comments and new lines are ignored.
            // However, other expressions cannot have addtional tokens in their line.
            if (self.currentToken.token != EOL) {
                check self.checkToken(EOL, "Cannot have anymore tokens in the same line");
            }

            self.lineIndex += 1;
        }

        // Return the TOML object
        // self.tomlObject = check self.buildTOMLObject(self.tomlObject);
        return self.tomlObject;
    }

    # Assert the next lexer token with the predicted token.
    #
    # + expectedTokens - Predicted token or tokens
    # + errorMessage - Parsing error if expected token not found  
    # + return - Parsing error if not found
    private function checkToken(TOMLToken|TOMLToken[] expectedTokens, string errorMessage) returns error? {
        self.currentToken = check self.lexer.getToken();

        // Generate an error if the expected token differ from the actual token.
        if (expectedTokens is TOMLToken) {
            if (self.currentToken.token != expectedTokens) {
                return self.generateError(errorMessage);
            }
        } else {
            if (expectedTokens.indexOf(self.currentToken.token) == ()) {
                return self.generateError(errorMessage);
            }
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
    private function keyValue(map<anydata>? structure) returns map<anydata>|error {
        string tomlKey = self.currentToken.value;

        check self.checkToken([DOT, KEY_VALUE_SEPERATOR], "Expected a '.' or a '=' after a key");

        match self.currentToken.token {
            DOT => {
                check self.checkToken([UNQUOTED_KEY, BASIC_STRING, LITERAL_STRING], "Expected a key after '.'");

                // If the structure exists and already assigned a value that is not a table,
                // then it is invalid to assign a value to it or nested to it.
                if (structure is map<anydata>) {
                    map<anydata> castedStructure = <map<anydata>>structure;
                    if (castedStructure.hasKey(tomlKey) && !(castedStructure[tomlKey] is map<anydata>)) {
                        return self.generateError("Duplicate values exists");
                    }
                }

                map<anydata> value = check self.keyValue(structure[tomlKey] is map<anydata> ? <map<anydata>>structure[tomlKey] : ());
                return self.buildInternalTable(tomlKey, value, structure);
            }

            KEY_VALUE_SEPERATOR => {
                self.lexer.state = EXPRESSION_VALUE;

                check self.checkToken([ // TODO: add the remaning values
                    BASIC_STRING,
                    LITERAL_STRING,
                    MULTI_BSTRING_DELIMITER,
                    MULTI_LSTRING_DELIMITER,
                    INTEGER,
                    OPEN_BRACKET,
                    BOOLEAN
                ], "Expected a value after '='");

                if (structure is map<anydata> && (<map<anydata>>structure).hasKey(tomlKey)) {
                    return self.generateError("Duplicate key '" + tomlKey + "'");
                } else {
                    return self.buildInternalTable(tomlKey, check self.dataValue(), structure);
                }
            }
            _ => {
                return self.generateError("Expected a '.' or a '=' after a key");
            }
        }
    }

    private function dataValue() returns anydata|error {
        anydata returnData;
        match self.currentToken.token {
            MULTI_BSTRING_DELIMITER => {
                check self.multiBasicString();
                returnData = self.lexemeBuffer;
            }
            MULTI_LSTRING_DELIMITER => {
                check self.multiLiteralString();
                returnData = self.lexemeBuffer;
            }
            INTEGER => {
                returnData = check self.number();
            }
            BOOLEAN => {
                returnData = check self.processTypeCastingError('boolean:fromString(self.currentToken.value));
            }
            OPEN_BRACKET => {
                returnData = check self.array();
            }
            _ => {
                returnData = self.currentToken.value;
            }
        }
        self.lexemeBuffer = "";
        return returnData;
    }

    private function multiBasicString() returns error? {
        self.lexer.state = MULTILINE_BSTRING;
        self.lexemeBuffer = "";

        // Predict the next toknes
        check self.checkToken([
            MULTI_BSTRING_CHARS,
            MULTI_BSTRING_ESCAPE,
            MULTI_BSTRING_DELIMITER,
            EOL
        ], "Invalid token inside a multi-line string");

        // Predicting the next tokens until the end of the string.
        while (self.currentToken.token != MULTI_BSTRING_DELIMITER) {
            match self.currentToken.token {
                MULTI_BSTRING_CHARS => { // Regular basic string
                    self.lexemeBuffer += self.currentToken.value;
                }
                MULTI_BSTRING_ESCAPE => { // Escape token
                    self.lexer.state = MULTILINE_ESCAPE;
                }
                EOL => { // Processing new lines
                    if (!self.initLexer()) {
                        return self.generateError("Expected to end the multi-line basic string");
                    }
                    if !(self.lexer.state == MULTILINE_ESCAPE) {
                        self.lexemeBuffer += "\\n";
                    }
                }
            }
            check self.checkToken([
                MULTI_BSTRING_CHARS,
                MULTI_BSTRING_ESCAPE,
                MULTI_BSTRING_DELIMITER,
                EOL
            ], "Invalid token inside a multi-line string");
        }

        self.lexer.state = EXPRESSION_KEY;
    }

    private function multiLiteralString() returns error? {
        self.lexer.state = MULITLINE_LSTRING;
        self.lexemeBuffer = "";

        // Predict the next toknes
        check self.checkToken([
            MULTI_LSTRING_CHARS,
            MULTI_LSTRING_DELIMITER,
            EOL
        ], "Invalid token inside a multi-line string");

        // Predicting the next tokens until the end of the string.
        while (self.currentToken.token != MULTI_LSTRING_DELIMITER) {
            match self.currentToken.token {
                MULTI_LSTRING_CHARS => { // Regular literal string
                    self.lexemeBuffer += self.currentToken.value;
                }
                EOL => { // Processing new lines
                    if (!self.initLexer()) {
                        return self.generateError("Expected to end the multi-line literal string");
                    }
                    self.lexemeBuffer += "\\n";
                }
            }
            check self.checkToken([
                MULTI_LSTRING_CHARS,
                MULTI_LSTRING_DELIMITER,
                EOL
            ], "Invalid token inside a multi-line string");
        }

        self.lexer.state = EXPRESSION_KEY;
    }

    # Handles the grammar rules of integers and float numbers.
    #
    # + fractional - Flag is set when processing the fractional segment
    # + return - Parsing error if occurred
    private function number(boolean fractional = false) returns anydata|error {
        self.lexemeBuffer += self.currentToken.value;
        check self.checkToken([EOL, EXPONENTIAL, DOT, ARRAY_SEPARATOR, CLOSE_BRACKET], "Invalid token after an integer");

        match self.currentToken.token {
            EOL|ARRAY_SEPARATOR|CLOSE_BRACKET => { // Generate the final number
                return fractional ? check self.processTypeCastingError('float:fromString(self.lexemeBuffer))
                                        : check self.processTypeCastingError('int:fromString(self.lexemeBuffer));
            }
            EXPONENTIAL => { // Handles exponential numbers
                check self.checkToken(INTEGER, "Expected an integer after the exponential");

                // Evaluating the exponential value
                float exponent = <float>(check self.processTypeCastingError('float:fromString(self.currentToken.value)));
                float prefix = <float>(check self.processTypeCastingError('float:fromString(self.lexemeBuffer)));
                return prefix * 'float:pow(10, exponent);
            }
            DOT => { // Handles fractional numbers
                if (fractional) {
                    return self.generateError("Cannot have a decimal point in the fraction part");
                }
                check self.checkToken(INTEGER, "Expected an integer after the decimal point");
                self.lexemeBuffer += ".";
                return check self.number(true);
            }
        }
    }

    private function array(anydata[] tempArray = [], boolean isStart = true) returns anydata[]|error {

        check self.checkToken([ // TODO: add the remaning values
            BASIC_STRING,
            LITERAL_STRING,
            MULTI_BSTRING_DELIMITER,
            MULTI_LSTRING_DELIMITER,
            INTEGER,
            BOOLEAN,
            OPEN_BRACKET,
            CLOSE_BRACKET,
            EOL,
            ARRAY_SEPARATOR
        ], "Expected a value after '='");

        match self.currentToken.token {
            EOL => {
                if (self.initLexer()) {
                    return self.array(tempArray, false);
                }
                return self.generateError("Exptected ']' at the end of an array");
            }
            CLOSE_BRACKET => { // If the array ends with a ','
                return tempArray;
            }
            INTEGER => { // Tokens that have consumed the next token
                tempArray.push(check self.dataValue());
                return self.currentToken.token == CLOSE_BRACKET ? tempArray : self.array(tempArray, false);
            }
            _ => { // Array value
                tempArray.push(check self.dataValue());
                check self.checkToken([ARRAY_SEPARATOR, CLOSE_BRACKET], "Expected an ',' or ']' after an array value");

                match self.currentToken.token {
                    CLOSE_BRACKET => { // End of the array value
                        return tempArray;
                    }
                    ARRAY_SEPARATOR => { // Expects another array value
                        return self.array(tempArray, false);
                    }
                    _ => {
                        return self.generateError("Expected an ',' or ']' after an array value");
                    }
                }
            }
        }
    }

    private function standardTable(map<anydata>? structure) returns error? {
        // Add the previous table to the TOML object
        self.tomlObject = check self.buildTOMLObject(self.tomlObject);

        // Expected a table key
        check self.checkToken([UNQUOTED_KEY, BASIC_STRING, LITERAL_STRING], "Expected a key after '[' in a table key");
        string key = self.currentToken.value;

        check self.checkToken([DOT, CLOSE_BRACKET], "Expected '.' or ']' after a table key");

        match self.currentToken.token {
            DOT => { // Build the dotted key

                // return check self.standardTable();
            }

            CLOSE_BRACKET => {
                // Initialize the current structure
                // Check whether it is possible to add values

            }
        }

    }

    private function buildTOMLObject(map<anydata>? structure = ()) returns map<anydata>|error {
        // Under the root table
        if (self.keyStack.length() == 0) {
            return self.currentStructure;
        }

        // First key table
        if (self.keyStack.length() == 1) {
            string key = self.keyStack.pop();
            return self.buildInternalTable(key, self.currentStructure, structure);
        }

        // Dotted tables
        string key = self.keyStack.shift();
        map<anydata> value = check self.buildTOMLObject(structure[key] is map<anydata> ? <map<anydata>>structure[key] : ());
        return self.buildInternalTable(key, value, structure);

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

    private function initLexer(boolean incrementLine = true) returns boolean {
        if (incrementLine) {
            self.lineIndex += 1;
        }
        if (self.lineIndex >= self.numLines) {
            return false;
        }
        self.lexer.line = self.lines[self.lineIndex];
        self.lexer.index = 0;
        self.lexer.lineNumber = self.lineIndex;
        return true;
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
