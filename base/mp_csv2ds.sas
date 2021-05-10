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
  @param outds= output ds (lib.ds format)
  @param view= Set to YES or NO to determine whether the output should be
    a view or not.  Default is NO (not a view).
  @param baseds= Template dataset on which to create the input statement.
    Is used to determine types, lengths, and any informats.

  @version 9.2
  @author Allan Bowe

  <h4> SAS Macros </h4>
  @li mp_abort.sas
  @li mf_existds.sas

**/

%macro mp_csv2ds(inref=0,outds=0,baseds=0,view=NO);

%mp_abort(iftrue=( &inref=0 )
  ,mac=&sysmacroname
  ,msg=%str(the INREF variable must be provided)
)
%mp_abort(iftrue=( %superq(outds)=0 )
  ,mac=&sysmacroname
  ,msg=%str(the OUTDS variable must be provided)
)
%mp_abort(iftrue=( &baseds=0 )
  ,mac=&sysmacroname
  ,msg=%str(the BASEDS variable must be provided)
)
%mp_abort(iftrue=( &baseds=0 )
  ,mac=&sysmacroname
  ,msg=%str(the BASEDS variable must be provided)
)
%mp_abort(iftrue=( %mf_existds(&baseds)=0 )
  ,mac=&sysmacroname
  ,msg=%str(the BASEDS dataset (&baseds) needs to be assigned, and to exist)
)

/* count rows */
%local hasheader; %let hasheader=0;
data _null_;
  if _N_ > 1 then do;
    call symputx('hasheader',1,'l');
    stop;
  end;
  infile &inref;
  input;
run;
%mp_abort(iftrue=( &hasheader=0 )
  ,mac=&sysmacroname
  ,msg=%str(No header row in &inref)
)

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
  else informat=cats(informat,'.');
  in=catx(' ',in,name,':',informat);
  if last then do;
    call symputx('instat',in,'l');
    call symputx('dropvars',dropvars,'l');
  end;
run;

/* import the CSV */
data &outds
  %if %upcase(&view)=YES %then %do;
    /view=&outds
  %end;
  ;
  infile &inref dsd firstobs=2;
  input &instat;
  %if %length(&dropvars)>0 %then %do;
    drop &dropvars;
  %end;
run;

%mend;