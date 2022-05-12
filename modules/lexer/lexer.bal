
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

    match state.context {
        EXPRESSION_KEY => {
            return contextExpressionKey(state);
        }
        EXPRESSION_VALUE => {
            return contextExpressionValue(state);
        }
        MULTILINE_BASIC_STRING|MULTILINE_ESCAPE => {
            return contextMultilineBasicString(state);
        }
        MULTILINE_LITERAL_STRING => {
            return contextMultilineLiteralString(state);
        }
        DATE_TIME => {
            return contextDateTime(state);
        }
    }

    return generateLexicalError(state, string `Invalid TOML context'`);
}
