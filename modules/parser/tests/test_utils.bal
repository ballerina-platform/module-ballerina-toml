import ballerina/test;
import toml.lexer;
import ballerina/io;

const ORIGIN_FILE_PATH = "modules/parser/tests/resources/";

# Assert if the key and value is properly set in the TOML object.
#
# + toml - TOML object to be asserted  
# + key - Expected key  
# + value - Expected value of the key  
function assertKey(map<anydata> toml, string key, string value) {
    resetParams();
    test:assertTrue(toml.hasKey(key));
    test:assertEquals(<string>toml[key], value);
}

# Assert if an parsing error is generated during the parsing
#
# + text - If isFile is set, file path else TOML string.
# + isFile - If set, reads the TOML file. default = false.  
# + isLexical - If set, checks for Lexical errors. Else, checks for Parsing errors.
function assertParsingError(string text, boolean isFile = false, boolean isLexical = false) {
    resetParams();
    anydata|error toml = isFile ? readFile(ORIGIN_FILE_PATH + text + ".toml") : read(text);
    if (isLexical) {
        test:assertTrue(toml is lexer:LexicalError);
    } else {
        test:assertTrue(toml is ParsingError);
    }
}

function resetParams() {
    lines = [];
    numLines = 0;
    lineIndex = -1;
    currentToken = {token: lexer:DUMMY};
    lexemeBuffer = "";
    tomlObject = {};
    currentStructure = {};
    keyStack = [];
    definedTableKeys = [];
    tokenConsumed = false;
    bufferedKey = "";
    isArrayTable = false;
    currentTableKey = "";

    lexer:line = "";
    lexer:state = lexer:EXPRESSION_KEY;
    lexer:index = 0;
    lexer:lineNumber = 0;
}

# Assertions to validate the values of the TOML object.  
class AssertKey {
    private map<anydata> toml;
    private map<anydata>? innerData;
    private string[] stack;

    # Init the AssertKey class.
    #
    # + text - If isFile is set, file path else TOML string  
    # + isFile - If set, reads the TOML file. default = false.    
    function init(string text, boolean isFile = false) returns error? {
        resetParams();
        self.toml = isFile ? <map<anydata>>(check readFile(ORIGIN_FILE_PATH + text + ".toml")) : <map<anydata>>(check read(text));
        self.innerData = ();
        self.stack = [];
    }

    # Assert the key and value of the TOML object.
    # Recall this method to check multiple values of the same TOML object.
    #
    # + tomlKey - Expected key of the TOML object  
    # + tomlValue - Expected value of the key. If no value is provided, value won't be checked.
    # + return - AssertKey object to reapply methods.  
    function hasKey(string tomlKey, anydata tomlValue = ()) returns AssertKey {
        map<anydata> assertedMap = self.innerData ?: self.toml;

        test:assertTrue(assertedMap.hasKey(tomlKey));

        if (tomlValue != ()) {
            test:assertEquals(<anydata>assertedMap[tomlKey], tomlValue);
        }
        return self;
    }

    # Dive into an inner key and assert the value.
    #
    # + tomlKey - Inner key
    # + return - AssertKey object to reapply methods.    
    function dive(string tomlKey) returns AssertKey {

        // If the current node is the root
        if (self.innerData == ()) {
            self.innerData = <map<anydata>?>self.toml[tomlKey];
        }

        // If the current node is nested
        else {
            self.innerData = <map<anydata?>>self.innerData[tomlKey];
        }

        self.stack.push(tomlKey);
        return self;
    }

    # Hop out from the current inner key.
    #
    # + return - Return Value Description  
    function hop() returns AssertKey {

        // If the parent node is the root
        if (self.stack.length() == 1) {
            self.innerData = ();
            _ = self.stack.pop();
            return self;
        }

        // Set the innerData to its parent map
        map<anydata>? targetedObject;
        foreach int i in 0 ... self.stack.length() - 2 {
            targetedObject = <map<anydata>?>self.toml[self.stack[i]];
            _ = self.stack.remove(i);
        }
        self.innerData = targetedObject;

        return self;
    }

    # Invoke this after finish writing the assertions.  
    function close() {
        return;
    }
}

# Parses a single line of a TOML string into a Ballerina map object.
#
# + tomlString - Single line of a TOML string
# + return - TOML map object is success. Else, returns an error
function read(string tomlString) returns map<anydata>|error {
    string[] lines = [tomlString];
    return check parse(lines);
}

# Parses a TOML file into a Ballerina map object.
#
# + filePath - Path to the toml file
# + return - TOML map object is success. Else, returns an error
function readFile(string filePath) returns map<anydata>|error {
    string[] lines = check io:fileReadLines(filePath);
    return check parse(lines);
}
