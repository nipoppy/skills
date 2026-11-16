# skills

This repository contains skills for LLM agents to work with Nipoppy users.

Skills can be found under the `skills` directory. They follow the [Agent Skills specification](https://agentskills.io/home). 

This repository is a plugin for Claude Code and GitHub Copilot CLI. Both read the manifest in `.claude-plugin/`.

## Available skills

| Skill | Purpose |
|---|---|
| [`argparse-argdump-serializer`](skills/argparse-argdump-serializer) | Serializing Python `argparse` parsers from a repository into JSON with `argdump` |
| [`boutiques-descriptor-creator`](skills/boutiques-descriptor-creator) | Generating a Boutiques 0.5 descriptor for a CLI tool from its help text, including containerized tools |
| [`nipoppy-cli`](skills/nipoppy-cli) | Working with the Nipoppy CLI |

## Install for Claude Code

```bash
claude plugin marketplace add nipoppy/skills
claude plugin install nipoppy-skills@nipoppy
```

Restart Claude Code afterwards. To try the skills from a local clone without installing them:

```bash
claude --plugin-dir /path/to/skills
```

## Install for GitHub Copilot CLI

```bash
copilot plugin marketplace add nipoppy/skills
copilot plugin install nipoppy-skills@nipoppy
```

## License

MIT. See [LICENSE](LICENSE).
