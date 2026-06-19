//
// Created by WavJaby on 2026/03/26.
//

#include "for.h"

#include <WJCL/string/wjcl_string.h>

#include "lib/code_gen.h"
#include "compiler_util.h"

bool code_forLoop(Object* src) {
    if (src->type == OBJECT_TYPE_UNDEFINED)
        goto FAILED;

    compilerLog("> (for loop, count: %s)\n", object_print(src));

    // TODO: 實作 for 迴圈 IR 生成
    //   1. 推入新 scope，取得計數運算元字串（需升級到 I32）
    //   2. 依 src->type 設定 scope->u.forLoop.symbol（記錄計數器型別）
    //   3. 輸出 entry → header → phi → icmp → 條件跳轉 → body label 的完整 IR 序列
    //   完整 block 結構與各 label 命名規則見 LLVM_IR_CHEATSHEET.md §phi 節點（for 迴圈）

FAILED:
    object_free(src);
    return true;
}

bool code_forLoopEnd(Object* obj) {
    // TODO: 輸出迴圈 update/exit IR，彈出 scope
    //   輸出 update label → 計數器遞增 → 跳回 header → exit label
    //   IR 指令與 label 命名規則見 LLVM_IR_CHEATSHEET.md §phi 節點（for 迴圈）
    return false;
}
