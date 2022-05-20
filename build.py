import os
from pathlib import Path

# Prepare Lua Macros
files = [f for f in Path('lua').iterdir() if f.match("*.lua")]
for file in files:
    basename = os.path.basename(file)
    name = 'ml_' + os.path.splitext(basename)[0]
    ml = open('lua/' + name + '.sas', "w")
    ml.write("/**\n")
    ml.write("  @file " + name + '.sas\n')
    ml.write("  @brief Compiles the " + basename + " lua file\n")
    ml.write("  @details Writes " + basename + " to the work directory\n")
    ml.write("  and then includes it.\n")
    ml.write("  Usage:\n\n")
    ml.write("      %" + name + "()\n\n")
    ml.write("**/\n\n")
    ml.write("%macro " + name + "();\n")
    ml.write("data _null_;\n")
    ml.write("  file \"%sysfunc(pathname(work))/" + name + ".lua\";\n")
    with open(file) as infile:
        for line in infile:
            ml.write("  put '" + line.rstrip().replace("'", "''") + " ';\n")
    ml.write("run;\n\n")

    ml.write("/* ensure big enough lrecl to avoid lua compilation issues */\n")
    ml.write("%local optval;\n")
    ml.write("%let optval=%sysfunc(getoption(lrecl));\n")
    ml.write("options lrecl=1024;\n\n")
    ml.write("/* execute the lua code by using a .lua extension */\n")
    ml.write("%inc \"%sysfunc(pathname(work))/" +
             name + ".lua\" /source2;\n\n")
    ml.write("options lrecl=&optval;\n\n")
    ml.write("%mend " + name + ";\n")

ml.close()

# prepare web files
files = ['viya/mv_createwebservice.sas',
         'meta/mm_createwebservice.sas', 'server/ms_createwebservice.sas']
for file in files:
    webout0 = open('base/mp_jsonout.sas', 'r')
    webout1 = open('base/mf_getuser.sas', 'r')

    if file == 'viya/mv_createwebservice.sas':
        webout2 = open('viya/mv_webout.sas', "r")
        weboutfiles = [webout0, webout1, webout2]
    elif file == 'server/ms_createwebservice.sas':
        webout2 = open('server/ms_webout.sas', "r")
        webout3 = open('server/mfs_httpheader.sas', 'r')
        weboutfiles = [webout0, webout1, webout2, webout3]
    else:
        webout2 = open('meta/mm_webout.sas', 'r')
        weboutfiles = [webout0, webout1, webout2]
    outfile = open(file + 'TEMP', 'w')
    infile = open(file, 'r')
    delrow = 0
    for line in infile:
        if line == '/* WEBOUT BEGIN */\n':
            delrow = 1
            outfile.write('/* WEBOUT BEGIN */\n')
            for weboutfile in weboutfiles:
                stripcomment = 1
                for w in weboutfile:
                    if w == '**/\n':
                        stripcomment = 0
                    elif stripcomment == 0:
                        outfile.write(
                            "  put '" + w.rstrip().replace("'", "''") + " ';\n")
        elif delrow == 1 and line == '/* WEBOUT END */\n':
            delrow = 0
            outfile.write('/* WEBOUT END */\n')
        elif delrow == 0:
            outfile.write(line.rstrip() + "\n")
    webout0.close()
    webout1.close()
    webout2.close()
    outfile.close()
    infile.close()
    os.remove(file)
    os.rename(file + 'TEMP', file)

# Concatenate all macros into a single file
header = """
/**
  @file
  @brief Auto-generated file
  @details
    This file contains all the macros in a single file - which means it can be
    'included' in SAS with just 2 lines of code:

      filename mc url
        "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

    The `build.py` file in the https://github.com/sasjs/core repo
    is used to create this file.

  @author Allan Bowe
**/
options noquotelenmax;
"""
f = open('all.sas', "w")             # r / r+ / rb / rb+ / w / wb
f.write(header)
folders = ['base', 'ddl', 'meta', 'metax', 'server', 'viya', 'lua', 'fcmp', 'xplatform']
for folder in folders:
    filenames = [fn for fn in Path(
        './' + folder).iterdir() if fn.match("*.sas")]
    filenames.sort()
    with open('mc_' + folder + '.sas', 'w') as outfile:
        for fname in filenames:
            with open(fname) as infile:
                outfile.write(infile.read())
    with open('mc_' + folder + '.sas', 'r') as c:
        f.write(c.read())
f.close()
