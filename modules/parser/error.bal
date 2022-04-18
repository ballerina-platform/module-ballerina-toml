import toml.lexer;

# Represents an error caused by parser
type ParsingError distinct error;

# Generates a Parsing Error Error.
#
# + state - Current parser state 
# + message - Error message
# + return - Constructed Parsing Error message
function generateError(ParserState state, string message) returns ParsingError {
    string text = "Parsing Error at line "
                        + state.lexerState.lineNumber.toString()
                        + " index "
                        + state.lexerState.index.toString()
                        + ": "
                        + message
                        + ".";
    return error ParsingError(text);
}

//TODO: Decouple the error messages
# Generate a standard error message based on the type.
#
# 1 - Expected ${expectedTokens} after ${beforeToken}, but found ${actualToken}
#
# 2 - Duplicate key exists for ${value}
#
# + messageType - Number of the template message
# + expectedTokens - Predicted tokens  
# + beforeToken - Token before the predicted token  
# + value - Any value name. Commonly used to indicate keys.
# + return - If success, the generated error message. Else, an error message.
function formatErrorMessage(
            int messageType,
            lexer:TOMLToken|lexer:TOMLToken[] expectedTokens = lexer:DUMMY,
            lexer:TOMLToken beforeToken = lexer:DUMMY,
            string value = "") returns string|ParsingError {

    match messageType {
        1 => { // Expected ${expectedTokens} after ${beforeToken}, but found ${actualToken}
            if (expectedTokens == lexer:DUMMY || beforeToken == lexer:DUMMY) {
                return error("Token parameters cannot be null for this template error message.");
            }
            string expectedTokensMessage;
            if (expectedTokens is lexer:TOMLToken[]) { // If multiple tokens
                string tempMessage = expectedTokens.reduce(function(string message, lexer:TOMLToken token) returns string {
                    return message + " '" + token + "' or";
                }, "");
                expectedTokensMessage = tempMessage.substring(0, tempMessage.length() - 3);
            } else { // If a single token
                expectedTokensMessage = " '" + expectedTokens + "'";
            }
            return "Expected" + expectedTokensMessage + " after '" + beforeToken + "', but found '${currentToken}'";
        }

        2 => { // Duplicate key exists for ${value}
            if (value.length() == 0) {
                return error("Value cannot be empty for this template message");
            }
            return "Duplicate key exists for '" + value + "'";
        }

        _ => {
            return error("Invalid message type number. Enter a value between 1-2");
        }
    }
}
