# AGENTS.md

## Overview

Welcome, agentic coding agents!  
This document outlines the essential build, lint, test, and style processes for contributing to this Elm-based metronome application. It includes explicit command invocations (for building, linting, formatting, and testing), code conventions, and key resources.  
**Always operate within these guardrails to maximize correctness, maintainability, and style consistency.**

---

## 1. Build / Lint / Test Commands

### **A. Building the Project**

- **Standard Build:**
  ```
  elm make Main.elm
  ```
  This outputs `index.html` by default.
- **Production Build:**
  Adapt with appropriate flags if needed (e.g., --optimize for prod).

### **B. Linting and Formatting**

- **elm-format:**  
  Format all source code according to the community Elm Style Guide.
  ```
  elm-format . --yes
  ```
  or for a specific file:
  ```
  elm-format Main.elm --yes
  ```
- **Additional tooling:**  
  If using Nix/devShell, `elmPackages.elm-format` will be available automatically in the environment.

### **C. Testing**

> **No test dependencies found in elm.json.**  
> If you add tests, install [elm-explorations/test](https://package.elm-lang.org/packages/elm-explorations/test/latest/).

**When tests are present:**

- **Install the test runner** (if not yet installed):
  ```
  npm install -g elm-test
  ```
- **Run all tests:**
  ```
  elm-test
  ```
- **Run a single test file:**
  ```
  elm-test tests/MyModuleTest.elm
  ```
  > Within a file, use `only` to focus on a particular test:
  >
  > ```elm
  > only <| test "runs just this" <| \_ -> ...
  > ```
- **Watch mode:**
  ```
  elm-test --watch
  ```
  > (Continuously runs tests on file changes.)

### **D. Cleaning Build Artifacts**

- **Clean generated HTML:**
  ```
  rm -rf index.html
  ```

---

## 2. Code Style Guidelines

### **A. Tooling**

- **elm-format** is mandatory.
  - Enforce format _before_ every commit and push.
  - Do NOT edit formatting by hand; always run the tool!
- **Optional:** [Prettier](https://prettier.io/) with [elm plugin](https://github.com/gicentre/prettier-plugin-elm) if you prefer unified formatting across web stack.

### **B. Imports**

- List imports alphabetically, grouped by standard library, then external packages, then project modules.
- Omit unused imports.
- No wildcard-style or deeply nested imports; use explicit `exposing` syntax and list items deliberately.

### **C. Formatting + Structure**

- Use `elm-format` default style:
  - Opening braces inline with function/type names.
  - One top-level declaration per line.
  - Indent with 4 spaces, not tabs.
  - Maximum line length: 80-100 columns (let formatter wrap as needed).
- Add trailing newlines at the end of files.

### **D. Types**

- Annotate all public functions with explicit type signatures.
- Favor custom types (ADT/union types) to represent distinct states instead of loose Booleans or strings.
- Organize type definitions at the start of each module.
- Use type aliases for records used in multiple places.

### **E. Naming Conventions**

- **Modules:** `TitleCase` (e.g. `Metronome`, `Metronome.Model`)
- **Types and Type Aliases:** `TitleCase` (e.g. `Msg`, `Model`)
- **Functions and Variables:** `camelCase` (e.g. `initModel`, `updateBeat`)
- **Constants:** `camelCase`
- **No abbreviations or cryptic names.** Choose clarity over brevity.
- Prefix event handlers with `on`, messages with intent nouns or verbs.

### **F. Error Handling**

- Use Elm’s type system to make error states impossible (`Maybe`, `Result`).
- Never use comments as error “catches” — all edge cases must be encoded in the types.
- Pattern match exhaustively on every custom type and discriminated union.
- Prefer using the compiler's static check to enforce correctness.

### **G. Project Structure**

- Place all Elm source in `src/` (to be standardized; currently, only Main.elm exists).
- Entry point (`Main.elm`) must be kept simple, delegating logic to modules as the project grows.

### **H. Comments, Documentation, and Modules**

- Top-level module docs (triple `--|` comments) for each module.
- Document all public functions/types with a brief description of their intent and usage.
- Use inline comments judiciously for non-obvious logic.

---

## 3. Commit Conventions

- Write descriptive commit messages (imperative, concise, present tense).
- Reference issue numbers (if relevant) in commit messages.
- Never commit unformatted or failing code.  
  Always build/lint/test locally before pushing!

---

## 4. Developer Environment & Tooling

- Use the provided Nix devShell for a guaranteed environment (`nix develop`).
  - Includes: Elm, elm-format, elm-json, browser-sync, watchexec.
- Use elm-format, deadnix, statix, prettier as available in your shell.
- Configure your editor for save-on-format (see plugin lists in [elm-format docs](https://github.com/avh4/elm-format#editor-integration)).

---

## 5. Updating Dependencies

- Use `elm-json install <package>` to add/upgrade dependencies.
- Run `elm2nix` if working with Nix to regenerate `elm-srcs.nix` after updating dependencies.

---

## 6. References

- [Elm Official Guide](https://guide.elm-lang.org/)
- [Elm Format](https://github.com/avh4/elm-format)
- [Elm Test](https://github.com/elm-explorations/test)
- [Elm Language Home](https://elm-lang.org/)
- [Elm Error Handling](https://guide.elm-lang.org/error_handling/)
- [Elm Packages](https://package.elm-lang.org/)
- [Elm Browser Example](https://elm-lang.org/examples/buttons)

---

**Agents: All automation, migration, or completion tasks must comply strictly with these conventions—even experimental or prototyping branches. Maintainability and correctness first!**
