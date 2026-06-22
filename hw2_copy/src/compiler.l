/* Definition section */
%option yymore
%{
    #include <stdlib.h>
    #include <string.h>
    #include <utf8.c/utf8.h>
    #include "lib/chinese_number.h"
    #include "compiler_util.h"
    #include "object.h"
    #include "value_data.h"
    #include "control/function_info.h"
    #include "y.tab.h"

    /* Set the parser location (yylloc) for the current token, mirroring the
       column formula used by PRINT_TOKEN (1-based column = first_column + 1). */
    #define SET_LLOC() do { \
        yylloc.first_line = yytokenLine; \
        yylloc.first_column = yycolumnUtf8 - yylengUtf8; \
        yylloc.last_line = yylineno; \
        yylloc.last_column = yycolumnUtf8; \
    } while (0)

    #define YY_NO_UNPUT
    #define YY_NO_INPUT

    int yycolumnUtf8, yylengUtf8, yytokenLine = 1, lastLineEndColumnUtf8 = 0;
    utf8_string yytextUtf8;

    static inline void updateNewline() {
        // TODO: Update the line number and column number
        lastLineEndColumnUtf8 = yycolumnUtf8 - yylengUtf8;
        yylloc.first_line = yylloc.last_line = yylineno;
        yylloc.first_column = yylloc.last_column = lastLineEndColumnUtf8;
        yycolumnUtf8 = 0;
        yylengUtf8 = 0;
        yytokenLine = yylineno;
    }

    /* Calculates UTF-8 character length to update the column counters */
    static inline void processUtf8Char() {
        yytextUtf8 = make_utf8_string(yytext);
        if (yytextUtf8.str) {
            // TODO: Calculate the column number
            // every time flex matches a token, count how many UTF-8 char are in yytext, then update the column tracker
            yylengUtf8 = utf8_char_count(yytextUtf8);
            yycolumnUtf8 += yylengUtf8;
        }
    }

    /* Appends the next matched token and reverting the column counters to the start of the string */
    static inline void yymore_utf8() {
        yymore();
        if (yytextUtf8.str) {
            // TODO: Reset column
            yycolumnUtf8 -= yylengUtf8;
        }
    }

    #define YY_USER_ACTION \
        processUtf8Char();

    #define PRINT_TOKEN(format, ...) printf("%d:%d: " format "\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1, __VA_ARGS__)

    /* Extracts string from the current token by specified padding */
    char* trimStringToken(int paddLen) {
        static char cache[4096];
        // TODO: Slice the string and copy

        int len = yyleng - paddLen * 2;
        if (len >= (int) sizeof(cache)) {
            len = (int) sizeof(cache) - 1;
        }
        strncpy(cache, yytext + paddLen, len);
        cache[len] = '\0';

        return cache;
    }
%}

/* Define regular expression label */
digit ("零"|"〇"|"一"|"二"|"三"|"四"|"五"|"六"|"七"|"八"|"九"|"兩"|"壹"|"貳"|"參"|"肆"|"伍"|"陸"|"柒"|"捌"|"玖")
num_unit ("十"|"百"|"千"|"萬"|"億"|"兆"|"京"|"垓"|"秭"|"穰"|"溝"|"澗"|"正"|"載"|"極"|"拾"|"佰"|"仟")
frac_unit ("分"|"釐"|"毫"|"絲"|"忽"|"微"|"纖"|"沙"|"塵"|"埃"|"渺"|"漠")
number_char ("負"|"·"|"又"|{digit}|{num_unit}|{frac_unit})
COMMENT ("注曰"|"疏曰"|"批曰")
HERE_ARE ("今有"|"吾有")
HERE_IS_A "有"
SAID "曰"
NAME_IT "名之曰"
VAR_TYPE ("長"|"數"|"言"|"爻"|"元"|"列")
VAR_TYPE_FUNC "術"

UTF8_BOM "\357\273\277"

ASCII   [\x00-\x7f]
U       [\x80-\xbf]

B2      [\xC2-\xDF]{U}
B3_1    \xE0[\xA0-\xBF]{U}
B3_2    [\xE1-\xEC]{U}{U}
B3_3    \xED[\x80-\x9F]{U}
B3_4    [\xEE-\xEF]{U}{U}
B4_1    \xF0[\x90-\xBF]{U}{U}
B4_2    [\xF1-\xF3]{U}{U}{U}
B4_3    \xF4[\x80-\x8F]{U}{U}

/* ALL UTF-8 https://www.w3.org/2005/03/23-lex-U#charRange
  {ASCII}
| ([\xC2-\xDF] {U})
| ( \xE0       [\xA0-\xBF]{U})
| ([\xE1-\xEC] {U}{U})
| ( \xED       [\x80-\x9F]{U})
| ([\xEE-\xEF] {U}{U})
| ( \xF0       [\x90-\xBF]{U}{U})
| ([\xF1-\xF3] {U}{U}{U})
| ( \xF4       [\x80-\x8F]{U}{U})
*/

ALL_UTF8 {ASCII}|{B2}|{B3_1}|{B3_2}|{B3_3}|{B3_4}|{B4_1}|{B4_2}|{B4_3}

B3_2_EXCLUDE_QUO ([\xE1-\xE2]{U}{U})|(\xE3\x80[\x80-\x8C\x8E-\xBF])|(\xE3[\x81-\xBF]{U})|([\xE4-\xEC]{U}{U})

EXCLUDE_QUO [\x20-\x7E]|{B2}|{B3_1}|{B3_2_EXCLUDE_QUO}|{B3_3}|{B3_4}|{B4_1}|{B4_2}|{B4_3}

%option yylineno
%x IDENT_CON STR_CON


 /* Rules section */
%%
{UTF8_BOM}  { updateNewline(); /* Skip UTF-8 BOM */ }

"「「"        { BEGIN(STR_CON); yymore_utf8(); }
<STR_CON>"」"/"」」" { yymore_utf8(); }
<STR_CON>"」」"    { BEGIN(INITIAL); SET_LLOC(); yylval.s_var = strdup(trimStringToken(6)); return STR_LIT; }
<STR_CON>\r?\n    { yymore_utf8(); }
<STR_CON>{EXCLUDE_QUO}+    { yymore_utf8(); }
<STR_CON>"」"    { yymore_utf8(); }

"「"        { BEGIN(IDENT_CON); yymore_utf8(); }
<IDENT_CON>"」"    { BEGIN(INITIAL); SET_LLOC(); yylval.s_var = strdup(trimStringToken(3)); return IDENT; }
<IDENT_CON>\r?\n    { yymore_utf8(); }
<IDENT_CON>{EXCLUDE_QUO}+    { yymore_utf8(); }

{COMMENT}   { SET_LLOC(); return COMMENT; }
{NAME_IT}   { SET_LLOC(); return NAME_IT; }
{HERE_ARE}  { SET_LLOC(); return HERE_ARE; }
{HERE_IS_A} { SET_LLOC(); return HERE_IS_A; }

"欲行是術" { SET_LLOC(); return TO_PERFORM_FUNC; }
"必先得" { SET_LLOC(); return REQUIRE_ARGS; }
"乃行是術曰"|"乃是術曰" { SET_LLOC(); return FUNC_BEGIN; }
"是謂" { SET_LLOC(); return FUNC_END_FOR; }
"之術也" { SET_LLOC(); return FUNC_END; }
"以施" { SET_LLOC(); return TO_CALL; }
"施" { SET_LLOC(); return CALL; }

"中有陽乎" { SET_LLOC(); yylval.exp_op = OP_OR; return EXP_LOGIC; }
"中無陰乎" { SET_LLOC(); yylval.exp_op = OP_AN; return EXP_LOGIC; }
"不大於" { SET_LLOC(); yylval.exp_op = OP_LE; return EXP_LOGIC; }
"不小於" { SET_LLOC(); yylval.exp_op = OP_GE; return EXP_LOGIC; }
"不等於" { SET_LLOC(); yylval.exp_op = OP_NE; return EXP_LOGIC; }
"大於" { SET_LLOC(); yylval.exp_op = OP_GT; return EXP_LOGIC; }
"小於" { SET_LLOC(); yylval.exp_op = OP_LT; return EXP_LOGIC; }
"等於" { SET_LLOC(); yylval.exp_op = OP_EQ; return EXP_LOGIC; }

"若非" { SET_LLOC(); return ELSE; }
"或若" { SET_LLOC(); return ELSE_IF; }
"若" { SET_LLOC(); return IF; }
"恆為是" { SET_LLOC(); return WHILE_TRUE; }
"為是" { SET_LLOC(); return FOR; }
"遍" { SET_LLOC(); return TIMES; }
"乃止" { SET_LLOC(); return BREAK; }
"乃得""矣"? { SET_LLOC(); return RETURN; }

"所餘幾何" { SET_LLOC(); yylval.exp_op = OP_MOD; return EXP_MATH_OP; }
"加" { SET_LLOC(); yylval.exp_op = OP_ADD; return EXP_MATH; }
"減" { SET_LLOC(); yylval.exp_op = OP_SUB; return EXP_MATH; }
"乘" { SET_LLOC(); yylval.exp_op = OP_MUL; return EXP_MATH; }
"除" { SET_LLOC(); yylval.exp_op = OP_DIV; return EXP_MATH; }
"於" { SET_LLOC(); yylval.exp_left = false; return EXP_PREPOSITION; }
"以" { SET_LLOC(); yylval.exp_left = true; return EXP_PREPOSITION; }

"書之" { SET_LLOC(); return PRINT; }
"之長" { SET_LLOC(); return LENGTH; }
"昔之" { SET_LLOC(); return PAST; }
"是矣" { SET_LLOC(); return IS_THUS; }
"之" { SET_LLOC(); return INDEX; }
"者" { SET_LLOC(); return TOPIC; }
"今" { SET_LLOC(); return SET; }
"其" { SET_LLOC(); return ITS; }
"充" { SET_LLOC(); return PUSH; }
"夫" { SET_LLOC(); return THOSE; }
"取" { SET_LLOC(); return TAKE; }
"曰" { SET_LLOC(); return SAID; }

"云云"|"也"|"矣" { SET_LLOC(); return END; }

{VAR_TYPE_FUNC} { SET_LLOC(); yylval.var_type = OBJECT_TYPE_FUNC; return VAR_TYPE_FUNC; }
{VAR_TYPE}      {
    SET_LLOC();
    if (strcmp(yytext, "長") == 0) yylval.var_type = OBJECT_TYPE_I64;
    else if (strcmp(yytext, "數") == 0) yylval.var_type = OBJECT_TYPE_NUM;
    else if (strcmp(yytext, "言") == 0) yylval.var_type = OBJECT_TYPE_STR;
    else if (strcmp(yytext, "爻") == 0) yylval.var_type = OBJECT_TYPE_BOOL;
    else if (strcmp(yytext, "元") == 0) yylval.var_type = OBJECT_TYPE_I32;
    else if (strcmp(yytext, "列") == 0) yylval.var_type = OBJECT_TYPE_ARRAY;
    return VAR_TYPE;
}
"陽" { SET_LLOC(); yylval.b_var = true; return BOOL_LIT; }
"陰" { SET_LLOC(); yylval.b_var = false; return BOOL_LIT; }

{number_char}+ {
    SET_LLOC();
    ScientificNotation sci;
    if (!chineseToArabic(yytext, &sci)) {
        yylval.n_var = sci;
        return NUMBER_LIT;
    }
}

[ \t]+      {}
\r?\n       { updateNewline(); }
("。"|"，") {
    yylloc.first_line = yylloc.last_line = yytokenLine;
    yylloc.first_column = yycolumnUtf8 - yylengUtf8;
    yylloc.last_column = yycolumnUtf8;
}

<<EOF>>     { yyterminate(); }

{ALL_UTF8} { }
. { }
%%
/*  C Code section */
int yywrap(void) {
    return 1;
}
