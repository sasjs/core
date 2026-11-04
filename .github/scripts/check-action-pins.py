#!/usr/bin/env python3
"""Check that every action this repository uses is pinned to a commit that exists.

    python3 .github/scripts/check-action-pins.py [root]

`root` defaults to `.github`, which is where every workflow and composite action
lives. The rules:

- every external `uses:` must name a full 40-character commit SHA, and the SHA must
  exist in that repository - a tag or a branch is not a pin;
- a `uses:` inside a `run:` block scalar is shell text, not an action;
- a `uses:` in a flow-style step - `- {name: x, uses: owner/repo@sha}` - counts;
- a quoted ref carries its quotes into the comparison unless they are stripped.

The verdict for each pin is one of four words, and only the first three can fail
the run:

  ok        the commit exists in that repository
  bad       the answer was 404 or 422: no such commit there
  denied    the token was refused - a 401, or a 403 that is not throttling
  unknown   no usable answer - a rate limit, a 5xx, a network error, or a 403
            whose body is missing or unreadable

`unknown` warns rather than failing, because a busy API says nothing about the
pin. But a run in which *nothing* could be verified fails: a gate that reports
nothing and exits 0 is worse than one that reports nothing and exits 1.

Exit status: 0 when every pin is ok (or only some are unknown), 1 otherwise.
"""
import fnmatch
import json
import os
import pathlib
import re
import sys
import time
import urllib.error
import urllib.request

API = 'https://api.github.com'

# per-ref backoff while the API is busy or throttling; the job timeout has to
# outlast the sum of these, see timeout-minutes in the workflow
BACKOFF_SECONDS = (5, 10)

# a Retry-After can ask for minutes. Wait for it up to this, then treat the pin as
# unverifiable rather than holding a runner for the rest of the hour.
MAX_RETRY_AFTER = 30

BLOCK_USES = re.compile(r'^(\s*)(?:-\s+)?uses:\s*(.+?)\s*$')
FLOW_USES = re.compile(r'[{,]\s*uses:\s*([^,}\n]+)')
UNPINNED = re.compile(r'^[^@\s]+@[0-9a-fA-F]{40}$')
LOCAL = ('./', '../', 'docker://')


def api(path, token):
    request = urllib.request.Request(
        API + path,
        headers={
            'Authorization': f'Bearer {token}',
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def refs_in(path):
    """(line number, ref) for every `uses:` in a workflow or action file."""
    refs = []
    block_indent = None
    scalar_indent = None

    for number, line in enumerate(path.read_text(errors='ignore').splitlines(), 1):
        stripped = line.strip()
        if not stripped:
            continue

        indent = len(line) - len(line.lstrip())

        # inside a block scalar (`run: |`) everything is text until the indentation
        # returns to the key that opened it
        if scalar_indent is not None:
            if indent > scalar_indent:
                continue
            scalar_indent = None
        if block_indent is not None:
            if indent > block_indent:
                continue
            block_indent = None

        if stripped.startswith('#'):
            continue

        if re.match(r'^(?:-\s+)?(?:run|script|with):\s*[|>]', stripped):
            block_indent = indent
            continue

        match = BLOCK_USES.match(line)
        if match:
            value = match.group(2)
            comment = value.find(' #')
            if comment != -1:
                value = value[:comment]
            refs.append((number, clean(value)))
            continue

        for value in FLOW_USES.findall(line):
            refs.append((number, clean(value)))

    return refs


def clean(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ('"', "'"):
        value = value[1:-1]
    return value


def header(error, name):
    """A header by name, matched case-insensitively.

    A real HTTPMessage is case-insensitive; a plain dict - which is what a test
    double passes - is not, so the comparison is done here.
    """
    for key, value in (getattr(error, 'headers', None) or {}).items():
        if key.lower() == name:
            return value
    return None


def retry_after(error):
    """Seconds the API asked us to wait, if it said so within our patience."""
    value = header(error, 'retry-after')
    if value is None:
        return None
    try:
        seconds = int(str(value).strip())
    except (TypeError, ValueError):
        return None
    return seconds if 0 <= seconds <= MAX_RETRY_AFTER else None


def throttled(error):
    """Whether a 403 is GitHub asking us to slow down rather than refusing us.

    A secondary limit sends Retry-After, a primary limit sends
    x-ratelimit-remaining: 0, and either way the body usually says "rate limit".
    None of those means the token is wrong, so none of them may fail the run.

    Returns True (throttled), False (refused) or None (no way to tell).

    The answer is cached on the exception: a caller that has already read the body
    - a logger, a test double that re-raises one instance - would otherwise see an
    empty stream and reach a different verdict the second time.
    """
    cached = getattr(error, '_pkg_throttled', 'missing')
    if cached != 'missing':
        return cached

    if header(error, 'retry-after') or header(error, 'x-ratelimit-remaining') == '0':
        result = True
    elif getattr(error, 'fp', None) is None:
        result = None
    else:
        try:
            body = error.read().decode('utf-8', 'ignore')
        except Exception:  # noqa: BLE001 - a body we cannot read is not evidence
            error._pkg_throttled = None
            return None

        if not body.strip():
            # urllib hands back an empty stream for a 403 that carried no body, and
            # a body already consumed elsewhere reads the same way: missing
            # evidence, not a refusal
            error._pkg_throttled = None
            return None

        result = 'rate limit' in body.lower()

    error._pkg_throttled = result
    return result


def resolves(repo, sha, token):
    """'ok', 'bad', 'denied' or 'unknown' - see the module docstring."""
    for attempt in range(len(BACKOFF_SECONDS) + 1):
        try:
            api(f'/repos/{repo}/commits/{sha}', token)
            return 'ok'
        except urllib.error.HTTPError as error:
            if error.code in (404, 422):
                return 'bad'
            if error.code == 401:
                return 'denied'
            if error.code == 403:
                answer = throttled(error)
                if answer is False:
                    return 'denied'
                if answer is None:
                    return 'unknown'
            transient = error.code == 403 or error.code == 429 or error.code >= 500
            if transient and attempt < len(BACKOFF_SECONDS):
                # honour Retry-After: retrying on our own schedule is what sustains
                # a secondary limit
                time.sleep(retry_after(error) or BACKOFF_SECONDS[attempt])
                continue
            return 'unknown'
        except (urllib.error.URLError, TimeoutError):
            if attempt < len(BACKOFF_SECONDS):
                time.sleep(BACKOFF_SECONDS[attempt])
                continue
            return 'unknown'
    return 'unknown'


def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '.github')
    token = os.environ.get('GITHUB_TOKEN')
    if not token:
        print('::error::GITHUB_TOKEN is not set, so no pin can be verified')
        return 1

    files = sorted(
        path for path in root.rglob('*')
        if path.is_file() and (fnmatch.fnmatch(path.name, '*.yml') or fnmatch.fnmatch(path.name, '*.yaml'))
    )

    pins = []
    for path in files:
        for number, ref in refs_in(path):
            if ref.startswith(LOCAL) or ref.startswith('docker://'):
                # a local action or a container image: not a pin this check owns
                continue
            pins.append((path, number, ref))

    unpinned = []
    unresolved = []
    denied = []
    unknown = []
    checked = 0

    for path, number, ref in pins:
        repo, _, sha = ref.partition('@')
        if not UNPINNED.match(ref):
            unpinned.append((path, number, ref))
            continue
        checked += 1
        status = resolves(repo, sha, token)
        if status == 'bad':
            unresolved.append((path, number, ref, f'no such commit in {repo}'))
        elif status == 'denied':
            denied.append((path, number, ref, repo))
        elif status == 'unknown':
            unknown.append((path, number, ref))

    for path, number, ref in unpinned:
        print(f'::error file={path},line={number}::uses: {ref} is not pinned to a commit sha')

    for path, number, ref, why in unresolved:
        print(f'::error file={path},line={number}::uses: {ref} - {why}')

    for path, number, ref, repo in denied:
        print(f'::error file={path},line={number}::uses: {ref} could not be checked - '
              f'the token was refused reading {repo}; check GITHUB_TOKEN, not the pin')

    for path, number, ref in unknown:
        print(f'::warning file={path},line={number}::uses: {ref} could not be checked - '
              f'the API gave no usable answer, which says nothing about the pin')

    everything_unverified = bool(checked) and len(unknown) == checked
    if everything_unverified:
        print(f'::error::none of the {checked} pin(s) could be verified - a run that checks '
              f'nothing does not pass')

    print(
        f'checked {checked} pinned action(s) in {len(files)} file(s): '
        f'{len(unpinned)} unpinned, {len(unresolved)} unresolved, '
        f'{len(denied)} refused, {len(unknown)} unverifiable'
    )

    return 1 if (unpinned or unresolved or denied or everything_unverified) else 0


if __name__ == '__main__':
    sys.exit(main())
