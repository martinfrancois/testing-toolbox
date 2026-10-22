# Repository agent instructions

## Continue existing work

- Before broad maintenance, inspect the current branch, worktree, recent commits, open pull request, CI runs, and existing research notes. Continue sound work already in progress and reuse prior findings.
- Account for every existing change before editing. Preserve unrelated work.
- When removing files, inspect both the worktree and the Git index. A staged addition deleted only from disk still appears as `AD` and can be committed accidentally. Record the removal for those exact paths, verify it with `git status` and `git ls-files`, and leave unrelated staging untouched.

## Repository layout

- Every non-hidden directory at the repository root MUST be an independently runnable demo. Supporting material that is not a demo MUST live in a hidden root directory such as `.docs` or inside another appropriate hidden project directory.
- When adding or removing a visible root directory, update CI and `.github/scripts/check_all_demos.sh` in the same change so every visible demo remains runnable through both entry points.

## Dependency policy

- Keep direct dependencies and development tools on their latest stable, mutually compatible versions. Explicitly declared dependency and tool versions MUST be final releases, including global CLI tools; exclude alpha, beta, release candidate, preview, nightly, and development builds. A package registry's `latest` tag is not proof of stability. Choose the newest stable release even when it belongs to an older major, and adapt the demo to its supported formats and options.
- Prereleases selected transitively in lockfiles are acceptable. Do not force overrides or downgrade a stable parent package just to remove them. The stable-only rule applies to versions we explicitly declare. A demo's own unpublished artifact version, such as `1.0-SNAPSHOT`, is project metadata rather than a dependency pin.
- Every explicit dependency, runtime, and container-image version MUST be covered by Renovate wherever it appears, including READMEs, shell commands, CI, and source code. When adding or changing a version, check every copy, add a native or custom manager where needed, and verify actual extraction and lookup with Renovate. Configuration validation or a regex match alone is insufficient. Keep demo test sources in scope; Renovate's default test-directory exclusions can hide container dependencies. Group copies that must move together, or derive them from one managed declaration.
- Keep historical versions in compatibility notes, research, generated reports, and test fixtures fixed; they describe evidence or test cases, not current dependency requirements. Document any other deliberate exclusion from Renovate with its reason.
- Java MUST track the latest Eclipse Temurin JDK major currently listed as LTS by [endoflife.date](https://endoflife.date/eclipse-temurin).
- Node.js MUST track the latest major currently listed as LTS by [endoflife.date](https://endoflife.date/nodejs). Do not adopt an upcoming LTS release before its status changes to LTS.
- When either required major changes, update `.tool-versions`, CI, documentation, and lockfiles together.
- When the newest release is incompatible, document the exact constraint and use the newest compatible version. Do not use forced dependency resolutions that install an incompatible graph merely to silence an audit.
- The seven-day dependency cooldown is for local project dependencies, not global CLI installations. Do not add release-age restrictions to global installs or delay this demo's setup to satisfy that cooldown.

## Standalone CLI demos and README commands

- For standalone CLI demos such as Artillery and json-server, prefer pinned global installations with a visible package-manager command such as `pnpm add -g`, followed by plain tool commands. Keep README, CI, and `.github/scripts/check_all_demos.sh` aligned. Avoid a custom install wrapper, `package.json`, lockfile, or package-script wrapper solely to launch these tools.
- This preference is about showing attendees what actually runs. Use the tools directly, such as `artillery run` and `json-server`, rather than hiding them behind `pnpm run` aliases. Keep package manifests in demos that genuinely need local application or test dependencies.
- Artillery's local `package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`, and custom `install.sh` were deliberately removed. Their absence is not an incomplete setup. Keep the global install command visible in the README and execute it directly in preparation and CI.
- Prioritize simple commands that attendees can understand and copy directly. Manual README instructions MUST work on Windows as well as macOS and Linux; use platform-neutral commands and avoid Bash-only setup or path substitutions. Keep platform-specific automation in the preparation script or CI.
- README Run commands MUST work from the repository root because IntelliJ runs Markdown commands there. Also document the equivalent commands from inside the demo folder for terminal users. Use explicit relative asset paths for each location; global installation does not change how paths resolve.
- The original failure was `pnpm run backend` producing `ERR_PNPM_NO_SCRIPT` when IntelliJ executed it at the repository root. It was a working-directory problem. Do not recreate a root package, workspace, or dispatcher just to support a standalone CLI demo.
- Prefer two clear examples over one complicated command that detects its directory. For Artillery, use `artillery run artillery/simple.yml` from the root and `artillery run simple.yml` from the demo folder. Apply the same distinction to backend and configuration paths. Do not add Git command substitutions just to make both examples identical.
- Install CLI tools while online, then verify their plain commands offline from both locations and from the caller's terminal environment. Preparation may select another Node.js version through nvm, so success only inside the preparation process is insufficient. This keeps IntelliJ clicks and terminal commands simple and avoids downloads during the talk.
- Check global command discovery independently of installation. pnpm 11+ puts global binaries in `PNPM_HOME/bin`; use this when diagnosing an actual PATH failure. Test the newly prepared binaries as well as the caller's commands, so an older npm installation cannot mask a broken pnpm install. Do not hardcode a machine's home directory or count a temporary preflight PATH change as proof that a fresh terminal works.
- Keep global CLI pins synchronized across the README, preparation script, and CI, and keep Renovate able to discover and update all three locations without a demo-local package manifest. Verify README extraction with Renovate itself when changing its custom managers, and retain its stable-only update policy. Artillery's HTTP scenarios do not need Playwright downloads or the native statsd transport; `--ignore-scripts` avoids those unused installation hooks. Reassess that flag if the demo starts using those features.
- Keep demo READMEs focused on installation and runnable commands. Put IDE rationale, offline workflow requirements, and agent conventions here. Omit obvious narration such as how IntelliJ chooses its directory or reminders to keep the backend running.
- Treat tools listed under Requirements as already installed and configured. Listing pnpm is sufficient; do not add `pnpm setup`, terminal-reopening instructions, or other prerequisite setup reminders to the demo README.
- Validate Windows commands in Windows CI or on a Windows machine when available. Distinguish added Windows coverage from a Windows run that actually passed; macOS checks alone do not establish Windows compatibility.
- On 2026-10-22, a global Artillery 2.0.34 install reported an OpenTelemetry peer mismatch: API 1.10.0 was selected while SDK packages required `<1.10.0`. Both HTTP scenarios still passed with external networking blocked. Recheck the installed versions and reproduce any affected behavior before adding a workaround; this observation is not a reason to restore a local package project or impose a global cooldown.

## Presentation demos

- Keep `.github/scripts/check_all_demos.sh` aligned with every demo, its required tools and assets, and `.github/workflows/ci.yml`. The script MUST remain macOS-first and Linux-compatible. It MUST install or cache the pinned runtimes, dependencies, browser support, command-line tools, and container images when online; run every feasible demo without stopping at the first failure; and list every failed check or incomplete setup with its reason at the end.
- On macOS, the preflight MUST use an existing nvm installation for Node.js. Do not require the user to replace nvm or change their interactive shell setup.
- When nvm is selected, the preflight MUST NOT install mise. It MUST use an active matching Temurin or SDKMAN! for Java. It MUST install SDKMAN! without changing shell startup files when Java needs a provider.
- When nvm is unavailable, prefer an existing SDKMAN! installation for Java. Use mise only for a runtime that still has no provider.
- Support Testcontainers Desktop on macOS, including its `tcc` and `tcd` Docker contexts and embedded runtime. Use the active Docker-compatible runtime when it works. Do not force Docker Desktop when Testcontainers Desktop already provides the runtime.
- After changing a demo or its tooling, run `.github/scripts/check_all_demos.sh --no-codex` and fix any mismatch. Agents MUST use `--no-codex`; the default command reserves its interactive Codex prompt for a human terminal.
- Finish edits before the final complete verification. The preflight checks that the worktree stays unchanged; edits made during a run, including concurrent user edits, can fail that check without a demo regression. Inspect the difference, preserve it, and verify the final state rather than treating the edit as a runtime failure.
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
