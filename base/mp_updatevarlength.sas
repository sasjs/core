/**
  @file mp_updatevarlength.sas
  @brief Change the length of a variable
  @details The library is assumed to be assigned.  Simple character updates
  currently supported, numerics are more complicated and will follow.

        data example;
          a='1';
          b='12';
          c='123';
        run;
        %mp_updatevarlength(example,a,3)
        %mp_updatevarlength(example,c,1)
        proc sql;
        describe table example;

  @param libds the library.dataset to be modified
  @param var The variable to modify
  @param len The new length to apply

  <h4> Dependencies </h4>
  @li mf_existds.sas
  @li mp_abort.sas
  @li mf_existvar.sas
  @li mf_getvarlen.sas
  @li mf_getvartype.sas
  @li mf_getnobs.sas
  @li mp_createconstraints.sas
  @li mp_getconstraints.sas
  @li mp_deleteconstraints.sas

  @version 9.2
  @author Allan Bowe

**/

%macro mp_updatevarlength(libds,var,len
)/*/STORE SOURCE*/;

%if %index(&libds,.)=0 %then %let libds=WORK.&libds;

%mp_abort(iftrue=(%mf_existds(&libds)=0)
  ,mac=&sysmacroname
  ,msg=%str(Table &libds not found!)
)

%mp_abort(iftrue=(%mf_existvar(&libds,&var)=0)
  ,mac=&sysmacroname
  ,msg=%str(Variable &var not found on &libds!)
)

/* not possible to in-place modify a numeric length, to add later */
%mp_abort(iftrue=(%mf_getvartype(&libds,&var)=0)
  ,mac=&sysmacroname
  ,msg=%str(Only character resizings are currently supported)
)

%local oldlen;
%let oldlen=%mf_getvarlen(&libds,&var);
%if  &oldlen=&len %then %do;
  %put &sysmacroname: Old and new lengths (&len) match!;
  %return;
%end;

%let libds=%upcase(&libds);


data;run;
%local dsconst; %let dsconst=&syslast;
%mp_getconstraints(lib=%scan(&libds,1,.),ds=%scan(&libds,2,.),outds=&dsconst)

%mp_abort(iftrue=(&syscc ne 0)
  ,mac=&sysmacroname
  ,msg=%str(syscc=&syscc)
)

%if %mf_getnobs(&dscont)=0 %then %do;
  /* must use SQL as proc datasets does not support length changes */
  proc sql;
  alter table &libds modify &var char(&len);
  %return;
%end;

/* we have constraints! */

%mp_deleteconstraints(inds=&dsconst,outds=&dsconst._dropd,execute=YES)

proc sql;
alter table &libds modify &var char(&len);

%mp_createconstraints(inds=&dsconst,outds=&dsconst._addd,execute=YES)

%mend;
