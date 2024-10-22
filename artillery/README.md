# artillery Performance and Load Testing

## Requirements

- NodeJS v20.11.1

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