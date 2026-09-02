# Repository agent instructions

## Continue existing work

- Before broad maintenance, inspect the current branch, worktree, recent commits, open pull request, CI runs, and existing research notes. Continue sound work already in progress and reuse prior findings.
- Account for every existing change before editing. Preserve unrelated work.

## Repository layout

- Every non-hidden directory at the repository root MUST be an independently runnable demo. Supporting material that is not a demo MUST live in a hidden root directory such as `.docs` or inside another appropriate hidden project directory.
- When adding or removing a visible root directory, update CI and `.github/scripts/check_all_demos.sh` in the same change so every visible demo remains runnable through both entry points.

## Dependency policy

- Keep direct dependencies and development tools on their latest stable, mutually compatible versions.
- Java MUST track the latest Eclipse Temurin JDK major currently listed as LTS by [endoflife.date](https://endoflife.date/eclipse-temurin).
- Node.js MUST track the latest major currently listed as LTS by [endoflife.date](https://endoflife.date/nodejs). Do not adopt an upcoming LTS release before its status changes to LTS.
- When either required major changes, update `.tool-versions`, CI, documentation, and lockfiles together.
- When the newest release is incompatible, document the exact constraint and use the newest compatible version. Do not use forced dependency resolutions that install an incompatible graph merely to silence an audit.

## Presentation demos

- Keep `.github/scripts/check_all_demos.sh` aligned with every demo, its required tools and assets, and `.github/workflows/ci.yml`. The script MUST remain macOS-first and Linux-compatible. It MUST install or cache the pinned runtimes, dependencies, browser support, command-line tools, and container images when online; run every feasible demo without stopping at the first failure; and list every failed check or incomplete setup with its reason at the end.
- On macOS, the preflight MUST use an existing nvm installation for Node.js. Do not require the user to replace nvm or change their interactive shell setup.
- When nvm is selected, the preflight MUST NOT install mise. It MUST use an active matching Temurin or SDKMAN! for Java. It MUST install SDKMAN! without changing shell startup files when Java needs a provider.
- When nvm is unavailable, prefer an existing SDKMAN! installation for Java. Use mise only for a runtime that still has no provider.
- Support Testcontainers Desktop on macOS, including its `tcc` and `tcd` Docker contexts and embedded runtime. Use the active Docker-compatible runtime when it works. Do not force Docker Desktop when Testcontainers Desktop already provides the runtime.
- After changing a demo or its tooling, run `.github/scripts/check_all_demos.sh --no-codex` and fix any mismatch. Agents MUST use `--no-codex`; the default command reserves its interactive Codex prompt for a human terminal.
- The preflight MUST detect loss of internet access without a flag. In offline mode it MUST test cached runtimes, dependencies, container images, every demo that can run locally, and the saved Allure fallback. If the offline check fails, finish the remaining checks and tell the human to reconnect and run `--fix-with-codex`; do not start the repair while downloads remain unavailable.
- Keep the script's repair handoff intact. On failure, an interactive human run offers a Codex repair and defaults to No. `--fix-with-codex` starts the repair without prompting. Both modes invoke Codex with `--yolo`, give it the full failure context, and rerun the preflight with `--no-codex` after it finishes. Codex MUST prefer the smallest durable correction over a one-run cache or generated-file patch. It MUST work efficiently without dropping the final complete verification.
- Codex discovery MUST work from a non-interactive macOS shell and after nvm changes the active Node.js version. Check supported standalone and package-manager locations instead of relying only on `PATH`.
- The WebDriverIO test target requires internet during preparation. Offline readiness for a talk means that `webdriverio/allure-report` has already been generated and opened in the browser. Do not add a fake local application solely to make the browser test run offline.
- After a major dependency refresh, regenerate `webdriverio/allure-report-reference` with the updated stack and natural random runs, then verify that the generated test-case data has `flaky: true` and its history has both passing and failing launches. Aggregate counts alone do not prove that Allure applied its Flaky mark. Commit the complete report and treat it as the last-resort offline presentation backup.
- Treat demo source code and comments as presentation material. Preserve comments that explain the point of a demo or act as presenter notes. If a code change makes one inaccurate, rewrite it without removing the teaching point.
- Demo source and configuration MUST stay as close as possible to production-ready code so attendees can copy and paste it without first removing presentation scaffolding.
- Do not add demo-only logic unless the demo cannot work without it. Make unavoidable demo-only behavior self-evident through its name and structure. If its purpose or the corresponding production approach is not obvious, add a concise comment that explains the difference.
- Keep CI-only orchestration in workflow files or CI scripts, outside the demo source.
- Prefer failure-only diagnostic capture. When a reporter saves videos only for failures, keep `saveAllVideos: false` and use the deliberate failing demo test to verify video generation.
- Keep deliberate failures explicit. CI MUST verify the expected test and diagnostic, while rejecting unexpected failures.
- Add the smallest documented compatibility workaround required by current tooling. Remove the workaround after an upgrade fixes its upstream cause.

## CI artifacts and Allure

- Retain GitHub Actions artifacts for the longest period the repository and GitHub permit. Verify the current limit when changing artifact configuration.
- Keep the latest Allure report reachable through the repository's GitHub Pages URL and downloadable as a workflow artifact.
- Preserve Allure history between runs so trend and flaky-test views work. A scheduled run MUST refresh the stored history before artifact expiry.
- Keep a manual presentation workflow option that repeats the naturally random flaky test until its history contains a representative mix of passes and failures and Allure's generated test-case data has `flaky: true`, then publishes the resulting report.
