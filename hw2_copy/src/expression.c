#include "expression.h"

#include "lib/code_gen.h"
#include "compiler_util.h"
#include "object.h"
#include "scope.h"

static inline bool object_sameRegister(const Object* a, const Object* b) {
    return a->type == OBJECT_TYPE_REGISTER && b->type == OBJECT_TYPE_REGISTER &&
        a->value.symbol->index == b->value.symbol->index;
}

static inline bool isExpressionOperationLegal(const ExpOp eop, const ObjectType targetType) {
    if (ExpOp_isArithmetic(eop) && !ObjectType_isNumber(targetType)) {
        if (eop == OP_ADD && targetType == OBJECT_TYPE_STR) {
            // String concatenation is legal
        } else {
            yyerrorf("運算符號『%s』不適用於『%s』之屬\n", expOp2str[eop], objectType2str[targetType]);
            return false;
        }
    }
    if (ExpOp_isBooleanOnly(eop) && targetType != OBJECT_TYPE_BOOL) {
        yyerrorf("運算符號『%s』不適用於『%s』之屬\n", expOp2str[eop], objectType2str[targetType]);
        return false;
    }
    if (eop == OP_MOD && !ObjectType_isInteger(targetType)) {
        yyerrorf("運算符號『%s』不適用於『%s』之屬\n", expOp2str[eop], objectType2str[targetType]);
        return false;
    }
    return true;
}

Object code_expression(const ExpOp eop, const bool opLeft, Object* a, Object* b,
                       const YYLTYPE* aLoc, const YYLTYPE* bLoc) {
    ObjectType aValueType = object_getValueType(a), bValueType = object_getValueType(b);

    const ObjectType targetType = object_getPromotedType(aValueType, bValueType);

    // Operand direction: opLeft true -> a is the left operand
    Object* left = opLeft ? a : b;
    Object* right = opLeft ? b : a;

    if (!isExpressionOperationLegal(eop, targetType))
        goto FAILED;

    // String concatenation (OP_ADD on strings)
    if (eop == OP_ADD && (aValueType == OBJECT_TYPE_STR || bValueType == OBJECT_TYPE_STR)) {
        if (aValueType != OBJECT_TYPE_STR || bValueType != OBJECT_TYPE_STR) {
            yyerrorf("字串相連，兩端皆須為言\n");
            goto FAILED;
        }
        char la[MAX_NAME_LENGTH], lb[MAX_NAME_LENGTH];
        Object rl = object_nameLiteralOrLoadReg(left, la, MAX_NAME_LENGTH);
        Object rr = object_nameLiteralOrLoadReg(right, lb, MAX_NAME_LENGTH);
        const SymbolData res = object_createRegisterSymbol(OBJECT_TYPE_STR);
        buffPrintln(&ctx->code, "%%reg%s = call ptr @wy_rt_str_concat(ptr %s, ptr %s)",
                    res.name, la, lb);
        const Object result = (Object){OBJECT_TYPE_REGISTER, .value.symbol = cloneStruct(SymbolData, &res)};
        compilerLog("exp %s %s %s -> %s\n", object_print(left), opDebugNames[eop],
                    object_print(right), object_print(&result));
        if (left->type == OBJECT_TYPE_SYMBOL) object_free(&rl);
        if (right->type == OBJECT_TYPE_SYMBOL) object_free(&rr);
        if (!object_sameRegister(a, b)) object_free(a);
        object_free(b);
        return result;
    }

    if (targetType == OBJECT_TYPE_UNDEFINED) {
        yyerrorf("運算兩端之屬不可通融\n");
        goto FAILED;
    }

    const ObjectType resultType = ExpOp_isOutputLogic(eop) ? OBJECT_TYPE_BOOL : targetType;

    char la[MAX_NAME_LENGTH], lb[MAX_NAME_LENGTH];
    Object rl = object_loadRegAndPromote(left, targetType, la, MAX_NAME_LENGTH);
    if (rl.type == OBJECT_TYPE_UNDEFINED) goto FAILED;
    Object rr = object_loadRegAndPromote(right, targetType, lb, MAX_NAME_LENGTH);
    if (rr.type == OBJECT_TYPE_UNDEFINED) {
        if (rl.type == OBJECT_TYPE_REGISTER && rl.value.symbol != left->value.symbol) object_free(&rl);
        goto FAILED;
    }

    const SymbolData res = object_createRegisterSymbol(resultType);
    const char* op = ObjectType_isFloat(targetType) ? opIRFloatNames[eop] : opIRIntNames[eop];
    buffPrintln(&ctx->code, "%%reg%s = %s %s %s, %s",
                res.name, op, objectType2llvmType[targetType], la, lb);

    const Object result = (Object){OBJECT_TYPE_REGISTER, .value.symbol = cloneStruct(SymbolData, &res)};
    compilerLog("exp %s %s %s -> %s\n", object_print(left), opDebugNames[eop],
                object_print(right), object_print(&result));

    // free the loaded/promoted operands if they are distinct registers
    if (rl.type == OBJECT_TYPE_REGISTER &&
        !(left->type == OBJECT_TYPE_REGISTER && rl.value.symbol == left->value.symbol))
        object_free(&rl);
    if (rr.type == OBJECT_TYPE_REGISTER &&
        !(right->type == OBJECT_TYPE_REGISTER && rr.value.symbol == right->value.symbol))
        object_free(&rr);

    if (!object_sameRegister(a, b)) object_free(a);
    object_free(b);
    return result;

FAILED:
    if (!object_sameRegister(a, b)) object_free(a);
    object_free(b);
    return (Object){.type = OBJECT_TYPE_UNDEFINED, .value = {}};
}

Object code_expressionMod(ExpOp dop, ExpOp eop, bool op_left, Object* a, Object* b,
                          YYLTYPE* dopLoc, YYLTYPE* eopLoc) {
    if (dop != OP_DIV) {
        yyerrorf("欲問所餘，必先用除\n");
        goto FAILED;
    }
    return code_expression(eop, op_left, a, b, dopLoc, eopLoc);

FAILED:
    if (!object_sameRegister(a, b)) object_free(a);
    object_free(b);
    return (Object){.type = OBJECT_TYPE_UNDEFINED, .value = {}};
}

Object code_expressionChain(ExpOp eop, bool op_left, Object* a, Object* b,
                            YYLTYPE* aLoc, YYLTYPE* bLoc) {
    return code_expression(eop, op_left, a, b, aLoc, bLoc);
}

Object code_expressionChainMod(ExpOp dop, ExpOp eop, bool op_left, Object* a, Object* b,
                               YYLTYPE* dopLoc, YYLTYPE* eopLoc) {
    if (dop != OP_DIV) {
        yyerrorf("欲問所餘，必先用除\n");
        object_free(a);
        object_free(b);
        return (Object){.type = OBJECT_TYPE_UNDEFINED, .value = {}};
    }
    return code_expressionChain(eop, op_left, a, b, dopLoc, eopLoc);
}
