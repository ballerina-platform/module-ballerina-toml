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

    # Already defined table keys
    private string[] definedTableKeys;

    # If the token for a next grammar rule has been bufferred to the current token
    private boolean tokenConsumed;

    # Buffers the key in the full format
    private string bufferedKey;

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
        self.definedTableKeys = [];
        self.tokenConsumed = false;
        self.bufferedKey = "";
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
                    self.bufferedKey = self.currentToken.value;
                    self.currentStructure = check self.keyValue(self.currentStructure.clone());
                    self.lexer.state = EXPRESSION_KEY;
                }
                OPEN_BRACKET => { // Process a standard tale
                    // Add the previous table to the TOML object
                    self.tomlObject = check self.buildTOMLObject(self.tomlObject.clone());

                    check self.checkToken([UNQUOTED_KEY, BASIC_STRING, LITERAL_STRING], "Expected a key after '[' in a table key");
                    check self.standardTable(self.tomlObject.clone());
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
        self.tomlObject = check self.buildTOMLObject(self.tomlObject.clone());
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
    # + structure - The structure for the previous key. Null if there is no value.
    # + return - Returns the structure after assigning the value.
    private function keyValue(map<anydata> structure) returns map<anydata>|error {
        string tomlKey = self.currentToken.value;
        check self.verifyKey(structure, tomlKey);
        check self.verifyTableKey(self.bufferedKey);

        check self.checkToken([DOT, KEY_VALUE_SEPERATOR], "Expected a '.' or a '=' after a key");

        match self.currentToken.token {
            DOT => {
                check self.checkToken([UNQUOTED_KEY, BASIC_STRING, LITERAL_STRING], "Expected a key after '.'");
                self.bufferedKey += "." + self.currentToken.value;
                map<anydata> value = check self.keyValue(structure[tomlKey] is map<anydata> ? <map<anydata>>structure[tomlKey] : {});
                structure[tomlKey] = value;
                return structure;
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
                    BOOLEAN,
                    INLINE_TABLE_OPEN
                ], "Expected a value after '='");

                structure[tomlKey] = check self.dataValue();
                return structure;

            }
            _ => {
                return self.generateError("Expected a '.' or a '=' after a key");
            }
        }
    }

    # If the structure exists and already assigned a value that is not a table,
    # then it is invalid to assign a value to it or nested to it.
    #
    # + structure - Structure which the key should exist in  
    # + key - Key to be verified in the structure  
    # + return - Error, if there already exists a non-table value
    private function verifyKey(map<anydata>? structure, string key) returns error? {
        if (structure is map<anydata>) {
            map<anydata> castedStructure = <map<anydata>>structure;
            if (castedStructure.hasKey(key) && !(castedStructure[key] is map<anydata>)) {
                // TODO: Improve the error message by stacking the parents
                return self.generateError("Duplicate values exists");
            }
        }
    }

    private function verifyTableKey(string tableKeyName) returns error?{
        if (self.definedTableKeys.indexOf(tableKeyName) != ()) {
            return self.generateError("Duplicate table key '" + tableKeyName + "'");
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
            INLINE_TABLE_OPEN => {
                returnData = check self.inlineTable();
                self.definedTableKeys.push(self.bufferedKey);
                self.bufferedKey = "";
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
        check self.checkToken([EOL, EXPONENTIAL, DOT, ARRAY_SEPARATOR, CLOSE_BRACKET, INLINE_TABLE_CLOSE], "Invalid token after an integer");

        match self.currentToken.token {
            EOL|ARRAY_SEPARATOR|CLOSE_BRACKET|INLINE_TABLE_CLOSE => { // Generate the final number
                self.tokenConsumed = true;
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

    private function array(anydata[] tempArray = []) returns anydata[]|error {

        check self.checkToken([ // TODO: add the remaning values
            BASIC_STRING,
            LITERAL_STRING,
            MULTI_BSTRING_DELIMITER,
            MULTI_LSTRING_DELIMITER,
            INTEGER,
            BOOLEAN,
            OPEN_BRACKET,
            CLOSE_BRACKET,
            INLINE_TABLE_OPEN,
            EOL,
            ARRAY_SEPARATOR
        ], "Expected a value or ']' after '['");

        match self.currentToken.token {
            EOL => {
                if (self.initLexer()) {
                    return self.array(tempArray);
                }
                return self.generateError("Exptected ']' at the end of an array");
            }
            CLOSE_BRACKET => { // If the array ends with a ','
                return tempArray;
            }
            _ => { // Array value
                tempArray.push(check self.dataValue());

                if (self.tokenConsumed) {
                    self.tokenConsumed = false;
                } else {
                    check self.checkToken([ARRAY_SEPARATOR, CLOSE_BRACKET], "Expected an ',' or ']' after an array value");
                }

                return self.currentToken.token == CLOSE_BRACKET ? tempArray : self.array(tempArray);
            }
        }
    }

    private function inlineTable(map<anydata> tempTable = {}, boolean isStart = true) returns map<anydata>|error {
        self.lexer.state = EXPRESSION_KEY;
        check self.checkToken([
            UNQUOTED_KEY,
            BASIC_STRING,
            LITERAL_STRING,
            isStart ? INLINE_TABLE_CLOSE : DUMMY
        ], "Expected a value or '}' after '{'");

        // This is unreachable after a separator.
        // This condition is only available to create an empty table.
        if (self.currentToken.token == INLINE_TABLE_CLOSE) {
            return tempTable;
        }

        map<anydata> newTable = check self.keyValue(tempTable.clone());

        if (self.tokenConsumed) {
            self.tokenConsumed = false;
        } else {
            check self.checkToken([ARRAY_SEPARATOR, INLINE_TABLE_CLOSE], "Expected ',' or '}' after a key value pair in an inline table");
        }

        if (self.currentToken.token == ARRAY_SEPARATOR) {
            return check self.inlineTable(newTable, false);
        }

        return newTable;
    }

    private function standardTable(map<anydata> structure, string keyName = "") returns error? {

        // Establish the current structure
        string tomlKey = self.currentToken.value;
        self.keyStack.push(tomlKey);
        check self.verifyKey(structure, tomlKey);

        check self.checkToken([DOT, CLOSE_BRACKET], "Expected '.' or ']' after a table key");

        match self.currentToken.token {
            DOT => { // Build the dotted key
                check self.checkToken([UNQUOTED_KEY, BASIC_STRING, LITERAL_STRING], "Expected a key after '.' in a table key");
                return check self.standardTable(structure[tomlKey] is map<anydata> ? <map<anydata>>structure[tomlKey] : {}, tomlKey + ".");
            }

            CLOSE_BRACKET => { // Initialize the current structure

                // Check if the table key is already defined
                string tableKeyName = keyName + tomlKey;
                check self.verifyTableKey(tableKeyName);
                self.definedTableKeys.push(tableKeyName);

                self.currentStructure = structure[tomlKey] is map<anydata> ? <map<anydata>>structure[tomlKey] : {};
                return;
            }
        }

    }

    private function buildTOMLObject(map<anydata> structure) returns map<anydata>|error {
        // Under the root table
        if (self.keyStack.length() == 0) {
            return self.currentStructure;
        }

        // First key table
        if (self.keyStack.length() == 1) {
            string key = self.keyStack.pop();
            structure[key] = self.currentStructure;
            return structure;
        }

        // Dotted tables
        string key = self.keyStack.shift();
        map<anydata> value = check self.buildTOMLObject(structure[key] is map<anydata> ? <map<anydata>>structure[key] : {});
        structure[key] = value;
        return structure;
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
