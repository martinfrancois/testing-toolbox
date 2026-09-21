# jest-fail-on-console

## Requirements

- Node.js v24 LTS

## Documentation

https://github.com/ValentinH/jest-fail-on-console

## How to run

Initial setup:

```bash
pnpm install
```

Run tests:

```bash
pnpm run test
```

`npm i` and `npm run test` still work without Corepack, but the lockfile here is pnpm's, so npm
resolves its own versions. After `corepack enable`, npm stops instead with `This project is
configured to use pnpm`, because `package.json` has a `packageManager` field.
