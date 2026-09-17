#!/usr/bin/env python3
"""
Re-apply per-agent model pinning for GSD across Claude Code, Codex CLI and OpenCode.

WHY THIS FILE EXISTS
--------------------
GSD has no runtime model resolution enabled in this setup: the project config sets
`resolve_model_ids: "omit"`, so `gsd_run query resolve-model <agent>` returns an empty
string for every agent and the orchestrator omits the `model=` parameter on spawn.
The model is therefore decided entirely by each agent's own definition file.

Claude Code and Codex CLI read the pin from each agent's own definition file, and those
hand-written pins are LOST on every `/gsd-update`.

OpenCode is different and this is the trap: GSD bakes `model:` into the agent
frontmatter (from `model_profile_overrides.opencode.<tier>` in ~/.gsd/defaults.json),
but OpenCode 1.18 IGNORES that key for subagents - the spawned session is created with
`model=undefined` and silently inherits the parent's model. Verified in the debug log.
The channel that actually works is the `agent` section of opencode.jsonc, so that is
what this script writes. The frontmatter values are left alone; they are inert.

Run this script after any GSD update to restore the intended assignment.

ASSIGNMENT
----------
Based on the `quality` profile tiering, with plan review split out onto its own model.

  group          | Claude Code | Codex CLI      | OpenCode
  ---------------|-------------|----------------|----------------------------------
  heavy (22)     | opus        | gpt-5.6-sol    | openrouter/~deepseek/...pro-latest
  checking (12)  | sonnet      | gpt-5.6-terra  | openrouter/~deepseek/...flash-latest
  gsd-plan-checker | fable     | gpt-6-astra    | (flash - not split out)

Codex also gets `model_reasoning_effort` (xhigh / medium / high) - it is the only
runtime where GSD's catalog defines reasoning effort. Claude Code keeps its
install-time `effort:` frontmatter key untouched. OpenCode has no effort channel.

FILE LOCATIONS
--------------
  ~/.claude/agents/gsd-*.md            frontmatter key `model:`  (+ .compact.md variants)
  ~/.codex/agents/gsd-*.toml           top-level `model` / `model_reasoning_effort`
  ~/.config/opencode/opencode.jsonc    `agent.<name>.model` (NOT the agent frontmatter)

A FOURTH CHANNEL THIS SCRIPT DOES NOT TOUCH
-------------------------------------------
`/gsd-review` (cross-AI peer review) does not spawn subagents at all. It shells out to
each reviewer CLI directly - the claude lane runs literally

    claude --model <M> --effort <E> -p -

with the prompt on stdin (see gsd-core/bin/lib/review-lane-descriptor.cjs). Its model
comes from `review.models.<lane>` in .planning/config.json, NOT from any agent file, so
nothing this script writes affects it. Lanes: claude, codex, opencode, gemini, cursor,
antigravity, ollama, lm_studio, llama_cpp, kimi-code, qwen, coderabbit. An unset lane
falls back to that CLI's own default model.

HOW TO VERIFY A RUNTIME ACTUALLY HONOURS ITS PIN
------------------------------------------------
Spawn one subagent headlessly and look at which model answered. Pick an agent whose
pin DIFFERS from the runtime's default model, or the test proves nothing.

  codex:    codex exec --skip-git-repo-check "Spawn the subagent gsd-verifier ..."
            then grep the rollout under ~/.codex/sessions for the model id
  opencode: opencode run --print-logs --log-level DEBUG "Use the task tool to spawn
            gsd-verifier ..." and read the `modelID=` on the subagent's stream line
  claude:   claude -p "Use the Agent tool with subagent_type gsd-verifier ..."
            --output-format json, then read `modelUsage`

This is how the OpenCode frontmatter trap above was found - do not assume a pin works
because the file contains it.

Usage:  python3 gsd-agent-models.py [--dry-run]
"""

import glob
import os
import re
import sys

DRY = "--dry-run" in sys.argv

# The 12 "checking" agents: verification, scanning, structured low-stakes output.
# Everything else in the gsd-* set is "heavy". gsd-plan-checker is handled separately.
CHECKING = {
    "verifier", "integration-checker", "nyquist-auditor", "codebase-mapper",
    "pattern-mapper", "doc-classifier", "doc-verifier", "dom-verifier",
    "research-synthesizer", "ui-checker", "ui-auditor", "mempalace-curator",
}

RUNTIMES = {
    "claude": {
        "dir": "~/.claude/agents",
        "glob": "gsd-*.md",
        "heavy": "opus",
        "checking": "sonnet",
        "plan_checker": "fable",
    },
    "codex": {
        "dir": "~/.codex/agents",
        "glob": "gsd-*.toml",
        "heavy": ("gpt-5.6-sol", "xhigh"),
        "checking": ("gpt-5.6-terra", "medium"),
        "plan_checker": ("gpt-6-astra", "high"),
    },
    "opencode": {
        # Agent names are discovered here, but the models are written to opencode.jsonc.
        "dir": "~/.config/opencode/agents",
        "glob": "gsd-*.md",
        "config": "~/.config/opencode/opencode.jsonc",
        "heavy": "openrouter/~deepseek/deepseek-pro-latest",
        "checking": "openrouter/~deepseek/deepseek-flash-latest",
        # OpenCode is not split out: plan-checker stays on flash.
        "plan_checker": "openrouter/~deepseek/deepseek-flash-latest",
    },
}


def agent_slug(filename):
    """gsd-plan-checker.compact.md -> plan-checker"""
    base = os.path.basename(filename)
    for suffix in (".compact.md", ".md", ".toml"):
        base = base.removesuffix(suffix)
    return base.removeprefix("gsd-")


def pick(cfg, slug):
    if slug == "plan-checker":
        return cfg["plan_checker"]
    return cfg["checking"] if slug in CHECKING else cfg["heavy"]


def patch_frontmatter(path, model):
    """Set `model:` in a YAML frontmatter block, replacing any existing value."""
    text = open(path).read()
    if not text.startswith("---"):
        return False
    head, rest = text.split("\n---", 1)
    head = re.sub(r"(?m)^model:.*\n", "", head)
    # Keep the key next to `effort:` when present, otherwise append to the block.
    if re.search(r"(?m)^effort:", head):
        head = re.sub(r"(?m)^(effort:.*)$", f"model: {model}\\n\\1", head, count=1)
    else:
        head = head + f"\nmodel: {model}"
    if not DRY:
        open(path, "w").write(head + "\n---" + rest)
    return True


def patch_toml(path, model, effort):
    """Set top-level model / model_reasoning_effort, inserted after sandbox_mode.

    They must stay above `developer_instructions` and any table header, or TOML
    would read them as belonging to a different section.
    """
    lines = open(path).read().split("\n")
    lines = [l for l in lines if not re.match(r"^(model|model_reasoning_effort) *=", l)]
    for i, line in enumerate(lines):
        if line.startswith("sandbox_mode"):
            lines[i:i + 1] = [line, f'model = "{model}"',
                              f'model_reasoning_effort = "{effort}"']
            break
    else:
        return False
    if not DRY:
        open(path, "w").write("\n".join(lines))
    return True


def patch_opencode_config(cfg, directory):
    """Write agent.<name>.model into opencode.jsonc for every gsd-* agent found."""
    import json
    path = os.path.expanduser(cfg["config"])
    names = sorted({os.path.basename(p).removesuffix(".compact.md").removesuffix(".md")
                    for p in glob.glob(os.path.join(directory, cfg["glob"]))})
    conf = json.load(open(path))
    section = conf.setdefault("agent", {})
    counts = {}
    for name in names:
        model = pick(cfg, name.removeprefix("gsd-"))
        section.setdefault(name, {})["model"] = model
        counts[model] = counts.get(model, 0) + 1
    if not DRY:
        json.dump(conf, open(path, "w"), indent=2)
        open(path, "a").write("\n")
    return counts


def main():
    for runtime, cfg in RUNTIMES.items():
        directory = os.path.expanduser(cfg["dir"])
        if not os.path.isdir(directory):
            print(f"{runtime}: skipped - {cfg['dir']} not found")
            continue
        if runtime == "opencode":
            counts = patch_opencode_config(cfg, directory)
            summary = ", ".join(f"{m}: {n}" for m, n in sorted(counts.items()))
            print(f"{runtime}: {summary}")
            continue
        counts = {}
        for path in sorted(glob.glob(os.path.join(directory, cfg["glob"]))):
            choice = pick(cfg, agent_slug(path))
            if runtime == "codex":
                model, effort = choice
                ok = patch_toml(path, model, effort)
            else:
                model = choice
                ok = patch_frontmatter(path, model)
            if ok:
                counts[model] = counts.get(model, 0) + 1
        summary = ", ".join(f"{m}: {n}" for m, n in sorted(counts.items()))
        print(f"{runtime}: {summary}")
    if DRY:
        print("\n(dry run - nothing written)")


if __name__ == "__main__":
    main()
