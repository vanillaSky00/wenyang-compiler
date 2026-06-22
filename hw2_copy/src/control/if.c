//
// Created by Wavjaby on 2026/3/26.
//

#include "if.h"

#include <WJCL/string/wjcl_string.h>

#include "lib/code_gen.h"
#include "compiler_util.h"

inline bool code_if(Object* src) {
    compilerLog("> (if)\n");

    ScopeData* scope = scope_pushType(SCOPE_IF_STMT);
    scope->u.ifInfo.elseifCount = 0;
    scope->u.ifInfo.containsElse = false;
    const int id = scope->id;

    char cond[MAX_NAME_LENGTH];
    Object regCond = object_loadRegAndPromote(src, OBJECT_TYPE_BOOL, cond, MAX_NAME_LENGTH);
    if (regCond.type == OBJECT_TYPE_UNDEFINED) goto FAILED;

    buffPrintln(&ctx->code, "br i1 %s, label %%if%d.true, label %%if%d.false", cond, id, id);
    buffPrintlnS(&ctx->code, "if%d.true:", id);

    if (src->type == OBJECT_TYPE_SYMBOL) object_free(&regCond);
    object_free(src);
    return false;
FAILED:
    object_free(src);
    return true;
}

static void emit_prev_false_label(int id, int elseifCount) {
    if (elseifCount == 0)
        buffPrintlnS(&ctx->code, "if%d.false:", id);
    else
        buffPrintlnS(&ctx->code, "if%d.elseif%d.false:", id, elseifCount - 1);
}

inline bool code_elseIfLabel() {
    const ScopeData* scope = scope_peek();
    const int id = scope->id;
    const int n = scope->u.ifInfo.elseifCount;

    buffPrintln(&ctx->code, "br label %%if%d.endif", id);
    emit_prev_false_label(id, n);
    return false;
}

inline bool code_elseIf(Object* src) {
    ScopeData* old = scope_peek();
    const int id = old->id;
    const int n = old->u.ifInfo.elseifCount;
    const bool hadElse = old->u.ifInfo.containsElse;

    scope_dump();
    compilerLog("> (else if)\n");

    ScopeData* scope = scope_pushId(SCOPE_IF_STMT, id);
    scope->u.ifInfo.elseifCount = n + 1;
    scope->u.ifInfo.containsElse = hadElse;

    char cond[MAX_NAME_LENGTH];
    Object regCond = object_loadRegAndPromote(src, OBJECT_TYPE_BOOL, cond, MAX_NAME_LENGTH);
    if (regCond.type == OBJECT_TYPE_UNDEFINED) goto FAILED;

    buffPrintln(&ctx->code, "br i1 %s, label %%if%d.elseif%d.true, label %%if%d.elseif%d.false",
                cond, id, n, id, n);
    buffPrintlnS(&ctx->code, "if%d.elseif%d.true:", id, n);

    if (src->type == OBJECT_TYPE_SYMBOL) object_free(&regCond);
    object_free(src);
    return false;
FAILED:
    object_free(src);
    return true;
}

inline bool code_else() {
    ScopeData* old = scope_peek();
    const int id = old->id;
    const int n = old->u.ifInfo.elseifCount;

    scope_dump();
    compilerLog("> (else)\n");

    buffPrintln(&ctx->code, "br label %%if%d.endif", id);
    emit_prev_false_label(id, n);

    ScopeData* scope = scope_pushId(SCOPE_IF_STMT, id);
    scope->u.ifInfo.elseifCount = n;
    scope->u.ifInfo.containsElse = true;
    return false;
}

inline bool code_ifEnd() {
    const ScopeData* scope = scope_peek();
    const int id = scope->id;
    const int n = scope->u.ifInfo.elseifCount;
    const bool hasElse = scope->u.ifInfo.containsElse;

    if (hasElse) {
        buffPrintln(&ctx->code, "br label %%if%d.endif", id);
        buffPrintlnS(&ctx->code, "if%d.endif:", id);
    } else if (n == 0) {
        // plain if: fall through to the false label
        buffPrintln(&ctx->code, "br label %%if%d.false", id);
        buffPrintlnS(&ctx->code, "if%d.false:", id);
    } else {
        // elseif(s) but no else: close last elseif true, then merge at endif
        buffPrintln(&ctx->code, "br label %%if%d.endif", id);
        emit_prev_false_label(id, n);
        buffPrintln(&ctx->code, "br label %%if%d.endif", id);
        buffPrintlnS(&ctx->code, "if%d.endif:", id);
    }

    scope_dump();
    compilerLog("< (if end)\n");
    return false;
}
