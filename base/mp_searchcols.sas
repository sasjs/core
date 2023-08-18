/**
  @file mp_searchcols.sas
  @brief Searches all columns in a library
  @details
  Scans a set of libraries and creates a dataset containing all source tables
    containing one or more of a particular set of columns

  Usage:

      %mp_searchcols(libs=sashelp work, cols=name sex age)

  @param libs= (SASHELP) Space separated list of libraries to search for columns
  @param cols= Space separated list of column names to search for (not case
    sensitive)
  @param outds= (mp_searchcols) the table to create with the results.  Will have
    one line per table match.
  @param match= (ANY) The match type. Valid values:
    @li ANY - The table contains at least one of the columns
    @li WILD - The table contains a column with a name that partially matches

  @version 9.2
  @author Allan Bowe
**/

%macro mp_searchcols(libs=sashelp
  ,cols=
  ,outds=mp_searchcols
  ,match=ANY
)/*/STORE SOURCE*/;

%put &sysmacroname process began at %sysfunc(datetime(),datetime19.);

/* get the list of tables in the library */
proc sql;
create table _data_ as
  select distinct upcase(libname) as libname
    , upcase(memname) as memname
    , upcase(name) as name
  from dictionary.columns
%if %sysevalf(%superq(libs)=,boolean)=0 %then %do;
  where upcase(libname) in ("IMPOSSIBLE",
  %local x;
  %do x=1 %to %sysfunc(countw(&libs));
    "%upcase(%scan(&libs,&x))"
  %end;
  )
%end;
  order by 1,2,3;

%local tempds;
%let tempds=&syslast;
data &outds;
  set &tempds;
  length cols matchcols $32767;
  cols=upcase(symget('cols'));
  colcount=countw(cols);
  by libname memname name;
  if _n_=1 then do;
    putlog "Searching libs: &libs";
    putlog "Searching cols: " cols;
  end;
  if first.memname then do;
    sumcols=0;
    retain matchcols;
    matchcols='';
  end;
%if &match=ANY %then %do;
  if findw(cols,name,,'spit') then do;
    sumcols+1;
    matchcols=cats(matchcols)!!' '!!cats(name);
  end;
%end;
%else %if &match=WILD %then %do;
  if _n_=1 then do;
    retain wcount;
    wcount=countw(cols);
    drop wcount;
  end;
  do i=1 to wcount;
    length curword $32;
    curword=scan(cols,i,' ');
    drop curword;
    if index(name,cats(curword)) then do;
      sumcols+1;
      matchcols=cats(matchcols)!!' '!!cats(curword);
    end;
  end;
%end;

  if last.memname then do;
    if sumcols>0 then output;
    if sumcols=colcount then putlog "Full Match: " libname memname;
  end;
  keep libname memname sumcols matchcols;
run;

proc sort; by descending sumcols memname libname; run;

proc sql;
drop table &tempds;
%put &sysmacroname process finished at %sysfunc(datetime(),datetime19.);

%mend mp_searchcols;