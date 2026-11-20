# artillery Performance and Load Testing

## Requirements

- Node.js v26 LTS
- pnpm

## Documentation

https://www.artillery.io/docs/get-started/first-test

## Installation

```bash
pnpm add -g --ignore-scripts artillery@2.0.34 @mockoon/cli@9.10.0
```

## Run from the repository root

Sample backend:

```bash
mockoon-cli start --data artillery/backend/mockoon.json --disable-log-to-file
```

Simple load (burst) test:

```bash
artillery run artillery/simple.yml
```

More complex load test:

```bash
artillery run artillery/complex.yml
```

## Run from inside the artillery folder

- Backend: `mockoon-cli start --data backend/mockoon.json --disable-log-to-file`
- Simple test: `artillery run simple.yml`
- Complex test: `artillery run complex.yml`
