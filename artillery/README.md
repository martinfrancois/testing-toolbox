# artillery Performance and Load Testing

## Requirements

- Node.js v24 LTS
- pnpm

## Documentation

https://www.artillery.io/docs/get-started/first-test

## Installation

```bash
pnpm add -g --ignore-scripts artillery@2.0.34 json-server@0.17.4
```

## Run from the repository root

Sample backend:

```bash
json-server artillery/backend/db.json
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

- Backend: `json-server backend/db.json`
- Simple test: `artillery run simple.yml`
- Complex test: `artillery run complex.yml`
