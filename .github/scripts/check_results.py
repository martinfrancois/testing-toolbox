#!/usr/bin/env python3
"""Decide whether a demo run counts as working.

Some demos in this repository fail on purpose during the talk (a wrong name in
junit-assertj, a console.error in jest-fail-on-console, a failing and a flaky
browser test in webdriverio). CI therefore cannot use the exit code of the test
run. This script reads the run's result files and passes only when:

  * at least one test result was found (a run that produced nothing is broken),
  * every test that is expected to fail did fail, for the expected reason,
  * every test that may fail (flaky on purpose) either passed or failed for the
    expected reason,
  * every other test passed.

Expectations come from the CHECK_EXPECT_FAIL and CHECK_MAY_FAIL environment
variables, one entry per line, each `NAME_REGEX` or `NAME_REGEX::MESSAGE_REGEX`.
Both regexes are searched, case-sensitively, in the test name and the failure
message. Formats: gradle (JUnit XML directory), jest (`jest --json` file),
allure (allure-results directory), artillery (`artillery run --output` file).
"""

import argparse
import glob
import json
import os
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass


@dataclass
class Result:
    name: str
    status: str  # passed | failed | skipped
    message: str = ""


def read_gradle(path):
    results = []
    for file in sorted(glob.glob(os.path.join(path, "*.xml"))):
        for case in ET.parse(file).getroot().iter("testcase"):
            name = f"{case.get('classname')}.{case.get('name')}"
            failure = case.find("failure") if case.find("failure") is not None else case.find("error")
            if failure is not None:
                message = f"{failure.get('type', '')}: {failure.get('message', '')}\n{failure.text or ''}"
                results.append(Result(name, "failed", message))
            elif case.find("skipped") is not None:
                results.append(Result(name, "skipped"))
            else:
                results.append(Result(name, "passed"))
    return results


def read_jest(path):
    with open(path, encoding="utf-8") as handle:
        report = json.load(handle)
    results = []
    for suite in report.get("testResults", []):
        cases = suite.get("assertionResults", [])
        if not cases:
            # The suite never ran its tests: a compile error or a crashed worker.
            status = "passed" if suite.get("status") == "passed" else "failed"
            results.append(Result(suite.get("name", "?"), status, suite.get("message", "")))
            continue
        for case in cases:
            status = {"passed": "passed", "failed": "failed"}.get(case.get("status"), "skipped")
            results.append(Result(case.get("fullName") or case.get("title"), status,
                                  "\n".join(case.get("failureMessages", []))))
    return results


def read_allure(path):
    results = []
    for file in sorted(glob.glob(os.path.join(path, "*-result.json"))):
        with open(file, encoding="utf-8") as handle:
            case = json.load(handle)
        status = {"passed": "passed", "failed": "failed", "broken": "failed"}.get(case.get("status"), "skipped")
        details = case.get("statusDetails") or {}
        results.append(Result(case.get("fullName") or case.get("name") or file, status,
                              f"{details.get('message', '')}\n{details.get('trace', '')}"))
    return results


def read_artillery(path):
    """An artillery run is healthy when requests were made, were answered with
    200 and no virtual user failed. The ensure thresholds are deliberately not
    checked: breaching them is part of the demo."""
    with open(path, encoding="utf-8") as handle:
        counters = json.load(handle).get("aggregate", {}).get("counters", {})
    errors = {key: value for key, value in counters.items() if key.startswith("errors.")}
    checks = [
        ("requests were sent", counters.get("http.requests", 0) > 0, f"http.requests={counters.get('http.requests', 0)}"),
        ("responses were HTTP 200", counters.get("http.codes.200", 0) > 0, f"http.codes.200={counters.get('http.codes.200', 0)}"),
        ("no virtual user failed", counters.get("vusers.failed", 0) == 0, f"vusers.failed={counters.get('vusers.failed', 0)}"),
        ("no errors were counted", not errors, f"errors={errors}"),
    ]
    return [Result(name, "passed" if ok else "failed", detail) for name, ok, detail in checks]


READERS = {"gradle": read_gradle, "jest": read_jest, "allure": read_allure, "artillery": read_artillery}


def parse_expectations(raw):
    expectations = []
    for line in (raw or "").splitlines():
        line = line.strip()
        if not line:
            continue
        name, _, message = line.partition("::")
        expectations.append((re.compile(name), re.compile(message) if message else None))
    return expectations


def matching(expectations, result):
    return [(name, message) for name, message in expectations if name.search(result.name)]


def judge(results, expect_fail, may_fail):
    problems = []
    rows = []
    if not results:
        problems.append("no test results were found, so the demo did not run at all")

    for result in results:
        expected = matching(expect_fail, result)
        tolerated = matching(may_fail, result)
        if expected:
            message_pattern = expected[0][1]
            if result.status != "failed":
                verdict = "MUST FAIL but did not: the built-in demo failure is gone"
            elif message_pattern and not message_pattern.search(result.message):
                verdict = f"failed for the wrong reason (expected /{message_pattern.pattern}/): {first_line(result.message)}"
            else:
                verdict = "fails on purpose, as expected"
        elif tolerated:
            message_pattern = tolerated[0][1]
            if result.status == "passed":
                verdict = "passed (may fail)"
            elif result.status == "failed" and (not message_pattern or message_pattern.search(result.message)):
                verdict = "failed on purpose, tolerated"
            else:
                verdict = f"failed for the wrong reason (expected /{message_pattern.pattern if message_pattern else '.*'}/): {first_line(result.message)}"
        elif result.status == "passed":
            verdict = "passed"
        else:
            verdict = f"{result.status.upper()}: {first_line(result.message)}"
        ok = not any(word in verdict for word in ("MUST FAIL", "wrong reason", "FAILED", "SKIPPED"))
        if not ok:
            problems.append(f"{result.name}: {verdict}")
        rows.append((result.name, result.status, verdict, ok))

    for name, _ in expect_fail:
        if not any(name.search(result.name) for result in results):
            problems.append(f"no test matched the expected failure /{name.pattern}/; it was renamed or removed")
    return rows, problems


def first_line(text):
    for line in (text or "").splitlines():
        if line.strip():
            return line.strip()[:200]
    return ""


def write_summary(title, rows, problems):
    lines = [f"### {title}", "", "| Test | Status | Verdict |", "|---|---|---|"]
    for name, status, verdict, ok in rows:
        icon = "✅" if ok else "❌"
        lines.append(f"| `{name}` | {status} | {icon} {verdict} |")
    if problems:
        lines += ["", "**Problems**", ""] + [f"- {problem}" for problem in problems]
    text = "\n".join(lines) + "\n"
    print(text)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as handle:
            handle.write(text)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--format", required=True, choices=sorted(READERS))
    parser.add_argument("--path", required=True, help="result directory or file, depending on the format")
    parser.add_argument("--title", default=None, help="heading for the job summary (defaults to the path)")
    args = parser.parse_args()

    results = READERS[args.format](args.path)
    rows, problems = judge(results,
                           parse_expectations(os.environ.get("CHECK_EXPECT_FAIL")),
                           parse_expectations(os.environ.get("CHECK_MAY_FAIL")))
    write_summary(args.title or args.path, rows, problems)
    if problems:
        print("::error::" + "; ".join(problems))
        return 1
    print(f"OK: {len(results)} result(s) checked")
    return 0


if __name__ == "__main__":
    sys.exit(main())
