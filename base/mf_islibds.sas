/**
  @file
  @brief Checks whether a string follows correct library.dataset format
  @details Many macros in the core library accept a library.dataset parameter
  referred to as 'libds'.  This macro validates the structure of that parameter,
  eg:

    @li 8 character libref?
    @li 32 character dataset?
    @li contains a period?

  It does NOT check whether the dataset exists, or if the library is assigned.

  Usage:

      %put %mf_islibds(work.something)=1;
      %put %mf_islibds(nolib)=0;
      %put %mf_islibds(badlibref.ds)=0;
      %put %mf_islibds(w.t.f)=0;

  @param [in] libds The string to be checked

  @return output Returns 1 if libds is valid, 0 if it is not

  <h4> Related Macros </h4>
  @li mf_islibds.test.sas
  @li mp_validatecol.sas

  @version 9.2
**/

%macro mf_islibds(libds
)/*/STORE SOURCE*/;

%local regex;
%let regex=%sysfunc(prxparse(%str(/^[_a-z]\w{0,7}\.[_a-z]\w{0,31}$/i)));

%sysfunc(prxmatch(&regex,&libds))

%mend mf_islibds;