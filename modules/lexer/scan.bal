import ballerina/regex;

# Check for the lexemes to create an basic string.
#
# + return - True if the end of the string, An error message for an invalid character.  
function basicString() returns LexicalError|boolean {
    if matchRegexPattern(BASIC_STRING_PATTERN) {
        // Process escaped characters
        if (peek() == "\\") {
            forward();
            check escapedCharacter();
            return false;
        }

        lexeme += <string>peek();
        return false;
    }

    if peek() == "\"" {
        return true;
    }

    return generateError(formatErrorMessage(BASIC_STRING));
}

# Check for the lexemes to create a basic string for a line in multiline strings.
#
# + return - True if the end of the string, An error message for an invalid character.  
function multilineBasicString() returns boolean|LexicalError {
    if (!matchRegexPattern(BASIC_STRING_PATTERN)) {
        if (checkCharacter("\"")) {
            if (peek(1) == "\"" && peek(2) == "\"") {

                // Check if the double quotes are at the end of the line
                if (peek(3) == "\"" && peek(4) == "\"") {
                    lexeme += "\"\"";
                    index += 1;
                    return true;
                }

                index -= 1;
                return true;
            }
        } else {
            return generateError(formatErrorMessage(MULTI_BSTRING_CHARS));
        }
    }

    // Process the escape symbol
    if (checkCharacter("\\")) {
        index -= 1;
        return true;
    }

    // Ignore whitespace if the multiline escape symbol is detected
    if (state == MULTILINE_ESCAPE && checkCharacter(" ")) {
        return false;
    }

    lexeme += <string>peek();
    state = MULTILINE_BSTRING;
    return false;
}

# Scan lexemes for the escaped characters.
# Adds the processed escaped character to the lexeme.
#
# + return - An error on failure
function escapedCharacter() returns LexicalError? {
    string currentChar;

    // Check if the character is empty
    if (peek() == ()) {
        return generateError("Escaped character cannot be empty");
    } else {
        currentChar = <string>peek();
    }

    // Check for predefined escape characters
    if (escapedCharMap.hasKey(currentChar)) {
        lexeme += <string>escapedCharMap[currentChar];
        return;
    }

    // Check for unicode characters
    match currentChar {
        "u" => {
            check unicodeEscapedCharacters("u", 4);
            return;
        }
        "U" => {
            check unicodeEscapedCharacters("U", 8);
            return;
        }
    }
    return generateError(formatErrorMessage(BASIC_STRING));
}

# Process the hex codes under the unicode escaped character.
#
# + escapedChar - Escaped character before the digits  
# + length - Number of digits
# + return - An error on failure
function unicodeEscapedCharacters(string escapedChar, int length) returns LexicalError? {

    // Check if the required digits do not overflow the current line.
    if line.length() < length + index {
        return generateError("Expected " + length.toString() + " characters for the '\\" + escapedChar + "' unicode escape");
    }

    string unicodeDigits = "";

    // Check if the digits adhere to the hexadecimal code pattern.
    foreach int i in 0 ... length - 1 {
        forward();
        if matchRegexPattern(HEXADECIMAL_DIGIT_PATTERN) {
            unicodeDigits += <string>peek();
            continue;
        }
        return generateError(formatErrorMessage(HEXADECIMAL));
    }
    int|error hexResult = 'int:fromHexString(unicodeDigits);
    if hexResult is error {
        return generateError('error:message(hexResult));
    }

    string|error unicodeResult = 'string:fromCodePointInt(hexResult);
    if unicodeResult is error {
        return generateError('error:message(unicodeResult));
    }

    lexeme += unicodeResult;
}

# Check for the lexemes to create an literal string.
#
# + return - True if the end of the string, An error message for an invalid character.  
function literalString() returns boolean|LexicalError {
    if matchRegexPattern(LITERAL_STRING_PATTERN) {
        lexeme += <string>peek();
        return false;
    }
    if (checkCharacter("'")) {
        return true;
    }
    return generateError(formatErrorMessage(LITERAL_STRING));

}

# Check for the lexemes to create a basic string for a line in multiline strings.
#
# + return - True if the end of the string, An error message for an invalid character.  
function multilineLiteralString() returns boolean|LexicalError {
    if (!matchRegexPattern(LITERAL_STRING_PATTERN)) {
        if (checkCharacter("'")) {
            if (peek(1) == "'" && peek(2) == "'") {

                // Check if the double quotes are at the end of the line
                if (peek(3) == "'" && peek(4) == "'") {
                    lexeme += "''";
                    index += 1;
                    return true;
                }

                index -= 1;
                return true;
            }
        } else {
            return generateError(formatErrorMessage(MULTI_BSTRING_CHARS));
        }
    }

    lexeme += <string>peek();
    return false;
}

# Check for the lexemes to create an unquoted key token.
#
# + return - True if the end of the key, An error message for an invalid character.  
function unquotedKey() returns boolean|LexicalError {
    if matchRegexPattern(UNQUOTED_STRING_PATTERN) {
        lexeme += <string>peek();
        return false;
    }

    if (checkCharacter([" ", ".", "]", "="])) {
        index = index - 1;
        return true;
    }

    return generateError(formatErrorMessage(UNQUOTED_KEY));

}

# Check for the lexemes to crete an DECIMAL token.
#
# + digitPattern - Regex pattern of the number system
# + return - Generates a function which checks the lexemes for the given number system.  
function digit(string digitPattern) returns function () returns boolean|LexicalError {
    return function() returns boolean|LexicalError {
        if matchRegexPattern(digitPattern) {
            lexeme += <string>peek();
            return false;
        }

        if (checkCharacter([" ", "#", "\t"])) {
            index -= 1;
            return true;
        }

        // Both preceding and succeeding chars of the '_' should be digits
        if (checkCharacter("_")) {
            // '_' should be after a digit
            if (lexeme.length() > 0) {
                string? nextChr = peek(1);
                // '_' should be before a digit
                if (nextChr == ()) {
                    forward();
                    return generateError("A digit must appear after the '_'");
                }
                // check if the next character is a digit
                if (regex:matches(<string>nextChr, digitPattern)) {
                    return false;
                }
                return generateError("Invalid character \"" + <string>peek() + "\" after '_'");
            }
            return generateError("Invalid character \"" + <string>peek() + "\" after '='");
        }

        // Float number allows only a decimal number a prefix.
        // Check for decimal points and exponential in decimal numbers.
        // Check for separators and end symbols.
        if (digitPattern == DECIMAL_DIGIT_PATTERN) {
            if (checkCharacter([".", "e", "E", ",", "]", "}"])) {
                index -= 1;
            }
            if (checkCharacter(["-", ":"])) {
                index -= 1;
                state = DATE_TIME;
            }
            if (state == DATE_TIME && checkCharacter(["-", ":", "t", "T", "+", "-", "Z"])) {
                index -= 1;
            }
            return true;
        }

        return generateError(formatErrorMessage(DECIMAL));

    };
}
