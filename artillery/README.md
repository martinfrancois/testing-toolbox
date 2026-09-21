# artillery Performance and Load Testing

## Requirements

- Node.js v24 LTS

## Documentation

https://www.artillery.io/docs/get-started/first-test

## Installation

pnpm fetches Artillery for the run, so there is nothing to install. With npm:

```bash
npm i -g artillery@latest
```

## Run

Sample backend: 
```bash
pnpm dlx json-server@latest backend/db.json5
```

Simple load (burst) test:

```bash
pnpm dlx artillery@latest run simple.yml
```

More complex load test:

```bash
pnpm dlx artillery@latest run complex.yml
```

After the npm installation above, drop the `pnpm dlx artillery@latest` prefix and run
`artillery run simple.yml`.
