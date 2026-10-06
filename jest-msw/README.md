# msw

## Requirements

- Node.js v24 LTS

## Documentation

https://mswjs.io/docs

## How to run

Initial setup:

```bash
pnpm install
```

Run tests:

```bash
pnpm run test
```

The `test` script starts Node with `--experimental-vm-modules`. msw 3 is ESM-only, and Jest can
only load it in that mode. `pnpm exec jest` on its own fails with `Must use import to load ES Module`,
so run the tests through `pnpm run test`.

msw no longer supports Jest officially and recommends Vitest instead, see
https://github.com/mswjs/msw/issues/2698.
