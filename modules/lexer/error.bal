
# Represent an error caused by the lexical analyzer
type LexicalError distinct error;

# Generate the template error message "Invalid character '${char}' for a '${token}'"
#
# + tokenName - Expected token name
# + return - Generated error message
function formatErrorMessage(TOMLToken tokenName) returns string {
    return "Invalid character '" + <string>peek() + "' for a '" + tokenName + "'";
}

# Generates a Lexical Error.
#
# + message - Error message  
# + return - Constructed Lexical Error message
function generateError(string message) returns LexicalError {
    string text = "Lexical Error at line "
                        + (lineNumber + 1).toString()
                        + " index "
                        + index.toString()
                        + ": "
                        + message
                        + ".";
    return error LexicalError(text);
}
