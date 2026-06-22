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

    static ValueData* activeValueData = NULL;
    static ValueData tempValueData = {0};
    static Object activeFunction = {.type = OBJECT_TYPE_UNDEFINED};
    static ObjectType activeParamType = OBJECT_TYPE_UNDEFINED;
    static Object activePushTarget = {.type = OBJECT_TYPE_UNDEFINED};
    static Object activeCallFunction = {.type = OBJECT_TYPE_UNDEFINED};
    static FuncCallInfo* activeFuncCall = NULL;
    static bool activeValueDataConsumed = false;

    static ScientificNotation oneCount(void) {
        return (ScientificNotation){.type = I32, .fraction = 1, .fractionLen = 1, .exp = 0};
    }

    static ValueData valueDataFromObject(Object* obj, const YYLTYPE* loc) {
        ValueData vd;
        ScientificNotation one = oneCount();
        object_ValueDataListCreate(object_getValueType(obj), &one, &vd);
        object_ValueDataListAdd(&vd, obj, loc);
        return vd;
    }

    static bool addValue(ValueData* vd, Object* obj, const YYLTYPE* loc) {
        return object_ValueDataListAdd(vd, obj, loc);
    }

    static ValueData emptyValueData(void) {
        ValueData vd;
        linkedList_init(&vd.valueList);
        vd.valueType = OBJECT_TYPE_UNDEFINED;
        vd.count = 0;
        return vd;
    }

    static void defineActiveValue(char* name) {
        if (activeValueData)
            code_createVariable(activeValueData, name);
        else
            free(name);
    }

    static void printObjectValue(Object* obj, const YYLTYPE* loc) {
        ValueData vd = valueDataFromObject(obj, loc);
        code_stdoutPrint(&vd, true);
        object_ValueDataListFree(&vd);
    }

    static void rememberFunctionResult(ValueData* vd) {
        Object* result = object_ValueDataListPop(vd);
        if (result) {
            ctx->last_result = *result;
            free(result);
        }
        object_ValueDataListFree(vd);
    }
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
%token PRINT TO_CALL CALL
%nonassoc TAKE
%precedence VALUE_INPUT_DONE
%token RETURN BREAK
%token TO_PERFORM_FUNC REQUIRE_ARGS FUNC_BEGIN FUNC_END_FOR FUNC_END
%token IF ELSE_IF ELSE WHILE_TRUE FOR TIMES
%token TOPIC PAST SET ITS IS_THUS
%token PUSH THOSE LENGTH
%token VAR_TYPE_FUNC
%token END

%token <n_var> NUMBER_LIT
%token <b_var> BOOL_LIT
%token <var_type> VAR_TYPE
%token <s_var> STR_LIT IDENT
%token <exp_op> EXP_MATH EXP_MATH_OP EXP_LOGIC
%token <exp_left> EXP_PREPOSITION

/* %left 範例 — ValueStmt 實作時視衝突補充 */
%left INDEX

/* Nonterminal with return — 實作子規則時依需要自行補充 */
%type <obj_val> ValueStmt LitOrVarStmt ValueLiteralStmt VariableStmt
%type <obj_val> ArithmeticStmt ExpressionStmt ExpressionChainStmt ExpressionNextStmt
%type <val_data> CreateValueDataListStmt FunctionCallStmt PrefixCallStmt

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
        { free($2); }
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
    : HERE_ARE NUMBER_LIT VAR_TYPE_FUNC NAME_IT IDENT
        { activeFunction = func_define(&$2, $5); }
      TO_PERFORM_FUNC FunctionArgsStmt FUNC_BEGIN
        { func_defineBody(); }
      BodyListStmt FUNC_END_FOR IDENT FUNC_END
        {
            func_defineBodyEnd(&activeFunction, $13);
            free($13);
            activeFunction = (Object){.type = OBJECT_TYPE_UNDEFINED};
        }
;

FunctionArgsStmt
    :
    | REQUIRE_ARGS NUMBER_LIT VAR_TYPE
        { activeParamType = $3; }
      FunctionArgListStmt
;

FunctionArgListStmt
    : SAID IDENT
        { func_defineAddParam(activeParamType, $2); }
    | FunctionArgListStmt SAID IDENT
        { func_defineAddParam(activeParamType, $3); }
;

/* Condition and Operation */
/* TODO: 控制流（FOR / WHILE / IF-ELSEIF-ELSE）
 * 三種分支，每種都有對應的開始與結束 IR 呼叫。
 * 函式：code_forLoop/End, code_whileLoopStart/End, code_if, code_elseIfLabel, code_elseIf, code_else, code_ifEnd
 * 注意：else-if 與 else 皆為可選；IF 結構由三個子規則組成
 */
ConditionStmt
    : WHILE_TRUE
        { code_whileLoopStart(); }
      BodyListStmt END
        { code_whileLoopEnd(NULL); }
    | FOR ValueStmt TIMES
        { code_forLoop(&$2); }
      BodyListStmt END
        { code_forLoopEnd(NULL); }
    | IF ExpressionStmt TOPIC
        { code_if(&$2); }
      BodyListStmt ElseIfList ElseStmt END
        { code_ifEnd(); }
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
    : CreateValueDataListStmt
        {
            activeValueData = &$1;
            activeValueDataConsumed = false;
        }
      ValueInputList CreateValueTail
        {
            if (!activeValueDataConsumed)
                object_ValueDataListFree(&$1);
            activeValueData = NULL;
            activeValueDataConsumed = false;
        }
    | ExpressionChainStmt
        {
            ctx->last_result = $1;
        }
    | ExpressionChainStmt
        {
            ScientificNotation one = oneCount();
            object_ValueDataListCreate(object_getValueType(&$1), &one, &tempValueData);
            object_ValueDataListAdd(&tempValueData, &$1, &@1);
            object_ValueDataListAddDefaults(&tempValueData, &@1);
            activeValueData = &tempValueData;
        }
      VariableDefineStmt
        {
            object_ValueDataListFree(&tempValueData);
            activeValueData = NULL;
        }
    | ExpressionChainStmt PRINT
        { printObjectValue(&$1, &@1); }
    | THOSE ValueStmt
        {
            ScientificNotation one = oneCount();
            object_ValueDataListCreate(object_getValueType(&$2), &one, &tempValueData);
            object_ValueDataListAdd(&tempValueData, &$2, &@2);
            object_ValueDataListAddDefaults(&tempValueData, &@1);
            activeValueData = &tempValueData;
        }
      VariableDefineStmt
        {
            object_ValueDataListFree(&tempValueData);
            activeValueData = NULL;
        }
    | THOSE ValueStmt PRINT
        { printObjectValue(&$2, &@2); }
    | AssignmentStmt
    | BREAK
        { code_break(); }
    | RETURN ValueStmt
        {
            ValueData vd = valueDataFromObject(&$2, &@2);
            code_returnValue(&vd);
        }
    | FunctionCallStmt
        { rememberFunctionResult(&$1); }
    | FunctionCallStmt PRINT
        {
            code_stdoutPrint(&$1, true);
            object_ValueDataListFree(&$1);
        }
    | FunctionCallStmt
        {
            activeValueData = &$1;
            object_ValueDataListAddDefaults(activeValueData, &@1);
        }
      VariableDefineStmt
        {
            object_ValueDataListFree(&$1);
            activeValueData = NULL;
        }
    | PUSH VariableStmt
        { activePushTarget = $2; }
      PushValueList
        {
            object_free(&activePushTarget);
            activePushTarget = (Object){.type = OBJECT_TYPE_UNDEFINED};
        }
;

CreateValueTail
    :
        { object_ValueDataListAddDefaults(activeValueData, &yylloc); }
      VariableDefineStmt
    | PRINT
        { code_stdoutPrint(activeValueData, true); }
    | RETURN
        {
            code_returnValue(activeValueData);
            activeValueDataConsumed = true;
        }
    | TAKE NUMBER_LIT TO_CALL VariableStmt
        { func_takeAndCall(&$2, &$4, activeValueData, &@3); }
      RETURN
        {
            code_returnValue(activeValueData);
            activeValueDataConsumed = true;
        }
;

CreateValueDataListStmt
    : HERE_ARE NUMBER_LIT VAR_TYPE
        { object_ValueDataListCreate($3, &$2, &$$); }
    | HERE_IS_A VAR_TYPE
        { object_ValueDataListCreate($2, NULL, &$$); }
    | HERE_IS_A VAR_TYPE ValueLiteralStmt
        {
            object_ValueDataListCreate($2, NULL, &$$);
            addValue(&$$, &$3, &@3);
        }
    | HERE_IS_A VAR_TYPE VariableStmt
        {
            object_ValueDataListCreate($2, NULL, &$$);
            addValue(&$$, &$3, &@3);
        }
;

ValueInputList
    :
    | ValueInputList LitOrVarStmt
        {
            if (activeValueData) addValue(activeValueData, &$2, &@2);
        }
;

VariableDefineStmt
    : NAME_IT IDENT
        { defineActiveValue($2); }
    | VariableDefineStmt SAID IDENT
        { defineActiveValue($3); }
;

AssignmentStmt
    : PAST VariableStmt TOPIC SET ITS IS_THUS
        {
            YYLTYPE savedLoc = yylloc;
            Object src = ctx->last_result;
            yylloc = @2;
            code_assign(&$2, &src);
            yylloc = savedLoc;
        }
    | PAST VariableStmt TOPIC SET ValueStmt IS_THUS
        { code_assign(&$2, &$5); }
;

PushValueList
    : EXP_PREPOSITION ValueStmt
        {
            YYLTYPE savedLoc = yylloc;
            yylloc = @2;
            code_arrayPush(&activePushTarget, &$2, &@2);
            yylloc = savedLoc;
        }
    | PushValueList EXP_PREPOSITION ValueStmt
        {
            YYLTYPE savedLoc = yylloc;
            yylloc = @3;
            code_arrayPush(&activePushTarget, &$3, &@3);
            yylloc = savedLoc;
        }
;

FunctionCallStmt
    : PrefixCallStmt
        { $$ = $1; }
;

PrefixCallStmt
    : CALL VariableStmt
        {
            activeCallFunction = $2;
            activeFuncCall = func_callInit(&activeCallFunction);
        }
      FunctionCallArgList
        {
            $$ = (ValueData){0};
            if (activeFuncCall) {
                func_call(activeFuncCall, &activeCallFunction, &$$, &@1);
                activeFuncCall = NULL;
            } else {
                $$ = emptyValueData();
            }
            object_free(&activeCallFunction);
            activeCallFunction = (Object){.type = OBJECT_TYPE_UNDEFINED};
        }
;

FunctionCallArgList
    :
    | FunctionCallArgList EXP_PREPOSITION ValueStmt
        {
            if (activeFuncCall)
                func_callArgAdd(activeFuncCall, &$3, &@3);
        }
;

ElseIfList
    :
    | ElseIfList ELSE_IF
        { code_elseIfLabel(); }
      ExpressionStmt TOPIC
        {
            code_elseIf(&$4);
        }
      BodyListStmt
;

ElseStmt
    :
    | ELSE
        { code_else(); }
      BodyListStmt
;

/* Expressions */
/* TODO: 運算式（四則/邏輯，鏈式）
 * 函式：code_expression/Mod, code_expressionChain/Mod
 * 注意：鏈式第一項用 code_expression，後續用 code_expressionChain；需更新 ctx->last_result
 */
ExpressionChainStmt
    : ArithmeticStmt
        { $$ = $1; }
    | ExpressionChainStmt ExpressionNextStmt
        { $$ = $2; }
    | ExpressionChainStmt TAKE NUMBER_LIT TO_CALL VariableStmt
        {
            ValueData vd = valueDataFromObject(&$1, &@1);
            func_takeAndCall(&$3, &$5, &vd, &@4);
            Object* result = object_ValueDataListPop(&vd);
            $$ = result ? *result : (Object){.type = OBJECT_TYPE_UNDEFINED};
            free(result);
            object_ValueDataListFree(&vd);
            ctx->last_result = $$;
        }
;

ArithmeticStmt
    : EXP_MATH ValueStmt EXP_PREPOSITION ValueStmt
        {
            $$ = code_expression($1, $3, &$2, &$4, &@2, &@4);
            ctx->last_result = $$;
        }
    | EXP_MATH ValueStmt EXP_PREPOSITION ValueStmt EXP_MATH_OP
        {
            $$ = code_expressionMod($1, $5, $3, &$2, &$4, &@1, &@5);
            ctx->last_result = $$;
        }
;

ExpressionStmt
    : ArithmeticStmt
        { $$ = $1; }
    | ValueStmt EXP_LOGIC ValueStmt
        {
            $$ = code_expression($2, true, &$1, &$3, &@1, &@3);
            ctx->last_result = $$;
        }
    | THOSE ValueStmt ValueStmt EXP_LOGIC
        {
            $$ = code_expression($4, true, &$2, &$3, &@2, &@3);
            ctx->last_result = $$;
        }
;

ExpressionNextStmt
    : ArithmeticStmt
        { $$ = $1; }
;

/* Value */
/* TODO: 值、字面值、變數查找
 * 函式：object_createStr/Number/Bool, scope_findSymbol, object_getIndex, code_getLength
 * 注意：ITS 取 ctx->last_result；陣列索引與長度為 ValueStmt 的延伸形式
 */
ValueStmt
    : ValueLiteralStmt
        { $$ = $1; }
    | VariableStmt
        { $$ = $1; }
    | ITS
        { $$ = ctx->last_result; }
    | ValueStmt INDEX ValueStmt
        {
            YYLTYPE savedLoc = yylloc;
            yylloc = @3;
            $$ = object_getIndex(&$1, &$3, &@1, &@3);
            yylloc = savedLoc;
            object_free(&$1);
            object_free(&$3);
        }
    | ValueStmt LENGTH
        { $$ = code_getLength(&$1, &@2); }
;

LitOrVarStmt
    : SAID ValueLiteralStmt
        { $$ = $2; }
    | SAID VariableStmt
        { $$ = $2; }
    | SAID ExpressionChainStmt %prec VALUE_INPUT_DONE
        { $$ = $2; }
;

ValueLiteralStmt
    : NUMBER_LIT
        { $$ = object_createNumber(&$1); }
    | BOOL_LIT
        { $$ = object_createBool($1); }
    | STR_LIT
        { $$ = object_createStr($1); }
;

VariableStmt
    : IDENT
        {
            $$ = scope_findSymbol($1);
            free($1);
        }
;

%%

#include "compiler.h"
