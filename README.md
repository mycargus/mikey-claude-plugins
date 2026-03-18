# mycargus-plugins

My personal Claude Code plugin collection.

## Installation

Install via the Claude Code marketplace by pointing at this repo:

```bash
claude plugin marketplace add https://github.com/mycargus/mycargus-plugins
claude plugin install mycargus@mycargus-plugins
```

## Skills

### /mycargus:testify

Review and align tests with test philosophy. Identifies code design issues, implementation detail testing, excessive mocking, and negative test coverage gaps — then suggests or implements improvements.

Open claude and type `/mycargus:testify` to see optional parameters.

See [mycargus/skills/testify/SKILL.md](mycargus/skills/testify/SKILL.md) for more information.

### /mycargus:spec-driven-dev

TDD workflow driven by Given/When/Then specifications. Provide a spec file or folder path for autonomous batch processing, or run interactively for one-at-a-time TDD loops. Applies Functional Core / Imperative Shell design principles.

Open claude and type `/mycargus:spec-driven-dev` to see optional parameters.

See [mycargus/skills/spec-driven-dev/SKILL.md](mycargus/skills/spec-driven-dev/SKILL.md) for more information.

## License

MIT
