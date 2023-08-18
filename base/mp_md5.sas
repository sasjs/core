/**
  @file
  @brief Generates an md5 expression for hashing a set of variables
  @details This is the same algorithm used to hash records in
  [Data Controller for SAS](https://datacontroller.io).

  It is not designed to be efficient - it is designed to be effective,
  given the range of edge cases (large floating points, special missing
  numerics, thousands of columns, very wide columns).

  It can be used only in data step, eg as follows:

      data _null_;
        set sashelp.class;
        hashvar=%mp_md5(cvars=name sex, nvars=age height weight);
        put hashvar=;
      run;

  Unfortunately it will not run in SQL - it fails with the following message:

  > The width value for HEX is out of bounds. It should be between 1 and 16

  The macro will also cause errors if the data contains (non-special) missings
  and the (undocumented) `options dsoptions=nonote2err;` is in effect.

  This can be avoided in two ways:

  @li Global option:  `options dsoptions=nonote2err;`
  @li Data step option: `data YOURLIB.YOURDATASET /nonote2err;`

  @param [in] cvars= () Space seperated list of character variables
  @param [in] nvars= () Space seperated list of numeric variables

  <h4> Related Programs </h4>
  @li mp_init.sas

  @version 9.2
  @author Allan Bowe
**/

%macro mp_md5(cvars=,nvars=);
%local i var sep;
put(md5(
  %do i=1 %to %sysfunc(countw(&cvars));
    %let var=%scan(&cvars,&i,%str( ));
    &sep put(md5(trim(&var)),$hex32.)
    %let sep=!!;
  %end;
  %do i=1 %to %sysfunc(countw(&nvars));
    %let var=%scan(&nvars,&i,%str( ));
    /* multiply by 1 to strip precision errors (eg 0 != 0) */
    /* but ONLY if not missing, else will lose any special missing values */
    &sep put(md5(trim(put(ifn(missing(&var),&var,&var*1),binary64.))),$hex32.)
    %let sep=!!;
  %end;
),$hex32.)
%mend mp_md5;
