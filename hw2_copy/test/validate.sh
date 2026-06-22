#!/usr/bin/env bash
# =============================================================================
# validate.sh  ──  數值穩健性驗證 (value-robustness validation)
# -----------------------------------------------------------------------------
# 為何需要本腳本：
#   官方 test/test.sh 是把編譯結果與「固定的」.verbose / .expected 參考檔比對。
#   但助教在實際計分時「會改變數的數值」(例：曰陰 → 曰陽、曰一 → 曰七)，
#   屆時參考檔也會跟著重新產生。因此「能通過 test.sh」只證明在那一組數值下正確，
#   並不保證換了數值仍正確。
#
#   本腳本不依賴任何固定參考檔。它對每一種語言特性，
#   用「多組不同的數值」即時產生 .wy 原始碼，
#   再用 bash 獨立算出應有輸出，最後 compile+run 比對。
#   這正是助教改數值後的情境，可證明編譯器是「真的在運算」而非「背答案」。
#
# 用法：
#   ./test/validate.sh            # 跑全部穩健性測試
#   ./test/validate.sh -o         # 另外再跑一次官方 test/test.sh (-n 不重編)
#   ./test/validate.sh -h         # 說明
#
# 注意：本腳本不修改、不依賴 test/test.sh 之變動；自成一格。
#       執行環境需有 wyc 之依賴 (llc, gcc) —— 即 docker compose 之 dev 容器。
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT/build"
RUN_OFFICIAL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--official) RUN_OFFICIAL=true; shift ;;
        -b|--build-dir) BUILD_DIR="$2"; shift 2 ;;
        -h|--help) sed -n '2,30p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *) echo "未識之項：$1" >&2; exit 1 ;;
    esac
done

GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'
YELLOW='\033[0;33m'; BOLD='\033[1m'; NC='\033[0m'

# ── build (only if needed) ──────────────────────────────────────────────────
WY="$BUILD_DIR/wy"; WYC="$BUILD_DIR/wyc"
if [[ ! -x "$WY" || ! -x "$WYC" ]]; then
    echo -e "${CYAN}建置中 (build)…${NC}"
    [[ -d "$BUILD_DIR" ]] || cmake -B "$BUILD_DIR" -S "$ROOT" -DCMAKE_BUILD_TYPE=Release \
        || { echo -e "${RED}cmake configure 失敗${NC}"; exit 1; }
    cmake --build "$BUILD_DIR" || { echo -e "${RED}build 失敗${NC}"; exit 1; }
fi
[[ -x "$WYC" ]] || { echo -e "${RED}找不到 wyc${NC}"; exit 1; }
command -v llc >/dev/null 2>&1 || { echo -e "${RED}找不到 llc —— 請在 docker dev 容器內執行${NC}"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0; FAIL=0; FAILED_NAMES=()

# ── helpers ─────────────────────────────────────────────────────────────────
# int -> 漢字數字 (0..99999)，採用編譯器接受之標準寫法 (10 -> 一十)
DIG=(零 一 二 三 四 五 六 七 八 九)
num2hanzi() {
    local n=$1
    if (( n == 0 )); then printf '零'; return; fi
    local -a w=(10000 1000 100 10 1) u=("萬" "千" "百" "十" "")
    local i d s="" zero=0 started=0
    for i in 0 1 2 3 4; do
        d=$(( n / w[i] % 10 ))
        if (( d == 0 )); then
            (( started )) && zero=1
        else
            (( zero )) && { s+="零"; zero=0; }
            s+="${DIG[d]}${u[i]}"; started=1
        fi
    done
    printf '%s' "$s"
}

# 編譯並執行一段 .wy 原始碼字串，回傳其 stdout
run_src() {
    local src="$1" exe="$WORK/prog"
    printf '%s' "$src" > "$WORK/t.wy"
    if ! "$WYC" "$WORK/t.wy" "$exe" >/dev/null 2>"$WORK/err"; then
        printf '__COMPILE_ERROR__\n'
        sed 's/^/      /' "$WORK/err" >&2
        return 1
    fi
    "$exe" 2>&1
}

# 去除尾端空白行後比較 (與 test.sh 之 normalize 同義)
trim_blank() { sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' ; }

check() {
    local name="$1" expected="$2" actual="$3"
    expected="$(printf '%s' "$expected" | trim_blank)"
    actual="$(printf '%s'   "$actual"   | trim_blank)"
    if [[ "$actual" == "$expected" ]]; then
        PASS=$((PASS+1))
        echo -e "  ${GREEN}PASS${NC}  $name"
    else
        FAIL=$((FAIL+1)); FAILED_NAMES+=("$name")
        echo -e "  ${RED}FAIL${NC}  $name"
        echo "        ── expected ──"; printf '%s\n' "$expected" | sed 's/^/        /'
        echo "        ── actual   ──"; printf '%s\n' "$actual"   | sed 's/^/        /'
    fi
}

echo -e "${BOLD}${CYAN}══ 數值穩健性驗證 (value-robustness) ══${NC}"
echo -e "  wyc = $WYC"

# ── T1  數字字面值往返 (numeral round-trip) ─────────────────────────────────
# 證明：任何被改成的數值，詞法分析(漢字轉數)都能正確解析並輸出。
echo -e "\n${BOLD}T1 數字往返：宣告一數，書之，須等於原值${NC}"
for n in 0 1 2 7 9 10 13 20 50 99 100 101 131 200 1000 1013 9999; do
    h="$(num2hanzi "$n")"
    src="吾有一數。曰${h}。名之曰「甲」。
吾有一數。曰「甲」。書之。"
    check "數 $h = $n" "$n" "$(run_src "$src")"
done

# ── T2  爻 (布林) 字面值 ────────────────────────────────────────────────────
# 助教典型改動：曰陰 ⇄ 曰陽
echo -e "\n${BOLD}T2 爻值：陰須印「陰」、陽須印「陽」${NC}"
for pair in "陰:陰" "陽:陽"; do
    lit="${pair%%:*}"; exp="${pair##*:}"
    src="吾有一爻。曰${lit}。名之曰「乙」。
吾有一爻。曰「乙」。書之。"
    check "爻 曰$lit" "$exp" "$(run_src "$src")"
done

# ── T3  字串字面值原樣輸出 ──────────────────────────────────────────────────
echo -e "\n${BOLD}T3 字串：宣告一言，書之，須原樣輸出${NC}"
for s in "問天地好在。" "噫吁戲！" "客上天然居" "ABC123"; do
    src="吾有一言。曰「「${s}」」。名之曰「丙」。
吾有一言。曰「丙」。書之。"
    check "言 「$s」" "$s" "$(run_src "$src")"
done

# ── T4  四則 + 取餘運算 ─────────────────────────────────────────────────────
# 對多組 (甲,乙) 即時算出 和/差/積/商/餘，與編譯器輸出比對。
echo -e "\n${BOLD}T4 算術：加/減/乘/除/餘，掃描多組數值${NC}"
arith_one() {
    local a=$1 b=$2 ha hb sum diff prod quot rem src exp
    ha="$(num2hanzi "$a")"; hb="$(num2hanzi "$b")"
    sum=$((a+b)); diff=$((a-b)); prod=$((a*b)); quot=$((a/b)); rem=$((a%b))
    src="有數${ha}。名之曰「甲」。
有數${hb}。名之曰「乙」。
加「甲」於「乙」。名之曰「和」。
減「甲」以「乙」。名之曰「差」。
乘「甲」以「乙」。名之曰「積」。
除「甲」以「乙」。名之曰「商」。
除「甲」以「乙」。所餘幾何。名之曰「餘」。
吾有一數。曰「和」。書之。
吾有一數。曰「差」。書之。
吾有一數。曰「積」。書之。
吾有一數。曰「商」。書之。
吾有一數。曰「餘」。書之。"
    exp="$sum
$diff
$prod
$quot
$rem"
    check "算 甲=$a 乙=$b (和$sum 差$diff 積$prod 商$quot 餘$rem)" "$exp" "$(run_src "$src")"
}
arith_one 10 3
arith_one 7 5
arith_one 50 7
arith_one 9 9
arith_one 100 8
arith_one 13 4
arith_one 1 1

# ── T5  條件分支 若/或若/若非 ───────────────────────────────────────────────
# 掃描可命中三條分支的數值，證明判斷依數值而動。
echo -e "\n${BOLD}T5 決策：若/或若/若非，依數值命中正確分支${NC}"
cond_one() {
    local a=$1 b=$2 ha hb src exp
    ha="$(num2hanzi "$a")"; hb="$(num2hanzi "$b")"
    if   (( a > b )); then exp="大"
    elif (( a == b )); then exp="等"
    else                   exp="小"; fi
    src="有數${ha}。名之曰「甲」。
有數${hb}。名之曰「乙」。
若「甲」大於「乙」者。
    有言「「大」」書之。
或若「甲」等於「乙」者。
    有言「「等」」書之。
若非。
    有言「「小」」書之。
也。"
    check "決策 甲=$a 乙=$b → $exp" "$exp" "$(run_src "$src")"
}
cond_one 5 3
cond_one 3 3
cond_one 2 4
cond_one 0 0
cond_one 100 99

# ── T6  迴圈：為是 n 遍 ，以及 恆為是 倒數 ─────────────────────────────────
echo -e "\n${BOLD}T6 迴圈：為是 n 遍 ＋ 恆為是 倒數${NC}"
loop_count_one() {
    local n=$1 hn exp src
    hn="$(num2hanzi "$n")"
    exp="$(for ((i=0;i<n;i++)); do echo 環; done)"
    src="為是 ${hn} 遍。
    有言「「環」」書之。
云云。"
    check "為是 $n 遍" "$exp" "$(run_src "$src")"
}
loop_count_one 1
loop_count_one 2
loop_count_one 3
loop_count_one 5

loop_countdown_one() {
    # 仿 07：自 n 倒數至 1，逐次書之
    local n=$1 hn exp src
    hn="$(num2hanzi "$n")"
    exp="$(for ((i=n;i>=1;i--)); do echo "$i"; done)"
    src="有數${hn}。名之曰「酒數」。
恆為是。若「酒數」等於零者乃止也。
    吾有一數。曰「酒數」。書之。
    減「酒數」以一。昔之「酒數」者。今其是矣。
云云。"
    check "恆為是 倒數 n=$n" "$exp" "$(run_src "$src")"
}
loop_countdown_one 3
loop_countdown_one 5
loop_countdown_one 1

# ── T7  字串相加 (concat) ───────────────────────────────────────────────────
echo -e "\n${BOLD}T7 字串相加：加 甲 以 乙 = 甲乙${NC}"
concat_one() {
    local a=$1 b=$2 src
    src="吾有一言。曰「「${a}」」。名之曰「甲」。
加「甲」以「「${b}」」。名之曰「合」。
吾有一言。曰「合」。書之。"
    check "concat 「$a」+「$b」" "${a}${b}" "$(run_src "$src")"
}
concat_one "客上" "天然居"
concat_one "春日" "宴"
concat_one "AB" "CD"

# ── T8  陣列：充 / 之長 / 索引取值 ──────────────────────────────────────────
echo -e "\n${BOLD}T8 陣列：之長與 1-based 索引${NC}"
array_one() {
    # 元素以空白分隔；驗證長度與「之 idx」取第 idx 個 (1-based)
    local idx=$1; shift
    local -a elems=("$@")
    local n=${#elems[@]} fill="" e src
    for e in "${elems[@]}"; do fill+="以「「${e}」」。"; done
    src="吾有一列。名之曰「列」。
充「列」${fill}
夫「列」之長。書之。
夫「列」之$(num2hanzi "$idx")。書之。"
    local exp="$n
${elems[idx-1]}"
    check "陣列 長度=$n 取第$idx → ${elems[idx-1]}" "$exp" "$(run_src "$src")"
}
array_one 2 宮 商 角
array_one 1 青龍 白虎 朱雀 玄武
array_one 5 甲 乙 丙 丁 戊

# ── 官方測試 (選擇性) ───────────────────────────────────────────────────────
if [[ "$RUN_OFFICIAL" == true ]]; then
    echo -e "\n${BOLD}${CYAN}══ 另跑官方 test/test.sh -n ══${NC}"
    "$SCRIPT_DIR/test.sh" -n || true
fi

# ── 總結 ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}══ 穩健性結果 ══${NC}"
echo -e "  ${GREEN}通過 PASS: $PASS${NC}    ${RED}失敗 FAIL: $FAIL${NC}"
if (( FAIL == 0 )); then
    echo -e "\n${GREEN}全數通過：改變數值後編譯器仍輸出正確結果。${NC}"
    exit 0
else
    echo -e "\n${RED}以下案例失敗：${NC}"
    printf '    - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
