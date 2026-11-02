#!/usr/bin/env python3
"""Mint an access/refresh token pair from a SASjs Server with local auth.

Server mode authenticates through the SASLogon session endpoints, not through a
login route on /SASjsApi: sign in at /SASLogon/login (which needs the XSRF
cookie set by a prior GET /), exchange that session for an authorization code at
/SASLogon/authorize, then swap the code for tokens at /SASjsApi/auth/token.
Client-credentials style calls are rejected ("clientId" is required, then "code"
is required), so this three-step chain is the only headless route.

Usage:
    SASJS_URL=https://example.com SASJS_USER=me SASJS_PASS=secret \
        python3 mint-tokens.py --client clientID1 --out .env.mytarget

The output file holds CLIENT, ACCESS_TOKEN and REFRESH_TOKEN, which is the shape
the sasjs CLI reads from .env.<target> for a serverType: SASJS target. No token
is ever printed: the script reports booleans only.

Access tokens are short-lived (an hour by default on a stock install). Re-run
this rather than debugging a 401: an expired token surfaces as "Login callback
called. Request failed." from the CLI, or a 401 from any /SASjsApi route.
"""
import argparse
import http.cookiejar
import json
import os
import sys
import urllib.error
import urllib.request


def post(opener, url, path, payload, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["x-xsrf-token"] = token
    req = urllib.request.Request(
        url + path, data=json.dumps(payload).encode(), headers=headers, method="POST"
    )
    with opener.open(req, timeout=60) as resp:
        body = resp.read().decode() or "{}"
    return json.loads(body)


def main():
    ap = argparse.ArgumentParser(
        description="Mint an access/refresh token pair from a SASjs Server with local auth."
    )
    ap.add_argument("--url", default=os.environ.get("SASJS_URL"), required=False,
                    help="server root, e.g. https://example.com (or set SASJS_URL)")
    ap.add_argument("--user", default=os.environ.get("SASJS_USER"),
                    help="local-auth username (or set SASJS_USER)")
    ap.add_argument("--password", default=os.environ.get("SASJS_PASS"),
                    help="password (or set SASJS_PASS; prefer the env var)")
    ap.add_argument("--client", default=os.environ.get("SASJS_CLIENT", "clientID1"),
                    help="OAuth client id registered on the server (default clientID1)")
    ap.add_argument("--out", help="write CLIENT/ACCESS_TOKEN/REFRESH_TOKEN here")
    ap.add_argument("--quiet", action="store_true", help="print nothing on success")
    args = ap.parse_args()

    if not (args.url and args.user and args.password):
        ap.error("--url, --user and --password (or SASJS_URL, SASJS_USER, SASJS_PASS) are required")

    url = args.url.rstrip("/")
    jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))

    try:
        with opener.open(url + "/", timeout=60) as resp:  # sets the XSRF cookie
            resp.read()

        xsrf = next((c.value for c in jar if c.name == "XSRF-TOKEN"), None)
        if not xsrf:
            sys.exit("no XSRF-TOKEN cookie returned by GET / - is this a server-mode instance?")

        login = post(opener, url, "/SASLogon/login",
                     {"username": args.user, "password": args.password}, xsrf)
        if not login.get("loggedIn"):
            sys.exit("login refused: %s" % json.dumps(login)[:200])

        code = post(opener, url, "/SASLogon/authorize", {"clientId": args.client}, xsrf).get("code")
        if not code:
            sys.exit("no authorization code returned - check the client id (%s)" % args.client)

        tok = post(opener, url, "/SASjsApi/auth/token",
                   {"clientId": args.client, "code": code})
    except urllib.error.HTTPError as err:
        sys.exit("%s %s: %s" % (err.code, err.reason, err.read().decode()[:300]))

    access, refresh = tok.get("accessToken"), tok.get("refreshToken")
    if not (access and refresh):
        sys.exit("token exchange returned no pair: %s" % json.dumps(tok)[:200])

    if args.out:
        with open(args.out, "w") as fh:
            fh.write("CLIENT=%s\nACCESS_TOKEN=%s\nREFRESH_TOKEN=%s\n" % (args.client, access, refresh))
    if not args.quiet:
        print("signed in as %s; tokens minted%s" % (args.user, (" -> " + args.out) if args.out else ""))


if __name__ == "__main__":
    main()
