# Local Shell Scripts Collection

This repository is a personal, open-source collection of shell scripts and related tooling that I actively use, refine, and gradually standardize.

It sits somewhere between a laboratory and a toolbox: a place to experiment with ideas, codify workflows, and keep scripts maintainable as they grow beyond one-off hacks. While the primary audience is myself, the repository is intentionally public so others can inspect, reuse, or adapt anything that may be useful.

The long-term goal is to evolve this into a reusable template for managing personal scripts in a clean, testable, and publishable way.

---

## Scope and Non‑Goals

**In scope:**

* Small to medium-sized shell scripts (initially Bash)
* Scripts that act as user-facing tools (CLI utilities)
* Supporting libraries, helpers, and shell completions
* A lightweight but explicit testing strategy
* Clear separation between runtime code, tests, and initialization logic

**Out of scope (for now):**

* Large applications or long-running daemons
* Heavy frameworks or external build systems
* Tight coupling to a single operating system or desktop environment

---

## Repository Layout

The repository follows a strict directory layout. Each top-level directory has a single, well-defined responsibility.

```
.
├── bin/
│   └── <script entrypoints>
├── lib/
│   └── <script-specific libraries>
├── tests/
│   ├── unit/
│   ├── integration/
│   └── fixtures/
├── completions/
│   ├── bash/
│   ├── zsh/
│   └── fish/
├── init/
│   └── env.bash
├── Makefile
└── README.md
```

### bin/

User-facing executables. These are the commands that are expected to be in `PATH`.

Rules:

* Files in `bin/` must be executable
* No complex logic should live here
* Each script should delegate real work to `lib/`

### lib/

Implementation code and reusable logic.

Rules:

* No direct side effects on load (no execution on `source`)
* Functions must be explicitly invoked
* Code here should be testable without requiring a real X session or hardware

### tests/

All automated and semi-automated tests live here.

* `unit/`: logic-level tests (pure functions, argument validation, parsing, decision logic)
* `integration/`: tests that exercise multiple components together, possibly mocking external tools
* `fixtures/`: static data used by tests (fake `xrandr` outputs, sample configs, etc.)

Manual test guides, checklists, or exploratory test notes should live in `docs/` if and when that directory is introduced, not inside `tests/`.

### completions/

Shell completion definitions, separated by shell.

Rules:

* No runtime logic
* Must not assume the script is already in `PATH`
* Should degrade gracefully if dependencies are missing

### init/

Environment initialization scripts.

These files are meant to be sourced from a shell startup file (for example `.bashrc`). Their responsibilities are intentionally narrow:

* Add `bin/` to `PATH`
* Load shell completions
* Perform minimal environment wiring

They must not:

* Execute user commands
* Produce output during normal shell startup

### Makefile

Developer-facing automation.

Typical responsibilities:

* Running tests
* Linting or static checks (if introduced)
* Installing or linking scripts locally
* Verifying repository invariants

---

## Testing Philosophy

Not everything in this repository can or should be tested against a real system.

The guiding principle is:

> Test logic and contracts, not hardware.

Examples of what is considered testable:

* Argument parsing and validation
* Resolution and mode selection logic
* Topology decisions (positioning rules, precedence)
* Error conditions and failure modes

Interaction with real tools like `xrandr` should be abstracted so their outputs can be injected via fixtures. Exhaustive or exploratory testing against a real X session is valuable, but it is treated as manual validation, not automated regression testing.

---

## 🧪 Testing Architecture & Contracts

This project treats tests not just as checks, but as strict contracts defining boundaries, inputs, and expected behaviors. The test suite is organized into three distinct domains located in `tests/`.

### Directory Structure

```text
tests/
├── unit/           # Logic contracts: Isolated function verification
├── integration/    # System contracts: Robustness and binary execution
└── fixtures/       # Data contracts: Static input data for tests
```

### 1. Integration Contracts (`tests/integration/`)

Integration tests verify the robustness of the system as a whole.

- **Target:** They execute the compiled binary located in `bin/vscreen`.
- **Scope:** Focus on "exhaustion testing" (end-to-end flows, error handling, piping).
- **Environment:** Self-contained. They do not rely on the user's global `$PATH` or shell environment; they dynamically locate the project root and artifacts.

### 2. Unit Contracts (`tests/unit/`)

Unit tests verify internal logic in isolation.

- **Target:** Individual functions or libraries within `lib/`.
- **Scope:** Logic correctness, edge cases, and return values.

### 3. Data Contracts (`tests/fixtures/`)

Contains static data used by the test suites. No code resides here.

- **Usage:** Valid/invalid configuration files, sample input texts, or expected output templates.

---

### 📊 Logging Strategy

Test execution logs are strictly segregated from source code and build artifacts. All logs are directed to the `logs/` directory with the following structure:

```text
logs/
├── integration/
│   └── vscreen/
│       ├── exhaust_20231027_120000.log  # Historical record
│       └── exhaust_latest.log           # Symlink to the most recent run
└── unit/
```

**Key Features:**

- **Subdivisions:** Logs are separated by contract type (`unit` vs `integration`).
- **History:** Files are timestamped to preserve execution history.
- **Quick Access:** A `*_latest.log` symlink is always updated to point to the last execution for immediate debugging.

---

## Motivations

I originally created several scripts directly in my personal `bin` directory, which eventually became cluttered and mixed with executables installed by applications. Over time, these scripts were also versioned inside a dotfiles repository called *Labophase*, which contained too much private and personal information to be made public.

This repository is the result of stepping back and reorganizing that setup.

Starting here, the intent is to:

* Separate scripts from unrelated dotfiles
* Make individual components publishable without leaking private context
* Split versioning across multiple focused repositories that can work independently or together
* Maintain private state and configuration in a single, isolated place

Even if no one ends up using these scripts, making them public is still worthwhile. Free software should exist even when it lives in quiet corners of the internet.

---

## Status

This repository is under active construction. Most scripts are still being migrated, refactored, or formalized. Interfaces may change, and parts of the layout may evolve, but the core structure and responsibilities described above are considered stable.

Contributions, suggestions, and critical feedback are welcome — especially when they help make the scripts simpler, more robust, or easier to reason about.

## TODOS

<!-- TODO(refactor): Renaming directories to look more like a young mystic's space
    For this happens, all scripts may be changed. Then use this env is better than hardcode directories 
    # Sigils Directory Structure Example: ( maybe without SIGILS prefix )
        export SIGILS_ROOT="${SIGILS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
        export SIGILS_BIN="$SIGILS_ROOT/spells"
        export SIGILS_LIB="$SIGILS_ROOT/bos"
        export SIGILS_LOGS="$SIGILS_ROOT/bom"
        export SIGILS_TESTS="$SIGILS_ROOT/scrying"
        export SIGILS_DOCS="$SIGILS_ROOT/grimoire"
        export SIGILS_DATA="$SIGILS_ROOT/manifestation"
        export SIGILS_INIT="$SIGILS_ROOT/invocations"
        export SIGILS_COMPLETIONS="$SIGILS_ROOT/omens"
        export SIGILS_CONFIG="$SIGILS_ROOT/pacts"
        export SIGILS_SERVICES="$SIGILS_ROOT/rituals"
    
    labels: wtf, low
-->
