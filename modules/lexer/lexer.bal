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
    if state.index >= state.line.length() {
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
