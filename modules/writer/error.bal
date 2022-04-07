# Represents an error caused by parser
type WritingError distinct error;

# Generates a Writing error
#
# + message - Error message
# + return - Constructed Parsing Error message  
function generateError(string message) returns WritingError {
    string text = "Writing Error: "
                        + message
                        + ".";
    return error WritingError(text);
}
