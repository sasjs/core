#!/usr/bin/env python3
"""Check that every action this repository uses is pinned to a commit that exists.

    python3 .github/scripts/check-action-pins.py [root]

`root` defaults to `.github`, which covers workflows *and* composite actions
(`.github/actions/**/action.yml`) - refs in a composite action are scored by the
scorecard the same way, so they are checked the same way.

Two things fail the check, because a pin can be wrong in two ways:

  - it is not a commit at all (`uses: owner/repo@v1`, `@main`, or something that is
    not an `owner/repo` action). The scorecard's Pinned-Dependencies check scores
    that on the next push to the default branch - too late to be useful in review,
    which is why it fails here directly.
  - it is 40 hex but does not exist in that action's repository. The step then
    fails at action resolution the next time its workflow runs, and for the
    scorecard workflow that is the push that follows the merge. Pinning an
    annotated tag's own id rather than the commit it points to produces exactly
    that.

A pin that could not be checked - a rate limit, a 5xx, a network blip that survives
the retries - is reported as a warning and does not fail the run: this exists to
catch a wrong sha, not to redden an unrelated pull request because the API was
busy. Re-run the job to confirm; a pin that is genuinely absent answers 404 or 422,
which does fail.

The file is read as text rather than through a YAML parser, because the danger is
in the string, not the structure: a `uses:` inside a `run: |` block is shell text,
and a quoted ref carries its quotes into any naive comparison. Both are handled
here - block scalars are skipped, quotes are stripped - and a step written in flow
style (`- {name: x, uses: owner/repo@sha}`) is found too.
"""
import json
import os
import pathlib
import re
import sys
import time
import urllib.error
import urllib.request

BLOCK_USES = re.compile(r'^(\s*)(?:-\s+)?uses:\s*(.+?)\s*$')
FLOW_USES = re.compile(r'[{,]\s*uses:\s*([^,}\n]+)')
BLOCK_SCALAR = re.compile(r'^(\s*)(?:-\s+)?[\w.-]+:\s*[|>][-+]?\s*(?:#.*)?$')
SHA = re.compile(r'^[0-9a-f]{40}$')

# one sleep per retry, so the worst case per ref stays inside the job's timeout
BACKOFF_SECONDS = (5, 10)


def clean(value):
    """The ref out of a `uses:` value: no trailing comment, no quotes."""
    value = re.sub(r'\s+#.*$', '', value).strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ('"', "'"):
        value = value[1:-1]
    return value


def refs_in(path):
    """Every (line number, ref) that is genuinely a `uses:` key in this file."""
    found = []
    block_indent = None

    for number, line in enumerate(path.read_text().splitlines(), start=1):
        indent = len(line) - len(line.lstrip())

        if block_indent is not None:
            # still inside the block scalar until something is indented no more
            if line.strip() == '' or indent > block_indent:
                continue
            block_indent = None

        if line.lstrip().startswith('#'):
            continue

        scalar = BLOCK_SCALAR.match(line)
        if scalar:
            block_indent = len(scalar.group(1))
            continue

        block = BLOCK_USES.match(line)
        if block:
            found.append((number, clean(block.group(2))))
            continue

        # flow style: `- {name: x, uses: owner/repo@sha}` (and a list of them)
        for value in FLOW_USES.findall(line):
            found.append((number, clean(value)))

    return found


def api(path, token):
    request = urllib.request.Request(
        f'https://api.github.com{path}',
        headers={
            'Authorization': f'Bearer {token}',
            'Accept': 'application/vnd.github+json',
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def resolves(repo, sha, token):
    """'ok' when the commit exists, 'bad' when it does not, 'unknown' otherwise.

    'bad' is 404 and 422 - the two answers that mean the commit is not in that
    repository - and 401/403, which mean the token could not read it: a broken or
    under-scoped GITHUB_TOKEN is a failure of the check itself, not a reason to
    pass, so it fails with its own message rather than warning.

    A rate limit (429), a 5xx or a network error is retried and then reported as
    'unknown', which the caller turns into a warning: it says nothing about the
    pin.
    """
    for attempt in range(len(BACKOFF_SECONDS) + 1):
        try:
            api(f'/repos/{repo}/commits/{sha}', token)
            return 'ok'
        except urllib.error.HTTPError as error:
            if error.code in (404, 422):
                return 'bad'
            if error.code in (401, 403):
                # the token cannot read this repository - retrying will not help
                return 'auth'
            transient = error.code == 429 or error.code >= 500
            if transient and attempt < len(BACKOFF_SECONDS):
                time.sleep(BACKOFF_SECONDS[attempt])
                continue
            return 'unknown'
        except (urllib.error.URLError, TimeoutError):
            if attempt < len(BACKOFF_SECONDS):
                time.sleep(BACKOFF_SECONDS[attempt])
                continue
            return 'unknown'
    return 'unknown'


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else '.github'
    token = os.environ.get('GITHUB_TOKEN', '')
    if not token:
        print('::error::GITHUB_TOKEN is not set')
        return 1

    files = sorted(
        path
        for path in pathlib.Path(root).rglob('*')
        if path.suffix in ('.yml', '.yaml') and path.is_file()
    )

    unpinned = []
    unresolved = []
    unauthorised = []
    unknown = []
    checked = 0

    for path in files:
        for number, ref in refs_in(path):
            if ref.startswith('./') or ref.startswith('docker://'):
                continue

            if '@' not in ref:
                unpinned.append((path, number, ref, 'no @<ref> at all'))
                continue

            action, sha = ref.rsplit('@', 1)
            if not SHA.fullmatch(sha):
                unpinned.append((path, number, ref, 'not a full commit SHA'))
                continue

            parts = action.split('/')
            if len(parts) < 2:
                unpinned.append((path, number, ref, 'not an owner/repo action'))
                continue

            repo = '/'.join(parts[:2])
            checked += 1
            status = resolves(repo, sha, token)
            if status == 'bad':
                unresolved.append((path, number, ref, f'no such commit in {repo}'))
            elif status == 'auth':
                unauthorised.append((path, number, ref, repo))
            elif status == 'unknown':
                unknown.append((path, number, ref))

    for path, number, ref, why in unpinned:
        print(f'::error file={path},line={number}::uses: {ref} is not pinned to a commit SHA - {why}')

    for path, number, ref, why in unresolved:
        print(f'::error file={path},line={number}::uses: {ref} does not resolve - {why}')

    for path, number, ref, repo in unauthorised:
        print(f'::error file={path},line={number}::uses: {ref} could not be checked - '
              f'the GITHUB_TOKEN cannot read {repo}. This is a token problem, not a pin problem')

    for path, number, ref in unknown:
        print(f'::warning file={path},line={number}::uses: {ref} could not be checked - '
              'API rate limit, outage or network. Not evidence about the pin; re-run to confirm')

    print(
        f'checked {checked} pinned action(s) in {len(files)} file(s): '
        f'{len(unpinned)} unpinned, {len(unresolved)} unresolved, '
        f'{len(unauthorised)} unauthorised, {len(unknown)} unverifiable'
    )

    return 1 if (unpinned or unresolved or unauthorised) else 0


if __name__ == '__main__':
    sys.exit(main())
