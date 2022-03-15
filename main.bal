import ballerina/io;

# Parses a single line of a TOML string into a Ballerina map object.
#
# + tomlString - Single line of a TOML string  
# + outputType - Type of the output structure. The default is map<anydata>
# + return - TOML map object is success. Else, returns an error
public function read(string tomlString, typedesc<anydata>? outputType = ()) returns anydata|error {
    string[] lines = [tomlString];
    Parser parser = new Parser(lines);
    map<anydata> output = check parser.parse();
    return outputType == () ? output : output.cloneWithType(outputType);
}

# Parses a TOML file into a Ballerina map object.
#
# + filePath - Path to the toml file
# + outputType - Type of the output structure. The default is map<anydata>
# + return - TOML map object is success. Else, returns an error
public function readFile(string filePath, typedesc<anydata>? outputType = ()) returns anydata|error {
    string[] lines = check io:fileReadLines(filePath);
    Parser parser = new Parser(lines);
    map<anydata> output = check parser.parse();
    return outputType == () ? output : output.cloneWithType(outputType);
}

# Writes the toml structure to a TOML document.
#
# + fileName - Path to the file  
# + tomlStructure - Structure to be written to the file.  
# + indentationPolicy - Number of whitespace for an indentation. Default = 2  
# + allowDottedKeys - If set, dotted keys are used instead of standard tables. Default = true
# + return - An error on failure
public function write(string fileName, map<anydata> tomlStructure, int indentationPolicy = 2, boolean allowDottedKeys = true) returns error? {
    Writer writer = new Writer(indentationPolicy, allowDottedKeys);
    check writer.openFile(fileName);
    string[] output = check writer.write(tomlStructure);
    check io:fileWriteLines(fileName, output);
}

type Cricketer record {
    string name;
    Stats TestStats;
    string nationality;
};

type Stats record {|
    int hundreds;
    int fifties;
    int runs;
|};

public function main() returns error? {
    Cricketer dimuthRecord = <Cricketer>(check readFile("dimuth_prev.toml", Cricketer));
    dimuthRecord.TestStats.hundreds += 1;
    dimuthRecord.TestStats.runs += 107;
    check write("dimuth_after.toml", dimuthRecord);
}
