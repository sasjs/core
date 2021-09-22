/**
  @file
  @brief Create a Markdown Table from a dataset
  @details A markdown table is a simple table representation for use in
  documents written in markdown format.

  An online generator is available here:
  https://www.tablesgenerator.com/markdown_tables

  This structure is also used by the Macro Core library for documenting input/
  output datasets, as well as the sasjs/cli tool for documenting inputs/outputs
  for web services.

  We take the standard definition one step further by embedding the informat
  in the table header row, like so:

      |var1:$32|var2:best.|var3:date9.|
      |---|---|---|
      |some text|42|01JAN1960|
      |blah|1|31DEC1999|

  Which resolves to:

  |var1:$32|var2:best.|var3:date9.|
  |---|---|---|
  |some text|42|01JAN1960|
  |blah|1|31DEC1999|


  Usage:

      %mp_mdtablewrite(libds=sashelp.class,showlog=YES)


  <h4> SAS Macros </h4>
  @li mf_getvarlist.sas
  @li mf_getvarformat.sas

  @param [in] libds= the library / dataset to create or read from.
  @param [out] fref= Fileref to contain the markdown. Default=mdtable.
  @param [out] showlog= set to YES to show the markdown in the log. Default=NO.

  @version 9.3
  @author Allan Bowe
**/

%macro mp_mdtablewrite(
  libds=,
  fref=mdtable,
  showlog=NO
)/*/STORE SOURCE*/;

/* check fileref is assigned */
%if %sysfunc(fileref(&fref)) > 0 %then %do;
  filename &fref temp;
%end;

%local vars;
%let vars=%mf_getvarlist(&libds);

/* create the header row */
data _null_;
  file &fref;
  length line $32767;
  put '|'
%local i var fmt;
%do i=1 %to %sysfunc(countw(&vars));
  %let var=%scan(&vars,&i);
  %let fmt=%mf_getvarformat(&libds,&var,force=1);
  "&var:&fmt|"
%end;
  ;
  put '|'
%do i=1 %to %sysfunc(countw(&vars));
  "---|"
%end;
  ;
run;

/* write out the data */
data _null_;
  file &fref mod dlm='|' lrecl=32767;
  set &libds ;
  length line $32767;
  line=cats('|',%mf_getvarlist(&libds,dlm=%str(,'|',)),'|');
  put line;
run;

%if %upcase(&showlog)=YES %then %do;
  options ps=max;
  data _null_;
    infile &fref;
    input;
    putlog _infile_;
  run;
%end;

%mend mp_mdtablewrite;