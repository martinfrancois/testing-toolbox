# From Bugs to Brilliance: Testing Toolbox in Action

[![CI](https://github.com/martinfrancois/testing-toolbox/actions/workflows/ci.yml/badge.svg)](https://github.com/martinfrancois/testing-toolbox/actions/workflows/ci.yml)

Click on the folders of the individual demos to see instructions on how to run them.

The Java demos need JDK 25, and the JavaScript demos need Node.js 24. The `.tool-versions`
file records both major versions for local use and CI.

CI runs every demo on push, on pull requests and once a week. Some demos fail on purpose (that is
the demo), so CI checks that exactly those tests fail, for the expected reason, and that
everything else passes. The expected failures are listed in `.github/workflows/ci.yml`.

The latest browser-test results and their rolling history are available in the
[published Allure report](https://martinfrancois.github.io/testing-toolbox/).
