#!/usr/bin/env python3
"""Checks that every documented use of the Action matches action.yml.

A workflow that passes an input the Action does not declare still runs: GitHub
prints a warning and carries on, and the setting silently does nothing. That is
harmless in a project's own workflow and a trap in an example people copy. So
every step that calls this Action, in ``examples/`` and in the YAML blocks of
the READMEs, is checked:

  * each ``with:`` key is an input ``action.yml`` declares;
  * each ``steps.<id>.outputs.<name>`` read from such a step is an output it
    declares;
  * ``command`` names a scan the runner script accepts.

Usage: python3 scripts/check-examples.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

try:
  import yaml
except ImportError:  # pragma: no cover - environment problem, not a docs one
  sys.exit("PyYAML is required: python3 -m pip install pyyaml")

REPO_ROOT = Path(__file__).resolve().parent.parent
ACTION_REPO = "Tooark/action-security-scanner"
READMES = ("README.md", "README.pt-BR.md")
YAML_BLOCK = re.compile(r"^```ya?ml\n(.*?)^```", re.MULTILINE | re.DOTALL)
OUTPUT_REF = re.compile(r"steps\.([A-Za-z0-9_-]+)\.outputs\.([A-Za-z0-9_-]+)")
COMMANDS = re.compile(r"^\s*((?:[a-z-]+ \| )+[a-z-]+)\) ;;$", re.MULTILINE)


def supported_commands() -> set[str]:
  """Reads the scans src/run-scanner.sh accepts from its validation `case`."""
  match = COMMANDS.search((REPO_ROOT / "src/run-scanner.sh").read_text(encoding="utf-8"))
  if not match:
    sys.exit("could not find the command list in src/run-scanner.sh")
  return set(match.group(1).split(" | "))


def action_steps(node):
  """Yields every step under `node` that calls this Action."""
  if isinstance(node, dict):
    uses = node.get("uses")
    if isinstance(uses, str) and uses.split("@")[0] == ACTION_REPO:
      yield node
    for value in node.values():
      yield from action_steps(value)
  elif isinstance(node, list):
    for item in node:
      yield from action_steps(item)


def check_document(text: str, inputs: set[str], outputs: set[str], commands: set[str]):
  """Returns (number of Action steps found, problems) for one YAML document."""
  steps = list(action_steps(yaml.safe_load(text)))
  problems: list[str] = []
  action_step_ids = set()

  for step in steps:
    if "id" in step:
      action_step_ids.add(step["id"])
    settings = step.get("with") or {}
    for name in settings:
      if name not in inputs:
        problems.append(f"passes '{name}', which action.yml does not declare")
    command = settings.get("command")
    if command is not None and command not in commands:
      problems.append(f"runs command '{command}', which src/run-scanner.sh does not accept")

  for step_id, name in OUTPUT_REF.findall(text):
    if step_id in action_step_ids and name not in outputs:
      problems.append(f"reads steps.{step_id}.outputs.{name}, which action.yml does not declare")

  return len(steps), problems


def main() -> int:
  action = yaml.safe_load((REPO_ROOT / "action.yml").read_text(encoding="utf-8"))
  inputs = set(action["inputs"])
  outputs = set(action["outputs"])
  commands = supported_commands()

  # (label, YAML text) for every place a reader copies a step from.
  documents: list[tuple[str, str]] = []
  for path in sorted((REPO_ROOT / "examples").glob("*.yml")):
    documents.append((str(path.relative_to(REPO_ROOT).as_posix()), path.read_text(encoding="utf-8")))
  for name in READMES:
    blocks = YAML_BLOCK.findall((REPO_ROOT / name).read_text(encoding="utf-8"))
    for index, block in enumerate(blocks, start=1):
      documents.append((f"{name} (yaml block {index})", block))

  failed = False
  total_steps = 0
  for label, text in documents:
    try:
      count, problems = check_document(text, inputs, outputs, commands)
    except yaml.YAMLError as exc:
      count, problems = 0, [f"does not parse as YAML: {exc}"]
    total_steps += count

    # A README block that never calls the Action is prose, not a reference.
    if not problems and count == 0 and not label.startswith("examples/"):
      continue
    if not problems and count == 0:
      problems = [f"never calls {ACTION_REPO}; drop it from examples/ or fix the reference"]

    if problems:
      failed = True
      print(f"  FAIL {label}")
      for problem in problems:
        print(f"       {problem}")
    else:
      print(f"  ok   {label}")

  if failed:
    print("\nexample validation failed", file=sys.stderr)
    return 1

  print(f"\n{total_steps} documented uses of the Action match action.yml")
  return 0


if __name__ == "__main__":
  sys.exit(main())
