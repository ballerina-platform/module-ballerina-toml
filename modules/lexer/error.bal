
# Represent an error caused by the lexical analyzer
public type LexicalError distinct error;

# Generate the template error message "Invalid character '${char}' for a '${token}'"
#
# + character - The character which the error occurred  
# + tokenName - Expected token name
# + return - Generated error message
function formatErrorMessage(string character, TOMLToken tokenName) returns string =>
    string `Invalid character '${character} for a '${tokenName}'`;

# Generates a Lexical Error.
#
# + state - Current lexer state  
# + message - Error message
# + return - Constructed Lexical Error message
function generateError(LexerState state, string message) returns LexicalError {
    string text = "Lexical Error at line "
                        + (state.lineNumber + 1).toString()
                        + " index "
                        + state.index.toString()
                        + ": "
                        + message
                        + ".";
    return error LexicalError(text);
}
