import toml.lexer;
import ballerina/time;

# Handles the grammar rules of integers and float numbers.
# Delegates to date and time when the dates can be predicted.
#
# + state - Current parser state  
# + prevValue - The prefixed value to the current token 
# + fractional - Flag is set when processing the fractional segment
# + return - Parsing error if occurred
function number(ParserState state, string prevValue, boolean fractional = false) returns json|lexer:LexicalError|ParsingError {
    string valueBuffer = prevValue + state.currentToken.value;
    check checkToken(state);

    match state.currentToken.token {
        lexer:EOL|lexer:SEPARATOR|lexer:CLOSE_BRACKET|lexer:INLINE_TABLE_CLOSE => { // Generate the final number
            if state.currentToken.token != lexer:EOL {
                state.tokenConsumed = true;
            }

            if (valueBuffer.length() > 1 && valueBuffer[0] == "0") && !fractional {
                return generateGrammarError(state, "Cannot have leading 0's in integers");
            }
            return fractional ? check processTypeCastingError(state, 'decimal:fromString(valueBuffer))
                                        : check processTypeCastingError(state, 'int:fromString(valueBuffer));
        }
        lexer:EXPONENTIAL => { // Handles exponential numbers
            check checkToken(state, lexer:DECIMAL);
            return <decimal>(check processTypeCastingError(state,
                'decimal:fromString(string `${valueBuffer}E${state.currentToken.value}`)));
            // Evaluating the exponential part
            // float exponent = <float>(check processTypeCastingError(state, 'float:fromString(state.currentToken.value)));
            // float prefix = <float>(check processTypeCastingError(state, 'float:fromString(valueBuffer)));
            // float finalValue = prefix * 'float:pow(10, exponent);
            // return <decimal>finalValue;
        }
        lexer:DOT => { // Handles fractional numbers
            if (fractional) {
                return generateGrammarError(state, "Cannot have a decimal point in the fraction part");
            }
            if (valueBuffer.length() > 1 && valueBuffer[0] == "0") {
                return generateGrammarError(state, "Cannot have leading 0's in integers");
            }
            check checkToken(state, lexer:DECIMAL);
            valueBuffer += ".";
            return check number(state, valueBuffer, true);
        }
        lexer:MINUS => {
            state.updateLexerContext(lexer:DATE_TIME);
            return check date(state, valueBuffer);
        }
        lexer:COLON => {
            state.updateLexerContext(lexer:DATE_TIME);
            return check time(state, valueBuffer, valueBuffer);
        }
        _ => {
            return generateGrammarError(state, "Invalid token after an decimal integer");
        }
    }
}

# Process the date component.
#
# + state - Current parser state  
# + prevValue - The prefixed value to the current token 
# + return - An error if the grammar rules are not met.  
function date(ParserState state, string prevValue) returns json|lexer:LexicalError|ParsingError {
    string valueBuffer = prevValue;

    // Validate the year
    int year = check checkDate(state, valueBuffer, 4, "year");

    // Validate the month
    check checkToken(state, lexer:DECIMAL);
    int month = check checkDate(state, state.currentToken.value, 2, "month");
    valueBuffer += "-" + state.currentToken.value;

    // Validate the day
    check checkToken(state, lexer:MINUS);
    check checkToken(state, lexer:DECIMAL);
    int day = check checkDate(state, state.currentToken.value, 2, "day");
    valueBuffer += "-" + state.currentToken.value;

    // Validate the complete date
    error? validateDate = 'time:dateValidate({year, month, day});
    if (validateDate is error) {
        return generateGrammarError(state, validateDate.toString().substring(18));
    }

    check checkToken(state);
    match state.currentToken.token {
        lexer:EOL => { // Local date
            return valueBuffer;
        }
        lexer:TIME_DELIMITER => { // Adding a time component to the date
            string delimiter = state.currentToken.value;
            check checkToken(state, [lexer:DECIMAL, lexer:EOL]);

            // Check if the whitespace is at trailing
            if state.currentToken.token == lexer:EOL {
                return delimiter == " "
                    ? valueBuffer
                    : generateGrammarError(state, string `Date time cannot end with '${delimiter}'`);
            }

            // Obtain the hours
            string hours = state.currentToken.value;
            valueBuffer += "T" + hours;
            check checkToken(state, lexer:COLON);
            return time(state, hours, valueBuffer, true);
        }
        _ => {
            return generateExpectError(state, [lexer:EOL, lexer:TIME_DELIMITER], lexer:DECIMAL);
        }
    }
}

# Process the time component.
#
# + state - Current parser state  
# + hours - Hours in the TOML document
# + prevValue - The prefixed value to the current token 
# + datePrefixed - True if there is a date before the time
# + return - Returns the formatted time on success. Else, an parsing error.
function time(ParserState state, string hours, string prevValue, boolean datePrefixed = false) returns json|lexer:LexicalError|ParsingError {
    // Validate hours
    check checkTime(state, hours, 0, 24, "hours");

    // Validate minutes
    check checkToken(state, lexer:DECIMAL, "Expected 2 digit minutes after ':'");
    check checkTime(state, state.currentToken.value, 0, 60, "minutes");
    string valueBuffer = prevValue + ":" + state.currentToken.value;

    // Validate seconds
    check checkToken(state, lexer:COLON, "Expected a ':' after minutes");
    check checkToken(state, lexer:DECIMAL, "Expected a 2 digit seconds after ':'");
    check checkTime(state, state.currentToken.value, 0, 60, "minutes");
    valueBuffer += ":" + state.currentToken.value;

    check checkToken(state);
    match state.currentToken.token {
        lexer:EOL => { // Partial time
            return valueBuffer;
        }
        lexer:DOT => { // Fractional time
            check checkToken(state, lexer:DECIMAL, "Expected a integer after '.' for the time fraction");
            valueBuffer += "." + state.currentToken.value;

            check checkToken(state);
            match state.currentToken.token {
                lexer:EOL => { // Fractional partial time
                    return valueBuffer;
                }
                lexer:PLUS|lexer:MINUS|lexer:ZULU => { // Fractional time with time offset
                    return timeOffset(state, valueBuffer, datePrefixed);
                }
            }
        }
        lexer:PLUS|lexer:MINUS|lexer:ZULU => { // Partial time with time offset
            return timeOffset(state, valueBuffer, datePrefixed);
        }
        _ => {

            return generateExpectError(state, [lexer:EOL, lexer:DOT, lexer:PLUS, lexer:MINUS, lexer:ZULU], lexer:DECIMAL);
        }
    }
}

# Returns the formatted time in UTC
#
# + state - Current parser state  
# + prevValue - The prefixed value to the current token 
# + datePrefixed - True if there is a date before the time
# + return - UTC object representing the time on success. Else, an parsing error.
function timeOffset(ParserState state, string prevValue, boolean datePrefixed) returns json|lexer:LexicalError|ParsingError {
    string valueBuffer = prevValue;

    match state.currentToken.token {
        lexer:ZULU => {
            return datePrefixed ? check getODT(state, valueBuffer + "Z")
                    : generateGrammarError(state, "Cannot crate a UTC time for a local time");
        }
        lexer:PLUS|lexer:MINUS => {
            if (datePrefixed) {
                valueBuffer += state.currentToken.token == lexer:PLUS ? "+" : "-";

                // Validate hours
                check checkToken(state, lexer:DECIMAL, "Expected a 2 digit hours after time offset");
                check checkTime(state, state.currentToken.value, 0, 24, "hours");
                valueBuffer += state.currentToken.value;

                // Validate minutes
                check checkToken(state, lexer:COLON, "Expected a ':' after hours");
                check checkToken(state, lexer:DECIMAL, "Expected 2 digit minutes after ':'");
                check checkTime(state, state.currentToken.value, 0, 60, "minutes");
                valueBuffer += ":" + state.currentToken.value;

                return getODT(state, valueBuffer);
            }
            return generateGrammarError(state, "Cannot crate a UTC time for a local time");
        }
    }
}

# Validates a given time component
#
# + state - Current parser state
# + value - Actual value in the TOML document 
# + lowerBound - Minimum acceptable value
# + upperBound - Maximum acceptable value
# + valueName - Name of the time component
# + return - Returns an error if the requirements are not met.
function checkTime(ParserState state, string value, int lowerBound, int upperBound, string valueName) returns ParsingError? {
    // Expected the time digits to be 2.
    if (value.length() != 2) {
        return generateGrammarError(state, string `Expected number of digits in '${valueName}' to be 2`);
    }
    int intValue = <int>check processTypeCastingError(state, 'int:fromString(value));
    if (intValue < lowerBound || intValue > upperBound) {

        return generateGrammarError(state, string `Expected ${valueName} to be between ${lowerBound.toString()}-${upperBound.toString()}`);
    }
}

# Validates the date component.
#
# + state - Current parser state
# + value - Actual value in the TOML document  
# + numDigits - Required number of digits to the component. 
# + valueName - Name of the date component.
# + return - Returns the value in integer. Else, an parsing error.
function checkDate(ParserState state, string value, int numDigits, string valueName) returns int|ParsingError {
    if (value.length() != numDigits) {
        return generateGrammarError(state, string `Expected number of digits in ${valueName} to be ${numDigits.toString()}`);
    }
    return <int>check processTypeCastingError(state, 'int:fromString(value));
}

function getODT(ParserState state, string inputTime) returns json|ParsingError {
    if state.parseOffsetDateTime {
        return check processTypeCastingError(state, time:utcFromString(inputTime));
    }
    return inputTime;
}
