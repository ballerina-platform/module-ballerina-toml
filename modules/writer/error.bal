# Represents an error caused when writing a TOML file.
public type WritingError distinct error;

# Generates a Writing error
#
# + message - Error message
# + return - Constructed Writing error message
function generateError(string message) returns WritingError => error(message);
