import toml.lexer;
import ballerina/lang.'boolean;
import ballerina/lang.'float;
import ballerina/lang.'int;
import ballerina/time;

# Handles the rule: key -> simple-key | dotted-key
# key_value -> key '=' value.
# The 'dotted-key' is being called recursively. 
# At the terminal, a value is assigned to the last key, 
# and nested under the previous key's map if exists.
#
# + structure - The structure for the previous key. Null if there is no value.
# + return - Returns the structure after assigning the value.
function keyValue(map<json> structure) returns map<json>|ParsingError|lexer:LexicalError {
    string tomlKey = currentToken.value;
    check verifyKey(structure, tomlKey);
    check verifyTableKey(currentTableKey == "" ? bufferedKey : currentTableKey + "." + bufferedKey);
    check checkToken();

    match currentToken.token {
        lexer:DOT => { // Process dotted keys
            check checkToken([lexer:UNQUOTED_KEY, lexer:BASIC_STRING, lexer:LITERAL_STRING]);
            bufferedKey += "." + currentToken.value;
            map<json> value = check keyValue(structure[tomlKey] is map<json> ? <map<json>>structure[tomlKey] : {});
            structure[tomlKey] = value;
            return structure;
        }

        lexer:KEY_VALUE_SEPARATOR => { // Process value assignment
            lexer:state = lexer:EXPRESSION_VALUE;

            check checkToken([
                lexer:BASIC_STRING,
                lexer:LITERAL_STRING,
                lexer:MULTI_BSTRING_DELIMITER,
                lexer:MULTI_LSTRING_DELIMITER,
                lexer:DECIMAL,
                lexer:BINARY,
                lexer:OCTAL,
                lexer:HEXADECIMAL,
                lexer:INFINITY,
                lexer:NAN,
                lexer:OPEN_BRACKET,
                lexer:BOOLEAN,
                lexer:INLINE_TABLE_OPEN
            ]);

            // Existing tables cannot be overwritten by inline tables
            if (currentToken.token == lexer:INLINE_TABLE_OPEN && structure[tomlKey] is map<json>) {
                return generateError(check formatErrorMessage(2, value = bufferedKey));
            }

            structure[tomlKey] = check dataValue();
            return structure;
        }
        _ => {
            return generateError(check formatErrorMessage(1, [lexer:DOT, lexer:KEY_VALUE_SEPARATOR], lexer:UNQUOTED_KEY));
        }
    }
}

# Generate any TOML data value.
#
# + return - If success, returns the formatted data value. Else, an error.
function dataValue() returns json|lexer:LexicalError|ParsingError {
    json returnData;
    match currentToken.token {
        lexer:MULTI_BSTRING_DELIMITER => {
            check multiBasicString();
            returnData = lexemeBuffer;
        }
        lexer:MULTI_LSTRING_DELIMITER => {
            check multiLiteralString();
            returnData = lexemeBuffer;
        }
        lexer:DECIMAL => {
            returnData = check number();
        }
        lexer:HEXADECIMAL => {
            returnData = check processTypeCastingError('int:fromHexString(currentToken.value));
        }
        lexer:BINARY => {
            returnData = check processInteger(2);
        }
        lexer:OCTAL => {
            returnData = check processInteger(8);
        }
        lexer:INFINITY => {
            returnData = currentToken.value[0] == "+" ? 'float:Infinity : -'float:Infinity;
        }
        lexer:NAN => {
            returnData = 'float:NaN;
        }
        lexer:BOOLEAN => {
            returnData = check processTypeCastingError('boolean:fromString(currentToken.value));
        }
        lexer:OPEN_BRACKET => {
            returnData = check array();

            // Static arrays cannot be redefined by the array tables.
            if (!isArrayTable) {
                definedTableKeys.push(currentTableKey.length() == 0 ? bufferedKey : currentTableKey + "." + bufferedKey);
                bufferedKey = "";
            }
        }
        lexer:INLINE_TABLE_OPEN => {
            returnData = check inlineTable();

            // Inline tables cannot be redefined by the standard tables.
            if (!isArrayTable) {
                definedTableKeys.push(currentTableKey.length() == 0 ? bufferedKey : currentTableKey + "." + bufferedKey);
                bufferedKey = "";
            }
        }
        _ => { // Latter primitive data types
            returnData = currentToken.value;
        }
    }
    lexemeBuffer = "";
    return returnData;
}

# Process multi-line basic string.
#
# + return - An error if the grammar rule is not made  
function multiBasicString() returns lexer:LexicalError|ParsingError|() {
    lexer:state = lexer:MULTILINE_BSTRING;
    lexemeBuffer = "";

    // Predict the next tokens
    check checkToken([
        lexer:MULTI_BSTRING_CHARS,
        lexer:MULTI_BSTRING_ESCAPE,
        lexer:MULTI_BSTRING_DELIMITER,
        lexer:EOL
    ]);

    // Predicting the next tokens until the end of the string.
    while (currentToken.token != lexer:MULTI_BSTRING_DELIMITER) {
        match currentToken.token {
            lexer:MULTI_BSTRING_CHARS => { // Regular basic string
                lexemeBuffer += currentToken.value
;
            }
            lexer:MULTI_BSTRING_ESCAPE => { // Escape token
                lexer:state = lexer:MULTILINE_ESCAPE;
            }
            lexer:EOL => { // Processing new lines
                check initLexer("Expected to end the multi-line basic string");

                // Ignore new lines after the escape symbol
                if !(lexer:state == lexer:MULTILINE_ESCAPE) {
                    lexemeBuffer += "\\n";
                }
            }
        }
        check checkToken([
            lexer:MULTI_BSTRING_CHARS,
            lexer:MULTI_BSTRING_ESCAPE,
            lexer:MULTI_BSTRING_DELIMITER,
            lexer:EOL
        ]);
    }

    lexer:state = lexer:EXPRESSION_KEY;
}

# Process multi-line literal string.
#
# + return - An error if the grammar production is not made.  
function multiLiteralString() returns lexer:LexicalError|ParsingError|() {
    lexer:state = lexer:MULITLINE_LSTRING;
    lexemeBuffer = "";

    // Predict the next tokens
    check checkToken([
        lexer:MULTI_LSTRING_CHARS,
        lexer:MULTI_LSTRING_DELIMITER,
        lexer:EOL
    ]);

    // Predicting the next tokens until the end of the string.
    while (currentToken.token != lexer:MULTI_LSTRING_DELIMITER) {
        match currentToken.token {
            lexer:MULTI_LSTRING_CHARS => { // Regular literal string
                lexemeBuffer += currentToken.value;
            }
            lexer:EOL => { // Processing new lines
                check initLexer(check formatErrorMessage(1, lexer:MULTI_LSTRING_DELIMITER, lexer:MULTI_BSTRING_DELIMITER));
                lexemeBuffer += "\\n";
            }
        }
        check checkToken([
            lexer:MULTI_LSTRING_CHARS,
            lexer:MULTI_LSTRING_DELIMITER,
            lexer:EOL
        ]);
    }

    lexer:state = lexer:EXPRESSION_KEY;
}

# Handles the grammar rules of integers and float numbers.
# Delegates to date and time when the dates can be predicted.
#
# + fractional - Flag is set when processing the fractional segment
# + return - Parsing error if occurred
function number(boolean fractional = false) returns json|lexer:LexicalError|ParsingError {
    lexemeBuffer += currentToken.value;
    check checkToken();

    match currentToken.token {
        lexer:EOL|lexer:SEPARATOR|lexer:CLOSE_BRACKET|lexer:INLINE_TABLE_CLOSE => { // Generate the final number
            tokenConsumed = true;
            if (lexemeBuffer.length() > 1 && lexemeBuffer[0] == "0") {
                return generateError("Cannot have leading 0's in integers or floats");
            }
            return fractional ? check processTypeCastingError('float:fromString(lexemeBuffer))
                                        : check processTypeCastingError('int:fromString(lexemeBuffer));
        }
        lexer:EXPONENTIAL => { // Handles lexer: numbers
            check checkToken(lexer:DECIMAL);

            // Evaluating the lexer: value
            float exponent = <float>(check processTypeCastingError('float:fromString(currentToken.value)));
            float prefix = <float>(check processTypeCastingError('float:fromString(lexemeBuffer)));
            return prefix * 'float:pow(10, exponent);
        }
        lexer:DOT => { // Handles fractional numbers
            if (fractional) {
                return generateError("Cannot have a decimal point in the fraction part");
            }
            check checkToken(lexer:DECIMAL);
            lexemeBuffer += ".";
            return check number(true);
        }
        lexer:MINUS => {
            lexer:state = lexer:DATE_TIME;
            return check date();
        }
        lexer:COLON => {
            lexer:state = lexer:DATE_TIME;
            return check time(lexemeBuffer);
        }
        _ => {
            return generateError("Invalid token after an decimal integer");
        }
    }
}

# Process the time component.
#
# + hours - Hours in the TOML document
# + datePrefixed - True if there is a date before the time
# + return - Returns the formatted time on success. Else, an parsing error.
function time(string hours, boolean datePrefixed = false) returns json|lexer:LexicalError|ParsingError {
    // Validate hours
    check checkTime(hours, 0, 24, "hours");

    // Validate minutes
    check checkToken(lexer:DECIMAL, "Expected 2 digit minutes after ':'");
    check checkTime(currentToken.value, 0, 60, "minutes");
    lexemeBuffer += ":" + currentToken.value;

    // Validate seconds
    check checkToken(lexer:COLON, "Expected a ':' after minutes");
    check checkToken(lexer:DECIMAL, "Expected a 2 digit seconds after ':'");
    check checkTime(currentToken.value, 0, 60, "minutes");
    lexemeBuffer += ":" + currentToken.value;

    check checkToken();
    match currentToken.token {
        lexer:EOL => { // Partial time
            return lexemeBuffer;
        }
        lexer:DOT => { // Fractional time
            check checkToken(lexer:DECIMAL, "Expected a integer after '.' for the time fraction");
            lexemeBuffer += "." + currentToken.value;

            check checkToken();
            match currentToken.token {
                lexer:EOL => { // Fractional partial time
                    return lexemeBuffer;
                }
                lexer:PLUS|lexer:MINUS|lexer:ZULU => { // Fractional time with time offset
                    return timeOffset(datePrefixed);
                }
            }
        }
        lexer:PLUS|lexer:MINUS|lexer:ZULU => { // Partial time with time offset
            return timeOffset(datePrefixed);
        }
        _ => {
            return generateError(check formatErrorMessage(1, [lexer:EOL, lexer:DOT, lexer:PLUS, lexer:MINUS, lexer:ZULU], lexer:DECIMAL));
        }
    }
}

# Returns the formatted time in UTC
#
# + datePrefixed - True if there is a date before the time
# + return - UTC object representing the time on success. Else, an parsing error.
function timeOffset(boolean datePrefixed) returns json|lexer:LexicalError|ParsingError {
    match currentToken.token {
        lexer:ZULU => {
            return datePrefixed ? check processTypeCastingError(time:utcFromString(lexemeBuffer + "Z"))
                    : generateError("Cannot crate a UTC time for a local time");
        }
        lexer:PLUS|lexer:MINUS => {
            if (datePrefixed) {
                lexemeBuffer += currentToken.token == lexer:PLUS ? "+" : "-";

                // Validate hours
                check checkToken(lexer:DECIMAL, "Expected a 2 digit hours after time offset");
                check checkTime(currentToken.value, 0, 24, "hours");
                lexemeBuffer += currentToken.value;

                // Validate minutes
                check checkToken(lexer:COLON, "Expected a ':' after hours");
                check checkToken(lexer:DECIMAL, "Expected 2 digit minutes after ':'");
                check checkTime(currentToken.value, 0, 60, "minutes");
                lexemeBuffer += ":" + currentToken.value;

                return processTypeCastingError(time:utcFromString(lexemeBuffer));
            }
            return generateError("Cannot crate a UTC time for a local time");
        }
    }
}

# Process the date component.
#
# + return - An error if the grammar rules are not met.  
function date() returns json|lexer:LexicalError|ParsingError {
    // Validate the year
    int year = check checkDate(lexemeBuffer, 4, "year");

    // Validate the month
    check checkToken(lexer:DECIMAL);
    int month = check checkDate(currentToken.value, 2, "month");
    lexemeBuffer += "-" + currentToken.value;

    // Validate the day
    check checkToken(lexer:MINUS);
    check checkToken(lexer:DECIMAL);
    int day = check checkDate(currentToken.value, 2, "day");
    lexemeBuffer += "-" + currentToken.value;

    // Validate the complete date
    error? validateDate = 'time:dateValidate({year, month, day});
    if (validateDate is error) {
        return generateError(validateDate.toString().substring(18));
    }

    check checkToken();
    match currentToken.token {
        lexer:EOL => { // Local date
            return lexemeBuffer;
        }
        lexer:TIME_DELIMITER => { // Adding a time component to the date

            // Obtain the hours
            check checkToken(lexer:DECIMAL);
            string hours = currentToken.value;
            lexemeBuffer += "T" + hours;
            check checkToken(lexer:COLON);
            return time(hours, true);
        }
        _ => {
            return generateError(check formatErrorMessage(1, [lexer:EOL, lexer:TIME_DELIMITER], lexer:DECIMAL));
        }
    }
}

# Process the rules after '[' or ','.
#
# + tempArray - Recursively constructing array
# + return - Completed array on success. An error if the grammar rules are not met.
function array(json[] tempArray = []) returns json[]|lexer:LexicalError|ParsingError {

    check checkToken([
        lexer:BASIC_STRING,
        lexer:LITERAL_STRING,
        lexer:MULTI_BSTRING_DELIMITER,
        lexer:MULTI_LSTRING_DELIMITER,
        lexer:DECIMAL,
        lexer:HEXADECIMAL,
        lexer:OCTAL,
        lexer:BINARY,
        lexer:INFINITY,
        lexer:NAN,
        lexer:BOOLEAN,
        lexer:OPEN_BRACKET,
        lexer:CLOSE_BRACKET,
        lexer:INLINE_TABLE_OPEN,
        lexer:EOL
    ]);

    match currentToken.token {
        lexer:EOL => {
            check initLexer(check formatErrorMessage(1, lexer:CLOSE_BRACKET, lexer:OPEN_BRACKET));
            return array(tempArray);
        }
        lexer:CLOSE_BRACKET => { // If the array ends with a ','
            return tempArray;
        }
        _ => { // Array value
            tempArray.push(check dataValue());
            return arrayValue(tempArray);
        }
    }
}

# Process the rules after an array value.
#
# + tempArray - Recursively constructing array
# + return - Completed array on success. An error if the grammar rules are not met.
function arrayValue(json[] tempArray = []) returns json[]|lexer:LexicalError|ParsingError {
    lexer:TOMLToken prevToken;

    if (tokenConsumed) {
        prevToken = lexer:DECIMAL;
        tokenConsumed = false;
    } else {
        prevToken = currentToken.token;
        check checkToken();
    }

    match currentToken.token {
        lexer:EOL => {
            check initLexer("Expected ']' or ',' after an array value");
            return arrayValue(tempArray);
        }
        lexer:CLOSE_BRACKET => {
            return tempArray;
        }
        lexer:SEPARATOR => {
            return array(tempArray);
        }
        _ => {
            return generateError(check formatErrorMessage(1, [lexer:EOL, lexer:CLOSE_BRACKET, lexer:SEPARATOR], prevToken));
        }
    }
}

# Process the grammar rules of inline tables.
#
# + tempTable - Recursively constructing inline table
# + isStart - True if the function is being called for the first time.
# + return - Map structure representing the table on success. Else, an error if the grammar rules are not met.
function inlineTable(map<json> tempTable = {}, boolean isStart = true) returns map<json>|lexer:LexicalError|ParsingError {
    lexer:state = lexer:EXPRESSION_KEY;
    check checkToken([
        lexer:UNQUOTED_KEY,
        lexer:BASIC_STRING,
        lexer:LITERAL_STRING,
        isStart ? lexer:INLINE_TABLE_CLOSE : lexer:DUMMY
    ]);

    // This is unreachable after a separator.
    // This condition is only available to create an empty table.
    if (currentToken.token == lexer:INLINE_TABLE_CLOSE) {
        return tempTable;
    }

    // Add the key value to the inline table.
    map<json> newTable = check keyValue(tempTable.clone());

    if (tokenConsumed) {
        tokenConsumed = false;
    } else {
        check checkToken([lexer:SEPARATOR, lexer:INLINE_TABLE_CLOSE]);
    }

    // Calls the method recursively to add new key values.
    if (currentToken.token == lexer:SEPARATOR) {
        return check inlineTable(newTable, false);
    }

    return newTable;
}

# Process the grammar rules for initializing the standard table.
# Sets a new current structure, so the succeeding key values are added to it.
#
# + structure - Mapping of the parent key
# + keyName - Recursively constructing the table key name
# + return - An error if the grammar rules are not met or any duplicate values.
function standardTable(map<json> structure, string keyName = "") returns lexer:LexicalError|ParsingError|() {

    // Verifies the current key
    string tomlKey = currentToken.value;
    keyStack.push(tomlKey);
    check verifyKey(structure, tomlKey);

    check checkToken();

    match currentToken.token {
        lexer:DOT => { // Build the dotted key
            check checkToken([lexer:UNQUOTED_KEY, lexer:BASIC_STRING, lexer:LITERAL_STRING]);
            return check standardTable(structure[tomlKey] is map<json> ? <map<json>>structure[tomlKey] : {}, keyName + tomlKey + ".");
        }

        lexer:CLOSE_BRACKET => { // Initialize the current structure

            // Check if the table key is already defined.
            string tableKeyName = keyName + tomlKey;
            check verifyTableKey(tableKeyName);
            definedTableKeys.push(tableKeyName);
            currentTableKey = tableKeyName;

            // Cannot define a standard table for an already defined array table.
            if (structure.hasKey(tomlKey) && !(structure[tomlKey] is map<json>)) {
                return generateError(check formatErrorMessage(2, value = tableKeyName));
            }

            currentStructure = structure[tomlKey] is map<json> ? <map<json>>structure[tomlKey] : {};
            return;
        }
    }

}

# Process the grammar rules of initializing an array table.
#
# + structure - Mapping of the parent key
# + keyName - Recursively constructing the table key name
# + return - An error if the grammar rules are not met or any duplicate values. 
function arrayTable(map<json> structure, string keyName = "") returns lexer:LexicalError|ParsingError|() {

    // Verifies the current key
    string tomlKey = currentToken.value;
    keyStack.push(tomlKey);
    check verifyKey(structure, tomlKey);

    check checkToken();

    match currentToken.token {
        lexer:DOT => { // Build the dotted key
            check checkToken([lexer:UNQUOTED_KEY, lexer:BASIC_STRING, lexer:LITERAL_STRING]);
            return check arrayTable(structure[tomlKey] is map<json> ? <map<json>>structure[tomlKey] : {}, tomlKey + ".");
        }

        lexer:ARRAY_TABLE_CLOSE => { // Initialize the current structure

            // Check if there is an static array or a standard table key already defined.
            check verifyTableKey(keyName + tomlKey);

            // Cannot define an array table for already defined standard table.
            if (structure.hasKey(tomlKey) && !(structure[tomlKey] is json[])) {
                return generateError(check formatErrorMessage(2, value = keyName + tomlKey));
            }

            // An array table always create a new object.
            currentStructure = {};
            return;
        }
    }
}
