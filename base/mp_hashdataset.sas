/**
  @file
  @brief Returns a unique hash for a dataset
  @details Ignores metadata attributes, used only to hash values. Compared
  datasets must be in the same order.

      %mp_hashdataset(sashelp.class,outds=myhash)

      data _null_;
        set work.myhash;
        put hashkey=;
      run;

  ![sas md5 hash dataset log results](https://i.imgur.com/MqF98vk.png)

  <h4> SAS Macros </h4>
  @li mf_getattrn.sas
  @li mf_getuniquename.sas
  @li mf_getvarlist.sas
  @li mf_getvartype.sas

  @param [in] libds dataset to hash
  @param [in] salt= Provide a salt (could be, for instance, the dataset name)
  @param [out] outds= (work.mf_hashdataset) The output dataset to create. This
  will contain one column (hashkey) with one observation (a hex32.
  representation of the input hash)
  |hashkey:$32.|
  |---|
  |28ABC74ABFC45F50794237BA5566E6CA|

  @version 9.2
  @author Allan Bowe
**/

%macro mp_hashdataset(
  libds,
  outds=,
  salt=
)/*/STORE SOURCE*/;
  %if %mf_getattrn(&libds,NLOBS)=0 %then %do;
    %put %str(WARN)ING: Dataset &libds is empty;, or is not a dataset;
  %end;
  %else %if %mf_getattrn(&libds,NLOBS)<0 %then %do;
    %put %str(ERR)OR: Dataset &libds is not a dataset;
  %end;
  %else %do;
    %local keyvar /* roll up the md5 */
      prevkeyvar /* retain prev record md5 */
      lastvar /* last var in input ds */
      varlist var i;
    /* avoid naming conflict for hash key vars */
    %let keyvar=%mf_getuniquename();
    %let prevkeyvar=%mf_getuniquename();
    %let lastvar=%mf_getuniquename();
    %let varlist=%mf_getvarlist(&libds);
    data &outds(rename=(&keyvar=hashkey) keep=&keyvar);
      length &prevkeyvar &keyvar $32;
      retain &prevkeyvar "%sysfunc(md5(%str(&salt)),$hex32.)";
      set &libds end=&lastvar;
      /* hash should include previous row */
      &keyvar=put(md5(&prevkeyvar
      /* loop every column, hashing every individual value */
    %do i=1 %to %sysfunc(countw(&varlist));
      %let var=%scan(&varlist,&i,%str( ));
      %if %mf_getvartype(&libds,&var)=C %then %do;
          !!put(md5(trim(&var)),$hex32.)
      %end;
      %else %do;
          !!put(md5(trim(put(&var*1,binary64.))),$hex32.)
      %end;
    %end;
      ),$hex32.);
      &prevkeyvar=&keyvar;
      if &lastvar then output;
    run;
  %end;
%mend mp_hashdataset;