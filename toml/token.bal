type Token record {|
    TOMLToken token;
    string value = "";
|};

enum TOMLToken {
    EXPRESSION,
    WHITESPACE,
    QUOTED_KEY,
    UNQUOTED_KEY,
    KEY_VALUE_SEPERATOR,
    BASIC_STRING,
    LITERAL_STRING,
    EOL
}