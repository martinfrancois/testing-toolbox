# msw

## Requirements

- Node.js v24 LTS

## Documentation

https://mswjs.io/docs

## How to run

Initial setup:

```bash
npm i
```

Run tests:

```bash
npm run test
```

The `test` script starts Node with `--experimental-vm-modules`. msw 2.11.3 and newer depend on
ESM-only packages (`until-async`, `rettime`) that Jest can only load in that mode. `npx jest` on its own
fails with `Must use import to load ES Module`, so run the tests through `npm run test`.

msw no longer supports Jest officially and recommends Vitest instead, see
https://github.com/mswjs/msw/issues/2698.
