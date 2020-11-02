/**
  @file mp_csv2ds.sas
  @brief Efficient import of arbitrary CSV using a dataset as template
  @details Used to import relevant columns from a large CSV using
  a dataset to provide the types and lengths.  Assumes that a header
  row is provided, and datarows start on line 2.  Extra columns in
  both the CSV and base dataset are ignored.

  Usage:

      filename mycsv temp;
      data _null_;
        file mycsv;
        put 'name,age,nickname';
        put 'John,48,Jonny';
        put 'Jennifer,23,Jen';
      run;

      %mp_csv2ds(inref=mycsv,outds=myds,baseds=sashelp.class)


  @param inref= fileref to the CSV
  @param outds= output ds.  Could also be a view (eg `outds=myds/view=myds`)
  @param baseds= Template dataset on which to create the input statement.
    Is used to determine types, lengths, and any informats.

  @version 9.2
  @author Allan Bowe
**/

%macro mp_csv2ds(inref=0,outds=0,baseds=0);
%if &inref=0 %then %do;
  %put %str(ERR)OR: the INREF variable must be provided;
  %let syscc=4;
  %abort;
%end;
%if &outds=0 %then %do;
  %put %str(ERR)OR: the OUTDS variable must be provided;
  %let syscc=4;
  %return;
%end;
%if &baseds=0 %then %do;
  %put %str(ERR)OR: the BASEDS variable must be provided;
  %let syscc=4;
  %return;
%end;

/* get the variables in the CSV */
data _data_;
  infile &inref;
  input;
  length name $32;
  do i=1 to countc(_infile_,',')+1;
    name=upcase(scan(_infile_,i,','));
    output;
  end;
  stop;
run;
%local csv_vars;%let csv_vars=&syslast;

/* get the variables in the dataset */
proc contents noprint data=&baseds
  out=_data_ (keep=name type length format: informat);
run;
%local base_vars; %let base_vars=&syslast;

proc sql undo_policy=none;
create table &csv_vars as
  select a.*
    ,b.type
    ,b.length
    ,b.format
    ,b.formatd
    ,b.formatl
    ,b.informat
  from &csv_vars a
  left join &base_vars b
  on a.name=upcase(b.name)
  order by i;

/* prepare the input statement */
%local instat dropvars;
data _null_;
  set &syslast end=last;
  length in dropvars $32767;
  retain in dropvars;
  if missing(type) then do;
    informat='$1.';
    dropvars=catx(' ',dropvars,name);
  end;
  else if missing(informat) then do;
    if type=1 then informat='best.';
    else informat=cats('$',length,'.');
  end;
  in=catx(' ',in,name,':',informat);
  if last then do;
    call symputx('instat',in,'l');
    call symputx('dropvars',dropvars,'l');
  end;
run;

/* import the CSV */
data &outds;
  infile &inref dsd firstobs=2;
  input &instat;
  drop &dropvars;
run;

%mend;