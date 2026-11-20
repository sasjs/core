/**
  @file
  @brief Assert dataset columns match a model and an optional key is valid
  @details Compares column names, types and lengths exactly, independent of
  column order, case, formats and labels. The model dataset can be empty.
  When key= is supplied, every component must be nonmissing and each composite
  key must be unique. An empty dataset has no duplicate or missing keys.

  One PASS or FAIL row is appended to outds. Missing datasets and invalid key
  columns produce FAIL. The inputs are not sorted or otherwise modified.

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

  <h4> Related Macros </h4>
  @li mp_assert.sas
  @li mp_assertcols.sas

  @version 9.4
  @author SASjs
**/
%macro mp_assertmodel(inds,base=,key=,desc=Testing dataset model,
    outds=work.test_results);
  %local a b i nbase nactual typ len bn bt bl
    result comments tmp rc keys keyname pos keylist missvars
    missingrows duplicaterows sqlstatus;
  %let result=FAIL;
  %let comments=;
  %let a=0;
  %let b=0;
  %let tmp=work.%mf_getuniquename(prefix=am);
  %let a=%sysfunc(open(%superq(inds),i));
  %if &a=0 %then %let comments=Input dataset cannot be opened;
  %else %do;
    %let b=%sysfunc(open(%superq(base),i));
    %if &b=0 %then %let comments=Model dataset cannot be opened;
    %else %do;
      %let nactual=%sysfunc(attrn(&a,nvars));
      %let nbase=%sysfunc(attrn(&b,nvars));
      %if &nactual ne &nbase %then
        %let comments=Column count differs from model;
      %else %do;
        %let result=PASS;
        %let comments=Column names types and lengths match;
        %do i=1 %to &nbase;
          %let bn=%sysfunc(varname(&b,&i));
          %let bt=%sysfunc(vartype(&b,&i));
          %let bl=%sysfunc(varlen(&b,&i));
          %let pos=%sysfunc(varnum(&a,%superq(bn)));
          %if &pos=0 %then %do;
            %let result=FAIL;
            %let comments=Missing column %superq(bn);
          %end;
          %else %do;
            %let typ=%sysfunc(vartype(&a,&pos));
            %let len=%sysfunc(varlen(&a,&pos));
            %if &typ ne &bt or &len ne &bl %then %do;
              %let result=FAIL;
              %let comments=Type or length differs for %superq(bn);
            %end;
          %end;
        %end;
      %end;
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
            select count(*) into :duplicaterows trimmed from (
              select &keylist, count(*) as n from &inds as t
              group by &keylist having count(*)>1
            );
          quit;
          %if &missingrows ne 0 or &duplicaterows ne 0 %then %do;
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
  proc append base=&outds data=&tmp;
  run;
  proc datasets lib=work nolist;
    delete %scan(&tmp,2,.);
  quit;
%mend mp_assertmodel;
