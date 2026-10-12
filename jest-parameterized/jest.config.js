/** @type {import('jest').Config} **/
module.exports = {
  testEnvironment: "node",
  transform: {
    // swc removes the types without checking them, so the test script runs tsc --noEmit first.
    "^.+.tsx?$": ["@swc/jest",{}],
  },
};