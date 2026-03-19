---
name: boutiques-descriptor-creator
description: Generate Boutiques descriptor JSON from command-line tools. Use this skill whenever a user asks for a Boutiques descriptor and provides a CLI tool name, help output, documentation page, or usage examples. The workflow supports native and containerized tools, extracts arguments from -h/--help, and validates the final descriptor.
license: MIT
---

## Overview

Use this workflow to generate a Boutiques descriptor from a CLI tool:
1. Collect tool help text by running `<tool-name> -h` or `<tool-name> --help`.
2. Extract core tool metadata and command template.
3. Parse arguments into Boutiques `inputs` fields.
4. Build the descriptor JSON.
5. Validate the descriptor as JSON, then run `bosh validate`.

Boutiques is a schema for describing command-line tools in a portable, machine-readable format: https://github.com/boutiques/boutiques

## When to use this skill

Use this skill when:
- A user asks for a Boutiques descriptor for any CLI tool.
- A user provides only a tool name and expects help text discovery.
- A user provides existing documentation, usage strings, or examples.
- The target tool is native or containerized.

## Accepted input sources

This workflow accepts:
1. A CLI tool name (preferred starting point).
2. Help text output from `-h` or `--help`.
3. Documentation pages.
4. Usage strings.
5. Parameter tables.
6. Command examples.

## Step 1: Collect help text from the tool

Default path:
1. Start with the tool name provided by the user.
2. Run `<tool-name> -h`.
3. If output is incomplete or unavailable, run `<tool-name> --help`.
4. Capture output for parsing.

Optional helper commands:
- `command -v <tool-name>` to confirm the binary is on PATH.
- `<tool-name> --version` to collect `tool-version` when available.

If help output is paged or verbose, redirect it to a file and parse from the saved text.

## Step 2: Containerized tools (Docker, Singularity, Apptainer)

When the CLI is available only through a container runtime, collect help text inside the container.

Docker examples:
- `docker run --rm <image>:<tag> <tool-name> -h`
- `docker run --rm <image>:<tag> <tool-name> --help`

Singularity examples:
- `singularity exec <image>.sif <tool-name> -h`
- `singularity exec <image>.sif <tool-name> --help`

Apptainer examples:
- `apptainer exec <image>.sif <tool-name> -h`
- `apptainer exec <image>.sif <tool-name> --help`

Notes:
- If the image entrypoint already invokes the tool, omit `<tool-name>` and pass only `-h` or `--help`.
- If required by the tool, mount input/output paths when running container commands.
- Record the container image in the descriptor `container-image` field.

## Step 3: Extract tool information

From help text or documentation, identify:
- **name**: Tool name (for example, `fmriprep`)
- **description**: Brief summary of tool behavior
- **tool-version**: Version string when available; otherwise ask the user
- **command-line**: Command template with value-keys in brackets

## Step 4: Parse parameters

For each parameter, determine:
- **id**: Unique identifier (snake_case, alphanumeric + underscores)
- **name**: Human-readable name
- **description**: Parameter purpose
- **type**: One of `String`, `Number`, `Flag`, `File`
- **optional**: `true` or `false` (square brackets usually indicate optional)
- **command-line-flag**: Actual flag such as `--output-spaces` or `-t`
- **command-line-flag-separator**: Separator between flag and value (for example, `=`). Default is a single space.
- **value-key**: Uppercase in brackets, for example `[OUTPUT_DIR]`
- **value-choices**: Allowed values for enum-like arguments
- **default-value**: Include when explicitly documented

## Step 5: Build the descriptor

Use this JSON structure:

```json
{
    "name": "<tool-name>",
    "description": "<tool-description>",
    "tool-version": "<version>",
    "schema-version": "0.5",
    "command-line": "<tool-name> [PARAM1] [PARAM2] ...",
    "container-image": {
        "image": "<docker-image>:<version>",
        "type": "docker"
    },
    "inputs": [
        {
            "id": "<param-id>",
            "name": "<param-name>",
            "description": "<description>",
            "optional": <true|false>,
            "type": "<String|Number|Flag|File>",
            "value-key": "[<PARAM_NAME>]",
            "command-line-flag": "<flag>"
        }
    ],
    "tags": {}
}
```

## Parameter type inference rules

Use these rules to determine the correct type:

| Syntax pattern | Type |
|----------------|------|
| No value (just a flag like `--verbose`) | Flag |
| Numeric value (`--nprocs 4`) | Number |
| Path/file input (`--input file.nii`) | File |
| String/enum choices (`--level minimal`) | String |
| List of values (`--output-spaces T1w MNI`) | String with `list: true` |
| Boolean flags | Flag |

## Optional vs Required parameters

- **Positional arguments** (no flag, appears in usage without brackets): Required
- **Optional arguments** (in square brackets in usage, or explicitly marked optional): Optional
- **Flags with defaults**: Make sure it appears in the description, not as a default-value field.

## Step 6: Validate output

Validate in this order:
1. Verify that the descriptor file contains valid JSON.
2. Run `bosh validate <path/to/descriptor.json>`.

JSON validation examples:
- `jq empty <path/to/descriptor.json>`
- `python -m json.tool <path/to/descriptor.json> >/dev/null`

Boutiques validation:
- `bosh validate <path/to/descriptor.json>`

Successful validation should report that the descriptor is valid.

## Value-choices handling

When a parameter has limited valid values:
```json
{
    "id": "level",
    "name": "level",
    "description": "Processing level",
    "optional": true,
    "type": "String",
    "value-key": "[LEVEL]",
    "command-line-flag": "--level",
    "value-choices": ["minimal", "resampling", "full"]
}
```

## Command-line flag conventions

- Long flags: `--output-spaces` → command-line-flag: "--output-spaces"
- Short flags: `-t` → command-line-flag: "-t"
- Combined short: `-w` → command-line-flag: "-w"
- Flag that doesn't need value (boolean): just the flag name
- If possible use the long flags

## Example: Converting fMRIPrep documentation

**Input (usage line from docs):**
```
fmriprep bids_dir output_dir {participant} [-h] [--skip_bids_validation]
           [--participant-label PARTICIPANT_LABEL [PARTICIPANT_LABEL ...]]
           [-t TASK_ID] [--echo-idx ECHO_IDX] ...
```

**Partial Output:**
```json
{
    "name": "fmriprep",
    "description": "fMRI PREProcessing workflows",
    "tool-version": "24.1.1",
    "schema-version": "0.5",
    "command-line": "fmriprep [BIDS_DIR] [OUTPUT_DIR] [ANALYSIS_LEVEL] [SKIP_BIDS_VALIDATION] ...",
    "inputs": [
        {
            "id": "bids_dir",
            "name": "bids_dir",
            "description": "The root folder of a BIDS valid dataset (sub-XXXXX folders should be found at the top level in this folder).",
            "optional": false,
            "type": "String",
            "value-key": "[BIDS_DIR]"
        },
        {
            "id": "output_dir",
            "name": "output_dir",
            "description": "The output path for the outcomes of preprocessing and visual reports",
            "optional": false,
            "type": "String",
            "value-key": "[OUTPUT_DIR]"
        },
        {
            "id": "analysis_level",
            "name": "analysis_level",
            "description": "Processing stage to be run, only 'participant' in the case of fMRIPrep.",
            "optional": false,
            "type": "String",
            "value-key": "[ANALYSIS_LEVEL]",
            "value-choices": ["participant"]
        },
        {
            "id": "skip_bids_validation",
            "name": "skip_bids_validation",
            "description": "Assume the input dataset is BIDS compliant and skip the validation",
            "optional": true,
            "type": "Flag",
            "value-key": "[SKIP_BIDS_VALIDATION]",
            "command-line-flag": "--skip-bids-validation"
        }
    ]
}
```

## Common patterns

- **Memory options**: `--mem`, `--mem-mb` → type: Number or String (with unit like "8GB")
- **Thread options**: `--nprocs`, `--omp-nthreads` → type: Number
- **Version flags**: `--version` → type: Flag
- **Help flags**: `-h`, `--help` → type: Flag
- **Debug flags**: `-v`, `-vv`, `--debug` → type: String with value-choices

## Important notes

- Always validate that output is valid JSON
- Use descriptive IDs (snake_case) for all inputs
- The value-key should match what's in the command-line template. If the usage string contains something like [options...] , expand it into individual flags.
- Set `schema-version` to "0.5" (current Boutiques schema version)
- Run `bosh validate <path/to/descriptor.json>` after JSON validation
- "command-line-flag": null is not a correct value. It should be a string, or the line should be removed
