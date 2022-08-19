# Check for the lexemes to create an literal string.
#
# + state - Current lexer state
# + return - True if the end of the string, An error message for an invalid character.
function scanLiteralString(LexerState state) returns boolean|LexicalError {
    if patternLiteralString(state.currentChar()) {
        state.appendToLexeme(state.currentChar());
        return false;
    }
    if checkCharacter(state, "'") {
        return true;
    }
    return generateInvalidCharacterError(state, LITERAL_STRING);
}

# Check for the lexemes to create a basic string for a line in multiline strings.
#
# + state - Current lexer state
# + return - True if the end of the string, An error message for an invalid character.
function scanMultilineLiteralString(LexerState state) returns boolean|LexicalError {
    if !patternLiteralString(state.currentChar()) {
        if checkCharacter(state, "'") {
            if state.peek(1) == "'" && state.peek(2) == "'" {

                // Check if the double quotes are at the end of the line
                if state.peek(3) == "'" && state.peek(4) == "'" {
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
            return generateInvalidCharacterError(state, MULTILINE_BASIC_STRING_LINE);
        }
    }

    state.appendToLexeme(state.currentChar());
    return false;
}

# Check for the lexemes to create an basic string.
#
# + state - Current lexer state
# + return - True if the end of the string, An error message for an invalid character.
function scanBasicString(LexerState state) returns LexicalError|boolean {
    if patternBasicString(state.currentChar()) {
        state.appendToLexeme(state.currentChar());
        return false;
    }

    // Process escaped characters
    if state.peek() == "\\" {
        state.forward();
        check scanEscapedCharacter(state);
        return false;
    }

    if state.peek() == "\"" {
        return true;
    }

    return generateInvalidCharacterError(state, BASIC_STRING);
}

# Check for the lexemes to create a basic string for a line in multiline strings.
#
# + state - Current lexer state
# + return - True if the end of the string, An error message for an invalid character.
function scanMultilineBasicString(LexerState state) returns boolean|LexicalError {
    if !patternBasicString(state.currentChar()) {
        // Process the escape symbol
        if checkCharacter(state, "\\") {
            if state.peek(1) == () || state.peek(1) == " " || state.peek(1) == "\t" {
                state.forward(-1);
                return true;
            }
            state.forward();
            check scanEscapedCharacter(state);
            return false;
        }

        if checkCharacter(state, "\"") {
            if state.peek(1) == "\"" && state.peek(2) == "\"" {

                // Check if the double quotes are at the end of the line
                if state.peek(3) == "\"" && state.peek(4) == "\"" {
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
            return generateInvalidCharacterError(state, MULTILINE_BASIC_STRING_LINE);
        }
    }

    // Ignore whitespace if the multiline escape symbol is detected
    if state.context == MULTILINE_ESCAPE && checkCharacter(state, " ") {
        return false;
    }

    state.appendToLexeme(state.currentChar());
    state.context = MULTILINE_BASIC_STRING;
    return false;
}

# Scan lexemes for the escaped characters.
# Adds the processed escaped character to the lexeme.
#
# + state - Current lexer state
# + return - An error on failure
function scanEscapedCharacter(LexerState state) returns LexicalError? {
    string currentChar;

    // Check if the character is empty
    currentChar = state.currentChar();

    // Check for predefined escape characters
    if escapedCharMap.hasKey(currentChar) {
        state.appendToLexeme(<string>escapedCharMap[currentChar]);
        return;
    }

    // Check for unicode characters
    match currentChar {
        "u" => {
            check scanUnicodeEscapedCharacter(state, "u", 4);
            return;
        }
        "U" => {
            check scanUnicodeEscapedCharacter(state, "U", 8);
            return;
        }
    }
    return generateInvalidCharacterError(state, BASIC_STRING);
}

# Process the hex codes under the unicode escaped character.
#
# + state - Current lexer state
# + escapedChar - Escaped character before the scanDigits  
# + length - Number of scanDigits
# + return - An error on failure
function scanUnicodeEscapedCharacter(LexerState state, string escapedChar, int length) returns LexicalError? {

    // Check if the required scanDigits do not overflow the current line.
    if state.line.length() < length + state.index {
        return generateLexicalError(state, string `Expected ${length.toString()} characters for the '\\${escapedChar}' unicode escape`);
    }

    string unicodeDigits = "";

    // Check if the scanDigits adhere to the hexadecimal code pattern.
    foreach int i in 0 ... length - 1 {
        state.forward();
        if patternHexadecimal(state.currentChar()) {
            unicodeDigits += state.currentChar();
            continue;
        }
        return generateInvalidCharacterError(state, HEXADECIMAL);
    }
    int|error hexResult = int:fromHexString(unicodeDigits);
    if hexResult is error {
        return generateLexicalError(state, error:message(hexResult));
    }

    string|error unicodeResult = string:fromCodePointInt(hexResult);
    if unicodeResult is error {
        return generateLexicalError(state, error:message(unicodeResult));
    }

    state.appendToLexeme(unicodeResult);
}

# Check for the lexemes to create an unquoted key token.
#
# + state - Current lexer state
# + return - True if the end of the key, An error message for an invalid character.
function scanUnquotedKey(LexerState state) returns boolean|LexicalError {
    if patternUnquotedString(state.currentChar()) {
        state.appendToLexeme(state.currentChar());
        return false;
    }

    if checkCharacter(state, [" ", ".", "]", "="]) {
        state.forward(-1);
        return true;
    }

    return generateInvalidCharacterError(state, UNQUOTED_KEY);

}

# Check for the lexemes to create an token of a number system.
#
# + pattern - Pattern of the number system  
# + return - Generates a function which checks the lexemes for the given number system.
function scanDigit(function (string:Char char) returns boolean pattern)
    returns function (LexerState state) returns boolean|LexicalError {
    return function(LexerState state) returns boolean|LexicalError {

        if pattern(state.currentChar()) {
            state.appendToLexeme(state.currentChar());
            return false;
        }

        if checkCharacter(state, [" ", "#", "\t", "\n"]) {
            state.forward(-1);
            return true;
        }

        // Both preceding and succeeding chars of the '_' should be scanDigits
        if checkCharacter(state, "_") {
            // '_' should be after a scanDigit
            if state.lexeme.length() > 0 {
                string? nextChr = state.peek(1);
                // '_' should be before a scanDigit
                if nextChr == () {
                    state.forward();
                    return generateLexicalError(state, "A digit must appear after the '_'");
                }
                // Check if the next character is a scanDigit
                if pattern(<string:Char>nextChr) {
                    return false;
                }

                return generateLexicalError(state, string `Invalid character '${state.currentChar()}' after '_'`);
            }
            return generateLexicalError(state, string `Invalid character '${state.currentChar()}' after '='`);
        }

        return generateInvalidCharacterError(state, DECIMAL);
    };
}


# Check for the lexemes to create an token of a number system.
#
# + state - Current lexer state
# + return - Return Value Description
function scanDecimal(LexerState state) returns boolean|LexicalError {
    function (LexerState) returns boolean|LexicalError scanDecimalDigit = scanDigit(patternDecimal);
    boolean|LexicalError digitOutput = scanDecimalDigit(state);

    if digitOutput is boolean {
        return digitOutput;
    }

    // Float number allows only a decimal number a prefix.
    // Check for decimal points and exponential in decimal numbers.
    // Check for separators and end symbols.
    if checkCharacter(state, [".", "e", "E", ",", "]", "}"]) {
        state.forward(-1);
    } else if checkCharacter(state, ["-", ":"]) {
        state.forward(-1);
        state.context = DATE_TIME;
    } else if state.context == DATE_TIME && checkCharacter(state, ["-", ":", "t", "T", "+", "-", "Z"]) {
        state.forward(-1);
    } else {
        return generateInvalidCharacterError(state, DECIMAL);
    }
    return true;
}
