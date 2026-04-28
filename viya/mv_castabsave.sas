/**
  @file mv_castabsave.sas
  @brief Saves an in-memory CAS table back to persistent storage
  @details Runs in SPRE against an active CAS session.  Accepts a
    SAS libref, derives the CAS caslib and session UUID from
    sashelp.vlibnam, locates the owning CAS server via the
    casManagement REST API, then queries the table endpoint to
    discover the original source file and saves back to that path.
    CASUTIL infers the file type from the output file extension.

    A CAS session must already be established by the caller, eg:

        cas mysess;
        libname mylib cas caslib=Public;
        %mv_castabsave(lib=mylib, table=BASEBALL)

  @param [in] lib=    SAS libref for the CAS caslib
  @param [in] table=  Name of the in-memory CAS table to save
  @param [in] mdebug= (0) Set to 1 to enable verbose logging:
                        - echoes resolved parameters
                        - prints HTTP response body
                        - enables mprint/notes during PROC calls

  <h4> SAS Macros </h4>
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mp_abort.sas

**/

%macro mv_castabsave(
    lib=
    ,table=
    ,mdebug=0
);

%local _sysopts base_uri caslib uuid server
      srcfile srccaslib fname1 libref1 ftmp i _svcount;
%let _sysopts=%sysfunc(getoption(mprint)) %sysfunc(getoption(notes));

/* ---- input validation -------------------------------------------------- */
%mp_abort(
  iftrue=("&lib"="" or "&table"=""),
  msg=%str(lib= and table= are required)
)

%if &mdebug=1 %then %do;
  %put &=lib;
  %put &=table;
  options mprint notes;
%end;

/* ---- derive caslib and session UUID from sashelp.vlibnam --------------- */
data _null_;
  set sashelp.vlibnam(
    where=(libname="%upcase(&lib)"
      and sysname in ("Caslib","Session UUID"))
  );
  if sysname="Caslib" then call symputx('caslib',sysvalue,'L');
  else call symputx('uuid',sysvalue,'L');
run;

%mp_abort(
  iftrue=("&caslib"=""),
  msg=%str(&lib is not an assigned CAS libref)
)

%mp_abort(
  iftrue=("&uuid"=""),
  msg=%str(No session UUID found for libref &lib)
)

%if &mdebug=1 %then %do;
  %put &=caslib;
  %put &=uuid;
%end;

%let base_uri=%mf_getplatform(VIYARESTAPI);

/* ---- get list of CAS servers ------------------------------------------- */
%let fname1=%mf_getuniquefileref();
%let libref1=%mf_getuniquelibref();

proc http method='GET' out=&fname1 oauth_bearer=sas_services
    url="&base_uri/casManagement/servers";
run;

%mp_abort(
  iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 200),
  msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
)

libname &libref1 JSON fileref=&fname1;

data _null_;
  set &libref1..items;
  call symputx(cats('_sv_', _n_), name, 'L');
  call symputx('_svcount', _n_, 'L');
run;

libname &libref1 clear;
filename &fname1 clear;

/* ---- find which server owns this session ------------------------------- */
%do i=1 %to &_svcount;
  %if "&server"="" %then %do;
    %if &mdebug=1 %then %put checking server: &&_sv_&i;
    %let ftmp=%mf_getuniquefileref();
    proc http method='GET' out=&ftmp oauth_bearer=sas_services
        url="&base_uri/casManagement/servers/&&_sv_&i/sessions/&uuid";
    run;
    %if &SYS_PROCHTTP_STATUS_CODE=200
      %then %let server=&&_sv_&i;
    filename &ftmp clear;
  %end;
%end;

%mp_abort(
  iftrue=("&server"=""),
  msg=%str(Could not find owning server for CAS session &uuid)
)

%if &mdebug=1 %then %put &=server;

/* ---- discover srcfile from REST endpoint ------------------------------- */
%let fname1=%mf_getuniquefileref();
%let libref1=%mf_getuniquelibref();

proc http method='GET' out=&fname1 oauth_bearer=sas_services
    url="&base_uri/casManagement/servers/&server/caslibs/&caslib/tables/&table";
run;

%if &mdebug=1 %then %do;
  %put &=SYS_PROCHTTP_STATUS_CODE &=SYS_PROCHTTP_STATUS_PHRASE;
  data _null_;
    infile &fname1;
    input;
    putlog _infile_;
  run;
%end;

%mp_abort(
  iftrue=(&SYS_PROCHTTP_STATUS_CODE=404),
  msg=%str(&caslib..&table not found - is it loaded in memory?)
)
%mp_abort(
  iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 200),
  msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
)

libname &libref1 JSON fileref=&fname1;

data _null_;
  set &libref1..tablereference;
  call symputx('srcfile', sourceTableName, 'L');
  call symputx('srccaslib', sourceCaslibName, 'L');
  stop;
run;

libname &libref1 clear;
filename &fname1 clear;

%mp_abort(
  iftrue=("&srcfile"="" or "&srccaslib"=""),
  msg=%str(No sourceTableName/sourceCaslibName for &caslib..&table)
)

%if &mdebug=1 %then %put &=srcfile;

/* ---- save to disk ------------------------------------------------------- */
proc casutil;
  save casdata="&table"
      incaslib="&caslib"
      casout="&srcfile"
      outcaslib="&srccaslib"
      replace;
quit;

%mp_abort(
  iftrue=(&syscc ne 0),
  msg=%str(Save failed for &caslib..&table)
)

%put NOTE: Table &caslib..&table saved to &srcfile;

/* ---- restore options --------------------------------------------------- */
%if &mdebug=1 %then %do;
  options &_sysopts;
%end;

%mend mv_castabsave;
