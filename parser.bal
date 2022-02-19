import ballerina/lang.'boolean;
import ballerina/lang.'float;
import ballerina/lang.'int;
import ballerina/time;

# Represents an error caused by parser
type ParsingError distinct error;

# Parses the TOML document using the lexer
class Parser {
    # Properties for the TOML lines
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

    # If the token for a next grammar rule has been buffered to the current token
    private boolean tokenConsumed;

    # Buffers the key in the full format
    private string bufferedKey;

    # If set, the parser is currently working on an array table
    private boolean isArrayTable;

    # The current table key name. If empty, then current table is the root.
    private string currentTableKey;

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
        self.isArrayTable = false;
        self.currentTableKey = "";
        self.lineIndex = -1;
        self.lexemeBuffer = "";
    }

    # Generates a map object for the TOML document.
    # Considers the predictions for the 'expression', 'table', and 'array table'.
    #
    # + return - If success, map object for the TOML document. 
    # Else, a lexical or a parsing error. 
    public function parse() returns map<anydata>|LexicalError|ParsingError {

        // Iterating each line of the document.
        while self.lineIndex < self.numLines - 1 {
            check self.initLexer("Cannot open the TOML document");
            check self.checkToken();
            self.lexer.state = EXPRESSION_KEY;

            match self.currentToken.token {
                UNQUOTED_KEY|BASIC_STRING|LITERAL_STRING => { // Process a key value
                    self.bufferedKey = self.currentToken.value;
                    self.currentStructure = check self.keyValue(self.currentStructure.clone());
                    self.lexer.state = EXPRESSION_KEY;
                }
                OPEN_BRACKET => { // Process a standard tale.
                    // Add the previous table to the TOML object
                    self.tomlObject = check self.buildTOMLObject(self.tomlObject.clone());
                    self.isArrayTable = false;

                    check self.checkToken([UNQUOTED_KEY, BASIC_STRING, LITERAL_STRING]);
                    check self.standardTable(self.tomlObject.clone());
                }
                ARRAY_TABLE_OPEN => { // Process an array table
                    // Add the previous structure to the array in the TOML object.
                    self.tomlObject = check self.buildTOMLObject(self.tomlObject.clone());
                    self.isArrayTable = true;

                    check self.checkToken([UNQUOTED_KEY, BASIC_STRING, LITERAL_STRING]);
                    check self.arrayTable(self.tomlObject.clone());
                }
            }

            // Comments and new lines are ignored.
            // However, other expressions cannot have additional tokens in their line.
            if (self.currentToken.token != EOL) {
                check self.checkToken(EOL);
            }
        }

        // Return the TOML object
        self.tomlObject = check self.buildTOMLObject(self.tomlObject.clone());
        return self.tomlObject;
    }

    # Assert the next lexer token with the predicted token.
    # If no token is provided, then the next token is retrieved without an error checking.
    # Hence, the error checking must be done explicitly.
    #
    # + expectedTokens - Predicted token or tokens
    # + customMessage - Error message to be displayed if the expected token not found  
    # + return - Parsing error if not found
    private function checkToken(TOMLToken|TOMLToken[] expectedTokens = DUMMY, string customMessage = "") returns error? {
        TOMLToken prevToken = self.currentToken.token;
        self.currentToken = check self.lexer.getToken();

        // Bypass error handling.
        if (expectedTokens == DUMMY) {
            return;
        }

        // Automatically generates a template error message if there is no custom message.
        string errorMessage = customMessage.length() == 0
                                ? check self.formatErrorMessage(1, expectedTokens, prevToken)
                                : customMessage;

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
        check self.verifyTableKey(self.currentTableKey == "" ? self.bufferedKey : self.currentTableKey + "." + self.bufferedKey);
        check self.checkToken();

        match self.currentToken.token {
            DOT => { // Process dotted keys
                check self.checkToken([UNQUOTED_KEY, BASIC_STRING, LITERAL_STRING]);
                self.bufferedKey += "." + self.currentToken.value;
                map<anydata> value = check self.keyValue(structure[tomlKey] is map<anydata> ? <map<anydata>>structure[tomlKey] : {});
                structure[tomlKey] = value;
                return structure;
            }

            KEY_VALUE_SEPARATOR => { // Process value assignment
                self.lexer.state = EXPRESSION_VALUE;

                check self.checkToken([
                    BASIC_STRING,
                    LITERAL_STRING,
                    MULTI_BSTRING_DELIMITER,
                    MULTI_LSTRING_DELIMITER,
                    DECIMAL,
                    BINARY,
                    OCTAL,
                    HEXADECIMAL,
                    INFINITY,
                    NAN,
                    OPEN_BRACKET,
                    BOOLEAN,
                    INLINE_TABLE_OPEN
                ]);

                // Existing tables cannot be overwritten by inline tables
                if (self.currentToken.token == INLINE_TABLE_OPEN && structure[tomlKey] is map<anydata>) {
                    return self.generateError(check self.formatErrorMessage(2, value = self.bufferedKey));
                }

                structure[tomlKey] = check self.dataValue();
                return structure;
            }
            _ => {
                return self.generateError(check self.formatErrorMessage(1, [DOT, KEY_VALUE_SEPARATOR], UNQUOTED_KEY));
            }
        }
    }

    # If the structure exists and already assigned a primitive value,
    # then it is invalid to assign a value to it or nested to it.
    #
    # + structure - Parent key of the provided one 
    # + key - Key to be verified in the structure  
    # + return - Error, if there already exists a primitive value.
    private function verifyKey(map<anydata>? structure, string key) returns error? {
        if (structure is map<anydata>) {
            map<anydata> castedStructure = <map<anydata>>structure;
            if (castedStructure.hasKey(key) && !(castedStructure[key] is anydata[] || castedStructure[key] is map<anydata>)) {
                return self.generateError("Duplicate values exists for '" + self.bufferedKey + "'");
            }
        }
    }

    # TOML allows only once to define a standard key table.
    # This function checks if the table key name already exists.
    #
    # + tableKeyName - Table key name to be checked
    # + return - An error if the key already exists.  
    private function verifyTableKey(string tableKeyName) returns error? {
        if (self.definedTableKeys.indexOf(tableKeyName) != ()) {
            return self.generateError("Duplicate table key exists for '" + tableKeyName + "'");
        }
    }

    # Generate any TOML data value.
    #
    # + return - If success, returns the formatted data value. Else, an error.
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
            DECIMAL => {
                returnData = check self.number();
            }
            HEXADECIMAL => {
                returnData = check self.processTypeCastingError('int:fromHexString(self.currentToken.value));
            }
            BINARY => {
                returnData = check self.processInteger(2);
            }
            OCTAL => {
                returnData = check self.processInteger(8);
            }
            INFINITY => {
                returnData = self.currentToken.value[0] == "+" ? 'float:Infinity : -'float:Infinity;
            }
            NAN => {
                returnData = 'float:NaN;
            }
            BOOLEAN => {
                returnData = check self.processTypeCastingError('boolean:fromString(self.currentToken.value));
            }
            OPEN_BRACKET => {
                returnData = check self.array();

                // Static arrays cannot be redefined by the array tables.
                if (!self.isArrayTable) {
                    self.definedTableKeys.push(self.currentTableKey.length() == 0 ? self.bufferedKey : self.currentTableKey + "." + self.bufferedKey);
                    self.bufferedKey = "";
                }
            }
            INLINE_TABLE_OPEN => {
                returnData = check self.inlineTable();

                // Inline tables cannot be redefined by the standard tables.
                if (!self.isArrayTable) {
                    self.definedTableKeys.push(self.currentTableKey.length() == 0 ? self.bufferedKey : self.currentTableKey + "." + self.bufferedKey);
                    self.bufferedKey = "";
                }
            }
            _ => { // Latter primitive data types
                returnData = self.currentToken.value;
            }
        }
        self.lexemeBuffer = "";
        return returnData;
    }

    # Process multi-line basic string.
    #
    # + return - An error if the grammar rule is not made  
    private function multiBasicString() returns error? {
        self.lexer.state = MULTILINE_BSTRING;
        self.lexemeBuffer = "";

        // Predict the next tokens
        check self.checkToken([
            MULTI_BSTRING_CHARS,
            MULTI_BSTRING_ESCAPE,
            MULTI_BSTRING_DELIMITER,
            EOL
        ]);

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
                    check self.initLexer("Expected to end the multi-line basic string");

                    // Ignore new lines after the escape symbol
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
            ]);
        }

        self.lexer.state = EXPRESSION_KEY;
    }

    # Process multi-line literal string.
    #
    # + return - An error if the grammar production is not made.  
    private function multiLiteralString() returns error? {
        self.lexer.state = MULITLINE_LSTRING;
        self.lexemeBuffer = "";

        // Predict the next tokens
        check self.checkToken([
            MULTI_LSTRING_CHARS,
            MULTI_LSTRING_DELIMITER,
            EOL
        ]);

        // Predicting the next tokens until the end of the string.
        while (self.currentToken.token != MULTI_LSTRING_DELIMITER) {
            match self.currentToken.token {
                MULTI_LSTRING_CHARS => { // Regular literal string
                    self.lexemeBuffer += self.currentToken.value;
                }
                EOL => { // Processing new lines
                    check self.initLexer(check self.formatErrorMessage(1, MULTI_LSTRING_DELIMITER, MULTI_BSTRING_DELIMITER));
                    self.lexemeBuffer += "\\n";
                }
            }
            check self.checkToken([
                MULTI_LSTRING_CHARS,
                MULTI_LSTRING_DELIMITER,
                EOL
            ]);
        }

        self.lexer.state = EXPRESSION_KEY;
    }

    # Handles the grammar rules of integers and float numbers.
    # Delegates to date and time when the dates can be predicted.
    #
    # + fractional - Flag is set when processing the fractional segment
    # + return - Parsing error if occurred
    private function number(boolean fractional = false) returns anydata|error {
        self.lexemeBuffer += self.currentToken.value;
        check self.checkToken();

        match self.currentToken.token {
            EOL|SEPARATOR|CLOSE_BRACKET|INLINE_TABLE_CLOSE => { // Generate the final number
                self.tokenConsumed = true;
                if (self.lexemeBuffer.length() > 1 && self.lexemeBuffer[0] == "0") {
                    return self.generateError("Cannot have leading 0's in integers or floats");
                }
                return fractional ? check self.processTypeCastingError('float:fromString(self.lexemeBuffer))
                                        : check self.processTypeCastingError('int:fromString(self.lexemeBuffer));
            }
            EXPONENTIAL => { // Handles exponential numbers
                check self.checkToken(DECIMAL);

                // Evaluating the exponential value
                float exponent = <float>(check self.processTypeCastingError('float:fromString(self.currentToken.value)));
                float prefix = <float>(check self.processTypeCastingError('float:fromString(self.lexemeBuffer)));
                return prefix * 'float:pow(10, exponent);
            }
            DOT => { // Handles fractional numbers
                if (fractional) {
                    return self.generateError("Cannot have a decimal point in the fraction part");
                }
                check self.checkToken(DECIMAL);
                self.lexemeBuffer += ".";
                return check self.number(true);
            }
            MINUS => {
                self.lexer.state = DATE_TIME;
                return check self.date();
            }
            COLON => {
                self.lexer.state = DATE_TIME;
                return check self.time(self.lexemeBuffer);
            }
            _ => {
                return self.generateError("Invalid token after an decimal integer");
            }
        }
    }

    # Validates a given time component
    #
    # + value - Actual value in the TOML document 
    # + lowerBound - Minimum acceptable value
    # + upperBound - Maximum acceptable value
    # + valueName - Name of the time component
    # + return - Returns an error if the requirements are not met.
    private function checkTime(string value, int lowerBound, int upperBound, string valueName) returns error? {
        // Expected the time digits to be 2.
        if (value.length() != 2) {
            return self.generateError("Expected number of digits in " + valueName + " to be 2");
        }
        int intValue = <int>check self.processTypeCastingError('int:fromString(value));
        if (intValue < lowerBound || intValue > upperBound) {
            return self.generateError("Expected " + valueName + " to be between " + lowerBound.toString() + "-" + upperBound.toString());
        }
    }

    # Process the time component.
    #
    # + hours - Hours in the TOML document
    # + datePrefixed - True if there is a date before the time
    # + return - Returns the formatted time on success. Else, an parsing error.
    private function time(string hours, boolean datePrefixed = false) returns anydata|error {
        // Validate hours
        check self.checkTime(hours, 0, 24, "hours");

        // Validate minutes
        check self.checkToken(DECIMAL, "Expected 2 digit minutes after ':'");
        check self.checkTime(self.currentToken.value, 0, 60, "minutes");
        self.lexemeBuffer += ":" + self.currentToken.value;

        // Validate seconds
        check self.checkToken(COLON, "Expected a ':' after minutes");
        check self.checkToken(DECIMAL, "Expected a 2 digit seconds after ':'");
        check self.checkTime(self.currentToken.value, 0, 60, "minutes");
        self.lexemeBuffer += ":" + self.currentToken.value;

        check self.checkToken();
        match self.currentToken.token {
            EOL => { // Partial time
                return self.lexemeBuffer;
            }
            DOT => { // Fractional time
                check self.checkToken(DECIMAL, "Expected a integer after '.' for the time fraction");
                self.lexemeBuffer += "." + self.currentToken.value;

                check self.checkToken();
                match self.currentToken.token {
                    EOL => { // Fractional partial time
                        return self.lexemeBuffer;
                    }
                    PLUS|MINUS|ZULU => { // Fractional time with time offset
                        return self.timeOffset(datePrefixed);
                    }
                }
            }
            PLUS|MINUS|ZULU => { // Partial time with time offset
                return self.timeOffset(datePrefixed);
            }
            _ => {
                return self.generateError(check self.formatErrorMessage(1, [EOL, DOT, PLUS, MINUS, ZULU], DECIMAL));
            }
        }
    }

    # Returns the formatted time in UTC
    #
    # + datePrefixed - True if there is a date before the time
    # + return - UTC object representing the time on success. Else, an parsing error.
    private function timeOffset(boolean datePrefixed) returns anydata|error {
        match self.currentToken.token {
            ZULU => {
                return datePrefixed ? time:utcFromString(self.lexemeBuffer + "Z")
                    : self.generateError("Cannot crate a UTC time for a local time");
            }
            PLUS|MINUS => {
                if (datePrefixed) {
                    self.lexemeBuffer += self.currentToken.token == PLUS ? "+" : "-";

                    // Validate hours
                    check self.checkToken(DECIMAL, "Expected a 2 digit hours after time offset");
                    check self.checkTime(self.currentToken.value, 0, 24, "hours");
                    self.lexemeBuffer += self.currentToken.value;

                    // Validate minutes
                    check self.checkToken(COLON, "Expected a ':' after hours");
                    check self.checkToken(DECIMAL, "Expected 2 digit minutes after ':'");
                    check self.checkTime(self.currentToken.value, 0, 60, "minutes");
                    self.lexemeBuffer += ":" + self.currentToken.value;

                    return time:utcFromString(self.lexemeBuffer);
                }
                return self.generateError("Cannot crate a UTC time for a local time");
            }
        }
    }

    # Validates the date component.
    #
    # + value - Actual value in the TOML document  
    # + numDigits - Required number of digits to the component. 
    # + valueName - Name of the date component.
    # + return - Returns the value in integer. Else, an parsing error.
    private function checkDate(string value, int numDigits, string valueName) returns int|error {
        if (value.length() != numDigits) {
            return self.generateError("Expected number of digits in " + valueName + " to be " + numDigits.toString());
        }
        return <int>check self.processTypeCastingError('int:fromString(value));
    }

    # Process the date component.
    #
    # + return - An error if the grammar rules are not met.  
    private function date() returns anydata|error {
        // Validate the year
        int year = check self.checkDate(self.lexemeBuffer, 4, "year");

        // Validate the month
        check self.checkToken(DECIMAL);
        int month = check self.checkDate(self.currentToken.value, 2, "month");
        self.lexemeBuffer += "-" + self.currentToken.value;

        // Validate the day
        check self.checkToken(MINUS);
        check self.checkToken(DECIMAL);
        int day = check self.checkDate(self.currentToken.value, 2, "day");
        self.lexemeBuffer += "-" + self.currentToken.value;

        // Validate the complete date
        error? validateDate = 'time:dateValidate({year, month, day});
        if (validateDate is error) {
            return self.generateError(validateDate.toString().substring(18));
        }

        check self.checkToken();
        match self.currentToken.token {
            EOL => { // Local date
                return self.lexemeBuffer;
            }
            TIME_DELIMITER => { // Adding a time component to the date

                // Obtain the hours
                check self.checkToken(DECIMAL);
                string hours = self.currentToken.value;
                self.lexemeBuffer += "T" + hours;
                check self.checkToken(COLON);
                return self.time(hours, true);
            }
            _ => {
                return self.generateError(check self.formatErrorMessage(1, [EOL, TIME_DELIMITER], DECIMAL));
            }
        }
    }

    # Process the rules after '[' or ','.
    #
    # + tempArray - Recursively constructing array
    # + return - Completed array on success. An error if the grammar rules are not met.
    private function array(anydata[] tempArray = []) returns anydata[]|error {

        check self.checkToken([
            BASIC_STRING,
            LITERAL_STRING,
            MULTI_BSTRING_DELIMITER,
            MULTI_LSTRING_DELIMITER,
            DECIMAL,
            HEXADECIMAL,
            OCTAL,
            BINARY,
            INFINITY,
            NAN,
            BOOLEAN,
            OPEN_BRACKET,
            CLOSE_BRACKET,
            INLINE_TABLE_OPEN,
            EOL
        ]);

        match self.currentToken.token {
            EOL => {
                check self.initLexer(check self.formatErrorMessage(1, CLOSE_BRACKET, OPEN_BRACKET));
                return self.array(tempArray);
            }
            CLOSE_BRACKET => { // If the array ends with a ','
                return tempArray;
            }
            _ => { // Array value
                tempArray.push(check self.dataValue());
                return self.arrayValue(tempArray);
            }
        }
    }

    # Process the rules after an array value.
    #
    # + tempArray - Recursively constructing array
    # + return - Completed array on success. An error if the grammar rules are not met.
    private function arrayValue(anydata[] tempArray = []) returns anydata[]|error {
        TOMLToken prevToken;

        if (self.tokenConsumed) {
            prevToken = DECIMAL;
            self.tokenConsumed = false;
        } else {
            prevToken = self.currentToken.token;
            check self.checkToken();
        }

        match self.currentToken.token {
            EOL => {
                check self.initLexer("Expected ']' or ',' after an array value");
                return self.arrayValue(tempArray);
            }
            CLOSE_BRACKET => {
                return tempArray;
            }
            SEPARATOR => {
                return self.array(tempArray);
            }
            _ => {
                return self.generateError(check self.formatErrorMessage(1, [EOL, CLOSE_BRACKET, SEPARATOR], prevToken));
            }
        }
    }

    # Process the grammar rules of inline tables.
    #
    # + tempTable - Recursively constructing inline table
    # + isStart - True if the function is being called for the first time.
    # + return - Map structure representing the table on success. Else, an error if the grammar rules are not met.
    private function inlineTable(map<anydata> tempTable = {}, boolean isStart = true) returns map<anydata>|error {
        self.lexer.state = EXPRESSION_KEY;
        check self.checkToken([
            UNQUOTED_KEY,
            BASIC_STRING,
            LITERAL_STRING,
            isStart ? INLINE_TABLE_CLOSE : DUMMY
        ]);

        // This is unreachable after a separator.
        // This condition is only available to create an empty table.
        if (self.currentToken.token == INLINE_TABLE_CLOSE) {
            return tempTable;
        }

        // Add the key value to the inline table.
        map<anydata> newTable = check self.keyValue(tempTable.clone());

        if (self.tokenConsumed) {
            self.tokenConsumed = false;
        } else {
            check self.checkToken([SEPARATOR, INLINE_TABLE_CLOSE]);
        }

        // Calls the method recursively to add new key values.
        if (self.currentToken.token == SEPARATOR) {
            return check self.inlineTable(newTable, false);
        }

        return newTable;
    }

    # Process the grammar rules for initializing the standard table.
    # Sets a new current structure, so the succeeding key values are added to it.
    #
    # + structure - Mapping of the parent key
    # + keyName - Recursively constructing the table key name
    # + return - An error if the grammar rules are not met or any duplicate values.
    private function standardTable(map<anydata> structure, string keyName = "") returns error? {

        // Verifies the current key
        string tomlKey = self.currentToken.value;
        self.keyStack.push(tomlKey);
        check self.verifyKey(structure, tomlKey);

        check self.checkToken();

        match self.currentToken.token {
            DOT => { // Build the dotted key
                check self.checkToken([UNQUOTED_KEY, BASIC_STRING, LITERAL_STRING]);
                return check self.standardTable(structure[tomlKey] is map<anydata> ? <map<anydata>>structure[tomlKey] : {}, keyName + tomlKey + ".");
            }

            CLOSE_BRACKET => { // Initialize the current structure

                // Check if the table key is already defined.
                string tableKeyName = keyName + tomlKey;
                check self.verifyTableKey(tableKeyName);
                self.definedTableKeys.push(tableKeyName);
                self.currentTableKey = tableKeyName;

                // Cannot define a standard table for an already defined array table.
                if (structure.hasKey(tomlKey) && !(structure[tomlKey] is map<anydata>)) {
                    return self.generateError(check self.formatErrorMessage(2, value = tableKeyName));
                }

                self.currentStructure = structure[tomlKey] is map<anydata> ? <map<anydata>>structure[tomlKey] : {};
                return;
            }
        }

    }

    # Process the grammar rules of initializing an array table.
    #
    # + structure - Mapping of the parent key
    # + keyName - Recursively constructing the table key name
    # + return - An error if the grammar rules are not met or any duplicate values. 
    private function arrayTable(map<anydata> structure, string keyName = "") returns error? {

        // Verifies the current key
        string tomlKey = self.currentToken.value;
        self.keyStack.push(tomlKey);
        check self.verifyKey(structure, tomlKey);

        check self.checkToken();

        match self.currentToken.token {
            DOT => { // Build the dotted key
                check self.checkToken([UNQUOTED_KEY, BASIC_STRING, LITERAL_STRING]);
                return check self.arrayTable(structure[tomlKey] is map<anydata> ? <map<anydata>>structure[tomlKey] : {}, tomlKey + ".");
            }

            ARRAY_TABLE_CLOSE => { // Initialize the current structure

                // Check if there is an static array or a standard table key already defined.
                check self.verifyTableKey(keyName + tomlKey);

                // Cannot define an array table for already defined standard table.
                if (structure.hasKey(tomlKey) && !(structure[tomlKey] is anydata[])) {
                    return self.generateError(check self.formatErrorMessage(2, value = keyName + tomlKey));
                }

                // An array table always create a new object.
                self.currentStructure = {};
                return;
            }
        }
    }

    # Adds the current structure to the final TOML object.
    #
    # + structure - Structure to which the changes are made.
    # + return - Constructed final toml object on success. Else, a parsing error.
    private function buildTOMLObject(map<anydata> structure) returns map<anydata>|error {
        // Under the root table
        if (self.keyStack.length() == 0) {
            return self.currentStructure;
        }

        // Under the key tables at the depth of 1
        if (self.keyStack.length() == 1) {
            string key = self.keyStack.pop();
            if (self.isArrayTable) {

                // Adds the current structure to the end of the array.
                if (structure[key] is anydata[]) {
                    (<anydata[]>structure[key]).push(self.currentStructure.clone());

                    // If the array does not exist, initialize and add it.
                } else {
                    structure[key] = [self.currentStructure.clone()];
                }

                // If a standard table, assign the structure directly under the key
            } else {
                structure[key] = self.currentStructure;
            }
            return structure;
        }

        // Dotted tables
        string key = self.keyStack.shift();
        map<anydata> value;

        // If the key is a table
        if (structure[key] is map<anydata>) {
            value = check self.buildTOMLObject(<map<anydata>>structure[key]);
            structure[key] = value;
        }

        // If there is a standard table under an array table, obtain the latest object.
        else if (structure[key] is anydata[]) {
            value = check self.buildTOMLObject(<map<anydata>>(<anydata[]>structure[key]).pop());
            (<anydata[]>structure[key]).push(value);
        }

        // Creates a new structure if not exists.
        else {
            value = check self.buildTOMLObject({});
            structure[key] = value;
        }

        return structure;
    }

    # Evaluates an integer of a different base
    #
    # + numberSystem - Number system of the value
    # + return - Processed integer. Error if there is a string.
    private function processInteger(int numberSystem) returns int|error {
        int value = 0;
        int power = 1;
        int length = self.currentToken.value.length() - 1;
        foreach int i in 0 ... length {
            value += check 'int:fromString(self.currentToken.value[length - i]) * power;
            power *= numberSystem;
        }
        return value;
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

    # Initialize the lexer with the attributes of a new line.
    #
    # + message - Error message to display when if the initialization fails 
    # + incrementLine - Sets the next line to the lexer
    # + return - An error if it fails to initialize  
    private function initLexer(string message, boolean incrementLine = true) returns error? {
        if (incrementLine) {
            self.lineIndex += 1;
        }
        if (self.lineIndex >= self.numLines) {
            return self.generateError(message);
        }
        self.lexer.line = self.lines[self.lineIndex];
        self.lexer.index = 0;
        self.lexer.lineNumber = self.lineIndex;
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

    # Generate a standard error message based on the type.
    #
    # 1 - Expected ${expectedTokens} after ${beforeToken}, but found ${actualToken}
    #
    # 2 - Duplicate key exists for ${value}
    #
    # + messageType - Number of the template message
    # + expectedTokens - Predicted tokens  
    # + beforeToken - Token before the predicted token  
    # + value - Any value name. Commonly used to indicate keys.
    # + return - If success, the generated error message. Else, an error message.
    private function formatErrorMessage(
            int messageType,
            TOMLToken|TOMLToken[] expectedTokens = DUMMY,
            TOMLToken beforeToken = DUMMY,
            string value = "") returns string|error {

        match messageType {
            1 => { // Expected ${expectedTokens} after ${beforeToken}, but found ${actualToken}
                if (expectedTokens == DUMMY || beforeToken == DUMMY) {
                    return error("Token parameters cannot be null for this template error message.");
                }
                string expectedTokensMessage;
                if (expectedTokens is TOMLToken[]) { // If multiple tokens
                    string tempMessage = expectedTokens.reduce(function(string message, TOMLToken token) returns string {
                        return message + " '" + token + "' or";
                    }, "");
                    expectedTokensMessage = tempMessage.substring(0, tempMessage.length() - 3);
                } else { // If a single token
                    expectedTokensMessage = " '" + expectedTokens + "'";
                }
                return "Expected" + expectedTokensMessage + " after '" + beforeToken + "', but found '" + self.currentToken.token + "'";
            }

            2 => { // Duplicate key exists for ${value}
                if (value.length() == 0) {
                    return error("Value cannot be empty for this template message");
                }
                return "Duplicate key exists for '" + value + "'";
            }

            _ => {
                return error("Invalid message type number. Enter a value between 1-2");
            }
        }

    }
}
