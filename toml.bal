import ballerina/io;
import toml.writer;
import toml.parser;

# Parses a Ballerina string of TOML content into a Ballerina map object.
#
# + tomlString - TOML content
# + config - Configuration for reading a TOML file
# + return - TOML map object on success. Else, returns an error
public function readString(string tomlString, *ReadConfig config) returns map<json>|Error {
    string[] lines = [tomlString];
    return check parser:parse(lines, config.parseOffsetDateTime);
}

# Parses a TOML file into a Ballerina map object.
#
# + filePath - Path to the toml file
# + config - Configuration for reading a TOML file
# + return - TOML map object on success. Else, returns an error
public function readFile(string filePath, *ReadConfig config) returns map<json>|Error {
    string[] lines = check io:fileReadLines(filePath);
    return check parser:parse(lines, config.parseOffsetDateTime);
}

# Converts the TOML structure to an array of strings.
#
# + tomlStructure - Structure to be written to the file
# + config - Configurations for writing a TOML file
# + return - TOML content on success. Else, an error on failure
public function writeString(map<json> tomlStructure, *WriteConfig config) returns string[]|Error
    => writer:write(tomlStructure, config.indentationPolicy, config.allowDottedKeys);

# Writes the TOML structure to a file.
#
# + filePath - Path to the file  
# + tomlStructure - Structure to be written to the file
# + config - Configurations for writing a TOML file
# + return - An error on failure
public function writeFile(string filePath, map<json> tomlStructure, *WriteConfig config) returns Error? {
    check openFile(filePath);
    string[] output = check writeString(tomlStructure, config);
    check io:fileWriteLines(filePath, output);
}
