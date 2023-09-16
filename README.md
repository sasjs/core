# Macro Core
[![npm package][npm-image]][npm-url]
[![Github Workflow][githubworkflow-image]][githubworkflow-url]
![npm](https://img.shields.io/npm/dt/@sasjs/core)
![GitHub top language](https://img.shields.io/github/languages/top/sasjs/core)
[![GitHub closed issues](https://img.shields.io/github/issues-closed-raw/sasjs/core)](https://github.com/sasjs/core/issues?q=is%3Aissue+is%3Aclosed)
[![GitHub issues](https://img.shields.io/github/issues-raw/sasjs/core)](https://github.com/sasjs/core/issues)
![total lines](https://tokei.rs/b1/github/sasjs/core)
[![Gitpod ready-to-code](https://img.shields.io/badge/Gitpod-ready--to--code-908a85?logo=gitpod)](https://gitpod.io/#https://github.com/sasjs/core)


[npm-image]:https://img.shields.io/npm/v/@sasjs/core.svg
[npm-url]:http://npmjs.org/package/@sasjs/core
[githubworkflow-image]:https://github.com/sasjs/core/actions/workflows/main.yml/badge.svg
[githubworkflow-url]:https://github.com/sasjs/core/blob/main/.github/workflows/main.yml
[dependency-url]:https://github.com/sasjs/core/blob/main/package.json


Much quality. Many standards. The **Macro Core** library exists to save time and development effort! Herein ye shall find a veritable host of MIT-licenced, production quality SAS macros. These are a mix of tools, utilities, functions and code generators that are useful in the context of [Application Development](https://sasapps.io) on the SAS platform (eg https://datacontroller.io). [Contributions](https://github.com/sasjs/core/blob/main/.github/CONTRIBUTING.md) are welcome.

You can download and compile them all in just two lines of SAS code:

```sas
filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
%inc mc;
```

Documentation: https://core.sasjs.io

## Components

### BASE folder (All Platforms)

- OS independent
- Works on all SAS Platforms
- No X command
- Prefixes: `mf_`, `mp_`

### DDL folder (All Platforms)

- OS independent
- Works on all SAS Platforms
- No X command
- Prefixes: `mddl_(lib)_` -> where lib can be "SAS" (in relation to a SAS component) or "DC" (in relation to a Data Controller component)

This library will not be used for storing data entries (such as formats or datalines).  Where this becomes necessary in the future, a new repo will be created, in order to keep the NPM bundle size down (for the benefit of those looking to embed purely macros in their applications).

### FCMP folder (All Platforms)

- Function and macro names are identical, except for special cases
- Prefixes: `mcf_`

The fcmp macros are used to generate fcmp functions, and can be used with or without the `proc fcmp` wrapper.

### LUA folder

Wait - this is a macro library - what is LUA doing here?  Well, it is a little known fact that you CAN run LUA within a SAS Macro.  It has to be written to a text file with a `.lua` extension, from where you can `%include` it.  So, without using the `proc lua` wrapper.

To contribute, simply write your freeform LUA in the LUA folder.  Then run the `build.py`, which will convert all files with a ".lua" extension into a macro wrapper with an `ml_` prefix (embedding the necessary data step put statements).  You can then use your module in any program by running:

```sas
/* compile the lua module */
%ml_yourmodule()

/* Execute.  Do not use the restart keyword! */
proc lua;
submit;
  print(yourStuff);
endsubmit;
run;
```

- Prefixes: `ml_`

### META folder (SAS9 only)

Macros used in SAS EBI, which connect to the metadata server.

- OS independent
- Metadata aware
- No X command
- Prefixes: `mm_`

### METAX folder (SAS9 only)

- OS specific
- Metadata aware
- X command enabled
- Prefixes: `mmx_`

### SERVER folder (@sasjs/server only)
These macros are used for building applications using [@sasjs/server](https://server.sasjs.io) - an open source REST API for Desktop SAS.

- OS independent
- @sasjs/server aware
- No X command
- Prefixes: `ms_`

### VIYA folder (Viya only)

Macros used for interfacing with SAS Viya.

- OS independent
- No X command
- Prefixes: `mv_`, `mvf_`

### XPLATFORM folder (Viya, Meta, and Server)

Sometimes it is helpful to use a macro that can be used interchangeably regardless of the server type on which is is running (SASVIYA, SAS9, SASJS).

- OS independent
- No X command
- Prefixes: `mx_`

## Installation

First, download the repo to a location your SAS system can access. Then update your sasautos path to include the components you wish to have available, eg:

```sas
%let repoloc=/your/path/core;
options insert=(sasautos="&repoloc/base");
options insert=(sasautos="&repoloc/ddl");
options insert=(sasautos="&repoloc/fcmp");
options insert=(sasautos="&repoloc/lua");
options insert=(sasautos="&repoloc/meta");
options insert=(sasautos="&repoloc/metax");
options insert=(sasautos="&repoloc/server");
options insert=(sasautos="&repoloc/viya");
options insert=(sasautos="&repoloc/xplatform");
```

The above can be done directly in your sas program, via an autoexec, or an initialisation program.

Alternatively - for quick access - simply run the following! This file contains all the macros.

```sas
filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
%inc mc;
```

## Standards

### File Properties

- filenames much match macro names
- filenames must be lowercase, without spaces
- macro names must be lowercase
- one macro per file
- prefixes:
  - _mcf_ for macro compiled functions (proc fcmp)
  - _mddl_ for macros containing DDL (Data Definition Language)
  - _mf_ for macro functions (can be used in open code).
  - _ml_ for macros that are used to compile LUA modules
  - _mm_ for metadata macros (interface with the metadata server).
  - _mmx_ for macros that use metadata and are XCMD enabled (working on both windows and unix)
  - _mp_ for macro procedures (which generate sas code)
  - _ms_ for macro procedures that will only work with [@sasjs/server](https://github.com/sasjs/server)
  - _mv_ for macro procedures that will only work in Viya
  - _mx_ for macros that work on Viya, SAS 9 EBI and SASjs Server
- follow verb-noun convention
- unix style line endings (lf)
- individual lines should be no more than 80 characters long
- UTF-8


### Header Properties

The **Macro Core** documentation is created using [doxygen](http://www.doxygen.nl). A full list of attributes can be found [here](http://www.doxygen.nl/manual/commands.html) but the following are most relevant:

- file. This needs to be present in order to be recognised by doxygen.
- brief. This is a short (one sentence) description of the macro.
- details. A longer description, which can contain doxygen [markdown](http://www.stack.nl/~dimitri/doxygen/manual/markdown.html).
- param. Name of each input param followed by a description.
- return. Explanation of what is returned by the macro.
- version. The EARLIEST SAS version in which this macro is known to work.
- author. Author name, contact details optional

All macros must be commented in the doxygen format, to enable the [online documentation](https://core.sasjs.io).

#### Dependencies
SAS code can contain one of two types of dependency - SAS Macros, and SAS Includes.  When compiling projects using the [SASjs CLI](https://cli.sasjs.io) the doxygen header is scanned for `  @li` items under the following headers:

```sas
  <h4> SAS Macros </h4>
  @li mf_nobs.sas
  @li mm_assignlib.sas

  <h4> SAS Includes </h4>
  @li somefile.ddl SOMEFREF
  @li someprogram.sas FREFTWO
```

The CLI can then extract all the dependencies and insert as precode (SAS Macros) or in a temp engine fileref (SAS Includes) when creating SAS Jobs and Services (and Tests).

When contributing to this library, it is therefore important to ensure that all dependencies are listed in the header in this format.


### Coding Standards

- Indentation = 2 spaces. No tabs!
- no trailing white space
- no invisible characters, other than spaces. If invisibles are needed, use hex literals.
- Macro variables should not have the trailing dot (`&var` not `&var.`) unless necessary to prevent incorrect resolution
- The closing `%mend;` should **not** contain the macro name.
- All macros should be defined with brackets, even if no variables are needed - ie `%macro x();` not `%macro x;`
- Mandatory parameters should be positional, all optional parameters should be keyword (var=) style.
- All dataset references must be 2 level (eg `work.blah`, not `blah`). This is to avoid contention when options [DATASTMTCHK](https://support.sas.com/documentation/cdl/en/lrdict/64316/HTML/default/viewer.htm#a000279064.htm)=ALLKEYWORDS is in effect, or the [USER](https://documentation.sas.com/doc/en/pgmsascdc/9.4_3.5/lrcon/n18m1vkqmeo4esn1moikt23zhp8s.htm) library is active.
- Avoid naming collisions! All macro variables should be local scope. Use system generated work tables where possible - eg `data ; set sashelp.class; run; data &output; set &syslast; run;`
- Where global macro variables are absolutely necessary, they should make use of `&sasjs_prefix` - see mp_init.sas
- The use of `quit;` for `proc sql` is optional unless you are looking to benefit from the timing statistics.
- Use [sasjs lint](https://github.com/sasjs/lint)!

## General Notes

- All macros should be compatible with SAS versions from support level B and above (so currently 9.2 and later). If an earlier version is not supported, then the macro should say as such in the header documentation, and exit gracefully (eg `%if %sysevalf(&sysver<9.3) %then %return`).

## Breaking Changes

We are currently on major release v4.  Breaking changes should be marked with the [deprecated](https://www.doxygen.nl/manual/commands.html#cmddeprecated) doxygen tag.  The following changes are planned when the next major/breaking release (v5) becomes necessary:

* mf_getuniquelibref.sas to have the deprecated maxtried parameter removed (no longer needed)
* mp_testservice.sas to be renamed as mp_execute.sas (as it doesn't actually test anything)
* `insert_cmplib` option of mcf_xxx macros will be deprecated (the option is now checked automatically with value inserted only if needed)
* mcf_xxx macros to have `wrap=` option defaulted to YES for convenience.  Set this option explicitly to avoid issues.
* mp_getddl.sas to be renamed to mp_ds2ddl.sas (consistent with other ds2xxx macros).  A wrapper macro is already in place, and you are able to use this immediately.  The default for SHOWLOG will also be YES instead of NO.
* mp_coretable.sas will be replaced by the standalone macros in the `ddl` folder (which are already available)

## Star Gazing

If you find this library useful, please leave a [star](https://github.com/sasjs/core/stargazers) and help us grow our star graph!

![](https://starchart.cc/sasjs/core.svg)

## Other SAS Repositories

The following repositories are also worth checking out:

* [chris-swenson/sasmacros](https://github.com/chris-swenson/sasmacros)
* [greg-wotton/sas-programs](https://github.com/greg-wootton/sas-programs)
* [KatjaGlassConsulting/SMILE-SmartSASMacros](https://github.com/KatjaGlassConsulting/SMILE-SmartSASMacros)
* [paul-canals/toolbox](https://github.com/paul-canals/toolbox)
* [rogerjdeangelis](https://github.com/rogerjdeangelis)
* [SASJedi/sas-macros](https://github.com/SASJedi/sas-macros)
* [scottbass/sas](https://github.com/scottbass/SAS)
* [xieliaing/SAS](https://github.com/xieliaing/SAS)
* [yabwon/sas_packages](https://github.com/yabwon/SAS_PACKAGES)

## Contributors ✨
<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->
[![All Contributors](https://img.shields.io/badge/all_contributors-13-orange.svg?style=flat-square)](#contributors-)
<!-- ALL-CONTRIBUTORS-BADGE:END -->
Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/allanbowe"><img src="https://avatars.githubusercontent.com/u/4420615?v=4?s=100" width="100px;" alt="Allan Bowe"/><br /><sub><b>Allan Bowe</b></sub></a><br /><a href="#business-allanbowe" title="Business development">💼</a> <a href="https://github.com/sasjs/core/commits?author=allanbowe" title="Code">💻</a> <a href="#content-allanbowe" title="Content">🖋</a> <a href="https://github.com/sasjs/core/commits?author=allanbowe" title="Documentation">📖</a> <a href="#infra-allanbowe" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="#maintenance-allanbowe" title="Maintenance">🚧</a> <a href="#mentoring-allanbowe" title="Mentoring">🧑‍🏫</a> <a href="#question-allanbowe" title="Answering Questions">💬</a> <a href="https://github.com/sasjs/core/pulls?q=is%3Apr+reviewed-by%3Aallanbowe" title="Reviewed Pull Requests">👀</a> <a href="https://github.com/sasjs/core/commits?author=allanbowe" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/rafgag"><img src="https://avatars.githubusercontent.com/u/69139928?v=4?s=100" width="100px;" alt="rafgag"/><br /><sub><b>rafgag</b></sub></a><br /><a href="https://github.com/sasjs/core/commits?author=rafgag" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/tmoody"><img src="https://avatars.githubusercontent.com/u/79837106?v=4?s=100" width="100px;" alt="Trevor Moody"/><br /><sub><b>Trevor Moody</b></sub></a><br /><a href="https://github.com/sasjs/core/commits?author=tmoody" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://krishna-acondy.io/"><img src="https://avatars.githubusercontent.com/u/2980428?v=4?s=100" width="100px;" alt="Krishna Acondy"/><br /><sub><b>Krishna Acondy</b></sub></a><br /><a href="https://github.com/sasjs/core/commits?author=krishna-acondy" title="Code">💻</a> <a href="#infra-krishna-acondy" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="#blog-krishna-acondy" title="Blogposts">📝</a> <a href="#content-krishna-acondy" title="Content">🖋</a> <a href="#ideas-krishna-acondy" title="Ideas, Planning, & Feedback">🤔</a> <a href="#video-krishna-acondy" title="Videos">📹</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/saadjutt01"><img src="https://avatars.githubusercontent.com/u/8914650?v=4?s=100" width="100px;" alt="Muhammad Saad "/><br /><sub><b>Muhammad Saad </b></sub></a><br /><a href="https://github.com/sasjs/core/commits?author=saadjutt01" title="Code">💻</a> <a href="#ideas-saadjutt01" title="Ideas, Planning, & Feedback">🤔</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://www.erudicat.com/"><img src="https://avatars.githubusercontent.com/u/25773492?v=4?s=100" width="100px;" alt="Yury Shkoda"/><br /><sub><b>Yury Shkoda</b></sub></a><br /><a href="https://github.com/sasjs/core/commits?author=YuryShkoda" title="Code">💻</a> <a href="#infra-YuryShkoda" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="#video-YuryShkoda" title="Videos">📹</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/medjedovicm"><img src="https://avatars.githubusercontent.com/u/18329105?v=4?s=100" width="100px;" alt="Mihajlo Medjedovic"/><br /><sub><b>Mihajlo Medjedovic</b></sub></a><br /><a href="#infra-medjedovicm" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/kkchandok"><img src="https://avatars.githubusercontent.com/u/46090627?v=4?s=100" width="100px;" alt="kkchandok"/><br /><sub><b>kkchandok</b></sub></a><br /><a href="#ideas-kkchandok" title="Ideas, Planning, & Feedback">🤔</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/VladislavParhomchik"><img src="https://avatars.githubusercontent.com/u/83717836?v=4?s=100" width="100px;" alt="Vladislav Parhomchik"/><br /><sub><b>Vladislav Parhomchik</b></sub></a><br /><a href="https://github.com/sasjs/core/commits?author=VladislavParhomchik" title="Tests">⚠️</a> <a href="https://github.com/sasjs/core/pulls?q=is%3Apr+reviewed-by%3AVladislavParhomchik" title="Reviewed Pull Requests">👀</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/vznesh"><img src="https://avatars.githubusercontent.com/u/28916792?v=4?s=100" width="100px;" alt="Vignesh T."/><br /><sub><b>Vignesh T.</b></sub></a><br /><a href="https://github.com/sasjs/core/issues?q=author%3Avznesh" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/yabwon"><img src="https://avatars.githubusercontent.com/u/9314894?v=4?s=100" width="100px;" alt="Bart Jablonski"/><br /><sub><b>Bart Jablonski</b></sub></a><br /><a href="https://github.com/sasjs/core/commits?author=yabwon" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://bandism.net/"><img src="https://avatars.githubusercontent.com/u/22633385?v=4?s=100" width="100px;" alt="Ikko Ashimine"/><br /><sub><b>Ikko Ashimine</b></sub></a><br /><a href="https://github.com/sasjs/core/commits?author=eltociear" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/henrik-forsell"><img src="https://avatars.githubusercontent.com/u/109935936?v=4?s=100" width="100px;" alt="Henrik Forsell"/><br /><sub><b>Henrik Forsell</b></sub></a><br /><a href="https://github.com/sasjs/core/commits?author=henrik-forsell" title="Documentation">📖</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!
