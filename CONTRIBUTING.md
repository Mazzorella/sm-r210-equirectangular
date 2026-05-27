# Contributing

## Branching

`main` should represent the latest stable, usable project state.

Use feature branches for work that is not ready to be treated as stable. Merge to `main` when the change is coherent, tested enough for its stage, and accurately documented.

## Commits

This project uses Conventional Commits.

Format commit subjects as:

```text
type: short imperative summary
```

Common types:

- `feat:` for new converter features or workflow capabilities
- `fix:` for bug fixes or corrected conversion behavior
- `docs:` for documentation-only changes
- `chore:` for repo maintenance and cleanup
- `refactor:` for restructuring without intended behavior changes
- `test:` for test-only changes

Use a short commit body when the change needs context:

```text
feat: add ProRes output mode

- Add a flag for Final Cut-friendly MOV output.
- Preserve the existing H.264 path as the default.
- Document when ProRes is useful.
```

## Media Files

Do not commit source videos, converted videos, Final Cut libraries, or generated test renders.

The `.gitignore` intentionally excludes common media formats and scratch output folders. Keep this repository focused on scripts, documentation, and calibration notes.

## Releases

Releases are usable checkpoints, not every commit.

- Use `v0.X.0` for meaningful workflow milestones.
- Use `v0.X.Y` for fixes to that milestone.
- Do not move existing release tags.
- Update release notes with the practical changes users need to know about.
