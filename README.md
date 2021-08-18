# Macro Core
[![npm package][npm-image]][npm-url]
[![Github Workflow][githubworkflow-image]][githubworkflow-url]
[![Dependency Status][dependency-image]][dependency-url]
[![npm](https://img.shields.io/npm/dt/@sasjs/core)]()
![Snyk Vulnerabilities for npm package](https://img.shields.io/snyk/vulnerabilities/npm/@sasjs/core)
[![License](https://img.shields.io/apm/l/atomic-design-ui.svg)](/LICENSE)
![GitHub top language](https://img.shields.io/github/languages/top/sasjs/core)
[![GitHub closed issues](https://img.shields.io/github/issues-closed-raw/sasjs/core)](https://github.com/sasjs/core/issues?q=is%3Aissue+is%3Aclosed)
[![GitHub issues](https://img.shields.io/github/issues-raw/sasjs/core)](https://github.com/sasjs/core/issues)
![total lines](https://tokei.rs/b1/github/sasjs/core)
[![Gitpod ready-to-code](https://img.shields.io/badge/Gitpod-ready--to--code-908a85?logo=gitpod)](https://gitpod.io/#https://github.com/sasjs/core)


[npm-image]:https://img.shields.io/npm/v/@sasjs/core.svg
[npm-url]:http://npmjs.org/package/@sasjs/core
[githubworkflow-image]:https://github.com/sasjs/core/actions/workflows/main.yml/badge.svg
[githubworkflow-url]:https://github.com/sasjs/core/blob/main/.github/workflows/main.yml
[dependency-image]:https://david-dm.org/sasjs/core.svg
[dependency-url]:https://github.com/sasjs/core/blob/main/package.json



Much quality. Many standards. The **Macro Core** library exists to save time and development effort! Herein ye shall find a veritable host of MIT-licenced, production quality SAS macros. These are a mix of tools, utilities, functions and code generators that are useful in the context of [Application Development](https://sasapps.io) on the SAS platform (eg https://datacontroller.io). [Contributions](https://github.com/sasjs/core/blob/main/CONTRIBUTING.md) are welcomed.

You can download and compile them all in just two lines of SAS code:

```sas
filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
%inc mc;
```

Documentation: https://core.sasjs.io

# Components

**base** library (SAS9/Viya)

- OS independent
- Not metadata aware
- No X command
- Prefixes: _mf_, _mp_

**fcmp** library (SAS9/Viya)
- Function and macro names are identical, except for special cases
- Prefixes: _mcf_

The fcmp macros are used to generate fcmp functions, and can be used with or
without the `proc fcmp` wrapper.

**meta** library (SAS9 only)

- OS independent
- Metadata aware
- No X command
- Prefixes: _mm_

**viya** library (Viya only)

- OS independent
- No X command
- Prefixes: _mv_

**metax** library (SAS9 only)

- OS specific
- Metadata aware
- X command enabled
- Prefixes: _mmw_,_mmu_,_mmx_

**lua** library

Wait - this is a macro library - what is LUA doing here?  Well, it is a little known fact that you CAN run LUA within a SAS Macro.  It has to be written to a text file with a `.lua` extension, from where you can `%include` it.  So, without using the `proc lua` wrapper.

To contribute, simply write your freeform LUA in the LUA folder.  Then run the `build.py`, which will convert your LUA into a data step with put statements, and create the macro wrapper with a `ml_` prefix.  You can then use your module in any program by running:

```
/* compile the lua module */
%ml_yourmodule()

/* Execute.  Do not use the restart keyword! */
proc lua;
submit;
  print(yourStuff);
endsubmit;
run;
```

- X command enabled
- Prefixes: _mmw_,_mmu_,_mmx_

# Installation

First, download the repo to a location your SAS system can access. Then update your sasautos path to include the components you wish to have available, eg:

```sas
options insert=(sasautos="/your/path/macrocore/base");
options insert=(sasautos="/your/path/macrocore/meta");
```

The above can be done directly in your sas program, via an autoexec, or an initialisation program.

Alternatively - for quick access - simply run the following! This file contains all the macros.

```sas
filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
%inc mc;
```

# Standards

## File Properties

- filenames much match macro names
- filenames must be lowercase, without spaces
- macro names must be lowercase
- one macro per file
- prefixes:
  - _mf_ for macro functions (can be used in open code).
  - _mp_ for macro procedures (which generate sas code)
  - _mm_ for metadata macros (interface with the metadata server).
  - _mmx_ for macros that use metadata and are XCMD enabled
  - _mx_ for macros that are XCMD enabled
  - _ml_ for macros that are used to compile LUA modules
  - _mv_ for macros that will only work in Viya
- follow verb-noun convention
- unix style line endings (lf)
- individual lines should be no more than 80 characters long
- UTF-8


## Header Properties

The **Macro Core** documentation is created using [doxygen](http://www.doxygen.nl). A full list of attributes can be found [here](http://www.doxygen.nl/manual/commands.html) but the following are most relevant:

- file. This needs to be present in order to be recognised by doxygen.
- brief. This is a short (one sentence) description of the macro.
- details. A longer description, which can contain doxygen [markdown](http://www.stack.nl/~dimitri/doxygen/manual/markdown.html).
- param. Name of each input param followed by a description.
- return. Explanation of what is returned by the macro.
- version. The EARLIEST SAS version in which this macro is known to work.
- author. Author name, contact details optional

All macros must be commented in the doxygen format, to enable the [online documentation](https://core.sasjs.io).

### Dependencies
SAS code can contain one of two types of dependency - SAS Macros, and SAS Includes.  When compiling projects using the [SASjs CLI](https://cli.sasjs.io) the doxygen header is scanned for `  @li` items under the following headers:

```sas
  <h4> SAS Macros </h4>
  @li mf_nobs.sas
  @li mm_assignlib.sas

  <h4> SAS Includes </h4>
  @li somefile.ddl SOMEFREF
  @li someprogram.sas FREFTWO
```

The CLI can then extract all the dependencies and insert as precode (SAS Macros) or in a temp engine fileref (SAS Includes) when creating SAS Jobs and Services.

When contributing to this library, it is therefore important to ensure that all dependencies are listed in the header in this format.


## Coding Standards

- Indentation = 2 spaces. No tabs!
- no trailing white space
- no invisible characters, other than spaces. If invisibles are needed, use hex literals.
- Macro variables should not have the trailing dot (`&var` not `&var.`) unless necessary to prevent incorrect resolution
- The closing `%mend;` should **not** contain the macro name.
- All macros should be defined with brackets, even if no variables are needed - ie `%macro x();` not `%macro x;`
- Mandatory parameters should be positional, all optional parameters should be keyword (var=) style.
- All dataset references must be 2 level (eg `work.blah`, not `blah`). This is to avoid contention when options [DATASTMTCHK](https://support.sas.com/documentation/cdl/en/lrdict/64316/HTML/default/viewer.htm#a000279064.htm)=ALLKEYWORDS is in effect.
- Avoid naming collisions! All macro variables should be local scope. Use system generated work tables where possible - eg `data ; set sashelp.class; run; data &output; set &syslast; run;`
- The use of `quit;` for `proc sql` is optional unless you are looking to benefit from the timing statistics.

# General Notes

- All macros should be compatible with SAS versions from support level B and above (so currently 9.2 and later). If an earlier version is not supported, then the macro should say as such in the header documentation, and exit gracefully (eg `%if %sysevalf(&sysver<9.3) %then %return`).

## Star Gazing

If you find this library useful, please leave a [star](https://github.com/sasjs/core/stargazers) and help us grow our star graph!

![](https://starchart.cc/sasjs/core.svg)




## Contributors ✨
<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->
[![All Contributors](https://img.shields.io/badge/all_contributors-8-orange.svg?style=flat-square)](#contributors-)
<!-- ALL-CONTRIBUTORS-BADGE:END -->
Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tr>
    <td align="center"><a href="https://github.com/allanbowe"><img src="https://avatars.githubusercontent.com/u/4420615?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Allan Bowe</b></sub></a><br /><a href="#business-allanbowe" title="Business development">💼</a> <a href="https://github.com/sasjs/core/commits?author=allanbowe" title="Code">💻</a> <a href="#content-allanbowe" title="Content">🖋</a> <a href="https://github.com/sasjs/core/commits?author=allanbowe" title="Documentation">📖</a> <a href="#infra-allanbowe" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="#maintenance-allanbowe" title="Maintenance">🚧</a> <a href="#mentoring-allanbowe" title="Mentoring">🧑‍🏫</a> <a href="#question-allanbowe" title="Answering Questions">💬</a> <a href="https://github.com/sasjs/core/pulls?q=is%3Apr+reviewed-by%3Aallanbowe" title="Reviewed Pull Requests">👀</a> <a href="https://github.com/sasjs/core/commits?author=allanbowe" title="Tests">⚠️</a></td>
    <td align="center"><a href="https://github.com/rafgag"><img src="https://avatars.githubusercontent.com/u/69139928?v=4?s=100" width="100px;" alt=""/><br /><sub><b>rafgag</b></sub></a><br /><a href="https://github.com/sasjs/core/commits?author=rafgag" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/tmoody"><img src="https://avatars.githubusercontent.com/u/79837106?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Trevor Moody</b></sub></a><br /><a href="https://github.com/sasjs/core/commits?author=tmoody" title="Code">💻</a></td>
    <td align="center"><a href="https://krishna-acondy.io/"><img src="https://avatars.githubusercontent.com/u/2980428?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Krishna Acondy</b></sub></a><br /><a href="https://github.com/sasjs/core/commits?author=krishna-acondy" title="Code">💻</a> <a href="#infra-krishna-acondy" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="#blog-krishna-acondy" title="Blogposts">📝</a> <a href="#content-krishna-acondy" title="Content">🖋</a> <a href="#ideas-krishna-acondy" title="Ideas, Planning, & Feedback">🤔</a> <a href="#video-krishna-acondy" title="Videos">📹</a></td>
    <td align="center"><a href="https://github.com/saadjutt01"><img src="https://avatars.githubusercontent.com/u/8914650?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Muhammad Saad </b></sub></a><br /><a href="https://github.com/sasjs/core/commits?author=saadjutt01" title="Code">💻</a> <a href="#ideas-saadjutt01" title="Ideas, Planning, & Feedback">🤔</a></td>
    <td align="center"><a href="https://www.erudicat.com/"><img src="https://avatars.githubusercontent.com/u/25773492?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Yury Shkoda</b></sub></a><br /><a href="https://github.com/sasjs/core/commits?author=YuryShkoda" title="Code">💻</a> <a href="#infra-YuryShkoda" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="#video-YuryShkoda" title="Videos">📹</a></td>
    <td align="center"><a href="https://github.com/medjedovicm"><img src="https://avatars.githubusercontent.com/u/18329105?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Mihajlo Medjedovic</b></sub></a><br /><a href="#infra-medjedovicm" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a></td>
  </tr>
  <tr>
    <td align="center"><a href="https://github.com/kkchandok"><img src="https://avatars.githubusercontent.com/u/46090627?v=4?s=100" width="100px;" alt=""/><br /><sub><b>kkchandok</b></sub></a><br /><a href="#ideas-kkchandok" title="Ideas, Planning, & Feedback">🤔</a></td>
  </tr>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!
