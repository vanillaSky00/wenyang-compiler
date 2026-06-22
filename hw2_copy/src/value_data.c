//
// Created by WavJaby on 2026/3/2.
//

#include "value_data.h"

#include <string.h>

#include "compiler_util.h"

// linkedList_init / linkedList_addp / linkedList_deleteNode / linkedList_freeA / cloneStruct 用法：見 README.md §工具函式速查
bool object_ValueDataListCreate(ObjectType valueType, const ScientificNotation* count, ValueData* valueData) {
    linkedList_init(&valueData->valueList);
    valueData->valueType = valueType;
    valueData->count = (count != NULL) ? sciToInt32(count) : 1;
    if (valueData->count <= 0) {
        yyerrorf("立名之數當為正，今得『%d』\n", valueData->count);
        return true;
    }
    return false;
}

bool object_ValueDataListAdd(ValueData* valueData, const Object* obj, const YYLTYPE* tokenLoc) {
    if ((int32_t)valueData->valueList.length >= valueData->count) {
        yyerrorlf("所賦之值過多，逾立名之數\n", tokenLoc);
        return true;
    }

    Object* clone = cloneStruct(Object, obj);
    if (obj->type == OBJECT_TYPE_STR && obj->value.str)
        clone->value.str = strdup(obj->value.str);
    linkedList_addp(&valueData->valueList, 0, clone); // freeFlag=0：不自動 free，由 freeA(free) 統一釋放
    return false;
}

bool object_ValueDataListAddDefaults(ValueData* valueData, const YYLTYPE* tokenLoc) {
    while ((int32_t)valueData->valueList.length < valueData->count) {
        Object zero;
        switch (valueData->valueType) {
        case OBJECT_TYPE_NUM:
        case OBJECT_TYPE_I32: {
            ScientificNotation z = {.type = I32, .fraction = 0, .fractionLen = 1, .exp = 0};
            zero = object_createNumber(&z);
            break;
        }
        case OBJECT_TYPE_I64: {
            ScientificNotation z = {.type = I64, .fraction = 0, .fractionLen = 1, .exp = 0};
            zero = object_createNumber(&z);
            break;
        }
        case OBJECT_TYPE_F64: {
            ScientificNotation z = {.type = F64, .fraction = 0, .fractionLen = 1, .exp = 0};
            zero = object_createNumber(&z);
            break;
        }
        case OBJECT_TYPE_BOOL:
            zero = object_createBool(false);
            break;
        case OBJECT_TYPE_STR:
            zero = object_createStr(strdup(""));
            break;
        case OBJECT_TYPE_ARRAY:
            zero = object_createArray();
            break;
        default:
            yyerrorlf("莫識其類『%s』，無由補其虛值\n", tokenLoc,
                      objectType2str[valueData->valueType]);
            return true;
        }
        if (object_ValueDataListAdd(valueData, &zero, tokenLoc)) {
            object_free(&zero);
            return true;
        }
        // Number/str values are shallow-shared into the list clone; the inner
        // allocation is owned by the list element and freed when popped.
        if (zero.type == OBJECT_TYPE_STR)
            object_free(&zero);
    }
    return false;
}

Object* object_ValueDataListPop(ValueData* valueData) {
    if (valueData->valueList.length == 0)
        return NULL;
    LinkedListNode* node = valueData->valueList.head->next;
    Object* obj = node->value;
    linkedList_deleteNode(&valueData->valueList, node);
    return obj;
}

bool object_ValueDataListFree(ValueData* valueData) {
    linkedList_freeA(&valueData->valueList, free);
    return false;
}
