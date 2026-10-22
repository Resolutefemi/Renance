#!/usr/bin/env python3
"""Balance-checks Dart sources without a Flutter SDK (CI gate pre-flight).

Walks each file as a state machine that correctly skips line/block
comments and string literals (single/double, raw, triple-quoted) while
still counting braces inside ${...} interpolations. Reports unbalanced
{}, [] and () with line numbers.
"""
import sys

OPEN = {'{': '}', '[': ']', '(': ')'}
CLOSE = {'}': '{', ']': '[', ')': '('}
SENTINEL = '${}'  # marks an interpolation opener on the bracket stack


def check(path: str) -> list[str]:
    with open(path, 'r', encoding='utf-8') as f:
        src = f.read()

    stack: list[tuple[str, int]] = []   # open brackets + line they opened
    modes: list[str] = []               # string modes we suspended for ${ }
    mode = 'code'                       # code | line | block | sq | dq | tsq | tdq
    raw = False
    i, line, n = 0, 1, len(src)

    def fail(msg: str) -> list[str]:
        return [f'{path}: {msg}']

    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ''
        if c == '\n':
            line += 1
            if mode == 'line':
                mode = 'code'
            i += 1
            continue

        if mode == 'code':
            if c == '/' and nxt == '/':
                mode = 'line'
                i += 2
                continue
            if c == '/' and nxt == '*':
                mode = 'block'
                i += 2
                continue
            if c == 'r' and nxt in ('\'', '"'):
                # raw string: no escapes inside
                triple = src[i + 1:i + 4] in ('\'\'\'', '"""')
                quote = nxt * (3 if triple else 1)
                mode = 'sq' if nxt == '\'' else 'dq'
                raw = True
                i += 1 + len(quote)
                while i < n:
                    if src[i] == '\n':
                        line += 1
                    if src.startswith(quote, i):
                        i += len(quote)
                        mode = 'code'
                        raw = False
                        break
                    i += 1
                else:
                    return fail(f'unterminated raw string ending line {line}')
                continue
            if c in ('\'', '"'):
                triple = src[i:i + 3] in ('\'\'\'', '"""')
                if triple:
                    mode = 'tsq' if c == '\'' else 'tdq'
                    i += 3
                else:
                    mode = 'sq' if c == '\'' else 'dq'
                    i += 1
                continue
            if c in OPEN:
                stack.append((c, line))
                i += 1
                continue
            if c in CLOSE:
                if not stack:
                    return fail(f'line {line}: unmatched {c}')
                o, ol = stack.pop()
                if o == SENTINEL:
                    if c != '}':
                        return fail(f'line {line}: {c} closes interpolation')
                    # the interpolation ended - resume the string literal
                    if not modes:
                        return fail(f'line {line}: interpolation without string')
                    mode = modes.pop()
                    i += 1
                    continue
                if OPEN[o] != c:
                    return fail(f'line {line}: {c} closes {o} from line {ol}')
                i += 1
                continue
            i += 1
            continue

        if mode in ('line', 'block'):
            if mode == 'block' and c == '*' and nxt == '/':
                mode = 'code'
                i += 2
                continue
            i += 1
            continue

        # inside a string literal
        if c == '\\' and not raw:
            i += 2
            continue
        if c == '$' and nxt == '{':
            modes.append(mode)
            mode = 'code'
            stack.append((SENTINEL, line))
            i += 2
            continue
        quote = {'sq': '\'', 'dq': '"', 'tsq': '\'\'\'', 'tdq': '"""'}[mode]
        if src.startswith(quote, i):
            i += len(quote)
            mode = 'code'
            continue
        if c == '\n':
            if mode in ('sq', 'dq'):
                return fail(f'line {line}: unterminated {mode} string')
            line += 1
        i += 1

    if mode != 'code':
        return fail(f'unterminated {mode} at EOF')
    if modes:
        return fail('suspended string interpolation at EOF')
    if stack:
        o, ol = stack[-1]
        return fail(f'unclosed {o} from line {ol}')
    return []


def main() -> int:
    bad = 0
    for path in sys.argv[1:]:
        errs = check(path)
        if errs:
            bad += 1
            for e in errs:
                print('FAIL', e)
        else:
            print('OK  ', path)
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
