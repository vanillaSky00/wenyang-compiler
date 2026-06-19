/* Definition section */
%code requires {
    # define YYLTYPE_IS_DECLARED 1
    # define YYLTYPE_IS_TRIVIAL 1
}

%{
    #include "compiler_util.h"
    #include "main.h"
    #include "expression.h"
    #include "value_data.h"
    #include "scope.h"
    #include "control/for.h"
    #include "control/if.h"
    #include "control/while.h"
    #include "control/function.h"
%}

%define parse.error custom
%locations

/* Variable or self-defined structure */
%union {
    ObjectType var_type;

    bool b_var;
    ScientificNotation n_var;
    char *s_var;

    Object obj_val;
    ValueData val_data;

    FuncCallInfo* func_call;

    bool exp_left;
    ExpOp exp_op;
}
/* Token — quick start 最小集合，實作各規則時依需要自行補充 */
%token COMMENT
%token HERE_ARE HERE_IS_A SAID NAME_IT
%token PRINT TO_CALL
%token RETURN

%token <n_var> NUMBER_LIT
%token <b_var> BOOL_LIT
%token <var_type> VAR_TYPE
%token <s_var> STR_LIT IDENT

/* %left 範例 — ValueStmt 實作時視衝突補充 */
%left INDEX

/* Nonterminal with return — 實作子規則時依需要自行補充 */
%type <val_data> CreateValueDataListStmt

/* For Return — 用於已提供的 ReturnStmt，詳見 YACC_CHEATSHEET.md §優先序宣告 */
%nonassoc LOWER_THAN_EXPR
%nonassoc RETURN

/* Yacc will start at this nonterminal */
%start Program
%%
/* Grammar section */

/* Scope */
Program
    : GlobalScopeStmt
;

GlobalScopeStmt
    : BodyListStmt
;

/* Scope Body */
BodyListStmt
    : BodyListStmt BodyStmt
    |
;

BodyStmt
    : COMMENT STR_LIT
    | OperationStmt
    | ConditionStmt
    | FunctionStmt
;

/* Function */
/* TODO: 函式定義
 * 登錄函式符號、推入 context/scope、逐一登錄參數、結束後彈出。
 * 函式：func_define, func_defineBody, func_defineBodyEnd, func_defineAddParam
 * 注意：參數型別需透過 $<var_type>0 跨規則傳遞；參數列與參數名稱各自是一層規則
 */
FunctionStmt
    :
;

FunctionArgsStmt
    :
;

FunctionArgListStmt
    :
;

/* Condition and Operation */
/* TODO: 控制流（FOR / WHILE / IF-ELSEIF-ELSE）
 * 三種分支，每種都有對應的開始與結束 IR 呼叫。
 * 函式：code_forLoop/End, code_whileLoopStart/End, code_if, code_elseIfLabel, code_elseIf, code_else, code_ifEnd
 * 注意：else-if 與 else 皆為可選；IF 結構由三個子規則組成
 */
ConditionStmt
    :
;

/* TODO: 各種操作語句
 * 涵蓋變數宣告、命名、賦值、函式呼叫、陣列 push、印出、return。
 * 函式：object_ValueDataList*, code_createVariable, code_assign, code_stdoutPrint,
 *       code_arrayPush, code_return, code_returnValue,
 *       func_callInit, func_callArgAdd, func_call, func_takeAndCall
 * 注意：函式呼叫分前置（施）與後置（以施）兩種；mid-rule action 用 $0 傳遞中間值；
 *       呼叫結果後可接命名、return、print 或省略
 */
OperationStmt
    :
;

CreateValueDataListStmt
    :
;

VariableDefineStmt
    :
;

/* Expressions */
/* TODO: 運算式（四則/邏輯，鏈式）
 * 函式：code_expression/Mod, code_expressionChain/Mod
 * 注意：鏈式第一項用 code_expression，後續用 code_expressionChain；需更新 ctx->last_result
 */
ExpressionChainStmt
    :
;

ExpressionStmt
    :
;

ExpressionNextStmt
    :
;

ValueLiteralOrLastStmt
    :
;

/* Value */
/* TODO: 值、字面值、變數查找
 * 函式：object_createStr/Number/Bool, scope_findSymbol, object_getIndex, code_getLength
 * 注意：ITS 取 ctx->last_result；陣列索引與長度為 ValueStmt 的延伸形式
 */
ValueStmt
    :
;

LitOrVarStmt
    :
;

ValueLiteralStmt
    :
;

VariableStmt
    :
;

%%

#include "compiler.h"
