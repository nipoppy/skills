# Boutiques Descriptor Schema Reference (v0.5)

Full field reference for Boutiques schema-version 0.5. The SKILL.md covers the
core workflow; read this file when you need field-level detail or are unsure
about a specific property.

## Table of contents

1. [Top-level required fields](#top-level-required)
2. [Top-level optional fields](#top-level-optional)
3. [inputs entries](#inputs)
4. [output-files entries](#output-files)
5. [groups entries](#groups)
6. [container-image](#container-image)
7. [error-codes](#error-codes)
8. [Command-line template syntax](#command-line-template)
9. [Complete minimal example](#example)

---

## Top-level required fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Tool identifier. Use `command` or `command-subcommand`. |
| `description` | string | Human-readable summary of what the tool does. |
| `schema-version` | string | Always `"0.5"`. |
| `tool-version` | string | Version of the tool being described (e.g. `"1.2.3"` or `"unknown"`). |
| `command-line` | string | Template string — see [Command-line template syntax](#command-line-template). |
| `inputs` | array | Array of input descriptor objects — see [inputs](#inputs). |

---

## Top-level optional fields

| Field | Type | Description |
|-------|------|-------------|
| `output-files` | array | Expected output files — see [output-files](#output-files). |
| `groups` | array | Constraint groups (mutex, required, etc.) — see [groups](#groups). |
| `container-image` | object | Docker/Singularity spec — see [container-image](#container-image). |
| `author` | string | Tool author name. |
| `url` | string | Tool website or documentation URL. |
| `doi` | string | DOI for citation. |
| `tags` | object | Key-value pairs for discoverability (e.g. `{"domain": "neuroimaging"}`). |
| `environment-variables` | array | Environment variables: `[{"name":"VAR","value":"default","description":"..."}]` |
| `error-codes` | array | Exit code descriptions — see [error-codes](#error-codes). |
| `suggested-resources` | object | `{"cpu-cores": 2, "ram": 4, "walltime-estimate": 600}` |
| `tests` | array | Test invocation specifications. |

---

## inputs

Each object in the `inputs` array describes one parameter.

### Required fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier. snake_case. Referenced by groups and disables-inputs. |
| `name` | string | Human-readable label. |
| `type` | string | `"File"`, `"String"`, `"Number"`, or `"Flag"`. |

### Commonly used optional fields

| Field | Type | Applies to | Description |
|-------|------|-----------|-------------|
| `description` | string | all | Description of the parameter. |
| `value-key` | string | all | Placeholder in command-line template, e.g. `"[INPUT_FILE]"`. Required unless the input has no command-line representation. |
| `command-line-flag` | string | all | The flag string, e.g. `"--input"` or `"-i"`. Omit for positional arguments. |
| `optional` | boolean | all | `true` if the parameter is not required. Default: `false`. |
| `list` | boolean | all | `true` if the parameter accepts multiple values (space-separated). |
| `default-value` | varies | all | Default value when not provided. |
| `requires-inputs` | array | all | IDs of other inputs that must also be specified when this one is. |
| `disables-inputs` | array | all | IDs of other inputs that cannot be specified alongside this one. |
| `integer` | boolean | Number | `true` if the value must be a whole number. |
| `minimum` | number | Number | Minimum allowed value (inclusive). |
| `maximum` | number | Number | Maximum allowed value (inclusive). |
| `value-choices` | array | String | Enumerated list of valid string values. |

### Flag type behaviour

For `"type": "Flag"`:
- When the flag is set to `true` at runtime, Boutiques inserts the `command-line-flag` value into the command.
- When set to `false`, the placeholder in `command-line` is replaced with an empty string.
- The `value-key` is still required so Boutiques knows where in the command-line to substitute.

### Example inputs

```json
[
  {
    "id": "input_image",
    "name": "Input image",
    "type": "File",
    "value-key": "[INPUT_IMAGE]",
    "description": "The input NIfTI image to process.",
    "optional": false
  },
  {
    "id": "fractional_intensity",
    "name": "Fractional intensity threshold",
    "type": "Number",
    "value-key": "[FRACTIONAL_INTENSITY]",
    "command-line-flag": "-f",
    "description": "Fractional intensity threshold (0–1). Default 0.5.",
    "optional": true,
    "minimum": 0,
    "maximum": 1,
    "default-value": 0.5
  },
  {
    "id": "output_type",
    "name": "Output type",
    "type": "String",
    "value-key": "[OUTPUT_TYPE]",
    "command-line-flag": "--output-type",
    "description": "Output file format.",
    "optional": true,
    "value-choices": ["NIFTI", "NIFTI_GZ", "NIFTI_PAIR"]
  },
  {
    "id": "verbose",
    "name": "Verbose",
    "type": "Flag",
    "value-key": "[VERBOSE]",
    "command-line-flag": "-v",
    "description": "Switch on diagnostic messages.",
    "optional": true
  }
]
```

---

## output-files

Each object describes a file the tool produces.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Unique identifier. |
| `name` | string | yes | Human-readable label. |
| `path-template` | string | yes | Path template using value-keys, e.g. `"[OUTPUT_IMAGE].nii.gz"`. |
| `description` | string | no | Description of the output. |
| `optional` | boolean | no | `true` if the file may not always be produced. |
| `list` | boolean | no | `true` if this entry represents multiple files. |
| `path-template-stripped-extensions` | array | no | Extensions to strip when constructing path, e.g. `[".nii", ".gz"]`. |

### Example

```json
[
  {
    "id": "output_brain",
    "name": "Brain-extracted image",
    "description": "Brain-extracted image in the same format as the input.",
    "path-template": "[OUTPUT_IMAGE]",
    "optional": false
  }
]
```

---

## groups

Groups express constraints between inputs.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Unique group identifier. |
| `name` | string | yes | Human-readable group name. |
| `members` | array | yes | List of input `id` values belonging to this group. |
| `description` | string | no | Explanation of the constraint. |
| `mutually-exclusive` | boolean | no | At most one member may be specified. |
| `one-is-required` | boolean | no | At least one member must be specified. |
| `all-or-none` | boolean | no | Either all members are specified or none. |

Combining `mutually-exclusive: true` and `one-is-required: true` means exactly one member must be specified.

### Example

```json
[
  {
    "id": "output_format_group",
    "name": "Output format",
    "description": "Specify at most one output format flag.",
    "members": ["flag_nii", "flag_nii_gz"],
    "mutually-exclusive": true
  }
]
```

---

## container-image

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | `"docker"`, `"singularity"`, or `"rootfs"`. |
| `image` | string | Image name/URI (e.g. `"fsl/fsl:6.0.4"`). |
| `index` | string | Registry URL for Docker (default: Docker Hub). |

### Example

```json
{
  "container-image": {
    "type": "docker",
    "image": "brainlife/fsl:6.0.0",
    "index": "docker.io"
  }
}
```

---

## error-codes

```json
"error-codes": [
  { "code": 1, "description": "Input file not found or unreadable." },
  { "code": 2, "description": "Invalid parameter value." }
]
```

---

## Command-line template

The `command-line` string is a template where each input's `value-key` acts as
a placeholder. At runtime, Boutiques substitutes each placeholder with the
actual value provided in the invocation.

### Rules

- Positional arguments: place the value-key directly, no flag prefix:
  `bet [INPUT_IMAGE] [OUTPUT_IMAGE]`
- Named flags with values: flag then value-key:
  `bet [INPUT_IMAGE] [OUTPUT_IMAGE] -f [FRACTIONAL_INTENSITY]`
- Boolean flags: value-key alone; Boutiques inserts the flag string when true:
  `bet [INPUT_IMAGE] [OUTPUT_IMAGE] [VERBOSE]`
- List inputs: the value-key is repeated for each value (space-separated automatically).
- Every input with a `value-key` must appear exactly once in `command-line`.
- Inputs without a `value-key` have no command-line representation (rare; used for
  metadata-only inputs).

---

## Example

Minimal complete descriptor for FSL's `bet`:

```json
{
  "name": "bet",
  "description": "Brain Extraction Tool — deletes non-brain tissue from an image.",
  "tool-version": "6.0.4",
  "schema-version": "0.5",
  "command-line": "bet [INPUT_IMAGE] [OUTPUT_IMAGE] -f [FRACTIONAL_INTENSITY] [VERBOSE]",
  "inputs": [
    {
      "id": "input_image",
      "name": "Input image",
      "type": "File",
      "value-key": "[INPUT_IMAGE]",
      "description": "Input image (any NIfTI format).",
      "optional": false
    },
    {
      "id": "output_image",
      "name": "Output image",
      "type": "String",
      "value-key": "[OUTPUT_IMAGE]",
      "description": "Output brain image base name.",
      "optional": false
    },
    {
      "id": "fractional_intensity",
      "name": "Fractional intensity threshold",
      "type": "Number",
      "value-key": "[FRACTIONAL_INTENSITY]",
      "command-line-flag": "-f",
      "description": "Fractional intensity threshold (0–1); smaller values give larger brain outlines. Default 0.5.",
      "optional": true,
      "minimum": 0,
      "maximum": 1,
      "default-value": 0.5
    },
    {
      "id": "verbose",
      "name": "Verbose",
      "type": "Flag",
      "value-key": "[VERBOSE]",
      "command-line-flag": "-v",
      "description": "Switch on diagnostic messages.",
      "optional": true
    }
  ],
  "output-files": [
    {
      "id": "output_brain",
      "name": "Brain image",
      "description": "Brain-extracted image.",
      "path-template": "[OUTPUT_IMAGE].nii.gz",
      "optional": false
    }
  ]
}
```
