/**
  @file mv_castabload.sas
  @brief Checks if a CAS table exists in a CASLIB; if not, loads & promotes it
  @details Runs in SPRE against an active CAS session. Uses
    `table.tableExists` to check whether the table is already in-memory,
    and PROC CASUTIL LOAD with the PROMOTE option to load it if not.
    CASUTIL infers the file type from the source file extension.

    A CAS session must already be established by the caller, eg:

        cas mysess;
        %mv_castabload(caslib=Public, table=BASEBALL)

    or (if not a hdat source with the same name as the table):

        %mv_castabload(caslib=Public, table=BASEBALL,
                    srcfile=MYBASEBALL.parquet)

  @param [in] caslib=  CASLIB containing the source file
  @param [in] table=   Name to give the in-memory CAS table
  @param [in] srcfile= (0) Source file name.ext in the caslib.  If not provided,
                          the code assumes that srcfile=&table..sashdat
  @param [in] mdebug=  (0) Set to 1 to enable verbose logging:
                        - echoes resolved parameters
                        - prints tableExists result
                        - enables mprint/notes during PROC calls

  @returns Sets global macro variable `MV_CASTABLOAD_RC`:
    0 = table already existed (no load performed)
    1 = table was loaded & promoted successfully
    3 = action failed (including source file missing)

  <h4> SAS Macros </h4>
  @li mfv_existsashdat.sas

**/

%macro mv_castabload(
    caslib=
    ,table=
    ,srcfile=0
    ,mdebug=0
);

%global MV_CASTABLOAD_RC;
%let MV_CASTABLOAD_RC=3;

%local _sysopts;
%let _sysopts=%sysfunc(getoption(mprint)) %sysfunc(getoption(notes));

/* ---- input validation -------------------------------------------------- */
%if "&caslib"="" or "&table"="" or "&srcfile"="" %then %do;
  %put %str(ERR)OR: caslib=, table= and srcfile= are all required;
  %return;
%end;
%if "&srcfile"="0" %then %let srcfile=&table..sashdat;

%if &mdebug=1 %then %do;
  %put &=caslib;
  %put &=table;
  %put &=srcfile;
  options mprint notes;
%end;

/* ---- check source file exists ------------------------------------------ */
%if not %mfv_existsashdat(&caslib..%scan(&srcfile,1,.)) %then %do;
  %put %str(ERR)OR: Source file "&srcfile" not found in caslib "&caslib";
  %let MV_CASTABLOAD_RC=3;
  %return;
%end;

/* ---- existence check --------------------------------------------------- */
proc cas;
  table.tableExists result=r /
      caslib="&caslib"
      name="&table";
  %if &mdebug=1 %then %do;
    print r;
  %end;
  if r.exists = 0 then rc = 9;
  else rc = 0;
  symputx('MV_CASTABLOAD_RC', rc, 'G');
quit;


/* ---- load if absent ---------------------------------------------------- */
%if &MV_CASTABLOAD_RC=9 %then %do;

  proc casutil;
    load casdata="&srcfile"
        incaslib="&caslib"
        casout="&table"
        outcaslib="&caslib"
        promote;
  quit;

  %if &syserr=0 %then %let MV_CASTABLOAD_RC=1;
  %else %let MV_CASTABLOAD_RC=3;

%end;

%if &MV_CASTABLOAD_RC=0 %then
  %put NOTE: Table &caslib..&table already loaded - skipping;
%else %if &MV_CASTABLOAD_RC=1 %then
  %put NOTE: Table &caslib..&table loaded and promoted;
%else %put %str(ERR)OR: load failed for &caslib..&table;

/* ---- restore options --------------------------------------------------- */
%if &mdebug=1 %then %do;
  options &_sysopts;
%end;

%mend mv_castabload;