//
// Created by Wavjaby on 2026/3/27.
//

#include "while.h"

#include <WJCL/string/wjcl_string.h>

#include "lib/code_gen.h"
#include "../compiler_util.h"

bool code_whileLoopStart() {
    compilerLog("> (while loop)\n");

    const ScopeData* scope = scope_pushType(SCOPE_WHILE_LOOP);

    buffPrintln(&ctx->code, "");
    buffPrintln(&ctx->code, "br label %%loop%d.body", scope->id);
    buffPrintlnS(&ctx->code, "loop%d.body:", scope->id);

    return false;
}

bool code_whileLoopEnd(Object* obj) {
    const ScopeData* scope = scope_peek();

    buffPrintln(&ctx->code, "br label %%loop%d.body", scope->id);
    buffPrintlnS(&ctx->code, "loop%d.exit:", scope->id);
    buffPrintln(&ctx->code, "");

    scope_dump();
    compilerLog("< (while loop end)\n");
    return false;
}

bool code_break() {
    // TODO: 跳出最近的迴圈
    //
    // 實作前先閱讀以下內容：
    //   1. scope.c 的 scope_findNearestLoop()：
    //      回傳什麼？loopScope->id < 0 代表什麼情況？
    //   2. 上方 code_whileLoopEnd 與 for.c 的 code_forLoopEnd：
    //      loop exit label 的命名規則是什麼？
    //   3. compiler_util.h 裡其他 compilerLog 呼叫的格式
    //
    // 讀懂後實作（約 4 行）：
    //   - 取得最近的迴圈 scope
    //   - 不在迴圈內時報錯並 return true
    //   - compilerLog 輸出 break 訊息
    //   - 輸出 br 跳到 exit label
    return false;
}
