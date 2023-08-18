/**
  @file
  @brief Convert all library members to CARDS files
  @details Gets list of members then calls the <code>%mp_ds2cards()</code> macro.
  Usage:

      %mp_lib2cards(lib=sashelp
          , outloc= C:\temp )

  The output will be one cards file in the `outloc` directory per dataset in the
  input `lib` library.  If the `outloc` directory does not exist, it is created.

  To create a single SAS file with the first 1000 records of each table in a
  library you could use this syntax:

      %mp_lib2cards(lib=sashelp
          , outloc= /tmp
          , outfile= myfile.sas
          , maxobs= 1000
      )

  <h4> SAS Macros </h4>
  @li mf_mkdir.sas
  @li mf_trimstr.sas
  @li mp_ds2cards.sas

  @param [in] lib= () Library in which to convert all datasets
  @param [out] outloc= (%sysfunc(pathname(work))) Location in which to store
    output. No quotes.
  @param [out] outfile= (0) Optional output file NAME - if provided, then
    will create a single output file instead of one file per input table.
  @param [in] maxobs= (max) limit output to the first <code>maxobs</code> rows

  @version 9.2
  @author Allan Bowe
**/

%macro mp_lib2cards(lib=
    ,outloc=%sysfunc(pathname(work))
    ,maxobs=max
    ,random_sample=NO
    ,outfile=0
)/*/STORE SOURCE*/;

/* Find the tables */
%local x ds memlist;
proc sql noprint;
select distinct lowcase(memname)
  into: memlist
  separated by ' '
  from dictionary.tables
  where upcase(libname)="%upcase(&lib)";

/* trim trailing slash, if provided */
%let outloc=%mf_trimstr(&outloc,/);
%let outloc=%mf_trimstr(&outloc,\);

/* create the output directory */
%mf_mkdir(&outloc)

/* create the cards files */
%do x=1 %to %sysfunc(countw(&memlist));
  %let ds=%scan(&memlist,&x);
  %mp_ds2cards(base_ds=&lib..&ds
    ,maxobs=&maxobs
    ,random_sample=&random_sample
  %if "&outfile" ne "0" %then %do;
    ,append=YES
    ,cards_file="&outloc/&outfile"
  %end;
  %else %do;
    ,append=NO
    ,cards_file="&outloc/&ds..sas"
  %end;
  )
%end;

%mend mp_lib2cards;