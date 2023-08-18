/**
  @file
  @brief Returns a unique hash for a dataset
  @details Ignores metadata attributes, used only to hash values. If used to
  compare datasets, they must have their columns and rows in the same order.

      %mp_hashdataset(sashelp.class,outds=myhash)

      data _null_;
        set work.myhash;
        put hashkey=;
      run;

  ![sas md5 hash dataset log results](https://i.4gl.io/1/KorUKoyE05.png/raw)

  <h4> SAS Macros </h4>
  @li mf_getattrn.sas
  @li mf_getuniquename.sas
  @li mf_getvarlist.sas
  @li mp_md5.sas

  <h4> Related Files </h4>
  @li mp_hashdataset.test.sas
  @li mp_hashdirectory.sas

  @param [in] libds dataset to hash
  @param [in] salt= () Provide a salt (could be, for instance, the dataset name)
  @param [in] iftrue= (1=1) A condition under which the macro should be executed
  @param [out] outds= (work._data_) The output dataset to create. This
  will contain one column (hashkey) with one observation (a $hex32.
  representation of the input hash)
  |hashkey:$32.|
  |---|
  |28ABC74ABFC45F50794237BA5566E6CA|

  @version 9.2
  @author Allan Bowe
**/

%macro mp_hashdataset(
  libds,
  outds=work._data_,
  salt=,
  iftrue=%str(1=1)
)/*/STORE SOURCE*/;

%local keyvar /* roll up the md5 */
  prevkeyvar /* retain prev record md5 */
  lastvar /* last var in input ds */
  cvars nvars;

%if not(%eval(%unquote(&iftrue))) %then %return;

/* avoid naming conflict for hash key vars */
%let keyvar=%mf_getuniquename();
%let prevkeyvar=%mf_getuniquename();
%let lastvar=%mf_getuniquename();

%if %mf_getattrn(&libds,NLOBS)=0 %then %do;
  data &outds;
    length hashkey $32;
    hashkey=put(md5("&salt"),$hex32.);
    output;
    stop;
  run;
  %put &sysmacroname: Dataset &libds is empty, or is not a dataset;
  %put &sysmacroname: hashkey of &outds is based on salt (&salt) only;
%end;
%else %if %mf_getattrn(&libds,NLOBS)<0 %then %do;
  %put %str(ERR)OR: Dataset &libds is not a dataset;
%end;
%else %do;
  data &outds(rename=(&keyvar=hashkey) keep=&keyvar)
  %if "%substr(&sysver,1,1)" ne "4" and "%substr(&sysver,1,1)" ne "5" %then %do;
    /nonote2err
  %end;
  ;
    length &prevkeyvar &keyvar $32;
    retain &prevkeyvar;
    if _n_=1 then &prevkeyvar=put(md5("&salt"),$hex32.);
    set &libds end=&lastvar;
    /* hash should include previous row */
    &keyvar=%mp_md5(
      cvars=%mf_getvarlist(&libds,typefilter=C) &prevkeyvar,
      nvars=%mf_getvarlist(&libds,typefilter=N)
    );
    &prevkeyvar=&keyvar;
    if &lastvar then output;
  run;
%end;
%mend mp_hashdataset;
