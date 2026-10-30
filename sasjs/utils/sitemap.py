#!/usr/bin/env python3
"""
Generates the sitemap.xml for the core.sasjs.io documentation site.

The docs pipeline in .github/workflows/main.yml publishes the doxygen output to
the sasjs/core.github.io repository, and runs this script there so the sitemap
lands in the same push as the pages it describes - there is no separate sitemap
job, and no pull request to merge after a release.

Usage (from the root of a checked-out core.github.io clone):

    python3 ../sasjs/utils/sitemap.py .

Each <lastmod> is the commit date of the last commit that touched the file.
Files generated during the current run are committed before this script runs,
so their lastmod is the date of that commit rather than the wall clock.  A file
that is not yet committed falls back to its modification time, which is correct
for a first build but drifts on every run - commit first.
"""

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

SKIP_DIRS = {'.git', 'node_modules', '.github'}
SITEMAP_NAME = 'sitemap.xml'


def last_modified(root, rel_path):
    """Returns the UTC timestamp of the last commit touching rel_path."""
    result = subprocess.run(
        ['git', '-C', str(root), 'log', '-1', '--format=%ct', '--', rel_path],
        capture_output=True, text=True
    )
    stamp = result.stdout.strip()
    if stamp:
        seconds = int(stamp)
    else:
        seconds = int((root / rel_path).stat().st_mtime)
    return time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(seconds))


def page_url(rel_path, base_url):
    """Maps a file to its URL, collapsing index.html to the directory URL."""
    path = rel_path[:-len('index.html')] if rel_path.endswith('index.html') else rel_path
    return base_url.rstrip('/') + '/' + path


def collect_pages(root, base_url):
    pages = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
        for filename in sorted(filenames):
            if not filename.endswith('.html'):
                continue
            full = Path(dirpath) / filename
            rel_path = full.relative_to(root).as_posix()
            pages.append((page_url(rel_path, base_url), last_modified(root, rel_path)))
    # the sitemap is sorted by URL so an unchanged site produces an unchanged file
    return sorted(pages)


def main():
    parser = argparse.ArgumentParser(description='Writes sitemap.xml for the docs site')
    parser.add_argument('root', nargs='?', default='.', help='root of the published site')
    parser.add_argument('--base-url', default='https://core.sasjs.io',
                        help='public URL of the site root')
    parser.add_argument('--output', default=SITEMAP_NAME,
                        help='sitemap path, relative to root')
    args = parser.parse_args()

    root = Path(args.root).resolve()
    if not root.is_dir():
        sys.exit(f'not a directory: {root}')

    pages = collect_pages(root, args.base_url)

    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">']
    for url, lastmod in pages:
        lines += ['<url>', f'<loc>{url}</loc>', f'<lastmod>{lastmod}</lastmod>', '</url>']
    lines.append('</urlset>')

    target = root / args.output
    target.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(f'{target}: {len(pages)} urls')


if __name__ == '__main__':
    main()
