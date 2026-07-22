#!/usr/bin/env bash
# Block dangerous git operations that the permissions deny-list can miss.
#
# Claude Code invokes PreToolUse hooks with the tool invocation on stdin as JSON.
# Exit 0 = allow. Exit 2 = block and return stderr to Claude as the reason.
#
# MATCHER DISCIPLINE: rules inspect the PARSED git invocation — executable,
# subcommand, and that invocation's own arguments — never the raw command
# string. The previous substring regexes false-positived on commands that
# merely QUOTE git operations (`gh pr create --body "...git push --force..."`,
# heredocs describing what this hook catches), and every false positive
# teaches operators to work around the guardrail. The command is split into
# logical lines (newlines outside quotes), heredoc bodies are skipped as data,
# each line is shlex-tokenized (quoted strings survive as single tokens) and
# split into pipeline/list segments, and only segments whose leading
# executable is git are analyzed. `bash|sh|zsh -c "<string>"` recurses into
# the string — that is the reflexive retry shape of a blocked agent. If
# tokenization fails (unbalanced quotes etc.), the old conservative substring
# rules run as the fallback — an unparseable command degrades toward blocking,
# never toward a silent allow.
#
# RESIDUAL (deliberate): `xargs git push`, `find -exec git ... ;`, and
# `echo "git ..." | sh` are not analyzed. This is a guardrail against an
# agent's habitual command shapes, not a sandbox against an adversary — a
# determined bypass always wins (git$IFS push evaded the old regex too).

set -uo pipefail

reason="$(PAYLOAD="$(cat)" /usr/bin/python3 <<'PYEOF'
import json, os, re, shlex, subprocess, sys

d = json.loads(os.environ.get("PAYLOAD", "{}") or "{}")
if d.get("tool_name") != "Bash":
    sys.exit(0)
cmd = d.get("tool_input", {}).get("command", "") or ""


def block(reason):
    print(reason)
    sys.exit(2)


OPERATORS = {"&&", "||", ";", ";;", "|", "|&", "&"}
WRAPPERS = ("command", "exec", "builtin", "nohup", "env", "eval", "sudo", "time")
SHELLS = ("bash", "sh", "zsh", "dash", "ksh")


def logical_lines(command):
    """Split on newlines OUTSIDE quotes (quoted multi-line strings — gh pr
    bodies — stay one line; backslash-newline continuations are preserved)."""
    lines, cur, quote, esc = [], [], None, False
    for ch in command:
        if esc:
            cur.append(ch)
            esc = False
        elif ch == "\\" and quote != "'":
            cur.append(ch)
            esc = True
        elif quote:
            if ch == quote:
                quote = None
            cur.append(ch)
        elif ch in "'\"":
            quote = ch
            cur.append(ch)
        elif ch == "\n":
            lines.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    lines.append("".join(cur))
    return lines


def tokenize(line):
    lex = shlex.shlex(line, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    return list(lex)  # raises ValueError on unbalanced quotes


def split_segments(command):
    """Pipeline/list segments per logical line; heredoc bodies are DATA and
    are never analyzed. Raises ValueError on unbalanced quotes."""
    segs = []
    heredoc_term = None
    for line in logical_lines(command):
        if heredoc_term is not None:
            if line.strip() == heredoc_term:
                heredoc_term = None
            continue
        cur, expect_term = [], False
        for tok in tokenize(line):
            if expect_term:
                heredoc_term = tok.lstrip("-")
                expect_term = False
            elif tok in ("<<", "<<-"):
                expect_term = True
            elif tok and all(c in "&|;()" for c in tok):
                if cur:
                    segs.append(cur)
                    cur = []
            else:
                cur.append(tok)
        if cur:
            segs.append(cur)
    return segs


def strip_prefixes(seg):
    """Index of the executable after VAR=val assignments and no-op wrappers."""
    i = 0
    while i < len(seg):
        tok = seg[i]
        if "=" in tok and not tok.startswith("-") and tok.split("=", 1)[0].isidentifier():
            i += 1
        elif tok in WRAPPERS:
            i += 1
        else:
            break
    return i


def git_argv(seg):
    i = strip_prefixes(seg)
    if i >= len(seg) or os.path.basename(seg[i]) != "git":
        return None
    return seg[i + 1:]


def shell_dash_c(seg):
    """The command-string argument of `bash|sh|zsh -c "<string>"`, else None."""
    i = strip_prefixes(seg)
    if i >= len(seg) or os.path.basename(seg[i]) not in SHELLS:
        return None
    saw_c = False
    for tok in seg[i + 1:]:
        if tok.startswith("-") and not tok.startswith("--"):
            if "c" in tok:
                saw_c = True
        elif saw_c:
            return tok
    return None


def eval_arg(seg):
    """eval's argument string (quoted or not), rejoined for re-analysis."""
    i = 0
    while i < len(seg) and "=" in seg[i] and not seg[i].startswith("-") and seg[i].split("=", 1)[0].isidentifier():
        i += 1
    if i < len(seg) and seg[i] == "eval" and len(seg) > i + 1:
        return " ".join(seg[i + 1:])
    return None


def split_subcommand(argv):
    """(subcommand, its args) after consuming git's global options."""
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path"):
            i += 2
            continue
        if a.startswith("-"):
            i += 1
            continue
        return a, argv[i + 1:]
    return None, []


def names_protected_ref(positionals):
    """A push positional that targets main/master (bare branch, src:dst
    refspec, fully-qualified ref, or the +forced variant of each)."""
    return any(
        p in ("main", "master", "refs/heads/main", "refs/heads/master")
        or p.endswith((":main", ":master", ":refs/heads/main", ":refs/heads/master"))
        for p in (q.lstrip("+") for q in positionals)
    )


def check_git(argv):
    sub, rest = split_subcommand(argv)
    if sub is None:
        return
    flags = [a for a in rest if a.startswith("-")]
    positionals = [a for a in rest if not a.startswith("-")]

    # 1. No --no-verify on git commit / git push (bypasses pre-commit & pre-push).
    if sub in ("commit", "push") and "--no-verify" in flags:
        block("git %s --no-verify bypasses pre-commit/pre-push hooks." % sub)

    if sub == "push":
        # 2. No repo-wide push modes — they reach main/master without naming it.
        if "--mirror" in flags:
            block("git push --mirror force-updates and prunes every remote ref, including main/master.")
        if "--all" in flags:
            block("git push --all pushes every branch, including main/master — open a PR instead.")
        force = any(
            f in ("--force", "--force-with-lease", "-f")
            or f.startswith("--force-with-lease=")
            for f in flags
        )
        # 3. No force-push to main/master.
        if force and names_protected_ref(positionals):
            block("force-push to main/master is never allowed.")
        # 4. No direct push to main/master (must go through a PR).
        if names_protected_ref(positionals):
            block("direct push to main/master — open a PR instead.")

    # 5. No git reset --hard on main/master.
    if sub == "reset" and "--hard" in flags:
        if any(
            p in ("main", "master", "origin/main", "origin/master",
                  "refs/heads/main", "refs/heads/master",
                  "upstream/main", "upstream/master")
            for p in positionals
        ):
            block("git reset --hard on main/master can destroy work.")

    # 6. No amending once a commit has been pushed (best-effort; local state only).
    if sub == "commit" and "--amend" in flags:
        proj = os.environ.get("CLAUDE_PROJECT_DIR", ".")
        try:
            unpushed = subprocess.run(
                ["git", "-C", proj, "log", "@{u}..HEAD", "--oneline"],
                capture_output=True, text=True, timeout=10,
            ).stdout.strip()
        except Exception:
            unpushed = ""
        if not unpushed:
            block("amending a commit that's already on the remote rewrites shared history.")


def substring_fallback(command):
    # The pre-tightening rules: conservative, may false-positive, never silent.
    if re.search(r"\bgit\s+(commit|push)\b.*--no-verify", command):
        block("git --no-verify bypasses pre-commit/pre-push hooks. [substring fallback: command did not tokenize]")
    if re.search(r"\bgit\s+push\b.*(--force|--force-with-lease|-f\b)", command) and re.search(r"\b(main|master)\b", command):
        block("force-push to main/master is never allowed. [substring fallback: command did not tokenize]")
    if re.search(r"\bgit\s+push\s+\S+\s+(main|master)\b", command):
        block("direct push to main/master — open a PR instead. [substring fallback: command did not tokenize]")
    if re.search(r"\bgit\s+reset\s+--hard\b.*\b(main|master|origin/main|origin/master)\b", command):
        block("git reset --hard on main/master can destroy work. [substring fallback: command did not tokenize]")


def analyze(command, depth=0):
    if depth > 3:
        return
    try:
        segments = split_segments(command)
    except ValueError:
        substring_fallback(command)
        return
    for seg in segments:
        argv = git_argv(seg)
        if argv is not None:
            check_git(argv)
            continue
        inner = shell_dash_c(seg)
        if inner is None:
            inner = eval_arg(seg)
        if inner is not None:
            analyze(inner, depth + 1)


analyze(cmd)
sys.exit(0)
PYEOF
)" && rc=0 || rc=$?

if [ "${rc:-0}" -eq 2 ]; then
  echo "Blocked by claude-template hook: ${reason}" >&2
  echo "If you truly need this, run it yourself in the terminal — don't work around the hook." >&2
  exit 2
fi
# Any other non-zero rc (python missing, crash) falls through to allow — a
# broken hook must not brick every Bash call; tests/block-dangerous-git.test.sh
# is the guard against silent rule regressions.
exit 0
