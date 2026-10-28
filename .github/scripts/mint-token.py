#!/usr/bin/env python3
"""Mint a SASjs Server access token and write .env.server for the CLI.

The estate's local login is used: GET / for the XSRF cookie, POST /SASLogon/login
for the session, /SASLogon/authorize for a single-use code, then
/SASjsApi/auth/token for the pair.  Nothing that expires is stored as a secret -
only the user's own credentials are - so the job cannot start failing a day or a
month after somebody minted a token by hand.

Values are never printed.  Set SASJS_DEBUG=1 to see the status of each call.

A call that stalls is the failure this script actually meets: the estate answers
only once the tunnel is up, and urllib waits forever unless a timeout is set, so
a dropped connection used to park the step for fifteen minutes and then surface
as `RemoteDisconnected` with no indication of which call it was.  Every call now
carries a timeout and retries a connection level failure a few times.
"""
import http.cookiejar
import http.client
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

DEBUG = os.environ.get('SASJS_DEBUG') == '1'
TIMEOUT = float(os.environ.get('SASJS_HTTP_TIMEOUT', '30'))
ATTEMPTS = int(os.environ.get('SASJS_HTTP_ATTEMPTS', '3'))
RETRY_STATUSES = (429, 500, 502, 503, 504)


class Transient(Exception):
    """A connection level failure, or a status worth trying again."""


def log(message):
    if DEBUG:
        print(message, file=sys.stderr)


class Session:
    def __init__(self, base):
        self.base = base.rstrip('/')
        self.jar = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(self.jar))

    def xsrf(self):
        for cookie in self.jar:
            if cookie.name == 'XSRF-TOKEN':
                return urllib.parse.unquote(cookie.value or '')
        return ''

    def call(self, path, payload=None, method=None):
        last = None
        for attempt in range(1, ATTEMPTS + 1):
            try:
                return self._attempt(path, payload, method)
            except Transient as err:
                last = err
                if attempt == ATTEMPTS:
                    break
                delay = 2 ** (attempt - 1)
                print('{}: {} - retrying in {}s ({}/{})'.format(
                    path, err, delay, attempt, ATTEMPTS), file=sys.stderr)
                time.sleep(delay)
        if last is not None:
            raise last
        raise Transient('{}: no attempt was made'.format(path))

    def _attempt(self, path, payload=None, method=None):
        data = json.dumps(payload).encode() if payload is not None else None
        request = urllib.request.Request(
            self.base + path, data=data, method=method or ('POST' if data else 'GET'))
        request.add_header('Accept', 'application/json')
        if data is not None:
            request.add_header('Content-Type', 'application/json')
        token = self.xsrf()
        if token:
            request.add_header('X-XSRF-TOKEN', token)
        try:
            with self.opener.open(request, timeout=TIMEOUT) as response:
                body = response.read()
                log('{} -> {}'.format(path, response.status))
                try:
                    return json.loads(body or '{}'), response.status
                except ValueError:
                    # GET / serves the single page app, not JSON
                    return {}, response.status
        except urllib.error.HTTPError as err:
            log('{} -> {} {}'.format(path, err.code, err.read()[:200]))
            if err.code in RETRY_STATUSES:
                raise Transient('HTTP {}'.format(err.code))
            raise
        except (urllib.error.URLError, http.client.HTTPException,
                TimeoutError, ConnectionError) as err:
            # A dropped or stalled connection: name the call, since the traceback
            # on its own does not say which one was in flight.
            raise Transient('{}: {}'.format(err.__class__.__name__, err))


def main():
    base = os.environ['SASJS_SERVER_URL']
    username = os.environ['SASJS_USERNAME']
    password = os.environ['SASJS_PASSWORD']
    client = os.environ.get('SASJS_CLIENT', '').strip()
    out = os.environ.get('ENV_SERVER', '.env.server')

    session = Session(base)
    session.call('/')  # sets the XSRF cookie

    login, _ = session.call('/SASLogon/login',
                            {'username': username, 'password': password})
    if not login.get('loggedIn'):
        print('login failed: {}'.format(login.get('message', 'no message')),
              file=sys.stderr)
        return 1

    if not client:
        # An admin can read the registered clients; anyone else gets 403, which
        # is why the client id can also be supplied as a repository variable.
        try:
            clients, _ = session.call('/SASjsApi/client')
            if isinstance(clients, list) and clients:
                client = clients[0].get('clientId', '')
        except urllib.error.HTTPError as err:
            log('/SASjsApi/client -> {}'.format(err.code))
    if not client:
        print('no clientId: set the SASJS_CLIENT repository variable, or run as an '
              'admin so the first registered client can be read', file=sys.stderr)
        return 1

    authorized, _ = session.call('/SASLogon/authorize', {'clientId': client})
    code = authorized.get('code', '')
    if not code:
        print('authorize returned no code', file=sys.stderr)
        return 1

    tokens, _ = session.call('/SASjsApi/auth/token',
                             {'clientId': client, 'code': code})
    access = tokens.get('accessToken', '')
    refresh = tokens.get('refreshToken', '')
    if not access:
        print('token exchange returned no accessToken', file=sys.stderr)
        return 1

    with open(out, 'w', encoding='utf-8') as handle:
        handle.write('CLIENT={}\nACCESS_TOKEN={}\nREFRESH_TOKEN={}\n'.format(
            client, access, refresh))
    os.chmod(out, 0o600)
    print('wrote {} (client {}, access token {} chars)'.format(
        out, client, len(access)))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Transient as err:
        print('the estate did not answer - {}'.format(err), file=sys.stderr)
        sys.exit(1)
    except urllib.error.HTTPError as err:
        print('HTTP {} from the estate - see SASJS_DEBUG=1'.format(err.code),
              file=sys.stderr)
        sys.exit(1)
