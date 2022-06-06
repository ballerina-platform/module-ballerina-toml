# Check for array table, standard table, and expression key.
#
# + state - Current lexer state
# + return - Tokenize TOML key token
function contextExpressionKey(LexerState state) returns LexerState|LexicalError {
    // Check for unquoted keys
    if patternUnquotedString(<string:Char>state.peek()) {
        return check iterate(state, scanUnquotedKey, UNQUOTED_KEY);
    }

    match state.peek() {
        " "|"\t" => { // Ignore whitespace
            state.forward();
            return check scan(state);
        }
        "#" => { // Ignore comments
            state.forward(-1);
            return state.tokenize(EOL);
        }
        "\"" => { // Check for basic string keys
            state.forward();
            return check iterate(state, scanBasicString,
                BASIC_STRING, "Expected '\"' at the end of the basic string");
        }
        "'" => { // Check for literal string keys
            state.forward();
            return check iterate(state, scanLiteralString,
                LITERAL_STRING, "Expected ''' at the end of the literal string");
        }
        "." => { // Check for dotted keys
            return state.tokenize(DOT);
        }
        "=" => { // Check for key value separator
            return state.tokenize(KEY_VALUE_SEPARATOR);
        }
        "[" => { // Array values and standard tables
            if state.peek(1) == "[" && state.context == EXPRESSION_KEY { // Array tables
                state.forward();
                return state.tokenize(ARRAY_TABLE_OPEN);
            }
            return state.tokenize(OPEN_BRACKET);
        }
        "]" => { // Array values and standard tables
            if state.peek(1) == "]" && state.context == EXPRESSION_KEY { // Array tables
                state.forward();
                return state.tokenize(ARRAY_TABLE_CLOSE);
            }
            return state.tokenize(CLOSE_BRACKET);
        }
        "}" => { // Close inline table
            return state.tokenize(INLINE_TABLE_CLOSE);
        }
        "," => { // Separator
            return state.tokenize(SEPARATOR);
        }
    }

    return generateInvalidCharacterError(state, EXPRESSION_KEY);
}

# Check for tokens related to multi-line basic string.
#
# + state - Current lexer state
# + return - Tokenize multiline basic string token
function contextMultilineBasicString(LexerState state) returns LexerState|LexicalError {
    if state.peek() == "\"" && state.peek(1) == "\"" && state.peek(2) == "\"" {
        state.forward(2);
        return state.tokenize(MULTILINE_BASIC_STRING_DELIMITER);
    }

    // Process the escape symbol
    if state.peek() == "\\" && (state.peek(1) == () || state.peek(1) == " ") {
        return state.tokenize(MULTILINE_BASIC_STRING_ESCAPE);
    }

    // Process multiline string regular characters
    if patternBasicString(<string:Char>state.peek())
            || state.peek() == "\\"
            || state.peek() == "'"
            || state.peek() == "\"" {
        return check iterate(state, scanMultilineBasicString, MULTILINE_BASIC_STRING_LINE);
    }

    return generateInvalidCharacterError(state, MULTILINE_BASIC_STRING);
}

# Check for tokens related to multi-line literal string.
#
# + state - Current lexer state
# + return - Tokenize multiline literal string token
function contextMultilineLiteralString(LexerState state) returns LexerState|LexicalError {
    if state.peek() == "'" && state.peek(1) == "'" && state.peek(2) == "'" {
        state.forward(2);
        return state.tokenize(MULTILINE_LITERAL_STRING_DELIMITER);
    }

    if patternLiteralString(<string:Char>state.peek())
            || state.peek() == "'"
            || state.peek() == "\"" {
        return iterate(state, scanMultilineLiteralString, MULTILINE_LITERAL_STRING_LINE);
    }

    return generateInvalidCharacterError(state, MULTILINE_LITERAL_STRING);
}

# Check for tokens related to date time.
#
# + state - Current lexer state
# + return - Tokenize date time token
function contextDateTime(LexerState state) returns LexerState|LexicalError {
    match state.peek() {
        "#" => { // Ignore comments
            state.forward(-1);
            return state.tokenize(EOL);
        }
        ":" => { // Time separator
            return state.tokenize(COLON);
        }
        "-" => { // Date separator or negative offset
            return state.tokenize(MINUS);
        }
        "t"|"T"|" " => { // Time delimiter
            state.appendToLexeme(<string>state.peek());
            return state.tokenize(TIME_DELIMITER);
        }
        "." => { // Time fraction
            return state.tokenize(DOT);
        }
        "+" => { // Positive offset
            return state.tokenize(PLUS);
        }
        "Z" => { // Zulu offset
            return state.tokenize(ZULU);
        }
    }

    // Scan digits for date time
    if patternDecimal(<string:Char>state.peek()) {
        return check iterate(state, scanDecimal, DECIMAL);
    }

    return generateInvalidCharacterError(state, DATE_TIME);
}

# Check for values of tables and array values.
#
# + state - Current lexer state
# + return - Tokenize TOML value token
function contextExpressionValue(LexerState state) returns LexerState|LexicalError {
    match state.peek() {
        " "|"\t" => { // Ignore whitespace
            state.forward();
            return check scan(state);
        }
        "#" => { // Ignore comments
            state.forward(-1);
            return state.tokenize(EOL);
        }
        "[" => { // Array values and standard tables
            return state.tokenize(OPEN_BRACKET);
        }
        "]" => { // Array values and standard tables
            return state.tokenize(CLOSE_BRACKET);
        }
        "," => { // Separator
            return state.tokenize(SEPARATOR);
        }
        "\"" => { // Basic strings
            // Multi-line basic strings
            if state.peek(1) == "\"" && state.peek(2) == "\"" {
                state.forward(2);
                return state.tokenize(MULTILINE_BASIC_STRING_DELIMITER);
            }

            // Basic strings
            state.forward();
            return check iterate(state, scanBasicString, BASIC_STRING, "Expected '\"' at the end of the basic string");
        }
        "'" => { // Literal strings
            // Multi-line literal string
            if state.peek(1) == "'" && state.peek(2) == "'" {
                state.forward(2);
                return state.tokenize(MULTILINE_LITERAL_STRING_DELIMITER);
            }

            // Literal strings
            state.forward();
            return check iterate(state, scanLiteralString, LITERAL_STRING, "Expected ''' at the end of the literal string");
        }
        "." => { // Dotted keys
            return state.tokenize(DOT);
        }
        "0" => {
            string? peekValue = state.peek(1);
            if peekValue == () {
                state.appendToLexeme("0");
                return state.tokenize(DECIMAL);
            }

            if patternDecimal(<string:Char>peekValue) || <string>peekValue == "e" {
                return check iterate(state, scanDecimal, DECIMAL);
            }

            match peekValue {
                "x" => { // Hexadecimal numbers
                    state.forward(2);
                    return check iterate(state, scanDigit(patternHexadecimal), HEXADECIMAL);
                }
                "o" => { // Octal numbers
                    state.forward(2);
                    return check iterate(state, scanDigit(patternOctal), OCTAL);
                }
                "b" => { // Binary numbers
                    state.forward(2);
                    return check iterate(state, scanDigit(patternBinary), BINARY);
                }
                " "|"#"|"."|","|"]" => { // Decimal numbers
                    state.appendToLexeme("0");
                    return state.tokenize(DECIMAL);
                }
                _ => {
                    return generateLexicalError(state, string `Invalid character '${peekValue}' after '0'`);
                }
            }
        }
        "+"|"-" => { // Decimal numbers
            state.appendToLexeme(<string>state.peek());
            state.forward();
            match state.peek() {
                "0" => { // There cannot be leading zero.
                    state.appendToLexeme("0");
                    return state.tokenize(DECIMAL);
                }
                () => { // Only '+' and '-' are invalid.
                    return generateLexicalError(state, "There must me DIGITs after '+'");
                }
                "n" => { // NAN token
                    return check tokensInSequence(state, "nan", NAN);
                }
                "i" => { // Infinity tokens
                    return check tokensInSequence(state, "inf", INFINITY);
                }
                _ => { // Remaining digits of the decimal numbers
                    if patternDecimal(<string:Char>state.peek()) {
                        return check iterate(state, scanDecimal, DECIMAL);
                    }
                    return generateLexicalError(state,
                        string `Invalid character '${state.peek(1) ?: "<end-of-line>"} after '${<string>state.peek()}'`);
                }
            }
        }
        "t" => { // Boolean true token
            return check tokensInSequence(state, "true", BOOLEAN);
        }
        "f" => { // Boolean false token
            return check tokensInSequence(state, "false", BOOLEAN);
        }
        "n" => { // NAN token
            return check tokensInSequence(state, "nan", NAN);
        }
        "i" => { // Positive infinity
            state.appendToLexeme("+");
            return check tokensInSequence(state, "inf", INFINITY);
        }
        "e"|"E" => { // Exponential tokens
            return state.tokenize(EXPONENTIAL);
        }
        "{" => { // Open inline table
            return state.tokenize(INLINE_TABLE_OPEN);
        }
        "}" => { // Close inline table
            return state.tokenize(INLINE_TABLE_CLOSE);
        }
    }

    // Check for values starting with an integer.
    if patternDecimal(<string:Char>state.peek()) {
        return check iterate(state, scanDecimal, DECIMAL);
    }

    return generateInvalidCharacterError(state, EXPRESSION_VALUE);
}
