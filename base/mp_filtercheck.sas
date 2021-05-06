/**
  @file
  @brief Checks an input filter table for validity
  @details Performs checks on the input table to ensure it arrives in the
  correct format.  This is necessary to prevent code injection.  Will update
  SYSCC to 1008 if bad records are found, and call mp_abort.sas for a
  graceful service exit (configurable).

  Used for dynamic filtering in [Data Controller for SAS&reg;](https://datacontroller.io).

  Usage:

      %mp_filtercheck(work.filter,targetds=sashelp.class,outds=work.badrecords)

  The input table should have the following format:

  |GROUP_LOGIC:$3|SUBGROUP_LOGIC:$3|SUBGROUP_ID:8.|VARIABLE_NM:$32|OPERATOR_NM:$10|RAW_VALUE:$4000|
  |---|---|---|---|---|---|
  |AND|AND|1|AGE|=|12|
  |AND|AND|1|SEX|<=|'M'|
  |AND|OR|2|Name|NOT IN|('Jane','Alfred')|
  |AND|OR|2|Weight|>=|7|

  Rules applied:

  @li GROUP_LOGIC - only AND/OR
  @li SUBGROUP_LOGIC - only AND/OR
  @li SUBGROUP_ID - only integers
  @li VARIABLE_NM - must be in the target table
  @li OPERATOR_NM - only =/>/</<=/>=/BETWEEN/IN/NOT IN/NE/CONTAINS
  @li RAW_VALUE - no unquoted values except integers, commas and spaces.

  @returns The &outds table containing any bad rows, plus a REASON_CD column.

  @param [in] inds The table to be checked, with the format above
  @param [in] targetds= The target dataset against which to verify VARIABLE_NM
  @param [out] abort= (YES) If YES will call mp_abort.sas on any exceptions
  @param [out] outds= The output table, which is a copy of the &inds. table
  plus a REASON_CD column, containing only bad records.  If bad records found,
  the SYSCC value will be set to 1008 (general data problem).  Downstream
  processes should check this table (and return code) before continuing.

  <h4> SAS Macros </h4>
  @li mp_abort.sas
  @li mf_getuniquefileref.sas
  @li mf_getvarlist.sas
  @li mf_getvartype.sas
  @li mf_nobs.sas
  @li mp_filtergenerate.sas
  @li mp_filtervalidate.sas

  <h4> Related Macros </h4>
  @li mp_filtergenerate.sas
  @li mp_filtervalidate.sas

  @version 9.3
  @author Allan Bowe

  @todo Support date / hex / name literals and exponents in RAW_VALUE field
**/

%macro mp_filtercheck(inds,targetds=,outds=work.badrecords,abort=YES);

%mp_abort(iftrue= (&syscc ne 0)
  ,mac=&sysmacroname
  ,msg=%str(syscc=&syscc - on macro entry)
)

/* Validate input column */
%local vtype;
%let vtype=%mf_getvartype(&inds,RAW_VALUE);
%mp_abort(iftrue=(&abort=YES and &vtype ne C),
  mac=&sysmacroname,
  msg=%str(%str(ERR)OR: RAW_VALUE must be character)
)
%if &vtype ne C %then %do;
  %put &sysmacroname: RAW_VALUE must be character;
  %let syscc=42;
  %return;
%end;


/**
  * Sanitise the values based on valid value lists, then strip out
  * quotes, commas, periods and spaces.
  * Only numeric values should remain
  */
%local reason_cd;
data &outds;
  /*length GROUP_LOGIC SUBGROUP_LOGIC $3 SUBGROUP_ID 8 VARIABLE_NM $32
    OPERATOR_NM $10 RAW_VALUE $4000;*/
  set &inds;
  length reason_cd $32;

  /* closed list checks */
  if GROUP_LOGIC not in ('AND','OR') then do;
    REASON_CD='GROUP_LOGIC should be either AND or OR';
    putlog REASON_CD= GROUP_LOGIC=;
    output;
  end;
  if SUBGROUP_LOGIC not in ('AND','OR') then do;
    REASON_CD='SUBGROUP_LOGIC should be either AND or OR';
    putlog REASON_CD= SUBGROUP_LOGIC=;
    output;
  end;
  if mod(SUBGROUP_ID,1) ne 0 then do;
    REASON_CD='SUBGROUP_ID should be integer';
    putlog REASON_CD= SUBGROUP_ID=;
    output;
  end;
  if upcase(VARIABLE_NM) not in
  (%upcase(%mf_getvarlist(&targetds,dlm=%str(,),quote=SINGLE)))
  then do;
    REASON_CD="VARIABLE_NM not in &targetds";
    putlog REASON_CD= VARIABLE_NM=;
    output;
  end;
  if OPERATOR_NM not in
  ('=','>','<','<=','>=','BETWEEN','IN','NOT IN','NE','CONTAINS')
  then do;
    REASON_CD='Invalid OPERATOR_NM';
    putlog REASON_CD= OPERATOR_NM=;
    output;
  end;

  /* special logic */
  if OPERATOR_NM='BETWEEN' then raw_value1=tranwrd(raw_value,' AND ','');
  else if OPERATOR_NM in ('IN','NOT IN') then do;
    if substr(raw_value,1,1) ne '('
    or substr(cats(reverse(raw_value)),1,1) ne ')'
    then do;
      REASON_CD='Missing brackets in RAW_VALUE';
      putlog REASON_CD= OPERATOR_NM= raw_value= raw_value1= ;
      output;
    end;
    else raw_value1=substr(raw_value,2,max(length(raw_value)-2,0));
  end;
  else raw_value1=raw_value;

  /* remove nested literals eg '' */
  raw_value1=tranwrd(raw_value1,"''",'');

  /* now match string literals (always single quotes) */
  raw_value2=raw_value1;
  regex = prxparse("s/(\').*?(\')//");
  call prxchange(regex,-1,raw_value2);

  /* remove commas and periods*/
  raw_value3=compress(raw_value2,',.');

  /* output records that contain values other than digits and spaces */
  if notdigit(compress(raw_value3,' '))>0 then do;
    putlog raw_value3= $hex32.;
    REASON_CD='Invalid RAW_VALUE';
    putlog REASON_CD= raw_value= raw_value1= raw_value2= raw_value3=;
    output;
  end;

run;

data _null_;
  set &outds;
  call symputx('REASON_CD',reason_cd,'l');
  stop;
run;

%mp_abort(iftrue=(&abort=YES and %mf_nobs(&outds)>0),
  mac=&sysmacroname,
  msg=%str(Filter issues in &inds, reason: &reason_cd, details in &outds)
)

%if %mf_nobs(&outds)>0 %then %do;
  %let syscc=1008;
  %return;
%end;

/**
  * syntax checking passed but it does not mean the filter is valid
  * for that we can run a proc sql validate query
  */
%local fref1;
%let fref1=%mf_getuniquefileref();
%mp_filtergenerate(&inds,outref=&fref1)

/* this macro will also set syscc to 1008 if any issues found */
%mp_filtervalidate(&fref1,&targetds,outds=&outds,abort=&abort)

%mend mp_filtercheck;
