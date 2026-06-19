//
// Created by Wavjaby on 2026/3/26.
//

#include "if.h"

#include <WJCL/string/wjcl_string.h>

#include "lib/code_gen.h"
#include "compiler_util.h"

inline bool code_if(Object* src) {
    compilerLog("> (if)\n");
    // TODO: 實作 if 分支 IR 生成
    //   1. 取得條件運算元字串
    //   2. 推入新 scope，初始化 elseifCount 與 containsElse
    //   3. 輸出條件跳轉 IR，依 scope->id 命名 true/false 兩個 label
    //   4. 輸出 true label（用 buffPrintlnS）
    //   5. 清理 Object，return false
    //   if/else block 結構見 LLVM_IR_CHEATSHEET.md §if / elseif / else 結構
    return false;
}

inline bool code_elseIfLabel() {
    // TODO: 結束前一個 if/elseif 分支，準備進入下一個 elseif
    //   1. 輸出無條件跳轉到 endif label
    //   2. 輸出前一段的 false label（第一次是 if.false，之後是 elseif<n>.false）
    //   3. 更新 elseifCount
    //   label 命名規則見 LLVM_IR_CHEATSHEET.md §if / elseif / else 結構
    return false;
}

inline bool code_elseIf(Object* src) {
    compilerLog("> (else if)\n");
    // TODO: 彈出當前 scope，推入同 id 的新 scope，繼續累積 elseifCount
    //   1. 從舊 scope 取出 scopeId 與 elseifCount，scope_dump()
    //   2. scope_pushId 推入同 id 的新 scope，elseifCount + 1
    //   3. 取得條件運算元字串，輸出條件跳轉 IR（true/false label 含 elseifCount）
    //   4. 輸出 elseif true label，清理 Object，return false
    return false;
}

inline bool code_else() {
    // TODO: 切換 scope 並輸出 else 的進入標籤
    //   1. 取出當前 scope 資訊後 scope_dump()
    //   2. 輸出無條件跳轉到 endif，再輸出前一段的 false label
    //   3. scope_pushId 推入同 id 的新 scope，設 containsElse=true
    //   label 命名規則同 code_elseIfLabel，見 LLVM_IR_CHEATSHEET.md
    return false;
}

inline bool code_ifEnd() {
    // TODO: 根據 scope 狀態輸出 if 結尾 IR，彈出 scope
    //   三種情況各自需要不同的 label 組合（見 LLVM_IR_CHEATSHEET.md §if 結構圖）：
    //   - 有 else：本體結束後跳 endif，endif label 作為匯合點
    //   - 無 else 無 elseif：本體結束後直接落到 false label
    //   - 有 elseif 無 else：最後一個 elseif 的 false label + endif 匯合點
    //   最後 scope_dump()
    return false;
}
