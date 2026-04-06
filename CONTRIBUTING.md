# Contributing to Feral File Mobile App

Thanks for helping improve the canonical mobile controller app for FF1 and The Digital Art System.

## Ground Rules

- Keep domain terminology aligned with `Channel`, `Playlist`, and `Work`.
- Prefer focused changes over broad speculative refactors.
- Do not commit secrets, private documents, production credentials, or generated artifacts.
- If you change setup or configuration behavior, update `README.md` and `.env.example` in the same pull request.

## Local Development Loop

```bash
cp .env.example .env
flutter pub get
./scripts/verify_local_setup.sh
```

If your change touches hardware flows, seed-database imports, or private service integrations, you may need extra environment variables beyond the default public setup.

For broader verification, run the targeted tests appropriate to your change in addition to the default smoke check.

## Pull Requests

- Explain the user-facing or developer-facing outcome clearly.
- Include test evidence for the change.
- Keep the public and private boundary intact: document interfaces, not secrets.
- Link the relevant issue when one exists.

## Issues

Use the repository issue templates for bugs and feature requests so maintainers can reproduce the problem or evaluate scope quickly.
