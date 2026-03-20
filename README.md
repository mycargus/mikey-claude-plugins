# mikey-claude-plugins

My personal Claude Code plugin collection.

## Prerequisites

- [jq](https://jqlang.github.io/jq/) — used by plugin hooks to parse tool input

## Installation

Install via the Claude Code marketplace by pointing at this repo:

```bash
claude plugin marketplace add https://github.com/mycargus/mikey-claude-plugins
claude plugin install mikey@mikey-claude-plugins
```

## Skills

### /mikey:testify

Review and align tests with test philosophy. Identifies code design issues, implementation detail testing, excessive mocking, and negative test coverage gaps — then suggests or implements improvements.

Open claude and type `/mikey:testify` to see optional parameters.

See [mikey/skills/testify/SKILL.md](mikey/skills/testify/SKILL.md) for more information.

### /mikey:tdd

TDD workflow driven by Given/When/Then specifications. Provide a spec file or folder path for autonomous batch processing, or run interactively for one-at-a-time TDD loops. Applies Functional Core / Imperative Shell design principles.

Open claude and type `/mikey:tdd` to see optional parameters.

See [mikey/skills/tdd/SKILL.md](mikey/skills/tdd/SKILL.md) for more information.

## Development

### Local dev workflow

1. **Uninstall** the marketplace version to avoid conflicts:
   ```bash
   claude plugin uninstall mikey@mikey-claude-plugins
   ```

2. **Load the local version** inline when starting Claude Code:
   ```bash
   claude --plugin-dir /path/to/mikey-claude-plugins/mikey
   ```

3. **Iterate** — edit skill/agent/hook files, then reload within the session:
   ```
   /reload-plugins
   ```

4. **Reinstall** from the marketplace when done:
   ```bash
   claude plugin install mikey@mikey-claude-plugins
   ```

## Releasing

1. Update `plugin.json` version
2. Commit changes
3. Create an annotated tag and push:
   ```bash
   git tag -a vX.Y.Z -m "summary of changes"
   git push origin main vX.Y.Z
   ```

The [release workflow](.github/workflows/release.yml) automatically creates a GitHub release from the tag.

## License

MIT
