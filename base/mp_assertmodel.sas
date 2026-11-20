/**
  @file
  @brief Assert dataset columns match a model and an optional key is valid
  @details Compares column names, types and lengths exactly, independent of
  column order, case, formats and labels. The model dataset can be empty.
  When key= is supplied, every component must be nonmissing and each composite
  key must be unique. An empty dataset has no duplicate or missing keys.

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
  %local a b i result comments tmp rc keys keyname pos keylist missvars
    missingrows duplicaterows sqlstatus sqlstatus2 appendstatus
    outref baseds validrefs
    inlen baselen outlen;
  /* Resolve unqualified names to WORK and reject direct aliases. */
  %let validrefs=0;
  %let inlen=%length(%superq(inds));
  %let baselen=%length(%superq(base));
  %let outlen=%length(%superq(outds));
  data _null_;
    length reference inds baseds outref $32767;
    hascontrol=(anycntrl(symget('inds'))>0 or
      anycntrl(symget('base'))>0 or anycntrl(symget('outds'))>0);
    inds=cats(symget('inds'));
    baseds=cats(symget('base'));
    outref=cats(symget('outds'));
    if index(inds,'.')=0 then inds=cats('WORK.',inds);
    if index(baseds,'.')=0 then baseds=cats('WORK.',baseds);
    if index(outref,'.')=0 then outref=cats('WORK.',outref);
    reference=inds;
    %mp_validatecol(reference,LIBDS,valid_input)
    reference=baseds;
    %mp_validatecol(reference,LIBDS,valid_base)
    reference=outref;
    %mp_validatecol(reference,LIBDS,valid_output)
    if &inlen<=32767 and &baselen<=32767 and &outlen<=32767 and
        valid_input and valid_base and valid_output and not hascontrol and
        lengthn(inds)=&inlen+(index(symget('inds'),'.')=0)*5 and
        lengthn(baseds)=&baselen+(index(symget('base'),'.')=0)*5 and
        lengthn(outref)=&outlen+(index(symget('outds'),'.')=0)*5 then do;
      if upcase(outref)=upcase(inds) or upcase(outref)=upcase(baseds) then
        validrefs=2;
      else do;
        validrefs=1;
        call symputx('inds',inds,'L');
        call symputx('baseds',baseds,'L');
        call symputx('outref',outref,'L');
      end;
    end;
    else validrefs=0;
    call symputx('validrefs',validrefs,'L');
  run;
  %if &validrefs ne 1 %then %do;
    %if &validrefs=2 %then
      %put %str(ERR)OR: MP_ASSERTMODEL result destination overlaps an input.;
    %else %put %str(ERR)OR: MP_ASSERTMODEL invalid dataset reference.;
    %let syscc=%sysfunc(max(&syscc,1012));
    %return;
  %end;
  %let result=FAIL;
  %let comments=;
  %let sqlstatus=0;
  %let sqlstatus2=0;
  %let a=0;
  %let b=0;
  %let tmp=work.%mf_getuniquename(prefix=am);
  %let a=%sysfunc(open(%superq(inds),i));
  %if &a=0 %then %let comments=Input dataset cannot be opened;
  %else %do;
    %let b=%sysfunc(open(%superq(baseds),i));
    %if &b=0 %then %let comments=Model dataset cannot be opened;
    %else %do;
      data _null_;
        length bn $32 comments $256 result $5;
        a=open(symget('inds'),'i');
        b=open(symget('baseds'),'i');
        if a=0 or b=0 then do;
          result='FAIL';
          comments='Unable to open datasets for metadata comparison';
        end;
        else do;
          nactual=attrn(a,'NVARS');
          nbase=attrn(b,'NVARS');
          result='PASS';
          comments='Column names types and lengths match';
          if nactual ne nbase then do;
            result='FAIL';
            comments='Column count differs from model';
          end;
          else do i=1 to nbase;
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
        end;
        if a ne 0 then rc=close(a);
        if b ne 0 then rc=close(b);
        call symputx('result',result,'L');
        call symputx('comments',comments,'L');
      run;
      %if &result=PASS and %length(%superq(key))>0 %then %do;
        %let keylist=;
        %let missvars=;
        %let keys=%sysfunc(countw(%superq(key),%str( )));
        %do i=1 %to &keys;
          %let keyname=%qscan(%superq(key),&i,%str( ));
          %if %sysfunc(nvalid(%superq(keyname),v7))=0 %then %do;
            %let result=FAIL;
            %let comments=Invalid key column name;
          %end;
          %else %do;
            %let pos=%sysfunc(varnum(&a,%superq(keyname)));
            %if &pos=0 %then %do;
              %let result=FAIL;
              %let comments=Key column not found %superq(keyname);
            %end;
            %else %do;
              %if &i>1 %then %let keylist=&keylist,;
              %let keylist=&keylist t.%superq(keyname);
              %let missvars=&missvars missing(t.%superq(keyname)) or;
            %end;
          %end;
        %end;
        %if &result=PASS %then %do;
          %let missvars=%substr(%superq(missvars),1,
            %eval(%length(%superq(missvars))-3));
          %let rc=%sysfunc(close(&a));
          %let a=0;
          %let rc=%sysfunc(close(&b));
          %let b=0;
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
      %end;
    %end;
  %end;
  %if &a ne 0 %then %let rc=%sysfunc(close(&a));
  %if &b ne 0 %then %let rc=%sysfunc(close(&b));
  data &tmp;
    length test_description $256 test_result $5 test_comments $256;
    test_description=symget('desc');
    test_result=symget('result');
    test_comments=symget('comments');
  run;
  proc append base=&outref data=&tmp;
  run;
  %let appendstatus=&syserr;
  %if &appendstatus ne 0 %then
    %put %str(ERR)OR: MP_ASSERTMODEL could not append a result to &outds.;
  proc datasets lib=work nolist;
    delete %scan(&tmp,2,.);
  quit;
%mend mp_assertmodel;
