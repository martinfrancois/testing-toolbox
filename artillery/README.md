# artillery Performance and Load Testing

## Requirements

- Node.js v24 LTS

## Documentation

https://www.artillery.io/docs/get-started/first-test

## Installation

This needs `pnpm setup` to have put pnpm's global bin directory on your PATH.

```bash
pnpm add -g --allow-build=@playwright/browser-chromium --allow-build=protobufjs \
  --allow-build=unix-dgram artillery@latest
```

The three install scripts Artillery declares have to be named, because pnpm 12.4 refuses to finish
the install while any of them is unrun. None of the three changes what these scenarios do, and pnpm
12.5 only warns, so the flags can go once your pnpm is past 12.4.

## Run

Sample backend: 
```bash
pnpm dlx json-server@latest backend/db.json5
```

Simple load (burst) test:

```bash
artillery run simple.yml
```

More complex load test:

```bash
artillery run complex.yml
```
