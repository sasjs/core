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

      %mp_ds2md(sashelp.class)

  @param [in] libds the library / dataset to create or read from.
  @param [out] outref= (mdtable) Fileref to contain the markdown
  @param [out] showlog= (YES) Set to NO to avoid printing markdown to the log

  <h4> SAS Macros </h4>
  @li mf_getvarlist.sas
  @li mf_getvarformat.sas

  @version 9.3
  @author Allan Bowe
**/

%macro mp_ds2md(
  libds,
  outref=mdtable,
  showlog=YES
)/*/STORE SOURCE*/;

/* check fileref is assigned */
%if %sysfunc(fileref(&outref)) > 0 %then %do;
  filename &outref temp;
%end;

%local vars;
%let vars=%upcase(%mf_getvarlist(&libds));

%if %trim(X&vars)=X %then %do;
  %put &sysmacroname: Table &libds has no columns!!;
  %return;
%end;

/* create the header row */
data _null_;
  file &outref;
  length line $32767;
  call missing(line);
  put '|'
%local i var fmt;
%do i=1 %to %sysfunc(countw(&vars));
  %let var=%scan(&vars,&i);
  %let fmt=%lowcase(%mf_getvarformat(&libds,&var,force=1));
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
  file &outref mod dlm='|' lrecl=32767;
  set &libds ;
  length line $32767;
  line='|`'!!cats(%mf_getvarlist(&libds,dlm=%str(%)!!' `|`'!!cats%()))!!' `|';
  put line;
run;

%if %upcase(&showlog)=YES %then %do;
  options ps=max;
  data _null_;
    infile &outref;
    input;
    putlog _infile_;
  run;
%end;

%mend mp_ds2md;