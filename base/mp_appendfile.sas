/**
  @file
  @brief Append (concatenate) two or more files.
  @details Will append one more more `appendrefs` (filerefs) to a `baseref`.
  Uses a binary mechanism, so will work with any file type.  For that reason -
  use with care!   And supply your own trailing carriage returns in each file..

  Usage:

        filename tmp1 temp;
        filename tmp2 temp;
        filename tmp3 temp;
        data _null_; file tmp1; put 'base file';
        data _null_; file tmp2; put 'append1';
        data _null_; file tmp3; put 'append2';
        run;
        %mp_appendfile(baseref=tmp1, appendrefs=tmp2 tmp3)


  @param [in] baseref= (0) Fileref of the base file (should exist)
  @param [in] appendrefs= (0) One or more filerefs to be appended to the base
    fileref.  Space separated.

  @version 9.2
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> SAS Macros </h4>
  @li mp_abort.sas
  @li mp_binarycopy.sas


**/

%macro mp_appendfile(
  baseref=0,
  appendrefs=0
)/*/STORE SOURCE*/;

%mp_abort(iftrue= (&baseref=0)
  ,mac=&sysmacroname
  ,msg=%str(Baseref NOT specified!)
)
%mp_abort(iftrue= (&appendrefs=0)
  ,mac=&sysmacroname
  ,msg=%str(Appendrefs NOT specified!)
)

%local i;
%do i=1 %to %sysfunc(countw(&appendrefs));
  %mp_abort(iftrue= (&syscc>0)
    ,mac=&sysmacroname
    ,msg=%str(syscc=&syscc)
  )
  %mp_binarycopy(inref=%scan(&appendrefs,&i), outref=&baseref, mode=APPEND)
%end;

%mend mp_appendfile;