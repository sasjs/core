#!/bin/bash
####################################################################
# PROJECT: SASjs Core Docs Build
# To execute, use the npm command (npm run docs)
# Target repo will have github action to create sitemap
# https://github.com/marketplace/actions/generate-sitemap
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
git push

echo "check it out:  https://sasjs.github.io/core.github.io/files.html"
