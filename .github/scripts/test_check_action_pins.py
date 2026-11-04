#!/usr/bin/env python3
"""The pin checker's own reading of a workflow, and its reading of the API.

    python3 .github/scripts/test_check_action_pins.py

The invariants these cases pin:

- `refs_in()` reports every `uses:` key it can see, exactly once, without its
  quotes, and reports nothing that is not a key: a `uses:` inside a `run:` block
  scalar is shell text, a commented-out step is a comment, and a flow-style step
  is still a step.
- `resolves()` maps every answer the API can give onto one of `ok`, `bad`,
  `denied`, `unknown`, and only `bad` and `denied` are statements about the pin.
  A busy or unreadable API is `unknown`, and a `Retry-After` is waited out on the
  API's schedule rather than the checker's.
- `main()` exits 1 for anything it can prove wrong and for a run in which nothing
  could be verified at all; it exits 0 only when every pin was verified, or when
  some were verified and the rest were merely unverifiable.

`refs_in()` is exercised against real files; `resolves()` and `main()` against a
stubbed `api()`, so no case needs a token or a network.
"""
import contextlib
import importlib.util
import io
import pathlib
import tempfile
import textwrap
import unittest
import urllib.error

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

    def test_a_trailing_comment_is_not_part_of_the_ref(self):
        self.assertEqual(
            refs('steps:\n  - uses: actions/checkout@v4 # v4.1.7\n'),
            ['actions/checkout@v4'],
        )


class ResolvesTest(unittest.TestCase):
    """What each answer from the API means for the run."""

    def setUp(self):
        self.original_api = CHECKER.api
        self.original_sleep = CHECKER.time.sleep
        self.calls = []
        self.slept = []
        # the backoff is real time; the classification is what is under test
        CHECKER.time.sleep = self.slept.append

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

    def test_an_empty_body_is_not_a_refusal(self):
        # urllib hands back an empty stream when the 403 carried no body
        self.assertEqual(self.answer(urllib.error.HTTPError(
            'https://api.github.com', 403, 'Forbidden', {},
            io.BytesIO(b''))), 'unknown')

    def test_a_whitespace_only_body_is_not_a_refusal(self):
        self.assertEqual(self.answer(urllib.error.HTTPError(
            'https://api.github.com', 403, 'Forbidden', {},
            io.BytesIO(b'  \n\t\n'))), 'unknown')

    def test_a_403_that_says_rate_limit_is_unverifiable(self):
        throttled = urllib.error.HTTPError(
            'https://api.github.com', 403, 'Forbidden',
            {'Retry-After': '60'}, None)
        self.assertEqual(self.answer(throttled), 'unknown')

    def test_retry_after_is_waited_out_on_the_api_schedule(self):
        # 60s is beyond our patience, so it is not honoured; the checker backs off
        self.answer(urllib.error.HTTPError(
            'https://api.github.com', 403, 'Forbidden', {'Retry-After': '60'}, None))
        self.assertEqual(self.slept, list(CHECKER.BACKOFF_SECONDS))

    def test_a_short_retry_after_is_honoured(self):
        self.slept.clear()
        self.answer(urllib.error.HTTPError(
            'https://api.github.com', 429, 'Too Many Requests', {'Retry-After': '3'}, None))
        self.assertEqual(self.slept, [3, 3])

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
    """The verdict the job gets: nothing wrong may read as a pass."""

    def run_main(self, statuses):
        original_refs = CHECKER.refs_in
        original_resolves = CHECKER.resolves
        original_token = CHECKER.os.environ.get('GITHUB_TOKEN')
        answers = list(statuses)

        CHECKER.refs_in = lambda path: [(1, f'owner/repo@{SHA}')]
        CHECKER.resolves = lambda repo, sha, token: answers.pop(0)
        CHECKER.os.environ['GITHUB_TOKEN'] = 'token'

        printed = io.StringIO()
        original_argv = CHECKER.sys.argv
        try:
            with tempfile.TemporaryDirectory() as directory:
                pathlib.Path(directory, 'workflow.yml').write_text('steps:\n')
                # one entry per pin, so the stub is asked once per ref
                count = len(statuses)
                CHECKER.refs_in = lambda path: [
                    (index + 1, f'owner/repo@{SHA}') for index in range(count)
                ]
                answers = list(statuses)
                CHECKER.sys.argv = ['check-action-pins.py', directory]
                with contextlib.redirect_stdout(printed):
                    code = CHECKER.main()
        finally:
            CHECKER.sys.argv = original_argv
            CHECKER.refs_in = original_refs
            CHECKER.resolves = original_resolves
            if original_token is None:
                CHECKER.os.environ.pop('GITHUB_TOKEN', None)
            else:
                CHECKER.os.environ['GITHUB_TOKEN'] = original_token

        return code, printed.getvalue()

    def test_a_refused_token_fails_the_run(self):
        code, output = self.run_main(['denied'])
        self.assertEqual(code, 1)
        self.assertIn('could not be checked - the token was refused', output)
        self.assertIn('1 refused', output)

    def test_an_unverifiable_pin_beside_a_good_one_only_warns(self):
        code, output = self.run_main(['ok', 'unknown'])
        self.assertEqual(code, 0)
        self.assertIn('::warning', output)
        self.assertIn('1 unverifiable', output)

    def test_a_run_that_verified_nothing_fails(self):
        # a green job that checked nothing reads as a pass; it must not
        code, output = self.run_main(['unknown', 'unknown'])
        self.assertEqual(code, 1)
        self.assertIn('none of the 2 pin(s) could be verified', output)

    def test_a_resolved_pin_passes(self):
        code, output = self.run_main(['ok'])
        self.assertEqual(code, 0)
        self.assertIn('0 refused, 0 unverifiable', output)

    def test_an_unpinned_ref_fails_without_asking_the_api(self):
        original_refs = CHECKER.refs_in
        original_token = CHECKER.os.environ.get('GITHUB_TOKEN')
        CHECKER.refs_in = lambda path: [(1, 'owner/repo@v4')]
        CHECKER.os.environ['GITHUB_TOKEN'] = 'token'
        printed = io.StringIO()
        try:
            with tempfile.TemporaryDirectory() as directory:
                pathlib.Path(directory, 'workflow.yml').write_text('steps:\n')
                with contextlib.redirect_stdout(printed):
                    original = CHECKER.sys.argv
                    CHECKER.sys.argv = ['check-action-pins.py', directory]
                    try:
                        code = CHECKER.main()
                    finally:
                        CHECKER.sys.argv = original
        finally:
            CHECKER.refs_in = original_refs
            if original_token is None:
                CHECKER.os.environ.pop('GITHUB_TOKEN', None)
            else:
                CHECKER.os.environ['GITHUB_TOKEN'] = original_token
        self.assertEqual(code, 1)
        self.assertIn('is not pinned to a commit sha', printed.getvalue())


if __name__ == '__main__':
    unittest.main()
