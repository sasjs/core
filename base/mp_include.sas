/**
  @file
  @brief Performs a wrapped \%include
  @details This macro wrapper is necessary if you need your included code to
  know that it is being \%included.

  If you are using %include in a regular program, you could make use of the
  following macro variables:

  @li SYSINCLUDEFILEDEVICE
  @li SYSINCLUDEFILEDIR
  @li SYSINCLUDEFILEFILEREF
  @li SYSINCLUDEFILENAME

  However these variables are NOT available inside a macro, as documented here:
https://documentation.sas.com/doc/en/pgmsascdc/9.4_3.5/mcrolref/n1j5tcc0n2xczyn1kg1o0606gsv9.htm

  This macro can be used in place of the %include statement, and will insert
  the following (equivalent) global variables:

  @li _SYSINCLUDEFILEDEVICE
  @li _SYSINCLUDEFILEDIR
  @li _SYSINCLUDEFILEFILEREF
  @li _SYSINCLUDEFILENAME

  These can be used whenever testing _within a macro_.  Outside of the macro,
  the regular automatic variables will still be available (thanks to a
  concatenated file list in the include statement).

  Example usage:

      filename example temp;
      data _null_;
        file example;
        put '%macro test();';
        put '%put &=_SYSINCLUDEFILEFILEREF;';
        put '%put &=SYSINCLUDEFILEFILEREF;';
        put '%mend; %test()';
        put '%put &=SYSINCLUDEFILEFILEREF;';
      run;
      %mp_include(example)

  @param [in] fileref The fileref of the file to be included. Must be provided.
  @param [in] prefix= (_) The prefix to apply to the global variables.
  @param [in] opts= (SOURCE2) The options to apply to the %inc statement
  @param [in] errds= (work.mp_abort_errds) There is no clean way to end a
    process within a %include called within a macro.  Furthermore, there is no
    way to test if a macro is called within a %include.  To handle this
    particular scenario, the %mp_abort() macro will test for the existence of
    the `_SYSINCLUDEFILEDEVICE` variable and return the outputs (msg,mac) inside
    this dataset.
    It will then run an abort cancel FILE to stop the include running, and pass
    the dataset back.
    NOTE - it is NOT possible to read this dataset as part of _this_ macro -
    when running abort cancel FILE, ALL macros are closed, so instead it is
    necessary to invoke "%mp_abort(mode=INCLUDE)" OUTSIDE of any macro wrappers.


  @version 9.4
  @author Allan Bowe

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mp_abort.sas

**/

%macro mp_include(fileref
  ,prefix=_
  ,opts=SOURCE2
  ,errds=work.mp_abort_errds
)/*/STORE SOURCE*/;

/* prepare precode */
%local tempref;
%let tempref=%mf_getuniquefileref();
data _null_;
  file &tempref;
  set sashelp.vextfl(where=(fileref="%upcase(&fileref)"));
  put '%let _SYSINCLUDEFILEDEVICE=' xengine ';';
  name=scan(xpath,-1,'/\');
  put '%let _SYSINCLUDEFILENAME=' name ';';
  path=subpad(xpath,1,length(xpath)-length(name)-1);
  put '%let _SYSINCLUDEFILEDIR=' path ';';
  put '%let _SYSINCLUDEFILEFILEREF=' "&fileref;";
run;

/* prepare the errds */
data &errds;
  length msg mac $1000;
  call missing(msg,mac);
  iftrue='1=0';
run;

/* include the include */
%inc &tempref &fileref/&opts;

%mp_abort(iftrue= (&syscc ne 0)
  ,mac=%str(&_SYSINCLUDEFILEDIR/&_SYSINCLUDEFILENAME)
  ,msg=%str(syscc=&syscc after executing &_SYSINCLUDEFILENAME)
)

filename &tempref clear;

%mend mp_include;