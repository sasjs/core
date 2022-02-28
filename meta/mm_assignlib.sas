/**
  @file
  @brief Assigns a meta engine library using LIBREF
  @details Queries metadata to get the library NAME which can then be used in
    a libname statement with the meta engine.

  usage:

      %macro mp_abort(iftrue,mac,msg);%put &=msg;%mend;

      %mm_assignlib(SOMEREF)

  <h4> SAS Macros </h4>
  @li mp_abort.sas

  @param libref the libref (not name) of the metadata library
  @param mAbort= If not assigned, HARD will call %mp_abort(), SOFT will
    silently return

  @returns libname statement

  @version 9.2
  @author Allan Bowe

**/

%macro mm_assignlib(
    libref
    ,mAbort=HARD
)/*/STORE SOURCE*/;

%if %sysfunc(libref(&libref)) %then %do;
  %local mp_abort msg; %let mp_abort=0;
  data _null_;
    length liburi LibName $200;
    call missing(of _all_);
    nobj=metadata_getnobj("omsobj:SASLibrary?@Libref='&libref'",1,liburi);
    if nobj=1 then do;
      rc=metadata_getattr(liburi,"Name",LibName);
      /* now try and assign it */
      if libname("&libref",,'meta',cats('liburi="',liburi,'";')) ne 0 then do;
        putlog "&libref could not be assigned";
        putlog liburi=;
        /**
          * Fetch the system message for display in the abort modal.  This is
          * not always helpful though.  One example, previously received:
          * NOTE: Libref XX refers to the same library metadata as libref XX.
          */
        call symputx('msg',sysmsg(),'l');
        if "&mabort"='HARD' then call symputx('mp_abort',1,'l');
      end;
      else do;
        put (_all_)(=);
        call symputx('libname',libname,'L');
        call symputx('liburi',liburi,'L');
      end;
    end;
    else if nobj>1 then do;
      if "&mabort"='HARD' then call symputx('mp_abort',1);
      call symputx('msg',"More than one library with libref=&libref");
    end;
    else do;
      if "&mabort"='HARD' then call symputx('mp_abort',1);
      call symputx('msg',"Library &libref not found in metadata");
    end;
  run;

  %if &mp_abort=1 %then %do;
    %mp_abort(iftrue= (&mp_abort=1)
      ,mac=mm_assignlib.sas
      ,msg=&msg
    )
    %return;
  %end;
  %else %if %length(&msg)>2 %then %do;
    %put NOTE: &msg;
    %return;
  %end;

%end;
%else %do;
  %put NOTE: Library &libref is already assigned;
%end;
%mend mm_assignlib;
