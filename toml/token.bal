type Token record {|
    TOMLToken token;
    string value = "";
|};

enum TOMLToken {
    DUMMY,
    KEY_VALUE_SEPERATOR,
    DOT,
    UNQUOTED_KEY,
    BASIC_STRING,
    LITERAL_STRING,
    INTEGER,
    BOOLEAN,
    EOL,
    MULTI_STRING_DELIMETER,
    MULTI_STRING_ESCAPE,
    MULTI_STRING_CHARS
}

enum State {
    EXPRESSION_KEY,
    EXPRESSION_VALUE,
    MULTILINE_STRING
}