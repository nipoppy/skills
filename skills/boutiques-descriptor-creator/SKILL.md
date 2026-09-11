---
name: boutiques-descriptor-creator
description: Generate Boutiques descriptor JSON from a command-line tool. Use when a user asks for a Boutiques descriptor and provides a CLI tool name, a Docker/Singularity/Apptainer image, helptext output, or documentation page.
license: MIT
---

# Boutiques Descriptor Creator

Two reference files are available:

- `references/boutiques-schema.md` — prose field reference for schema-version 0.5. Read it for
  field-level detail: `groups`, `output-files`, `container-image`, `error-codes`, and the
  command-line template rules.
- `references/descriptor.schema.json` — the authoritative JSON Schema. Consult it when the prose
  reference is not specific enough, or to confirm a field's exact type.

Load `references/boutiques-schema.md` before writing any `groups`, `output-files`, or
`disables-inputs`/`requires-inputs` entry. Do not invent that syntax from memory.

## Instructions

### Step 1: Collect help text from the tool

#### Non-containerized tools

1. Start with the tool name provided by the user.
2. Run `<tool-name> -h`.
3. If output is incomplete or unavailable, run `<tool-name> --help`.
4. If both are unhelpful, run the tool with no arguments at all (`<tool-name>`) — many tools print
   usage in that case.
5. Also try to read the tool's man page (if available) with `man -P cat <tool-name>` for non-interactive capture.
6. Capture all output for parsing. Do not limit the amount of output captured. If help output is paged or verbose, redirect it to a file and parse from the saved text.

If the tool requires a TTY to display help (output is empty, or contains "not a terminal"), stop
and ask the user to paste the help text manually. Do not guess at the tool's interface.

#### Containerized tools

When the CLI is available only through a container runtime, collect helptext inside the container.

Docker examples:
- `docker run --rm <image>:<tag> <tool-name> -h`
- `docker run --rm <image>:<tag> <tool-name> --help`

Singularity examples:
- `singularity exec <image>.sif <tool-name> -h`
- `singularity exec <image>.sif <tool-name> --help`

Apptainer examples:
- `apptainer exec <image>.sif <tool-name> -h`
- `apptainer exec <image>.sif <tool-name> --help`

Add bind paths using `--volume` (for Docker) or `--bind` (for Singularity/Apptainer) if there are errors related to filesystem access.

If these commands fail, inspect the container entrypoint/runscript first:
- Docker: inspect entrypoint and cmd with `docker image inspect <image>:<tag> --format '{{json .Config.Entrypoint}} {{json .Config.Cmd}}'`.
- Docker: if entrypoint is a script path, inspect it with `docker run --rm --entrypoint cat <image>:<tag> <entrypoint-path>`.
- Singularity/Apptainer: inspect the runscript with `singularity inspect --runscript <image>.sif` (or the equivalent `apptainer inspect ...`).
- Singularity/Apptainer: if needed, read `/.singularity.d/runscript` inside the image via `singularity exec <image>.sif cat /.singularity.d/runscript` (or the equivalent `apptainer exec ...`).

After identifying the real entry command, rerun help using the entrypoint's underlying executable.

If the image entrypoint already invokes the tool, omit `<tool-name>` and pass only `-h` or `--help`.

### Step 2: Determine the tool version

The version becomes the `tool-version` field and part of the output filename, so establish it
before parsing parameters. Try, in order:

1. `<tool-name> --version`
2. `<tool-name> -version` (common in FSL and other older tools)
3. A `version` subcommand, if the helptext mentions one: `<tool-name> version`
4. For containerized tools, run the same commands inside the container, or read the image tag —
   `nipreps/fmriprep:23.1.3` implies `23.1.3`.

Record only the version string itself, not the surrounding banner text: from
`fMRIPrep: fMRI PREProcessing workflows v23.1.3`, record `23.1.3`.

If no version can be determined, use `"unknown"` and tell the user that the version could not be
detected so they can correct it.

### Step 3: Extract tool information

From help text or documentation, identify:
- **name**: Tool name (for example, `fmriprep`)
- **description**: Brief summary of tool behavior
- **tool-version**: Version string from Step 2
- **command-line**: Command template with value-keys in brackets

### Step 4: Parse parameters

For each parameter, determine:
- **id**: Unique identifier (snake_case, alphanumeric + underscores)
- **description**: Parameter purpose. This should be exactly what the user would see in the help text or documentation, without modification. Do not add inferred information or rephrase the description.
- **type**: One of `String`, `Number`, or `Flag`
- **optional**: `true` or `false` (square brackets usually indicate optional)
- **command-line-flag**: Actual flag such as `--output-spaces` or `-t`. Prefer long flags if both are available. Omit if the parameter is positional.
- **command-line-flag-separator**: Separator between flag and value (for example, `=`). Omit if the separator is a single space or if the flag does not take a value.
- **value-key**: Uppercase in brackets, for example `[OUTPUT_DIR]`
- **value-choices**: Allowed values for enum-like arguments
- **default-value**: Do not include this field. Instead, include the default behavior in the description.

### Step 5: Build the descriptor

Unless otherwise specified, name the descriptor file `<tool_name>-<tool_version>.json`.

In general, use this JSON structure:

```json
{
    "name": "<tool-name>",
    "description": "<tool-description>",
    "tool-version": "<version>",
    "schema-version": "0.5",
    "command-line": "<tool-name> [PARAM1] [PARAM2] ...",
    "container-image": {
        "image": "<owner>/<docker-image>:<version>",
        "type": "docker"
    },
    "inputs": [
        {
            "id": "<param-id>",
            "name": "<param-id>",
            "type": "<String|Number|Flag|File>",
            "value-key": "[<PARAM_NAME>]",
            "description": "<description>",
            ...
        }
    ],
    "tags": {}
}
```

#### Important notes

- If the tool IS NOT containerized, omit the `container-image` field and warn the user.
    - If the tool IS containerized but is not a Docker container image, add placeholders for `container-image` and inform the user that they should add Docker image information.
- The value-key should match what's in the command-line template. If the usage string contains something like [options...] or [OPTIONS...], expand it into individual flags (one for each input).

#### Parameter type inference rules

Use these rules to determine the correct type:

| Syntax pattern | Type |
|----------------|------|
| No value (just a boolean flag like `--verbose`) | Flag |
| Numeric value (`--nprocs 4`) | Number |
| Path/file input (`--input file.nii`) | String |
| Other values (`--level minimal`) | String |

Use `String` for paths by default, even though the schema also allows a `File` type. `bosh`
validates `File` inputs for existence at invocation time, which fails for output paths and working
directories that the tool itself creates. Use `File` only when the input must already exist on
disk and you want that checked — and say so when you do.

#### Optional parameters

If an input is optional (in square brackets in usage, or explicitly marked optional), add `"optional": true`. Otherwise, omit the `optional` field.

#### Flags/options

If the input is a flag or option (for example, `--flag` or `--option OPTION`), add a `command-line-flag` field with the flag name. Use long-form names (prefixed with double dashes) if available, e.g. `"command-line-flag": "--flag"` instead of `"command-line-flag": "-f"`.

If the flag takes a value, optionally add a `command-line-flag-separator` field if the separator is not a single space.

#### Value-choices handling

When an input has limited valid values, add a `"value-choices": [<choice1>, <choice2>, ...]` field.
Help text usually shows these in braces (`{register,header}`), after the metavar
(`--level {minimal,resampling}`), or spelled out in the description ("one of: nii, nii.gz").

Helptext:

```
--bold2t1w-init {register,header}
                      Either "register" (the default) to initialize volumes at center or
                      "header" to use the header information when coregistering.
```

Input:

```json
{
    "id": "bold2t1w_init",
    "name": "bold2t1w_init",
    "type": "String",
    "value-key": "[BOLD2T1W_INIT]",
    "description": "Either \"register\" (the default) to initialize volumes at center or \"header\" to use the header information when coregistering.",
    "optional": true,
    "command-line-flag": "--bold2t1w-init",
    "value-choices": [
        "register",
        "header"
    ]
}
```

`value-choices` may not be used with the `Flag` type.

#### Multi-value option handling

When a parameter accepts multiple values (for example, `--modalities T1w MNI`), use `list: true`.
Help text signals this with a repeated metavar (`PARTICIPANT_LABEL [PARTICIPANT_LABEL ...]`), an
ellipsis, or wording such as "a space delimited list".

Helptext:

```
--participant-label PARTICIPANT_LABEL [PARTICIPANT_LABEL ...]
                      A space delimited list of participant identifiers.
```

Input:

```json
{
    "id": "participant_label",
    "name": "participant_label",
    "type": "String",
    "value-key": "[PARTICIPANT_LABEL]",
    "description": "A space delimited list of participant identifiers.",
    "optional": true,
    "list": true,
    "command-line-flag": "--participant-label"
}
```

If the values are joined by something other than a space (for example `--labels a,b,c`), add
`"list-separator": ","`. An input of type `Flag` cannot be a list.

#### Numeric constraints

For `Number` inputs only, add:

- `"integer": true` when the value must be a whole number (`--nprocs 4`, metavars such as `N`,
  `NUM`, `INT`, `COUNT`)
- `"minimum"` / `"maximum"` when the help text states an inclusive valid range

```json
{
    "id": "n_procs",
    "name": "n_procs",
    "type": "Number",
    "value-key": "[N_PROCS]",
    "description": "Number of cores used to run in parallel. Defaults to the number of available CPUs minus one.",
    "optional": true,
    "command-line-flag": "--n_procs",
    "integer": true,
    "minimum": 1
}
```

Do not add these fields to `String`, `File`, or `Flag` inputs — the schema rejects them.

#### Output files

If the tool writes files to paths the user supplies, add an `output-files` entry for each. Look for
inputs whose flag, metavar, or description indicates output (`--output`, `--out`, `-o`,
`OUTPUT_DIR`, "the output path for ...").

```json
"output-files": [
    {
        "id": "output_dir",
        "name": "output_dir",
        "description": "The output path for the outcomes of preprocessing and visual reports.",
        "path-template": "[OUTPUT_DIR]"
    }
]
```

The `path-template` references the `value-key` of the input that names the path. Omit
`output-files` entirely if the tool's outputs are not addressable this way. Read
`references/boutiques-schema.md` for `conditional-path-template`,
`path-template-stripped-extensions`, and `file-template`.

#### Mutually exclusive and dependent inputs

When the helptext says options cannot be combined ("use `-T` or `-I`, not both"), express that with
a top-level `groups` array — the key is `groups`, not `input-groups`:

```json
"groups": [
    {
        "id": "mode_group",
        "name": "Mode selection",
        "description": "Mutually exclusive mode flags.",
        "members": ["flag_t", "flag_i"],
        "mutually-exclusive": true
    }
]
```

`groups` entries also support `one-is-required` and `all-or-none`. For dependencies between
individual inputs rather than sets, use `disables-inputs` / `requires-inputs` on the input itself.
Read `references/boutiques-schema.md` before writing either — do not guess the syntax.

#### Examples

##### Example 1

###### Input (helptext)
```
fmriprep [-h] [--skip_bids_validation] [--participant-label PARTICIPANT_LABE [PARTICIPANT_LABEL ...]] 
    [-t TASK_ID] [--bold2t1w-init {register,header}] [--version] [-v] bids_dir output_dir {participant}

fMRIPrep: fMRI PREProcessing workflows v23.1.3

positional arguments:
  bids_dir              The root folder of a BIDS valid dataset (sub-XXXXX folders should be found at the top level in this
                        folder).
  output_dir            The output path for the outcomes of preprocessing and visual reports
  {participant}         Processing stage to be run, only "participant" in the case of fMRIPrep (see BIDS-Apps
                        specification).

options:
  -h, --help            show this help message and exit

Options for filtering BIDS queries:
  --skip_bids_validation, --skip-bids-validation
                        Assume the input dataset is BIDS compliant and skip the validation (default: False)
  --participant-label PARTICIPANT_LABEL [PARTICIPANT_LABEL ...], --participant_label PARTICIPANT_LABEL [PARTICIPANT_LABEL ...]
                        A space delimited list of participant identifiers or a single identifier (the sub- prefix can be
                        removed) (default: None)
  -t TASK_ID, --task-id TASK_ID
                        Select a specific task to be processed (default: None)

Workflow configuration:
  --bold2t1w-init {register,header}
                        Either "register" (the default) to initialize volumes at center or "header" to use the header
                        information when coregistering BOLD to T1w images. (default: register)

Other options:
  --version             show program's version number and exit
  -v, --verbose         Increases log verbosity for each occurrence, debug level is -vvv (default: 0)
```

###### Output

```json
{
    "name": "fmriprep",
    "description": "fMRI PREProcessing workflows",
    "tool-version": "23.1.3",
    "schema-version": "0.5",
    "command-line": "fmriprep [BIDS_DIR] [OUTPUT_DIR] [ANALYSIS_LEVEL] [SKIP_BIDS_VALIDATION] [PARTICIPANT_LABEL] [TASK_ID] [BOLD2T1W_INIT] [HELP] [VERSION] [VERBOSE_COUNT]",
    "container-image": {
        "image": "nipreps/fmriprep:23.1.3",
        "type": "docker"
    },
    "inputs": [
        {
            "id": "bids_dir",
            "name": "bids_dir",
            "type": "String",
            "value-key": "[BIDS_DIR]",
            "description": "The root folder of a BIDS valid dataset (sub-XXXXX folders should be found at the top level in this folder)."
        },
        {
            "id": "output_dir",
            "name": "output_dir",
            "type": "String",
            "value-key": "[OUTPUT_DIR]",
            "description": "The output path for the outcomes of preprocessing and visual reports"
        },
        {
            "id": "analysis_level",
            "name": "analysis_level",
            "type": "String",
            "value-key": "[ANALYSIS_LEVEL]",
            "description": "Processing stage to be run, only \"participant\" in the case of fMRIPrep (see BIDS-Apps specification).",
            "value-choices": [
                "participant"
            ]
        },
        {
            "id": "skip_bids_validation",
            "name": "skip_bids_validation",
            "type": "Flag",
            "value-key": "[SKIP_BIDS_VALIDATION]",
            "description": "Assume the input dataset is BIDS compliant and skip the validation",
            "optional": true,
            "command-line-flag": "--skip_bids_validation"
        },
        {
            "id": "participant_label",
            "name": "participant_label",
            "type": "String",
            "value-key": "[PARTICIPANT_LABEL]",
            "description": "A space delimited list of participant identifiers or a single identifier (the sub- prefix can be removed)",
            "optional": true,
            "list": true,
            "command-line-flag": "--participant-label"
        },
        {
            "id": "task_id",
            "name": "task_id",
            "type": "String",
            "value-key": "[TASK_ID]",
            "description": "Select a specific task to be processed",
            "optional": true,
            "command-line-flag": "--task-id"
        },
        {
            "id": "bold2t1w_init",
            "name": "bold2t1w_init",
            "type": "String",
            "value-key": "[BOLD2T1W_INIT]",
            "description": "Either \"register\" (the default) to initialize volumes at center or \"header\" to use the header information when coregistering BOLD to T1w images.",
            "optional": true,
            "command-line-flag": "--bold2t1w-init",
            "value-choices": [
                "register",
                "header"
            ]
        },
        {
            "id": "help",
            "name": "help",
            "type": "Flag",
            "value-key": "[HELP]",
            "description": "show this help message and exit",
            "optional": true,
            "command-line-flag": "--help"
        },
        {
            "id": "version",
            "name": "version",
            "type": "Flag",
            "value-key": "[VERSION]",
            "description": "show program's version number and exit",
            "optional": true,
            "command-line-flag": "--version"
        },
        {
            "id": "verbose_count",
            "name": "verbose_count",
            "type": "String",
            "value-key": "[VERBOSE_COUNT]",
            "description": "Increases log verbosity for each occurrence, debug level is -vvv (default: 0)",
            "optional": true,
            "value-choices": [
                "-v",
                "-vv",
                "-vvv"
            ]
        }
    ],
    "output-files": [
        {
            "id": "output_directory",
            "name": "output_directory",
            "description": "The output path for the outcomes of preprocessing and visual reports",
            "path-template": "[OUTPUT_DIR]"
        }
    ]
}
```

##### Example 2

###### Input (helptext)

```
Usage: clinica run t1-freesurfer [OPTIONS] BIDS_DIRECTORY CAPS_DIRECTORY

  Cross-sectional pre-processing of T1w images with FreeSurfer.

  https://aramislab.paris.inria.fr/clinica/docs/public/latest/Pipelines/T1_FreeSurfer/

Options:
  Pipeline-specific options:      Options specific to the pipeline being run
    -raa, --recon_all_args TEXT   Additional flags for recon-all command line Please note that = is compulsory after --recon_all_args/-raa flag (this is not the case for other flags).  [default: -qcache]
  Common pipelines options:       Options common to all Clinica pipelines
    -tsv, --subjects_sessions_tsv FILE
                                  TSV file containing a list of subjects with their sessions.
    -wd, --working_directory DIRECTORY
                                  Temporary directory to store pipelines intermediate results.
    -overwrite, --overwrite_outputs
                                  Force overwrite of output files in CAPS folder.
    -ap, --atlas_path PATH        Compute atlases at the end of the path
  Options common to all clinica tools: 
                                  Options common to all clinica tools
    -np, --n_procs INTEGER        Number of cores used to run in parallel.  [default: (Number of available CPU minus one)]
    -cn, --caps-name TEXT         The name of the CAPS dataset that will be created by the pipeline. This is not the name of the folder itself, but the name in the metadata, which can be different if desired. If the CAPS folder already exists and already has a name, this will have no effect and the existing name will be kept.
  -h, --help                      Show this message and exit.
```

###### Output

```json
{
    "name": "clinica-t1-freesurfer",
    "description": "Cross-sectional pre-processing of T1w images with FreeSurfer.",
    "tool-version": "0.10.1",
    "schema-version": "0.5",
    "command-line": "clinica run t1-freesurfer [RECON_ALL_ARGS] [SUBJECTS_SESSIONS_TSV] [WORKING_DIRECTORY] [OVERWRITE_OUTPUTS] [ATLAS_PATH] [N_PROCS] [CAPS_NAME] [HELP] [BIDS_DIRECTORY] [CAPS_DIRECTORY]",
    "inputs": [
        {
            "id": "bids_directory",
            "name": "bids_directory",
            "type": "String",
            "value-key": "[BIDS_DIRECTORY]",
            "description": "The root directory containing the BIDS data."
        },
        {
            "id": "caps_directory",
            "name": "caps_directory",
            "type": "String",
            "value-key": "[CAPS_DIRECTORY]",
            "description": "The root directory for the CAPS data."
        },
        {
            "id": "recon_all_args",
            "name": "recon_all_args",
            "type": "String",
            "value-key": "[RECON_ALL_ARGS]",
            "description": "Additional flags for recon-all command line Please note that = is compulsory after --recon_all_args/-raa flag (this is not the case for other flags). Defaults to -qcache.",
            "optional": true,
            "command-line-flag": "--recon_all_args",
            "command-line-flag-separator": "="
        },
        {
            "id": "subjects_sessions_tsv",
            "name": "subjects_sessions_tsv",
            "type": "String",
            "value-key": "[SUBJECTS_SESSIONS_TSV]",
            "description": "TSV file containing a list of subjects with their sessions.",
            "optional": true,
            "command-line-flag": "--subjects_sessions_tsv"
        },
        {
            "id": "working_directory",
            "name": "working_directory",
            "type": "String",
            "value-key": "[WORKING_DIRECTORY]",
            "description": "Temporary directory to store pipelines intermediate results.",
            "optional": true,
            "command-line-flag": "--working_directory"
        },
        {
            "id": "overwrite_outputs",
            "name": "overwrite_outputs",
            "type": "Flag",
            "value-key": "[OVERWRITE_OUTPUTS]",
            "description": "Force overwrite of output files in CAPS folder.",
            "optional": true,
            "command-line-flag": "--overwrite_outputs"
        },
        {
            "id": "atlas_path",
            "name": "atlas_path",
            "type": "String",
            "value-key": "[ATLAS_PATH]",
            "description": "Compute atlases at the end of the path",
            "optional": true,
            "command-line-flag": "--atlas_path"
        },
        {
            "id": "n_procs",
            "name": "n_procs",
            "type": "Number",
            "value-key": "[N_PROCS]",
            "description": "Number of cores used to run in parallel. Defaults to the number of available CPUs minus one.",
            "optional": true,
            "command-line-flag": "--n_procs",
            "integer": true,
            "minimum": 1
        },
        {
            "id": "caps_name",
            "name": "caps_name",
            "type": "String",
            "value-key": "[CAPS_NAME]",
            "description": "The name of the CAPS dataset that will be created by the pipeline. This is not the name of the folder itself, but the name in the metadata, which can be different if desired. If the CAPS folder already exists and already has a name, this will have no effect and the existing name will be kept.",
            "optional": true,
            "command-line-flag": "--caps-name"
        },
        {
            "id": "help",
            "name": "help",
            "type": "Flag",
            "value-key": "[HELP]",
            "description": "Show this message and exit.",
            "optional": true,
            "command-line-flag": "--help"
        }
    ]
}
```


### Step 6: Validate output

DO NOT use `jq` to validate.

Validation requires the `boutiques` package, which provides `bosh`:

```bash
pip install boutiques
```

Validate in this order:
1. Make sure every argument/option in the command-line template is represented in the `inputs` section with a corresponding `value-key`.
2. Run `./scripts/validate.sh <path/to/descriptor.json>` from the skill directory.

Successful validation should report that the descriptor is valid (`OK`).

## Constraints

- Never invent flags, options, or value-choices that are not present in the captured help text. If help is truncated or unavailable, report what was captured and ask the user how to proceed.
- Every `value-key` in `command-line` must have exactly one matching input, and every input's `value-key` must appear in `command-line`. Check both directions.
- Keep `id` values unique. If two flags would produce the same id, append `_2`.
- If the target file already exists, warn the user before overwriting it.
- Indent generated JSON with 4 spaces, matching the examples above.
- For a tool with many subcommands, describe the one the user asked about and state that the others are not covered. One descriptor per command or subcommand.
