---
name: argparse-argdump-serializer
description: Serialize Python argparse.ArgumentParser objects from a GitHub repository into JSON files using argdump. Use this skill whenever a user asks to extract or serialize CLI parsers from repo code.
license: MIT
---

# Argparse Argdump Serializer

## Instructions

### Step 1: Determine tool name and version

Use user-provided values first. If missing, derive them from repository metadata or git tags.

Preferred command for version from repository tags:

```bash
git describe --tags
```

If version is still unknown, use `unknown` and report that assumption.

### Step 2: Locate parser definitions in the repository

Search for parser construction patterns in likely entrypoints and CLI modules:
- `argparse.ArgumentParser(`
- `def build_parser(`
- `def get_parser(`
- `def make_parser(`
- `set_defaults(func=`
- `__main__.py`, `cli.py`, `main.py`

Also inspect project metadata to find CLI entrypoints:
- `pyproject.toml` (`[project.scripts]` or tool-specific script sections)
- `setup.cfg` / `setup.py` (`entry_points`)

Pick the parser factory that backs the user-facing command.

### Step 3: Extract a standalone parser script

Create a standalone script (for example `extract_parser.py`) that builds the target parser without requiring full package installation.

Keep these constraints:
- Copy only parser-related functions/constants/classes.
- Remove unrelated runtime dependencies (network, pipeline execution, heavy framework imports).
- Preserve argument names, defaults, choices, help strings, and parser metadata.
- Set `prog` to the real CLI name when needed.

If imports fail because of non-parser runtime dependencies, replace execution hooks with minimal stubs while preserving parser behavior.

### Step 4: Serialize with argdump

In the standalone script, serialize the parser with `argdump.dumps(parser)`:

```python
import argdump

# do whatever is needed to get the parser object
parser = ...
parser.prog = 'tool_name'  # based on the CLI command or entrypoint

json_str = argdump.dumps(parser)
```

### Step 5: Write the output JSON file

Unless the user specifies otherwise, use:
- `<tool_name>-<tool_version>-argdump.json`

Write the serialized string as UTF-8:

```python
output_file = f"{tool_name}-{tool_version}-argdump.json"
with open(output_file, "w", encoding="utf-8") as f:
    f.write(json_str)
```

Honor any user-provided output path or filename override.

### Step 6: Validate output

After writing the file:
1. Confirm the file exists and is non-empty.
2. Confirm valid JSON with `python -m json.tool <output_file>`.

### Step 7: Report deliverables

Return:
1. Path to the standalone extraction script.
2. Path to the generated argdump JSON file.
3. Any assumptions made (entrypoint selected, version fallback, stubs added).
