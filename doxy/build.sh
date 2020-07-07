#!/bin/bash
####################################################################
# PROJECT: Macro Core Docs Build                                   #
####################################################################

BUILD_FOLDER="/tmp/macrocore_docs"

# move to project root
cd ..

# create build directory
rm -rf $BUILD_FOLDER
mkdir $BUILD_FOLDER

# copy relevant files
cp -r base $BUILD_FOLDER
cp -r meta $BUILD_FOLDER
cp -r metax $BUILD_FOLDER
cp -r viya $BUILD_FOLDER
cp -r doxy $BUILD_FOLDER
cp main.dox $BUILD_FOLDER
cp doxy/Doxyfile $BUILD_FOLDER

# update Doxyfile and generate
cd $BUILD_FOLDER
echo "OUTPUT_DIRECTORY=$BUILD_FOLDER/out" >> $BUILD_FOLDER/Doxyfile
echo "INPUT+=main.dox" >> $BUILD_FOLDER/Doxyfile
doxygen Doxyfile

# refresh github pages site
git clone git@github.com:macropeople/macrocore.github.io.git
cd macrocore.github.io
git rm -r *
mv $BUILD_FOLDER/out/doxy/* .
echo 'core.sasjs.io' > CNAME
git add *
git commit -m "build.sh build on $(date +%F:%H:%M:%S)"
git push

echo "check it out:  https://macropeople.github.io/macrocore.github.io/files.html"
