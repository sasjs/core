/**
  @file
  @brief Checks an input filter table for validity
  @details Performs checks on the input table to ensure it arrives in the
  correct format.  This is necessary to prevent code injection.  Will update
  SYSCC to 1008 if bad records are found, and call mp_abort.sas for a
  graceful service exit (configurable).

  Used for dynamic filtering in [Data Controller for SAS&reg;](
  https://datacontroller.io).

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
  @param [in] targetds= The target dataset against which to verify VARIABLE_NM.
    This must be available (ie, the library must be assigned).
  @param [out] abort= (YES) If YES will call mp_abort.sas on any exceptions
  @param [out] outds= (work.badrecords) The output table, which is a copy of the
    &inds. table plus a REASON_CD column, containing only bad records.
    If bad records are found, the SYSCC value will be set to 1008
    (a general data problem).
    Downstream processes should check this table (and return code) before
    continuing.

  <h4> SAS Macros </h4>
  @li mp_abort.sas
  @li mf_getuniquefileref.sas
  @li mf_getvarlist.sas
  @li mf_getvartype.sas
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
  */
%local reason_cd nobs;
%let nobs=0;
data &outds;
  /*length GROUP_LOGIC SUBGROUP_LOGIC $3 SUBGROUP_ID 8 VARIABLE_NM $32
    OPERATOR_NM $10 RAW_VALUE $4000;*/
  set &inds end=last;
  length reason_cd $4032 vtype vtype2 $1 vnum dsid 8 tmp $4000;
  drop tmp;

  /* quick check to ensure column exists */
  if upcase(VARIABLE_NM) not in
  (%upcase(%mf_getvarlist(&targetds,dlm=%str(,),quote=SINGLE)))
  then do;
    REASON_CD="Variable "!!cats(variable_nm)!!" not in &targetds";
    putlog REASON_CD= VARIABLE_NM=;
    call symputx('reason_cd',reason_cd,'l');
    call symputx('nobs',_n_,'l');
    output;
    return;
  end;

  /* need to open the dataset to get the column type */
  retain dsid;
  if _n_=1 then dsid=open("&targetds","i");
  if dsid>0 then do;
    vnum=varnum(dsid,VARIABLE_NM);
    if vnum<1 then do;
      /* should not happen as was also tested for above */
      REASON_CD=cats("Variable (",VARIABLE_NM,") not found in &targetds");
      putlog REASON_CD= dsid=;
      call symputx('reason_cd',reason_cd,'l');
      call symputx('nobs',_n_,'l');
      output;
      goto endstep;
    end;
    /* now we can get the type */
    else vtype=vartype(dsid,vnum);
  end;
  else do;
      REASON_CD=cats("Could not open &targetds");
      putlog REASON_CD= dsid=;
      call symputx('reason_cd',reason_cd,'l');
      call symputx('nobs',_n_,'l');
      output;
      stop;
  end;

  /* closed list checks */
  if GROUP_LOGIC not in ('AND','OR') then do;
    REASON_CD='GROUP_LOGIC should be AND/OR, not:'!!cats(GROUP_LOGIC);
    putlog REASON_CD= GROUP_LOGIC=;
    call symputx('reason_cd',reason_cd,'l');
    call symputx('nobs',_n_,'l');
    output;
  end;
  if SUBGROUP_LOGIC not in ('AND','OR') then do;
    REASON_CD='SUBGROUP_LOGIC should be AND/OR, not:'!!cats(SUBGROUP_LOGIC);
    putlog REASON_CD= SUBGROUP_LOGIC=;
    call symputx('reason_cd',reason_cd,'l');
    call symputx('nobs',_n_,'l');
    output;
  end;
  if mod(SUBGROUP_ID,1) ne 0 then do;
    REASON_CD='SUBGROUP_ID should be integer, not '!!cats(subgroup_id);
    putlog REASON_CD= SUBGROUP_ID=;
    call symputx('reason_cd',reason_cd,'l');
    call symputx('nobs',_n_,'l');
    output;
  end;
  if OPERATOR_NM not in
  ('=','>','<','<=','>=','NE','GE','LE','BETWEEN','IN','NOT IN','CONTAINS')
  then do;
    REASON_CD='Invalid OPERATOR_NM: '!!cats(OPERATOR_NM);
    putlog REASON_CD= OPERATOR_NM=;
    call symputx('reason_cd',reason_cd,'l');
    call symputx('nobs',_n_,'l');
    output;
  end;

  /* special missing logic */
  if vtype='N' & OPERATOR_NM in ('=','>','<','<=','>=','NE','GE','LE') then do;
    if cats(upcase(raw_value)) in (
      '.','.A','.B','.C','.D','.E','.F','.G','.H','.I','.J','.K','.L','.M','.N'
      '.N','.O','.P','.Q','.R','.S','.T','.U','.V','.W','.X','.Y','.Z','._'
    )
    then do;
      /* valid numeric - exit data step loop */
      return;
    end;
    else if subpad(upcase(raw_value),1,1) in (
      'A','B','C','D','E','F','G','H','I','J','K','L','M','N'
      'N','O','P','Q','R','S','T','U','V','W','X','Y','Z','_'
    )
    then do;
      /* check if the raw_value contains a valid variable NAME */
      vnum=varnum(dsid,subpad(raw_value,1,32));
      if vnum>0 then do;
        /* now we can get the type */
        vtype2=vartype(dsid,vnum);
        /* check type matches */
        if vtype2=vtype then do;
          /* valid target var - exit loop */
          return;
        end;
        else do;
          REASON_CD=cats("Compared Type (",vtype2,") is not (",vtype,")");
          putlog REASON_CD= dsid=;
          call symputx('reason_cd',reason_cd,'l');
          call symputx('nobs',_n_,'l');
          output;
          goto endstep;
        end;
      end;
    end;
  end;

  /* special logic */
  if OPERATOR_NM in ('IN','NOT IN','BETWEEN') then do;
    if OPERATOR_NM='BETWEEN' then raw_value1=tranwrd(raw_value,' AND ',',');
    else do;
      if substr(raw_value,1,1) ne '('
      or substr(cats(reverse(raw_value)),1,1) ne ')'
      then do;
        REASON_CD='Missing start/end bracket in RAW_VALUE';
        putlog REASON_CD= OPERATOR_NM= raw_value= raw_value1= ;
        call symputx('reason_cd',reason_cd,'l');
        call symputx('nobs',_n_,'l');
        output;
      end;
      else raw_value1=substr(raw_value,2,max(length(raw_value)-2,0));
    end;
    /* we now have a comma seperated list of values */
    if vtype='N' then do i=1 to countc(raw_value1, ',')+1;
      tmp=scan(raw_value1,i,',');
      if cats(tmp) ne '.' and input(tmp, ?? 8.) eq . then do;
        if OPERATOR_NM ='BETWEEN' and subpad(upcase(tmp),1,1) in (
          'A','B','C','D','E','F','G','H','I','J','K','L','M','N'
          'N','O','P','Q','R','S','T','U','V','W','X','Y','Z','_'
        )
        then do;
          /* check if the raw_value contains a valid variable NAME */
          /* is not valid syntax for IN or NOT IN */
          vnum=varnum(dsid,subpad(tmp,1,32));
          if vnum>0 then do;
            /* now we can get the type */
            vtype2=vartype(dsid,vnum);
            /* check type matches */
            if vtype2=vtype then do;
              /* valid target var - exit loop */
              return;
            end;
            else do;
              REASON_CD=cats("Compared Type (",vtype2,") is not (",vtype,")");
              putlog REASON_CD= dsid=;
              call symputx('reason_cd',reason_cd,'l');
              call symputx('nobs',_n_,'l');
              output;
              goto endstep;
            end;
          end;
        end;
        REASON_CD='Non Numeric value provided';
        putlog REASON_CD= OPERATOR_NM= raw_value= raw_value1= ;
        call symputx('reason_cd',reason_cd,'l');
        call symputx('nobs',_n_,'l');
        output;
      end;
      return;
    end;
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
    if vtype='C' and subpad(upcase(raw_value),1,1) in (
      'A','B','C','D','E','F','G','H','I','J','K','L','M','N'
      'N','O','P','Q','R','S','T','U','V','W','X','Y','Z','_'
    )
    then do;
      /* check if the raw_value contains a valid variable NAME */
      vnum=varnum(dsid,subpad(raw_value,1,32));
      if vnum>0 then do;
        /* now we can get the type */
        vtype2=vartype(dsid,vnum);
        /* check type matches */
        if vtype2=vtype then do;
          /* valid target var - exit loop */
          return;
        end;
        else do;
          REASON_CD=cats("Compared Char Type (",vtype2,") is not (",vtype,")");
          putlog REASON_CD= dsid=;
          call symputx('reason_cd',reason_cd,'l');
          call symputx('nobs',_n_,'l');
          output;
          goto endstep;
        end;
      end;
    end;

    putlog raw_value3= $hex32.;
    REASON_CD=cats('Invalid RAW_VALUE:',raw_value);
    putlog (_all_)(=);
    call symputx('reason_cd',reason_cd,'l');
    call symputx('nobs',_n_,'l');
    output;
  end;

  endstep:
  if last then rc=close(dsid);
run;


data _null_;
  set &outds end=last;
  putlog (_all_)(=);
run;

%mp_abort(iftrue=(&abort=YES and &nobs>0),
  mac=&sysmacroname,
  msg=%str(Data issue: %superq(reason_cd))
)

%if &nobs>0 %then %do;
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
