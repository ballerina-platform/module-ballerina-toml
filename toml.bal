import ballerina/io;
import toml.writer;
import toml.parser;

# Configurations for writing a TOML document.
#
# + indentationPolicy - Number of whitespace for an indentation
# + allowDottedKeys - If set, dotted keys are used instead of standard tables
public type WriteConfig record {|
    int indentationPolicy = 2;
    boolean allowDottedKeys = true;
|};

# Configurations for reading a TOML document.
#
# + parseOffsetDateTime - If set, then offset date time is converted to Ballerina time:Utc
public type ReadConfig record {|
    boolean parseOffsetDateTime = true;
|};

# Parses a single line of a TOML string into a Ballerina map object.
#
# + tomlString - Single line of a TOML string  
# + config - Configuration for reading a TOML file
# + return - TOML map object is success. Else, returns an error
public function readString(string tomlString, ReadConfig config = {}) returns map<json>|error {
    string[] lines = [tomlString];
    return check parser:parse(lines, config.parseOffsetDateTime);
}

# Parses a TOML file into a Ballerina map object.
#
# + filePath - Path to the toml file
# + config - Configuration for reading a TOML file
# + return - TOML map object is success. Else, returns an error
public function read(string filePath, ReadConfig config = {}) returns map<json>|error {
    string[] lines = check io:fileReadLines(filePath);
    return check parser:parse(lines, config.parseOffsetDateTime);
}

# Writes the toml structure to a TOML document.
#
# + fileName - Path to the file  
# + tomlStructure - Structure to be written to the file
# + config - Configurations for writing a TOML file
# + return - An error on failure
public function write(string fileName, map<json> tomlStructure, WriteConfig config = {}) returns error? {
    check writer:openFile(fileName);
    string[] output = check writer:write(tomlStructure, config.indentationPolicy, config.allowDottedKeys);
    check io:fileWriteLines(fileName, output);
}
