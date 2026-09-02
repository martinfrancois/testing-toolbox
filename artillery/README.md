# artillery Performance and Load Testing

## Requirements

- Node.js v24 LTS

## Documentation

https://www.artillery.io/docs/get-started/first-test

## Installation

```bash
npm i -g artillery@latest
```

## Run

Sample backend: 
```bash
npx json-server backend/db.json5
```

Simple load (burst) test:

```bash
artillery run simple.yml
```

More complex load test:

```bash
artillery run complex.yml
```
