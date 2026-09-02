# WebdriverIO video recording

Research date: 2026-09-02

## Recommendation

Keep `wdio-video-reporter` for this repository, with `saveAllVideos: false` and WebDriver Classic forced. This is the smallest working configuration for the existing Jasmine suite and its Allure report. Remove the Classic fallback after the reporter fixes its BiDi promise ordering or after WebdriverIO's first-party DevTools service supports this suite's Jasmine hooks.

For a Mocha or Cucumber suite, prefer WebdriverIO's maintained `@wdio/devtools-service` with trace mode and per-test, failure-only retention. It keeps WebDriver BiDi enabled, records a continuous Chrome screencast through CDP, attaches each retained video to its Allure test automatically, and avoids saving videos for passing tests.

```ts
services: [[
    'devtools',
    {
        mode: 'trace',
        traceGranularity: 'test',
        tracePolicy: 'retain-on-failure',
        video: 'retain-on-failure',
    },
]],
```

WebdriverIO introduced trace mode for CI diagnosis in 2026 and states that `@wdio/devtools-service` supports WebdriverIO 9 and later. The service can retain a per-test WebM only when the final test attempt fails. With `@wdio/allure-reporter` configured, it attaches the video and trace to the corresponding Allure test without custom hooks. [WebdriverIO trace announcement](https://webdriver.io/blog/2026/06/18/webdriverio-tracing/), [trace-mode video retention](https://webdriver.io/docs/devtools/wdio/trace-mode/#per-test-screenshot--video), [Allure integration](https://webdriver.io/docs/devtools/allure/)

The service's trace documentation states that its retry-aware WebdriverIO path has end-to-end coverage for Mocha and Cucumber. A local run against this repository's Jasmine suite did not receive per-test boundaries. The service fell back to one session trace, produced no failure video, and attached nothing to the Allure test. Migrating this repository would therefore require changing its test framework or fixing the Jasmine integration. Neither is justified for a video-reporting demo.

Chrome, Chromium, and Edge push frames through CDP, which WebdriverIO says does not affect test-command timing. Firefox and Safari use screenshot polling and therefore have some interval-dependent overhead. The service does not require `wdio:enforceWebDriverClassic`; its configuration reference says WebDriverIO attaches BiDi automatically. Video encoding requires `ffmpeg` on `PATH`. [screencast browser support and setup](https://webdriver.io/docs/devtools/wdio/screencast/), [DevTools configuration reference](https://webdriver.io/docs/devtools/reference/)

The package is actively released in the WebdriverIO-owned repository. Its current package metadata accepts `webdriverio` version 9.19.1 or later and `@wdio/allure-reporter` version 9. [package metadata](https://github.com/webdriverio/devtools/blob/main/packages/service/package.json)

## Why the current workaround exists

WebdriverIO 9 attempts to establish a WebDriver BiDi session by default. `wdio:enforceWebDriverClassic` is its supported opt-out, but enabling it removes the BiDi features that WebdriverIO 9 normally provides. It is a compatibility workaround, not the preferred steady-state configuration. [WebdriverIO 9 release notes](https://webdriver.io/blog/2024/08/15/webdriverio-v9-release/#new-features), [capability reference](https://webdriver.io/docs/capabilities/#wdioenforcewebdriverclassic)

`wdio-video-reporter` 6.2.0 has an ordering bug in its BiDi frame path:

1. At test end, the reporter calls `addFrame()` and then calls `generateVideo()` without awaiting the frame. [test-end source](https://github.com/webdriverio-community/wdio-video-reporter/blob/v6.2.0/src/index.ts#L273-L287)
2. In the BiDi branch, `addFrame()` first starts `getWindowHandle()`. It adds the screenshot promise to `screenshotPromises` only after that first promise resolves. The Classic branch adds its screenshot promise immediately. [frame-capture source](https://github.com/webdriverio-community/wdio-video-reporter/blob/v6.2.0/src/index.ts#L356-L393)
3. `generateVideo()` immediately calls `Promise.all(this.screenshotPromises)`. Promises added after that call are not part of the existing `Promise.all`, so the final BiDi screenshot can outlive video generation or session teardown. [video-generation source](https://github.com/webdriverio-community/wdio-video-reporter/blob/v6.2.0/src/index.ts#L402-L475)

The third point is an inference from the package source and standard Promise iteration behavior. The same code remains on the package's main branch as of the research date. Raising `videoRenderTimeout` changes how long the reporter waits for ffmpeg and output files. It does not register the missing screenshot promise earlier. Setting `screenshotIntervalSecs` adds more screenshots but does not repair the final-frame ordering.

A proper upstream fix would push one promise for the complete BiDi chain into `screenshotPromises` synchronously:

```ts
const screenshotPromise = browser.getWindowHandle()
    .then((contextId) => browser.browsingContextCaptureScreenshot({
        context: contextId,
        origin: 'viewport',
        format: {type: 'image/png'},
    }))
    .then(/* write the frame */)
    .catch(/* write the fallback frame */);

this.screenshotPromises.push(screenshotPromise);
```

Until the package publishes such a fix, forcing Classic WebDriver is reliable because its current Classic branch registers the screenshot promise synchronously. A local package patch can preserve BiDi, but it makes a copy-paste example depend on patch maintenance. For Mocha and Cucumber projects, the first-party DevTools service avoids this workaround.

## `saveAllVideos` and interval capture

`saveAllVideos: false` is both the package default and the value in its documented examples. It renders videos for failures and does not keep videos for successful tests. Restoring `false` is the production-oriented setting. A deliberately failing demonstration test is enough to prove the integration. [reporter configuration](https://github.com/webdriverio-community/wdio-video-reporter/blob/v6.2.0/README.md#saveallvideos), [Allure example](https://github.com/webdriverio-community/wdio-video-reporter/blob/v6.2.0/README.md#with-allure-reporter)

Version 6.2.0 also has an open report that `saveAllVideos: true` can hang while finalizing a successful test. Keeping the default avoids that failure mode. [reporter issue 862](https://github.com/webdriverio-community/wdio-video-reporter/issues/862)

There is a separate open bug where version 6.2.0 adds an empty Allure video placeholder to a passing test even when `saveAllVideos` is false. An upstream pull request moves attachment creation to `generateVideo()`, but it remains unmerged. This does not affect the retained failed-test video. [reporter issue 865](https://github.com/webdriverio-community/wdio-video-reporter/issues/865), [proposed fix 921](https://github.com/webdriverio-community/wdio-video-reporter/pull/921)

The reporter still takes screenshots while a passing test runs because it learns the outcome only at test end. Its own documentation warns that screenshots after nearly every command slow tests. `screenshotIntervalSecs: 0.5` adds two screenshot requests per second on top of command-triggered frames and is intended to capture visual changes between commands. It should be omitted unless smoother animation is worth the extra work. [capture trade-off](https://github.com/webdriverio-community/wdio-video-reporter/blob/v6.2.0/README.md#L10-L14), [interval option](https://github.com/webdriverio-community/wdio-video-reporter/blob/v6.2.0/README.md#screenshotintervalsecs)

## Other maintained options

Selenium's official Docker images can record a whole browser session with a video container. They also support retaining recordings only for failed sessions. This is useful when a project already runs Selenium Grid, but it adds a browser container, video process, and roughly one CPU per recorder. It is heavier than the DevTools service for this small local-runner demo. [Selenium Docker video recording](https://github.com/SeleniumHQ/docker-selenium#video-recording)

Cloud browser providers also record sessions, and WebdriverIO has first-party integration services for them. That route is appropriate when the test suite already needs a hosted browser matrix. It requires credentials and moves the video UI outside Allure, so it does not fit this repository's self-contained example as well. [WebdriverIO cloud services](https://webdriver.io/docs/cloudservices/)
