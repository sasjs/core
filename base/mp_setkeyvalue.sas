/**
  @file
  @brief Logs a key value pair a control dataset
  @details If the dataset does not exist, it is created.  Usage:

      %mp_setkeyvalue(someindex,22,type=N)
      %mp_setkeyvalue(somenewindex,somevalue)

  <h4> SAS Macros </h4>
  @li mf_existds.sas

  <h4> Related Macros </h4>
  @li mf_getvalue.sas

  @param [in] key Provide a key on which to perform the lookup
  @param [in] value Provide a value
  @param [in] type= either C or N will populate valc and valn respectively.
    C is default.
  @param [out] libds= define the target table to hold the parameters

  @version 9.2
  @author Allan Bowe
  @source https://github.com/sasjs/core

**/

%macro mp_setkeyvalue(key,value,type=C,libds=work.mp_setkeyvalue
)/*/STORE SOURCE*/;

  %if not (%mf_existds(&libds)) %then %do;
    data &libds (index=(key/unique));
      length key $64 valc $2048 valn 8 type $1;
      call missing(of _all_);
      stop;
    run;
  %end;

  proc sql;
    delete from &libds
      where key=symget('key');
    insert into &libds
      set key=symget('key')
  %if &type=C %then %do;
        ,valc=symget('value')
        ,type='C'
  %end;
  %else %do;
        ,valn=symgetn('value')
        ,type='N'
  %end;
  ;

  quit;

%mend mp_setkeyvalue;