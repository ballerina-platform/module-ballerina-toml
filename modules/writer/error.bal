# Represents an error caused by parser
type WritingError distinct error;

# Generates a Writing error
#
# + message - Error message
# + return - Constructed Writing error message
function generateError(string message) returns WritingError => error(message);
