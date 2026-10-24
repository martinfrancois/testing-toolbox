#!/usr/bin/env python3
"""Fail once the webdriverio demo can drop its video reporter workaround.

The demo runs WebdriverIO 10 with wdio-video-reporter 6.2.0, which only supports
WebdriverIO 9, through overrides in webdriverio/pnpm-workspace.yaml. Its
replacement @wdio/video-reporter is not on npm yet. This check fails as soon as
the registry lists a stable release of it that is older than the demo's
dependency cooldown, so the workaround cannot outlive its reason. The steps to
remove it are in https://github.com/martinfrancois/testing-toolbox/issues/69.

The check reads the registry over the network. When the registry cannot be
reached after a few tries, it only prints a warning and passes, so an outage
cannot fail the build; the next run checks again.
"""

import json
import re
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

PACKAGE = "@wdio/video-reporter"
WORKSPACE = Path(__file__).resolve().parents[2] / "webdriverio" / "pnpm-workspace.yaml"
ATTEMPTS = 4
RETRY_DELAY_SECONDS = 10
ISSUE = "https://github.com/martinfrancois/testing-toolbox/issues/69"


class RegistryUnreachable(Exception):
    pass


def cooldown():
    """Read the demo's own cooldown, so this check and pnpm agree on when a release is usable."""
    match = re.search(r"^minimumReleaseAge:\s*(\d+)\s*$", WORKSPACE.read_text(), re.MULTILINE)
    if not match:
        raise SystemExit(f"minimumReleaseAge not found in {WORKSPACE}")
    return timedelta(minutes=int(match.group(1)))


def publish_times(package):
    """Return {version: publish time} from the registry, None if the package does not exist."""
    url = "https://registry.npmjs.org/" + package.replace("/", "%2f")
    for attempt in range(1, ATTEMPTS + 1):
        try:
            with urllib.request.urlopen(url, timeout=30) as response:
                times = json.load(response).get("time", {})
            return {
                version: datetime.fromisoformat(stamp.replace("Z", "+00:00"))
                for version, stamp in times.items()
                if version not in ("created", "modified")
            }
        except urllib.error.HTTPError as error:
            if error.code == 404:
                return None
            problem = f"HTTP {error.code}"
        except (urllib.error.URLError, TimeoutError, OSError, ValueError) as error:
            problem = str(error)
        print(f"Registry request {attempt}/{ATTEMPTS} for {package} failed: {problem}")
        if attempt < ATTEMPTS:
            time.sleep(RETRY_DELAY_SECONDS * attempt)
    raise RegistryUnreachable(package)


def main(package=PACKAGE):
    try:
        times = publish_times(package)
    except RegistryUnreachable:
        print(f"::warning::Could not reach the npm registry to check {package}; the next run checks again.")
        return 0
    if times is None:
        print(f"{package} is not on npm yet, so the workaround is still needed.")
        return 0
    wait = cooldown()
    now = datetime.now(timezone.utc)
    usable = [version for version, published in times.items() if "-" not in version and now - published >= wait]
    if usable:
        newest = max(usable, key=times.get)
        print(f"::error::{package} {newest} is on npm and older than the cooldown. Remove the workaround: {ISSUE}")
        return 1
    stable = {version: published for version, published in times.items() if "-" not in version}
    if stable:
        first = min(stable.values()) + wait
        print(f"{package} has a stable release, usable after {first:%Y-%m-%d %H:%M} UTC.")
    else:
        print(f"{package} has no stable release yet, so the workaround is still needed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
