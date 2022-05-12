import ballerina/regex;

enum RegexPatterns {
    UNQUOTED_STRING_PATTERN = "[a-zA-Z0-9\\-\\_]{1}",
    BASIC_STRING_PATTERN = "[\\x20\\x09\\x21\\x23-\\x5b\\x5d-\\x7e\\x80-\\ud7ff\\ue000-\\uffff]{1}",
    LITERAL_STRING_PATTERN = "[\\x20\\x09-\\x26\\x28-\\x7e\\x80-\\ud7ff\\ue000-\\uffff]{1}",
    ESCAPE_STRING_PATTERN = "[\\x22\\x5c\\x62\\x66\\x6e\\x72\\x74\\x75\\x55]{1}",
    DECIMAL_DIGIT_PATTERN = "[0-9]{1}",
    HEXADECIMAL_DIGIT_PATTERN = "[0-9a-fA-F]{1}",
    OCTAL_DIGIT_PATTERN = "[0-7]{1}",
    BINARY_DIGIT_PATTERN = "[0-1]{1}"
}

public enum Context {
    EXPRESSION_KEY,
    EXPRESSION_VALUE,
    DATE_TIME,
    MULTILINE_BASIC_STRING,
    MULTILINE_LITERAL_STRING,
    MULTILINE_ESCAPE
}

final readonly & map<string> escapedCharMap = {
    "b": "\u{08}",
    "t": "\t",
    "n": "\n",
    "f": "\u{0c}",
    "r": "\r",
    "\"": "\"",
    "\\": "\\"
};

# Generates a Token for the next immediate lexeme.
#
# + state - The lexer state for the next token
# + return - If success, returns a token, else returns a Lexical Error
public function scan(LexerState state) returns LexerState|LexicalError {

    // Generate EOL token 
    if (state.index >= state.line.length()) {
        return state.tokenize(EOL);
    }

    // Check for bare keys at the start of a line.
    if (state.context == EXPRESSION_KEY && regex:matches(<string>state.peek(), UNQUOTED_STRING_PATTERN)) {
        return check iterate(state, unquotedKey, UNQUOTED_KEY);
    }

    // Generate tokens related to multi line basic strings
    if (state.context == MULTILINE_BASIC_STRING || state.context == MULTILINE_ESCAPE) {
        if state.peek() == "\"" && state.peek(1) == "\"" && state.peek(2) == "\"" {
            state.forward(2);
            return state.tokenize(MULTILINE_BASIC_STRING_DELIMITER);
        }

        // Process the escape symbol
        if (state.peek() == "\\" && (state.peek(1) == () || state.peek(1) == " ")) {
            return state.tokenize(MULTILINE_BASIC_STRING_ESCAPE);
        }

        // Process multiline string regular characters
        if regex:matches(<string>state.peek(), BASIC_STRING_PATTERN)
            || state.peek() == "\\"
            || state.peek() == "'"
            || state.peek() == "\"" {
            return check iterate(state, multilineBasicString, MULTILINE_BASIC_STRING_LINE);
        }
    }

    // Generate tokens related to multi-line literal string
    if state.context == MULTILINE_LITERAL_STRING {
        if state.peek() == "'" && state.peek(1) == "'" && state.peek(2) == "'" {
            state.forward(2);
            return state.tokenize(MULTILINE_LITERAL_STRING_DELIMITER);
        }
        if regex:matches(<string>state.peek(), LITERAL_STRING_PATTERN)
            || state.peek() == "'"
            || state.peek() == "\"" {
            return iterate(state, multilineLiteralString, MULTILINE_LITERAL_STRING_LINE);
        }
    }

    // Process tokens related to date time
    if (state.context == DATE_TIME) {
        match state.peek() {
            ":" => { // Time separator
                return state.tokenize(COLON);
            }
            "-" => { // Date separator or negative offset
                return state.tokenize(MINUS);
            }
            "t"|"T"|" " => { // Time delimiter
                return state.tokenize(TIME_DELIMITER);
            }
            "+" => { // Positive offset
                return state.tokenize(PLUS);
            }
            "Z" => { // Zulu offset
                return state.tokenize(ZULU);
            }
        }

        // Digits for date time
        if (regex:matches(<string>state.peek(), DECIMAL_DIGIT_PATTERN)) {
            return check iterate(state, digit(DECIMAL_DIGIT_PATTERN), DECIMAL);
        }
    }

    match state.peek() {
        " "|"\t" => { // Whitespace
            state.forward();
            return check scan(state);
        }
        "#" => { // Comments
            state.forward(-1);
            return state.tokenize(EOL);
        }
        "=" => { // Key value separator
            return state.tokenize(KEY_VALUE_SEPARATOR);
        }
        "[" => { // Array values and standard tables
            if (state.peek(1) == "[" && state.context == EXPRESSION_KEY) { // Array tables
                state.forward();
                return state.tokenize(ARRAY_TABLE_OPEN);
            }
            return state.tokenize(OPEN_BRACKET);
        }
        "]" => { // Array values and standard tables
            if (state.peek(1) == "]" && state.context == EXPRESSION_KEY) { // Array tables
                state.forward();
                return state.tokenize(ARRAY_TABLE_CLOSE);
            }
            return state.tokenize(CLOSE_BRACKET);
        }
        "," => {
            return state.tokenize(SEPARATOR);
        }
        "\"" => { // Basic strings

            // Multi-line basic strings
            if (state.peek(1) == "\"" && state.peek(2) == "\"") {
                state.forward(2);
                return state.tokenize(MULTILINE_BASIC_STRING_DELIMITER);
            }

            state.forward();
            return check iterate(state, basicString, BASIC_STRING, "Expected '\"' at the end of the basic string");
        }
        "'" => { // Literal strings

            // Multi-line literal string
            if (state.peek(1) == "'" && state.peek(2) == "'") {
                state.forward(2);
                return state.tokenize(MULTILINE_LITERAL_STRING_DELIMITER);
            }

            state.forward();
            return check iterate(state, literalString, LITERAL_STRING, "Expected ''' at the end of the literal string");
        }
        "." => { // Dotted keys
            return state.tokenize(DOT);
        }
        "0" => {
            string? peekValue = state.peek(1);
            if (peekValue == ()) {
                state.appendToLexeme("0");
                return state.tokenize(DECIMAL);
            }

            if (regex:matches(<string>peekValue, DECIMAL_DIGIT_PATTERN)) || <string>peekValue == "e" {
                return check iterate(state, digit(DECIMAL_DIGIT_PATTERN), DECIMAL);
            }

            match peekValue {
                "x" => { // Hexadecimal numbers
                    state.forward(2);
                    return check iterate(state, digit(HEXADECIMAL_DIGIT_PATTERN), HEXADECIMAL);
                }
                "o" => { // Octal numbers
                    state.forward(2);
                    return check iterate(state, digit(OCTAL_DIGIT_PATTERN), OCTAL);
                }
                "b" => { // Binary numbers
                    state.forward(2);
                    return check iterate(state, digit(BINARY_DIGIT_PATTERN), BINARY);
                }
                " "|"#"|"."|","|"]" => { // Decimal numbers
                    state.appendToLexeme("0");
                    return state.tokenize(DECIMAL);
                }
                _ => {
                    return generateError(state, string `Invalid character '${peekValue}' after '0'`);
                }
            }
        }
        "+"|"-" => { // Decimal numbers
            match state.peek(1) {
                "0" => { // There cannot be leading zero.
                    state.appendToLexeme(<string>state.peek() + "0");
                    state.forward();
                    return state.tokenize(DECIMAL);
                }
                () => { // Only '+' and '-' are invalid.
                    return generateError(state, "There must me digits after '+'");
                }
                "n" => { // NAN token
                    state.appendToLexeme(<string>state.peek());
                    state.forward();
                    return check tokensInSequence(state, "nan", NAN);
                }
                "i" => { // Infinity tokens
                    state.appendToLexeme(<string>state.peek());
                    state.forward();
                    return check tokensInSequence(state, "inf", INFINITY);
                }
                _ => { // Remaining digits of the decimal numbers
                    state.appendToLexeme(<string>state.peek());
                    state.forward();
                    return check iterate(state, digit(DECIMAL_DIGIT_PATTERN), DECIMAL);
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
        "i" => {
            state.appendToLexeme("+");
            return check tokensInSequence(state, "inf", INFINITY);
        }
        "e"|"E" => { // Exponential tokens
            return state.tokenize(EXPONENTIAL);
        }
        "{" => { // Inline table
            return state.tokenize(INLINE_TABLE_OPEN);
        }
        "}" => { // Inline table
            return state.tokenize(INLINE_TABLE_CLOSE);
        }
    }

    // Check for values starting with an integer.
    if ((state.context == EXPRESSION_VALUE) && regex:matches(<string>state.peek(), DECIMAL_DIGIT_PATTERN)) {
        return check iterate(state, digit(DECIMAL_DIGIT_PATTERN), DECIMAL);
    }

    return generateError(state, string `Invalid character '${<string>state.peek()}'`);
}
