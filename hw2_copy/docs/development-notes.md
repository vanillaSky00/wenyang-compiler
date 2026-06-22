# HW2 Development Notes

## Goal

Make `/workspace/hw2_copy` pass `./test/test.sh` inside the Docker dev container.

## Implemented Areas

- Completed the parser grammar in `src/compiler.y` for declarations, mixed print lists, assignments, arithmetic chains, conditions, loops, arrays, function definitions, prefix calls, and postfix `取...以施` calls.
- Added location anchoring in parser actions where verbose output expects logs at specific source tokens, such as assignment destinations, index operands, and pushed values.
- Fixed lexer location bookkeeping in `src/compiler.l` for skipped newlines and punctuation so final verbose scope logs match expected files.
- Moved declaration type enforcement to `code_createVariable()` so `吾有...言...書之` can print mixed values, while `名之曰` declarations remain type checked.
- Fixed numeric default values in `src/value_data.c` so default zero emits valid LLVM.
- Initialized symbol metadata in `src/scope.c`, especially array element type state.
- Fixed `或若` IR ordering so else-if condition instructions are emitted in the false branch block instead of the previous true branch.

## Verification

Final command:

```sh
docker compose exec dev bash -lc 'cd /workspace/hw2_copy && ./test/test.sh'
```

Result: all visible tests pass, `105/105`.
