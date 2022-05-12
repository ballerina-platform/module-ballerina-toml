import ballerina/regex;

# Check for the lexemes to create an literal string.
#
# + state - Current lexer state
# + return - True if the end of the string, An error message for an invalid character.
function literalString(LexerState state) returns boolean|LexicalError {
    if regex:matches(<string>state.peek(), LITERAL_STRING_PATTERN) {
        state.appendToLexeme(<string>state.peek());
        return false;
    }
    if (checkCharacter(state, "'")) {
        return true;
    }
    return generateError(state, formatErrorMessage(<string>state.peek(), LITERAL_STRING));
}

# Check for the lexemes to create a basic string for a line in multiline strings.
#
# + state - Current lexer state
# + return - True if the end of the string, An error message for an invalid character.
function multilineLiteralString(LexerState state) returns boolean|LexicalError {
    if (!regex:matches(<string>state.peek(), LITERAL_STRING_PATTERN)) {
        if (checkCharacter(state, "'")) {
            if (state.peek(1) == "'" && state.peek(2) == "'") {

                // Check if the double quotes are at the end of the line
                if (state.peek(3) == "'" && state.peek(4) == "'") {
                    state.appendToLexeme("''");
                    state.forward();
                    return true;
                }

                // Check if the single quotes are at the end of the line
                if state.peek(3) == "'" {
                    state.appendToLexeme("'");
                    return true;
                }

                state.forward(-1);
                return true;
            }
        } else {
            return generateError(state, formatErrorMessage(<string>state.peek(), MULTILINE_BASIC_STRING_LINE));
        }
    }

    state.appendToLexeme(<string>state.peek());
    return false;
}

# Check for the lexemes to create an basic string.
#
# + state - Current lexer state
# + return - True if the end of the string, An error message for an invalid character.
function basicString(LexerState state) returns LexicalError|boolean {
    if regex:matches(<string>state.peek(), BASIC_STRING_PATTERN) {
        state.appendToLexeme(<string>state.peek());
        return false;
    }

    // Process escaped characters
    if (state.peek() == "\\") {
        state.forward();
        check escapedCharacter(state);
        return false;
    }

    if state.peek() == "\"" {
        return true;
    }

    return generateError(state, formatErrorMessage(<string>state.peek(), BASIC_STRING));
}

# Check for the lexemes to create a basic string for a line in multiline strings.
#
# + state - Current lexer state
# + return - True if the end of the string, An error message for an invalid character.
function multilineBasicString(LexerState state) returns boolean|LexicalError {
    if (!regex:matches(<string>state.peek(), BASIC_STRING_PATTERN)) {
        // Process the escape symbol
        if (checkCharacter(state, "\\")) {
            if state.peek(1) == () || state.peek(1) == " " || state.peek(1) == "\t" {
                state.forward(-1);
                return true;
            }
            state.forward();
            check escapedCharacter(state);
            return false;
        }

        if (checkCharacter(state, "\"")) {
            if (state.peek(1) == "\"" && state.peek(2) == "\"") {

                // Check if the double quotes are at the end of the line
                if (state.peek(3) == "\"" && state.peek(4) == "\"") {
                    state.appendToLexeme("\"\"");
                    state.forward();
                    return true;
                }

                // Check if the single quotes are at the end of the line
                if state.peek(3) == "\"" {
                    state.appendToLexeme("\"");
                    return true;
                }

                state.forward(-1);
                return true;
            }
        } else {
            return generateError(state, formatErrorMessage(<string>state.peek(), MULTILINE_BASIC_STRING_LINE));
        }
    }

    // Ignore whitespace if the multiline escape symbol is detected
    if (state.context == MULTILINE_ESCAPE && checkCharacter(state, " ")) {
        return false;
    }

    state.appendToLexeme(<string>state.peek());
    state.context = MULTILINE_BASIC_STRING;
    return false;
}

# Scan lexemes for the escaped characters.
# Adds the processed escaped character to the lexeme.
#
# + state - Current lexer state
# + return - An error on failure
function escapedCharacter(LexerState state) returns LexicalError? {
    string currentChar;

    // Check if the character is empty
    if (state.peek() == ()) {
        return generateError(state, "Escaped character cannot be empty");
    } else {
        currentChar = <string>state.peek();
    }

    // Check for predefined escape characters
    if (escapedCharMap.hasKey(currentChar)) {
        state.appendToLexeme(<string>escapedCharMap[currentChar]);
        return;
    }

    // Check for unicode characters
    match currentChar {
        "u" => {
            check unicodeEscapedCharacters(state, "u", 4);
            return;
        }
        "U" => {
            check unicodeEscapedCharacters(state, "U", 8);
            return;
        }
    }
    return generateError(state, formatErrorMessage(<string>state.peek(), BASIC_STRING));
}

# Process the hex codes under the unicode escaped character.
#
# + state - Current lexer state
# + escapedChar - Escaped character before the digits  
# + length - Number of digits
# + return - An error on failure
function unicodeEscapedCharacters(LexerState state, string escapedChar, int length) returns LexicalError? {

    // Check if the required digits do not overflow the current line.
    if state.line.length() < length + state.index {
        return generateError(state, string `Expected ${length.toString()} characters for the '\\${escapedChar}' unicode escape`);
    }

    string unicodeDigits = "";

    // Check if the digits adhere to the hexadecimal code pattern.
    foreach int i in 0 ... length - 1 {
        state.forward();
        if regex:matches(<string>state.peek(), HEXADECIMAL_DIGIT_PATTERN) {
            unicodeDigits += <string>state.peek();
            continue;
        }
        return generateError(state, formatErrorMessage(<string>state.peek(), HEXADECIMAL));
    }
    int|error hexResult = 'int:fromHexString(unicodeDigits);
    if hexResult is error {
        return generateError(state, 'error:message(hexResult));
    }

    string|error unicodeResult = 'string:fromCodePointInt(hexResult);
    if unicodeResult is error {
        return generateError(state, 'error:message(unicodeResult));
    }

    state.appendToLexeme(unicodeResult);
}

# Check for the lexemes to create an unquoted key token.
#
# + state - Current lexer state
# + return - True if the end of the key, An error message for an invalid character.
function unquotedKey(LexerState state) returns boolean|LexicalError {
    if regex:matches(<string>state.peek(), UNQUOTED_STRING_PATTERN) {
        state.appendToLexeme(<string>state.peek());
        return false;
    }

    if (checkCharacter(state, [" ", ".", "]", "="])) {
        state.forward(-1);
        return true;
    }

    return generateError(state, formatErrorMessage(<string>state.peek(), UNQUOTED_KEY));

}

# Check for the lexemes to crete an DECIMAL token.
#
# + digitPattern - Regex pattern of the number system
# + return - Generates a function which checks the lexemes for the given number system.  
function digit(string digitPattern) returns function (LexerState state) returns boolean|LexicalError {
    return function(LexerState state) returns boolean|LexicalError {
        if regex:matches(<string>state.peek(), digitPattern) {
            state.appendToLexeme(<string>state.peek());
            return false;
        }

        if (checkCharacter(state, [" ", "#", "\t"])) {
            state.forward(-1);
            return true;
        }

        // Both preceding and succeeding chars of the '_' should be digits
        if (checkCharacter(state, "_")) {
            // '_' should be after a digit
            if (state.lexeme.length() > 0) {
                string? nextChr = state.peek(1);
                // '_' should be before a digit
                if (nextChr == ()) {
                    state.forward();
                    return generateError(state, "A digit must appear after the '_'");
                }
                // check if the next character is a digit
                if (regex:matches(<string>nextChr, digitPattern)) {
                    return false;
                }

                return generateError(state, string `Invalid character '${<string>state.peek()}' after '_'`);
            }
            return generateError(state, string `Invalid character '${<string>state.peek()}' after '='`);
        }

        // Float number allows only a decimal number a prefix.
        // Check for decimal points and exponential in decimal numbers.
        // Check for separators and end symbols.
        if (digitPattern == DECIMAL_DIGIT_PATTERN) {
            if (checkCharacter(state, [".", "e", "E", ",", "]", "}"])) {
                state.forward(-1);
            }
            if (checkCharacter(state, ["-", ":"])) {
                state.forward(-1);
                state.context = DATE_TIME;
            }
            if (state.context == DATE_TIME && checkCharacter(state, ["-", ":", "t", "T", "+", "-", "Z"])) {
                state.forward(-1);
            }
            return true;
        }
        return generateError(state, formatErrorMessage(<string>state.peek(), DECIMAL));
    }
;
}
