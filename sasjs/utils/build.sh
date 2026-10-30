#!/bin/bash
####################################################################
# PROJECT: SASjs Core Docs Build
# To execute, use the npm command (npm run docs)
# Publishes the doxygen output to sasjs/core.github.io, including the
# sitemap.xml that describes it.
####################################################################

# refresh github pages site
rm -rf sasjsbuild/docsite
git clone git@github.com:sasjs/core.github.io.git sasjsbuild/docsite
rm -rf sasjsbuild/docsite/*.html
rm -rf sasjsbuild/docsite/*.js
rm -rf sasjsbuild/docsite/*.png
rm -rf sasjsbuild/docsite/*.dot
rm -rf sasjsbuild/docsite/*.css
rm -rf sasjsbuild/docsite/*.svg
rm -rf search
cp -R sasjsbuild/docs/* sasjsbuild/docsite/
cd sasjsbuild/docsite/
git config user.name sasjs
echo 'core.sasjs.io' > CNAME
git add .
git commit -m "build.sh build on $(date +%F:%H:%M:%S)"

# the pages are committed before the sitemap is generated, so each <lastmod> is
# the commit date of the page it describes; both commits go in one push
python3 ../../sasjs/utils/sitemap.py .
git add sitemap.xml
git diff --staged --quiet || git commit -m "chore: update sitemap"
git push

echo "check it out:  https://sasjs.github.io/core.github.io/files.html"
