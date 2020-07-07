# Macro Core

Much quality. Many standards. The **Macro Core** library exists to save time and development effort! Herein ye shall find a veritable host of MIT-licenced, production quality SAS macros. These are a mix of tools, utilities, functions and code generators that are useful in the context of Application Development on the SAS platform (eg https://datacontroller.io). [Contributions](https://github.com/sasjs/core/blob/master/CONTRIBUTING.md) are welcomed.

You can download and compile them all in just two lines of SAS code:

```sas
filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
%inc mc;
```

Documentation: https://sasjs.github.io/core.github.io/files.html

# Components

**base** library (SAS9/Viya)

- OS independent
- Not metadata aware
- No X command
- Prefixes: _mf_, _mp_

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

# Installation

First, download the repo to a location your SAS system can access. Then update your sasautos path to include the components you wish to have available,eg:

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
- filenames must be lowercase
- macro names must be lowercase
- one macro per file
- prefixes:
  - _mf_ for macro functions (can be used in open code).
  - _mp_ for macro procedures (which generate sas code)
  - _mm_ for metadata macros (interface with the metadata server).
  - _mmx_ for macros that use metadata and are XCMD enabled
  - _mx_ for macros that are XCMD enabled
  - _mv_ for macros that will only work in Viya
- follow verb-noun convention
- unix style line endings (lf)
- individual lines should be no more than 80 characters long
- UTF-8
- no trailing white space

## Header Properties

The **Macro Core** documentation is created using [doxygen](http://www.doxygen.nl). A full list of attributes can be found [here](http://www.doxygen.nl/manual/commands.html) but the following are most relevant:

- file. This needs to be present in order to be recognised by doxygen.
- brief. This is a short (one sentence) description of the macro.
- details. A longer description, which can contain doxygen [markdown](http://www.stack.nl/~dimitri/doxygen/manual/markdown.html).
- param. Name of each input param followed by a description.
- return. Explanation of what is returned by the macro.
- version. The EARLIEST SAS version in which this macro is known to work.
- author. Author name, contact details optional

All macros must be commented in the doxygen format, to enable the [online documentation](https://sasjs.github.io/core.github.io/).

## Coding Standards

- Indentation = 2 spaces. No tabs!
- Macro variables should not have the trailing dot (`&var` not `&var.`) unless necessary to prevent incorrect resolution
- The closing `%mend;` should not contain the macro name.
- All macros should be defined with brackets, even if no variables are needed - ie `%macro x();` not `%macro x;`
- Mandatory parameters should be positional, all optional parameters should be keyword (var=) style.
- All dataset references must be 2 level (eg `work.blah`, not `blah`). This is to avoid contention when options [DATASTMTCHK](https://support.sas.com/documentation/cdl/en/lrdict/64316/HTML/default/viewer.htm#a000279064.htm)=ALLKEYWORDS is in effect.
- Avoid naming collisions! All macro variables should be local scope. Use system generated work tables where possible - eg `data ; set sashelp.class; run; data &output; set &syslast; run;`

# General Notes

- All macros should be compatible with SAS versions from support level B and above (so currently 9.2 and later). If an earlier version is not supported, then the macro should say as such in the header documentation, and exit gracefully (eg `%if %sysevalf(&sysver<9.3) %then %return`).
