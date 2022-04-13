/**
  @file
  @brief Create a CARDS file from a SAS dataset.
  @details Uses dataset attributes to convert all data into datalines.
    Running the generated file will rebuild the original dataset.  Includes
    support for large decimals, binary data, PROCESSED_DTTM columns, and
    alternative encoding.  If the input dataset is empty, the cards file will
    still be created.

    Additional support to generate a random sample and max rows.

  Usage:

      %mp_ds2cards(base_ds=sashelp.class
        , tgt_ds=work.class
        , cards_file= "C:\temp\class.sas"
        , showlog=NO
        , maxobs=5
      )

  TODO:
    - labelling the dataset
    - explicity setting a unix LF
    - constraints / indexes etc

  @param [in] base_ds= Should be two level - eg work.blah.  This is the table
                  that is converted to a cards file.
  @param [in] tgt_ds= Table that the generated cards file would create.
    Optional - if omitted, will be same as BASE_DS.
  @param [out] cards_file= ("%sysfunc(pathname(work))/cardgen.sas") Location in
    which to write the (.sas) cards file
  @param [in] maxobs= (max) To limit output to the first <code>maxobs</code>
    observations, enter an integer here.
  @param [in] random_sample= (NO) Set to YES to generate a random sample of
    data.  Can be quite slow.
  @param [in] showlog= (YES) Whether to show generated cards file in the SAS
    log.  Valid values:
    @li YES
    @li NO
  @param [in] outencoding= Provide encoding value for file statement (eg utf-8)
  @param [in] append= (NO) If NO then will rebuild the cards file if it already
    exists, otherwise will append to it.  Used by the mp_lib2cards.sas macro.

  <h4> Related Macros </h4>
  @li mp_lib2cards.sas
  @li mp_ds2inserts.sas
  @li mp_mdtablewrite.sas

  @version 9.2
  @author Allan Bowe
  @cond
**/

%macro mp_ds2cards(base_ds=, tgt_ds=
    ,cards_file="%sysfunc(pathname(work))/cardgen.sas"
    ,maxobs=max
    ,random_sample=NO
    ,showlog=YES
    ,outencoding=
    ,append=NO
)/*/STORE SOURCE*/;
%local i setds nvars;

%if not %sysfunc(exist(&base_ds)) %then %do;
  %put %str(WARN)ING:  &base_ds does not exist;
  %return;
%end;

%if %index(&base_ds,.)=0 %then %let base_ds=WORK.&base_ds;
%if (&tgt_ds = ) %then %let tgt_ds=&base_ds;
%if %index(&tgt_ds,.)=0 %then %let tgt_ds=WORK.%scan(&base_ds,2,.);
%if ("&outencoding" ne "") %then %let outencoding=encoding="&outencoding";
%if ("&append" = "" or "&append" = "NO") %then %let append=;
%else %let append=mod;

/* get varcount */
%let nvars=0;
proc sql noprint;
select count(*) into: nvars from dictionary.columns
  where upcase(libname)="%scan(%upcase(&base_ds),1)"
    and upcase(memname)="%scan(%upcase(&base_ds),2)";
%if &nvars=0 %then %do;
  %put %str(WARN)ING: Dataset &base_ds has no variables, will not be converted.;
  %return;
%end;

/* get indexes */
proc sort
  data=sashelp.vindex(
    where=(upcase(libname)="%scan(%upcase(&base_ds),1)"
      and upcase(memname)="%scan(%upcase(&base_ds),2)")
    )
  out=_data_;
  by indxname indxpos;
run;

%local indexes;
data _null_;
  set &syslast end=last;
  if _n_=1 then call symputx('indexes','(index=(','l');
  by indxname indxpos;
  length vars $32767 nom uni $8;
  retain vars;
  if first.indxname then do;
    idxcnt+1;
    nom='';
    uni='';
    vars=name;
  end;
  else vars=catx(' ',vars,name);
  if last.indxname then do;
    if nomiss='yes' then nom='/nomiss';
    if unique='yes' then uni='/unique';
    call symputx('indexes'
      ,catx(' ',symget('indexes'),indxname,'=(',vars,')',nom,uni)
      ,'l');
  end;
  if last then call symputx('indexes',cats(symget('indexes'),'))'),'l');
run;


data;run;
%let setds=&syslast;
proc sql
%if %datatyp(&maxobs)=NUMERIC %then %do;
  outobs=&maxobs;
%end;
  ;
  create table &setds as select * from &base_ds
%if &random_sample=YES %then %do;
  order by ranuni(42)
%end;
  ;
reset outobs=max;
create table datalines1 as
  select name,type,length,varnum,format,label from dictionary.columns
  where upcase(libname)="%upcase(%scan(&base_ds,1))"
    and upcase(memname)="%upcase(%scan(&base_ds,2))";

/**
  Due to long decimals cannot use best. format
  So - use bestd. format and then use character functions to strip trailing
    zeros, if NOT an integer or missing!!  Cannot use int() as it upsets
    note2err when there are missings.
  resolved code = ifc( mod(coalesce(VARIABLE,0),1)=0
    ,put(VARIABLE,best32.)
    ,substrn(put(VARIABLE,bestd32.),1
    ,findc(put(VARIABLE,bestd32.),'0','TBK')));
**/

data datalines_2;
  format dataline $32000.;
  set datalines1 (where=(upcase(name) not in
    ('PROCESSED_DTTM','VALID_FROM_DTTM','VALID_TO_DTTM')));
  if type='num' then dataline=
    cats('ifc(mod(coalesce(',name,',0),1)=0
      ,put(',name,',best32.-l)
      ,substrn(put(',name,',bestd32.-l),1
      ,findc(put(',name,',bestd32.-l),"0","TBK")))');
  /**
    * binary data must be converted, to store in text format.  It is identified
    * by the presence of the $HEX keyword in the format.
    */
  else if upcase(format)=:'$HEX' then
    dataline=cats('put(trim(',name,'),',format,')');
  /**
    * There is no easy way to store line breaks in a cards file.
    * To discuss this, use: https://github.com/sasjs/core/issues/80
    * Removing all nonprintables with kw (keep writeable)
    */
  else dataline=cats('compress(',name,', ,"kw")');
run;

proc sql noprint;
select dataline into: datalines separated by ',' from datalines_2;

%local
  process_dttm_flg
  valid_from_dttm_flg
  valid_to_dttm_flg
;
%let process_dttm_flg = N;
%let valid_from_dttm_flg = N;
%let valid_to_dttm_flg = N;
data _null_;
  set datalines1 ;
/* build attrib statement */
  if type='char' then type2='$';
  if strip(format) ne '' then format2=cats('format=',format);
  if strip(label) ne '' then label2=cats('label=',quote(trim(label)));
  str1=catx(' ',(put(name,$33.)||'length=')
        ,put(cats(type2,length),$7.)||format2,label2);


/* Build input statement */
  if upcase(format)=:'$HEX' then type3=':'!!format;
  else if type='char' then type3=':$char.';
  str2=put(name,$33.)||type3;


  if(upcase(name) = "PROCESSED_DTTM") then
    call symputx("process_dttm_flg", "Y", "L");
  if(upcase(name) = "VALID_FROM_DTTM") then
    call symputx("valid_from_dttm_flg", "Y", "L");
  if(upcase(name) = "VALID_TO_DTTM") then
    call symputx("valid_to_dttm_flg", "Y", "L");


  call symputx(cats("attrib_stmt_", put(_N_, 8.)), str1, "L");
  call symputx(cats("input_stmt_", put(_N_, 8.))
    , ifc(upcase(name) not in
      ('PROCESSED_DTTM','VALID_FROM_DTTM','VALID_TO_DTTM'), str2, ""), "L");
run;

data _null_;
  file &cards_file. &outencoding lrecl=32767 termstr=nl &append;
  length __attrib $32767;
  if _n_=1 then do;
    put '/**';
    put '  @file';
    put "  @brief Datalines for %upcase(%scan(&base_ds,2)) dataset";
    put "  @details Generated by %nrstr(%%)mp_ds2cards()";
    put "    Source: https://github.com/sasjs/core";
    put '  @cond ';
    put '**/';
    put "data &tgt_ds &indexes;";
    put "attrib ";
    %do i = 1 %to &nvars;
      __attrib=symget("attrib_stmt_&i");
      put __attrib;
    %end;
    put ";";

    %if &process_dttm_flg. eq Y %then %do;
      put 'retain PROCESSED_DTTM %sysfunc(datetime());';
    %end;
    %if &valid_from_dttm_flg. eq Y %then %do;
      put 'retain VALID_FROM_DTTM &low_date;';
    %end;
    %if &valid_to_dttm_flg. eq Y %then %do;
      put 'retain VALID_TO_DTTM &high_date;';
    %end;
    if __nobs=0 then do;
      put 'call missing(of _all_);/* avoid uninitialised notes */';
      put 'stop;';
      put 'run;';
    end;
    else do;
      put "infile cards dsd;";
      put "input ";
      %do i = 1 %to &nvars.;
        %if(%length(&&input_stmt_&i..)) %then
          put "  &&input_stmt_&i..";
        ;
      %end;
      put ";";
      put "datalines4;";
    end;
  end;
  set &setds end=__lastobs nobs=__nobs;
/* remove all formats for write purposes - some have long underlying decimals */
  format _numeric_ best30.29;
  length __dataline $32767;
  __dataline=catq('cqtmb',&datalines);
  put __dataline;
  if __lastobs then do;
    put ';;;;';
    put 'run;';
    put '/** @endcond **/';
    stop;
  end;
run;
proc sql;
  drop table &setds;
quit;

%if &showlog=YES %then %do;
  data _null_;
    infile &cards_file lrecl=32767;
    input;
    put _infile_;
  run;
%end;

%put NOTE: CARDS FILE SAVED IN:;
%put NOTE-;%put NOTE-;
%put NOTE- %sysfunc(dequote(&cards_file.));
%put NOTE-;%put NOTE-;
%mend mp_ds2cards;
/** @endcond **/
