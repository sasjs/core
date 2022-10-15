/**
  @file
  @brief Pulls latest release info from a GIT repository
  @details Useful for grabbing the latest version number or other attributes
  from a GIT server.  Supported providers are GitLab and GitHub. Pull requests
  are welcome if you'd like to see additional providers!

  Note that each provider provides slightly different JSON output.  Therefore
  the macro simply extracts the JSON and assigns the libname (using the JSON
  engine).

  Example usage (eg, to grab latest release version from github):

      %mp_gitreleaseinfo(GITHUB,sasjs/core,outlib=mylibref)

      data _null_;
        set mylibref.root;
        putlog TAG_NAME=;
      run;

  @param [in] provider The GIT provider for the release info.  Accepted values:
    @li GITLAB
    @li GITHUB - Tables include root, assets, author, alldata
  @param [in] project The link to the repository.  This has different formats
    depending on the vendor:
    @li GITHUB - org/repo, eg sasjs/core
    @li GITLAB - project, eg 1343223
  @param [in] server= (0) If your repo is self-hosted, then provide the domain
    here.  Otherwise it will default to the provider domain (eg gitlab.com).
  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages
  @param [out] outlib= (GITREL) The JSON-engine libref to be created, which will
    point at the returned JSON

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas

  <h4> Related Files </h4>
  @li mp_gitreleaseinfo.test.sas

**/

%macro mp_gitreleaseinfo(provider,project,server=0,outlib=GITREL,mdebug=0);
%local url fref;

%let provider=%upcase(&provider);

%if &provider=GITHUB %then %do;
  %if "&server"="0" %then %let server=https://api.github.com;
  %let url=&server/repos/&project/releases/latest;
%end;
%else %if &provider=GITLAB %then %do;
  %if "&server"="0" %then %let server=https://gitlab.com;
  %let url=&server/api/v4/projects/&project/releases;
%end;

%let fref=%mf_getuniquefileref();

proc http method='GET' out=&fref url="&url";
%if &mdebug=1 %then %do;
  debug level = 3;
%end;
run;

libname &outlib JSON fileref=&fref;

%if &mdebug=1 %then %do;
  data _null_;
    infile &fref;
    input;
    putlog _infile_;
  run;
%end;

%mend mp_gitreleaseinfo;
