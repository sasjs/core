/**
  @file mp_createwebservice.sas
  @brief Create a web service in SAS 9 or Viya
  @details Creates a SASJS ready Stored Process in SAS 9 or Job Execution
  Service in SAS Viya

Usage:

    %* compile macros ;
    filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
    %inc mc;

    %* write some code;
    filename ft15f001 temp;
    parmcards4;
        %* fetch any data from frontend ;
        %webout(FETCH)
        data example1 example2;
          set sashelp.class;
        run;
        %* send data back;
        %webout(OPEN)
        %webout(ARR,example1) * Array format, fast, suitable for large tables ;
        %webout(OBJ,example2) * Object format, easier to work with ;
        %webout(CLOSE)
    ;;;;
    %mp_createwebservice(path=/Public/app/common,name=appInit,replace=YES)

  <h4> SAS Macros </h4>
  @li mf_getplatform.sas
  @li mm_createwebservice.sas
  @li mv_createwebservice.sas

  @param [in,out] path= The full folder path where the service will be created
  @param [in,out] name= Service name.  Avoid spaces.
  @param [in] desc= The description of the service (optional)
  @param [in] precode= Space separated list of filerefs, pointing to the code
    that needs to be attached to the beginning of the service (optional)
  @param [in] code= (ft15f001) Space seperated fileref(s) of the actual code to
    be added
  @param [in] replace= (YES) Select YES to replace any existing service in that
    location


  @version 9.2
  @author Allan Bowe

**/

%macro mp_createwebservice(path=HOME
    ,name=initService
    ,precode=
    ,code=ft15f001
    ,desc=This service was created by the mp_createwebservice macro
    ,replace=YES
)/*/STORE SOURCE*/;

%if &syscc ge 4 %then %do;
  %put syscc=&syscc - &sysmacroname will not execute in this state;
  %return;
%end;

%local platform; %let platform=%mf_getplatform();
%if &platform=SASVIYA %then %do;
  %if "&path"="HOME" %then %let path=/Users/&sysuserid/My Folder;
  %mv_createwebservice(path=&path
    ,name=&name
    ,code=&code
    ,precode=&precode
    ,desc=&desc
    ,replace=&replace
  )
%end;
%else %if &platform=SASJS %then %do;
  %if "&path"="HOME" %then %let path=/Users/&_sasjs_username/My Folder;
  %ms_createfile(&path/&name..sas
    ,inref=&code
    ,prerefs=&precode
  )
%end;
%else %do;
  %if "&path"="HOME" %then %let path=/User Folders/&_METAPERSON/My Folder;
  %mm_createwebservice(path=&path
    ,name=&name
    ,code=&code
    ,precode=&precode
    ,desc=&desc
    ,replace=&replace
  )
%end;

%mend mp_createwebservice;
