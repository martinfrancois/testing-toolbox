# WebdriverIO & Allure Reporting

## Requirements

- Node.js v24 LTS, version 24.18.0 or newer. Node.js 24.16.0 and 24.17.0 contain
  [an archive extraction regression](https://github.com/nodejs/node/issues/63487) that prevents the
  Chrome download from unpacking and leaves an empty report.

## Documentation

- https://webdriver.io/docs/gettingstarted
- https://webdriver.io/docs/allure-reporter/

## How to run

Initial setup:

```bash
npm i
```

Run tests:

```bash
npm run test
```

Open report:

```bash
npm run report
```

Example report is available in the `allure-report-reference` folder.
Open that checked-in fallback without running the tests:

```bash
npm run report -- allure-report-reference
```

## CI report

The latest report is published at
[martinfrancois.github.io/testing-toolbox](https://martinfrancois.github.io/testing-toolbox/).
Each CI run also provides a downloadable `allure-report` artifact for 90 days. The weekly run
restores the previous report's history before generating and publishing the next report. Allure 2
retains its supported history window of 20 launches.

Before a presentation, open the repository's **Actions** tab, select **CI**, choose **Run workflow**,
and enable **Repeat the random test until Allure marks it flaky with representative history**. The
workflow reruns the naturally random example until its history contains at least three passes and
three failures and verifies that Allure applied its Flaky mark. The resulting report is published
at the URL above. The **Publish Allure report** job also displays a direct report link in its job
summary.
