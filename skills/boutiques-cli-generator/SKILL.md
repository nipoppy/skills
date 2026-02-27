---
name: boutiques-cli-generator
description: Generate Boutiques descriptor JSON from any command-line tool documentation. Use this skill whenever you need to create a Boutiques descriptor from command-line help text, documentation pages, or CLI tool specifications. This applies to neuroimaging tools, bioinformatics pipelines, data processing utilities, or any command-line application.
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: cli-tools
---

## What I do

I transform command-line documentation or help text into a Boutiques descriptor JSON. Boutiques is a schema (http://github.com/boutiques/boutiques-schema) for describing command-line tools in a portable, machine-readable format.

## When to use me

Use this skill when:
- The user provides command-line documentation (e.g., from a readthedocs page)
- The user provides the output of `--help` or `-h` for a CLI tool
- The user wants to create a Boutiques descriptor for any command-line tool
- You need to convert neuroimaging tools (fMRIPrep, FreeSurfer, ANTs, etc.), bioinformatics pipelines, or any CLI tool to Boutiques format

## Input formats I handle

The skill works with:
1. **Full documentation pages** - e.g., https://fmriprep.org/en/24.1.1/usage.html
2. **Help text output** - e.g., from running `tool --help`
3. **Usage strings** - e.g., `usage: fmriprep [options] bids_dir output_dir {participant}`
4. **Parameter tables** - documentation with argument names, types, descriptions, and default values

## How to generate a Boutiques descriptor

### Step 1: Extract tool information

From the documentation, identify:
- **name**: Tool name (e.g., "fmriprep")
- **description**: Brief description of what the tool does
- **tool-version**: Version string (if not explicitly stated, use a reasonable default or "N/A")
- **command-line**: The full command template with value-keys in brackets

### Step 2: Parse parameters

For each parameter, determine:
- **id**: Unique identifier (snake_case, alphanumeric + underscores)
- **name**: Human-readable name
- **description**: What the parameter does (from docs)
- **type**: One of "String", "Number", "Flag", "File"
- **optional**: true/false (usually inferred from syntax - square brackets mean optional)
- **command-line-flag**: The actual flag (e.g., "--output-spaces", "-t")
- **value-key**: Uppercase in brackets, e.g., "[OUTPUT_DIR]"
- **value-choices**: If enum/choices are specified
- **default-value**: If a default is mentioned

### Step 3: Build the descriptor

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
    "tags": {},
    "suggested-resources": {
        "cpu-cores": 1,
        "ram": 1,
        "walltime-estimate": 60
    }
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
- **Flags with defaults**: Include `default-value` field

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
    "default-value": "full",
    "value-choices": ["minimal", "resampling", "full"]
}
```

## Command-line flag conventions

- Long flags: `--output-spaces` → command-line-flag: "--output-spaces"
- Short flags: `-t` → command-line-flag: "-t"
- Combined short: `-w` → command-line-flag: "-w"
- Flag that doesn't need value (boolean): just the flag name

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

## Output handling

If the documentation mentions output files, add an `output-files` section:

```json
"output-files": [
    {
        "id": "output_dir",
        "name": "output_directory",
        "description": "Directory for preprocessed outputs",
        "value-key": "[OUTPUT_DIR]",
        "path-template": "[OUTPUT_DIR]"
    }
]
```

## Common patterns

- **Memory options**: `--mem`, `--mem-mb` → type: Number or String (with unit like "8GB")
- **Thread options**: `--nprocs`, `--omp-nthreads` → type: Number
- **Version flags**: `--version` → type: Flag
- **Help flags**: `-h`, `--help` → type: Flag
- **Debug flags**: `-v`, `-vv`, `--debug` → type: String with value-choices

## Important notes

- Always validate the output JSON is valid
- Include the container-image section with a reasonable docker/singularity image if you can infer it
- Use descriptive IDs (snake_case) for all inputs
- The value-key should match what's in the command-line template
- Set `schema-version` to "0.5" (current Boutiques schema version)
- Include suggested-resources with reasonable defaults
