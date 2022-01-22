import ballerina/io;

# Parses a single line of a TOML string into a Ballerina map object.
#
# + tomlString - Single line of a TOML string
# + return - TOML map object is sucess. Else, returns an error
public function read(string tomlString) returns map<any>|error {
    string[] lines = [tomlString];
    Parser parser = new Parser(lines);
    return parser.parse();
}

# Parses a TOML file into a Ballerina map object.
#
# + filePath - Path to the toml file
# + return - TOML map object is sucess. Else, returns an error
public function readFile(string filePath) returns map<any>|error {
    string[] lines = check io:fileReadLines(filePath);
    Parser parser = new Parser(lines);
    return parser.parse();
}