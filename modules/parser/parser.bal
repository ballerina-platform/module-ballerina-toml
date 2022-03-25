import toml.lexer;

# Properties for the TOML lines
string[] lines = [];
int numLines = 0;
int lineIndex = -1;

# Current token
lexer:Token currentToken = {token: lexer:DUMMY};

# Hold the lexemes until the final value is generated
string lexemeBuffer = "";

# Output TOML object
map<anydata> tomlObject = {};

# Current map structure the parser is working on
map<anydata> currentStructure = {};

# Key stack to the current structure
string[] keyStack = [];

# Already defined table keys
string[] definedTableKeys = [];

# If the token for a next grammar rule has been buffered to the current token
boolean tokenConsumed = false;

# Buffers the key in the full format
string bufferedKey = "";

# If set, the parser is currently working on an array table
boolean isArrayTable = false;

# The current table key name. If empty, then current table is the root.
string currentTableKey = "";

# Generates a map object for the TOML document.
# Considers the predictions for the 'expression', 'table', and 'array table'.
#
# + inputLines - TOML lines to be parsed.
# + return - If success, map object for the TOML document.
# Else, a lexical or a parsing error.
public function parse(string[] inputLines) returns map<anydata>|lexer:LexicalError|ParsingError {
    lines = inputLines;
    numLines = inputLines.length();

    // Iterating each line of the document.
    while lineIndex < numLines - 1 {
        check initLexer("Cannot open the TOML document");
        check checkToken();
        lexer:state = lexer:EXPRESSION_KEY;

        match currentToken.token {
            lexer:UNQUOTED_KEY|lexer:BASIC_STRING|lexer:LITERAL_STRING => { // Process a key value
                bufferedKey = currentToken.value;
                currentStructure = check keyValue(currentStructure.clone());
                lexer:state = lexer:EXPRESSION_KEY;
            }
            lexer:OPEN_BRACKET => { // Process a standard tale.
                // Add the previous table to the TOML object
                tomlObject = check buildTOMLObject(tomlObject.clone());
                isArrayTable = false;

                check checkToken([lexer:UNQUOTED_KEY, lexer:BASIC_STRING, lexer:LITERAL_STRING]);
                check standardTable(tomlObject.clone());
            }
            lexer:ARRAY_TABLE_OPEN => { // Process an array table
                // Add the previous structure to the array in the TOML object.
                tomlObject = check buildTOMLObject(tomlObject.clone());
                isArrayTable = true;

                check checkToken([lexer:UNQUOTED_KEY, lexer:BASIC_STRING, lexer:LITERAL_STRING]);
                check arrayTable(tomlObject.clone());
            }
        }

        // Comments and new lines are ignored.
        // However, other expressions cannot have additional tokens in their line.
        if (currentToken.token != lexer:EOL) {
            check checkToken(lexer:EOL);
        }
    }

    // Return the TOML object
    tomlObject = check buildTOMLObject(tomlObject.clone());
    return tomlObject;
}