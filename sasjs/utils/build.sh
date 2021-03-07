#!/bin/bash
####################################################################
# PROJECT: Macro Core Docs Build                                   #
# To execute, use the npm command (npm run docs)                   #
####################################################################

# refresh github pages site
rm -rf sasjsbuild/docsite
git clone git@github.com:sasjs/core.github.io.git sasjsbuild/docsite
rm -rf sasjsbuild/docsite/*
mv sasjsbuild/docs/* sasjsbuild/docsite/
cd sasjsbuild/docsite/
echo 'core.sasjs.io' > CNAME
git add .
git commit -m "build.sh build on $(date +%F:%H:%M:%S)"
git push
npx sitemap-generator-cli https://core.sasjs.io
git add .
git commit -m "adding sitemap"
git push

echo "check it out:  https://sasjs.github.io/core.github.io/files.html"
