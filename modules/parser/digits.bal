import toml.lexer;
import ballerina/time;

# Handles the grammar rules of integers and float numbers.
# Delegates to date and time when the dates can be predicted.
#
# + fractional - Flag is set when processing the fractional segment
# + return - Parsing error if occurred
function number(ParserState state, string prevValue, boolean fractional = false) returns json|lexer:LexicalError|ParsingError {
    string lexemeBuffer = prevValue + state.currentToken.value;
    check checkToken(state);

    match state.currentToken.token {
        lexer:EOL|lexer:SEPARATOR|lexer:CLOSE_BRACKET|lexer:INLINE_TABLE_CLOSE => { // Generate the final number
            state.tokenConsumed = true;
            if (lexemeBuffer.length() > 1 && lexemeBuffer[0] == "0") {
                return generateError(state, "Cannot have leading 0's in integers or floats");
            }
            return fractional ? check processTypeCastingError(state, 'float:fromString(lexemeBuffer))
                                        : check processTypeCastingError(state, 'int:fromString(lexemeBuffer));
        }
        lexer:EXPONENTIAL => { // Handles lexer: numbers
            check checkToken(state, lexer:DECIMAL);

            // Evaluating the lexer: value
            float exponent = <float>(check processTypeCastingError(state, 'float:fromString(state.currentToken.value)));
            float prefix = <float>(check processTypeCastingError(state, 'float:fromString(lexemeBuffer)));
            return prefix * 'float:pow(10, exponent);
        }
        lexer:DOT => { // Handles fractional numbers
            if (fractional) {
                return generateError(state, "Cannot have a decimal point in the fraction part");
            }
            check checkToken(state, lexer:DECIMAL);
            lexemeBuffer += ".";
            return check number(state, lexemeBuffer, true);
        }
        lexer:MINUS => {
            state.updateLexerContext(lexer:DATE_TIME);
            return check date(state, lexemeBuffer);
        }
        lexer:COLON => {
            state.updateLexerContext(lexer:DATE_TIME);
            return check time(state, lexemeBuffer, lexemeBuffer);
        }
        _ => {
            return generateError(state, "Invalid token after an decimal integer");
        }
    }
}

# Process the date component.
#
# + return - An error if the grammar rules are not met.  
function date(ParserState state, string prevValue) returns json|lexer:LexicalError|ParsingError {
    string lexemeBuffer = prevValue;

    // Validate the year
    int year = check checkDate(state, lexemeBuffer, 4, "year");

    // Validate the month
    check checkToken(state, lexer:DECIMAL);
    int month = check checkDate(state, state.currentToken.value, 2, "month");
    lexemeBuffer += "-" + state.currentToken.value;

    // Validate the day
    check checkToken(state, lexer:MINUS);
    check checkToken(state, lexer:DECIMAL);
    int day = check checkDate(state, state.currentToken.value, 2, "day");
    lexemeBuffer += "-" + state.currentToken.value;

    // Validate the complete date
    error? validateDate = 'time:dateValidate({year, month, day});
    if (validateDate is error) {
        return generateError(state, validateDate.toString().substring(18));
    }

    check checkToken(state);
    match state.currentToken.token {
        lexer:EOL => { // Local date
            return lexemeBuffer;
        }
        lexer:TIME_DELIMITER => { // Adding a time component to the date

            // Obtain the hours
            check checkToken(state, lexer:DECIMAL);
            string hours = state.currentToken.value;
            lexemeBuffer += "T" + hours;
            check checkToken(state, lexer:COLON);
            return time(state, hours, lexemeBuffer, true);
        }
        _ => {
            return generateError(state, check formatErrorMessage(1, [lexer:EOL, lexer:TIME_DELIMITER], lexer:DECIMAL));
        }
    }
}

# Process the time component.
#
# + hours - Hours in the TOML document
# + datePrefixed - True if there is a date before the time
# + return - Returns the formatted time on success. Else, an parsing error.
function time(ParserState state, string hours, string prevValue, boolean datePrefixed = false) returns json|lexer:LexicalError|ParsingError {
    // Validate hours
    check checkTime(state, hours, 0, 24, "hours");

    // Validate minutes
    check checkToken(state, lexer:DECIMAL, "Expected 2 digit minutes after ':'");
    check checkTime(state, state.currentToken.value, 0, 60, "minutes");
    string lexemeBuffer = prevValue + ":" + state.currentToken.value;

    // Validate seconds
    check checkToken(state, lexer:COLON, "Expected a ':' after minutes");
    check checkToken(state, lexer:DECIMAL, "Expected a 2 digit seconds after ':'");
    check checkTime(state, state.currentToken.value, 0, 60, "minutes");
    lexemeBuffer += ":" + state.currentToken.value;

    check checkToken(state);
    match state.currentToken.token {
        lexer:EOL => { // Partial time
            return lexemeBuffer;
        }
        lexer:DOT => { // Fractional time
            check checkToken(state, lexer:DECIMAL, "Expected a integer after '.' for the time fraction");
            lexemeBuffer += "." + state.currentToken.value;

            check checkToken(state);
            match state.currentToken.token {
                lexer:EOL => { // Fractional partial time
                    return lexemeBuffer;
                }
                lexer:PLUS|lexer:MINUS|lexer:ZULU => { // Fractional time with time offset
                    return timeOffset(state, lexemeBuffer, datePrefixed);
                }
            }
        }
        lexer:PLUS|lexer:MINUS|lexer:ZULU => { // Partial time with time offset
            return timeOffset(state, lexemeBuffer, datePrefixed);
        }
        _ => {
            return generateError(state, check formatErrorMessage(1, [lexer:EOL, lexer:DOT, lexer:PLUS, lexer:MINUS, lexer:ZULU], lexer:DECIMAL));
        }
    }
}

# Returns the formatted time in UTC
#
# + datePrefixed - True if there is a date before the time
# + return - UTC object representing the time on success. Else, an parsing error.
function timeOffset(ParserState state, string prevValue, boolean datePrefixed) returns json|lexer:LexicalError|ParsingError {
    string lexemeBuffer = prevValue;

    match state.currentToken.token {
        lexer:ZULU => {
            return datePrefixed ? check processTypeCastingError(state, time:utcFromString(lexemeBuffer + "Z"))
                    : generateError(state, "Cannot crate a UTC time for a local time");
        }
        lexer:PLUS|lexer:MINUS => {
            if (datePrefixed) {
                lexemeBuffer += state.currentToken.token == lexer:PLUS ? "+" : "-";

                // Validate hours
                check checkToken(state, lexer:DECIMAL, "Expected a 2 digit hours after time offset");
                check checkTime(state, state.currentToken.value, 0, 24, "hours");
                lexemeBuffer += state.currentToken.value;

                // Validate minutes
                check checkToken(state, lexer:COLON, "Expected a ':' after hours");
                check checkToken(state, lexer:DECIMAL, "Expected 2 digit minutes after ':'");
                check checkTime(state, state.currentToken.value, 0, 60, "minutes");
                lexemeBuffer += ":" + state.currentToken.value;

                return processTypeCastingError(state, time:utcFromString(lexemeBuffer));
            }
            return generateError(state, "Cannot crate a UTC time for a local time");
        }
    }
}
