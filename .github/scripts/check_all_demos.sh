#!/usr/bin/env bash

# Prepare this machine for the demos, run every demo that can run in the
# current environment, and report every problem together at the end.

set -u
set -o pipefail

script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
checker="$repo_root/.github/scripts/check_results.py"
pumba_nettools_image="ghcr.io/alexei-led/pumba-alpine-nettools:latest"
fix_with_codex=false
allow_codex_prompt=true
offline=false
use_nvm=false
use_sdkman=false
codex_bin=""
temp_parent=""
temp_root=""
diagnostic_root=""
preflight_log=""
codex_log=""
interactive_terminal=false
terminal_state=""
last_reason=""
passed=()
failed=()
setup_problems=()
not_checked=()
root_demos=(
    artillery
    jest-fail-on-console
    jest-msw
    jest-parameterized
    junit-assertj
    junit-awaitility
    junit-datafaker
    junit-instancio
    junit-mockito
    junit-mockserver
    junit-parameterized
    junit-pioneer
    junit-testcontainers-toxiproxy
    pumba
    webdriverio
)

usage() {
    printf '%s\n' \
        'Usage: .github/scripts/check_all_demos.sh [--fix-with-codex] [--no-codex]' \
        '' \
        'Prepares and checks every presentation demo. Set' \
        'TESTING_TOOLBOX_OFFLINE=true to verify the cached offline state.' \
        '' \
        '  --fix-with-codex  Run Codex non-interactively with --yolo after a failure' \
        '  --no-codex       Never prompt or invoke Codex (intended for agents)' \
        '  --help           Show this help'
}

original_args=("$@")
while [[ $# -gt 0 ]]; do
    case "$1" in
        --fix-with-codex) fix_with_codex=true ;;
        --no-codex) allow_codex_prompt=false ;;
        --help|-h) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

cleanup() {
    [[ -n "$temp_parent" && -n "$temp_root" && -d "$temp_root" ]] || return
    [[ "$(dirname "$temp_root")" == "$temp_parent" ]] || return
    case "$(basename "$temp_root")" in
        testing-toolbox.??????) rm -rf -- "$temp_root" ;;
    esac
}
trap cleanup EXIT

section() {
    printf '\n== %s ==\n' "$1"
}

reason() {
    last_reason="$1"
    printf 'Problem: %s\n' "$last_reason" >&2
    return 1
}

record() {
    local label="$1"
    shift
    last_reason=""
    section "$label"
    if "$@"; then
        passed+=("$label")
    else
        failed+=("$label${last_reason:+: $last_reason}")
    fi
}

setup_problem() {
    setup_problems+=("$1")
    printf 'Setup problem: %s\n' "$1" >&2
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

is_registered_root_demo() {
    local candidate="$1" demo
    for demo in "${root_demos[@]}"; do
        [[ "$candidate" == "$demo" ]] && return 0
    done
    return 1
}

check_root_layout() {
    local path demo
    for path in "$repo_root"/*/; do
        demo="$(basename "$path")"
        if ! is_registered_root_demo "$demo"; then
            reason "visible root directory '$demo' is not registered as a runnable demo"
            return
        fi
        if [[ ! -f "$path/README.md" ]]; then
            reason "visible root demo '$demo' has no README.md with its run instructions"
            return
        fi
    done
    for demo in "${root_demos[@]}"; do
        if [[ ! -d "$repo_root/$demo" ]]; then
            reason "registered root demo '$demo' is missing"
            return
        fi
    done
    return 0
}

is_online() {
    if [[ "${TESTING_TOOLBOX_OFFLINE:-false}" == "true" ]]; then
        return 1
    fi
    curl --head --silent --fail --max-time 8 https://registry.npmjs.org/ >/dev/null 2>&1
}

internet_is_reachable() {
    curl --head --silent --fail --max-time 8 https://registry.npmjs.org/ >/dev/null 2>&1
}

expected_java_major() {
    awk '$1 == "java" {sub(/^temurin-/, "", $2); print $2}' "$repo_root/.tool-versions"
}

expected_node_major() {
    awk '$1 == "nodejs" {print $2}' "$repo_root/.tool-versions"
}

java_is_expected_temurin() {
    command_exists java || return 1
    local java_expected java_output
    java_expected="$(expected_java_major)"
    java_output="$(java -XshowSettings:properties -version 2>&1)" || return 1
    printf '%s\n' "$java_output" | grep -Eq "java[.]version = ${java_expected}([.]|$)" &&
        printf '%s\n' "$java_output" | grep -Eqi 'Eclipse Adoptium|Temurin'
}

node_is_expected_major() {
    command_exists node || return 1
    [[ "$(node --version | sed 's/^v//; s/[.].*$//')" == "$(expected_node_major)" ]]
}

bootstrap_nvm() {
    if ! command_exists nvm; then
        local nvm_dir="${NVM_DIR:-${HOME}/.nvm}"
        local nvm_script="" candidate
        for candidate in "$nvm_dir/nvm.sh" /opt/homebrew/opt/nvm/nvm.sh /usr/local/opt/nvm/nvm.sh; do
            if [[ -s "$candidate" ]]; then
                nvm_script="$candidate"
                break
            fi
        done
        if [[ -n "$nvm_script" ]]; then
            # nvm is a shell function, so scripts must load it explicitly.
            NVM_DIR="$nvm_dir"
            export NVM_DIR
            # shellcheck source=/dev/null
            . "$nvm_script"
        fi
    fi
    command_exists nvm || return
    use_nvm=true
    [[ "${TESTING_TOOLBOX_NVM_ACTIVE:-false}" == "true" ]] && return

    local node_expected
    node_expected="$(expected_node_major)"
    section "Install pinned Node.js with nvm"
    if [[ "$offline" == true ]]; then
        if ! nvm use "$node_expected"; then
            setup_problem "nvm does not have Node.js $node_expected cached"
            return
        fi
    elif ! nvm install "$node_expected"; then
        setup_problem "nvm could not install Node.js $node_expected"
        return
    fi
    if ! node_is_expected_major; then
        setup_problem "nvm did not activate Node.js $node_expected"
        return
    fi
    export TESTING_TOOLBOX_NVM_ACTIVE=true
}

load_sdkman() {
    command_exists sdk && return 0
    local sdkman_dir="${SDKMAN_DIR:-${HOME}/.sdkman}"
    [[ -s "$sdkman_dir/bin/sdkman-init.sh" ]] || return 1
    SDKMAN_DIR="$sdkman_dir"
    export SDKMAN_DIR
    # SDKMAN! is implemented as shell functions, so scripts must load it explicitly.
    # Its init script probes optional shell variables without nounset-safe defaults.
    # shellcheck source=/dev/null
    set +u
    . "$sdkman_dir/bin/sdkman-init.sh"
    local sdk_exit=$?
    set -u
    [[ "$sdk_exit" -eq 0 ]] && command_exists sdk
}

sdkman_command() {
    # SDKMAN! functions also read optional variables without nounset-safe defaults.
    set +u
    sdk "$@"
    local sdk_exit=$?
    set -u
    return "$sdk_exit"
}

cached_sdkman_temurin() {
    local sdkman_dir="$1" java_expected="$2" candidate
    for candidate in \
        "$sdkman_dir"/candidates/java/"$java_expected"-tem \
        "$sdkman_dir"/candidates/java/"$java_expected".*-tem; do
        if [[ -d "$candidate" ]]; then
            basename "$candidate"
            return
        fi
    done
    return 1
}

available_sdkman_temurin() {
    local java_expected="$1"
    sdkman_command list java 2>/dev/null | awk -F '|' -v major="$java_expected" '
        {
            identifier = $NF
            gsub(/[[:space:]]/, "", identifier)
            if (identifier ~ ("^" major "([.][[:alnum:].+_-]+)?-tem$")) {
                print identifier
                exit
            }
        }
    '
}

bootstrap_sdkman() {
    java_is_expected_temurin && return

    load_sdkman || true
    if ! command_exists sdk && [[ "$use_nvm" == false ]]; then
        return
    fi

    # When nvm owns Node.js, SDKMAN! owns Java. Do not install a second
    # multi-runtime manager solely to provide Temurin.
    use_sdkman=true
    local sdkman_dir="${SDKMAN_DIR:-${HOME}/.sdkman}"
    if ! command_exists sdk; then
        if [[ "$offline" == true ]]; then
            setup_problem "SDKMAN! is unavailable and Eclipse Temurin is not active"
            return
        fi
        section "Install SDKMAN!"
        local installer="$temp_root/sdkman-install.sh"
        if ! curl --fail --location --silent --show-error \
            'https://get.sdkman.io?ci=true&rcupdate=false' --output "$installer" ||
            ! bash "$installer" || ! load_sdkman; then
            setup_problem "SDKMAN! is missing and its installer failed"
            return
        fi
    fi

    local java_expected candidate
    java_expected="$(expected_java_major)"
    if [[ "$offline" == true ]]; then
        candidate="$(cached_sdkman_temurin "$sdkman_dir" "$java_expected" || true)"
    else
        candidate="$(available_sdkman_temurin "$java_expected" || true)"
        if [[ -z "$candidate" ]]; then
            candidate="$(cached_sdkman_temurin "$sdkman_dir" "$java_expected" || true)"
        fi
    fi
    if [[ -z "$candidate" ]]; then
        setup_problem "SDKMAN! has no Eclipse Temurin $java_expected candidate available"
        return
    fi

    section "Install pinned Eclipse Temurin with SDKMAN!"
    if [[ "$offline" == false && ! -d "$sdkman_dir/candidates/java/$candidate" ]]; then
        local previous_auto_answer="${sdkman_auto_answer-}"
        sdkman_auto_answer=true
        if ! sdkman_command install java "$candidate" < <(printf 'n\n'); then
            setup_problem "SDKMAN! could not install Eclipse Temurin $candidate"
            if [[ -n "$previous_auto_answer" ]]; then
                sdkman_auto_answer="$previous_auto_answer"
            else
                unset sdkman_auto_answer
            fi
            return
        fi
        if [[ -n "$previous_auto_answer" ]]; then
            sdkman_auto_answer="$previous_auto_answer"
        else
            unset sdkman_auto_answer
        fi
    fi
    if ! sdkman_command use java "$candidate" >/dev/null || ! java_is_expected_temurin; then
        setup_problem "SDKMAN! could not activate Eclipse Temurin $candidate"
    fi
}

bootstrap_mise() {
    [[ "${TESTING_TOOLBOX_MISE_ACTIVE:-false}" == "true" ]] && return

    local java_expected node_expected
    java_expected="$(expected_java_major)"
    node_expected="$(expected_node_major)"
    local runtimes=()
    if [[ "$use_sdkman" == false ]] && ! java_is_expected_temurin; then
        runtimes+=("java@temurin-$java_expected")
    fi
    if [[ "$use_nvm" == false ]] && ! node_is_expected_major; then
        runtimes+=("node@$node_expected")
    fi
    [[ ${#runtimes[@]} -gt 0 ]] || return 0

    local mise_bin=""
    if command_exists mise; then
        mise_bin="$(command -v mise)"
    elif [[ -x "${HOME}/.local/bin/mise" ]]; then
        mise_bin="${HOME}/.local/bin/mise"
    elif [[ "$offline" == false ]]; then
        section "Install mise"
        local installer="$temp_root/mise-install.sh"
        if curl --fail --location --silent --show-error https://mise.run --output "$installer" &&
            sh "$installer"; then
            mise_bin="${HOME}/.local/bin/mise"
        else
            setup_problem "mise is missing and its installer failed"
        fi
    else
        setup_problem "mise is missing and cannot be installed while offline"
    fi
    [[ -n "$mise_bin" && -x "$mise_bin" ]] || return

    section "Install pinned runtimes with mise"
    local runtime
    if [[ "$offline" == true ]]; then
        for runtime in "${runtimes[@]}"; do
            if ! "$mise_bin" where "$runtime" >/dev/null 2>&1; then
                setup_problem "mise does not have $runtime cached"
                return
            fi
        done
    else
        for runtime in "${runtimes[@]}"; do
            if ! "$mise_bin" install "$runtime"; then
                setup_problem "mise could not install $runtime"
                return
            fi
        done
    fi

    export TESTING_TOOLBOX_MISE_ACTIVE=true
    "$mise_bin" exec "${runtimes[@]}" -- "$script_path" "${original_args[@]}"
    exit $?
}

check_runtimes() {
    local java_expected node_expected java_output node_actual
    java_expected="$(expected_java_major)"
    node_expected="$(expected_node_major)"

    if ! command_exists java; then
        setup_problem "Java is unavailable; expected Eclipse Temurin $java_expected"
    else
        java_output="$(java -XshowSettings:properties -version 2>&1)"
        if ! printf '%s\n' "$java_output" | grep -Eq "java\.version = ${java_expected}([.]|$)"; then
            setup_problem "Java does not match the pinned major $java_expected"
        fi
        if ! printf '%s\n' "$java_output" | grep -Eqi 'Eclipse Adoptium|Temurin'; then
            setup_problem "Java is not an Eclipse Temurin build"
        fi
    fi

    if ! command_exists node; then
        setup_problem "Node.js is unavailable; expected major $node_expected"
    else
        node_actual="$(node --version | sed 's/^v//; s/[.].*$//')"
        if [[ "$node_actual" != "$node_expected" ]]; then
            setup_problem "Node.js major is $node_actual; expected $node_expected"
        fi
    fi

    if ! command_exists python3; then
        setup_problem "python3 is unavailable, so demo result files cannot be checked"
    fi
}

select_testcontainers_desktop_context() {
    [[ "$(uname -s)" == "Darwin" ]] || return 1
    [[ -z "${DOCKER_HOST:-}" && -z "${DOCKER_CONTEXT:-}" ]] || return 1
    local context endpoint
    for context in tcc tcd; do
        if docker context inspect "$context" >/dev/null 2>&1 && \
            docker --context "$context" info >/dev/null 2>&1; then
            export DOCKER_CONTEXT="$context"
            endpoint="$(docker context inspect "$context" --format '{{.Endpoints.docker.Host}}')"
            if [[ "$endpoint" == unix://* || "$endpoint" == tcp://* ]]; then
                export DOCKER_HOST="$endpoint"
            fi
            printf 'Using Testcontainers Desktop Docker context: %s\n' "$context"
            return 0
        fi
    done
    return 1
}

prepare_docker() {
    if ! command_exists docker && [[ "$(uname -s)" == "Darwin" && "$offline" == false ]] && command_exists brew; then
        if open -Ra 'Testcontainers Desktop' >/dev/null 2>&1; then
            section "Install the Docker command-line client"
            if ! brew install docker; then
                setup_problem "Homebrew could not install the Docker command-line client"
            fi
        else
            section "Install Docker Desktop"
            if ! brew install --cask docker; then
                setup_problem "Homebrew could not install Docker Desktop"
            fi
        fi
    fi

    if ! command_exists docker; then
        setup_problem "Docker is unavailable; the Testcontainers and Pumba demos cannot run"
        return
    fi

    select_testcontainers_desktop_context || true
    if ! docker info >/dev/null 2>&1 && [[ "$(uname -s)" == "Darwin" ]] && \
        open -Ra 'Testcontainers Desktop' >/dev/null 2>&1; then
        section "Start Testcontainers Desktop"
        open -a 'Testcontainers Desktop' >/dev/null 2>&1 || true
        local attempt
        for attempt in $(seq 1 45); do
            select_testcontainers_desktop_context >/dev/null 2>&1 && break
            sleep 1
        done
    fi
    if ! docker info >/dev/null 2>&1 && [[ "$(uname -s)" == "Darwin" ]] && \
        open -Ra Docker >/dev/null 2>&1; then
        section "Start Docker Desktop"
        open -a Docker >/dev/null 2>&1 || true
        local attempt
        for attempt in $(seq 1 60); do
            docker info >/dev/null 2>&1 && break
            sleep 1
        done
    fi

    if ! docker info >/dev/null 2>&1; then
        setup_problem "the Docker client is installed, but its daemon is unavailable"
        return
    fi

    local podman_socket=""
    if [[ ! -S /var/run/docker.sock || ! -w /var/run/docker.sock ]] && command_exists podman; then
        podman_socket="$(podman info --format '{{.Host.RemoteSocket.Path}}' 2>/dev/null || true)"
        if [[ -n "$podman_socket" && -S "$podman_socket" ]]; then
            export DOCKER_HOST="unix://$podman_socket"
        fi
    fi
}

docker_ready() {
    command_exists docker && docker info >/dev/null 2>&1
}

cache_image() {
    local image="$1"
    if [[ "$offline" == true ]]; then
        docker image inspect "$image" >/dev/null 2>&1 || {
            setup_problem "Docker image $image is not cached"
            return 1
        }
    elif ! docker pull "$image"; then
        setup_problem "Docker could not pull $image"
        return 1
    fi
}

prepare_docker_images() {
    docker_ready || return
    section "Cache Docker images"
    cache_image "alpine:3.24.1" || true
    cache_image "gaiaadm/pumba:1.2.1" || true
    cache_image "$pumba_nettools_image" || true
    cache_image "redis:8.10.1-alpine" || true
    cache_image "ghcr.io/shopify/toxiproxy:2.12.0" || true

    local client_image="testing-toolbox/pumba-client:3.24.1"
    if [[ "$offline" == true ]]; then
        if ! docker image inspect "$client_image" >/dev/null 2>&1; then
            setup_problem "the Pumba client image with iproute2 is not cached"
        fi
    else
        docker build --pull --tag "$client_image" - <<'DOCKERFILE' || \
            setup_problem "Docker could not build the Pumba client image"
FROM alpine:3.24.1
RUN apk add --no-cache iproute2
DOCKERFILE
    fi
}

npm_ci() {
    local demo="$1"
    local mode="--prefer-online"
    [[ "$offline" == true ]] && mode="--offline"
    (cd "$repo_root/$demo" && npm ci "$mode")
}

prepare_node_dependencies() {
    command_exists npm || return
    local demo
    for demo in jest-fail-on-console jest-msw jest-parameterized webdriverio; do
        section "Install $demo dependencies"
        if ! npm_ci "$demo"; then
            if [[ "$offline" == true ]]; then
                setup_problem "$demo dependencies could not be installed from the local npm cache"
            else
                setup_problem "$demo dependencies could not be installed"
            fi
        fi
    done

    section "Install Artillery tools"
    local mode="--prefer-online"
    [[ "$offline" == true ]] && mode="--offline"
    if [[ "$offline" == true ]] && command_exists artillery && command_exists json-server; then
        printf 'Using cached Artillery and json-server installations.\n'
    elif ! npm install --global "$mode" artillery@latest json-server@latest; then
        setup_problem "Artillery and json-server could not be installed"
    fi
    command_exists artillery || setup_problem "the artillery command is unavailable"
    command_exists json-server || setup_problem "the json-server command is unavailable"
}

run_java_demo() {
    local demo="$1" expect_fail="${2:-}" may_fail="${3:-}"
    if ! command_exists java || ! command_exists python3; then
        reason "Java or python3 is unavailable"
        return
    fi
    if [[ "$demo" == "junit-testcontainers-toxiproxy" ]] && ! docker_ready; then
        reason "Docker is unavailable"
        return
    fi

    local options=()
    [[ "$offline" == true ]] && options+=(--offline)
    (cd "$repo_root/$demo" && ./gradlew clean test --continue --console=plain "${options[@]}") || true
    CHECK_EXPECT_FAIL="$expect_fail" CHECK_MAY_FAIL="$may_fail" \
        python3 "$checker" --format gradle \
        --path "$repo_root/$demo/build/test-results/test" --title "$demo" || \
        reason "the Gradle results did not match the demo's expected behavior"
}

run_jest_demo() {
    local demo="$1" expect_fail="${2:-}"
    if ! command_exists npm || ! command_exists python3; then
        reason "npm or python3 is unavailable"
        return
    fi
    local result="$temp_root/$demo-results.json"
    (cd "$repo_root/$demo" && npm test -- --ci --json --outputFile="$result") || true
    CHECK_EXPECT_FAIL="$expect_fail" python3 "$checker" --format jest \
        --path "$result" --title "$demo" || \
        reason "the Jest results did not match the demo's expected behavior"
}

flaky_status() {
    python3 - "$repo_root/webdriverio/_results_/allure-raw" <<'PY'
import glob
import json
import os
import sys

for path in glob.glob(os.path.join(sys.argv[1], "*-result.json")):
    with open(path, encoding="utf-8") as handle:
        result = json.load(handle)
    if result.get("name") == "should login with valid credentials sometimes":
        print(result.get("status", ""))
        break
PY
}

failed_video_source() {
    python3 - "$repo_root/webdriverio/_results_/allure-raw" <<'PY'
import glob
import json
import os
import sys

for path in glob.glob(os.path.join(sys.argv[1], "*-result.json")):
    with open(path, encoding="utf-8") as handle:
        result = json.load(handle)
    if result.get("name") != "should login with valid credentials failing":
        continue
    attachments = list(result.get("attachments", []))
    for step in result.get("steps", []):
        attachments.extend(step.get("attachments", []))
    for attachment in attachments:
        if attachment.get("type") == "video/webm":
            print(attachment.get("source", ""))
            raise SystemExit
PY
}

verify_flaky_report() {
    local report_dir="$1"
    python3 - "$report_dir" <<'PY'
import glob
import json
import os
import sys

report = sys.argv[1]
history_id = None
marked_flaky = False
for path in glob.glob(os.path.join(report, "data", "test-cases", "*.json")):
    with open(path, encoding="utf-8") as handle:
        result = json.load(handle)
    if result.get("name") == "should login with valid credentials sometimes":
        history_id = result.get("historyId")
        marked_flaky = result.get("flaky") is True
        break
if not history_id:
    raise SystemExit("the random flaky test is missing from the report")
with open(os.path.join(report, "history", "history.json"), encoding="utf-8") as handle:
    history = json.load(handle)
statuses = [item.get("status") for item in history.get(history_id, {}).get("items", [])]
passes = statuses.count("passed")
failures = statuses.count("failed")
if passes < 3 or failures < 3:
    raise SystemExit(f"the random test history has {passes} passes and {failures} failures; expected at least 3 of each")
if not marked_flaky:
    raise SystemExit("Allure did not mark the random test as flaky")
print(f"Verified Allure Flaky mark with history: {passes} passed, {failures} failed")
PY
}

run_webdriverio() {
    local report_dir="$repo_root/webdriverio/allure-report"
    local report="$report_dir/index.html"
    if [[ "$offline" == true ]]; then
        if [[ ! -s "$report" ]] || ! verify_flaky_report "$report_dir"; then
            report_dir="$repo_root/webdriverio/allure-report-reference"
            report="$report_dir/index.html"
        fi
        if [[ ! -s "$report" ]] || ! verify_flaky_report "$report_dir"; then
            reason "neither the generated nor checked-in Allure report marks the random test as flaky with representative history"
            return
        fi
        not_checked+=("webdriverio browser run: the public demo site needs internet; $(basename "$report_dir") is ready")
        printf 'Offline report: %s\n' "$report"
        return 0
    fi
    if ! command_exists npm || ! command_exists java || ! command_exists python3; then
        reason "npm, Java, or python3 is unavailable"
        return
    fi

    mkdir -p "$repo_root/webdriverio/allure-report"
    if [[ ! -d "$repo_root/webdriverio/allure-report/history" ]]; then
        cp -R "$repo_root/webdriverio/allure-report-reference/history" \
            "$repo_root/webdriverio/allure-report/"
    fi

    local headless=false
    if [[ "$(uname -s)" != "Darwin" && -z "${DISPLAY:-}" ]]; then
        headless=true
    fi

    local required_each=3 max_attempts=30 passes=0 failures=0 attempt status run_log
    local all_runs_ok=true
    for attempt in $(seq 1 "$max_attempts"); do
        printf '\nWebDriverIO history run %s of at most %s\n' "$attempt" "$max_attempts"
        run_log="$temp_root/webdriverio-$attempt.log"
        (cd "$repo_root/webdriverio" && \
            WDIO_HEADLESS="$headless" ALLURE_BUILD_OFFSET="$attempt" npm test) \
            >"$run_log" 2>&1 || true
        if ! CHECK_EXPECT_FAIL='should login with valid credentials failing' \
            CHECK_MAY_FAIL='should login with valid credentials sometimes::Random failure triggered' \
            python3 "$checker" --format allure \
            --path "$repo_root/webdriverio/_results_/allure-raw" \
            --title "webdriverio history run $attempt"; then
            tail -n 100 "$run_log" >&2
            all_runs_ok=false
            break
        fi
        status="$(flaky_status)"
        case "$status" in
            passed) passes=$((passes + 1)) ;;
            failed) failures=$((failures + 1)) ;;
            *) all_runs_ok=false; last_reason="the random flaky test had unexpected status '$status'"; break ;;
        esac
        printf 'Random test history from this preparation: %s passed, %s failed\n' "$passes" "$failures"
        if [[ "$passes" -ge "$required_each" && "$failures" -ge "$required_each" ]] && \
            verify_flaky_report "$repo_root/webdriverio/allure-report"; then
            break
        fi
    done

    if [[ "$all_runs_ok" != true ]]; then
        reason "${last_reason:-a WebDriverIO run did not match the expected results}"
        return
    fi
    if [[ "$passes" -lt "$required_each" || "$failures" -lt "$required_each" ]]; then
        reason "the random flaky test did not produce at least $required_each passes and failures in $max_attempts runs"
        return
    fi
    if [[ ! -s "$report" ]]; then
        reason "WebDriverIO did not generate the Allure report"
        return
    fi
    if ! verify_flaky_report "$repo_root/webdriverio/allure-report"; then
        reason "the Allure report does not mark the random test as flaky with representative history"
        return
    fi

    local video_source ffmpeg
    video_source="$(failed_video_source)"
    if [[ -z "$video_source" || ! -s "$repo_root/webdriverio/_results_/allure-raw/$video_source" ]]; then
        reason "the deliberate WebDriverIO failure has no video attachment"
        return
    fi
    ffmpeg="$(find "$repo_root/webdriverio/node_modules/@ffmpeg-installer" -type f -name ffmpeg -perm -u+x 2>/dev/null | head -n 1)"
    if [[ -z "$ffmpeg" ]] || ! "$ffmpeg" -v error \
        -i "$repo_root/webdriverio/_results_/allure-raw/$video_source" -f null -; then
        reason "the deliberate failure's video is not playable"
        return
    fi
    printf 'Presentation report: %s\n' "$report"
}

wait_for_backend() {
    local attempt
    for attempt in $(seq 1 30); do
        curl --silent --fail http://localhost:3000/posts >/dev/null 2>&1 && return 0
        sleep 1
    done
    return 1
}

run_artillery() {
    if ! command_exists artillery || ! command_exists json-server || \
        ! command_exists curl || ! command_exists python3; then
        reason "artillery, json-server, curl, or python3 is unavailable"
        return
    fi
    local backend_log="$temp_root/json-server.log"
    local simple="$temp_root/artillery-simple.json"
    local complex="$temp_root/artillery-complex.json"
    local simple_log="$temp_root/artillery-simple.log"
    local complex_log="$temp_root/artillery-complex.log"
    json-server "$repo_root/artillery/backend/db.json5" >"$backend_log" 2>&1 &
    local backend_pid=$!
    if ! wait_for_backend; then
        kill "$backend_pid" >/dev/null 2>&1 || true
        wait "$backend_pid" >/dev/null 2>&1 || true
        reason "json-server did not start; see $backend_log while the script is running"
        return
    fi

    (cd "$repo_root/artillery" && artillery run \
        --overrides '{"config":{"phases":[{"duration":5,"arrivalRate":5}]}}' \
        --output "$simple" simple.yml) >"$simple_log" 2>&1 || true
    (cd "$repo_root/artillery" && artillery run \
        --overrides '{"config":{"phases":[{"duration":10,"arrivalRate":2}]}}' \
        --output "$complex" complex.yml) >"$complex_log" 2>&1 || true
    kill "$backend_pid" >/dev/null 2>&1 || true
    wait "$backend_pid" >/dev/null 2>&1 || true

    local ok=true
    if ! python3 "$checker" --format artillery --path "$simple" \
        --title 'artillery simple.yml'; then
        tail -n 100 "$simple_log" >&2
        ok=false
    fi
    if ! python3 "$checker" --format artillery --path "$complex" \
        --title 'artillery complex.yml'; then
        tail -n 100 "$complex_log" >&2
        ok=false
    fi
    [[ "$ok" == true ]] || reason "the Artillery reports did not contain healthy requests and responses"
}

docker_socket_path() {
    local host="${DOCKER_HOST:-}" context="${DOCKER_CONTEXT:-}"
    [[ -n "$context" ]] || context="$(docker context show 2>/dev/null || true)"
    if [[ "$host" == unix://* ]]; then
        printf '%s\n' "${host#unix://}"
        return
    fi
    host="$(docker context inspect --format '{{.Endpoints.docker.Host}}' 2>/dev/null || true)"
    if [[ "$host" == unix://* ]]; then
        printf '%s\n' "${host#unix://}"
    elif [[ "$host" == tcp://* && ("$context" == tcc || "$context" == tcd) ]]; then
        # Docker resolves bind sources inside Testcontainers Desktop's Linux runtime.
        printf '%s\n' /var/run/docker.sock
    elif [[ -S /var/run/docker.sock ]]; then
        printf '%s\n' /var/run/docker.sock
    fi
}

run_pumba() {
    if ! docker_ready; then
        reason "Docker is unavailable"
        return
    fi
    local socket context
    socket="$(docker_socket_path)"
    context="${DOCKER_CONTEXT:-$(docker context show 2>/dev/null || true)}"
    if [[ -z "$socket" ]] || \
        [[ ! -S "$socket" && "$context" != tcc && "$context" != tcd ]]; then
        reason "the Docker Unix socket could not be found for Pumba"
        return
    fi

    local suffix network target client log
    suffix="$(basename "$temp_root" | tr -cd '[:alnum:]')"
    network="toolbox-chaos-$suffix"
    target="toolbox-target-$suffix"
    client="toolbox-client-$suffix"
    log="$temp_root/ping.log"
    local network_created=false target_created=false client_created=false ok=true

    if docker network create "$network"; then
        network_created=true
    else
        ok=false
        last_reason="Docker could not create the Pumba demo network"
    fi
    if [[ "$ok" == true ]] && docker run --pull=never -d --name "$target" \
        --network "$network" alpine:3.24.1 sleep 600; then
        target_created=true
    else
        [[ -n "$last_reason" ]] || last_reason="Docker could not start the Pumba target"
        ok=false
    fi
    if [[ "$ok" == true ]] && docker run --pull=never -d --name "$client" \
        --network "$network" testing-toolbox/pumba-client:3.24.1 ping "$target"; then
        client_created=true
    else
        [[ -n "$last_reason" ]] || last_reason="Docker could not start the Pumba ping client"
        ok=false
    fi

    local attempt
    if [[ "$ok" == true ]]; then
        for attempt in $(seq 1 30); do
            docker logs "$client" 2>&1 | grep -q 'bytes from' && break
            sleep 1
        done
        if ! docker logs "$client" 2>&1 | grep -q 'bytes from'; then
            last_reason="the Pumba client did not start receiving ping replies"
            ok=false
        fi
    fi
    local socket_options=()
    if [[ "$socket" == *podman* ]]; then
        socket_options+=(--security-opt label=disable)
    fi
    if [[ "$ok" == true ]] && ! docker run --pull=never --rm \
        "${socket_options[@]}" -v "$socket:/var/run/docker.sock" gaiaadm/pumba:1.2.1 \
        netem --duration 15s --tc-image "$pumba_nettools_image" --pull-image=false \
        delay --time 3000 "$client"; then
        last_reason="Pumba could not apply the network delay"
        ok=false
    fi
    if [[ "$client_created" == true ]]; then
        docker logs "$client" >"$log" 2>&1 || true
    fi

    [[ "$client_created" == true ]] && docker rm -f "$client" >/dev/null 2>&1 || true
    [[ "$target_created" == true ]] && docker rm -f "$target" >/dev/null 2>&1 || true
    [[ "$network_created" == true ]] && docker network rm "$network" >/dev/null 2>&1 || true

    if [[ "$ok" == true ]] && ! grep -qE \
        'time=([3-9][0-9]{3}|[1-9][0-9]{4,})([.][0-9]+)? ms' "$log"; then
        last_reason="the ping log did not contain a delay of at least 3 seconds"
        ok=false
    fi
    [[ "$ok" == true ]] || reason "$last_reason"
}

check_worktree() {
    local after_status
    after_status="$(git -C "$repo_root" status --porcelain=v1 --untracked-files=all)"
    if [[ "$after_status" != "$before_status" ]]; then
        printf '%s\n' 'Worktree before the run:' "$before_status" \
            'Worktree after the run:' "$after_status" >&2
        reason "the checks changed tracked or untracked repository files"
    fi
}

print_items() {
    local heading="$1"
    shift
    printf '%s\n' "$heading"
    if [[ $# -eq 0 ]]; then
        printf '  (none)\n'
        return
    fi
    local item
    for item in "$@"; do
        printf '  - %s\n' "$item"
    done
}

write_codex_prompt() {
    local prompt_file="$1"
    local attempt
    for attempt in $(seq 1 50); do
        grep -Fq 'The preparation is incomplete.' "$preflight_log" 2>/dev/null && break
        sleep 0.1
    done
    {
        printf '%s\n' \
            'Get this testing-toolbox presentation environment ready. The preflight below ran and found problems.' \
            '' \
            "Repository: $repo_root" \
            "Machine: $(uname -a)" \
            "Offline mode: $offline" \
            '' \
            'Setup problems:'
        local item
        for item in "${setup_problems[@]}"; do printf -- '- %s\n' "$item"; done
        [[ ${#setup_problems[@]} -gt 0 ]] || printf '%s\n' '- none'
        printf '%s\n' '' 'Failed checks:'
        for item in "${failed[@]}"; do printf -- '- %s\n' "$item"; done
        [[ ${#failed[@]} -gt 0 ]] || printf '%s\n' '- none'
        printf '%s\n' '' 'Checks skipped because of the environment:'
        for item in "${not_checked[@]}"; do printf -- '- %s\n' "$item"; done
        [[ ${#not_checked[@]} -gt 0 ]] || printf '%s\n' '- none'
        printf '%s\n' \
            '' \
            'Diagnose and fix the machine or repository as needed, then rerun:' \
            '  .github/scripts/check_all_demos.sh --no-codex' \
            '' \
            'Keep working until that command passes, or report the exact external blocker.' \
            'You may install tools and start local services. Do not commit, push, or merge.' \
            'The worktree may contain temporary changes made while presenting the demos.' \
            'Preserve unrelated work, but you may restore a changed file or hunk to HEAD when it is a temporary talk change that caused a reported failure.' \
            'Report exactly which uncommitted changes you discarded.' \
            'Make the smallest durable fix. Update the preflight or its documented contract when the cause can recur.' \
            'Do not patch a cache or generated file solely to make this one run pass. Work quickly, but do not skip the final complete preflight.' \
            'Preserve deliberate demo failures and presenter comments. Keep demo code suitable for production copy and paste.' \
            'Do not replace the WebDriverIO target with a local fake. Its live run needs internet during preparation.' \
            'For an offline talk, use the generated webdriverio/allure-report or the checked-in allure-report-reference and open it beforehand.'
        printf '%s\n' '' 'Complete preflight log:' '```text'
        cat "$preflight_log"
        printf '%s\n' '```'
        printf '%s\n' '' 'Worktree state before the preflight:' '```text'
        printf '%s\n' "${before_status:-clean}"
        printf '%s\n' '```'
    } >"$prompt_file"
}

wait_for_reconnect() {
    printf '\nWaiting for internet access before offering the Codex repair. Press Ctrl+C to stop.\n' >&2
    until internet_is_reachable; do
        sleep 5
    done
    offline=false
    printf 'Internet access restored.\n' >&2
}

find_codex() {
    if command_exists codex; then
        command -v codex
        return
    fi

    local candidate npm_prefix
    for candidate in \
        "${HOME}/.local/bin/codex" \
        "${HOME}/.codex/packages/standalone/current/bin/codex" \
        "${HOME}/.volta/bin/codex" \
        "${HOME}/Library/pnpm/codex" \
        "${HOME}/.bun/bin/codex" \
        /opt/homebrew/bin/codex \
        /usr/local/bin/codex \
        "${NVM_DIR:-${HOME}/.nvm}"/versions/node/*/bin/codex; do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return
        fi
    done

    if command_exists npm; then
        npm_prefix="$(npm prefix --global 2>/dev/null || true)"
        candidate="$npm_prefix/bin/codex"
        if [[ -n "$npm_prefix" && -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return
        fi
    fi

    if [[ -x "${SHELL:-}" ]]; then
        candidate="$("$SHELL" -lic 'command -v codex' 2>/dev/null | tail -n 1)"
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return
        fi
    fi
    return 1
}

offer_codex_fix() {
    local automatic="$1"
    codex_bin="$(find_codex || true)"
    if [[ -z "$codex_bin" ]]; then
        printf '\nCodex is not installed, so the script cannot offer an automatic repair.\n' >&2
        return 1
    fi

    local run_codex=false
    if [[ "$automatic" == true ]]; then
        run_codex=true
    elif [[ "$allow_codex_prompt" == true && "$interactive_terminal" == true ]]; then
        local answer
        printf '\nAsk Codex to fix these problems with --yolo? [y/N] ' >/dev/tty
        read -r answer </dev/tty
        case "$answer" in
            y|Y|yes|YES|Yes) run_codex=true ;;
        esac
    fi
    [[ "$run_codex" == true ]] || return 1

    local prompt_file codex_status
    prompt_file="$diagnostic_root/codex-prompt.md"
    write_codex_prompt "$prompt_file"

    section "Codex repair"
    printf 'Codex output will be saved to %s\n' "$codex_log"
    "$codex_bin" exec --yolo --color never -C "$repo_root" \
        --output-last-message "$diagnostic_root/codex-last-message.txt" - \
        <"$prompt_file" 2>&1 | tee "$codex_log"
    codex_status="${PIPESTATUS[0]}"
    if [[ "$codex_status" -ne 0 ]]; then
        printf 'Codex exited with status %s. Inspect %s\n' "$codex_status" "$codex_log" >&2
    fi

    printf '\nCodex finished. Rerunning the complete preflight without another Codex handoff.\n'
    if [[ -n "$terminal_state" ]]; then
        stty "$terminal_state" </dev/tty >/dev/tty 2>&1 || stty sane </dev/tty >/dev/tty 2>&1 || true
    fi
    cleanup
    trap - EXIT
    if [[ "$interactive_terminal" == true ]]; then
        exec "$script_path" --no-codex </dev/tty >/dev/tty 2>&1
    fi
    exec "$script_path" --no-codex
}

main() {
    cd "$repo_root" || exit 1
    temp_parent="$(cd "${TMPDIR:-/tmp}" && pwd -P)" || exit 1
    temp_root="$(mktemp -d "$temp_parent/testing-toolbox.XXXXXX")"
    diagnostic_root="$(mktemp -d "$temp_parent/testing-toolbox-preflight-log.XXXXXX")"
    preflight_log="$diagnostic_root/preflight.log"
    codex_log="$diagnostic_root/codex-repair.log"
    if [[ -t 0 && -t 1 ]]; then
        interactive_terminal=true
        terminal_state="$(stty -g </dev/tty 2>/dev/null || true)"
    fi
    exec > >(tee "$preflight_log") 2>&1
    printf 'Diagnostic logs: %s\n' "$diagnostic_root"

    if is_online; then
        offline=false
        printf 'Internet access detected. Dependencies and demo assets will be refreshed.\n'
    else
        offline=true
        printf 'Offline mode. Cached dependencies and the saved Allure report will be checked.\n'
    fi

    bootstrap_nvm
    bootstrap_sdkman
    bootstrap_mise
    before_status="$(git status --porcelain=v1 --untracked-files=all)"
    record "Visible root directories are runnable demos" check_root_layout
    check_runtimes
    prepare_docker
    prepare_docker_images
    prepare_node_dependencies

    record "junit-assertj" run_java_demo junit-assertj \
        'PersonRepositoryTest[.]getPeopleBornIn::Smith'
    record "junit-awaitility" run_java_demo junit-awaitility
    record "junit-datafaker" run_java_demo junit-datafaker
    record "junit-instancio" run_java_demo junit-instancio
    record "junit-mockito" run_java_demo junit-mockito
    record "junit-mockserver" run_java_demo junit-mockserver
    record "junit-parameterized" run_java_demo junit-parameterized
    record "junit-pioneer" run_java_demo junit-pioneer \
        'alpha = false \| numeric = false \| uppercase = false \| symbols = false::IllegalArgumentException' \
        'PasswordGeneratorTest::must contain|to contain at least one'
    record "junit-testcontainers-toxiproxy" run_java_demo junit-testcontainers-toxiproxy

    record "jest-fail-on-console" run_jest_demo jest-fail-on-console \
        'should fail on error::console[.]error'
    record "jest-msw" run_jest_demo jest-msw
    record "jest-parameterized" run_jest_demo jest-parameterized
    record "webdriverio" run_webdriverio
    record "artillery" run_artillery
    record "pumba" run_pumba
    record "Worktree remains unchanged" check_worktree

    section "Summary"
    print_items "Passed checks:" "${passed[@]}"
    print_items "Setup problems:" "${setup_problems[@]}"
    print_items "Failed checks:" "${failed[@]}"
    print_items "Not checked:" "${not_checked[@]}"
    printf '\nDiagnostic logs: %s\n' "$diagnostic_root"

    if [[ ${#setup_problems[@]} -eq 0 && ${#failed[@]} -eq 0 ]]; then
        printf '\nAll demos are prepared and checked.\n'
        if [[ -s "$repo_root/webdriverio/allure-report/index.html" ]]; then
            printf 'Before the talk, run (cd webdriverio && npm run report) and leave the report open.\n'
        else
            printf 'Before the talk, run (cd webdriverio && npm run report -- allure-report-reference) and leave the report open.\n'
        fi
        return 0
    fi

    printf '\nThe preparation is incomplete. Every known problem is listed above.\n' >&2
    if [[ "$offline" == true ]]; then
        if [[ "$allow_codex_prompt" != true ]]; then
            printf '%s\n' \
                'Reconnect to the internet, then let Codex repair the remaining setup with:' \
                '  .github/scripts/check_all_demos.sh --fix-with-codex' >&2
            return 1
        fi
        wait_for_reconnect
        if [[ "$fix_with_codex" == true ]]; then
            offer_codex_fix true
        else
            offer_codex_fix false || true
        fi
        return 1
    fi
    if [[ "$fix_with_codex" == true ]]; then
        offer_codex_fix true
    elif [[ "$allow_codex_prompt" == true ]]; then
        offer_codex_fix false || true
    fi
    return 1
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
