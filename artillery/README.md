# Artillery

Load and stress testing tool.

https://www.artillery.io/

Getting started guide:

https://www.artillery.io/docs/get-started/first-test

## Installation

```bash
npm i -g artillery@latest
```

With pnpm, the three install scripts Artillery depends on have to be named, because pnpm does not
run a dependency's install script unless it is listed. This needs `pnpm setup` to have put pnpm's
global bin directory on your PATH:

```bash
pnpm add -g --allow-build=@playwright/browser-chromium --allow-build=protobufjs \
  --allow-build=unix-dgram artillery@latest
```

## Usage

Sample backend: 
```bash
npx json-server backend/db.json5
```

With pnpm:
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
