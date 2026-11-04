#!/usr/bin/env python3
"""The pin checker's own reading of a workflow, and its reading of the API.

    python3 .github/scripts/check-action-pins.test.py

Every way this check has been wrong so far has been a way of interpreting an
answer: a `uses:` inside a `run:` block scalar read as an action, a quoted ref
compared with its quotes, a flow-style step missed entirely, a refused token
counted as an unverifiable pin. Those readings are what these cases pin.

`refs_in()` is exercised against real files; `resolves()` and `main()` against a
stubbed `api()`, so no case needs a token or a network.
"""
import contextlib
import io
import pathlib
import tempfile
import textwrap
import unittest
import urllib.error

import importlib.util

HERE = pathlib.Path(__file__).resolve().parent


def load_checker():
    spec = importlib.util.spec_from_file_location(
        'check_action_pins', HERE / 'check-action-pins.py'
    )
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


CHECKER = load_checker()

SHA = '0' * 40


def refs(source):
    """The refs the checker reads out of one YAML document, in file order."""
    with tempfile.TemporaryDirectory() as directory:
        path = pathlib.Path(directory) / 'workflow.yml'
        path.write_text(textwrap.dedent(source))
        return [ref for _, ref in CHECKER.refs_in(path)]


class RefsInTest(unittest.TestCase):
    def test_block_style_step(self):
        self.assertEqual(
            refs(
                """\
                steps:
                  - uses: actions/checkout@v4
                  - name: Setup
                    uses: actions/setup-node@v4
                """
            ),
            ['actions/checkout@v4', 'actions/setup-node@v4'],
        )

    def test_flow_mapping_step(self):
        self.assertEqual(
            refs(
                """\
                steps:
                  - {name: Build, uses: actions/checkout@v4}
                  - { uses: actions/setup-node@v4, with: {node-version: 22} }
                """
            ),
            ['actions/checkout@v4', 'actions/setup-node@v4'],
        )

    def test_several_flow_mappings_on_one_line(self):
        self.assertEqual(
            refs("steps:\n  - [{uses: a/b@v1}, {uses: c/d@v2}]\n"),
            ['a/b@v1', 'c/d@v2'],
        )

    def test_quotes_are_not_part_of_the_ref(self):
        self.assertEqual(refs('steps:\n  - uses: "actions/checkout@v4"\n'), [
            'actions/checkout@v4'
        ])
        self.assertEqual(refs('steps:\n  - {uses: "actions/checkout@v4"}\n'), [
            'actions/checkout@v4'
        ])

    def test_a_uses_inside_a_block_scalar_is_shell_text(self):
        self.assertEqual(
            refs(
                """\
                steps:
                  - name: Echo
                    run: |
                      echo "uses: notanaction@v1"
                      cat <<EOF
                      uses: alsonot@v2
                      EOF
                  - uses: actions/checkout@v4
                """
            ),
            ['actions/checkout@v4'],
        )

    def test_a_commented_out_step_is_not_read(self):
        self.assertEqual(
            refs(
                """\
                steps:
                  # - uses: actions/checkout@v4
                  - uses: actions/setup-node@v4
                """
            ),
            ['actions/setup-node@v4'],
        )

    def test_a_local_or_container_ref_is_read_and_left_to_the_caller(self):
        # refs_in() reports every key; main() is what skips these, so the parse
        # must not quietly drop them
        self.assertEqual(
            refs("steps:\n  - uses: ./local-action\n  - uses: docker://alpine:3\n"),
            ['./local-action', 'docker://alpine:3'],
        )


class ResolvesTest(unittest.TestCase):
    """What each answer from the API means for the run."""

    def setUp(self):
        self.original_api = CHECKER.api
        self.original_sleep = CHECKER.time.sleep
        self.calls = []
        # the backoff is real time; the classification is what is under test
        CHECKER.time.sleep = lambda seconds: None

    def tearDown(self):
        CHECKER.api = self.original_api
        CHECKER.time.sleep = self.original_sleep

    def answer(self, error):
        def api(path, token):
            self.calls.append(path)
            raise error

        CHECKER.api = api
        return CHECKER.resolves('owner/repo', SHA, 'token')

    def test_a_commit_that_exists(self):
        CHECKER.api = lambda path, token: {'sha': SHA}
        self.assertEqual(CHECKER.resolves('owner/repo', SHA, 'token'), 'ok')

    def test_404_and_422_mean_the_commit_is_not_there(self):
        self.assertEqual(self.answer(urllib.error.HTTPError(
            'https://api.github.com', 404, 'Not Found', {}, None)), 'bad')
        self.assertEqual(self.answer(urllib.error.HTTPError(
            'https://api.github.com', 422, 'Unprocessable', {}, None)), 'bad')

    def test_a_refused_token_is_not_verifiable_and_is_not_a_retry(self):
        # 401 will not become 200, so retrying only delays the report
        self.assertEqual(self.answer(urllib.error.HTTPError(
            'https://api.github.com', 401, 'Unauthorized', {}, None)), 'denied')
        self.assertEqual(len(self.calls), 1)

    def test_a_403_that_is_not_throttling_is_a_refused_token(self):
        # a permission 403 answers with a body, and it does not say "rate limit"
        self.assertEqual(self.answer(urllib.error.HTTPError(
            'https://api.github.com', 403, 'Forbidden', {},
            io.BytesIO(b'{"message": "Resource not accessible by integration"}'))), 'denied')

    def test_a_403_with_no_body_at_all_is_not_a_refusal(self):
        # nothing to read is missing evidence: a body consumed before this function
        # saw it looks identical, and that must not fail the run
        self.assertEqual(self.answer(urllib.error.HTTPError(
            'https://api.github.com', 403, 'Forbidden', {}, None)), 'unknown')

    def test_a_403_that_says_rate_limit_is_unverifiable(self):
        throttled = urllib.error.HTTPError(
            'https://api.github.com', 403, 'Forbidden',
            {'Retry-After': '60'}, None)
        self.assertEqual(self.answer(throttled), 'unknown')

    def test_a_403_with_a_secondary_rate_limit_body_is_unverifiable(self):
        error = urllib.error.HTTPError(
            'https://api.github.com', 403, 'Forbidden', {},
            io.BytesIO(b'{"message": "You have exceeded a secondary rate limit"}'))
        self.assertEqual(self.answer(error), 'unknown')

    def test_a_403_with_an_exhausted_budget_is_unverifiable(self):
        # the primary limit: no Retry-After, but the budget is spent
        exhausted = urllib.error.HTTPError(
            'https://api.github.com', 403, 'Forbidden',
            {'X-RateLimit-Remaining': '0'}, None)
        self.assertEqual(self.answer(exhausted), 'unknown')

    def test_a_403_whose_body_cannot_be_read_is_unverifiable(self):
        # no evidence either way: not a reason to send a maintainer at the token
        error = urllib.error.HTTPError(
            'https://api.github.com', 403, 'Forbidden', {},
            io.BytesIO(b'whatever'))

        def unreadable():
            raise OSError('connection reset while reading the body')

        error.read = unreadable
        self.assertEqual(self.answer(error), 'unknown')

    def test_429_and_5xx_and_network_blips_are_unverifiable(self):
        self.assertEqual(self.answer(urllib.error.HTTPError(
            'https://api.github.com', 429, 'Too Many Requests', {}, None)), 'unknown')
        self.assertEqual(self.answer(urllib.error.HTTPError(
            'https://api.github.com', 502, 'Bad Gateway', {}, None)), 'unknown')
        self.assertEqual(self.answer(urllib.error.URLError('no route')), 'unknown')


class MainTest(unittest.TestCase):
    """The verdict the job gets: a refused token must not read as a pass."""

    def run_main(self, status):
        original_refs = CHECKER.refs_in
        original_status = CHECKER.resolves
        original_sleep = CHECKER.time.sleep
        original_argv = CHECKER.sys.argv
        original_token = CHECKER.os.environ.get('GITHUB_TOKEN')

        CHECKER.refs_in = lambda path: [(1, f'owner/repo@{SHA}')]
        CHECKER.resolves = lambda repo, sha, token: status
        CHECKER.time.sleep = lambda seconds: None
        CHECKER.os.environ['GITHUB_TOKEN'] = 'token'
        CHECKER.sys.argv = ['check-action-pins.py', '.']

        printed = io.StringIO()

        try:
            with tempfile.TemporaryDirectory() as directory:
                pathlib.Path(directory, 'workflow.yml').write_text('steps:\n')
                CHECKER.sys.argv = ['check-action-pins.py', directory]
                with contextlib.redirect_stdout(printed):
                    code = CHECKER.main()
        finally:
            CHECKER.refs_in = original_refs
            CHECKER.resolves = original_status
            CHECKER.time.sleep = original_sleep
            CHECKER.sys.argv = original_argv
            if original_token is None:
                CHECKER.os.environ.pop('GITHUB_TOKEN', None)
            else:
                CHECKER.os.environ['GITHUB_TOKEN'] = original_token

        return code, printed.getvalue()

    def test_a_refused_token_fails_the_run(self):
        code, output = self.run_main('denied')
        self.assertEqual(code, 1)
        self.assertIn('could not be checked - the token was refused', output)
        self.assertIn('1 refused', output)

    def test_an_unverifiable_pin_only_warns(self):
        code, output = self.run_main('unknown')
        self.assertEqual(code, 0)
        self.assertIn('::warning', output)
        self.assertIn('1 unverifiable', output)

    def test_a_resolved_pin_passes(self):
        code, output = self.run_main('ok')
        self.assertEqual(code, 0)
        self.assertIn('0 refused, 0 unverifiable', output)


if __name__ == '__main__':
    unittest.main()
