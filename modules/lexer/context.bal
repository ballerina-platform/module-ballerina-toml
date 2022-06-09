# Check for tokens related to array table, standard table, and expression key.
#
# + state - Current lexer state
# + return - Tokenized TOML key token. Else, an error on failure.
function contextExpressionKey(LexerState state) returns LexerState|LexicalError {
    // Check for line breaks when reading a string
    if state.peek() == "\n" {
        state.isNewLine = true;
        return state.tokenize(EOL);
    }

    // Check for unquoted keys
    if patternUnquotedString(state.currentChar()) {
        return iterate(state, scanUnquotedKey, UNQUOTED_KEY);
    }

    match state.peek() {
        " "|"\t" => { // Ignore whitespace
            state.forward();
            return scan(state);
        }
        "#" => { // Ignore comments
            state.forward(-1);
            return state.tokenize(EOL);
        }
        "\"" => { // Check for basic string key
            state.forward();
            return iterate(state, scanBasicString,
                BASIC_STRING, "Expected '\"' at the end of the basic string");
        }
        "'" => { // Check for literal string key
            state.forward();
            return iterate(state, scanLiteralString,
                LITERAL_STRING, "Expected ''' at the end of the literal string");
        }
        "." => { // Check for dotted key
            return state.tokenize(DOT);
        }
        "=" => { // Check for key value separator
            return state.tokenize(KEY_VALUE_SEPARATOR);
        }
        "[" => { // Check for opening array value or standard table
            if state.peek(1) == "[" { // Array table
                state.forward();
                return state.tokenize(ARRAY_TABLE_OPEN);
            }
            // Standard table
            return state.tokenize(OPEN_BRACKET);
        }
        "]" => { // Check for closing array value or standard table
            if state.peek(1) == "]" { // Array table
                state.forward();
                return state.tokenize(ARRAY_TABLE_CLOSE);
            }
            // Standard table
            return state.tokenize(CLOSE_BRACKET);
        }
        "}" => { // Check for closing inline table
            return state.tokenize(INLINE_TABLE_CLOSE);
        }
        "," => { // Check for separator
            return state.tokenize(SEPARATOR);
        }
    }

    return generateInvalidCharacterError(state, EXPRESSION_KEY);
}

# Check for tokens related to multi-line basic string.
#
# + state - Current lexer state
# + return - Tokenized multiline basic string token. Else, an error on failure.
function contextMultilineBasicString(LexerState state) returns LexerState|LexicalError {
    // Scan for multiline basic string delimiter
    if state.peek() == "\"" && state.peek(1) == "\"" && state.peek(2) == "\"" {
        state.forward(2);
        return state.tokenize(MULTILINE_BASIC_STRING_DELIMITER);
    }

    // Process the escape symbol
    if state.peek() == "\\" && (state.peek(1) == () || state.peek(1) == " ") {
        return state.tokenize(MULTILINE_BASIC_STRING_ESCAPE);
    }

    // Process multiline basic string regular characters
    return iterate(state, scanMultilineBasicString, MULTILINE_BASIC_STRING_LINE);
}

# Check for tokens related to multi-line literal string.
#
# + state - Current lexer state
# + return - Tokenized multiline literal string token. Else, an error on failure.
function contextMultilineLiteralString(LexerState state) returns LexerState|LexicalError {
    // Scan for multiline literal string delimiter
    if state.peek() == "'" && state.peek(1) == "'" && state.peek(2) == "'" {
        state.forward(2);
        return state.tokenize(MULTILINE_LITERAL_STRING_DELIMITER);
    }

    // Process multiline literal string regular characters
    return iterate(state, scanMultilineLiteralString, MULTILINE_LITERAL_STRING_LINE);
}

# Check for tokens related to date time.
#
# + state - Current lexer state
# + return - Tokenized date time token. Else, an error on failure.
function contextDateTime(LexerState state) returns LexerState|LexicalError {
    match state.peek() {
        "#" => { // Ignore comments
            state.forward(-1);
            return state.tokenize(EOL);
        }
        "\n" => { // Check for line breaks when reading from string
            state.isNewLine = true;
            return state.tokenize(EOL);
        }
        ":" => { // Check for time separator
            return state.tokenize(COLON);
        }
        "t"|"T"|" " => { // check for time delimiter
            state.appendToLexeme(state.currentChar());
            return state.tokenize(TIME_DELIMITER);
        }
        "." => { // Check for time fraction
            return state.tokenize(DOT);
        }
        "-" => { // Check for date separator or negative offset
            return state.tokenize(MINUS);
        }
        "+" => { // Check for positive offset
            return state.tokenize(PLUS);
        }
        "Z" => { // Check for Zulu offset
            return state.tokenize(ZULU);
        }
    }

    // Scan digits for date time
    if patternDecimal(state.currentChar()) {
        return iterate(state, scanDecimal, DECIMAL);
    }

    return generateInvalidCharacterError(state, DATE_TIME);
}

# Check for values of tables and array values.
#
# + state - Current lexer state
# + return - Tokenized TOML value token. Else, an error on failure.
function contextExpressionValue(LexerState state) returns LexerState|LexicalError {
    match state.peek() {
        " "|"\t" => { // Ignore whitespace
            state.forward();
            return scan(state);
        }
        "\n" => { // Check for line breaks when reading from string
            state.isNewLine = true;
            return state.tokenize(EOL);
        }
        "#" => { // Ignore comments
            state.forward(-1);
            return state.tokenize(EOL);
        }
        "[" => { // Check for opening array value and standard table
            return state.tokenize(OPEN_BRACKET);
        }
        "]" => { // Check for closing array value and standard table
            return state.tokenize(CLOSE_BRACKET);
        }
        "," => { // Check for separator 
            return state.tokenize(SEPARATOR);
        }
        "\"" => { // Check for basic string delimiter 
            // Multi-line basic strings
            if state.peek(1) == "\"" && state.peek(2) == "\"" {
                state.forward(2);
                return state.tokenize(MULTILINE_BASIC_STRING_DELIMITER);
            }

            // Basic strings
            state.forward();
            return iterate(state, scanBasicString, BASIC_STRING, "Expected '\"' at the end of the basic string");
        }
        "'" => { // Check for literal string delimiter 
            // Multi-line literal string
            if state.peek(1) == "'" && state.peek(2) == "'" {
                state.forward(2);
                return state.tokenize(MULTILINE_LITERAL_STRING_DELIMITER);
            }

            // Literal strings
            state.forward();
            return iterate(state, scanLiteralString, LITERAL_STRING, "Expected ''' at the end of the literal string");
        }
        "." => { // Check for decimal point
            return state.tokenize(DOT);
        }
        "0" => { // Check for numbers starting with 0
            string? peekValue = state.peek(1);
            
            // A decimal cannot start with 0 unless it is the only digit
            if peekValue == () {
                state.appendToLexeme("0");
                return state.tokenize(DECIMAL);
            }

            if patternDecimal(<string:Char>peekValue) || <string>peekValue == "e" {
                return iterate(state, scanDecimal, DECIMAL);
            }

            match peekValue {
                "x" => { // Check for hexadecimal numbers
                    state.forward(2);
                    return iterate(state, scanDigit(patternHexadecimal), HEXADECIMAL);
                }
                "o" => { // Check for octal numbers
                    state.forward(2);
                    return iterate(state, scanDigit(patternOctal), OCTAL);
                }
                "b" => { // Check for binary numbers
                    state.forward(2);
                    return iterate(state, scanDigit(patternBinary), BINARY);
                }
                " "|"#"|"."|","|"]" => { // A decimal cannot start with 0 unless it is the only digit
                    state.appendToLexeme("0");
                    return state.tokenize(DECIMAL);
                }
                _ => {
                    return generateLexicalError(state, string `Invalid character '${peekValue}' after '0'`);
                }
            }
        }
        "+"|"-" => { // Check for positive and negative decimal number
            state.appendToLexeme(state.currentChar());
            state.forward();
            match state.peek() {
                "0" => { // There cannot be leading zero.
                    state.appendToLexeme("0");
                    return state.tokenize(DECIMAL);
                }
                () => { // Only '+' and '-' are invalid.
                    return generateLexicalError(state, string `Expected digits after '${<string>state.peek(-1)}'`);
                }
                "n" => { // Check for NaN token
                    return tokensInSequence(state, "nan", NAN);
                }
                "i" => { // Check for infinity tokens
                    return tokensInSequence(state, "inf", INFINITY);
                }
                _ => { // Check for remaining digits of the decimal numbers
                    if patternDecimal(state.currentChar()) {
                        return iterate(state, scanDecimal, DECIMAL);
                    }
                    return generateLexicalError(state,
                        string `Invalid character '${state.peek(1) ?: "<end-of-line>"} after '${state.currentChar()}'`);
                }
            }
        }
        "t" => { // Check for boolean true token
            return tokensInSequence(state, "true", BOOLEAN);
        }
        "f" => { // Check for boolean false token
            return tokensInSequence(state, "false", BOOLEAN);
        }
        "n" => { // Check for NaN token
            return tokensInSequence(state, "nan", NAN);
        }
        "i" => { // Check for positive infinity
            state.appendToLexeme("+");
            return tokensInSequence(state, "inf", INFINITY);
        }
        "e"|"E" => { // Check for exponential token
            return state.tokenize(EXPONENTIAL);
        }
        "{" => { // Check for opening inline table
            return state.tokenize(INLINE_TABLE_OPEN);
        }
        "}" => { // Check for closing inline table
            return state.tokenize(INLINE_TABLE_CLOSE);
        }
    }

    // Check for values starting with an integer
    if patternDecimal(state.currentChar()) {
        return iterate(state, scanDecimal, DECIMAL);
    }

    return generateInvalidCharacterError(state, EXPRESSION_VALUE);
}
