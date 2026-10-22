"""Regression checks for preflight orchestration, without downloads or browsers."""

import json
import os
import time

from preflight_history import recent_runs, render
from pathlib import Path
import subprocess
import tempfile
import unittest


class PreflightTest(unittest.TestCase):
    def shell(self, body, *args, shell="/bin/bash"):
        script = Path(__file__).with_name("check_all_demos.sh").resolve()
        return subprocess.run([
            shell, "-c", 'preflight_script="$1"; shift; source "$preflight_script"; ' + body,
            "test-preflight", str(script), *map(str, args),
        ], capture_output=True, text=True, timeout=30)

    def test_gradle_launcher_failure_cannot_reuse_results(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            demo = root / "demo"
            results = demo / "build/test-results/test"
            results.mkdir(parents=True)
            (results / "TEST-demo.xml").write_text(
                '<testsuite><testcase classname="demo" name="passes"/></testsuite>')
            launcher = demo / "gradlew"
            launcher.write_text("#!/bin/sh\necho 'wrapper unavailable' >&2\nexit 1\n")
            launcher.chmod(0o755)
            # Source with no arguments, since the preflight parses its CLI on load.
            result = self.shell(f'''
repo_root={str(root)!r}
java() {{ :; }}
run_java_demo demo
''')
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("no test results were found", result.stdout)
            self.assertFalse(list(results.glob("*.xml")))

    def test_online_success_requires_offline_success(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            result = self.shell(f'''
repo_root={str(root)!r}
allow_codex_prompt=false
is_online() {{ return 0; }}
for function in bootstrap_nvm bootstrap_sdkman bootstrap_mise bootstrap_pnpm \\
    check_root_layout check_runtimes prepare_docker prepare_docker_images \\
    prepare_node_dependencies prepare_artillery_tools check_terminal_artillery \\
    run_java_demo run_jest_demo run_webdriverio \\
    run_artillery run_pumba check_worktree check_terminal_report; do
    eval "$function() {{ return 0; }}"
done
run_offline_verification() {{ echo 'simulated offline failure'; return 1; }}
main
''')
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn("Offline readiness: offline verification failed", result.stdout)
            statuses = list((root / ".git/testing-toolbox-preflight").glob("*/status.txt"))
            self.assertEqual([p.read_text().strip() for p in statuses], ["failed"])

    def test_preflight_rejects_broken_terminal_report_command(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            result = self.shell(f'''
repo_root={str(root)!r}
allow_codex_prompt=false
is_online() {{ return 1; }}
for function in bootstrap_nvm bootstrap_sdkman bootstrap_mise bootstrap_pnpm \\
    check_root_layout check_runtimes prepare_docker prepare_docker_images \\
    prepare_node_dependencies prepare_artillery_tools check_terminal_artillery \\
    run_java_demo run_jest_demo run_webdriverio \\
    run_artillery run_pumba check_worktree; do
    eval "$function() {{ return 0; }}"
done
check_terminal_report() {{ reason 'caller pnpm ENOEXEC'; }}
main
''')
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn("Terminal report command: caller pnpm ENOEXEC", result.stdout)

    def test_report_probe_uses_callers_launcher(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "webdriverio").mkdir()
            for name, output in [("caller", "caller ENOEXEC"), ("bootstrap", "wrong launcher")]:
                folder = root / name
                folder.mkdir()
                cli = folder / "pnpm"
                cli.write_text(f"#!/bin/sh\necho '{output}' >&2\nexit 126\n")
                cli.chmod(0o755)
            result = self.shell(f'''
repo_root={str(root)!r}
temp_root="$repo_root"
diagnostic_root="$repo_root"
prepared_report_dir="$repo_root/webdriverio/allure-report"
original_path="$repo_root/caller:$PATH"
export PATH="$repo_root/bootstrap:$PATH"
check_terminal_report
''')
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("caller ENOEXEC", result.stderr)
            self.assertNotIn("wrong launcher", result.stderr)
            self.assertIn("pnpm run report failed in the caller's environment", result.stderr)

    def test_reconnect_preserves_original_offline_mode(self):
        result = self.shell('''
offline=true
internet_is_reachable() { return 0; }
wait_for_reconnect
[[ "$offline" == true ]]
''')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_no_codex_overrides_automatic_repair(self):
        script = Path(__file__).with_name("check_all_demos.sh").resolve()
        result = subprocess.run([
            "bash", "-c", 'source "$1" --fix-with-codex --no-codex; '
            '[[ "$fix_with_codex" == false && "$allow_codex_prompt" == false ]]',
            "test-preflight", str(script),
        ], capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_repair_exit_zero_does_not_override_failed_verification(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            codex = root / "codex"
            codex.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\necho "repair-mode=${TESTING_TOOLBOX_OFFLINE-unset}"\ncat >/dev/null\nexit 0\n')
            codex.chmod(0o755)
            rerun = root / "rerun"
            rerun.write_text('#!/bin/sh\necho "verification $*"\nexit 1\n')
            rerun.chmod(0o755)
            result = self.shell(f'''
export TESTING_TOOLBOX_OFFLINE=true
diagnostic_root={str(root)!r}
codex_log="$diagnostic_root/codex-repair.log"
script_path="$diagnostic_root/rerun"
find_codex() {{ printf '%s\\n' "$diagnostic_root/codex"; }}
write_codex_prompt() {{ echo test >"$1"; }}
offer_codex_fix true
''')
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertIn("--yolo", result.stdout)
            self.assertIn("repair-mode=unset", result.stdout)
            self.assertIn("verification --no-codex", result.stdout)

    def test_offline_selects_installed_pnpm_before_old_path_entry(self):
        script = Path(__file__).with_name("check_all_demos.sh").resolve()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, version in [("old", "10.25.0"), ("node", "12.13.0")]:
                folder = root / name
                folder.mkdir()
                cli = folder / "pnpm"
                cli.write_text(f"#!/bin/sh\necho {version}\n")
                cli.chmod(0o755)
            (root / "prefix").mkdir()
            (root / "prefix/bin").symlink_to(root / "node", target_is_directory=True)
            result = subprocess.run([
                "bash", "-c", '''
preflight_script="$1"
fixture="$2"
set --
source "$preflight_script"
offline=true
export PATH="$fixture/old:$fixture/node:$PATH"
node() { printf '12.13.0\\n'; }
npm() { printf '%s\\n' "$fixture/prefix"; }
# Mimic npm's actual global prefix layout.
bootstrap_pnpm
[[ ${#setup_problems[@]} -eq 0 ]] && [[ "$(pnpm --version)" == 12.13.0 ]]
''', "test-preflight", str(script), str(root),
            ], capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_nvm_bin_precedes_an_existing_earlier_runtime(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("old", "nvm"):
                (root / name).mkdir()
                node = root / name / "node"
                node.write_text("#!/bin/sh\necho v24.0.0\n")
                node.chmod(0o755)
            result = self.shell(f'''
fixture={str(root)!r}
offline=true
export PATH="$fixture/old:$fixture/nvm:$PATH"
nvm() {{ export NVM_BIN="$fixture/nvm"; }}
expected_node_major() {{ printf '24\\n'; }}
bootstrap_nvm
[[ "$(command -v node)" == "$fixture/nvm/node" ]]
''')
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_global_tools_offline_never_installs_and_uses_pnpm_bin(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "bin").mkdir()
            for name in ("artillery", "json-server"):
                cli = root / "bin" / name
                cli.write_text("#!/bin/sh\necho ready\n")
                cli.chmod(0o755)
            body = f'''
export PNPM_HOME={str(root)!r}
offline=true
pnpm() {{ touch "$PNPM_HOME/unexpected-download"; return 99; }}
prepare_artillery_tools
[[ "$(command -v artillery)" == "$PNPM_HOME/bin/artillery" ]] &&
[[ ${{#setup_problems[@]}} -eq 0 ]]
'''
            result = self.shell(body)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertFalse((root / "unexpected-download").exists())
            (root / "bin/artillery").write_text("#!/bin/sh\nexit 126\n")
            broken = self.shell(body)
            self.assertNotEqual(broken.returncode, 0)
            self.assertIn("reconnect and rerun preparation", broken.stderr)
            self.assertFalse((root / "unexpected-download").exists())

    def test_global_tools_online_installs_with_pnpm(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            result = self.shell(f'''
export PNPM_HOME={str(root)!r}
offline=false
pnpm() {{ printf '%s\\n' "$@" >"$PNPM_HOME/install-args"; }}
artillery() {{ return 0; }}
json-server() {{ return 0; }}
prepare_artillery_tools
[[ ${{#setup_problems[@]}} -eq 0 ]]
''')
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            args = (root / "install-args").read_text().splitlines()
            self.assertEqual(args[:3], ["add", "-g", "--ignore-scripts"])
            self.assertEqual({arg.split("@")[0] for arg in args[3:]}, {"artillery", "json-server"})

    def test_pumba_uses_daemon_socket_override(self):
        script = Path(__file__).with_name("check_all_demos.sh")
        result = subprocess.run([
            "bash", "-c", '''
preflight_script="$1"
set --
source "$preflight_script"
export DOCKER_CONTEXT=tcd
export DOCKER_HOST=unix:///Users/example/.colima/default/docker.sock
export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock
docker_socket_path
''', "test-preflight", str(script),
        ], capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "/var/run/docker.sock")

    def test_pumba_runs_with_system_bash_and_default_socket(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.shell(f'''
export temp_root={directory!r}
export DOCKER_CONTEXT=tcd
docker_ready() {{ return 0; }}
docker_socket_path() {{ echo /var/run/docker.sock; }}
docker() {{
    case "$1" in
        logs) echo '64 bytes from target: time=3000 ms' ;;
        network)
            if [[ "$2" == create ]]; then echo exact-network-id; fi ;;
        run)
            printf '%s\\n' "$@" >>"$temp_root/container-args"
            case "$*" in
                *gaiaadm/pumba*) printf '%s\\n' "$@" >"$temp_root/pumba-args" ;;
            esac ;;
    esac
    return 0
}}
export -f docker
run_pumba
''', shell="/bin/bash")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            args = (Path(directory) / "pumba-args").read_text().splitlines()
            self.assertIn("/var/run/docker.sock:/var/run/docker.sock", args)
            self.assertIn("--pull-image=false", args)
            container_args = (Path(directory) / "container-args").read_text()
            self.assertEqual(container_args.count("--network\nexact-network-id\n"), 2)

    def test_pumba_cleanup_removes_only_selected_ids_and_can_repeat(self):
        cleanup = Path(__file__).resolve().parents[2] / "pumba/cleanup.sh"
        with tempfile.TemporaryDirectory() as directory:
            result = self.shell(f'''
export fixture={directory!r}
docker() {{
    case "$*" in
        'ps --all --quiet --filter label=testing-toolbox.pumba=presentation')
            [[ -f "$fixture/container-removed" ]] || echo container-id ;;
        'rm --force container-id') touch "$fixture/container-removed" ;;
        'network ls --quiet --filter label=testing-toolbox.pumba=presentation')
            [[ -f "$fixture/network-one" ]] || echo network-one
            [[ -f "$fixture/network-two" ]] || echo network-two ;;
        'network rm network-one') touch "$fixture/network-one" ;;
        'network rm network-two') touch "$fixture/network-two" ;;
        *) echo "unexpected Docker operation: $*" >&2; return 99 ;;
    esac
    return 0
}}
export -f docker
/bin/bash {str(cleanup)!r} && /bin/bash {str(cleanup)!r}
''')
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(sorted(p.name for p in Path(directory).iterdir()),
                             ["container-removed", "network-one", "network-two"])

    def test_launcher_failure_cannot_reuse_allure_results(self):
        script = Path(__file__).with_name("check_all_demos.sh")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            raw = root / "webdriverio/_results_/allure-raw"
            raw.mkdir(parents=True)
            (root / "webdriverio/allure-report/history").mkdir(parents=True)
            for index, (name, status, message) in enumerate([
                ("should login with valid credentials", "passed", ""),
                ("should login with valid credentials failing", "failed", "deliberate failure"),
                ("should login with valid credentials sometimes", "failed", "Random failure triggered"),
            ]):
                (raw / f"{index}-result.json").write_text(json.dumps({
                    "name": name, "fullName": name, "status": status,
                    "statusDetails": {"message": message},
                }))
            result = subprocess.run([
                "bash", "-c", '''
preflight_script="$1"
fixture="$2"
set --
source "$preflight_script"
repo_root="$fixture"
temp_root="$fixture"
pnpm() {
    printf 'WDIO_HEADLESS=%s\n' "${WDIO_HEADLESS-unset}"
    echo "Simulated launcher failure" >&2
    return 126
}
run_webdriverio
''', "test-preflight", str(script), str(root),
            ], capture_output=True, text=True, timeout=30)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("WDIO_HEADLESS=true", result.stderr)
            self.assertIn("no test results were found", result.stdout)
            self.assertNotIn("WebDriverIO history run 2", result.stdout)
            self.assertFalse(list(raw.glob("*-result.json")))


class CheckResultsTest(unittest.TestCase):
    def test_cp1252_console_keeps_unicode_job_summary(self):
        script = Path(__file__).with_name("check_results.py").resolve()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            report = root / "artillery.json"
            report.write_text(json.dumps({"aggregate": {"counters": {
                "http.requests": 1,
                "http.codes.200": 1,
                "vusers.failed": 0,
            }}}), encoding="utf-8")
            summary = root / "summary.md"
            env = os.environ.copy()
            env["PYTHONIOENCODING"] = "cp1252"
            env["GITHUB_STEP_SUMMARY"] = str(summary)

            result = subprocess.run([
                "python3", str(script), "--format", "artillery",
                "--path", str(report), "--title", "artillery",
            ], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)

            self.assertEqual(result.returncode, 0, result.stderr.decode("cp1252"))
            self.assertIn("OK: 4 result(s) checked", result.stdout.decode("cp1252"))
            self.assertIn("✅", summary.read_text(encoding="utf-8"))

    def test_cp1252_console_handles_unicode_failure_annotation(self):
        script = Path(__file__).with_name("check_results.py").resolve()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            report = root / "artillery.json"
            report.write_text(json.dumps({"aggregate": {"counters": {
                "http.requests": 1,
                "http.codes.200": 1,
                "vusers.failed": 0,
                "errors.💥": 1,
            }}}), encoding="utf-8")
            summary = root / "summary.md"
            env = os.environ.copy()
            env["PYTHONIOENCODING"] = "cp1252"
            env["GITHUB_STEP_SUMMARY"] = str(summary)

            result = subprocess.run([
                "python3", str(script), "--format", "artillery",
                "--path", str(report), "--title", "artillery",
            ], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)

            self.assertEqual(result.returncode, 1, result.stderr.decode("cp1252"))
            self.assertNotIn("UnicodeEncodeError", result.stderr.decode("cp1252"))
            self.assertIn(r"errors.\U0001f4a5", result.stdout.decode("cp1252"))
            self.assertIn("💥", summary.read_text(encoding="utf-8"))


class HistoryTest(unittest.TestCase):
    def test_repeated_legacy_failures_keep_original_mode_and_prior_outcome(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            repo = (root / "repo").resolve()
            for name in ("one", "two"):
                run = root / f"testing-toolbox-preflight-log.{name}"
                run.mkdir()
                (run / "preflight.log").write_text(
                    f"Repository: {repo}\nOffline mode.\nSetup problem: old pnpm\n"
                    "== Summary ==\nFailed checks:\n  - Jest\nDiagnostic logs: elsewhere\n"
                    "== Codex repair ==\nInternet access detected.\nAll demos are prepared and checked.\n")
                (run / "codex-last-message.txt").write_text("Claimed fixed after online run")
            runs = recent_runs(repo, root / "current", [root])
            self.assertEqual(len(runs), 2)
            self.assertTrue(all(run[2:4] == ("failed", "offline") for run in runs))
            report = render(runs)
            self.assertIn("2 runs: Setup problem: old pnpm", report)
            self.assertIn("Claimed fixed after online run", report)
            self.assertNotIn("All demos are prepared and checked", report)

    def test_history_filters_age_checkout_current_and_limits_count(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            repo = root / "repo"
            now = time.time()
            for index in range(16):
                run = root / f"run-{index}"
                run.mkdir()
                (run / "repository.txt").write_text(str(repo if index != 0 else root / "other"))
                log = run / "preflight.log"
                log.write_text("Offline mode.\nProblem: missing cache\n")
                os.utime(log, (now - index, now - index))
            old = root / "run-1/preflight.log"
            os.utime(old, (now - 49 * 3600, now - 49 * 3600))
            runs = recent_runs(repo, root / "run-2", [root, root], now)
            self.assertEqual(len(runs), 12)
            self.assertEqual(runs[0][1].name, "run-3")
            self.assertNotIn(root / "run-0", [run[1] for run in runs])


if __name__ == "__main__":
    unittest.main()
