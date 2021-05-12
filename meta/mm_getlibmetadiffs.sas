/**
  @file
  @brief Compares the metadata of a library with the physical tables
  @details Creates a series of output tables that show the differences between
  metadata and physical tables.
  Each output can be created with an optional prefix.

  Credit - Paul Homes
  https://platformadmin.com/blogs/paul/2012/11/sas-proc-metalib-ods-output

  Usage:

      %* create (and assign) a library for testing purposes ;
      %mm_createlibrary(
        libname=My Temp Library,
        libref=XXTEMPXX,
        tree=/User Folders/&sysuserid,
        directory=%sysfunc(pathname(work))
      )

      %* create some tables;
      data work.table1 table2 table3;
        a=1;b='two';c=3;
      run;

      %* register the tables;
      proc metalib;
        omr=(library="My Temp Library");
        report(type=detail);
        update_rule (delete);
      run;

      %* modify the tables;
      proc sql;
      drop table table3;
      alter table table2 drop c;
      alter table table2 add d num;

      %* run the macro;
      %mm_getlibmetadiffs(libname=My Temp Library)

      %* delete the library ;
      %mm_deletelibrary(name=My Temp Library)

  The program will create four output tables, with the following structure (and
  example data):

  #### &prefix.added
  |name:$32.|metaID:$17.|SAStabName:$32.|
  |---|---|---|
  | | |DATA1|

  #### &prefix.deleted
  |name:$32.|metaID:$17.|SAStabName:$32.|
  |---|---|---|
  |TABLE3|A5XLSNXI.BK0001HO|TABLE3|

  #### &prefix.updated
  |tabName:$32.|tabMetaID:$17.|SAStabName:$32.|metaName:$32.|metaID:$17.|sasname:$32.|metaType:$16.|change:$64.|
  |---|---|---|---|---|---|---|---|
  |TABLE2|A5XLSNXI.BK0001HN|TABLE2|c|A5XLSNXI.BM000MA9|c|Column|Deleted|
  | | | |d| |d|Column|Added|

  #### &prefix.meta
  |Label1:$28.|cValue1:$1.|nValue1:D12.3|
  |---|---|---|
  |Total tables analyzed|4|4|
  |Tables to be Updated|1|1|
  |Tables to be Deleted|1|1|
  |Tables to be Added|1|1|
  |Tables matching data source|1|1|
  |Tables not processed|0|0|

  If you are interested in more functionality like this (checking the health of
  SAS metadata and your SAS 9 environment) then do contact [Allan Bowe](
  https://www.linkedin.com/in/allanbowe) for details of our SAS 9 Health Check
  service.

  Our system scan will perform hundreds of checks to identify common issues,
  such as dangling metadata, embedded passwords, security issues and more.

  @param [in] libname= the metadata name of the library to be compared
  @param [out] outlib=(work) The library in which to store the output tables.
  @param [out] prefix=(metadiff) The prefix for the four tables created.

  @version 9.3
  @author Allan Bowe

**/

%macro mm_getlibmetadiffs(
  libname= ,
  prefix=metadiff,
  outlib=work
)/*/STORE SOURCE*/;

  /* create tempds */
  data;run;
  %local tempds;
  %let tempds=&syslast;

  /* save options */
  proc optsave out=&tempds;
  run;

  options VALIDVARNAME=ANY VALIDMEMNAME=EXTEND;

  ods output
    factoid1=&outlib..&prefix.meta
    updtab=&outlib..&prefix.updated
    addtab=&outlib..&prefix.added
    deltab=&outlib..&prefix.deleted
  ;

  proc metalib;
    omr=(library="&libname");
    noexec;
    report(type=detail);
    update_rule (delete);
  run;

  ods output close;

  /* restore options */
  proc optload data=&tempds;
  run;

%mend mm_getlibmetadiffs;
