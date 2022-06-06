import ballerina/io;
import toml.writer;
import toml.parser;

# Parses a single line of a TOML string into a Ballerina map object.
#
# + tomlString - Single line of a TOML string  
# + config - Configuration for reading a TOML file
# + return - TOML map object is success. Else, returns an error
public function readString(string tomlString, *ReadConfig config) returns map<json>|Error {
    string[] lines = [tomlString];
    return check parser:parse(lines, config.parseOffsetDateTime);
}

# Parses a TOML file into a Ballerina map object.
#
# + filePath - Path to the toml file
# + config - Configuration for reading a TOML file
# + return - TOML map object is success. Else, returns an error
public function read(string filePath, *ReadConfig config) returns map<json>|Error {
    string[] lines = check io:fileReadLines(filePath);
    return check parser:parse(lines, config.parseOffsetDateTime);
}

# Converts the toml structure to a array of strings.
#
# + tomlStructure - Structure to be written to the file
# + config - Configurations for writing a TOML file
# + return - An error on failure
public function writeString(map<json> tomlStructure, *WriteConfig config) returns string[]|Error
    => writer:write(tomlStructure, config.indentationPolicy, config.allowDottedKeys);

# Writes the toml structure to a TOML document.
#
# + filePath - Path to the file  
# + tomlStructure - Structure to be written to the file
# + config - Configurations for writing a TOML file
# + return - An error on failure
public function write(string filePath, map<json> tomlStructure, *WriteConfig config) returns Error? {
    check openFile(filePath);
    string[] output = check writeString(tomlStructure, config);
    check io:fileWriteLines(filePath, output);
}
