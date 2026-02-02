# AGENTS.md: Agentic Coding & Contribution Guide for Metronome

## 1. Build, Lint, Test & Format Commands

All build, lint, test, and formatting actions in this repository must use the following standardized commands. **Agents must not use alternatives (e.g., npm, yarn, direct Elm calls).**

### Build

```sh
devenv tasks run build
```

### Lint

```sh
devenv tasks run lint
```

### Format

```sh
nix fmt
```

- _This command will format all code automatically according to repo standards._
- **Agents must not apply manual or external formatting tools.**

### Test

```sh
devenv tasks run test
```

#### Running Individual Tests

- If single test execution is available, prefer running:
  - `devenv tasks run test -- <test-name-or-filter>`
  - _If unsupported, fallback to running all tests or consult maintainers for custom run options._

---

## 2. Code Style Guidelines

Below are the enforced coding guidelines for this repository. **Agents must always adhere to these standards when writing, editing, refactoring, or reviewing code.**

### General Principles

- Prefer clarity and simplicity in all code.
- Avoid clever tricks or obfuscation.
- Write code for maintainability and readability.
- All code should work in both agentic and human workflows: deterministic, reproducible, and standard-compliant.

### File Organization

- Code files must be grouped logically: Elm code, JS interop/ports, build orchestration.
- JavaScript files for browser ports should be concise with clear function boundaries.
- No unused or commented-out code; keep files clean.

### Imports & Dependencies

- JS: Place all imports at the very top of each file.
- Avoid wildcard imports—prefer importing only what is needed.
- Elm: Use explicit imports for modules and expose only required functions/types.
- Do not use dynamic `require()`/`import()` unless required for a specific agentic workflow.

### Formatting

- All formatting is handled by `nix fmt` — agents should NOT format code manually!
- Indentation: Use 2 spaces for JavaScript, 4 spaces for Elm.
- No trailing whitespace or extra blank lines.
- Max line length: 100 characters in JS, default Elm formatter for Elm files.
- Block and inline comments must use single space after comment tokens.
- JS: Always use semicolons (`;`) where required, avoid ASI pitfalls.

### Types

- Use type annotations for all Elm function signatures.
- In JS, prefer JSDoc type comments if possible, otherwise use TypeScript notation when clarity is needed (even in JS).
- JS: Make explicit any implicit conversions (do not rely on loose JS coercion).
- Elm: Model domain concepts as custom types; favor union types for sealed data structures.

### Naming Conventions

- Use descriptive, lowercase camelCase for functions and variables in JS, PascalCase for constructors/types in Elm.
- Elm modules: PascalCase (e.g., `Metronome.Ports`)
- Avoid single-letter variable names except loop counters.
- Functions must be named for what they DO (`playClick`, not `f` or `do1`).
- Constants: UPPER_CASE if exported, otherwise camelCase.

### Error Handling

- JS:
  - Always handle errors from async code.
  - Use try/catch where exceptions are possible.
  - Log meaningful error messages with context.
- Elm:
  - Use `Result` or `Maybe` for operations that may fail.
  - Propagate errors; do not silence or swallow exceptions.
  - Use explicit error types for domain-specific errors.

### Comments and Documentation

- JS: Use `//` for inline and block comments. Write docblocks as needed for exported functions.
- Elm: Use `{- -}` for comments. Prefer module-level and type-level comments.
- Comments must describe why tricky blocks exist, not what they do (code should be self-describing).

### Code Structure: Example JS (from ports.js)

```js
window.setupPorts = function (app) {
  // Web Audio context for metronome click
  const context = new (window.AudioContext || window.webkitAudioContext)();
  function playClick(primary) {
    // ...
  }
  // Port subscriptions
  if (app.ports && app.ports.beatClick) {
    app.ports.beatClick.subscribe((beatType) => {
      // ...
    });
  }
};
```

### Principles in Action: Elm

- Module structure must expose only what is needed (minimize default exports).
- Prefer `case` expressions over nested `if` for ADT handling.
- Model state with records, not tuples for readability.
- Group related types/functions together in modules.

### Automated Workflows

- All automation must be idempotent and stateless.
- Never create or modify files outside the repo structure.
- Agentic edits should always be atomic — single, minimal changes per commit/pull request.

### Agent Communication

- Agents must interoperate cleanly: use only the commands and formats described above.
- All code changes must pass build, lint, test, and format checks prior to PR/commit.
- AGENTS.md must be kept current; improve this file if you discover repo-specific conventions.

---

If you encounter ambiguity, refer to Elm and JS official style guides, or ask project maintainers before diverging.

**End of file.**
