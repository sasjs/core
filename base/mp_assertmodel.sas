/**
  @file
  @brief Assert dataset columns match a model and an optional key is valid
  @details Compares column names, types and lengths exactly, independent of
  column order, case, formats and labels. The model dataset can be empty.
  When key= is supplied, every component must be nonmissing and each composite
  key must be unique. A blank key= skips key validation. An empty dataset has
  no duplicate or missing keys.

  One PASS or FAIL row is appended to outds. Missing datasets and invalid key
  columns produce FAIL. The macro does not sort or intentionally modify inputs.
  Dataset names must use ordinary V7 member names, not name literals.
  Unqualified dataset names refer to WORK. OUTDS must identify a distinct
  dataset and must not alias either input through a libref, filesystem link,
  view or other storage mapping. Dataset options are not
  accepted. Direct overlaps, malformed dataset names and name literals are
  rejected with a diagnostic in the SAS log and nonzero SYSCC, without
  appending a result row. Physical aliases are not detected. Key validation
  follows the caller's observation options.

  Example:

      %mp_assertmodel(work.actual,base=work.expected,key=id region,
        desc=Checking the output model)

  @param [in] inds Input dataset to check
  @param [in] base= Reference dataset defining the expected columns
  @param [in] key= Space-separated V7 column names comprising a primary key
  @param [in] desc= (Testing dataset model) Description for the result row
  @param [out] outds= (work.test_results) Assertion results dataset

  <h4> SAS Macros </h4>
  @li mf_getuniquename.sas
  @li mp_validatecol.sas

  <h4> Related Macros </h4>
  @li mp_assert.sas
  @li mp_assertcols.sas

  @version 9.4
  @author SASjs
**/
%macro mp_assertmodel(inds,base=,key=,desc=Testing dataset model,
    outds=work.test_results);
  %local result comments tmp keylist missvars
    missingrows duplicaterows sqlstatus sqlstatus2 appendstatus
    baseds validrefs keylen;
  /* Resolve unqualified names to WORK and reject direct aliases. */
  %let validrefs=0;
  %let keylen=%length(%superq(key));
  data _null_;
    length reference inds baseds outds $32767 bn $32 keyname $32767
      comments $256 result $5 keys keylist missvars $32767;
    inds=cats(symget('inds'));
    baseds=cats(symget('base'));
    outds=cats(symget('outds'));
    if index(inds,'.')=0 then inds=cats('WORK.',inds);
    if index(baseds,'.')=0 then baseds=cats('WORK.',baseds);
    if index(outds,'.')=0 then outds=cats('WORK.',outds);
    reference=inds;
    %mp_validatecol(reference,LIBDS,valid_input)
    reference=baseds;
    %mp_validatecol(reference,LIBDS,valid_base)
    reference=outds;
    %mp_validatecol(reference,LIBDS,valid_output)
    if valid_input and valid_base and valid_output then do;
      if upcase(outds)=upcase(inds) or upcase(outds)=upcase(baseds) then
        validrefs=2;
      else do;
        validrefs=1;
        call symputx('inds',inds,'L');
        call symputx('baseds',baseds,'L');
        call symputx('outds',outds,'L');
      end;
    end;
    else validrefs=0;
    call symputx('validrefs',validrefs,'L');
    if validrefs ne 1 then stop;
    a=open(inds,'i');
    if a ne 0 then b=open(baseds,'i');
    else b=0;
    result='FAIL';
    if a=0 then comments='Input dataset cannot be opened';
    else if b=0 then comments='Model dataset cannot be opened';
    else do;
      result='PASS';
      comments='Column names types and lengths match';
      if attrn(a,'NVARS') ne attrn(b,'NVARS') then do;
        result='FAIL';
        comments='Column count differs from model';
      end;
      else do i=1 to attrn(b,'NVARS');
        bn=varname(b,i);
        pos=varnum(a,bn);
        if pos=0 then do;
          result='FAIL';
          comments=catx(' ','Missing column',bn);
        end;
        else if vartype(a,pos) ne vartype(b,i) or
            varlen(a,pos) ne varlen(b,i) then do;
          result='FAIL';
          comments=catx(' ','Type or length differs for',bn);
        end;
      end;
      if result='PASS' and &keylen>32767 then do;
        result='FAIL';
        comments='Key list too long';
      end;
      else if result='PASS' then do;
        keys=symget('key');
        do i=1 to countw(keys,' ');
          keyname=scan(keys,i,' ');
          if not nvalid(keyname,'V7') then do;
            result='FAIL';
            comments='Invalid key column name';
          end;
          else if varnum(a,keyname)=0 then do;
            result='FAIL';
            comments=catx(' ','Key column not found',keyname);
          end;
          else do;
            if lengthn(missvars)+lengthn(keyname)+11+
                4*(not missing(missvars))>32767 then do;
              result='FAIL';
              comments='Key expression too long';
              leave;
            end;
            else do;
              keylist=catx(',',keylist,cats('t.',keyname));
              missvars=catx(' or ',missvars,cats('missing(t.',keyname,')'));
            end;
          end;
        end;
      end;
    end;
    if a ne 0 then rc=close(a);
    if b ne 0 then rc=close(b);
    call symputx('result',result,'L');
    call symputx('comments',comments,'L');
    call symputx('keylist',keylist,'L');
    call symputx('missvars',missvars,'L');
  run;
  %if &validrefs ne 1 %then %do;
    %if &validrefs=2 %then
      %put %str(ERR)OR: MP_ASSERTMODEL result destination overlaps an input.;
    %else %put %str(ERR)OR: MP_ASSERTMODEL invalid dataset reference.;
    %let syscc=%sysfunc(max(&syscc,1012));
    %return;
  %end;
  %let sqlstatus=0;
  %let sqlstatus2=0;
  %let tmp=work.%mf_getuniquename(prefix=am);
  %if &result=PASS and %length(%superq(keylist))>0 %then %do;
    %let missingrows=-1;
    %let duplicaterows=-1;
    proc sql noprint;
      select count(*) into :missingrows trimmed
      from &inds as t where &missvars;
      %let sqlstatus=&sqlrc;
      select count(*) into :duplicaterows trimmed from (
        select &keylist, count(*) as n
        from &inds as t
        group by &keylist having count(*)>1
      );
      %let sqlstatus2=&sqlrc;
    quit;
    %if &sqlstatus ne 0 or &sqlstatus2 ne 0 %then %do;
      %let result=FAIL;
      %let comments=Unable to check key values;
    %end;
    %else %if &missingrows ne 0 or &duplicaterows ne 0 %then %do;
      %let result=FAIL;
      %let comments=Key contains missing or duplicate values;
    %end;
    %else %let comments=Column model and key match;
  %end;
  data &tmp;
    length test_description $256 test_result $5 test_comments $256;
    test_description=symget('desc');
    test_result=symget('result');
    test_comments=symget('comments');
  run;
  proc append base=&outds data=&tmp;
  run;
  %let appendstatus=&syserr;
  %if &appendstatus ne 0 %then
    %put %str(ERR)OR: MP_ASSERTMODEL could not append a result to &outds.;
  proc datasets lib=work nolist;
    delete %scan(&tmp,2,.);
  quit;
%mend mp_assertmodel;
