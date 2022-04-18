import ballerina/regex;

enum RegexPatterns {
    UNQUOTED_STRING_PATTERN = "[a-zA-Z0-9\\-\\_]{1}",
    BASIC_STRING_PATTERN = "[\\x20\\x09\\x21\\x23-\\x5b\\x5d-\\x7e\\x80-\\xd7ff\\xe000-\\xffff]{1}",
    LITERAL_STRING_PATTERN = "[\\x20\\x09-\\x26\\x28-\\x7e\\x80-\\xd7ff\\xe000-\\xffff]{1}",
    ESCAPE_STRING_PATTERN = "[\\x22\\x5c\\x62\\x66\\x6e\\x72\\x74\\x75\\x55]{1}",
    DECIMAL_DIGIT_PATTERN = "[0-9]{1}",
    HEXADECIMAL_DIGIT_PATTERN = "[0-9a-fA-F]{1}",
    OCTAL_DIGIT_PATTERN = "[0-7]{1}",
    BINARY_DIGIT_PATTERN = "[0-1]{1}"
}

public enum State {
    EXPRESSION_KEY,
    EXPRESSION_VALUE,
    DATE_TIME,
    MULTILINE_BSTRING,
    MULITLINE_LSTRING,
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
# + return - If success, returns a token, else returns a Lexical Error 
public function scan() returns Token|LexicalError {

    // Generate EOL token 
    if (index >= line.length()) {
        return {token: EOL};
    }

    // Check for bare keys at the start of a line.
    if (state == EXPRESSION_KEY && regex:matches(line[index], UNQUOTED_STRING_PATTERN)) {
        return check iterate(unquotedKey, UNQUOTED_KEY);
    }

    // Generate tokens related to multi line basic strings
    if (state == MULTILINE_BSTRING || state == MULTILINE_ESCAPE) {
        // Process the escape symbol
        if (line[index] == "\\") {
            return generateToken(MULTI_BSTRING_ESCAPE);
        }

        // Process multiline string regular characters
        if (regex:matches(line[index], BASIC_STRING_PATTERN)) {
            return check iterate(multilineBasicString, MULTI_BSTRING_CHARS);
        }

    }

    // Generate tokens related to multi-line literal string
    if (state == MULITLINE_LSTRING && regex:matches(line[index], LITERAL_STRING_PATTERN)) {
        return iterate(multilineLiteralString, MULTI_LSTRING_CHARS);
    }

    // Process tokens related to date time
    if (state == DATE_TIME) {
        match peek() {
            ":" => { // Time separator
                return generateToken(COLON);
            }
            "-" => { // Date separator or negative offset
                return generateToken(MINUS);
            }
            "t"|"T"|" " => { // Time delimiter
                return generateToken(TIME_DELIMITER);
            }
            "+" => { // Positive offset
                return generateToken(PLUS);
            }
            "Z" => { // Zulu offset
                return generateToken(ZULU);
            }
        }

        // Digits for date time
        if (regex:matches(line[index], DECIMAL_DIGIT_PATTERN)) {
            return check iterate(digit(DECIMAL_DIGIT_PATTERN), DECIMAL);
        }
    }

    match peek() {
        " "|"\t" => { // Whitespace
            index += 1;
            return check scan();
        }
        "#" => { // Comments
            return generateToken(EOL);
        }
        "=" => { // Key value separator
            return generateToken(KEY_VALUE_SEPARATOR);
        }
        "[" => { // Array values and standard tables
            if (peek(1) == "[" && state == EXPRESSION_KEY) { // Array tables
                index += 1;
                return generateToken(ARRAY_TABLE_OPEN);
            }
            return generateToken(OPEN_BRACKET);
        }
        "]" => { // Array values and standard tables
            if (peek(1) == "]" && state == EXPRESSION_KEY) { // Array tables
                index += 1;
                return generateToken(ARRAY_TABLE_CLOSE);
            }
            return generateToken(CLOSE_BRACKET);
        }
        "," => {
            return generateToken(SEPARATOR);
        }
        "\"" => { // Basic strings

            // Multi-line basic strings
            if (peek(1) == "\"" && peek(2) == "\"") {
                index += 2;
                return generateToken(MULTI_BSTRING_DELIMITER);
            }

            index += 1;
            return check iterate(basicString, BASIC_STRING, "Expected '\"' at the end of the basic string");
        }
        "'" => { // Literal strings

            // Multi-line literal string
            if (peek(1) == "'" && peek(2) == "'") {
                index += 2;
                return generateToken(MULTI_LSTRING_DELIMITER);
            }

            index += 1;
            return check iterate(literalString, LITERAL_STRING, "Expected ''' at the end of the literal string");
        }
        "." => { // Dotted keys
            return generateToken(DOT);
        }
        "0" => {
            string? peekValue = peek(1);
            if (peekValue == ()) {
                lexeme = "0";
                return generateToken(DECIMAL);
            }

            if (regex:matches(<string>peekValue, DECIMAL_DIGIT_PATTERN)) {
                return check iterate(digit(DECIMAL_DIGIT_PATTERN), DECIMAL);
            }

            match peekValue {
                "x" => { // Hexadecimal numbers
                    index += 2;
                    return check iterate(digit(HEXADECIMAL_DIGIT_PATTERN), HEXADECIMAL);
                }
                "o" => { // Octal numbers
                    index += 2;
                    return check iterate(digit(OCTAL_DIGIT_PATTERN), OCTAL);
                }
                "b" => { // Binary numbers
                    index += 2;
                    return check iterate(digit(BINARY_DIGIT_PATTERN), BINARY);
                }
                " "|"#"|"."|","|"]" => { // Decimal numbers
                    lexeme = "0";
                    return generateToken(DECIMAL);
                }
                _ => {
                    return generateError("Invalid character '" + line[index + 1] + "' after '0'");
                }
            }
        }
        "+"|"-" => { // Decimal numbers
            match peek(1) {
                "0" => { // There cannot be leading zero.
                    lexeme = line[index] + "0";
                    index += 1;
                    return generateToken(DECIMAL);
                }
                () => { // Only '+' and '-' are invalid.
                    return generateError("There must me digits after '+'");
                }
                "n" => { // NAN token
                    lexeme = line[index];
                    index += 1;
                    return check tokensInSequence("nan", NAN);
                }
                "i" => { // Infinity tokens
                    lexeme = line[index];
                    index += 1;
                    return check tokensInSequence("inf", INFINITY);
                }
                _ => { // Remaining digits of the decimal numbers
                    lexeme = line[index];
                    index += 1;
                    return check iterate(digit(DECIMAL_DIGIT_PATTERN), DECIMAL);
                }
            }
        }
        "t" => { // Boolean true token
            return check tokensInSequence("true", BOOLEAN);
        }
        "f" => { // Boolean false token
            return check tokensInSequence("false", BOOLEAN);
        }
        "n" => { // NAN token
            return check tokensInSequence("nan", NAN);
        }
        "i" => {
            lexeme = "+";
            return check tokensInSequence("inf", INFINITY);
        }
        "e"|"E" => { // Exponential tokens
            return generateToken(EXPONENTIAL);
        }
        "{" => { // Inline table
            return generateToken(INLINE_TABLE_OPEN);
        }
        "}" => { // Inline table
            return generateToken(INLINE_TABLE_CLOSE);
        }
    }

    // Check for values starting with an integer.
    if ((state == EXPRESSION_VALUE) && regex:matches(line[index], DECIMAL_DIGIT_PATTERN)) {
        return check iterate(digit(DECIMAL_DIGIT_PATTERN), DECIMAL);
    }

    return generateError("Invalid character '" + line[index] + "'");
}
