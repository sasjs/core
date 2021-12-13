/**
  @file
  @brief Export a dataset to SQL insert statements
  @details Converts dataset values to SQL insert statements for use across
  multiple database types.

  Usage:

      %mp_ds2inserts(sashelp.class,outref=myref,outds=class)
      data class;
        set sashelp.class;
        stop;
      proc sql;
      %inc myref;

  @param [in] ds The dataset to be exported
  @param [in] maxobs= (max) The max number of inserts to create
  @param [out] outref= (0) The output fileref.  If it does not exist, it is
    created. If it does exist, new records are APPENDED.
  @param [out] schema= (0) The library (or schema) in which the target table is
    located.  If not provided, is ignored.
  @param [out] outds= (0) The output table to load.  If not provided, will
    default to the table in the &ds parameter.
  @param [in] flavour= (SAS) The SQL flavour to be applied to the output. Valid
    options:
    @li SAS (default) - suitable for regular proc sql
    @li PGSQL - Used for Postgres databases
  @param [in] applydttm= (YES) If YES, any columns using datetime formats will
    be converted to native DB datetime literals

  <h4> SAS Macros </h4>
  @li mf_existfileref.sas
  @li mf_getvarcount.sas
  @li mf_getvarformat.sas
  @li mf_getvarlist.sas
  @li mf_getvartype.sas

  @version 9.2
  @author Allan Bowe (credit mjsq)
**/

%macro mp_ds2inserts(ds, outref=0,schema=0,outds=0,flavour=SAS,maxobs=max
  ,applydttm=YES
)/*/STORE SOURCE*/;

%if not %sysfunc(exist(&ds)) %then %do;
  %put %str(WAR)NING:  &ds does not exist;
  %return;
%end;

%if not %sysfunc(exist(&ds)) %then %do;
  %put %str(WAR)NING:  &ds does not exist;
  %return;
%end;

%if %index(&ds,.)=0 %then %let ds=WORK.&ds;

%let flavour=%upcase(&flavour);
%if &flavour ne SAS and &flavour ne PGSQL %then %do;
  %put %str(WAR)NING:  &flavour is not supported;
  %return;
%end;

%if &outref=0 %then %do;
  %put %str(WAR)NING:  Please provide a fileref;
  %return;
%end;
%if %mf_existfileref(&outref)=0 %then %do;
  filename &outref temp lrecl=66000;
%end;

%if &schema=0 %then %let schema=;
%else %let schema=&schema..;

%if &outds=0 %then %let outds=%scan(&ds,2,.);

%local nobs;
proc sql noprint;
select count(*) into: nobs TRIMMED from &ds;
%if &nobs=0 %then %do;
  data _null_;
    file &outref mod;
    put "/* No rows found in &ds */";
  run;
%end;

%local vars;
%let vars=%mf_getvarcount(&ds);
%if &vars=0 %then %do;
  data _null_;
    file &outref mod;
    put "/* No columns found in &schema.&ds */";
  run;
  %return;
%end;
%else %if &vars>1600 and &flavour=PGSQL %then %do;
  data _null_;
    file &fref mod;
    put "/* &schema.&ds contains &vars vars */";
    put "/* Postgres cannot handle tables with over 1600 vars */";
    put "/* No inserts will be generated for this table */";
  run;
  %return;
%end;

%local varlist varlistcomma;
%let varlist=%mf_getvarlist(&ds);
%let varlistcomma=%mf_getvarlist(&ds,dlm=%str(,),quote=double);

/* next, export data */
data _null_;
  file &outref mod ;
  if _n_=1 then put "/* &schema.&outds (&nobs rows, &vars columns) */";
  set &ds;
  %if &maxobs ne max %then %do;
    if _n_>&maxobs then stop;
  %end;
  length _____str $32767;
  call missing(_____str);
  format _numeric_ best.;
  format _character_ ;
  %local i comma var vtype vfmt;
  %do i=1 %to %sysfunc(countw(&varlist));
    %let var=%scan(&varlist,&i);
    %let vtype=%mf_getvartype(&ds,&var);
    %let vfmt=%upcase(%mf_getvarformat(&ds,&var,force=1));
    %if &i=1 %then %do;
      %if &flavour=SAS %then %do;
        put "insert into &schema.&outds set ";
        put "  &var="@;
      %end;
      %else %if &flavour=PGSQL %then %do;
        _____str=cats(
          "INSERT INTO &schema.&outds ("
          ,symget('varlistcomma')
          ,") VALUES ("
        );
        put _____str;
        put "  "@;
      %end;
    %end;
    %else %do;
      %if &flavour=SAS %then %do;
        put "  ,&var="@;
      %end;
      %else %if &flavour=PGSQL %then %do;
        put "  ,"@;
      %end;
    %end;
    %if &vtype=N %then %do;
      %if &flavour=SAS %then %do;
        put &var;
      %end;
      %else %if &flavour=PGSQL %then %do;
        if missing(&var) then put 'NULL';
        %if &applydttm=YES and "%substr(&vfmt.xxxxxxxx,1,8)"="DATETIME"
        %then %do;
          else put "TIMESTAMP '" &var E8601DT25.6 "'";
        %end;
        %else %do;
          else put &var;
        %end;
      %end;
    %end;
    %else %do;
      _____str="'"!!trim(tranwrd(&var,"'","''"))!!"'";
      put _____str;
    %end;
  %end;
  %if &flavour=SAS %then %do;
    put ';';
  %end;
  %else %if &flavour=PGSQL %then %do;
    put ');';
  %end;

  if _n_=&nobs then put /;
run;

%mend mp_ds2inserts;