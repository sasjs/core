#!/usr/bin/env python3
"""Post the SASjs test results of a workflow run as a pull request comment.

The comment is upserted: one comment per pull request, found by a hidden
marker, so a branch with several pushes does not grow a comment per run.
"""
import csv
import json
import os
import sys
import urllib.error
import urllib.request

MARKER = '<!-- sasjs-test-results -->'


def api(url, token, data=None, method=None):
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(
        url,
        data=body,
        method=method or ('POST' if body else 'GET'),
        headers={
            'Authorization': 'Bearer ' + token,
            'Accept': 'application/vnd.github+json',
            'Content-Type': 'application/json',
        },
    )
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read() or '{}')


def read_results(path):
    if not os.path.exists(path):
        return []
    with open(path, newline='', encoding='utf-8', errors='replace') as handle:
        return list(csv.DictReader(handle))


def build_body(rows, mode, tests, run_url, coverage='', uncovered=''):
    suites = {}
    failures = []
    for row in rows:
        suite = row.get('test_target') or '(unknown)'
        result = (row.get('test_suite_result') or '').strip().upper()
        counts = suites.setdefault(suite, {'PASS': 0, 'FAIL': 0, 'OTHER': 0})
        counts[result if result in ('PASS', 'FAIL') else 'OTHER'] += 1
        if result == 'FAIL':
            failures.append((suite, row.get('test_description') or ''))

    lines = [MARKER,
             '### SASjs test run',
             '',
             'Mode: **{}**'.format(mode)]
    if mode == 'subset':
        lines.append('Tests: `{}`'.format(', '.join(tests) if tests else 'none - ran everything'))
    if coverage:
        line = 'Compile: {}'.format(coverage)
        if uncovered and uncovered != '0':
            line += ', {} macros never reached'.format(uncovered)
        lines.append(line)
    lines.append('')
    # No results means the run failed before asserting anything; that step has
    # already failed the job, so the comment reports it without failing again.
    total_fail = 0
    if not suites:
        lines.append('No results were produced - the run failed before any assertion.')
    else:
        lines.append('| suite | pass | fail | other |')
        lines.append('|---|---|---|---|')
        for suite in sorted(suites):
            c = suites[suite]
            lines.append('| {} | {} | {} | {} |'.format(suite, c['PASS'], c['FAIL'], c['OTHER']))
        total_pass = sum(c['PASS'] for c in suites.values())
        total_fail = sum(c['FAIL'] for c in suites.values())
        lines.append('')
        lines.append('**{} passed, {} failed**'.format(total_pass, total_fail))
        if failures:
            lines.append('')
            lines.append('Failing:')
            for suite, desc in failures[:25]:
                lines.append('- `{}` {}'.format(suite, desc))
            if len(failures) > 25:
                lines.append('- ... and {} more'.format(len(failures) - 25))
    lines.append('')
    lines.append('[Logs and artefacts]({})'.format(run_url))
    return '\n'.join(lines), total_fail


def main():
    token = os.environ['GH_TOKEN']
    repo = os.environ['GITHUB_REPOSITORY']
    pr = os.environ['PR_NUMBER']
    results = os.environ.get('RESULTS', 'sasjsresults/testResults.csv')
    mode = os.environ.get('MODE', 'full')
    tests = [t for t in os.environ.get('TESTS', '').split() if t]
    run_url = '{}/{}/actions/runs/{}'.format(
        os.environ['GITHUB_SERVER_URL'], repo, os.environ['GITHUB_RUN_ID'])

    body, failures = build_body(read_results(results), mode, tests, run_url,
                                os.environ.get('COVERAGE', ''),
                                os.environ.get('UNCOVERED', ''))
    comments_url = 'https://api.github.com/repos/{}/issues/{}/comments'.format(repo, pr)

    existing = None
    for comment in api(comments_url, token):
        if MARKER in (comment.get('body') or ''):
            existing = comment
            break
    if existing:
        api(existing['url'], token, {'body': body}, method='PATCH')
    else:
        api(comments_url, token, {'body': body})

    # A failing suite fails the step; the comment is already posted by then.
    return 1 if failures else 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except urllib.error.HTTPError as err:
        print('comment failed: {} {}'.format(err.code, err.read()[:400]), file=sys.stderr)
        sys.exit(1)
