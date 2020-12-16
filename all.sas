
/**
  @file
  @brief Auto-generated file
  @details
    This file contains all the macros in a single file - which means it can be
    'included' in SAS with just 2 lines of code:

      filename mc url
        "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

    The `build.py` file in the https://github.com/sasjs/core repo
    is used to create this file.

  @author Allan Bowe
**/
options noquotelenmax;
/**
  @file
  @brief abort gracefully according to context
  @details Do not use directly!  See bottom of explanation for details.

   Configures an abort mechanism according to site specific policies or the
    particulars of an environment.  For instance, can stream custom
    results back to the client in an STP Web App context, or completely stop
    in the case of a batch run.

  For the sharp eyed readers - this is no longer a macro function!! It became
  a macro procedure during a project and now it's kinda stuck that way until
  that project is updated (if it's ever updated).  In the meantime we created
  `mp_abort` which is just a wrapper for this one, and so we recomend you use
  that for forwards compatibility reasons.

  @param mac= to contain the name of the calling macro
  @param type= deprecated.  Not used.
  @param msg= message to be returned
  @param iftrue= supply a condition under which the macro should be executed.

  @version 9.2
  @author Allan Bowe
  @cond
**/

%macro mf_abort(mac=mf_abort.sas, type=, msg=, iftrue=%str(1=1)
)/*/STORE SOURCE*/;

  %if not(%eval(%unquote(&iftrue))) %then %return;

  %put NOTE: ///  mf_abort macro executing //;
  %if %length(&mac)>0 %then %put NOTE- called by &mac;
  %put NOTE - &msg;

  /* Stored Process Server web app context */
  %if %symexist(_metaperson) or "&SYSPROCESSNAME"="Compute Server" %then %do;
    options obs=max replace nosyntaxcheck mprint;
    /* extract log err / warn, if exist */
    %local logloc logline;
    %global logmsg; /* capture global messages */
    %if %symexist(SYSPRINTTOLOG) %then %let logloc=&SYSPRINTTOLOG;
    %else %let logloc=%qsysfunc(getoption(LOG));
    proc printto log=log;run;
    %if %length(&logloc)>0 %then %do;
      %let logline=0;
      data _null_;
        infile &logloc lrecl=5000;
        input; putlog _infile_;
        i=1;
        retain logonce 0;
        if (_infile_=:"%str(WARN)ING" or _infile_=:"%str(ERR)OR") and logonce=0 then do;
          call symputx('logline',_n_);
          logonce+1;
        end;
      run;
      /* capture log including lines BEFORE the err */
      %if &logline>0 %then %do;
        data _null_;
          infile &logloc lrecl=5000;
          input;
          i=1;
          stoploop=0;
          if _n_ ge &logline-5 and stoploop=0 then do until (i>12);
            call symputx('logmsg',catx('\n',symget('logmsg'),_infile_));
            input;
            i+1;
            stoploop=1;
          end;
          if stoploop=1 then stop;
        run;
      %end;
    %end;

    /* send response in SASjs JSON format */
    data _null_;
      file _webout mod lrecl=32000;
      length msg $32767;
      sasdatetime=datetime();
      msg=cats(symget('msg'),'\n\nLog Extract:\n',symget('logmsg'));
      /* escape the quotes */
      msg=tranwrd(msg,'"','\"');
      /* ditch the CRLFs as chrome complains */
      msg=compress(msg,,'kw');
      /* quote without quoting the quotes (which are escaped instead) */
      msg=cats('"',msg,'"');
      if symexist('_debug') then debug=symget('_debug');
      if debug ge 131 then put '>>weboutBEGIN<<';
      put '{"START_DTTM" : "' "%sysfunc(datetime(),datetime20.3)" '"';
      put ',"sasjsAbort" : [{';
      put ' "MSG":' msg ;
      put ' ,"MAC": "' "&mac" '"}]';
      put ",""SYSUSERID"" : ""&sysuserid"" ";
      if symexist('_metauser') then do;
        _METAUSER=quote(trim(symget('_METAUSER')));
        put ",""_METAUSER"": " _METAUSER;
        _METAPERSON=quote(trim(symget('_METAPERSON')));
        put ',"_METAPERSON": ' _METAPERSON;
      end;
      _PROGRAM=quote(trim(resolve(symget('_PROGRAM'))));
      put ',"_PROGRAM" : ' _PROGRAM ;
      put ",""SYSCC"" : ""&syscc"" ";
      put ",""SYSERRORTEXT"" : ""&syserrortext"" ";
      put ",""SYSJOBID"" : ""&sysjobid"" ";
      put ",""SYSWARNINGTEXT"" : ""&syswarningtext"" ";
      put ',"END_DTTM" : "' "%sysfunc(datetime(),datetime20.3)" '" ';
      put "}" @;
      %if &_debug ge 131 %then %do;
        put '>>weboutEND<<';
      %end;
    run;
    %let syscc=0;
    %if %symexist(SYS_JES_JOB_URI) %then %do;
      /* refer web service output to file service in one hit */
      filename _webout filesrvc parenturi="&SYS_JES_JOB_URI" name="_webout.json";
      %let rc=%sysfunc(fcopy(_web,_webout));
    %end;
    %else %do;
      data _null_;
        if symexist('sysprocessmode')
         then if symget("sysprocessmode")="SAS Stored Process Server"
          then rc=stpsrvset('program error', 0);
      run;
    %end;
    /**
     * endsas is reliable but kills some deployments.
     * Abort variants are ungraceful (non zero return code)
     * This approach lets SAS run silently until the end :-)
     */
    %put _all_;
    filename skip temp;
    data _null_;
      file skip;
      put '%macro skip(); %macro skippy();';
    run;
    %inc skip;
  %end;
  %else %do;
    %put _all_;
    %abort cancel;
  %end;
%mend;

/** @endcond *//**
  @file mf_existds.sas
  @brief Checks whether a dataset OR a view exists.
  @details Can be used in open code, eg as follows:

      %if %mf_existds(libds=work.someview) %then %put  yes it does!;

  NOTE - some databases have case sensitive tables, for instance POSTGRES
    with the preserve_tab_names=yes libname setting.  This may impact
    expected results (depending on whether you 'expect' the result to be
    case insensitive in this context!)

  @param libds library.dataset
  @return output returns 1 or 0
  @warning Untested on tables registered in metadata but not physically present
  @version 9.2
  @author Allan Bowe
**/

%macro mf_existds(libds
)/*/STORE SOURCE*/;

  %if %sysfunc(exist(&libds)) ne 1 & %sysfunc(exist(&libds,VIEW)) ne 1 %then 0;
  %else 1;

%mend;/**
  @file
  @brief Checks whether a feature exists
  @details Check to see if a feature is supported in your environment.
    Run without arguments to see a list of detectable features.
    Note - this list is based on known versions of SAS rather than
    actual feature detection, as that is tricky / impossible to do
    without generating errors in most cases.

        %put %mf_existfeature(PROCLUA);

  @param feature the feature to detect.  Leave blank to list all in log.

  @return output returns 1 or 0 (or -1 if not found)

  <h4> Dependencies </h4>
  @li mf_getplatform.sas


  @version 8
  @author Allan Bowe
**/
/** @cond */

%macro mf_existfeature(feature
)/*/STORE SOURCE*/;
  %let feature=%upcase(&feature);
  %local platform;
  %let platform=%mf_getplatform();

  %if &feature= %then %do;
    %put Supported features:  PROCLUA;
  %end;
  %else %if &feature=PROCLUA %then %do;
    %if &platform=SASVIYA %then 1;
    %else %if "&sysver"="9.3" or "&sysver"="9.4" %then 1;
    %else 0;
  %end;
  %else %do;
    -1
    %put &sysmacroname: &feature not found;
  %end;
%mend;

/** @endcond *//**
  @file
  @brief Checks if a variable exists in a data set.
  @details Returns 0 if the variable does NOT exist, and return the position of
    the var if it does.
    Usage:

        %put %mf_existvar(work.someds, somevar)

  @param libds (positional) - 2 part dataset or view reference
  @param var (positional) - variable name
  @version 9.2
  @author Allan Bowe
**/
/** @cond */

%macro mf_existvar(libds /* 2 part dataset name */
      , var /* variable name */
)/*/STORE SOURCE*/;

  %local dsid rc;
  %let dsid=%sysfunc(open(&libds,is));

  %if &dsid=0 or %length(&var)=0 %then %do;
    %put %sysfunc(sysmsg());
      0
  %end;
  %else %do;
      %sysfunc(varnum(&dsid,&var))
      %let rc=%sysfunc(close(&dsid));
  %end;

%mend;

/** @endcond *//**
  @file
  @brief Checks if a set of variables ALL exist in a data set.
  @details Returns 0 if ANY of the variables do not exist, or 1 if they ALL do.
    Usage:

        %put %mf_existVarList(sashelp.class, age sex name dummyvar)

  <h4> Dependencies </h4>
  @li mf_abort.sas

  @param libds 2 part dataset or view reference
  @param varlist space separated variable names

  @version 9.2
  @author Allan Bowe
  @cond
**/

%macro mf_existvarlist(libds, varlist
)/*/STORE SOURCE*/;

  %if %str(&libds)=%str() or %str(&varlist)=%str() %then %do;
    %mf_abort(msg=No value provided to libds(&libds) or varlist (&varlist)!
      ,mac=mf_existvarlist.sas)
  %end;

  %local dsid rc i var found;
  %let dsid=%sysfunc(open(&libds,is));

  %if &dsid=0 %then %do;
    %put WARNING:  unable to open &libds in mf_existvarlist (&dsid);
  %end;

  %if %sysfunc(attrn(&dsid,NVARS))=0 %then %do;
    %put MF_EXISTVARLIST:  No variables in &libds ;
    0
    %return;
  %end;

  %else %do i=1 %to %sysfunc(countw(&varlist));
    %let var=%scan(&varlist,&i);

    %if %sysfunc(varnum(&dsid,&var))=0  %then %do;
      %let found=&found &var;
    %end;
  %end;

  %let rc=%sysfunc(close(&dsid));
  %if %str(&found)=%str() %then %do;
    1
  %end;
  %else %do;
    0
    %put Vars not found: &found;
  %end;
%mend;

/** @endcond *//**
  @file
  @brief Returns a character attribute of a dataset.
  @details Can be used in open code, eg as follows:

      %put Dataset label = %mf_getattrc(sashelp.class,LABEL);
      %put Member Type = %mf_getattrc(sashelp.class,MTYPE);

  @param libds library.dataset
  @param attr full list in [documentation](
    https://support.sas.com/documentation/cdl/en/lrdict/64316/HTML/default/viewer.htm#a000147794.htm)
  @return output returns result of the attrc value supplied, or -1 and log
    message if error.

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getattrc(
     libds
    ,attr
)/*/STORE SOURCE*/;
  %local dsid rc;
  %let dsid=%sysfunc(open(&libds,is));
  %if &dsid = 0 %then %do;
    %put WARNING: Cannot open %trim(&libds), system message below;
    %put %sysfunc(sysmsg());
    -1
  %end;
  %else %do;
    %sysfunc(attrc(&dsid,&attr))
    %let rc=%sysfunc(close(&dsid));
  %end;
%mend;/**
  @file
  @brief Returns a numeric attribute of a dataset.
  @details Can be used in open code, eg as follows:

      %put Number of observations=%mf_getattrn(sashelp.class,NLOBS);
      %put Number of variables = %mf_getattrn(sashelp.class,NVARS);

  @param libds library.dataset
  @param attr Common values are NLOBS and NVARS, full list in [documentation](
    http://support.sas.com/documentation/cdl/en/lrdict/64316/HTML/default/viewer.htm#a000212040.htm)
  @return output returns result of the attrn value supplied, or -1 and log
    message if error.

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getattrn(
     libds
    ,attr
)/*/STORE SOURCE*/;
  %local dsid rc;
  %let dsid=%sysfunc(open(&libds,is));
  %if &dsid = 0 %then %do;
    %put WARNING: Cannot open %trim(&libds), system message below;
    %put %sysfunc(sysmsg());
    -1
  %end;
  %else %do;
    %sysfunc(attrn(&dsid,&attr))
    %let rc=%sysfunc(close(&dsid));
  %end;
%mend;/**
  @file
  @brief Returns the engine type of a SAS library
  @details Usage:

      %put %mf_getengine(SASHELP);

  returns:
  > V9

  A note is also written to the log.  The credit for this macro goes to the
  contributors of Chris Hemedingers blog [post](
  http://blogs.sas.com/content/sasdummy/2013/06/04/find-a-sas-library-engine/)

  @param libref Library reference (also accepts a 2 level libds ref).

  @return output returns the library engine for the FIRST library encountered.

  @warning will only return the FIRST library engine - for concatenated
    libraries, with different engines, inconsistent results may be encountered.

  @version 9.2
  @author Allan Bowe

**/
/** @cond */

%macro mf_getengine(libref
)/*/STORE SOURCE*/;
  %local dsid engnum rc engine;

  /* in case the parameter is a libref.tablename, pull off just the libref */
  %let libref = %upcase(%scan(&libref, 1, %str(.)));

  %let dsid=%sysfunc(open(sashelp.vlibnam(where=(libname="%upcase(&libref)")),i));
  %if (&dsid ^= 0) %then %do;
    %let engnum=%sysfunc(varnum(&dsid,ENGINE));
    %let rc=%sysfunc(fetch(&dsid));
    %let engine=%sysfunc(getvarc(&dsid,&engnum));
    %put &libref. ENGINE is &engine.;
    %let rc= %sysfunc(close(&dsid));
  %end;

 &engine

%mend;

/** @endcond *//**
  @file
  @brief Returns the size of a file in bytes.
  @details Provide full path/filename.extension to the file, eg:

      %put %mf_getfilesize(fpath=C:\temp\myfile.txt);

      or

      data x;do x=1 to 100000;y=x;output;end;run;
      %put %mf_getfilesize(libds=work.x,format=yes);

      gives:

      2mb

  @param fpath= full path and filename.  Provide this OR the libds value.
  @param libds= library.dataset value (assumes library is BASE engine)
  @param format=  set to yes to apply sizekmg. format
  @returns bytes

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getfilesize(fpath=,libds=0,format=NO
)/*/STORE SOURCE*/;

  %if &libds ne 0 %then %do;
    %let fpath=%sysfunc(pathname(%scan(&libds,1,.)))/%scan(&libds,2,.).sas7bdat;
  %end;

  %local rc fid fref bytes;
  %let rc=%sysfunc(filename(fref,&fpath));
  %let fid=%sysfunc(fopen(&fref));
  %let bytes=%sysfunc(finfo(&fid,File Size (bytes)));
  %let rc=%sysfunc(fclose(&fid));
  %let rc=%sysfunc(filename(fref));

  %if &format=NO %then %do;
     &bytes
  %end;
  %else %do;
    %sysfunc(INPUTN(&bytes, best.),sizekmg.)
  %end;

%mend ;/**
  @file
  @brief retrieves a key value pair from a control dataset
  @details By default, control dataset is work.mp_setkeyvalue.  Usage:

    %mp_setkeyvalue(someindex,22,type=N)
    %put %mf_getkeyvalue(someindex)


  @param key Provide a key on which to perform the lookup
  @param libds= define the target table which holds the parameters

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getkeyvalue(key,libds=work.mp_setkeyvalue
)/*/STORE SOURCE*/;
 %local ds dsid key valc valn type rc;
%let dsid=%sysfunc(open(&libds(where=(key="&key"))));
%syscall set(dsid);
%let rc = %sysfunc(fetch(&dsid));
%let rc = %sysfunc(close(&dsid));

%if &type=N %then %do;
  &valn
%end;
%else %if &type=C %then %do;
  &valc
%end;
%else %put %str(ERR)OR: Unable to find key &key in ds &libds;
%mend;/**
  @file mf_getplatform.sas
  @brief Returns platform specific variables
  @details Enables platform specific variables to be returned

      %put %mf_getplatform();

    returns:
      SASMETA  (or SASVIYA)

  @param switch the param for which to return a platform specific variable

  <h4> Dependencies </h4>
  @li mf_mval.sas
  @li mf_trimstr.sas

  @version 9.4 / 3.4
  @author Allan Bowe
**/

%macro mf_getplatform(switch
)/*/STORE SOURCE*/;
%local a b c;
%if &switch.NONE=NONE %then %do;
  %if %symexist(sysprocessmode) %then %do;
    %if "&sysprocessmode"="SAS Object Server" 
    or "&sysprocessmode"= "SAS Compute Server" %then %do;
        SASVIYA
    %end;
    %else %if "&sysprocessmode"="SAS Stored Process Server" %then %do;
      SASMETA
      %return;
    %end;
    %else %do;
      SAS
      %return;
    %end;
  %end;
  %else %if %symexist(_metaport) %then %do;
    SASMETA
    %return;
  %end;
  %else %do;
    SAS
    %return;
  %end;
%end;
%else %if &switch=SASSTUDIO %then %do;
  /* return the version of SAS Studio else 0 */
  %if %mf_mval(_CLIENTAPP)=%str(SAS Studio) %then %do;
    %let a=%mf_mval(_CLIENTVERSION);
    %let b=%scan(&a,1,.);
    %if %eval(&b >2) %then %do;
      &b
    %end;
    %else 0;
  %end;
  %else 0;
%end;
%else %if &switch=VIYARESTAPI %then %do;
  %mf_trimstr(%sysfunc(getoption(servicesbaseurl)),/)
%end;
%mend;/**
  @file
  @brief Adds custom quotes / delimiters to a  delimited string
  @details Can be used in open code, eg as follows:

    %put %mf_getquotedstr(blah   blah  blah);

  which returns:
> 'blah','blah','blah'

  @param in_str the unquoted, spaced delimited string to transform
  @param dlm= the delimeter to be applied to the output (default comma)
  @param indlm= the delimeter used for the input (default is space)
  @param quote= the quote mark to apply (S=Single, D=Double). If any other value
    than uppercase S or D is supplied, then that value will be used as the
    quoting character.
  @return output returns a string with the newly quoted / delimited output.

  @version 9.2
  @author Allan Bowe
**/


%macro mf_getquotedstr(IN_STR,DLM=%str(,),QUOTE=S,indlm=%str( )
)/*/STORE SOURCE*/;
  %if &quote=S %then %let quote=%str(%');
  %else %if &quote=D %then %let quote=%str(%");
  %else %let quote=%str();
  %local i item buffer;
  %let i=1;
  %do %while (%qscan(&IN_STR,&i,%str(&indlm)) ne %str() ) ;
    %let item=%qscan(&IN_STR,&i,%str(&indlm));
    %if %bquote(&QUOTE) ne %then %let item=&QUOTE%qtrim(&item)&QUOTE;
    %else %let item=%qtrim(&item);

    %if (&i = 1) %then %let buffer =%qtrim(&item);
    %else %let buffer =&buffer&DLM%qtrim(&item);

    %let i = %eval(&i+1);
  %end;

  %let buffer=%sysfunc(coalescec(%qtrim(&buffer),&QUOTE&QUOTE));

  &buffer

%mend;/**
  @file mf_getschema.sas
  @brief Returns the database schema of a SAS library
  @details Usage:

      %put %mf_getschema(MYDB);

  returns:
  > dbo

  @param libref Library reference (also accepts a 2 level libds ref).

  @return output returns the library schema for the FIRST library encountered

  @warning will only return the FIRST library schema - for concatenated
    libraries, with different schemas, inconsistent results may be encountered.

  @version 9.2
  @author Allan Bowe
  @cond
**/

%macro mf_getschema(libref
)/*/STORE SOURCE*/;
  %local dsid vnum rc schema;
  /* in case the parameter is a libref.tablename, pull off just the libref */
  %let libref = %upcase(%scan(&libref, 1, %str(.)));
  %let dsid=%sysfunc(open(sashelp.vlibnam(where=(
    libname="%upcase(&libref)" and sysname='Schema/Owner'
  )),i));
  %if (&dsid ^= 0) %then %do;
    %let vnum=%sysfunc(varnum(&dsid,SYSVALUE));
    %let rc=%sysfunc(fetch(&dsid));
    %let schema=%sysfunc(getvarc(&dsid,&vnum));
    %put &libref. schema is &schema.;
    %let rc= %sysfunc(close(&dsid));
  %end;

  &schema

%mend;

/** @endcond */
/**
  @file
  @brief Assigns and returns an unused fileref
  @details
  Use as follows:

      %let fileref1=%mf_getuniquefileref();
      %let fileref2=%mf_getuniquefileref();
      %put &fileref1 &fileref2;

  which returns:

> mcref0 mcref1

  @param prefix= first part of fileref. Remember that filerefs can only be 8
    characters, so a 7 letter prefix would mean that `maxtries` should be 10.
  @param maxtries= the last part of the libref.  Provide an integer value.

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getuniquefileref(prefix=mcref,maxtries=1000);
  %local x fname;
  %let x=0;
  %do x=0 %to &maxtries;
  %if %sysfunc(fileref(&prefix&x)) > 0 %then %do;
    %let fname=&prefix&x;
    %let rc=%sysfunc(filename(fname,,temp));
    %if &rc %then %put %sysfunc(sysmsg());
    &prefix&x
    %*put &sysmacroname: Fileref &prefix&x was assigned and returned;
    %return;
  %end;
  %end;
  %put unable to find available fileref in range &prefix.0-&maxtries;
%mend;/**
  @file
  @brief Returns an unused libref
  @details Use as follows:

    libname mclib0 (work);
    libname mclib1 (work);
    libname mclib2 (work);

    %let libref=%mf_getuniquelibref();
    %put &=libref;

  which returns:

> mclib3

  @param prefix= first part of libref.  Remember that librefs can only be 8 characters,
    so a 7 letter prefix would mean that maxtries should be 10.
  @param maxtries= the last part of the libref.  Provide an integer value.

  @version 9.2
  @author Allan Bowe
**/


%macro mf_getuniquelibref(prefix=mclib,maxtries=1000);
  %local x libref;
  %let x=0;
  %do x=0 %to &maxtries;
  %if %sysfunc(libref(&prefix&x)) ne 0 %then %do;
    %let libref=&prefix&x;
    %let rc=%sysfunc(libname(&libref,%sysfunc(pathname(work))));
    %if &rc %then %put %sysfunc(sysmsg());
    &prefix&x
    %*put &sysmacroname: Libref &libref assigned as WORK and returned;
    %return;
  %end;
  %end;
  %put unable to find available libref in range &prefix.0-&maxtries;
%mend;/**
  @file mf_getuniquename.sas
  @brief Returns a shortened (32 char) GUID as a valid SAS name
  @details Use as follows:

      %let myds=%mf_getuniquename();
      %put &=myds;

  which returns:

> MCc59c750610321d4c8bf75faadbcd22

  @param prefix= set a prefix for the new name

  @version 9.3
  @author Allan Bowe
**/


%macro mf_getuniquename(prefix=MC);
  &prefix.%substr(%sysfunc(compress(%sysfunc(uuidgen()),-)),1,32-%length(&prefix))
%mend;/**
  @file
  @brief Returns a userid according to session context
  @details In a workspace session, a user is generally represented by <code>
    &sysuserid</code> or <code>SYS_COMPUTE_SESSION_OWNER</code> if it exists.  
    In a Stored Process session, <code>&sysuserid</code>
    resolves to a system account (default=sassrv) and instead there are several
    metadata username variables to choose from (_metauser, _metaperson
    ,_username, _secureusername).  The OS account is represented by
    <code> _secureusername</code> whilst the metadata account is under <code>
    _metaperson</code>.

        %let user= %mf_getUser();
        %put &user;
        
  @param type - do not use, may be deprecated in a future release

  @return SYSUSERID (if workspace server)
  @return _METAPERSON (if stored process server)
  @return SYS_COMPUTE_SESSION_OWNER (if Viya compute session)

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getuser(type=META
)/*/STORE SOURCE*/;
  %local user metavar;
  %if &type=OS %then %let metavar=_secureusername;
  %else %let metavar=_metaperson;

  %if %symexist(SYS_COMPUTE_SESSION_OWNER) %then %let user=&SYS_COMPUTE_SESSION_OWNER;
  %else %if %symexist(&metavar) %then %do;
    %if %length(&&&metavar)=0 %then %let user=&sysuserid;
    /* sometimes SAS will add @domain extension - remove for consistency */
    %else %let user=%scan(&&&metavar,1,@);
  %end;
  %else %let user=&sysuserid;

  %quote(&user)

%mend;
/**
  @file
  @brief Retrieves a value from a dataset.  If no filter supplied, then first
    record is used.
  @details Be sure to <code>%quote()</code> your where clause.  Example usage:

      %put %mf_getvalue(sashelp.class,name,filter=%quote(age=15));
      %put %mf_getvalue(sashelp.class,name);

  <h4> Dependencies </h4>
  @li mf_getattrn.sas

  @param libds dataset to query
  @param variable the variable which contains the value to return.
  @param filter contents of where clause

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getvalue(libds,variable,filter=1
)/*/STORE SOURCE*/;
 %if %mf_getattrn(&libds,NLOBS)>0 %then %do;
    %local dsid rc &variable;
    %let dsid=%sysfunc(open(&libds(where=(&filter))));
    %syscall set(dsid);
    %let rc = %sysfunc(fetch(&dsid));
    %let rc = %sysfunc(close(&dsid));

    %trim(&&&variable)

  %end;
%mend;/**
  @file
  @brief Returns number of variables in a dataset
  @details Useful to identify those renagade datasets that have no columns!

        %put Number of Variables=%mf_getvarcount(sashelp.class);

  returns:
  > Number of Variables=4

  @param libds Two part dataset (or view) reference.

  @version 9.2
  @author Allan Bowe

**/

%macro mf_getvarcount(libds
)/*/STORE SOURCE*/;
  %local dsid nvars rc ;
  %let dsid=%sysfunc(open(&libds));
  %let nvars=.;
  %if &dsid %then %do;
    %let nvars=%sysfunc(attrn(&dsid,NVARS));
    %let rc=%sysfunc(close(&dsid));
  %end;
  %else %do;
    %put unable to open &libds (rc=&dsid);
    %let rc=%sysfunc(close(&dsid));
  %end;
  &nvars
%mend;/**
  @file
  @brief Returns the format of a variable
  @details Uses varfmt function to identify the format of a particular variable.
  Usage:

      data test;
         format str1 $1.  num1 datetime19.;
         str2='hello mum!'; num2=666;
         stop;
      run;
      %put %mf_getVarFormat(test,str1);
      %put %mf_getVarFormat(work.test,num1);
      %put %mf_getVarFormat(test,str2,force=1);
      %put %mf_getVarFormat(work.test,num2,force=1);
      %put %mf_getVarFormat(test,renegade);

  returns:

      $1.
      DATETIME19.
      $10.
      8.
      NOTE: Variable renegade does not exist in test

  @param libds Two part dataset (or view) reference.
  @param var Variable name for which a format should be returned
  @param force Set to 1 to supply a default if the variable has no format
  @returns outputs format

  @author Allan Bowe
  @version 9.2
**/

%macro mf_getVarFormat(libds /* two level ds name */
      , var /* variable name from which to return the format */
      , force=0
)/*/STORE SOURCE*/;
  %local dsid vnum vformat rc vlen vtype;
  /* Open dataset */
  %let dsid = %sysfunc(open(&libds));
  %if &dsid > 0 %then %do;
    /* Get variable number */
    %let vnum = %sysfunc(varnum(&dsid, &var));
    /* Get variable format */
    %if(&vnum > 0) %then %let vformat=%sysfunc(varfmt(&dsid, &vnum));
    %else %do;
       %put NOTE: Variable &var does not exist in &libds;
       %let rc = %sysfunc(close(&dsid));
       %return;
    %end;
  %end;
  %else %do;
    %put dataset &libds not opened! (rc=&dsid);
    %return;
  %end;

  /* supply a default if no format available */
  %if %length(&vformat)<2 & &force=1 %then %do;
    %let vlen = %sysfunc(varlen(&dsid, &vnum));
    %let vtype = %sysfunc(vartype(&dsid, &vnum.));
    %if &vtype=C %then %let vformat=$&vlen..;
    %else %let vformat=8.;
  %end;


  /* Close dataset */
  %let rc = %sysfunc(close(&dsid));
  /* Return variable format */
  &vformat
%mend;/**
  @file
  @brief Returns the length of a variable
  @details Uses varlen function to identify the length of a particular variable.
  Usage:

      data test;
         format str $1.  num datetime19.;
         stop;
      run;
      %put %mf_getVarLen(test,str);
      %put %mf_getVarLen(work.test,num);
      %put %mf_getVarLen(test,renegade);

  returns:

      1
      8
      NOTE: Variable renegade does not exist in test

  @param libds Two part dataset (or view) reference.
  @param var Variable name for which a length should be returned
  @returns outputs length

  @author Allan Bowe
  @version 9.2

**/

%macro mf_getVarLen(libds /* two level ds name */
      , var /* variable name from which to return the length */
)/*/STORE SOURCE*/;
  %local dsid vnum vlen rc;
  /* Open dataset */
  %let dsid = %sysfunc(open(&libds));
  %if &dsid > 0 %then %do;
    /* Get variable number */
    %let vnum = %sysfunc(varnum(&dsid, &var));
    /* Get variable format */
    %if(&vnum > 0) %then %let vlen = %sysfunc(varlen(&dsid, &vnum));
    %else %do;
       %put NOTE: Variable &var does not exist in &libds;
       %let vlen = %str( );
    %end;
  %end;
  %else %put dataset &libds not opened! (rc=&dsid);

  /* Close dataset */
  %let rc = %sysfunc(close(&dsid));
  /* Return variable format */
  &vlen
%mend;/**
  @file
  @brief Returns dataset variable list direct from header
  @details WAY faster than dictionary tables or sas views, and can
    also be called in macro logic (is pure macro). Can be used in open code,
    eg as follows:

        %put List of Variables=%mf_getvarlist(sashelp.class);

  returns:
  > List of Variables=Name Sex Age Height Weight

        %put %mf_getvarlist(sashelp.class,dlm=%str(,),quote=double);

  returns:
  > "Name","Sex","Age","Height","Weight"

  @param libds Two part dataset (or view) reference.
  @param dlm= provide a delimiter (eg comma or space) to separate the vars
  @param quote= use either DOUBLE or SINGLE to quote the results

  @version 9.2
  @author Allan Bowe

**/

%macro mf_getvarlist(libds
      ,dlm=%str( )
      ,quote=no
)/*/STORE SOURCE*/;
  /* declare local vars */
  %local outvar dsid nvars x rc dlm q var;

  /* credit Rowland Hale  - byte34 is double quote, 39 is single quote */
  %if %upcase(&quote)=DOUBLE %then %let q=%qsysfunc(byte(34));
  %else %if %upcase(&quote)=SINGLE %then %let q=%qsysfunc(byte(39));
  /* open dataset in macro */
  %let dsid=%sysfunc(open(&libds));


  %if &dsid %then %do;
    %let nvars=%sysfunc(attrn(&dsid,NVARS));
    %if &nvars>0 %then %do;
      /* add first dataset variable to global macro variable */
      %let outvar=&q.%sysfunc(varname(&dsid,1))&q.;
      /* add remaining variables with supplied delimeter */
      %do x=1 %to &nvars;
        %let var=&q.%sysfunc(varname(&dsid,&x))&q.;
        %if &var=&q&q %then %do;
          %put &sysmacroname: Empty column found in &libds!;
          %let var=&q. &q.;
        %end;
        %if &x=1 %then %let outvar=&var;
        %else %let outvar=&outvar.&dlm.&var.;
      %end;
    %end;
    %let rc=%sysfunc(close(&dsid));
  %end;
  %else %do;
    %put unable to open &libds (rc=&dsid);
    %let rc=%sysfunc(close(&dsid));
  %end;
  &outvar
%mend;/**
  @file
  @brief Returns the position of a variable in dataset (varnum attribute).
  @details Uses varnum function to determine position.

Usage:

    data work.test;
       format str $1.  num datetime19.;
       stop;
    run;
    %put %mf_getVarNum(work.test,str);
    %put %mf_getVarNum(work.test,num);
    %put %mf_getVarNum(work.test,renegade);

returns:

  > 1

  > 2

  > NOTE: Variable renegade does not exist in test

  @param libds Two part dataset (or view) reference.
  @param var Variable name for which a position should be returned

  @author Allan Bowe
  @version 9.2

**/

%macro mf_getVarNum(libds /* two level ds name */
      , var /* variable name from which to return the format */
)/*/STORE SOURCE*/;
  %local dsid vnum rc;
  /* Open dataset */
  %let dsid = %sysfunc(open(&libds));
  %if &dsid > 0 %then %do;
    /* Get variable number */
    %let vnum = %sysfunc(varnum(&dsid, &var));
    %if(&vnum <= 0) %then %do;
       %put NOTE: Variable &var does not exist in &libds;
       %let vnum = %str( );
    %end;
  %end;
  %else %put dataset &ds not opened! (rc=&dsid);

  /* Close dataset */
  %let rc = %sysfunc(close(&dsid));

  /* Return variable number */
    &vnum.

%mend;/**
  @file
  @brief Returns variable type - Character (C) or Numeric (N)
  @details
Usage:

      data test;
         length str $1.  num 8.;
         stop;
      run;
      %put %mf_getvartype(test,str);
      %put %mf_getvartype(work.test,num);



  @param libds Two part dataset (or view) reference.
  @param var the variable name to be checked
  @return output returns C or N depending on variable type.  If variable
    does not exist then a blank is returned and a note is written to the log.

  @version 9.2
  @author Allan Bowe

**/

%macro mf_getvartype(libds /* two level name */
      , var /* variable name from which to return the type */
)/*/STORE SOURCE*/;
  %local dsid vnum vtype rc;
  /* Open dataset */
  %let dsid = %sysfunc(open(&libds));
  %if &dsid. > 0 %then %do;
    /* Get variable number */
    %let vnum = %sysfunc(varnum(&dsid, &var));
    /* Get variable type (C/N) */
    %if(&vnum. > 0) %then %let vtype = %sysfunc(vartype(&dsid, &vnum.));
    %else %do;
       %put NOTE: Variable &var does not exist in &libds;
       %let vtype = %str( );
    %end;
  %end;
  %else %put dataset &libds not opened! (rc=&dsid);

  /* Close dataset */
  %let rc = %sysfunc(close(&dsid));
  /* Return variable type */
  &vtype
%mend;/**
  @file mf_isblank.sas
  @brief Checks whether a macro variable is empty (blank)
  @details Simply performs:

      %sysevalf(%superq(param)=,boolean)

  Usage:
     
     %put mf_isblank(&var);

  inspiration:  https://support.sas.com/resources/papers/proceedings09/022-2009.pdf

  @param param VALUE to be checked 

  @return output returns 1 (if blank) else 0

  @version 9.2
**/

%macro mf_isblank(param
)/*/STORE SOURCE*/;

  %sysevalf(%superq(param)=,boolean)

%mend;/**
  @file
  @brief Checks whether a path is a valid directory
  @details
  Usage:

      %let isdir=%mf_isdir(/tmp);

  With thanks and full credit to Andrea Defronzo - https://www.linkedin.com/in/andrea-defronzo-b1a47460/

  @param path full path of the file/directory to be checked

  @return output returns 1 if path is a directory, 0 if it is not

  @version 9.2
**/

%macro mf_isdir(path
)/*/STORE SOURCE*/;
	%local rc did is_directory fref_t;

	%let is_directory = 0;
	%let rc = %sysfunc(filename(fref_t, %superq(path)));
	%let did = %sysfunc(dopen(&fref_t.));
	%if &did. ^= 0 %then %do;
	   %let is_directory = 1;
	   %let rc = %sysfunc(dclose(&did.));
	%end;
	%let rc = %sysfunc(filename(fref_t));

	&is_directory

%mend;/**
  @file
  @brief Returns physical location of various SAS items
  @details Returns location of the PlatformObjectFramework tools
    Usage:

      %put %mf_loc(POF); %*location of PlatformObjectFramework tools;

  @version 9.2
  @author Allan Bowe
**/

%macro mf_loc(loc);
%let loc=%upcase(&loc);
%local root;

%if &loc=POF or &loc=PLATFORMOBJECTFRAMEWORK %then %do;
  %let root=%substr(%sysget(SASROOT),1,%index(%sysget(SASROOT),SASFoundation)-2);
  %let root=&root/SASPlatformObjectFramework/&sysver;
  %put Batch tools located at: &root;
  &root
%end;
%else %if &loc=VIYACONFIG %then %do;
  %let root=/opt/sas/viya/config;
  %put Viya Config located at: &root;
  &root
%end;

%mend;
/**
  @file
  @brief Creates a directory, including any intermediate directories
  @details Works on windows and unix environments via dcreate function.
Usage:

    %mf_mkdir(/some/path/name)


  @param dir relative or absolute pathname.  Unquoted.
  @version 9.2

**/

%macro mf_mkdir(dir
)/*/STORE SOURCE*/;

  %local lastchar child parent;

  %let lastchar = %substr(&dir, %length(&dir));
  %if (%bquote(&lastchar) eq %str(:)) %then %do;
    /* Cannot create drive mappings */
    %return;
  %end;

  %if (%bquote(&lastchar)=%str(/)) or (%bquote(&lastchar)=%str(\)) %then %do;
    /* last char is a slash */
    %if (%length(&dir) eq 1) %then %do;
      /* one single slash - root location is assumed to exist */
      %return;
    %end;
    %else %do;
      /* strip last slash */
      %let dir = %substr(&dir, 1, %length(&dir)-1);
    %end;
  %end;

  %if (%sysfunc(fileexist(%bquote(&dir))) = 0) %then %do;
    /* directory does not exist so prepare to create */
    /* first get the childmost directory */
    %let child = %scan(&dir, -1, %str(/\:));

    /*
      If child name = path name then there are no parents to create. Else
      they must be recursively scanned.
    */

    %if (%length(&dir) gt %length(&child)) %then %do;
       %let parent = %substr(&dir, 1, %length(&dir)-%length(&child));
       %mf_mkdir(&parent)
    %end;

    /*
      Now create the directory.  Complain loudly of any errors.
    */

    %let dname = %sysfunc(dcreate(&child, &parent));
    %if (%bquote(&dname) eq ) %then %do;
       %put %str(ERR)OR: could not create &parent + &child;
       %abort cancel;
    %end;
    %else %do;
       %put Directory created:  &dir;
    %end;
  %end;
  /* exit quietly if directory did exist.*/
%mend;
/**
  @file mf_mval.sas
  @brief Returns a macro variable value if the variable exists
  @details Use this macro to avoid repetitive use of `%if %symexist(MACVAR) %then`
  type logic.  
  Usage:

      %if %mf_mval(maynotexist)=itdid %then %do;

  @version 9.2
  @author Allan Bowe
**/

%macro mf_mval(var);
  %if %symexist(&var) %then %do;
    %superq(&var)
  %end;
%mend;
/**
  @file
  @brief Returns number of logical (undeleted) observations.
  @details Beware - will not work on external database tables!
  Is just a convenience macro for calling <code> %mf_getattrn()</code>.

        %put Number of observations=%mf_nobs(sashelp.class);

  <h4> Dependencies </h4>
  @li mf_getattrn.sas

  @param libds library.dataset

  @return output returns result of the attrn value supplied, or log message
    if error.


  @version 9.2
  @author Allan Bowe

**/

%macro mf_nobs(libds
)/*/STORE SOURCE*/;
  %mf_getattrn(&libds,NLOBS)
%mend;/**
  @file mf_trimstr.sas
  @brief Removes character(s) from the end, if they exist
  @details If the designated characters exist at the end of the string, they 
  are removed

        %put %mf_trimstr(/blah/,/); * /blah;
        %put %mf_trimstr(/blah/,h); * /blah/;
        %put %mf_trimstr(/blah/,h/);* /bla;

  <h4> Dependencies </h4>


  @param basestr The string to be modified
  @param trimstr The string to be removed from the end of `basestr`, if it exists

  @return output returns result with the value of `trimstr` removed from the end


  @version 9.2
  @author Allan Bowe

**/

%macro mf_trimstr(basestr,trimstr);
%local baselen trimlen trimval;

/* return if basestr is shorter than trimstr (or 0) */
%let baselen=%length(%superq(basestr));
%let trimlen=%length(%superq(trimstr));
%if &baselen < &trimlen or &baselen=0 %then %return;

/* obtain the characters from the end of basestr */
%let trimval=%qsubstr(%superq(basestr)
  ,%length(%superq(basestr))-&trimlen+1
  ,&trimlen);

/* compare and if matching, chop it off! */
%if %superq(basestr)=%superq(trimstr) %then %do;
  %return;
%end;
%else %if %superq(trimval)=%superq(trimstr) %then %do;
  %qsubstr(%superq(basestr),1,%length(%superq(basestr))-&trimlen)
%end;
%else %do;
  &basestr
%end;

%mend;/**
  @file
  @brief Creates a Unique ID based on system time in a friendly format
  @details format = YYYYMMDD_HHMMSSmmm_<sysjobid>_<3randomDigits>

        %put %mf_uid();

  @version 9.2
  @author Allan Bowe

**/

%macro mf_uid(
)/*/STORE SOURCE*/;
  %local today now;
  %let today=%sysfunc(today(),yymmddn8.);
  %let now=%sysfunc(compress(%sysfunc(time(),time12.3),:.));

  &today._&now._&sysjobid._%sysevalf(%sysfunc(ranuni(0))*999,CEIL)

%mend;/**
  @file
  @brief Checks if a set of macro variables exist / contain values.
  @details Writes ERROR to log if abortType is SOFT, else will call %mf_abort.
  Usage:

      %let var1=x;
      %let var2=y;
      %put %mf_verifymacvars(var1 var2);

  Returns:
  > 1

  <h4> Dependencies </h4>
  @li mf_abort.sas

  @param verifyvars space separated list of macro variable names
  @param makeupcase= set to YES to convert all variable VALUES to
    uppercase.
  @param mAbort= Abort Type.  Default is SOFT (writes err to log).
    Set to any other value to call mf_abort (which can be configured to abort in
    various fashions according to context).

  @warning will not be able to verify the following variables due to
    naming clash!
      - verifyVars
      - verifyVar
      - verifyIterator
      - makeUpcase

  @version 9.2
  @author Allan Bowe

**/


%macro mf_verifymacvars(
     verifyVars  /* list of macro variable NAMES */
    ,makeUpcase=NO  /* set to YES to make all the variable VALUES uppercase */
    ,mAbort=SOFT
)/*/STORE SOURCE*/;

  %local verifyIterator verifyVar abortmsg;
  %do verifyIterator=1 %to %sysfunc(countw(&verifyVars,%str( )));
    %let verifyVar=%qscan(&verifyVars,&verifyIterator,%str( ));
    %if not %symexist(&verifyvar) %then %do;
      %let abortmsg= Variable &verifyVar is MISSING;
      %goto exit_err;
    %end;
    %if %length(%trim(&&&verifyVar))=0 %then %do;
      %let abortmsg= Variable &verifyVar is EMPTY;
      %goto exit_err;
    %end;
    %if &makeupcase=YES %then %do;
      %let &verifyVar=%upcase(&&&verifyvar);
    %end;
  %end;

  %goto exit_success;
  %exit_err:
    %if &mAbort=SOFT %then %put %str(ERR)OR: &abortmsg;
    %else %mf_abort(mac=mf_verifymacvars,type=&mabort,msg=&abortmsg);
  %exit_success:

%mend;
/**
  @file
  @brief Returns words that are in string 1 but not in string 2
  @details  Compares two space separated strings and returns the words that are
  in the first but not in the second.
  Usage:

      %let x= %mf_wordsInStr1ButNotStr2(
         Str1=blah sss blaaah brah bram boo
        ,Str2=   blah blaaah brah ssss
      );

  returns:
  > sss bram boo

  @param str1= string containing words to extract
  @param str2= used to compare with the extract string

  @warning CASE SENSITIVE!

  @version 9.2
  @author Allan Bowe

**/

%macro mf_wordsInStr1ButNotStr2(
    Str1= /* string containing words to extract */
   ,Str2= /* used to compare with the extract string */
)/*/STORE SOURCE*/;

%local count_base count_extr i i2 extr_word base_word match outvar;
%if %length(&str1)=0 or %length(&str2)=0 %then %do;
  %put WARNING: empty string provided!;
  %put base string (str1)= &str1;
  %put compare string (str2) = &str2;
  %return;
%end;
%let count_base=%sysfunc(countw(&Str2));
%let count_extr=%sysfunc(countw(&Str1));

%do i=1 %to &count_extr;
  %let extr_word=%scan(&Str1,&i,%str( ));
  %let match=0;
  %do i2=1 %to &count_base;
    %let base_word=%scan(&Str2,&i2,%str( ));
    %if &extr_word=&base_word %then %let match=1;
  %end;
  %if &match=0 %then %let outvar=&outvar &extr_word;
%end;

  &outvar

%mend;

/**
  @file
  @brief abort gracefully according to context
  @details Configures an abort mechanism according to site specific policies or
    the particulars of an environment.  For instance, can stream custom
    results back to the client in an STP Web App context, or completely stop
    in the case of a batch run.

  Using SAS Abort Cancel mechanisms can cause hung sessions in some Stored Process
  environments.  This macro takes a unique approach - we set the SAS syscc to 0,
  run `stpsrvset('program error', 0)` (if SAS 9) and then - we open a macro
  but don't close it!  This provides a graceful abort for SAS web services in all
  web enabled environments.

  @param mac= to contain the name of the calling macro
  @param msg= message to be returned
  @param iftrue= supply a condition under which the macro should be executed.

  @version 9.4M3
  @author Allan Bowe
  @cond
**/

%macro mp_abort(mac=mp_abort.sas, type=, msg=, iftrue=%str(1=1)
)/*/STORE SOURCE*/;

  %if not(%eval(%unquote(&iftrue))) %then %return;

  %put NOTE: ///  mp_abort macro executing //;
  %if %length(&mac)>0 %then %put NOTE- called by &mac;
  %put NOTE - &msg;

  /* Stored Process Server web app context */
  %if %symexist(_metaperson)
  or (%symexist(SYSPROCESSNAME) and "&SYSPROCESSNAME"="Compute Server" )
  %then %do;
    options obs=max replace nosyntaxcheck mprint;
    /* extract log errs / warns, if exist */
    %local logloc logline;
    %global logmsg; /* capture global messages */
    %if %symexist(SYSPRINTTOLOG) %then %let logloc=&SYSPRINTTOLOG;
    %else %let logloc=%qsysfunc(getoption(LOG));
    proc printto log=log;run;
    %if %length(&logloc)>0 %then %do;
      %let logline=0;
      data _null_;
        infile &logloc lrecl=5000;
        input; putlog _infile_;
        i=1;
        retain logonce 0;
        if (_infile_=:"%str(WARN)ING" or _infile_=:"%str(ERR)OR") and logonce=0 then do;
          call symputx('logline',_n_);
          logonce+1;
        end;
      run;
      /* capture log including lines BEFORE the err */
      %if &logline>0 %then %do;
        data _null_;
          infile &logloc lrecl=5000;
          input;
          i=1;
          stoploop=0;
          if _n_ ge &logline-5 and stoploop=0 then do until (i>12);
            call symputx('logmsg',catx('\n',symget('logmsg'),_infile_));
            input;
            i+1;
            stoploop=1;
          end;
          if stoploop=1 then stop;
        run;
      %end;
    %end;

    %if %symexist(SYS_JES_JOB_URI) %then %do;
      /* setup webout */
      OPTIONS NOBOMFILE;
      %if "X&SYS_JES_JOB_URI.X"="XX" %then %do;
          filename _webout temp lrecl=999999 mod;
      %end;
      %else %do;
        filename _webout filesrvc parenturi="&SYS_JES_JOB_URI"
          name="_webout.json" lrecl=999999 mod;
      %end;
    %end;

    /* send response in SASjs JSON format */
    data _null_;
      file _webout mod lrecl=32000;
      length msg $32767 debug $8;
      sasdatetime=datetime();
      msg=cats(symget('msg'),'\n\nLog Extract:\n',symget('logmsg'));
      /* escape the quotes */
      msg=tranwrd(msg,'"','\"');
      /* ditch the CRLFs as chrome complains */
      msg=compress(msg,,'kw');
      /* quote without quoting the quotes (which are escaped instead) */
      msg=cats('"',msg,'"');
      if symexist('_debug') then debug=quote(trim(symget('_debug')));
      else debug='""';
      if debug ge '"131"' then put '>>weboutBEGIN<<';
      put '{"START_DTTM" : "' "%sysfunc(datetime(),datetime20.3)" '"';
      put ',"sasjsAbort" : [{';
      put ' "MSG":' msg ;
      put ' ,"MAC": "' "&mac" '"}]';
      put ",""SYSUSERID"" : ""&sysuserid"" ";
      put ',"_DEBUG":' debug ;
      if symexist('_metauser') then do;
        _METAUSER=quote(trim(symget('_METAUSER')));
        put ",""_METAUSER"": " _METAUSER;
        _METAPERSON=quote(trim(symget('_METAPERSON')));
        put ',"_METAPERSON": ' _METAPERSON;
      end;
      if symexist('SYS_JES_JOB_URI') then do;
        SYS_JES_JOB_URI=quote(trim(symget('SYS_JES_JOB_URI')));
        put ',"SYS_JES_JOB_URI": ' SYS_JES_JOB_URI;
      end;
      _PROGRAM=quote(trim(resolve(symget('_PROGRAM'))));
      put ',"_PROGRAM" : ' _PROGRAM ;
      put ",""SYSCC"" : ""&syscc"" ";
      put ",""SYSERRORTEXT"" : ""&syserrortext"" ";
      put ",""SYSJOBID"" : ""&sysjobid"" ";
      put ",""SYSWARNINGTEXT"" : ""&syswarningtext"" ";
      put ',"END_DTTM" : "' "%sysfunc(datetime(),datetime20.3)" '" ';
      put "}" @;
      if debug ge '"131"' then put '>>weboutEND<<';
    run;

    %let syscc=0;
    %if %symexist(_metaport) %then %do;
      data _null_;
        if symexist('sysprocessmode')
         then if symget("sysprocessmode")="SAS Stored Process Server"
          then rc=stpsrvset('program error', 0);
      run;
    %end;
    /**
     * endsas is reliable but kills some deployments.
     * Abort variants are ungraceful (non zero return code)
     * This approach lets SAS run silently until the end :-)
     */
    %put _all_;
    filename skip temp;
    data _null_;
      file skip;
      put '%macro skip(); %macro skippy();';
    run;
    %inc skip;
  %end;
  %else %do;
    %put _all_;
    %abort cancel;
  %end;
%mend;

/** @endcond *//**
  @file
  @brief Copy any file using binary input / output streams
  @details Reads in a file byte by byte and writes it back out.  Is an
    os-independent method to copy files.  In case of naming collision, the
    default filerefs can be modified.
    Based on http://stackoverflow.com/questions/13046116/using-sas-to-copy-a-text-file

        %mp_binarycopy(inloc="/home/me/blah.txt", outref=_webout)

  @param inloc full, quoted "path/and/filename.ext" of the object to be copied
  @param outloc full, quoted "path/and/filename.ext" of object to be created
  @param inref can override default input fileref to avoid naming clash
  @param outref an override default output fileref to avoid naming clash
  @returns nothing

  @version 9.2

**/

%macro mp_binarycopy(
     inloc=           /* full path and filename of the object to be copied */
    ,outloc=          /* full path and filename of object to be created */
    ,inref=____in   /* override default to use own filerefs */
    ,outref=____out /* override default to use own filerefs */
)/*/STORE SOURCE*/;
   /* these IN and OUT filerefs can point to anything */
  %if &inref = ____in %then %do;
    filename &inref &inloc lrecl=1048576 ;
  %end;
  %if &outref=____out %then %do;
    filename &outref &outloc lrecl=1048576 ;
  %end;

   /* copy the file byte-for-byte  */
   data _null_;
     length filein 8 fileid 8;
     filein = fopen("&inref",'I',1,'B');
     fileid = fopen("&outref",'O',1,'B');
     rec = '20'x;
     do while(fread(filein)=0);
        rc = fget(filein,rec,1);
        rc = fput(fileid, rec);
        rc =fwrite(fileid);
     end;
     rc = fclose(filein);
     rc = fclose(fileid);
   run;
  %if &inref = ____in %then %do;
    filename &inref clear;
  %end;
  %if &outref=____out %then %do;
    filename &outref clear;
  %end;
%mend;/**
  @file mp_cleancsv.sas
  @brief Fixes embedded cr / lf / crlf in CSV
  @details CSVs will sometimes contain lf or crlf within quotes (eg when
    saved by excel).  When the termstr is ALSO lf or crlf that can be tricky
    to process using SAS defaults.
    This macro converts any csv to follow the convention of a windows excel file,
    applying CRLF line endings and converting embedded cr and crlf to lf.

  usage:

      fileref mycsv "/path/your/csv";
      %mp_cleancsv(in=mycsv,out=/path/new.csv)

  @param in= provide path or fileref to input csv
  @param out= output path or fileref to output csv
  @param qchar= quote char - hex code 22 is the double quote.

  @version 9.2
  @author Allan Bowe
  @cond
**/

%macro mp_cleancsv(in=NOTPROVIDED,out=NOTPROVIDED,qchar='22'x);
%if "&in"="NOTPROVIDED" or "&out"="NOTPROVIDED" %then %do;
  %put %str(ERR)OR: Please provide valid input (&in) and output (&out) locations;
  %return;
%end;

/* presence of a period(.) indicates a physical location */
%if %index(&in,.) %then %let in="&in";
%if %index(&out,.) %then %let out="&out";

/**
 * convert all cr and crlf within quotes to lf
 * convert all other cr or lf to crlf
 */
  data _null_;
    infile &in recfm=n ;
    file &out recfm=n;
    retain isq iscrlf 0 qchar &qchar;
    input inchar $char1. ;
    if inchar=qchar then isq = mod(isq+1,2);
    if isq then do;
      /* inside a quote change cr and crlf to lf */
      if inchar='0D'x then do;
        put '0A'x;
        input inchar $char1.;
        if inchar ne '0A'x then do;
          put inchar $char1.;
          if inchar=qchar then isq = mod(isq+1,2);
        end;
      end;
      else put inchar $char1.;
    end;
    else do;
      /* outside a quote, change cr and lf to crlf */
      if inchar='0D'x then do;
        put '0D0A'x;
        input inchar $char1.;
        if inchar ne '0A'x then do;
          put inchar $char1.;
          if inchar=qchar then isq = mod(isq+1,2);
        end;
      end;
      else if inchar='0A'x then put '0D0A'x;
      else put inchar $char1.;
    end;
  run;
%mend;
/** @endcond *//**
  @file mp_createconstraints.sas
  @brief Creates constraints
  @details Takes the output from mp_getconstraints.sas as input

        proc sql;
        create table work.example(
          TX_FROM float format=datetime19.,
          DD_TYPE char(16),
          DD_SOURCE char(2048),
          DD_SHORTDESC char(256),
          constraint pk primary key(tx_from, dd_type,dd_source),
          constraint unq unique(tx_from, dd_type),
          constraint nnn not null(DD_SHORTDESC)
        );
      
      %mp_getconstraints(lib=work,ds=example,outds=work.constraints)
      %mp_deleteconstraints(inds=work.constraints,outds=dropped,execute=YES)
      %mp_createconstraints(inds=work.constraints,outds=created,execute=YES)

  @param inds= The input table containing the constraint info
  @param outds= a table containing the create statements (create_statement column)
  @param execute= `YES|NO` - default is NO. To actually create, use YES.

  <h4> Dependencies </h4>

  @version 9.2
  @author Allan Bowe

**/

%macro mp_createconstraints(inds=mp_getconstraints
  ,outds=mp_createconstraints
  ,execute=NO
)/*/STORE SOURCE*/;

proc sort data=&inds out=&outds;
  by libref table_name constraint_name;
run;

data &outds;
  set &outds;
  by libref table_name constraint_name;
  length create_statement $500;
  if _n_=1 and "&execute"="YES" then call execute('proc sql;');
  if first.constraint_name then do;
    if constraint_type='PRIMARY' then type='PRIMARY KEY';
    else type=constraint_type;
    create_statement=catx(" ","alter table",libref,".",table_name
      ,"add constraint",constraint_name,type,"(");
    if last.constraint_name then 
      create_statement=cats(create_statement,column_name,");");
    else create_statement=cats(create_statement,column_name,",");
    if "&execute"="YES" then call execute(create_statement);
  end;
  else if last.constraint_name then do;
    create_statement=cats(column_name,");");
    if "&execute"="YES" then call execute(create_statement);
  end;
  else do;
    create_statement=cats(column_name,",");
    if "&execute"="YES" then call execute(create_statement);
  end;
  output;
run;

%mend;/**
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
    %mp_createwebservice(path=/Public/app/common,name=appInit,code=ft15f001,replace=YES)

  <h4> Dependencies </h4>
  @li mf_getplatform.sas
  @li mm_createwebservice.sas
  @li mv_createwebservice.sas

  @param path= The full folder path where the service will be created
  @param name= Service name.  Avoid spaces.
  @param desc= The description of the service (optional)
  @param precode= Space separated list of filerefs, pointing to the code that
    needs to be attached to the beginning of the service (optional)
  @param code= Space seperated fileref(s) of the actual code to be added
  @param replace= select YES to replace any existing service in that location


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
%else %do;
  %if "&path"="HOME" %then %let path=/User Folders/&sysuserid/My Folder;
  %mm_createwebservice(path=&path
    ,name=&name
    ,code=&code
    ,precode=&precode
    ,desc=&desc
    ,replace=&replace
  )
%end;

%mend;
/**
  @file mp_csv2ds.sas
  @brief Efficient import of arbitrary CSV using a dataset as template
  @details Used to import relevant columns from a large CSV using
  a dataset to provide the types and lengths.  Assumes that a header
  row is provided, and datarows start on line 2.  Extra columns in
  both the CSV and base dataset are ignored.

  Usage:

      filename mycsv temp;
      data _null_;
        file mycsv;
        put 'name,age,nickname';
        put 'John,48,Jonny';
        put 'Jennifer,23,Jen';
      run;

      %mp_csv2ds(inref=mycsv,outds=myds,baseds=sashelp.class)


  @param inref= fileref to the CSV
  @param outds= output ds (lib.ds format)
  @param view= Set to YES or NO to determine whether the output should be
    a view or not.  Default is NO (not a view).
  @param baseds= Template dataset on which to create the input statement.
    Is used to determine types, lengths, and any informats.

  @version 9.2
  @author Allan Bowe

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mf_existds.sas

**/

%macro mp_csv2ds(inref=0,outds=0,baseds=0,view=NO);

%mp_abort(iftrue=( &inref=0 )
  ,mac=&sysmacroname
  ,msg=%str(the INREF variable must be provided)
)
%mp_abort(iftrue=( %superq(outds)=0 )
  ,mac=&sysmacroname
  ,msg=%str(the OUTDS variable must be provided)
)
%mp_abort(iftrue=( &baseds=0 )
  ,mac=&sysmacroname
  ,msg=%str(the BASEDS variable must be provided)
)
%mp_abort(iftrue=( &baseds=0 )
  ,mac=&sysmacroname
  ,msg=%str(the BASEDS variable must be provided)
)
%mp_abort(iftrue=( %mf_existds(&baseds)=0 )
  ,mac=&sysmacroname
  ,msg=%str(the BASEDS dataset (&baseds) needs to be assigned, and to exist)
)

/* count rows */
%local hasheader; %let hasheader=0;
data _null_;
  if _N_ > 1 then do;
     call symputx('hasheader',1,'l');
     stop;
  end;
  infile &inref;
  input;
run;
%mp_abort(iftrue=( &hasheader=0 )
  ,mac=&sysmacroname
  ,msg=%str(No header row in &inref)
)

/* get the variables in the CSV */
data _data_;
  infile &inref;
  input;
  length name $32;
  do i=1 to countc(_infile_,',')+1;
    name=upcase(scan(_infile_,i,','));
    output;
  end;
  stop;
run;
%local csv_vars;%let csv_vars=&syslast;

/* get the variables in the dataset */
proc contents noprint data=&baseds
  out=_data_ (keep=name type length format: informat);
run;
%local base_vars; %let base_vars=&syslast;

proc sql undo_policy=none;
create table &csv_vars as
  select a.*
    ,b.type
    ,b.length
    ,b.format
    ,b.formatd
    ,b.formatl
    ,b.informat
  from &csv_vars a
  left join &base_vars b
  on a.name=upcase(b.name)
  order by i;

/* prepare the input statement */
%local instat dropvars;
data _null_;
  set &syslast end=last;
  length in dropvars $32767;
  retain in dropvars;
  if missing(type) then do;
    informat='$1.';
    dropvars=catx(' ',dropvars,name);
  end;
  else if missing(informat) then do;
    if type=1 then informat='best.';
    else informat=cats('$',length,'.');
  end;
  else informat=cats(informat,'.');
  in=catx(' ',in,name,':',informat);
  if last then do;
    call symputx('instat',in,'l');
    call symputx('dropvars',dropvars,'l');
  end;
run;

/* import the CSV */
data &outds
  %if %upcase(&view)=YES %then %do;
   /view=&outds
  %end;
  ;
  infile &inref dsd firstobs=2;
  input &instat;
  %if %length(&dropvars)>0 %then %do;
    drop &dropvars;
  %end;
run;

%mend;/**
  @file mp_deleteconstraints.sas
  @brief Delete constraionts
  @details Takes the output from mp_getconstraints.sas as input

        proc sql;
        create table work.example(
          TX_FROM float format=datetime19.,
          DD_TYPE char(16),
          DD_SOURCE char(2048),
          DD_SHORTDESC char(256),
          constraint pk primary key(tx_from, dd_type,dd_source),
          constraint unq unique(tx_from, dd_type),
          constraint nnn not null(DD_SHORTDESC)
        );
      
      %mp_getconstraints(lib=work,ds=example,outds=work.constraints)
      %mp_deleteconstraints(inds=work.constraints,outds=dropped,execute=YES)

  @param inds= The input table containing the constraint info
  @param outds= a table containing the drop statements (drop_statement column)
  @param execute= `YES|NO` - default is NO. To actually drop, use YES.


  @version 9.2
  @author Allan Bowe

**/

%macro mp_deleteconstraints(inds=mp_getconstraints
  ,outds=mp_deleteconstraints
  ,execute=NO
)/*/STORE SOURCE*/;

proc sort data=&inds out=&outds;
  by libref table_name constraint_name;
run;

data &outds;
  set &outds;
  by libref table_name constraint_name;
  length drop_statement $500;
  if _n_=1 and "&execute"="YES" then call execute('proc sql;');
  if first.constraint_name then do;
    drop_statement=catx(" ","alter table",libref,".",table_name
      ,"drop constraint",constraint_name,";");
    output;
    if "&execute"="YES" then call execute(drop_statement);
  end;
run;

%mend;/**
  @file
  @brief Returns all files and subdirectories within a specified parent
  @details When used with getattrs=NO, is not OS specific (uses dopen / dread).

  If getattrs=YES then the doptname / foptname functions are used to scan all
  properties - any characters that are not valid in a SAS name (v7) are simply
  stripped, and the table is transposed so theat each property is a column
  and there is one file per row.  An attempt is made to get all properties
  whether a file or folder, but some files/folders cannot be accessed, and so
  not all properties can / will be populated.

  Credit for the rename approach:
  https://communities.sas.com/t5/SAS-Programming/SAS-Function-to-convert-string-to-Legal-SAS-Name/m-p/27375/highlight/true#M5003


  usage:

      %mp_dirlist(path=/some/location,outds=myTable)

      %mp_dirlist(outds=cwdfileprops, getattrs=YES)

      %mp_dirlist(fref=MYFREF)

  @warning In a Unix environment, the existence of a named pipe will cause this
  macro to hang.  Therefore this tool should be used with caution in a SAS 9 web
  application, as it can use up all available multibridge sessions if requests
  are resubmitted.
  If anyone finds a way to positively identify a named pipe using SAS (without
  X CMD) do please raise an issue!


  @param path= for which to return contents
  @param fref= Provide a DISK engine fileref as an alternative to PATH
  @param outds= the output dataset to create
  @param getattrs= YES/NO (default=NO).  Uses doptname and foptname to return
  all attributes for each file / folder.


  @returns outds contains the following variables:
   - directory (containing folder)
   - file_or_folder (file / folder)
   - filepath (path/to/file.name)
   - filename (just the file name)
   - ext (.extension)
   - msg (system message if any issues)
   - OS SPECIFIC variables, if <code>getattrs=</code> is used.

  @version 9.2
  @author Allan Bowe
**/

%macro mp_dirlist(path=%sysfunc(pathname(work))
    , fref=0
    , outds=work.mp_dirlist
    , getattrs=NO
)/*/STORE SOURCE*/;
%let getattrs=%upcase(&getattrs)XX;

data &outds (compress=no keep=file_or_folder filepath filename ext msg directory);
  length directory filepath $500 fref fref2 $8 file_or_folder $6 filename $80 ext $20 msg $200;
  %if &fref=0 %then %do;
    rc = filename(fref, "&path");
  %end;
  %else %do;
    fref="&fref";
    rc=0;
  %end;
  if rc = 0 then do;
     did = dopen(fref);
     directory=dinfo(did,'Directory');
     if did=0 then do;
        putlog "NOTE: This directory is empty - " directory;
        msg=sysmsg();
        put _all_;
        stop;
     end;
     rc = filename(fref);
  end;
  else do;
    msg=sysmsg();
    put _all_;
    stop;
  end;
  dnum = dnum(did);
  do i = 1 to dnum;
    filename = dread(did, i);
    filepath=cats(directory,'/',filename);
    rc = filename(fref2,filepath);
    midd=dopen(fref2);
    dmsg=sysmsg();
    if did > 0 then file_or_folder='folder';
    rc=dclose(midd);
    midf=fopen(fref2);
    fmsg=sysmsg();
    if midf > 0 then file_or_folder='file';
    rc=fclose(midf);

    if index(fmsg,'File is in use') or index(dmsg,'is not a directory')
      then file_or_folder='file';
    else if index(fmsg, 'Insufficient authorization') then file_or_folder='file';
    else if file_or_folder='' then file_or_folder='locked';

    if file_or_folder='file' then do;
      ext = prxchange('s/.*\.{1,1}(.*)/$1/', 1, filename);
      if filename = ext then ext = ' ';
    end;
    else do;
      ext='';
      file_or_folder='folder';
    end;
    output;
  end;
  rc = dclose(did);
  stop;
run;

%if %substr(&getattrs,1,1)=Y %then %do;
  data &outds;
    set &outds;
    length infoname infoval $60 fref $8;
    rc=filename(fref,filepath);
    drop rc infoname fid i close fref;
    if file_or_folder='file' then do;
      fid=fopen(fref);
      if fid le 0 then do;
        msg=sysmsg();
        putlog "Could not open file:" filepath fid= ;
        sasname='_MCNOTVALID_';
        output;
      end;
      else do i=1 to foptnum(fid);
        infoname=foptname(fid,i);
        infoval=finfo(fid,infoname);
        sasname=compress(infoname, '_', 'adik');
        if anydigit(sasname)=1 then sasname=substr(sasname,anyalpha(sasname));
        if upcase(sasname) ne 'FILENAME' then output;
      end;
      close=fclose(fid);
    end;
    else do;
      fid=dopen(fref);
      if fid le 0 then do;
        msg=sysmsg();
        putlog "Could not open folder:" filepath fid= ;
        sasname='_MCNOTVALID_';
        output;
      end;
      else do i=1 to doptnum(fid);
        infoname=doptname(fid,i);
        infoval=dinfo(fid,infoname);
        sasname=compress(infoname, '_', 'adik');
        if anydigit(sasname)=1 then sasname=substr(sasname,anyalpha(sasname));
        if upcase(sasname) ne 'FILENAME' then output;
      end;
      close=dclose(fid);
    end;
  run;
  proc sort;
    by filepath sasname;
  proc transpose data=&outds out=&outds(drop=_:);
    id sasname;
    var infoval;
    by filepath file_or_folder filename ext ;
  run;
%end;
%mend;/**
  @file
  @brief Creates a dataset containing distinct _formatted_ values
  @details If no format is supplied, then the original value is used instead.
    There is also a dependency on other macros within the Macro Core library.
    Usage:

        %mp_distinctfmtvalues(libds=sashelp.class,var=age,outvar=age,outds=test)

  @param libds input dataset
  @param var variable to get distinct values for
  @param outvar variable to create.  Default:  `formatted_value`
  @param outds dataset to create.  Default:  work.mp_distinctfmtvalues
  @param varlen length of variable to create (default 200)

  @version 9.2
  @author Allan Bowe

**/

%macro mp_distinctfmtvalues(
     libds=
    ,var=
    ,outvar=formatted_value
    ,outds=work.mp_distinctfmtvalues
    ,varlen=2000
)/*/STORE SOURCE*/;

  %local fmt vtype;
  %let fmt=%mf_getvarformat(&libds,&var);
  %let vtype=%mf_getvartype(&libds,&var);

  proc sql;
  create table &outds as
    select distinct
    %if &vtype=C & %trim(&fmt)=%str() %then %do;
       &var
    %end;
    %else %if &vtype=C %then %do;
      put(&var,&fmt)
    %end;
    %else %if %trim(&fmt)=%str() %then %do;
        put(&var,32.)
    %end;
    %else %do;
      put(&var,&fmt)
    %end;
       as &outvar length=&varlen
    from &libds;
%mend;/**
  @file
  @brief Drops tables / views (if they exist) without warnings in the log
  @details
  Example usage:

      proc sql;
      create table data1 as select * from sashelp.class;
      create view view2 as select * from sashelp.class;
      %mp_dropmembers(list=data1 view2)

  <h4> Dependencies </h4>
  @li mf_isblank.sas


  @param list space separated list of datasets / views
  @param libref= can only drop from a single library at a time

  @version 9.2
  @author Allan Bowe

**/

%macro mp_dropmembers(
     list /* space separated list of datasets / views */
    ,libref=WORK  /* can only drop from a single library at a time */
)/*/STORE SOURCE*/;

  %if %mf_isblank(&list) %then %do;
    %put NOTE: nothing to drop!;
    %return;
  %end;

  proc datasets lib=&libref nolist;
    delete &list;
    delete &list /mtype=view;
  run;
%mend;/**
  @file
  @brief Create a CARDS file from a SAS dataset.
  @details Uses dataset attributes to convert all data into datalines.
    Running the generated file will rebuild the original dataset.
  usage:

      %mp_ds2cards(base_ds=sashelp.class
        , cards_file= "C:\temp\class.sas"
        , maxobs=5)

    stuff to add
     - labelling the dataset
     - explicity setting a unix LF
     - constraints / indexes etc

  @param base_ds= Should be two level - eg work.blah.  This is the table that
                   is converted to a cards file.
  @param tgt_ds= Table that the generated cards file would create. Optional -
                  if omitted, will be same as BASE_DS.
  @param cards_file= Location in which to write the (.sas) cards file
  @param maxobs= to limit output to the first <code>maxobs</code> observations
  @param showlog= whether to show generated cards file in the SAS log (YES/NO)
  @param outencoding= provide encoding value for file statement (eg utf-8)


  @version 9.2
  @author Allan Bowe
**/

%macro mp_ds2cards(base_ds=, tgt_ds=
    ,cards_file="%sysfunc(pathname(work))/cardgen.sas"
    ,maxobs=max
    ,random_sample=NO
    ,showlog=YES
    ,outencoding=
)/*/STORE SOURCE*/;
%local i setds nvars;

%if not %sysfunc(exist(&base_ds)) %then %do;
   %put WARNING:  &base_ds does not exist;
   %return;
%end;

%if %index(&base_ds,.)=0 %then %let base_ds=WORK.&base_ds;
%if (&tgt_ds = ) %then %let tgt_ds=&base_ds;
%if %index(&tgt_ds,.)=0 %then %let tgt_ds=WORK.%scan(&base_ds,2,.);
%if ("&outencoding" ne "") %then %let outencoding=encoding="&outencoding";

/* get varcount */
%let nvars=0;
proc sql noprint;
select count(*) into: nvars from dictionary.columns
  where libname="%scan(%upcase(&base_ds),1)"
    and memname="%scan(%upcase(&base_ds),2)";
%if &nvars=0 %then %do;
  %put WARNING:  Dataset &base_ds has no variables!  It will not be converted.;
  %return;
%end;

/* get indexes */
proc sort data=sashelp.vindex
    (where=(upcase(libname)="%scan(%upcase(&base_ds),1)"
       and upcase(memname)="%scan(%upcase(&base_ds),2)"))
	out=_data_;
  by indxname indxpos;
run;

%local indexes;
data _null_;
  set &syslast end=last;
  if _n_=1 then call symputx('indexes','(index=(','l');
  by indxname indxpos;
  length vars $32767 nom uni $8;
  retain vars;
  if first.indxname then do;
    idxcnt+1;
    nom='';
    uni='';
  	vars=name;
  end;
  else vars=catx(' ',vars,name);
  if last.indxname then do;
    if nomiss='yes' then nom='/nomiss';
    if unique='yes' then uni='/unique';
    call symputx('indexes'
      ,catx(' ',symget('indexes'),indxname,'=(',vars,')',nom,uni)
      ,'l');
  end;
  if last then call symputx('indexes',cats(symget('indexes'),'))'),'l');
run;


data;run;
%let setds=&syslast;
proc sql
%if %datatyp(&maxobs)=NUMERIC %then %do;
  outobs=&maxobs;
%end;
  ;
  create table &setds as select * from &base_ds
%if &random_sample=YES %then %do;
  order by ranuni(42)
%end;
  ;
reset outobs=max;
create table datalines1 as
   select name,type,length,varnum,format,label from dictionary.columns
   where libname="%upcase(%scan(&base_ds,1))"
    and memname="%upcase(%scan(&base_ds,2))";

/**
  Due to long decimals cannot use best. format
  So - use bestd. format and then use character functions to strip trailing
    zeros, if NOT an integer!!
  resolved code = ifc(int(VARIABLE)=VARIABLE
    ,put(VARIABLE,best32.)
    ,substrn(put(VARIABLE,bestd32.),1
    ,findc(put(VARIABLE,bestd32.),'0','TBK')));
**/

data datalines_2;
  format dataline $32000.;
 set datalines1 (where=(upcase(name) not in
    ('PROCESSED_DTTM','VALID_FROM_DTTM','VALID_TO_DTTM')));
  if type='num' then dataline=
    cats('ifc(int(',name,')=',name,'
      ,put(',name,',best32.-l)
      ,substrn(put(',name,',bestd32.-l),1
      ,findc(put(',name,',bestd32.-l),"0","TBK")))');
  else dataline=name;
run;

proc sql noprint;
select dataline into: datalines separated by ',' from datalines_2;

%local
   process_dttm_flg
   valid_from_dttm_flg
   valid_to_dttm_flg
;
%let process_dttm_flg = N;
%let valid_from_dttm_flg = N;
%let valid_to_dttm_flg = N;
data _null_;
  set datalines1 ;
/* build attrib statement */
  if type='char' then type2='$';
  if strip(format) ne '' then format2=cats('format=',format);
  if strip(label) ne '' then label2=cats('label=',quote(trim(label)));
  str1=catx(' ',(put(name,$33.)||'length=')
        ,put(cats(type2,length),$7.)||format2,label2);


/* Build input statement */
  if type='char' then type3=':$char.';
  str2=put(name,$33.)||type3;


  if(upcase(name) = "PROCESSED_DTTM") then
    call symputx("process_dttm_flg", "Y", "L");
  if(upcase(name) = "VALID_FROM_DTTM") then
    call symputx("valid_from_dttm_flg", "Y", "L");
  if(upcase(name) = "VALID_TO_DTTM") then
    call symputx("valid_to_dttm_flg", "Y", "L");


  call symputx(cats("attrib_stmt_", put(_N_, 8.)), str1, "L");
  call symputx(cats("input_stmt_", put(_N_, 8.))
    , ifc(upcase(name) not in
      ('PROCESSED_DTTM','VALID_FROM_DTTM','VALID_TO_DTTM'), str2, ""), "L");
run;

data _null_;
  file &cards_file. &outencoding lrecl=32767 termstr=nl;
  length __attrib $32767;
  if _n_=1 then do;
    put '/*******************************************************************';
    put " Datalines for %upcase(%scan(&base_ds,2)) dataset ";
    put " Generated by %nrstr(%%)mp_ds2cards()";
    put " Available on github.com/sasjs/core";
    put '********************************************************************/';
    put "data &tgt_ds &indexes;";
    put "attrib ";
    %do i = 1 %to &nvars;
      __attrib=symget("attrib_stmt_&i");
      put __attrib;
    %end;
    put ";";

    %if &process_dttm_flg. eq Y %then %do;
      put 'retain PROCESSED_DTTM %sysfunc(datetime());';
    %end;
    %if &valid_from_dttm_flg. eq Y %then %do;
      put 'retain VALID_FROM_DTTM &low_date;';
    %end;
    %if &valid_to_dttm_flg. eq Y %then %do;
      put 'retain VALID_TO_DTTM &high_date;';
    %end;
    if __nobs=0 then do;
      put 'call missing(of _all_);/* avoid uninitialised notes */';
      put 'stop;';
      put 'run;';
    end;
    else do;
      put "infile cards dsd delimiter=',';";
      put "input ";
      %do i = 1 %to &nvars.;
        %if(%length(&&input_stmt_&i..)) %then
           put "   &&input_stmt_&i..";
        ;
      %end;
      put ";";
      put "datalines4;";
    end;
  end;
  set &setds end=__lastobs nobs=__nobs;
/* remove all formats for write purposes - some have long underlying decimals */
  format _numeric_ best30.29;
  length __dataline $32767;
  __dataline=catq('cqtmb',&datalines);
  put __dataline;
  if __lastobs then do;
    put ';;;;';
    put 'run;';
    stop;
  end;
run;
proc sql;
  drop table &setds;
quit;

%if &showlog=YES %then %do;
  data _null_;
    infile &cards_file lrecl=32767;
    input;
    put _infile_;
  run;
%end;

%put NOTE: CARDS FILE SAVED IN:;
%put NOTE-;%put NOTE-;
%put NOTE- %sysfunc(dequote(&cards_file.));
%put NOTE-;%put NOTE-;
%mend;/**
  @file
  @brief Export a dataset to a CSV file
  @details Export to a file or a fileref
  Usage:

      %mp_ds2csv(sashelp.class,outref="%sysfunc(pathname(work))/file.csv")

  @param ds The dataset to be exported
  @param outfile= The output filename - should be quoted.
  @param outref= The output fileref (takes precedence if provided)
  @param outencoding= The output encoding to use (unquoted)

  @version 9.2
  @author Allan Bowe (credit mjsq)
**/

%macro mp_ds2csv(ds, outref=0, outfile=, outencoding=0
)/*/STORE SOURCE*/;

%if not %sysfunc(exist(&ds)) %then %do;
   %put WARNING:  &ds does not exist;
   %return;
%end;

%if %index(&ds,.)=0 %then %let ds=WORK.&ds;

%if &outencoding=0 %then %let outencoding=;
%else %let outencoding=encoding="&outencoding";

%local outloc;
%if &outref=0 %then %let outloc=&outfile;
%else %let outloc=&outref;

/* credit to mjsq - https://stackoverflow.com/a/55642267 */

/* first get headers */
data _null_;
   file &outloc dlm=',' dsd &outencoding lrecl=32767;
   length header $ 2000;
   dsid=open("&ds.","i");
   num=attrn(dsid,"nvars");
   do i=1 to num;
      header = trim(left(coalescec(varlabel(dsid,i),varname(dsid,i))));
      put header @;
   end;
   rc=close(dsid);
run;

/* next, export data */
data _null_;
   set &ds.;
   file &outloc mod dlm=',' dsd &outencoding lrecl=32767;
   put (_all_) (+0);
run;


%mend;/**
  @file mp_getconstraints.sas
  @brief Get constraint details at column level
  @details Useful for capturing constraints before they are dropped / reapplied
  during an update.

        proc sql;
        create table work.example(
          TX_FROM float format=datetime19.,
          DD_TYPE char(16),
          DD_SOURCE char(2048),
          DD_SHORTDESC char(256),
          constraint pk primary key(tx_from, dd_type,dd_source),
          constraint unq unique(tx_from, dd_type),
          constraint nnn not null(DD_SHORTDESC)
        );
      
      %mp_getconstraints(lib=work,ds=example,outds=work.constraints)

  @param lib= The target library (default=WORK)
  @param ds= The target dataset.  Leave blank (default) for all datasets.
  @param outds the output dataset

  <h4> Dependencies </h4>

  @version 9.2
  @author Allan Bowe

**/

%macro mp_getconstraints(lib=WORK
  ,ds=
  ,outds=mp_getconstraints
)/*/STORE SOURCE*/;

%let lib=%upcase(&lib);
%let ds=%upcase(&ds);

/* must use SQL as proc datasets does not support length changes */
proc sql noprint;
create table &outds as
  select a.TABLE_CATALOG as libref
    ,a.TABLE_NAME
    ,a.constraint_type
    ,a.constraint_name
    ,b.column_name
  from dictionary.TABLE_CONSTRAINTS a
  left join dictionary.constraint_column_usage  b
  on a.TABLE_CATALOG=b.TABLE_CATALOG
    and a.TABLE_NAME=b.TABLE_NAME
    and a.constraint_name=b.constraint_name
  where a.TABLE_CATALOG="&lib"  
    and b.TABLE_CATALOG="&lib"  
  %if "&ds" ne "" %then %do;
    and a.TABLE_NAME="&ds"
    and b.TABLE_NAME="&ds"
  %end;
  ;

%mend;/**
  @file
  @brief Extract DBML from SAS Libraries
  @details DBML is an open source markup format to represent databases.
  More details: https://www.dbml.org/home/

  Usage:


      %mp_getdbml(liblist=SASHELP WORK,outref=mydbml,showlog=YES)

  Take the log output and paste it into the renderer at https://dbdiagram.io
  to view your data model diagram.  The code takes a "best guess" at
  the one to one and one to many relationships (based on constraints
  and indexes, and assuming that the column names would match).

  You may need to adjust the rendered DBML to suit your needs.

  ![dbml for sas](https://i.imgur.com/8T1tIZp.gif)


  <h4> SAS Macros </h4>
  @li mf_getquotedstr.sas
  @li mp_getconstraints.sas

  @param liblist= Space seperated list of librefs to take as
    input (Default=SASHELP)
  @param outref= Fileref to contain the DBML (Default=getdbml)
  @param showlog= set to YES to show the DBML in the log (Default is NO)

  @version 9.3
  @author Allan Bowe
**/

%macro mp_getdbml(liblist=SASHELP,outref=getdbml,showlog=NO
)/*/STORE SOURCE*/;

/* check fileref is assigned */
%if %sysfunc(fileref(&outref)) > 0 %then %do;
  filename &outref temp;
%end;

%let liblist=%upcase(&liblist);

proc sql noprint;
create table _data_ as
  select * from dictionary.tables
  where upcase(libname) in (%mf_getquotedstr(&liblist))
  order by libname,memname;
%local tabinfo; %let tabinfo=&syslast;

create table _data_ as
  select * from dictionary.columns
  where upcase(libname) in (%mf_getquotedstr(&liblist))
  order by libname,memname,varnum;
%local colinfo; %let colinfo=&syslast;

%local dsnlist;
  select distinct upcase(cats(libname,'.',memname)) into: dsnlist
  separated by ' '
  from &syslast
;

create table _data_ as
  select * from dictionary.indexes
  where upcase(libname) in (%mf_getquotedstr(&liblist))
  order by idxusage, indxname, indxpos;
%local idxinfo; %let idxinfo=&syslast;

/* Extract all Primary Key and Unique data constraints */
%mp_getconstraints(lib=%scan(&liblist,1),outds=_data_)
%local colconst; %let colconst=&syslast;

%do x=2 %to %sysfunc(countw(&liblist));
  %mp_getconstraints(lib=%scan(&liblist,&x),outds=_data_)
  proc append base=&colconst data=&syslast;
  run;
%end;




/* header info */
data _null_;
  file &outref;
  put "// DBML generated by &sysuserid on %sysfunc(datetime(),datetime19.) ";
  put "Project sasdbml {";
  put "  database_type: 'SAS'";
  put "  Note: 'Generated by the mp_getdbml() macro'";
  put "}";
run;

/* create table groups */
data _null_;
  file &outref mod;
  set &tabinfo;
  by libname;
  if first.libname then put "TableGroup " libname "{";
  ds=quote(cats(libname,'.',memname));
  put '   ' ds;
  if last.libname then put "}";
run;

/* table for pks */
data _data_;
  length curds const col $39;
  call missing (of _all_);
  stop;
run;
%let pkds=&syslast;

%local x curds constraints_used constcheck;
%do x=1 %to %sysfunc(countw(&dsnlist,%str( )));
  %let curds=%scan(&dsnlist,&x,%str( ));
  %let constraints_used=;
  %let constcheck=0;
  data _null_;
    file &outref mod;
    length lab $1024 typ $20;
    set &colinfo (where=(
        libname="%scan(&curds,1,.)" and upcase(memname)="%scan(&curds,2,.)"
    )) end=last;

    if _n_=1 then do;
      table='Table "'!!"&curds"!!'"{';
      put table;
    end;
    name=upcase(name);
    lab=" note:"!!quote(trim(tranwrd(label,'"',"'")));
    if upcase(format)=:'DATETIME' then typ='datetime';
    else if type='char' then typ=cats('char(',length,')');
    else typ='num';

    if notnull='yes' then notnul=' not null';
    if notnull='no' and missing(label) then put '  ' name typ;
    else if notnull='yes' and missing(label) then put '  ' name typ '[' notnul ']';
    else if notnull='no' then put '  ' name typ '[' lab ']';
    else put '  ' name typ '[' notnul ',' lab ']';

  run;

  data _data_(keep=curds const col);
    length ctype $11 cols constraints_used $5000;
    set &colconst (where=(
      upcase(libref)="%scan(&curds,1,.)"
      and upcase(table_name)="%scan(&curds,2,.)"
      and constraint_type in ('PRIMARY','UNIQUE')
    )) end=last;
    file &outref mod;
    by constraint_type constraint_name;
    retain cols;
    column_name=upcase(column_name);

    if _n_=1 then put / '  indexes {';

    if upcase(strip(constraint_type)) = 'PRIMARY' then ctype='[pk]';
    else ctype='[unique]';

    if first.constraint_name then cols = cats('(',column_name);
    else cols=cats(cols,',',column_name);

    if last.constraint_name then do;
      cols=cats(cols,')',ctype)!!' //'!!constraint_name;
      put '    ' cols;
      constraints_used=catx(' ',constraints_used, constraint_name);
      call symputx('constcheck',1);
    end;

    if last then call symputx('constraints_used',cats(upcase(constraints_used)));

    length curds const col $39;
    curds="&curds";
    const=constraint_name;
    col=column_name;
  run;

  proc append base=&pkds data=&syslast;run;

  /* Create Unique Indexes, but only if they were not already defined within the Constraints section. */
  data _data_(keep=curds const col);
    set &idxinfo (where=(
      libname="%scan(&curds,1,.)"
      and upcase(memname)="%scan(&curds,2,.)"
      and unique='yes'
      and upcase(indxname) not in (%mf_getquotedstr(&constraints_used))
    ));
    file &outref mod;
    by idxusage indxname;
    name=upcase(name);
    if &constcheck=1 then stop; /* in fact we only care about PKs so stop if we have */
    if _n_=1 and &constcheck=0 then put / '  indexes {';

    length cols $5000;
    retain cols;
    if first.indxname then cols = cats('(',name);
    else cols=cats(cols,',',name);

    if last.indxname then do;
      cols=cats(cols,')[unique]')!!' //'!!indxname;
      put '    ' cols;
      call symputx('constcheck',1);
    end;

    length curds const col $39;
    curds="&curds";
    const=indxname;
    col=name;
  run;
  proc append base=&pkds data=&syslast;run;

  data _null_;
    file &outref mod;
    if &constcheck =1 then put '  }';
    put '}';
  run;

%end;

/**
 * now we need to figure out the relationships
 */

/* sort alphabetically so we can have one set of unique cols per table */
proc sort data=&pkds nodupkey;
  by curds const col;
run;

data &pkds.1 (keep=curds col)
     &pkds.2 (keep=curds cols);
  set &pkds;
  by curds const;
  length retconst $39 cols $5000;
  retain retconst cols;
  if first.curds then do;
    retconst=const;
    cols=upcase(col);
  end;
  else cols=catx(' ',cols,upcase(col));
  if retconst=const then do;
    output &pkds.1;
    if last.const then output &pkds.2;
  end;
run;

%let curdslist="0";
%do x=1 %to %sysfunc(countw(&dsnlist,%str( )));
  %let curds=%scan(&dsnlist,&x,%str( ));

  %let pkcols=0;
  data _null_;
    set &pkds.2(where=(curds="&curds"));
    call symputx('pkcols',cols);
  run;
  %if &pkcols ne 0 %then %do;
    %let curdslist=&curdslist,"&curds";

    /* start with one2one */
    data &pkds.4;
      file &outref mod;
      set &pkds.2(where=(cols="&pkcols" and curds not in (&curdslist)));
      line='Ref: "'!!"&curds"
        !!cats('".(',"%mf_getquotedstr(&pkcols,dlm=%str(,),quote=%str( ))",')')
        !!' - '
        !!cats(quote(trim(curds)),'.(',"%mf_getquotedstr(&pkcols,dlm=%str(,),quote=%str( ))",')');
      put line;
    run;

    /* now many2one */
    /* get table with one row per col */
    data &pkds.5;
      set &pkds.1(where=(curds="&curds"));
    run;
    /* get tables which contain the PK columns */
    proc sql;
    create table &pkds.5a as
      select upcase(cats(b.libname,'.',b.memname)) as curds
        ,b.name
      from &pkds.5 a
      inner join &colinfo b
      on a.col=upcase(b.name);
    /* count to make sure those tables contain ALL the columns */
    create table &pkds.5b as
      select curds,count(*) as cnt
      from &pkds.5a
      where curds not in (select curds from &pkds.2 where cols="&pkcols") /* not a one to one match */
        and curds ne "&curds" /* exclude self */
      group by 1;
    create table &pkds.6 as
      select a.*
        ,b.cols
      from &pkds.5b a
      left join &pkds.4 b
      on a.curds=b.curds;

    data _null_;
      set &pkds.6;
      file &outref mod;
      colcnt=%sysfunc(countw(&pkcols));
      if cnt=colcnt then do;
        /* table contains all the PK cols, and was not a direct / 121 match */
        line='Ref: "'!!"&curds"
          !!'".('
          !!"%mf_getquotedstr(&pkcols,dlm=%str(,),quote=%str( ))"
          !!') > '
          !!cats(quote(trim(curds))
              ,'.('
              ,"%mf_getquotedstr(&pkcols,dlm=%str(,),quote=%str( ))"
              ,')'
          );
        put line;
      end;
    run;
  %end;
%end;


%if %upcase(&showlog)=YES %then %do;
  options ps=max;
  data _null_;
    infile &outref;
    input;
    putlog _infile_;
  run;
%end;

%mend;/**
  @file mp_getddl.sas
  @brief Extract DDL in various formats, by table or library
  @details Data Definition Language relates to a set of SQL instructions used
    to create tables in SAS or a database.  The macro can be used at table or
    library level.  The default behaviour is to create DDL in SAS format.

  Usage:

      data test(index=(pk=(x y)/unique /nomiss));
        x=1;
        y='blah';
        label x='blah';
      run;
      proc sql; describe table &syslast;
      %mp_getddl(work,test,flavour=tsql,showlog=YES)

  <h4> Dependencies </h4>
  @li mp_getconstraints.sas

  @param lib libref of the library to create DDL for.  Should be assigned.
  @param ds dataset to create ddl for (optional)
  @param fref= the fileref to which to write the DDL.  If not preassigned, will
    be assigned to TEMP.
  @param flavour= The type of DDL to create (default=SAS). Supported=TSQL
  @param showlog= Set to YES to show the DDL in the log
  @param schema= Choose a preferred schema name (default is to use actual schema
    ,else libref)
  @param applydttm= for non SAS DDL, choose if columns are created with native
   datetime2 format or regular decimal type
  @version 9.3
  @author Allan Bowe
**/

%macro mp_getddl(libref,ds,fref=getddl,flavour=SAS,showlog=NO,schema=
  ,applydttm=NO
)/*/STORE SOURCE*/;

/* check fileref is assigned */
%if %sysfunc(fileref(&fref)) > 0 %then %do;
  filename &fref temp;
%end;
%if %length(&libref)=0 %then %let libref=WORK;
%let flavour=%upcase(&flavour);

proc sql noprint;
create table _data_ as
  select * from dictionary.tables
  where upcase(libname)="%upcase(&libref)"
  %if %length(&ds)>0 %then %do;
    and upcase(memname)="%upcase(&ds)"
  %end;
  ;
%local tabinfo; %let tabinfo=&syslast;

create table _data_ as
  select * from dictionary.columns
  where upcase(libname)="%upcase(&libref)"
  %if %length(&ds)>0 %then %do;
    and upcase(memname)="%upcase(&ds)"
  %end;
  ;
%local colinfo; %let colinfo=&syslast;

%local dsnlist;
  select distinct upcase(memname) into: dsnlist
  separated by ' '
  from &syslast
;

create table _data_ as
  select * from dictionary.indexes
  where upcase(libname)="%upcase(&libref)"
  %if %length(&ds)>0 %then %do;
    and upcase(memname)="%upcase(&ds)"
  %end;
  order by idxusage, indxname, indxpos
  ;
%local idxinfo; %let idxinfo=&syslast;

/* Extract all Primary Key and Unique data constraints */
%mp_getconstraints(lib=%upcase(&libref),ds=%upcase(&ds),outds=_data_)
%local colconst; %let colconst=&syslast;

%macro addConst();
  %global constraints_used;
  data _null_;
    length ctype $11 constraint_name_orig $256 constraints_used $5000;
    set &colconst (where=(table_name="&curds" and constraint_type in ('PRIMARY','UNIQUE'))) end=last;
    file &fref mod;
    by constraint_type constraint_name;
    retain constraints_used;
    constraint_name_orig=constraint_name;
    if upcase(strip(constraint_type)) = 'PRIMARY' then ctype='PRIMARY KEY';
    else ctype=strip(constraint_type);
    %if &flavour=TSQL %then %do;
      column_name=catt('[',column_name,']');
      constraint_name=catt('[',constraint_name,']');
    %end;
    %else %if &flavour=PGSQL %then %do;
      column_name=catt('"',column_name,'"');
      constraint_name=catt('"',constraint_name,'"');
    %end;
    if first.constraint_name then do;
      constraints_used = catx(' ', constraints_used, constraint_name_orig);
      put "   ,CONSTRAINT " constraint_name ctype "(" ;
      put '     ' column_name;
    end;
  else put '     ,' column_name;
  if last.constraint_name then do;
    put "   )";
    call symput('constraints_used',strip(constraints_used));
  end;
  run;
  %put &=constraints_used;
%mend;

data _null_;
  file &fref;
  put "/* DDL generated by &sysuserid on %sysfunc(datetime(),datetime19.) */";
run;

%local x curds;
%if &flavour=SAS %then %do;
  data _null_;
    file &fref mod;
    put "/* SAS Flavour DDL for %upcase(&libref).&curds */";
    put "proc sql;";
  run;
  %do x=1 %to %sysfunc(countw(&dsnlist));
    %let curds=%scan(&dsnlist,&x);
    data _null_;
      file &fref mod;
      length nm lab $1024 typ $20;
      set &colinfo (where=(upcase(memname)="&curds")) end=last;

      if _n_=1 then do;
        if memtype='DATA' then do;
          put "create table &libref..&curds(";
        end;
        else do;
          put "create view &libref..&curds(";
        end;
        put "    "@@;
      end;
      else put "   ,"@@;
      if length(format)>1 then fmt=" format="!!cats(format);
      if length(label)>1 then lab=" label="!!quote(trim(label));
      if notnull='yes' then notnul=' not null';
      if type='char' then typ=cats('char(',length,')');
      else if length ne 8 then typ='num length='!!left(length);
      else typ='num';
      put name typ fmt notnul lab;
    run;

    /* Extra step for data constraints */
    %addConst()

    data _null_;
      file &fref mod;
      put ');';
    run;

    /* Create Unique Indexes, but only if they were not already defined within the Constraints section. */
    data _null_;
      *length ds $128;
      set &idxinfo (where=(memname="&curds" and unique='yes' and indxname not in (%sysfunc(tranwrd("&constraints_used",%str( ),%str(","))))));
      file &fref mod;
      by idxusage indxname;
/*       ds=cats(libname,'.',memname); */
      if first.indxname then do;
          put 'CREATE UNIQUE INDEX ' indxname "ON &libref..&curds (" ;
          put '  ' name ;
      end;
      else put '  ,' name ;
      *else put '    ,' name ;
      if last.indxname then do;
        put ');';
      end;
    run;

/*
    ods output IntegrityConstraints=ic;
    proc contents data=testali out2=info;
    run;
    */
  %end;
%end;
%else %if &flavour=TSQL %then %do;
  /* if schema does not exist, set to be same as libref */
  %local schemaactual;
  proc sql noprint;
  select sysvalue into: schemaactual
    from dictionary.libnames
    where libname="&libref" and engine='SQLSVR';
  %let schema=%sysfunc(coalescec(&schemaactual,&schema,&libref));

  %do x=1 %to %sysfunc(countw(&dsnlist));
    %let curds=%scan(&dsnlist,&x);
    data _null_;
      file &fref mod;
      put "/* TSQL Flavour DDL for &schema..&curds */";
    data _null_;
      file &fref mod;
      set &colinfo (where=(upcase(memname)="&curds")) end=last;
      if _n_=1 then do;
        if memtype='DATA' then do;
          put "create table [&schema].[&curds](";
        end;
        else do;
          put "create view [&schema].[&curds](";
        end;
        put "    "@@;
      end;
      else put "   ,"@@;
      format=upcase(format);
      if 1=0 then; /* dummy if */
      %if &applydttm=YES %then %do;
        else if format=:'DATETIME' then fmt='[datetime2](7)  ';
      %end;
      else if type='num' then fmt='[decimal](18,2)';
      else if length le 8000 then fmt='[varchar]('!!cats(length)!!')';
      else fmt=cats('[varchar](max)');
      if notnull='yes' then notnul=' NOT NULL';
      put "[" name +(-1) "]" fmt notnul;
    run;

    /* Extra step for data constraints */
    %addConst()

    /* Create Unique Indexes, but only if they were not already defined within the Constraints section. */
    data _null_;
      *length ds $128;
      set &idxinfo (where=(memname="&curds" and unique='yes' and indxname not in (%sysfunc(tranwrd("&constraints_used",%str( ),%str(","))))));
      file &fref mod;
      by idxusage indxname;
      *ds=cats(libname,'.',memname);
      if first.indxname then do;
        /* add nonclustered in case of multiple unique indexes */
        put '   ,index [' indxname +(-1) '] UNIQUE NONCLUSTERED (';
        put '     [' name +(-1) ']';
      end;
      else put '     ,[' name +(-1) ']';
      if last.indxname then do;
        put '   )';
      end;
    run;

    data _null_;
      file &fref mod;
      put ')';
      put 'GO';
    run;

    /* add extended properties for labels */
    data _null_;
      file &fref mod;
      length nm $64 lab $1024;
      set &colinfo (where=(upcase(memname)="&curds" and label ne '')) end=last;
      nm=cats("N'",tranwrd(name,"'","''"),"'");
      lab=cats("N'",tranwrd(label,"'","''"),"'");
      put ' ';
      put "EXEC sys.sp_addextendedproperty ";
      put "  @name=N'MS_Description',@value=" lab ;
      put "  ,@level0type=N'SCHEMA',@level0name=N'&schema' ";
      put "  ,@level1type=N'TABLE',@level1name=N'&curds'";
      put "  ,@level2type=N'COLUMN',@level2name=" nm ;
      if last then put 'GO';
    run;
  %end;
%end;
%else %if &flavour=PGSQL %then %do;
  /* if schema does not exist, set to be same as libref */
  %local schemaactual;
  proc sql noprint;
  select sysvalue into: schemaactual
    from dictionary.libnames
    where libname="&libref" and engine='POSTGRES';
  %let schema=%sysfunc(coalescec(&schemaactual,&schema,&libref));
  data _null_;
    file &fref mod;
    put "CREATE SCHEMA &schema;";
  %do x=1 %to %sysfunc(countw(&dsnlist));
    %let curds=%scan(&dsnlist,&x);
    data _null_;
      file &fref mod;
      put "/* Postgres Flavour DDL for &schema..&curds */";
    data _null_;
      file &fref mod;
      set &colinfo (where=(upcase(memname)="&curds")) end=last;
      length fmt $32;
      if _n_=1 then do;
        if memtype='DATA' then do;
          put "CREATE TABLE &schema..&curds (";
        end;
        else do;
          put "CREATE VIEW &schema..&curds (";
        end;
        put "    "@@;
      end;
      else put "   ,"@@;
      format=upcase(format);
      if 1=0 then; /* dummy if */
      %if &applydttm=YES %then %do;
        else if format=:'DATETIME' then fmt=' TIMESTAMP ';
      %end;
      else if type='num' then fmt=' DOUBLE PRECISION';
      else fmt='VARCHAR('!!cats(length)!!')';
      if notnull='yes' then notnul=' NOT NULL';
      /* quote column names in case they represent reserved words */
      name2=quote(trim(name));
      put name2 fmt notnul;
    run;

    /* Extra step for data constraints */
    %addConst()

    data _null_;
      file &fref mod;
      put ');';
    run;

    /* Create Unique Indexes, but only if they were not already defined within the Constraints section. */
    data _null_;
      *length ds $128;
      set &idxinfo (where=(memname="&curds" and unique='yes' and indxname not in (%sysfunc(tranwrd("&constraints_used",%str( ),%str(","))))));
      file &fref mod;
      by idxusage indxname;
/*       ds=cats(libname,'.',memname); */
      if first.indxname then do;
          put 'CREATE UNIQUE INDEX "' indxname +(-1) '" ' "ON &schema..&curds (" ;
          put '  "' name +(-1) '"' ;
      end;
      else put '  ,"' name +(-1) '"';
      *else put '    ,' name ;
      if last.indxname then do;
        put ');';
      end;
    run;

  %end;
%end;
%if %upcase(&showlog)=YES %then %do;
  options ps=max;
  data _null_;
    infile &fref;
    input;
    putlog _infile_;
  run;
%end;

%mend;/**
  @file mp_getmaxvarlengths.sas
  @brief Scans a dataset to find the max length of the variable values
  @details  
  This macro will scan a base dataset and produce an output dataset with two
  columns:

  - NAME    Name of the base dataset column
  - MAXLEN Maximum length of the data contained therein.

  Character fields may be allocated very large widths (eg 32000) of which the maximum
    value is likely to be much narrower.  This macro was designed to enable a HTML
    table to be appropriately sized however this could be used as part of a data
    audit to ensure we aren't over-sizing our tables in relation to the data therein.

  Numeric fields are converted using the relevant format to determine the width.
  Usage:

      %mp_getmaxvarlengths(sashelp.class,outds=work.myds)

  @param libds Two part dataset (or view) reference.
  @param outds= The output dataset to create

  <h4> Dependencies </h4>
  @li mf_getvarlist.sas
  @li mf_getvartype.sas
  @li mf_getvarformat.sas

  @version 9.2
  @author Allan Bowe

**/

%macro mp_getmaxvarlengths(
    libds      /* libref.dataset to analyse */
   ,outds=work.mp_getmaxvarlengths /* name of output dataset to create */
)/*/STORE SOURCE*/;

%local vars x var fmt;
%let vars=%mf_getvarlist(libds=&libds);

proc sql;
create table &outds (rename=(
    %do x=1 %to %sysfunc(countw(&vars,%str( )));
      ________&x=%scan(&vars,&x)
    %end;
    ))
  as select
    %do x=1 %to %sysfunc(countw(&vars,%str( )));
      %let var=%scan(&vars,&x);
      %if &x>1 %then ,;
      %if %mf_getvartype(&libds,&var)=C %then %do;
        max(length(&var)) as ________&x
      %end;
      %else %do;
        %let fmt=%mf_getvarformat(&libds,&var);
        %put fmt=&fmt;
        %if %str(&fmt)=%str() %then %do;
          max(length(cats(&var))) as ________&x
        %end;
        %else %do;
          max(length(put(&var,&fmt))) as ________&x
        %end;
      %end;
    %end;
  from &libds;

  proc transpose data=&outds
    out=&outds(rename=(_name_=NAME COL1=MAXLEN));
  run;

%mend;/**
  @file mp_guesspk.sas
  @brief Guess the primary key of a table
  @details Tries to guess the primary key of a table based on the following logic:

      * Columns with nulls are ignored
      * Return only column combinations that provide unique results
      * Start from one column, then move out to include composite keys of 2 to 6 columns

  The library of the target should be assigned before using this macro.

  Usage:

      filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;
      %mp_guesspk(sashelp.class,outds=classpks)

  @param baseds The dataset to analyse
  @param outds= The output dataset to contain the possible PKs
  @param max_guesses= The total number of possible primary keys to generate.  A
    table is likely to have multiple unlikely PKs, so no need to list them all. Default=3.
  @param min_rows= The minimum number of rows a table should have in order to try
    and guess the PK.  Default=5.

  <h4> Dependencies </h4>
  @li mf_getvarlist.sas
  @li mf_getuniquename.sas
  @li mf_nobs.sas

  @version 9.3
  @author Allan Bowe

**/

%macro mp_guesspk(baseds
      ,outds=mp_guesspk
      ,max_guesses=3
      ,min_rows=5
)/*/STORE SOURCE*/;

  /* declare local vars */
  %local var vars vcnt i j k l tmpvar tmpds rows posspks ppkcnt;
  %let vars=%mf_getvarlist(&baseds);
  %let vcnt=%sysfunc(countw(&vars));

  %if &vcnt=0 %then %do;
    %put &sysmacroname: &baseds has no variables!  Exiting.;
    %return;
  %end;

  /* get null count and row count */
  %let tmpvar=%mf_getuniquename();
  proc sql noprint;
  create table _data_ as select
    count(*) as &tmpvar
  %do i=1 %to &vcnt;
    %let var=%scan(&vars,&i);
    ,sum(case when &var is missing then 1 else 0 end) as &var
  %end;
    from &baseds;

  /* transpose table and scan for not null cols */
  proc transpose;
  data _null_;
    set &syslast end=last;
    length vars $32767;
    retain vars ;
    if _name_="&tmpvar" then call symputx('rows',col1,'l');
    else if col1=0 then vars=catx(' ',vars,_name_);
    if last then call symputx('posspks',vars,'l');
  run;

  %let ppkcnt=%sysfunc(countw(&posspks));
  %if &ppkcnt=0 %then %do;
    %put &sysmacroname: &baseds has no non-missing variables!  Exiting.;
    %return;
  %end;

  proc sort data=&baseds(keep=&posspks) out=_data_ noduprec;
    by _all_;
  run;
  %local pkds; %let pkds=&syslast;

  %if &rows > %mf_nobs(&pkds) %then %do;
    %put &sysmacroname: &baseds has no combination of unique records! Exiting.;
    %return;
  %end;

  /* now check cardinality */
  proc sql noprint;
  create table _data_ as select
  %do i=1 %to &ppkcnt;
    %let var=%scan(&posspks,&i);
    count(distinct &var) as &var
    %if &i<&ppkcnt %then ,;
  %end;
    from &pkds;

  /* transpose and sort by cardinality */
  proc transpose;
  proc sort; by descending col1;
  run;

  /* create initial PK list and re-order posspks list */
  data &outds(keep=pkguesses);
    length pkguesses $5000 vars $5000;
    set &syslast end=last;
    retain vars ;
    vars=catx(' ',vars,_name_);
    if col1=&rows then do;
      pkguesses=_name_;
      output;
    end;
    if last then call symputx('posspks',vars,'l');
  run;

  %if %mf_nobs(&outds) ge &max_guesses %then %do;
    %put &sysmacroname: %mf_nobs(&outds) possible primary key values found;
    %return;
  %end;

  %if &ppkcnt=1 %then %do;
    %put &sysmacroname: No more PK guess possible;
    %return;
  %end;

  /* begin scanning for uniques on pairs of PKs */
  %let tmpds=%mf_getuniquename();
  %local lev1 lev2;
  %do i=1 %to &ppkcnt;
    %let lev1=%scan(&posspks,&i);
    %do j=2 %to &ppkcnt;
      %let lev2=%scan(&posspks,&j);
      %if &lev1 ne &lev2 %then %do;
        /* check for two level uniqueness */
        proc sort data=&pkds(keep=&lev1 &lev2) out=&tmpds noduprec;
          by _all_;
        run;
        %if %mf_nobs(&tmpds)=&rows %then %do;
          proc sql;
          insert into &outds values("&lev1 &lev2");
          %if %mf_nobs(&outds) ge &max_guesses %then %do;
            %put &sysmacroname: Max PKs reached at Level 2 for &baseds;
            %return;
          %end;
        %end;
      %end;
    %end;
  %end;

  %if &ppkcnt=2 %then %do;
    %put &sysmacroname: No more PK guess possible;
    %return;
  %end;

  /* begin scanning for uniques on PK triplets */
  %local lev3;
  %do i=1 %to &ppkcnt;
    %let lev1=%scan(&posspks,&i);
    %do j=2 %to &ppkcnt;
      %let lev2=%scan(&posspks,&j);
      %if &lev1 ne &lev2 %then %do k=3 %to &ppkcnt;
        %let lev3=%scan(&posspks,&k);
        %if &lev1 ne &lev3 and &lev2 ne &lev3 %then %do;
          /* check for three level uniqueness */
          proc sort data=&pkds(keep=&lev1 &lev2 &lev3) out=&tmpds noduprec;
            by _all_;
          run;
          %if %mf_nobs(&tmpds)=&rows %then %do;
            proc sql;
            insert into &outds values("&lev1 &lev2 &lev3");
            %if %mf_nobs(&outds) ge &max_guesses %then %do;
              %put &sysmacroname: Max PKs reached at Level 3 for &baseds;
              %return;
            %end;
          %end;
        %end;
      %end;
    %end;
  %end;

  %if &ppkcnt=3 %then %do;
    %put &sysmacroname: No more PK guess possible;
    %return;
  %end;

  /* scan for uniques on up to 4 PK fields */
  %local lev4;
  %do i=1 %to &ppkcnt;
    %let lev1=%scan(&posspks,&i);
    %do j=2 %to &ppkcnt;
      %let lev2=%scan(&posspks,&j);
      %if &lev1 ne &lev2 %then %do k=3 %to &ppkcnt;
        %let lev3=%scan(&posspks,&k);
        %if &lev1 ne &lev3 and &lev2 ne &lev3 %then %do l=4 %to &ppkcnt;
          %let lev4=%scan(&posspks,&l);
          %if &lev1 ne &lev4 and &lev2 ne &lev4 and &lev3 ne &lev4 %then %do;
            /* check for four level uniqueness */
            proc sort data=&pkds(keep=&lev1 &lev2 &lev3 &lev4) out=&tmpds noduprec;
              by _all_;
            run;
            %if %mf_nobs(&tmpds)=&rows %then %do;
              proc sql;
              insert into &outds values("&lev1 &lev2 &lev3 &lev4");
              %if %mf_nobs(&outds) ge &max_guesses %then %do;
                %put &sysmacroname: Max PKs reached at Level 4 for &baseds;
                %return;
              %end;
            %end;
          %end;
        %end;
      %end;
    %end;
  %end;

  %if &ppkcnt=4 %then %do;
    %put &sysmacroname: No more PK guess possible;
    %return;
  %end;

  /* scan for uniques on up to 4 PK fields */
  %local lev5 m;
  %do i=1 %to &ppkcnt;
    %let lev1=%scan(&posspks,&i);
    %do j=2 %to &ppkcnt;
      %let lev2=%scan(&posspks,&j);
      %if &lev1 ne &lev2 %then %do k=3 %to &ppkcnt;
        %let lev3=%scan(&posspks,&k);
        %if &lev1 ne &lev3 and &lev2 ne &lev3 %then %do l=4 %to &ppkcnt;
          %let lev4=%scan(&posspks,&l);
          %if &lev1 ne &lev4 and &lev2 ne &lev4 and &lev3 ne &lev4 %then
          %do m=5 %to &ppkcnt;
            %let lev5=%scan(&posspks,&m);
            %if &lev1 ne &lev5 & &lev2 ne &lev5 & &lev3 ne &lev5 & &lev4 ne &lev5 %then %do;
              /* check for four level uniqueness */
              proc sort data=&pkds(keep=&lev1 &lev2 &lev3 &lev4 &lev5) out=&tmpds noduprec;
                by _all_;
              run;
              %if %mf_nobs(&tmpds)=&rows %then %do;
                proc sql;
                insert into &outds values("&lev1 &lev2 &lev3 &lev4 &lev5");
                %if %mf_nobs(&outds) ge &max_guesses %then %do;
                  %put &sysmacroname: Max PKs reached at Level 5 for &baseds;
                  %return;
                %end;
              %end;
            %end;
          %end;
        %end;
      %end;
    %end;
  %end;

  %if &ppkcnt=5 %then %do;
    %put &sysmacroname: No more PK guess possible;
    %return;
  %end;

  /* scan for uniques on up to 4 PK fields */
  %local lev6 n;
  %do i=1 %to &ppkcnt;
    %let lev1=%scan(&posspks,&i);
    %do j=2 %to &ppkcnt;
      %let lev2=%scan(&posspks,&j);
      %if &lev1 ne &lev2 %then %do k=3 %to &ppkcnt;
        %let lev3=%scan(&posspks,&k);
        %if &lev1 ne &lev3 and &lev2 ne &lev3 %then %do l=4 %to &ppkcnt;
          %let lev4=%scan(&posspks,&l);
          %if &lev1 ne &lev4 and &lev2 ne &lev4 and &lev3 ne &lev4 %then
          %do m=5 %to &ppkcnt;
            %let lev5=%scan(&posspks,&m);
            %if &lev1 ne &lev5 & &lev2 ne &lev5 & &lev3 ne &lev5 & &lev4 ne &lev5 %then
            %do n=6 %to &ppkcnt;
              %let lev6=%scan(&posspks,&n);
              %if &lev1 ne &lev6 & &lev2 ne &lev6 & &lev3 ne &lev6
              & &lev4 ne &lev6 & &lev5 ne &lev6 %then
              %do;
                /* check for four level uniqueness */
                proc sort data=&pkds(keep=&lev1 &lev2 &lev3 &lev4 &lev5 &lev6)
                  out=&tmpds noduprec;
                  by _all_;
                run;
                %if %mf_nobs(&tmpds)=&rows %then %do;
                  proc sql;
                  insert into &outds values("&lev1 &lev2 &lev3 &lev4 &lev5 &lev6");
                  %if %mf_nobs(&outds) ge &max_guesses %then %do;
                    %put &sysmacroname: Max PKs reached at Level 6 for &baseds;
                    %return;
                  %end;
                %end;
              %end;
            %end;
          %end;
        %end;
      %end;
    %end;
  %end;

  %if &ppkcnt=6 %then %do;
    %put &sysmacroname: No more PK guess possible;
    %return;
  %end;

%mend;/**
  @file mp_jsonout.sas
  @brief Writes JSON in SASjs format to a fileref
  @details PROC JSON is faster but will produce errs like the ones below if
  special chars are encountered.

     >An object or array close is not valid at this point in the JSON text.
     >Date value out of range

  If this happens, try running with ENGINE=DATASTEP.

  Usage:

        filename tmp temp;
        data class; set sashelp.class;run;
        
        %mp_jsonout(OBJ,class,jref=tmp)

        data _null_;
        infile tmp;
        input;list;
        run;

  If you are building web apps with SAS then you are strongly encouraged to use
  the mX_createwebservice macros in combination with the 
  [sasjs adapter](https://github.com/sasjs/adapter).
  For more information see https://sasjs.io

  @param action Valid values:
    * OPEN - opens the JSON
    * OBJ - sends a table with each row as an object
    * ARR - sends a table with each row in an array
    * CLOSE - closes the JSON

  @param ds the dataset to send.  Must be a work table.
  @param jref= the fileref to which to send the JSON
  @param dslabel= the name to give the table in the exported JSON
  @param fmt= Whether to keep or strip formats from the table
  @param engine= Which engine to use to send the JSON, options are:
  * PROCJSON (default)
  * DATASTEP 

  @param dbg= DEPRECATED - was used to conditionally add PRETTY to
    proc json but this can cause line truncation in large files.
    

  @version 9.2
  @author Allan Bowe
  @source https://github.com/sasjs/core

**/

%macro mp_jsonout(action,ds,jref=_webout,dslabel=,fmt=Y,engine=PROCJSON,dbg=0
)/*/STORE SOURCE*/;
%put output location=&jref;
%if &action=OPEN %then %do;
  data _null_;file &jref encoding='utf-8';
    put '{"START_DTTM" : "' "%sysfunc(datetime(),datetime20.3)" '"';
  run;
%end;
%else %if (&action=ARR or &action=OBJ) %then %do;
  options validvarname=upcase;
  data _null_;file &jref mod encoding='utf-8';
    put ", ""%lowcase(%sysfunc(coalescec(&dslabel,&ds)))"":";

  %if &engine=PROCJSON %then %do;
    data;run;%let tempds=&syslast;
    proc sql;drop table &tempds;
    data &tempds /view=&tempds;set &ds; 
    %if &fmt=N %then format _numeric_ best32.;;
    proc json out=&jref pretty
        %if &action=ARR %then nokeys ;
        ;export &tempds / nosastags fmtnumeric;
    run;
    proc sql;drop view &tempds;
  %end;
  %else %if &engine=DATASTEP %then %do;
    %local cols i tempds;
    %let cols=0;
    %if %sysfunc(exist(&ds)) ne 1 & %sysfunc(exist(&ds,VIEW)) ne 1 %then %do;
      %put &sysmacroname:  &ds NOT FOUND!!!;
      %return;
    %end;
    data _null_;file &jref mod ; 
      put "["; call symputx('cols',0,'l');
    proc sort data=sashelp.vcolumn(where=(libname='WORK' & memname="%upcase(&ds)"))
      out=_data_;
      by varnum;

    data _null_; 
      set _last_ end=last;
      call symputx(cats('name',_n_),name,'l');
      call symputx(cats('type',_n_),type,'l');
      call symputx(cats('len',_n_),length,'l');
      if last then call symputx('cols',_n_,'l');
    run;

    proc format; /* credit yabwon for special null removal */
      value bart ._ - .z = null
      other = [best.];

    data;run; %let tempds=&syslast; /* temp table for spesh char management */
    proc sql; drop table &tempds;
    data &tempds/view=&tempds;
      attrib _all_ label='';
      %do i=1 %to &cols;
        %if &&type&i=char %then %do;
          length &&name&i $32767;
          format &&name&i $32767.;
        %end;
      %end;
      set &ds;
      format _numeric_ bart.;
    %do i=1 %to &cols;
      %if &&type&i=char %then %do;
        &&name&i='"'!!trim(prxchange('s/"/\"/',-1,
                    prxchange('s/'!!'0A'x!!'/\n/',-1,
                    prxchange('s/'!!'0D'x!!'/\r/',-1,
                    prxchange('s/'!!'09'x!!'/\t/',-1,
                    prxchange('s/\\/\\\\/',-1,&&name&i)
        )))))!!'"';
      %end;
    %end;
    run; 
    /* write to temp loc to avoid _webout truncation - https://support.sas.com/kb/49/325.html */
    filename _sjs temp lrecl=131068 encoding='utf-8';
    data _null_; file _sjs lrecl=131068 encoding='utf-8' mod;
      set &tempds;
      if _n_>1 then put "," @; put
      %if &action=ARR %then "[" ; %else "{" ;
      %do i=1 %to &cols;
        %if &i>1 %then  "," ;
        %if &action=OBJ %then """&&name&i"":" ;
        &&name&i 
      %end;
      %if &action=ARR %then "]" ; %else "}" ; ;
    proc sql;
    drop view &tempds;
    /* now write the long strings to _webout 1 byte at a time */
    data _null_;
      length filein 8 fileid 8;
      filein = fopen("_sjs",'I',1,'B');
      fileid = fopen("&jref",'A',1,'B');
      rec = '20'x;
      do while(fread(filein)=0);
        rc = fget(filein,rec,1);
        rc = fput(fileid, rec);
        rc =fwrite(fileid);
      end;
      rc = fclose(filein);
      rc = fclose(fileid);
    run;
    filename _sjs clear;
    data _null_; file &jref mod encoding='utf-8';
      put "]";
    run;
  %end;
%end;

%else %if &action=CLOSE %then %do;
  data _null_;file &jref encoding='utf-8';
    put "}";
  run;
%end;
%mend;/**
  @file
  @brief Convert all library members to CARDS files
  @details Gets list of members then calls the <code>%mp_ds2cards()</code>
            macro
    usage:

    %mp_lib2cards(lib=sashelp
        , outloc= C:\temp )

  <h4> Dependencies </h4>
  @li mf_mkdir.sas
  @li mp_ds2cards.sas

  @param lib= Library in which to convert all datasets
  @param outloc= Location in which to store output.  Defaults to WORK library.
    Do not use a trailing slash (my/path not my/path/).  No quotes.
  @param maxobs= limit output to the first <code>maxobs</code> observations

  @version 9.2
  @author Allan Bowe
**/

%macro mp_lib2cards(lib=
    ,outloc=%sysfunc(pathname(work)) /* without trailing slash */
    ,maxobs=max
    ,random_sample=NO
)/*/STORE SOURCE*/;

/* Find the tables */
%local x ds memlist;
proc sql noprint;
select distinct lowcase(memname)
  into: memlist
  separated by ' '
  from dictionary.tables
  where upcase(libname)="%upcase(&lib)";

/* create the output directory */
%mf_mkdir(&outloc)

/* create the cards files */
%do x=1 %to %sysfunc(countw(&memlist));
   %let ds=%scan(&memlist,&x);
   %mp_ds2cards(base_ds=&lib..&ds
      ,cards_file="&outloc/&ds..sas"
      ,maxobs=&maxobs
      ,random_sample=&random_sample)
%end;

%mend;/**
  @file
  @brief Logs the time the macro was executed in a control dataset.
  @details If the dataset does not exist, it is created.  Usage:

    %mp_perflog(started)
    %mp_perflog()
    %mp_perflog(startanew,libds=work.newdataset)
    %mp_perflog(finished,libds=work.newdataset)
    %mp_perflog(finished)


  @param label Provide label to go into the control dataset
  @param libds= Provide a dataset in which to store performance stats.  Default
              name is <code>work.mp_perflog</code>;

  @version 9.2
  @author Allan Bowe
  @source https://github.com/sasjs/core

**/

%macro mp_perflog(label,libds=work.mp_perflog
)/*/STORE SOURCE*/;

  %if not (%mf_existds(&libds)) %then %do;
    data &libds;
      length sysjobid $10 label $256 dttm 8.;
      format dttm datetime19.3;
      call missing(of _all_);
      stop;
    run;
  %end;

  proc sql;
    insert into &libds
      set sysjobid="&sysjobid"
        ,label=symget('label')
        ,dttm=%sysfunc(datetime());
  quit;

%mend;/**
  @file
  @brief Returns all children from a hierarchy table for a specified parent
  @details Where data stores hierarchies in a simple parent / child mapping,
    it is not always straightforward to extract all the children for a
    particular parent.  This problem is known as a recursive self join.  This
    macro will extract all the descendents for a parent.
  Usage:

      data have;
        p=1;c=2;output;
        p=2;c=3;output;
        p=2;c=4;output;
        p=3;c=5;output;
        p=6;c=7;output;
        p=8;c=9;output;
      run;

      %mp_recursivejoin(base_ds=have
        ,outds=want
        ,matchval=1
        ,parentvar=p
        ,childvar=c
        )

  @param base_ds= base table containing hierarchy (not modified)
  @param outds= the output dataset to create with the generated hierarchy
  @param matchval= the ultimate parent from which to filter
  @param parentvar= name of the parent variable
  @param childvar= name of the child variable (should be same type as parent)
  @param mdebug= set to 1 to prevent temp tables being dropped


  @returns outds contains the following variables:
   - level (0 = top level)
   - &parentvar
   - &childvar (null if none found)

  @version 9.2
  @author Allan Bowe

**/

%macro mp_recursivejoin(base_ds=
    ,outds=
    ,matchval=
    ,parentvar=
    ,childvar=
    ,iter= /* reserved for internal / recursive use by the macro itself */
    ,maxiter=500 /* avoid infinite loop */
    ,mDebug=0);

%if &iter= %then %do;
  proc sql;
  create table &outds as
    select 0 as level,&parentvar, &childvar
    from &base_ds
    where &parentvar=&matchval;
  %if &sqlobs.=0 %then %do;
    %put NOTE: &sysmacroname: No match for &parentvar=&matchval;
    %return;
  %end;
  %let iter=1;
%end;
%else %if &iter>&maxiter %then %return;

proc sql;
create table _data_ as
  select &iter as level
    ,curr.&childvar as &parentvar
    ,base_ds.&childvar as &childvar
  from &outds curr
  left join &base_ds base_ds
  on  curr.&childvar=base_ds.&parentvar
  where curr.level=%eval(&iter.-1)
    & curr.&childvar is not null;
%local append_ds; %let append_ds=&syslast;
%local obs; %let obs=&sqlobs;
insert into &outds select distinct * from &append_ds;
%if &mdebug=0 %then drop table &append_ds;;

%if &obs %then %do;
  %mp_recursivejoin(iter=%eval(&iter.+1)
    ,outds=&outds,parentvar=&parentvar
    ,childvar=&childvar
    ,base_ds=&base_ds
    )
%end;

%mend;
/**
  @file
  @brief Reset an option to original value
  @details Inspired by the SAS Jedi - https://blogs.sas.com/content/sastraining/2012/08/14/jedi-sas-tricks-reset-sas-system-options/
    Called as follows:

    options obs=30;
    %mp_resetoption(OBS)


  @param option the option to reset

  @version 9.2
  @author Allan Bowe

**/

%macro mp_resetoption(option /* the option to reset */
)/*/STORE SOURCE*/;

data _null_;
  length code  $1500;
  startup=getoption("&option",'startupvalue');
  current=getoption("&option");
  if startup ne current then do;
    code =cat('OPTIONS ',getoption("&option",'keyword','startupvalue'),';');
    putlog "NOTE: Resetting system option: " code ;
    call execute(code );
  end;
run;

%mend;/**
  @file mp_runddl.sas
  @brief An opinionated way to execute DDL files in SAS.
  @details When delivering projects there should be seperation between the DDL
    used to generate the tables and the sample data used to populate them.

  This macro expects certain folder structure - eg:

    rootlib
    |-- LIBREF1
    |  |__ mytable.ddl
    |  |__ someothertable.ddl
    |-- LIBREF2
    |  |__ table1.ddl
    |  |__ table2.ddl
    |-- LIBREF3
       |__ table3.ddl
       |__ table4.ddl

  Only files with the .ddl suffix are executed.  The parent folder name is used
  as the libref.
  Files should NOT contain the `proc sql` statement - this is to prevent
  statements being executed if there is an err condition.

  Usage:

    %mp_runddl(/some/rootlib)  * execute all libs ;

    %mp_runddl(/some/rootlib, inc=LIBREF1 LIBREF2) * include only these libs;

    %mp_runddl(/some/rootlib, exc=LIBREF3) * same as above ;


  @param path location of the DDL folder structure
  @param inc= list of librefs to include
  @param exc= list of librefs to exclude (takes precedence over inc=)

  @version 9.3
  @author Allan Bowe
  @source https://github.com/sasjs/core

**/

%macro mp_runddl(path, inc=, exc=
)/*/STORE SOURCE*/;



%mend;/**
  @file mp_searchcols.sas
  @brief Searches all columns in a library
  @details
  Scans a set of libraries and creates a dataset containing all source tables
    containing one or more of a particular set of columns

  Usage:

      %mp_searchcols(libs=sashelp work, cols=name sex age)

  @param libs=
  @version 9.2
  @author Allan Bowe
**/

%macro mp_searchcols(libs=sashelp
  ,cols=
  ,outds=mp_searchcols
)/*/STORE SOURCE*/;

%put &sysmacroname process began at %sysfunc(datetime(),datetime19.);

/* get the list of tables in the library */
proc sql;
create table _data_ as
  select distinct upcase(libname) as libname
    , upcase(memname) as memname
    , upcase(name) as name
  from dictionary.columns
%if %sysevalf(%superq(libs)=,boolean)=0 %then %do;
  where upcase(libname) in ("IMPOSSIBLE",
  %local x;
  %do x=1 %to %sysfunc(countw(&libs));
   "%upcase(%scan(&libs,&x))"
  %end;
  )
%end;
  order by 1,2,3;

data &outds;
  set &syslast;
  length cols matchcols $32767;
  cols=upcase(symget('cols'));
  colcount=countw(cols);
  by libname memname name;
  if _n_=1 then do;
    putlog "Searching libs: &libs";
    putlog "Searching cols: " cols;
  end;
  if first.memname then do;
    sumcols=0;
    retain matchcols;
    matchcols='';
  end;
  if findw(cols,name,,'spit') then do;
    sumcols+1;
    matchcols=cats(matchcols)!!' '!!cats(name);
  end;
  if last.memname then do;
    if sumcols>0 then output;
    if sumcols=colcount then putlog "Full Match: " libname memname;
  end;
  keep libname memname sumcols matchcols;
run;

proc sort; by descending sumcols memname libname; run;

%put &sysmacroname process finished at %sysfunc(datetime(),datetime19.);

%mend;
/**
  @file
  @brief Searches all data in a library
  @details
  Scans an entire library and creates a copy of any table
    containing a specific string OR numeric value.  Only 
    matching records are written out.
    If both a string and numval are provided, the string
    will take precedence.

  Usage:

      %mp_searchdata(lib=sashelp, string=Jan)
      %mp_searchdata(lib=sashelp, numval=1)


  Outputs zero or more tables to an MPSEARCH library with specific records.

  @param lib=  the libref to search (should be already assigned)
  @param ds= the dataset to search (leave blank to search entire library)
  @param string= the string value to search
  @param numval= the numeric value to search (must be exact)
  @param outloc= the directory in which to create the output datasets with matching
    rows.  Will default to a subfolder in the WORK library.
  @param outobs= set to a positive integer to restrict the number of observations
  @param filter_text= add a (valid) filter clause to further filter the results

  <h4> Dependencies </h4>
  @li mf_getvarlist.sas
  @li mf_getvartype.sas
  @li mf_mkdir.sas
  @li mf_nobs.sas

  @version 9.2
  @author Allan Bowe
**/

%macro mp_searchdata(lib=sashelp
  ,ds= 
  ,string= /* the query will use a contains (?) operator */
  ,numval= /* numeric must match exactly */
  ,outloc=%sysfunc(pathname(work))/mpsearch
  ,outobs=-1
  ,filter_text=%str(1=1)
)/*/STORE SOURCE*/;

%local table_list table table_num table colnum col start_tm check_tm vars type coltype;
%put process began at %sysfunc(datetime(),datetime19.);

%if &syscc ge 4 %then %do;
  %put %str(WAR)NING: SYSCC=&syscc on macro entry;
  %return;
%end;

%if &string = %then %let type=N;
%else %let type=C;

%mf_mkdir(&outloc)
libname mpsearch "&outloc";

/* get the list of tables in the library */
proc sql noprint;
select distinct memname into: table_list separated by ' '
  from dictionary.tables 
  where upcase(libname)="%upcase(&lib)"
%if &ds ne %then %do;
  and upcase(memname)=%upcase("&ds")
%end;
  ;
/* check that we have something to check */
proc sql 
%if &outobs>-1 %then %do;
  outobs=&outobs
%end;
;
%if %length(&table_list)=0 %then %put library &lib contains no tables!;
/* loop through each table */
%else %do table_num=1 %to %sysfunc(countw(&table_list,%str( )));
  %let table=%scan(&table_list,&table_num,%str( ));
  %let vars=%mf_getvarlist(&lib..&table);
  %if %length(&vars)=0 %then %do;
    %put NO COLUMNS IN &lib..&table!  This will be skipped.;
  %end;
  %else %do;
    %let check_tm=%sysfunc(datetime());
    /* build sql statement */
    create table mpsearch.&table as select * from &lib..&table
      where %unquote(&filter_text) and 
    (0
    /* loop through columns */
    %do colnum=1 %to %sysfunc(countw(&vars,%str( )));
      %let col=%scan(&vars,&colnum,%str( ));
      %let coltype=%mf_getvartype(&lib..&table,&col);
      %if &type=C and &coltype=C %then %do;
        /* if a char column, see if it contains the string */
        or ("&col"n ? "&string")
      %end;
      %else %if &type=N and &coltype=N %then %do;
        /* if numeric match exactly */
        or ("&col"n = &numval)
      %end;
    %end;
    );
    %put Search query for &table took %sysevalf(%sysfunc(datetime())-&check_tm) seconds;
    %if &sqlrc ne 0 %then %do;
      %put %str(WAR)NING: SQLRC=&sqlrc when processing &table;
      %return;
    %end;
    %if %mf_nobs(mpsearch.&table)=0 %then %do;
      drop table mpsearch.&table;
    %end;
  %end;
%end;

%put process finished at %sysfunc(datetime(),datetime19.);

%mend;
/**
  @file
  @brief Logs a key value pair a control dataset
  @details If the dataset does not exist, it is created.  Usage:

    %mp_setkeyvalue(someindex,22,type=N)
    %mp_setkeyvalue(somenewindex,somevalue)

  <h4> Dependencies </h4>
  @li mf_existds.sas

  @param key Provide a key on which to perform the lookup
  @param value Provide a value
  @param type= either C or N will populate valc and valn respectively.  C is
               default.
  @param libds= define the target table to hold the parameters

  @version 9.2
  @author Allan Bowe
  @source https://github.com/sasjs/core

**/

%macro mp_setkeyvalue(key,value,type=C,libds=work.mp_setkeyvalue
)/*/STORE SOURCE*/;

  %if not (%mf_existds(&libds)) %then %do;
    data &libds (index=(key/unique));
      length key $32 valc $256 valn 8 type $1;
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

%mend;/**
  @file
  @brief Capture session start / finish times and request details
  @details For details, see http://www.rawsas.com/2015/09/logging-of-stored-process-server.html.
    Requires a base table in the following structure (name can be changed):

    proc sql;
    create table &libds(
       request_dttm num not null format=datetime.
      ,status_cd char(4) not null
      ,_metaperson varchar(100) not null
      ,_program varchar(500)
      ,sysuserid varchar(50)
      ,sysjobid varchar(12)
      ,_sessionid varchar(50)
    );

    Called via STP init / term events (configurable in SMC) as follows:

    %mp_stprequests(status_cd=INIT, libds=YOURLIB.DATASET )


  @param status_cd= Use INIT for INIT and TERM for TERM events
  @param libds= Location of base table (library.dataset).  To minimise risk
    of table locks, we HIGHLY recommend using a database (NOT a SAS dataset).
    THE LIBRARY SHOULD BE ASSIGNED ALREADY - eg in autoexec or earlier in the
    init program proper.

  @version 9.2
  @author Allan Bowe
  @source https://github.com/sasjs/core

**/

%macro mp_stprequests(status_cd= /* $4 eg INIT or TERM */
      ,libds=somelib.stp_requests /* base table location  */
)/*/STORE SOURCE*/;

  /* set nosyntaxcheck so the code runs regardless */
  %local etls_syntaxcheck;
  %let etls_syntaxcheck=%sysfunc(getoption(syntaxcheck));
  options nosyntaxcheck;

  data ;
    if 0 then set &libds;
    request_dttm=datetime();
    status_cd="&status_cd";
    _METAPERSON="&_metaperson";
    _PROGRAM="&_program";
    SYSUSERID="&sysuserid";
    SYSJOBID="&sysjobid";
  %if not %symexist(_SESSIONID) %then %do;
    /* session id is stored in the replay variable but needs to be extracted */
    _replay=symget('_replay');
    _replay=subpad(_replay,index(_replay,'_sessionid=')+11,length(_replay));
    index=index(_replay,'&')-1;
    if index=-1 then index=length(_replay);
    _replay=substr(_replay,1,index);
    _SESSIONID=_replay;
    drop _replay index;
  %end;
  %else %do;
    /* explicitly created sessions are automatically available */
    _SESSIONID=symget('_SESSIONID');
  %end;
    output;
    stop;
  run;

  proc append base=&libds data=&syslast nowarn;run;

  options &etls_syntaxcheck;
%mend;/**
  @file
  @brief Streams a file to _webout according to content type
  @details Will set headers using appropriate functions (SAS 9 vs Viya) and send
  content as a binary stream.

  Usage:

      filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

      %mp_streamfile(contenttype=csv,inloc=/some/where.txt,outname=myfile.txt)

  <h4> Dependencies </h4>
  @li mf_getplatform.sas
  @li mp_binarycopy.sas

  @param contenttype= Either TEXT, ZIP, CSV, EXCEL (default TEXT)
  @param inloc= /path/to/file.ext to be sent
  @param inref= fileref of file to be sent (if provided, overrides `inloc`)
  @param outname= the name of the file, as downloaded by the browser

  @author Allan Bowe
  @source https://github.com/sasjs/core

**/

%macro mp_streamfile(
  contenttype=TEXT
  ,inloc=
  ,inref=0
  ,outname=
)/*/STORE SOURCE*/;

%let contentype=%upcase(&contenttype);
%local platform; %let platform=%mf_getplatform();

%if &contentype=ZIP %then %do;
  %if &platform=SASMETA %then %do;
    data _null_;
      rc=stpsrv_header('Content-type','application/zip');
      rc=stpsrv_header('Content-disposition',"attachment; filename=&outname");
    run;
  %end;
  %else %if &platform=SASVIYA %then %do;
    filename _webout filesrvc parenturi="&SYS_JES_JOB_URI" name='_webout.zip'
      contenttype='application/zip'
      contentdisp="attachment; filename=&outname";
  %end;
%end;
%else %if &contentype=EXCEL %then %do;
  /* suitable for XLS format */
  %if &platform=SASMETA %then %do;
    data _null_;
      rc=stpsrv_header('Content-type','application/vnd.ms-excel');
      rc=stpsrv_header('Content-disposition',"attachment; filename=&outname");
    run;
  %end;
  %else %if &platform=SASVIYA %then %do;
    filename _webout filesrvc parenturi="&SYS_JES_JOB_URI" name='_webout.xls'
      contenttype='application/vnd.ms-excel'
      contentdisp="attachment; filename=&outname";
  %end;
%end;
%else %if &contentype=XLSX %then %do;
  %if &platform=SASMETA %then %do;
    data _null_;
      rc=stpsrv_header('Content-type','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      rc=stpsrv_header('Content-disposition',"attachment; filename=&outname");
    run;
  %end;
  %else %if &platform=SASVIYA %then %do;
    filename _webout filesrvc parenturi="&SYS_JES_JOB_URI" name='_webout.xls'
      contenttype='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      contentdisp="attachment; filename=&outname";
  %end;
%end;
%else %if &contentype=TEXT %then %do;
  %if &platform=SASMETA %then %do;
    data _null_;
      rc=stpsrv_header('Content-type','application/text');
      rc=stpsrv_header('Content-disposition',"attachment; filename=&outname");
    run;
  %end;
  %else %if &platform=SASVIYA %then %do;
    filename _webout filesrvc parenturi="&SYS_JES_JOB_URI" name='_webout.txt'
      contenttype='application/text'
      contentdisp="attachment; filename=&outname";
  %end;
%end;
%else %if &contentype=CSV %then %do;
  %if &platform=SASMETA %then %do;
    data _null_;
      rc=stpsrv_header('Content-type','application/csv');
      rc=stpsrv_header('Content-disposition',"attachment; filename=&outname");
    run;
  %end;
  %else %if &platform=SASVIYA %then %do;
    filename _webout filesrvc parenturi="&SYS_JES_JOB_URI" name='_webout.txt'
      contenttype='application/csv'
      contentdisp="attachment; filename=&outname";
  %end;
%end;
%else %if &contentype=HTML %then %do;
  %if &platform=SASVIYA %then %do;
    filename _webout filesrvc parenturi="&SYS_JES_JOB_URI" name="_webout.json"
      contenttype="text/html";
  %end;
%end;
%else %do;
  %put %str(ERR)OR: Content Type &contenttype NOT SUPPORTED by &sysmacroname!;
  %return;
%end;

%if &inref ne 0 %then %do;
 %mp_binarycopy(inref=&inref,outref=_webout)
%end;
%else %do;
 %mp_binarycopy(inloc="&inloc",outref=_webout)
%end;

%mend;/**
  @file
  @brief Recursively scans a directory tree to get all subfolders and content
  @details
  Usage:

      %mp_tree(dir=/tmp, outds=work.tree)

  Credits:

  * Roger Deangelis, https://communities.sas.com/t5/SAS-Programming/listing-all-files-within-a-directory-and-subdirectories/m-p/332616/highlight/true#M74887
  * Tom, https://communities.sas.com/t5/SAS-Programming/listing-all-files-of-all-types-from-all-subdirectories/m-p/334113/highlight/true#M75419


  @param dir= Directory to be scanned (default=/tmp)
  @param outds= Dataset to create (default=work.mp_tree)

  @returns outds contains the following variables:

   - `dir`: a flag (1/0) to say whether it is a directory or not.  This is not
     reliable - folders that you do not have permission to open will be flagged
     as directories.
   - `ext`: file extension
   - `filename`: file name
   - `dirname`: directory name
   - `fullpath`: directory + file name

  @version 9.2
**/

%macro mp_tree(dir=/tmp
  ,outds=work.mp_tree
)/*/STORE SOURCE*/;

data &outds ;
  length dir 8 ext filename dirname $256 fullpath $512 ;
  call missing(of _all_);
  fullpath = "&dir";
run;

%local sep;
%if &sysscp=WIN or &SYSSCP eq DNTHOST %then %let sep=\;
%else %let sep=/;

data &outds ;
  modify &outds ;
  retain sep "&sep";
  rc=filename('tmp',fullpath);
  dir_id=dopen('tmp');
  dir = (dir_id ne 0) ;
  if dir then dirname=fullpath;
  else do;
    filename=scan(fullpath,-1,sep) ;
    dirname =substrn(fullpath,1,length(fullpath)-length(filename));
    if index(filename,'.')>1 then ext=scan(filename,-1,'.');
  end;
  replace;
  if dir then do;
    do i=1 to dnum(dir_id);
      fullpath=cats(dirname,sep,dread(dir_id,i));
      output;
    end;
    rc=dclose(dir_id);
  end;
  rc=filename('tmp');
run;

%mend;/**
  @file mp_unzip.sas
  @brief Unzips a zip file
  @details Opens the zip file and copies all the contents to another directory.
    It is not possible to retain permissions / timestamps, also the BOF marker
    is lost so it cannot extract binary files.

    Usage:

      filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

      %mp_unzip(ziploc="/some/file.zip",outdir=/some/folder)

  <h4> Dependencies </h4>
  @li mf_mkdir.sas
  @li mf_getuniquefileref.sas

  @param ziploc= fileref or quoted full path to zip file ("/path/to/file.zip")
  @param outdir= directory in which to write the outputs (created if non existant)

  @version 9.4
  @author Allan Bowe
  @source https://github.com/sasjs/core

**/

%macro mp_unzip(
  ziploc=
  ,outdir=%sysfunc(pathname(work))
)/*/STORE SOURCE*/;

%local fname1 fname2 fname3;
%let fname1=%mf_getuniquefileref();
%let fname2=%mf_getuniquefileref();
%let fname3=%mf_getuniquefileref();

filename &fname1 ZIP &ziploc; * Macro variable &datazip would be read from the file*;

/* Read the "members" (files) from the ZIP file */
data _data_(keep=memname isFolder);
  length memname $200 isFolder 8;
  fid=dopen("&fname1");
  if fid=0 then stop;
  memcount=dnum(fid);
  do i=1 to memcount;
    memname=dread(fid,i);
    /* check for trailing / in folder name */
    isFolder = (first(reverse(trim(memname)))='/');
    output;
  end;
  rc=dclose(fid);
run;
filename &fname1 clear;

/* loop through each entry and either create the subfolder or extract member */
data _null_;
  set &syslast;
  if isFolder then call execute('%mf_mkdir(&outdir/'!!memname!!')');
  else call execute('filename &fname2 zip &ziploc member='
    !!quote(trim(memname))!!';filename &fname3 "&outdir/'
    !!trim(memname)!!'" recfm=n;data _null_; rc=fcopy("&fname2","&fname3");run;'
    !!'filename &fname2 clear; filename &fname3 clear;');
run;

%mend;/**
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
/**
  @file
  @brief Creates a zip file
  @details For DIRECTORY usage, will ignore subfolders. For DATASET usage,
    provide a column that contains the full file path to each file to be zipped.

    %mp_zip(in=myzips,type=directory,outname=myDir)
    %mp_zip(in=/my/file/path.txt,type=FILE,outname=myFile)
    %mp_zip(in=SOMEDS,incol=FPATH,type=DATASET,outname=myFile)

  If you are sending zipped output to the _webout destination as part of an STP
  be sure that _debug is not set (else the SPWA will send non zipped content
  as well).

  <h4> Dependencies </h4>
  @li mp_dirlist.sas

  @param in= unquoted filepath, dataset of files or directory to zip
  @param type= FILE, DATASET, DIRECTORY. (FILE / DATASET not ready yet)
  @param outname= output file to create, without .zip extension
  @param outpath= location for output zip file
  @param incol= if DATASET input, say which column contains the filepath

  @version 9.2
  @author Allan Bowe
  @source https://github.com/sasjs/core

**/

%macro mp_zip(
  in=
  ,type=FILE
  ,outname=FILE
  ,outpath=%sysfunc(pathname(WORK))
  ,incol=
  ,debug=NO
)/*/STORE SOURCE*/;

%let type=%upcase(&type);
%local ds;

ods package open nopf;

%if &type=FILE %then %do;
  ods package add file="&in" mimetype="application/x-compress";
%end;
%else %if &type=DIRECTORY %then %do;
  %mp_dirlist(path=&in,outds=_data_)
  %let ds=&syslast;
  data _null_;
    set &ds;
    length __command $4000;
    if file_or_folder='file';
    command=cats('ods package add file="',filepath
      ,'" mimetype="application/x-compress";');
    call execute(command);
  run;
  /* tidy up */
  %if &debug=NO %then %do;
    proc sql; drop table &ds;quit;
  %end;
%end;
%else %if &type=DATASET %then %do;
  data _null_;
    set &in;
    length __command $4000;
    command=cats('ods package add file="',&incol
      ,'" mimetype="application/x-compress";');
    call execute(command);
  run;
  ods package add file="&in" mimetype="application/x-compress";
%end;


ods package publish archive properties
  (archive_name="&outname..zip" archive_path="&outpath");
ods package close;

%mend;/**
  @file mm_adduser2group.sas
  @brief Adds a user to a group
  @details Adds a user to a metadata group.  The macro first checks whether the
    user is in that group, and if not, the user is added.

  Usage:

      %mm_adduser2group(user=sasdemo
        ,group=someGroup)


  @param user= the user name (not displayname)
  @param group= the group to which to add the user
  @param mdebug= set to 1 to show debug info in log

  @warning the macro does not check inherited group memberships - it looks at
    direct members only

  @version 9.3
  @author Allan Bowe

**/

%macro mm_adduser2group(user=
  ,group=
  ,mdebug=0
);
/* first, check if user is in group already exists */
%local check uuri guri;
%let check=ok;

data _null_;
  length uri type msg $256;
  call missing(of _all_);
  rc=metadata_getnobj("omsobj:Person?@Name='&user'",1,uri);
  if rc<=0 then do;
    msg="%str(WARN)ING: rc="!!cats(rc)!!" &user not found "!!
        ", or there was an err reading the repository.";
    call symputx('check',msg);
    putlog msg;
    stop;
  end;
  call symputx('uuri',scan(uri,2,'\'));

  rc=metadata_getnobj("omsobj:IdentityGroup?@Name='&group'",1,uri);
  if rc<=0 then do;
    msg="%str(WARN)ING: rc="!!cats(rc)!!" &group not found "!!
        ", or there was an err reading the repository.";
    call symputx('check',msg);
    putlog msg;
    stop;
  end;
  call symputx('guri',scan(uri,2,'\'));

  rc=metadata_getnobj("omsobj:Person?Person[@Name='&user'][IdentityGroups/*[@Name='&group']]",1,uri);
  if rc=0 then do;
    msg="%str(WARN)ING: rc="!!cats(rc)!!" &user already in &group";
    call symputx('check',msg);
    stop;
  end;

  if &mdebug ne 0 then put (_all_)(=);
run;

/* stop if issues */
%if %quote(&check) ne %quote(ok) %then %do;
  %put &check;
  %return;
%end;

%if &syscc ge 4 %then %do;
  %put WARNING:  SYSCC=&syscc, exiting &sysmacroname;
  %return;
%end;


filename __us2grp temp;

proc metadata in= "<UpdateMetadata><Reposid>$METAREPOSITORY</Reposid><Metadata>
    <Person Id='&uuri'><IdentityGroups><IdentityGroup ObjRef='&guri' />
    </IdentityGroups></Person></Metadata>
    <NS>SAS</NS><Flags>268435456</Flags></UpdateMetadata>"
  out=__us2grp verbose;
run;

%if &mdebug ne 0 %then %do;
  /* write the response to the log for debugging */
  data _null_;
    infile __us2grp lrecl=32767;
    input;
    put _infile_;
  run;
%end;

filename __us2grp clear;

%mend;/**
  @file
  @brief Assigns library directly using details from metadata
  @details Queries metadata to get the libname definition then allocates the
    library directly (ie, not using the META engine).
  usage:

      %mm_assignDirectLib(MyLib);
      data x; set mylib.sometable; run;

      %mm_assignDirectLib(MyDB,open_passthrough=MyAlias);
      create table MyTable as
        select * from connection to MyAlias( select * from DBTable);
      disconnect from MyAlias;
      quit;

  <h4> Dependencies </h4>
  @li mf_getengine.sas
  @li mp_abort.sas

  @param libref the libref (not name) of the metadata library
  @param open_passthrough= provide an alias to produce the CONNECT TO statement
    for the relevant external database
  @param sql_options= an override default output fileref to avoid naming clash
  @param mDebug= set to 1 to show debug messages in the log
  @param mAbort= set to 1 to call %mp_abort().

  @returns libname statement

  @version 9.2
  @author Allan Bowe

**/

%macro mm_assigndirectlib(
     libref /* libref to assign from metadata */
    ,open_passthrough= /* provide an alias to produce the
                          CONNECT TO statement for the
                          relevant external database */
    ,sql_options= /* add any options to add to proc sql statement eg outobs=
                      (only valid for pass through) */
    ,mDebug=0
    ,mAbort=0
)/*/STORE SOURCE*/;

%local mD;
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing mm_assigndirectlib.sas;
%&mD.put _local_;

%if &mAbort=1 %then %let mAbort=;
%else %let mAbort=%str(*);

%&mD.put NOTE: Creating direct (non META) connection to &libref library;

%local cur_engine;
%let cur_engine=%mf_getengine(&libref);
%if &cur_engine ne META and &cur_engine ne %then %do;
  %put NOTE:  &libref already has a direct (&cur_engine) libname connection;
  %return;
%end;
%else %if %upcase(&libref)=WORK %then %do;
  %put NOTE: We already have a direct connection to WORK :-) ;
  %return;
%end;

/* need to determine the library ENGINE first */
%local engine;
data _null_;
  length lib_uri engine $256;
  call missing (of _all_);
  /* get URI for the particular library */
  rc1=metadata_getnobj("omsobj:SASLibrary?@Libref ='&libref'",1,lib_uri);
  /* get the Engine attribute of the previous object */
  rc2=metadata_getattr(lib_uri,'Engine',engine);
  putlog "mm_assigndirectlib for &libref:" rc1= lib_uri= rc2= engine=;
  call symputx("liburi",lib_uri,'l');
  call symputx("engine",engine,'l');
run;

/* now obtain engine specific connection details */
%if &engine=BASE %then %do;
  %&mD.put NOTE: Retrieving BASE library path;
  data _null_;
    length up_uri $256 path cat_path $1024;
    retain cat_path;
    call missing (of _all_);
    /* get all the filepaths of the UsingPackages association  */
    i=1;
    rc3=metadata_getnasn("&liburi",'UsingPackages',i,up_uri);
    do while (rc3>0);
      /* get the DirectoryName attribute of the previous object */
      rc4=metadata_getattr(up_uri,'DirectoryName',path);
      if i=1 then path = '("'!!trim(path)!!'" ';
      else path =' "'!!trim(path)!!'" ';
      cat_path = trim(cat_path) !! " " !! trim(path) ;
      i+1;
        rc3=metadata_getnasn("&liburi",'UsingPackages',i,up_uri);
    end;
    cat_path = trim(cat_path) !! ")";
    &mD.putlog "NOTE: Getting physical path for &libref library";
    &mD.putlog rc3= up_uri= rc4= cat_path= path=;
    &mD.putlog "NOTE: Libname cmd will be:";
    &mD.putlog "libname &libref" cat_path;
    call symputx("filepath",cat_path,'l');
  run;

  %if %sysevalf(&sysver<9.4) %then %do;
   libname &libref &filepath;
  %end;
  %else %do;
    /* apply the new filelocks option to cater for temporary locks */
    libname &libref &filepath filelockwait=5;
  %end;

%end;
%else %if &engine=REMOTE %then %do;
  data x;
    length rcCon rcProp rc k 3 uriCon uriProp PropertyValue PropertyName Delimiter $256 properties $2048;
    retain properties;
    rcCon = metadata_getnasn("&liburi", "LibraryConnection", 1, uriCon);

    rcProp = metadata_getnasn(uriCon, "Properties", 1, uriProp);

    k = 1;
    rcProp = metadata_getnasn(uriCon, "Properties", k, uriProp);
    do while (rcProp > 0);
      rc = metadata_getattr(uriProp , "DefaultValue",PropertyValue);
      rc = metadata_getattr(uriProp , "PropertyName",PropertyName);
      rc = metadata_getattr(uriProp , "Delimiter",Delimiter);
      properties = trim(properties) !! " " !! trim(PropertyName) !! trim(Delimiter) !! trim(PropertyValue);
        output;
      k+1;
      rcProp = metadata_getnasn(uriCon, "Properties", k, uriProp);
    end;
    %&mD.put NOTE: Getting properties for REMOTE SHARE &libref library;
    &mD.put _all_;
    %&mD.put NOTE: Libname cmd will be:;
    %&mD.put libname &libref &engine &properties slibref=&libref;
    call symputx ("properties",trim(properties),'l');
  run;

  libname &libref &engine &properties slibref=&libref;

%end;

%else %if &engine=OLEDB %then %do;
  %&mD.put NOTE: Retrieving OLEDB connection details;
  data _null_;
    length domain datasource provider properties schema
      connx_uri domain_uri conprop_uri lib_uri schema_uri value $256.;
    call missing (of _all_);
    /* get source connection ID */
    rc=metadata_getnasn("&liburi",'LibraryConnection',1,connx_uri);
    /* get connection domain */
    rc1=metadata_getnasn(connx_uri,'Domain',1,domain_uri);
    rc2=metadata_getattr(domain_uri,'Name',domain);
    &mD.putlog / 'NOTE: ' // 'NOTE- connection id: ' connx_uri ;
    &mD.putlog 'NOTE- domain: ' domain;
    /* get DSN and PROVIDER from connection properties */
    i=0;
    do until (rc<0);
      i+1;
      rc=metadata_getnasn(connx_uri,'Properties',i,conprop_uri);
      rc2=metadata_getattr(conprop_uri,'Name',value);
      if value='Connection.OLE.Property.DATASOURCE.Name.xmlKey.txt' then do;
         rc3=metadata_getattr(conprop_uri,'DefaultValue',datasource);
      end;
      else if value='Connection.OLE.Property.PROVIDER.Name.xmlKey.txt' then do;
         rc4=metadata_getattr(conprop_uri,'DefaultValue',provider);
      end;
      else if value='Connection.OLE.Property.PROPERTIES.Name.xmlKey.txt' then do;
         rc5=metadata_getattr(conprop_uri,'DefaultValue',properties);
      end;
    end;
    &mD.putlog 'NOTE- dsn/provider/properties: ' /
                    datasource provider properties;
    &mD.putlog 'NOTE- schema: ' schema // 'NOTE-';

    /* get SCHEMA */
    rc6=metadata_getnasn("&liburi",'UsingPackages',1,lib_uri);
    rc7=metadata_getattr(lib_uri,'SchemaName',schema);
    call symputx('SQL_domain',domain,'l');
    call symputx('SQL_dsn',datasource,'l');
    call symputx('SQL_provider',provider,'l');
    call symputx('SQL_properties',properties,'l');
    call symputx('SQL_schema',schema,'l');
  run;

  %if %length(&open_passthrough)>0 %then %do;
    proc sql &sql_options;
    connect to OLEDB as &open_passthrough(INSERT_SQL=YES
      /* need additional properties to make this work */
        properties=('Integrated Security'=SSPI
                    'Persist Security Info'=True
                   %sysfunc(compress(%str(&SQL_properties),%str(())))
                   )
      DATASOURCE=&sql_dsn PROMPT=NO
      PROVIDER=&sql_provider SCHEMA=&sql_schema CONNECTION = GLOBAL);
  %end;
  %else %do;
    LIBNAME &libref OLEDB  PROPERTIES=&sql_properties
      DATASOURCE=&sql_dsn  PROVIDER=&sql_provider SCHEMA=&sql_schema
    %if %length(&sql_domain)>0 %then %do;
       authdomain="&sql_domain"
    %end;
       connection=shared;
  %end;
%end;
%else %if &engine=ODBC %then %do;
  &mD.%put NOTE: Retrieving ODBC connection details;
  data _null_;
    length connx_uri conprop_uri value datasource up_uri schema $256.;
    call missing (of _all_);
    /* get source connection ID */
    rc=metadata_getnasn("&liburi",'LibraryConnection',1,connx_uri);
    /* get connection properties */
    i=0;
    do until (rc2<0);
      i+1;
      rc2=metadata_getnasn(connx_uri,'Properties',i,conprop_uri);
      rc3=metadata_getattr(conprop_uri,'Name',value);
      if value='Connection.ODBC.Property.DATASRC.Name.xmlKey.txt' then do;
         rc4=metadata_getattr(conprop_uri,'DefaultValue',datasource);
         rc2=-1;
      end;
    end;
    /* get SCHEMA */
    rc6=metadata_getnasn("&liburi",'UsingPackages',1,up_uri);
    rc7=metadata_getattr(up_uri,'SchemaName',schema);
    &mD.put rc= connx_uri= rc2= conprop_uri= rc3= value= rc4= datasource=
      rc6= up_uri= rc7= schema=;

    call symputx('SQL_schema',schema,'l');
    call symputx('SQL_dsn',datasource,'l');
  run;

  %if %length(&open_passthrough)>0 %then %do;
    proc sql &sql_options;
    connect to ODBC as &open_passthrough
      (INSERT_SQL=YES DATASRC=&sql_dsn. CONNECTION=global);
  %end;
  %else %do;
    libname &libref ODBC DATASRC=&sql_dsn SCHEMA=&sql_schema;
  %end;
%end;
%else %if &engine=POSTGRES %then %do;
  %put NOTE: Obtaining POSTGRES library details;
  data _null_;
    length database ignore_read_only_columns direct_exe preserve_col_names
      preserve_tab_names server schema authdomain user password
      prop name value uri urisrc $256.;
    call missing (of _all_);
    /* get database value */
    prop='Connection.DBMS.Property.DB.Name.xmlKey.txt';
    rc=metadata_getprop("&liburi",prop,database,"");
    if database^='' then database='database='!!quote(trim(database));
    call symputx('database',database,'l');

    /* get IGNORE_READ_ONLY_COLUMNS value */
    prop='Library.DBMS.Property.DBIROC.Name.xmlKey.txt';
    rc=metadata_getprop("&liburi",prop,ignore_read_only_columns,"");
    if ignore_read_only_columns^='' then ignore_read_only_columns=
      'ignore_read_only_columns='!!ignore_read_only_columns;
    call symputx('ignore_read_only_columns',ignore_read_only_columns,'l');

    /* get DIRECT_EXE value */
    prop='Library.DBMS.Property.DirectExe.Name.xmlKey.txt';
    rc=metadata_getprop("&liburi",prop,direct_exe,"");
    if direct_exe^='' then direct_exe='direct_exe='!!direct_exe;
    call symputx('direct_exe',direct_exe,'l');

    /* get PRESERVE_COL_NAMES value */
    prop='Library.DBMS.Property.PreserveColNames.Name.xmlKey.txt';
    rc=metadata_getprop("&liburi",prop,preserve_col_names,"");
    if preserve_col_names^='' then preserve_col_names=
      'preserve_col_names='!!preserve_col_names;
    call symputx('preserve_col_names',preserve_col_names,'l');

    /* get PRESERVE_TAB_NAMES value */
    /* be careful with PRESERVE_TAB_NAMES=YES - it will mean your table will
       become case sensitive!! */
    prop='Library.DBMS.Property.PreserveTabNames.Name.xmlKey.txt';
    rc=metadata_getprop("&liburi",prop,preserve_tab_names,"");
    if preserve_tab_names^='' then preserve_tab_names=
      'preserve_tab_names='!!preserve_tab_names;
    call symputx('preserve_tab_names',preserve_tab_names,'l');

    /* get SERVER value */
    if metadata_getnasn("&liburi","LibraryConnection",1,uri)>0 then do;
      prop='Connection.DBMS.Property.SERVER.Name.xmlKey.txt';
      rc=metadata_getprop(uri,prop,server,"");
    end;
    if server^='' then server='server='!!server;
    call symputx('server',server,'l');

    /* get SCHEMA value */
    if metadata_getnasn("&liburi","UsingPackages",1,uri)>0 then do;
      rc=metadata_getattr(uri,"SchemaName",schema);
    end;
    if schema^='' then schema='schema='!!schema;
    call symputx('schema',schema,'l');

    /* get AUTHDOMAIN value */
    /* this is only useful if the user account contains that auth domain
    if metadata_getnasn("&liburi","DefaultLogin",1,uri)>0 then do;
      rc=metadata_getnasn(uri,"Domain",1,urisrc);
      rc=metadata_getattr(urisrc,"Name",authdomain);
    end;
    if authdomain^='' then authdomain='authdomain='!!quote(trim(authdomain));
    */
    call symputx('authdomain',authdomain,'l');

    /* get user & pass */
    if authdomain='' & metadata_getnasn("&liburi","DefaultLogin",1,uri)>0 then
    do;
      rc=metadata_getattr(uri,"UserID",user);
      rc=metadata_getattr(uri,"Password",password);
    end;
    if user^='' then do;
      user='user='!!quote(trim(user));
      password='password='!!quote(trim(password));
    end;
    call symputx('user',user,'l');
    call symputx('password',password,'l');

    &md.put _all_;
  run;

  %if %length(&open_passthrough)>0 %then %do;
    %put WARNING:  Passthrough option for postgres not yet supported;
    %return;
  %end;
  %else %do;
    %if &mdebug=1 %then %do;
      %put NOTE: Executing the following:/;
      %put NOTE- libname &libref POSTGRES &database &ignore_read_only_columns;
      %put NOTE-   &direct_exe &preserve_col_names &preserve_tab_names;
      %put NOTE-   &server &schema &authdomain &user &password //;
    %end;
    libname &libref POSTGRES &database &ignore_read_only_columns &direct_exe
      &preserve_col_names &preserve_tab_names &server &schema &authdomain
      &user &password;
  %end;
%end;
%else %if &engine=ORACLE %then %do;
  %put NOTE: Obtaining &engine library details;
  data _null_;
    length assocuri1 assocuri2 assocuri3 authdomain path schema $256;
    call missing (of _all_);

    /* get auth domain */
    rc=metadata_getnasn("&liburi",'LibraryConnection',1,assocuri1);
    rc=metadata_getnasn(assocuri1,'Domain',1,assocuri2);
    rc=metadata_getattr(assocuri2,"Name",authdomain);
    call symputx('authdomain',authdomain,'l');

    /* path */
    rc=metadata_getprop(assocuri1,'Connection.Oracle.Property.PATH.Name.xmlKey.txt',path);
    call symputx('path',path,'l');

    /* schema */
    rc=metadata_getnasn("&liburi",'UsingPackages',1,assocuri3);
    rc=metadata_getattr(assocuri3,'SchemaName',schema);
    call symputx('schema',schema,'l');
  run;
  %put NOTE: Executing the following:/; %put NOTE-;
  %put NOTE- libname &libref ORACLE path=&path schema=&schema authdomain=&authdomain;
  %put NOTE-;
  libname &libref ORACLE path=&path schema=&schema authdomain=&authdomain;
%end;
%else %if &engine=SQLSVR %then %do;
  %put NOTE: Obtaining &engine library details;
  data _null;
    length assocuri1 assocuri2 assocuri3 authdomain path schema userid passwd $256;
    call missing (of _all_);
 
    rc=metadata_getnasn("&liburi",'DefaultLogin',1,assocuri1);
    rc=metadata_getattr(assocuri1,"UserID",userid);
    rc=metadata_getattr(assocuri1,"Password",passwd);
    call symputx('user',userid,'l');
    call symputx('pass',passwd,'l');
 
    /* path */
    rc=metadata_getnasn("&liburi",'LibraryConnection',1,assocuri2);
    rc=metadata_getprop(assocuri2,'Connection.SQL.Property.Datasrc.Name.xmlKey.txt',path);
    call symputx('path',path,'l');
 
    /* schema */
    rc=metadata_getnasn("&liburi",'UsingPackages',1,assocuri3);
    rc=metadata_getattr(assocuri3,'SchemaName',schema);
    call symputx('schema',schema,'l');
  run;

  %put NOTE: Executing the following:/; %put NOTE-;
  %put NOTE- libname &libref SQLSVR datasrc=&path schema=&schema user="&user" pass="XXX";
  %put NOTE-;

  libname &libref SQLSVR datasrc=&path schema=&schema user="&user" pass="&pass" ;
%end;
%else %if &engine=TERADATA %then %do;
  %put NOTE: Obtaining &engine library details;
  data _null;
    length assocuri1 assocuri2 assocuri3 authdomain path schema userid passwd $256;
    call missing (of _all_);
 
        /* get auth domain */
    rc=metadata_getnasn("&liburi",'LibraryConnection',1,assocuri1);
    rc=metadata_getnasn(assocuri1,'Domain',1,assocuri2);
    rc=metadata_getattr(assocuri2,"Name",authdomain);
    call symputx('authdomain',authdomain,'l');

    /*
    rc=metadata_getnasn("&liburi",'DefaultLogin',1,assocuri1);
    rc=metadata_getattr(assocuri1,"UserID",userid);
    rc=metadata_getattr(assocuri1,"Password",passwd);
    call symputx('user',userid,'l');
    call symputx('pass',passwd,'l');
    */

    /* path */
    rc=metadata_getnasn("&liburi",'LibraryConnection',1,assocuri2);
    rc=metadata_getprop(assocuri2,'Connection.Teradata.Property.SERVER.Name.xmlKey.txt',path);
    call symputx('path',path,'l');
 
    /* schema */
    rc=metadata_getnasn("&liburi",'UsingPackages',1,assocuri3);
    rc=metadata_getattr(assocuri3,'SchemaName',schema);
    call symputx('schema',schema,'l');
  run;

  %put NOTE: Executing the following:/; %put NOTE-;
  %put NOTE- libname &libref TERADATA server=&path schema=&schema authdomain=&authdomain;
  %put NOTE-;

  libname &libref TERADATA server=&path schema=&schema authdomain=&authdomain;
%end;
%else %if &engine= %then %do;
  %put NOTE: Libref &libref is not registered in metadata;
  %&mAbort.mp_abort(
    msg=%str(ERR)OR: Libref &libref is not registered in metadata
    ,mac=mm_assigndirectlib.sas);
  %return;
%end;
%else %do;
  %put WARNING: Engine &engine is currently unsupported;
  %put WARNING- Please contact your support team.;
  %return;
%end;

%mend;
/**
  @file
  @brief Assigns a meta engine library using LIBREF
  @details Queries metadata to get the library NAME which can then be used in
    a libname statement with the meta engine.

  usage:

      %macro mp_abort(iftrue,mac,msg);%put &=msg;%mend;

      %mm_assignlib(SOMEREF)

  <h4> Dependencies </h4>
  @li mp_abort.sas

  @param libref the libref (not name) of the metadata library
  @param mAbort= If not assigned, HARD will call %mp_abort(), SOFT will silently return

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
      ,mac=&sysmacroname
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
%mend;
/**
  @file
  @brief Create an Application object in a metadata folder
  @details Application objects are useful for storing properties in metadata.
    This macro is idempotent - it will not create an object with the same name
    in the same location, twice.

  usage:

      %mm_createapplication(tree=/User Folders/sasdemo
        ,name=MyApp
        ,classidentifier=myAppSeries
        ,params= name1=value1&#x0a;name2=value2&#x0a;emptyvalue=
      )

  @warning application components do not get deleted when removing the container folder!  be sure you have the administrative priviliges to remove this kind of metadata from the SMC plugin (or be ready to do to so programmatically).

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mf_verifymacvars.sas

  @param tree= The metadata folder uri, or the metadata path, in which to
    create the object.  This must exist.
  @param name= Application object name.  Avoid spaces.
  @param ClassIdentifier= the class of applications to which this app belongs
  @param params= name=value pairs which will become public properties of the
    application object. These are delimited using &#x0a; (newline character)

  @param desc= Application description (optional).  Avoid ampersands as these
    are illegal characters (unless they are escapted- eg &amp;)
  @param version= version number of application
  @param frefin= fileref to use (enables change if there is a conflict).  The
    filerefs are left open, to enable inspection after running the
    macro (or importing into an xmlmap if needed).
  @param frefout= fileref to use (enables change if there is a conflict)
  @param mDebug= set to 1 to show debug messages in the log

  @author Allan Bowe

**/

%macro mm_createapplication(
    tree=/User Folders/sasdemo
    ,name=myApp
    ,ClassIdentifier=mcore
    ,desc=Created by mm_createapplication
    ,params= param1=1&#x0a;param2=blah
    ,version=
    ,frefin=mm_in
    ,frefout=mm_out
    ,mDebug=1
    );

%local mD;
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing &sysmacroname..sas;
%&mD.put _local_;

%mf_verifymacvars(tree name)

/**
 * check tree exists
 */

data _null_;
  length type uri $256;
  rc=metadata_pathobj("","&tree","Folder",type,uri);
  call symputx('type',type,'l');
  call symputx('treeuri',uri,'l');
run;

%mp_abort(
  iftrue= (&type ne Tree)
  ,mac=mm_createapplication.sas
  ,msg=Tree &tree does not exist!
)

/**
 * Check object does not exist already
 */
data _null_;
  length type uri $256;
  rc=metadata_pathobj("","&tree/&name","Application",type,uri);
  call symputx('type',type,'l');
  putlog (_all_)(=);
run;

%mp_abort(
  iftrue= (&type = SoftwareComponent)
  ,mac=mm_createapplication.sas
  ,msg=Application &name already exists in &tree!
)


/**
 * Now we can create the application
 */
filename &frefin temp;

/* write header XML */
data _null_;
  file &frefin;
  name=quote(symget('name'));
  desc=quote(symget('desc'));
  ClassIdentifier=quote(symget('ClassIdentifier'));
  version=quote(symget('version'));
  params=quote(symget('params'));
  treeuri=quote(symget('treeuri'));

  put "<AddMetadata><Reposid>$METAREPOSITORY</Reposid><Metadata> "/
    '<SoftwareComponent IsHidden="0" Name=' name ' ProductName=' name /
    '  ClassIdentifier=' ClassIdentifier ' Desc=' desc /
    '  SoftwareVersion=' version '  SpecVersion=' version /
    '  Major="1" Minor="1" UsageVersion="1000000" PublicType="Application" >' /
    '  <Notes>' /
    '    <TextStore Name="Public Configuration Properties" IsHidden="0" ' /
    '       UsageVersion="0" StoredText=' params '/>' /
    '  </Notes>' /
    "<Trees><Tree ObjRef=" treeuri "/></Trees>"/
    "</SoftwareComponent></Metadata><NS>SAS</NS>"/
    "<Flags>268435456</Flags></AddMetadata>";
run;

filename &frefout temp;

proc metadata in= &frefin out=&frefout verbose;
run;

%if &mdebug=1 %then %do;
  /* write the response to the log for debugging */
  data _null_;
    infile &frefout lrecl=1048576;
    input;
    put _infile_;
  run;
%end;

%put NOTE: Checking to ensure application (&name) was created;
data _null_;
  length type uri $256;
  rc=metadata_pathobj("","&tree/&name","Application",type,uri);
  call symputx('apptype',type,'l');
  %if &mdebug=1 %then putlog (_all_)(=);;
run;
%if &apptype ne SoftwareComponent %then %do;
  %put %str(ERR)OR: Could not find (&name) at (&tree)!!;
  %return;
%end;
%else %put NOTE: Application (&name) successfully created in (&tree)!;


%mend;/**
  @file mm_createdataset.sas
  @brief Create a dataset from a metadata definition
  @details This macro was built to support viewing empty tables in
    https://datacontroller.io - a free evaluation copy is available by
    contacting the author (Allan Bowe).

    The table can be retrieved using LIBRARY.DATASET reference, or directly
    using the metadata URI.

    The dataset is written to the WORK library.

  usage:

    %mm_createdataset(libds=metlib.some_dataset)

    or

    %mm_createdataset(tableuri=G5X8AFW1.BE00015Y)

  <h4> Dependencies </h4>
  @li mm_getlibs.sas
  @li mm_gettables.sas
  @li mm_getcols.sas

  @param libds= library.dataset metadata source.  Note - table names in metadata
    can be longer than 32 chars (just fyi, not an issue here)
  @param tableuri= Metadata URI of the table to be created
  @param outds= The dataset to create, default is `work.mm_createdataset`.
    The table name needs to be 32 chars or less as per SAS naming rules.
  @param mdebug= set DBG to 1 to disable DEBUG messages

  @version 9.4
  @author Allan Bowe

**/

%macro mm_createdataset(libds=,tableuri=,outds=work.mm_createdataset,mDebug=0);
%local dbg errorcheck tempds1 tempds2 tempds3;
%if &mDebug=0 %then %let dbg=*;
%let errorcheck=1;

%if %index(&libds,.)>0 %then %do;
  /* get lib uri */
  data;run;%let tempds1=&syslast;
  %mm_getlibs(outds=&tempds1)
  data _null_;
    set &tempds1;
    if upcase(libraryref)="%upcase(%scan(&libds,1,.))";
    call symputx('liburi',LibraryId,'l');
  run;
  /* get ds uri */
  data;run;%let tempds2=&syslast;
  %mm_gettables(uri=&liburi,outds=&tempds2)
  data _null_;
    set &tempds2;
    if upcase(tablename)="%upcase(%scan(&libds,2,.))";
    call symputx('tableuri',tableuri);
  run;
%end;

data;run;%let tempds3=&syslast;
%mm_getcols(tableuri=&tableuri,outds=&tempds3)

data _null_;
  set &tempds3 end=last;
  if _n_=1 then call execute('data &outds;');
  length attrib $32767;

  if SAScolumntype='C' then type='$';
  attrib='attrib '!!cats(colname)!!' length='!!cats(type,SASColumnLength,'.');

  if not missing(sasformat) then fmt=' format='!!cats(sasformat);
  if not missing(sasinformat) then infmt=' informat='!!cats(sasinformat);
  if not missing(coldesc) then desc=' label='!!quote(cats(coldesc));

  attrib=trim(attrib)!!fmt!!infmt!!desc!!';';

  call execute(attrib);
  if last then call execute('call missing(of _all_);stop;run;');
run;

%mend;/**
  @file
  @brief Create a Document object in a metadata folder
  @details Document objects are useful for storing properties in metadata.
    This macro is idempotent - it will not create an object with the same name
    in the same location, twice.
    Note - the filerefs are left open, to enable inspection after running the
    macro (or importing into an xmlmap if needed).

  usage:

      %mm_createdocument(tree=/User Folders/sasdemo
        ,name=MyNote)

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mf_verifymacvars.sas


  @param tree= The metadata folder uri, or the metadata path, in which to
    create the document.  This must exist.
  @param name= Document object name.  Avoid spaces.

  @param desc= Document description (optional)
  @param textrole= TextRole property (optional)
  @param frefin= fileref to use (enables change if there is a conflict)
  @param frefout= fileref to use (enables change if there is a conflict)
  @param mDebug= set to 1 to show debug messages in the log

  @author Allan Bowe

**/

%macro mm_createdocument(
    tree=/User Folders/sasdemo
    ,name=myNote
    ,desc=Created by &sysmacroname
    ,textrole=
    ,frefin=mm_in
    ,frefout=mm_out
    ,mDebug=1
    );

%local mD;
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing &sysmacroname..sas;
%&mD.put _local_;

%mf_verifymacvars(tree name)

/**
 * check tree exists
 */

data _null_;
  length type uri $256;
  rc=metadata_pathobj("","&tree","Folder",type,uri);
  call symputx('type',type,'l');
  call symputx('treeuri',uri,'l');
run;

%mp_abort(
  iftrue= (&type ne Tree)
  ,mac=mm_createdocument.sas
  ,msg=Tree &tree does not exist!
)

/**
 * Check object does not exist already
 */
data _null_;
  length type uri $256;
  rc=metadata_pathobj("","&tree/&name","Note",type,uri);
  call symputx('type',type,'l');
  call symputx('docuri',uri,'l');
  putlog (_all_)(=);
run;

%if &type = Document %then %do;
  %put Document &name already exists in &tree!;
  %return;
%end;

/**
 * Now we can create the document
 */
filename &frefin temp;

/* write header XML */
data _null_;
  file &frefin;
  name=quote("&name");
  desc=quote("&desc");
  textrole=quote("&textrole");
  treeuri=quote("&treeuri");

  put "<AddMetadata><Reposid>$METAREPOSITORY</Reposid>"/
    '<Metadata><Document IsHidden="0" PublicType="Note" UsageVersion="1000000"'/
    "  Name=" name " desc=" desc " TextRole=" textrole ">"/
    "<Notes> "/
    '  <TextStore IsHidden="0"  Name=' name ' UsageVersion="0" '/
    '    TextRole="SourceCode" StoredText="hello world" />' /
    '</Notes>'/
    /*URI="Document for public note" */
    "<Trees><Tree ObjRef=" treeuri "/></Trees>"/
    "</Document></Metadata><NS>SAS</NS>"/
    "<Flags>268435456</Flags></AddMetadata>";
run;

filename &frefout temp;

proc metadata in= &frefin out=&frefout verbose;
run;

%if &mdebug=1 %then %do;
  /* write the response to the log for debugging */
  data _null_;
    infile &frefout lrecl=1048576;
    input;
    put _infile_;
  run;
%end;

%mend;/**
  @file
  @brief Recursively create a metadata folder
  @details This macro was inspired by Paul Homes who wrote an early
    version (mkdirmd.sas) in 2010. The original is described here:
    https://platformadmin.com/blogs/paul/2010/07/mkdirmd/

    The macro will NOT create a new ROOT folder - not
    because it can't, but more because that is generally not something
    your administrator would like you to do!

    The macro is idempotent - if you run it twice, it will only create a folder
    once.

  usage:

    %mm_createfolder(path=/some/meta/folder)

  @param path= Name of the folder to create.
  @param mdebug= set DBG to 1 to disable DEBUG messages

  @version 9.4
  @author Allan Bowe

**/

%macro mm_createfolder(path=,mDebug=0);
%put &sysmacroname: execution started for &path;
%local dbg errorcheck;
%if &mDebug=0 %then %let dbg=*;

%local parentFolderObjId child errorcheck paths;
%let paths=0;
%let errorcheck=1;

%if &syscc ge 4 %then %do;
  %put SYSCC=&syscc - this macro requires a clean session;
  %return;
%end;

data _null_;
  length objId parentId objType parent child $200
    folderPath $1000;
  call missing (of _all_);
  folderPath = "%trim(&path)";

  * remove any trailing slash ;
  if ( substr(folderPath,length(folderPath),1) = '/' ) then
    folderPath=substr(folderPath,1,length(folderPath)-1);

  * name must not be blank;
  if ( folderPath = '' ) then do;
    put "%str(ERR)OR: &sysmacroname PATH parameter value must be non-blank";
  end;

  * must have a starting slash ;
  if ( substr(folderPath,1,1) ne '/' ) then do;
    put "%str(ERR)OR: &sysmacroname PATH parameter value must have starting slash";
    stop;
  end;

  * check if folder already exists ;
  rc=metadata_pathobj('',cats(folderPath,"(Folder)"),"",objType,objId);
  if rc ge 1 then do;
    put "NOTE: Folder " folderPath " already exists!";
    stop;
  end;

  * do not create a root (one level) folder ;
  if countc(folderPath,'/')=1 then do;
    put "%str(ERR)OR: &sysmacroname will not create a new ROOT folder";
    stop;
  end;

  * check that root folder exists ;
  root=cats('/',scan(folderpath,1,'/'),"(Folder)");
  if metadata_pathobj('',root,"",objType,parentId)<1 then do;
     put "%str(ERR)OR: " root " does not exist!";
     stop;
  end;

  * check that parent folder exists ;
  child=scan(folderPath,-1,'/');
  parent=substr(folderpath,1,length(folderpath)-length(child)-1);
  rc=metadata_pathobj('',cats(parent,"(Folder)"),"",objType,parentId);
  if rc<1 then do;
    putlog 'The following folders will be created:';
    /* folder does not exist - so start from top and work down */
     length newpath $1000;
     paths=0;
     do x=2 to countw(folderpath,'/');
       newpath='';
       do i=1 to x;
         newpath=cats(newpath,'/',scan(folderpath,i,'/'));
       end;
       rc=metadata_pathobj('',cats(newpath,"(Folder)"),"",objType,parentId);
       if rc<1 then do;
         paths+1;
         call symputx(cats('path',paths),newpath);
         putlog newpath;
       end;
       call symputx('paths',paths);
     end;
  end;
  else putlog "parent " parent " exists";

  call symputx('parentFolderObjId',parentId,'l');
  call symputx('child',child,'l');
  call symputx('errorcheck',0,'l');

  &dbg put (_all_)(=);
run;

%if &errorcheck=1 or &syscc ge 4 %then %return;

%if &paths>0 %then %do x=1 %to &paths;
  %put executing recursive call for &&path&x;
   %mm_createfolder(path=&&path&x)
%end;
%else %do;
  filename __newdir temp;
  options noquotelenmax;
  %local inmeta;
  %put creating: &path;
  %let inmeta=<AddMetadata><Reposid>$METAREPOSITORY</Reposid><Metadata>
    <Tree Name='&child' PublicType='Folder' TreeType='BIP Folder' UsageVersion='1000000'>
    <ParentTree><Tree ObjRef='&parentFolderObjId'/></ParentTree></Tree></Metadata>
    <NS>SAS</NS><Flags>268435456</Flags></AddMetadata>;

  proc metadata in="&inmeta" out=__newdir verbose;
  run ;

  /* check it was successful */
  data _null_;
    length objId parentId objType parent child $200 ;
    call missing (of _all_);
    rc=metadata_pathobj('',cats("&path","(Folder)"),"",objType,objId);
    if rc ge 1 then do;
      putlog "SUCCCESS!  &path created.";
    end;
    else do;
      putlog "%str(ERR)OR: unsuccessful attempt to create &path";
      call symputx('syscc',8);
    end;
  run;

  /* write the response to the log for debugging */
  %if &mDebug ne 0 %then %do;
    data _null_;
      infile __newdir lrecl=32767;
      input;
      put _infile_;
    run;
  %end;
  filename __newdir clear;
%end;

%put &sysmacroname: execution finished for &path;
%mend;/**
  @file
  @brief Create a SAS Library
  @details Currently only supports BASE engine

    This macro is idempotent - if you run it twice (for the same libref or
    libname), it will only create one library.  There is a dependency on other
    macros in this library - they should be installed as a suite (see README).

  Usage:

      %mm_createlibrary(
        libname=My New Library
        ,libref=mynewlib
        ,libdesc=Super & <fine>
        ,engine=BASE
        ,tree=/User Folders/sasdemo
        ,servercontext=SASApp
        ,directory=/tmp/tests
        ,mDebug=1)

  <h4> Dependencies </h4>
  @li mf_verifymacvars.sas
  @li mm_createfolder.sas


  @param libname= Library name (as displayed to user, 256 chars). Duplicates
    are not created (case sensitive).
  @param libref= Library libref (8 chars).  Duplicate librefs are not created,
    HOWEVER- the check is not case sensitive - if *libref* exists, *LIBREF*
    will still be created.   Librefs created will always be uppercased.
  @param engine= Library engine (currently only BASE supported)
  @param tree= The metadata folder uri, or the metadata path, in which to
    create the library.
  @param servercontext= The SAS server against which the library is registered.
  @param IsPreassigned= set to 1 if the library should be pre-assigned.

  @param libdesc= Library description (optional)
  @param directory= Required for the BASE engine. The metadata directory objects
    are searched to find an existing one with a matching physical path.
    If more than one uri found with that path, then the first one will be used.
    If no URI is found, a new directory object will be created.  The physical
    path will also be created, if it doesn't exist.


  @param mDebug= set to 1 to show debug messages in the log
  @param frefin= fileref to use (enables change if there is a conflict).  The
    filerefs are left open, to enable inspection after running the
    macro (or importing into an xmlmap if needed).
  @param frefout= fileref to use (enables change if there is a conflict)


  @version 9.3
  @author Allan Bowe

**/

%macro mm_createlibrary(
     libname=My New Library
    ,libref=mynewlib
    ,libdesc=Created automatically using the mm_createlibrary macro
    ,engine=BASE
    ,tree=/User Folders/sasdemo
    ,servercontext=SASApp
    ,directory=/tmp/somelib
    ,IsPreassigned=0
    ,mDebug=0
    ,frefin=mm_in
    ,frefout=mm_out
)/*/STORE SOURCE*/;

%local mD;
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing &sysmacroname..sas;
%&mD.put _local_;

%let libref=%upcase(&libref);

/**
 * Check Library does not exist already with this libname
 */
data _null_;
  length type uri $256;
  rc=metadata_resolve("omsobj:SASLibrary?@Name='&libname'",type,uri);
  call symputx('checktype',type,'l');
  call symputx('liburi',uri,'l');
  putlog (_all_)(=);
run;
%if &checktype = SASLibrary %then %do;
  %put WARNING: Library (&liburi) already exists with libname (&libname)  ;
  %return;
%end;

/**
 * Check Library does not exist already with this libref
 */
data _null_;
  length type uri $256;
  rc=metadata_resolve("omsobj:SASLibrary?@Libref='&libref'",type,uri);
  call symputx('checktype',type,'l');
  call symputx('liburi',uri,'l');
  putlog (_all_)(=);
run;
%if &checktype = SASLibrary %then %do;
  %put WARNING: Library (&liburi) already exists with libref (&libref)  ;
  %return;
%end;


/**
 * Attempt to create tree
 */
%mm_createfolder(path=&tree)

/**
 * check tree exists
 */
data _null_;
  length type uri $256;
  rc=metadata_pathobj("","&tree","Folder",type,uri);
  call symputx('foldertype',type,'l');
  call symputx('treeuri',uri,'l');
run;
%if &foldertype ne Tree %then %do;
  %put WARNING: Tree &tree does not exist!;
  %return;
%end;

/**
 * Create filerefs for proc metadata call
 */
filename &frefin temp;
filename &frefout temp;

%if &engine=BASE %then %do;

  %mf_verifymacvars(libname libref engine servercontext tree)



  /**
   * Check that the ServerContext exists
   */
  data _null_;
    length type uri $256;
    rc=metadata_resolve("omsobj:ServerContext?@Name='&ServerContext'",type,uri);
    call symputx('checktype',type,'l');
    call symputx('serveruri',uri,'l');
    putlog (_all_)(=);
  run;
  %if &checktype ne ServerContext %then %do;
    %put %str(ERR)OR: ServerContext (&ServerContext) does not exist!;
    %return;
  %end;

  /**
   * Get prototype info
   */
  data _null_;
    length type uri str $256;
    str="omsobj:Prototype?@Name='Library.SAS.Prototype.Name.xmlKey.txt'";
    rc=metadata_resolve(str,type,uri);
    call symputx('checktype',type,'l');
    call symputx('prototypeuri',uri,'l');
    putlog (_all_)(=);
  run;
  %if &checktype ne Prototype %then %do;
    %put %str(ERR)OR: Prototype (Library.SAS.Prototype.Name.xmlKey.txt) not found!;
    %return;
  %end;

  /**
   * Check that Physical location exists
   */
  %if %sysfunc(fileexist(&directory))=0 %then %do;
    %put %str(ERR)OR: Physical directory (&directory) does not appear to exist!;
    %return;
  %end;

  /**
   * Check that Directory Object exists in metadata
   */
  data _null_;
    length type uri $256;
    rc=metadata_resolve("omsobj:Directory?@DirectoryRole='LibraryPath'"
      !!" and @DirectoryName='&directory'",type,uri);
    call symputx('checktype',type,'l');
    call symputx('directoryuri',uri,'l');
    putlog (_all_)(=);
  run;
  %if &checktype ne Directory %then %do;
    %put NOTE: Directory object does not exist for (&directory) location;
    %put NOTE: It will now be created;

    data _null_;
      file &frefin;
      directory=quote(symget('directory'));
      put "<AddMetadata><Reposid>$METAREPOSITORY</Reposid><Metadata> "/
      '<Directory UsageVersion="1000000" IsHidden="0" IsRelative="0"'/
      '  DirectoryRole="LibraryPath" Name="Path" DirectoryName=' directory '/>'/
      "</Metadata><NS>SAS</NS>"/
      "<Flags>268435456</Flags></AddMetadata>";
    run;

    proc metadata in= &frefin out=&frefout %if &mdebug=1 %then verbose;;
    run;
    %if &mdebug=1 %then %do;
      data _null_;
        infile &frefout lrecl=1048576;
        input; put _infile_;
      run;
    %end;
    %put NOTE: Checking to ensure directory (&directory) object was created;
    data _null_;
      length type uri $256;
      rc=metadata_resolve("omsobj:Directory?@DirectoryRole='LibraryPath'"
        !!" and @DirectoryName='&directory'",type,uri);
      call symputx('checktype2',type,'l');
      call symputx('directoryuri',uri,'l');
      %if &mdebug=1 %then putlog (_all_)(=);;
    run;
    %if &checktype2 ne Directory %then %do;
      %put %str(ERR)OR: Directory (&directory) object was NOT created!;
      %return;
    %end;
    %else %put NOTE: Directory (&directoryuri) successfully created!;
  %end;

  /**
   *  check SAS version
   */
  %if %sysevalf(&sysver lt 9.3) %then %do;
    %put WARNING: Version 9.3 or later required;
    %return;
  %end;

  /**
   * Prepare the XML and create the library
   */
  data _null_;
    file &frefin;
    treeuri=quote(symget('treeuri'));
    serveruri=quote(symget('serveruri'));
    directoryuri=quote(symget('directoryuri'));
    libname=quote(symget('libname'));
    libref=quote(symget('libref'));
    IsPreassigned=quote(symget('IsPreassigned'));
    prototypeuri=quote(symget('prototypeuri'));

    /* escape description so it can be stored as XML */
    libdesc=tranwrd(symget('libdesc'),'&','&amp;');
    libdesc=tranwrd(libdesc,'<','&lt;');
    libdesc=tranwrd(libdesc,'>','&gt;');
    libdesc=tranwrd(libdesc,"'",'&apos;');
    libdesc=tranwrd(libdesc,'"','&quot;');
    libdesc=tranwrd(libdesc,'0A'x,'&#10;');
    libdesc=tranwrd(libdesc,'0D'x,'&#13;');
    libdesc=tranwrd(libdesc,'$','&#36;');
    libdesc=quote(trim(libdesc));

    put "<AddMetadata><Reposid>$METAREPOSITORY</Reposid><Metadata> "/
        '<SASLibrary Desc=' libdesc ' Engine="BASE" IsDBMSLibname="0" '/
        '  IsHidden="0" IsPreassigned=' IsPreassigned ' Libref=' libref /
        '  UsageVersion="1000000" PublicType="Library" name=' libname '>'/
        '  <DeployedComponents>'/
        '    <ServerContext ObjRef=' serveruri "/>"/
        '  </DeployedComponents>'/
        '  <PropertySets>'/
        '    <PropertySet Name="ModifiedByProductPropertySet" '/
        '      SetRole="ModifiedByProductPropertySet" UsageVersion="0" />'/
        '  </PropertySets>'/
        "  <Trees><Tree ObjRef=" treeuri "/></Trees>"/
        '  <UsingPackages> '/
        '    <Directory ObjRef=' directoryuri ' />'/
        '  </UsingPackages>'/
        '  <UsingPrototype>'/
        '    <Prototype ObjRef=' prototypeuri '/>'/
        '  </UsingPrototype>'/
        '</SASLibrary></Metadata><NS>SAS</NS>'/
        '<Flags>268435456</Flags></AddMetadata>';
  run;


  proc metadata in= &frefin out=&frefout %if &mdebug=1 %then verbose ;;
  run;

  %if &mdebug=1 %then %do;
    data _null_;
      infile &frefout lrecl=1048576;
      input;put _infile_;
    run;
  %end;
  %put NOTE: Checking to ensure library (&libname) was created;
  data _null_;
    length type uri $256;
    rc=metadata_pathobj("","&tree/&libname","Library",type,uri);
    call symputx('libtype',type,'l');
    call symputx('liburi',uri,'l');
    %if &mdebug=1 %then putlog (_all_)(=);;
  run;
  %if &libtype ne SASLibrary %then %do;
    %put %str(ERR)OR: Could not find (&libname) at (&tree)!!;
    %return;
  %end;
  %else %put NOTE: Library (&libname) successfully created in (&tree)!;
%end;
%else %do;
  %put %str(ERR)OR: Other library engine types are not yet supported!!;
%end;


/**
 * Wrap up
 */
%if &mdebug ne 1 %then %do;
  filename &frefin clear;
  filename &frefout clear;
%end;

%mend;
/**
  @file
  @brief Create a type 1 Stored Process (9.2 compatible)
  @details This macro creates a Type 1 stored process, and also the necessary
    PromptGroup / File / TextStore objects.  It requires the location (or uri)
    for the App Server / Directory / Folder (Tree) objects.
    To upgrade this macro to work with type 2 (which can embed SAS code
    and is compabitible with SAS from 9.3 onwards) then the UsageVersion should
    change to 2000000 and the TextStore object updated.  The ComputeServer
    reference will also be to ServerContext rather than LogicalServer.

    This macro is idempotent - if you run it twice, it will only create an STP
    once.

  usage (type 1 STP):

      %mm_createstp(stpname=MyNewSTP
        ,filename=mySpecialProgram.sas
        ,directory=SASEnvironment/SASCode/STPs
        ,tree=/User Folders/sasdemo
        ,outds=work.uris)

  If you wish to remove the new STP you can do so by running:

      data _null_;
        set work.uris;
        rc1 = METADATA_DELOBJ(texturi);
        rc2 = METADATA_DELOBJ(prompturi);
        rc3 = METADATA_DELOBJ(fileuri);
        rc4 = METADATA_DELOBJ(stpuri);
        putlog (_all_)(=);
      run;

  usage (type 2 STP):
      %mm_createstp(stpname=MyNewType2STP
        ,filename=mySpecialProgram.sas
        ,directory=SASEnvironment/SASCode/STPs
        ,tree=/User Folders/sasdemo
        ,Server=SASApp
        ,stptype=2)

  <h4> Dependencies </h4>
  @li mf_nobs.sas
  @li mf_verifymacvars.sas
  @li mm_getdirectories.sas
  @li mm_updatestpsourcecode.sas
  @li mp_dropmembers.sas
  @li mm_getservercontexts.sas

  @param stpname= Stored Process name.  Avoid spaces - testing has shown that
    the check to avoid creating multiple STPs in the same folder with the same
    name does not work when the name contains spaces.
  @param stpdesc= Stored Process description (optional)
  @param filename= the name of the .sas program to run
  @param directory= The directory uri, or the actual path to the sas program
    (no trailing slash).  If more than uri is found with that path, then the
    first one will be used.
  @param tree= The metadata folder uri, or the metadata path, in which to
    create the STP.
  @param server= The server which will run the STP.  Server name or uri is fine.
  @param outds= The two level name of the output dataset.  Will contain all the
    meta uris. Defaults to work.mm_createstp.
  @param mDebug= set to 1 to show debug messages in the log
  @param stptype= Default is 1 (STP code saved on filesystem).  Set to 2 if
    source code is to be saved in metadata (9.3 and above feature).
  @param minify= set to YES to strip comments / blank lines etc
  @param frefin= fileref to use (enables change if there is a conflict).  The
    filerefs are left open, to enable inspection after running the
    macro (or importing into an xmlmap if needed).
  @param frefout= fileref to use (enables change if there is a conflict)
  @param repo= ServerContext is tied to a repo, if you are not using the
    foundation repo then select a different one here

  @returns outds  dataset containing the following columns:
   - stpuri
   - prompturi
   - fileuri
   - texturi

  @version 9.2
  @author Allan Bowe

**/

%macro mm_createstp(
     stpname=Macro People STP
    ,stpdesc=This stp was created automatically by the mm_createstp macro
    ,filename=mm_createstp.sas
    ,directory=SASEnvironment/SASCode
    ,tree=/User Folders/sasdemo
    ,package=false
    ,streaming=true
    ,outds=work.mm_createstp
    ,mDebug=0
    ,server=SASApp
    ,stptype=1
    ,minify=NO
    ,frefin=mm_in
    ,frefout=mm_out
)/*/STORE SOURCE*/;

%local mD;
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing mm_CreateSTP.sas;
%&mD.put _local_;

%mf_verifymacvars(stpname filename directory tree)
%mp_dropmembers(%scan(&outds,2,.))

/**
 * check tree exists
 */
data _null_;
  length type uri $256;
  rc=metadata_pathobj("","&tree","Folder",type,uri);
  call symputx('foldertype',type,'l');
  call symputx('treeuri',uri,'l');
run;
%if &foldertype ne Tree %then %do;
  %put WARNING: Tree &tree does not exist!;
  %return;
%end;

/**
 * Check STP does not exist already
 */
%local cmtype;
data _null_;
  length type uri $256;
  rc=metadata_pathobj("","&tree/&stpname",'StoredProcess',type,uri);
  call symputx('cmtype',type,'l');
  call symputx('stpuri',uri,'l');
run;
%if &cmtype = ClassifierMap %then %do;
  %put WARNING: Stored Process &stpname already exists in &tree!;
  %return;
%end;

/**
 * Check that the physical file exists
 */
%if %sysfunc(fileexist(&directory/&filename)) ne 1 %then %do;
  %put WARNING: FILE *&directory/&filename* NOT FOUND!;
  %return;
%end;

%if &stptype=1 %then %do;
  /* type 1 STP - where code is stored on filesystem */
  %if %sysevalf(&sysver lt 9.2) %then %do;
    %put WARNING: Version 9.2 or later required;
    %return;
  %end;

  /* check directory object (where 9.2 source code reference is stored) */
  data _null_;
    length id $20 dirtype $256;
    rc=metadata_resolve("&directory",dirtype,id);
    call symputx('checkdirtype',dirtype,'l');
  run;

  %if &checkdirtype ne Directory %then %do;
    %mm_getdirectories(path=&directory,outds=&outds ,mDebug=&mDebug)
    %if %mf_nobs(&outds)=0 or %sysfunc(exist(&outds))=0 %then %do;
      %put WARNING: The directory object does not exist for &directory;
      %return;
    %end;
  %end;
  %else %do;
    data &outds;
      directoryuri="&directory";
    run;
  %end;

  data &outds (keep=stpuri prompturi fileuri texturi);
    length stpuri prompturi fileuri texturi serveruri $256 ;
    set &outds;

    /* final checks on uris */
    length id $20 type $256;
    __rc=metadata_resolve("&treeuri",type,id);
    if type ne 'Tree' then do;
      putlog "WARNING:  Invalid tree URI: &treeuri";
      stopme=1;
    end;
    __rc=metadata_resolve(directoryuri,type,id);
    if type ne 'Directory' then do;
      putlog 'WARNING:  Invalid directory URI: ' directoryuri;
      stopme=1;
    end;

  /* get server info */
    __rc=metadata_resolve("&server",type,serveruri);
    if type ne 'LogicalServer' then do;
      __rc=metadata_getnobj("omsobj:LogicalServer?@Name='&server'",1,serveruri);
      if serveruri='' then do;
        putlog "WARNING:  Invalid server: &server";
        stopme=1;
      end;
    end;

    if stopme=1 then do;
      putlog (_all_)(=);
      stop;
    end;

    /* create empty prompt */
    rc1=METADATA_NEWOBJ('PromptGroup',prompturi,'Parameters');
    rc2=METADATA_SETATTR(prompturi, 'UsageVersion', '1000000');
    rc3=METADATA_SETATTR(prompturi, 'GroupType','2');
    rc4=METADATA_SETATTR(prompturi, 'Name','Parameters');
    rc5=METADATA_SETATTR(prompturi, 'PublicType','Embedded:PromptGroup');
    GroupInfo="<PromptGroup promptId='PromptGroup_%sysfunc(datetime())_&sysprocessid'"
      !!" version='1.0'><Label><Text xml:lang='en-GB'>Parameters</Text>"
      !!"</Label></PromptGroup>";
    rc6 = METADATA_SETATTR(prompturi, 'GroupInfo',groupinfo);

    if sum(of rc1-rc6) ne 0 then do;
      putlog 'WARNING: Issue creating prompt.';
      if prompturi ne . then do;
        putlog '  Removing orphan: ' prompturi;
        rc = METADATA_DELOBJ(prompturi);
        put rc=;
      end;
      stop;
    end;

    /* create a file uri */
    rc7=METADATA_NEWOBJ('File',fileuri,'SP Source File');
    rc8=METADATA_SETATTR(fileuri, 'FileName',"&filename");
    rc9=METADATA_SETATTR(fileuri, 'IsARelativeName','1');
    rc10=METADATA_SETASSN(fileuri, 'Directories','MODIFY',directoryuri);
    if sum(of rc7-rc10) ne 0 then do;
      putlog 'WARNING: Issue creating file.';
      if fileuri ne . then do;
        putlog '  Removing orphans:' prompturi fileuri;
        rc = METADATA_DELOBJ(prompturi);
        rc = METADATA_DELOBJ(fileuri);
        put (_all_)(=);
      end;
      stop;
    end;

    /* create a TextStore object */
    rc11= METADATA_NEWOBJ('TextStore',texturi,'Stored Process');
    rc12= METADATA_SETATTR(texturi, 'TextRole','StoredProcessConfiguration');
    rc13= METADATA_SETATTR(texturi, 'TextType','XML');
    storedtext='<?xml version="1.0" encoding="UTF-8"?><StoredProcess>'
      !!"<ResultCapabilities Package='&package' Streaming='&streaming'/>"
      !!"<OutputParameters/></StoredProcess>";
    rc14= METADATA_SETATTR(texturi, 'StoredText',storedtext);
    if sum(of rc11-rc14) ne 0 then do;
      putlog 'WARNING: Issue creating TextStore.';
      if texturi ne . then do;
        putlog '  Removing orphans: ' prompturi fileuri texturi;
        rc = METADATA_DELOBJ(prompturi);
        rc = METADATA_DELOBJ(fileuri);
        rc = METADATA_DELOBJ(texturi);
        put (_all_)(=);
      end;
      stop;
    end;

    /* create meta obj */
    rc15= METADATA_NEWOBJ('ClassifierMap',stpuri,"&stpname");
    rc16= METADATA_SETASSN(stpuri, 'Trees','MODIFY',treeuri);
    rc17= METADATA_SETASSN(stpuri, 'ComputeLocations','MODIFY',serveruri);
    rc18= METADATA_SETASSN(stpuri, 'SourceCode','MODIFY',fileuri);
    rc19= METADATA_SETASSN(stpuri, 'Prompts','MODIFY',prompturi);
    rc20= METADATA_SETASSN(stpuri, 'Notes','MODIFY',texturi);
    rc21= METADATA_SETATTR(stpuri, 'PublicType', 'StoredProcess');
    rc22= METADATA_SETATTR(stpuri, 'TransformRole', 'StoredProcess');
    rc23= METADATA_SETATTR(stpuri, 'UsageVersion', '1000000');
    rc24= METADATA_SETATTR(stpuri, 'Desc', "&stpdesc");

    /* tidy up if err */
    if sum(of rc15-rc24) ne 0 then do;
      putlog "%str(WARN)ING: Issue creating STP.";
      if stpuri ne . then do;
        putlog '  Removing orphans: ' prompturi fileuri texturi stpuri;
        rc = METADATA_DELOBJ(prompturi);
        rc = METADATA_DELOBJ(fileuri);
        rc = METADATA_DELOBJ(texturi);
        rc = METADATA_DELOBJ(stpuri);
        put (_all_)(=);
      end;
    end;
    else do;
      fullpath=cats('_program=',treepath,"/&stpname");
      putlog "NOTE: Stored Process Created!";
      putlog "NOTE- "; putlog "NOTE-"; putlog "NOTE-" fullpath;
      putlog "NOTE- "; putlog "NOTE-";
    end;
    output;
    stop;
  run;
%end;
%else %if &stptype=2 %then %do;
  /* type 2 stp - code is stored in metadata */
  %if %sysevalf(&sysver lt 9.3) %then %do;
    %put WARNING: SAS version 9.3 or later required to create type2 STPs;
    %return;
  %end;
  /* check we have the correct ServerContext */
  %mm_getservercontexts(outds=contexts)
  %local serveruri; %let serveruri=NOTFOUND;
  data _null_;
    set contexts;
    where upcase(servername)="%upcase(&server)";
    call symputx('serveruri',serveruri);
  run;
  %if &serveruri=NOTFOUND %then %do;
    %put WARNING: ServerContext *&server* not found!;
    %return;
  %end;

  /**
   * First, create a Hello World type 2 stored process
   */
  filename &frefin temp;
  data _null_;
    file &frefin;
    treeuri=quote(symget('treeuri'));
    serveruri=quote(symget('serveruri'));
    stpdesc=quote(symget('stpdesc'));
    stpname=quote(symget('stpname'));

    put "<AddMetadata><Reposid>$METAREPOSITORY</Reposid><Metadata> "/
    '<ClassifierMap UsageVersion="2000000" IsHidden="0" IsUserDefined="0" '/
    ' IsActive="1" PublicType="StoredProcess" TransformRole="StoredProcess" '/
    '  Name=' stpname ' Desc=' stpdesc '>'/
    "  <ComputeLocations>"/
    "    <ServerContext ObjRef=" serveruri "/>"/
    "  </ComputeLocations>"/
    "<Notes> "/
    '  <TextStore IsHidden="0"  Name="SourceCode" UsageVersion="0" '/
    '    TextRole="StoredProcessSourceCode" StoredText="%put hello world!;" />'/
    '  <TextStore IsHidden="0" Name="Stored Process" UsageVersion="0" '/
    '    TextRole="StoredProcessConfiguration" TextType="XML" '/
    '    StoredText="&lt;?xml version=&quot;1.0&quot; encoding=&quot;UTF-8&qu'@@
    'ot;?&gt;&lt;StoredProcess&gt;&lt;ServerContext LogicalServerType=&quot;S'@@
    'ps&quot; OtherAllowed=&quot;false&quot;/&gt;&lt;ResultCapabilities Packa'@@
    'ge=&quot;' @@ "&package" @@ '&quot; Streaming=&quot;' @@ "&streaming" @@
    '&quot;/&gt;&lt;OutputParameters/&gt;&lt;/StoredProcess&gt;" />' /
    "  </Notes> "/
    "  <Prompts> "/
    '   <PromptGroup  Name="Parameters" GroupType="2" IsHidden="0" '/
    '     PublicType="Embedded:PromptGroup" UsageVersion="1000000" '/
    '     GroupInfo="&lt;PromptGroup promptId=&quot;PromptGroup_1502797359253'@@
    '_802080&quot; version=&quot;1.0&quot;&gt;&lt;Label&gt;&lt;Text xml:lang='@@
    '&quot;en-US&quot;&gt;Parameters&lt;/Text&gt;&lt;/Label&gt;&lt;/PromptGro'@@
    'up&gt;" />'/
    "  </Prompts> "/
    "<Trees><Tree ObjRef=" treeuri "/></Trees>"/
    "</ClassifierMap></Metadata><NS>SAS</NS>"/
    "<Flags>268435456</Flags></AddMetadata>";
  run;

  filename &frefout temp;

  proc metadata in= &frefin out=&frefout ;
  run;

  %if &mdebug=1 %then %do;
    /* write the response to the log for debugging */
    data _null_;
      infile &frefout lrecl=1048576;
      input;
      put _infile_;
    run;
  %end;

  /**
   * Next, add the source code
   */
  %mm_updatestpsourcecode(stp=&tree/&stpname
    ,stpcode="&directory/&filename"
    ,frefin=&frefin.
    ,frefout=&frefout.
    ,mdebug=&mdebug
    ,minify=&minify)


%end;
%else %do;
  %put WARNING:  STPTYPE=*&stptype* not recognised!;
%end;

%mend;/**
  @file mm_createwebservice.sas
  @brief Create a Web Ready Stored Process
  @details This macro creates a Type 2 Stored Process with the mm_webout macro
    included as pre-code.
Usage:

    %* compile macros ;
    filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
    %inc mc;

    %* parmcards lets us write to a text file from open code ;
    filename ft15f001 temp;
    parmcards4;
        %* do some sas, any inputs are now already WORK tables;
        data example1 example2;
          set sashelp.class;
        run;
        %* send data back;
        %webout(OPEN)
        %webout(ARR,example1) * Array format, fast, suitable for large tables ;
        %webout(OBJ,example2) * Object format, easier to work with ;
        %webout(CLOSE)
    ;;;;
    %mm_createwebservice(path=/Public/app/common,name=appInit,code=ft15f001,replace=YES)

  <h4> Dependencies </h4>
  @li mm_createstp.sas
  @li mf_getuser.sas
  @li mm_createfolder.sas
  @li mm_deletestp.sas

  @param path= The full path (in SAS Metadata) where the service will be created
  @param name= Stored Process name.  Avoid spaces - testing has shown that
    the check to avoid creating multiple STPs in the same folder with the same
    name does not work when the name contains spaces.
  @param desc= The description of the service (optional)
  @param precode= Space separated list of filerefs, pointing to the code that
    needs to be attached to the beginning of the service (optional)
  @param code= Space seperated fileref(s) of the actual code to be added
  @param server= The server which will run the STP.  Server name or uri is fine.
  @param mDebug= set to 1 to show debug messages in the log
  @param replace= select YES to replace any existing service in that location
  @param adapter= the macro uses the sasjs adapter by default.  To use another
    adapter, add a (different) fileref here.

  @version 9.2
  @author Allan Bowe

**/

%macro mm_createwebservice(path=
    ,name=initService
    ,precode=
    ,code=
    ,desc=This stp was created automagically by the mm_createwebservice macro
    ,mDebug=0
    ,server=SASApp
    ,replace=NO
    ,adapter=sasjs
)/*/STORE SOURCE*/;

%if &syscc ge 4 %then %do;
  %put &=syscc - &sysmacroname will not execute in this state;
  %return;
%end;

%local mD;
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing mm_createwebservice.sas;
%&mD.put _local_;

* remove any trailing slash ;
%if "%substr(&path,%length(&path),1)" = "/" %then
  %let path=%substr(&path,1,%length(&path)-1);

/**
 * Add webout macro
 * These put statements are auto generated - to change the macro, change the
 * source (mm_webout) and run `build.py`
 */
filename sasjs temp;
data _null_;
  file sasjs lrecl=3000 ;
  put "/* Created on %sysfunc(datetime(),datetime19.) by %mf_getuser() */";
/* WEBOUT BEGIN */
  put ' ';
  put '%macro mp_jsonout(action,ds,jref=_webout,dslabel=,fmt=Y,engine=PROCJSON,dbg=0 ';
  put ')/*/STORE SOURCE*/; ';
  put '%put output location=&jref; ';
  put '%if &action=OPEN %then %do; ';
  put '  data _null_;file &jref encoding=''utf-8''; ';
  put '    put ''{"START_DTTM" : "'' "%sysfunc(datetime(),datetime20.3)" ''"''; ';
  put '  run; ';
  put '%end; ';
  put '%else %if (&action=ARR or &action=OBJ) %then %do; ';
  put '  options validvarname=upcase; ';
  put '  data _null_;file &jref mod encoding=''utf-8''; ';
  put '    put ", ""%lowcase(%sysfunc(coalescec(&dslabel,&ds)))"":"; ';
  put ' ';
  put '  %if &engine=PROCJSON %then %do; ';
  put '    data;run;%let tempds=&syslast; ';
  put '    proc sql;drop table &tempds; ';
  put '    data &tempds /view=&tempds;set &ds; ';
  put '    %if &fmt=N %then format _numeric_ best32.;; ';
  put '    proc json out=&jref pretty ';
  put '        %if &action=ARR %then nokeys ; ';
  put '        ;export &tempds / nosastags fmtnumeric; ';
  put '    run; ';
  put '    proc sql;drop view &tempds; ';
  put '  %end; ';
  put '  %else %if &engine=DATASTEP %then %do; ';
  put '    %local cols i tempds; ';
  put '    %let cols=0; ';
  put '    %if %sysfunc(exist(&ds)) ne 1 & %sysfunc(exist(&ds,VIEW)) ne 1 %then %do; ';
  put '      %put &sysmacroname:  &ds NOT FOUND!!!; ';
  put '      %return; ';
  put '    %end; ';
  put '    data _null_;file &jref mod ; ';
  put '      put "["; call symputx(''cols'',0,''l''); ';
  put '    proc sort data=sashelp.vcolumn(where=(libname=''WORK'' & memname="%upcase(&ds)")) ';
  put '      out=_data_; ';
  put '      by varnum; ';
  put ' ';
  put '    data _null_; ';
  put '      set _last_ end=last; ';
  put '      call symputx(cats(''name'',_n_),name,''l''); ';
  put '      call symputx(cats(''type'',_n_),type,''l''); ';
  put '      call symputx(cats(''len'',_n_),length,''l''); ';
  put '      if last then call symputx(''cols'',_n_,''l''); ';
  put '    run; ';
  put ' ';
  put '    proc format; /* credit yabwon for special null removal */ ';
  put '      value bart ._ - .z = null ';
  put '      other = [best.]; ';
  put ' ';
  put '    data;run; %let tempds=&syslast; /* temp table for spesh char management */ ';
  put '    proc sql; drop table &tempds; ';
  put '    data &tempds/view=&tempds; ';
  put '      attrib _all_ label=''''; ';
  put '      %do i=1 %to &cols; ';
  put '        %if &&type&i=char %then %do; ';
  put '          length &&name&i $32767; ';
  put '          format &&name&i $32767.; ';
  put '        %end; ';
  put '      %end; ';
  put '      set &ds; ';
  put '      format _numeric_ bart.; ';
  put '    %do i=1 %to &cols; ';
  put '      %if &&type&i=char %then %do; ';
  put '        &&name&i=''"''!!trim(prxchange(''s/"/\"/'',-1, ';
  put '                    prxchange(''s/''!!''0A''x!!''/\n/'',-1, ';
  put '                    prxchange(''s/''!!''0D''x!!''/\r/'',-1, ';
  put '                    prxchange(''s/''!!''09''x!!''/\t/'',-1, ';
  put '                    prxchange(''s/\\/\\\\/'',-1,&&name&i) ';
  put '        )))))!!''"''; ';
  put '      %end; ';
  put '    %end; ';
  put '    run; ';
  put '    /* write to temp loc to avoid _webout truncation - https://support.sas.com/kb/49/325.html */ ';
  put '    filename _sjs temp lrecl=131068 encoding=''utf-8''; ';
  put '    data _null_; file _sjs lrecl=131068 encoding=''utf-8'' mod; ';
  put '      set &tempds; ';
  put '      if _n_>1 then put "," @; put ';
  put '      %if &action=ARR %then "[" ; %else "{" ; ';
  put '      %do i=1 %to &cols; ';
  put '        %if &i>1 %then  "," ; ';
  put '        %if &action=OBJ %then """&&name&i"":" ; ';
  put '        &&name&i ';
  put '      %end; ';
  put '      %if &action=ARR %then "]" ; %else "}" ; ; ';
  put '    proc sql; ';
  put '    drop view &tempds; ';
  put '    /* now write the long strings to _webout 1 byte at a time */ ';
  put '    data _null_; ';
  put '      length filein 8 fileid 8; ';
  put '      filein = fopen("_sjs",''I'',1,''B''); ';
  put '      fileid = fopen("&jref",''A'',1,''B''); ';
  put '      rec = ''20''x; ';
  put '      do while(fread(filein)=0); ';
  put '        rc = fget(filein,rec,1); ';
  put '        rc = fput(fileid, rec); ';
  put '        rc =fwrite(fileid); ';
  put '      end; ';
  put '      rc = fclose(filein); ';
  put '      rc = fclose(fileid); ';
  put '    run; ';
  put '    filename _sjs clear; ';
  put '    data _null_; file &jref mod encoding=''utf-8''; ';
  put '      put "]"; ';
  put '    run; ';
  put '  %end; ';
  put '%end; ';
  put ' ';
  put '%else %if &action=CLOSE %then %do; ';
  put '  data _null_;file &jref encoding=''utf-8''; ';
  put '    put "}"; ';
  put '  run; ';
  put '%end; ';
  put '%mend; ';
  put '%macro mm_webout(action,ds,dslabel=,fref=_webout,fmt=Y); ';
  put '%global _webin_file_count _webin_fileref1 _webin_name1 _program _debug ';
  put '  sasjs_tables; ';
  put '%local i tempds; ';
  put ' ';
  put '%if &action=FETCH %then %do; ';
  put '  %if %str(&_debug) ge 131 %then %do; ';
  put '    options mprint notes mprintnest; ';
  put '  %end; ';
  put '  %let _webin_file_count=%eval(&_webin_file_count+0); ';
  put '  /* now read in the data */ ';
  put '  %do i=1 %to &_webin_file_count; ';
  put '    %if &_webin_file_count=1 %then %do; ';
  put '      %let _webin_fileref1=&_webin_fileref; ';
  put '      %let _webin_name1=&_webin_name; ';
  put '    %end; ';
  put '    data _null_; ';
  put '      infile &&_webin_fileref&i termstr=crlf; ';
  put '      input; ';
  put '      call symputx(''input_statement'',_infile_); ';
  put '      putlog "&&_webin_name&i input statement: "  _infile_; ';
  put '      stop; ';
  put '    data &&_webin_name&i; ';
  put '      infile &&_webin_fileref&i firstobs=2 dsd termstr=crlf encoding=''utf-8''; ';
  put '      input &input_statement; ';
  put '      %if %str(&_debug) ge 131 %then %do; ';
  put '        if _n_<20 then putlog _infile_; ';
  put '      %end; ';
  put '    run; ';
  put '    %let sasjs_tables=&sasjs_tables &&_webin_name&i; ';
  put '  %end; ';
  put '%end; ';
  put ' ';
  put '%else %if &action=OPEN %then %do; ';
  put '  /* fix encoding */ ';
  put '  OPTIONS NOBOMFILE; ';
  put '  data _null_; ';
  put '    rc = stpsrv_header(''Content-type'',"text/html; encoding=utf-8"); ';
  put '  run; ';
  put ' ';
  put '  /* setup json */ ';
  put '  data _null_;file &fref encoding=''utf-8''; ';
  put '  %if %str(&_debug) ge 131 %then %do; ';
  put '    put ''>>weboutBEGIN<<''; ';
  put '  %end; ';
  put '    put ''{"START_DTTM" : "'' "%sysfunc(datetime(),datetime20.3)" ''"''; ';
  put '  run; ';
  put ' ';
  put '%end; ';
  put ' ';
  put '%else %if &action=ARR or &action=OBJ %then %do; ';
  put '  %if &sysver=9.4 %then %do; ';
  put '    %mp_jsonout(&action,&ds,dslabel=&dslabel,fmt=&fmt ';
  put '      ,engine=PROCJSON,dbg=%str(&_debug) ';
  put '    ) ';
  put '  %end; ';
  put '  %else %do; ';
  put '    %mp_jsonout(&action,&ds,dslabel=&dslabel,fmt=&fmt ';
  put '      ,engine=DATASTEP,dbg=%str(&_debug) ';
  put '    ) ';
  put '  %end; ';
  put '%end; ';
  put '%else %if &action=CLOSE %then %do; ';
  put '  %if %str(&_debug) ge 131 %then %do; ';
  put '    /* if debug mode, send back first 10 records of each work table also */ ';
  put '    options obs=10; ';
  put '    data;run;%let tempds=%scan(&syslast,2,.); ';
  put '    ods output Members=&tempds; ';
  put '    proc datasets library=WORK memtype=data; ';
  put '    %local wtcnt;%let wtcnt=0; ';
  put '    data _null_; ';
  put '      set &tempds; ';
  put '      if not (name =:"DATA"); ';
  put '      i+1; ';
  put '      call symputx(''wt''!!left(i),name,''l''); ';
  put '      call symputx(''wtcnt'',i,''l''); ';
  put '    data _null_; file &fref encoding=''utf-8''; ';
  put '      put ",""WORK"":{"; ';
  put '    %do i=1 %to &wtcnt; ';
  put '      %let wt=&&wt&i; ';
  put '      proc contents noprint data=&wt ';
  put '        out=_data_ (keep=name type length format:); ';
  put '      run;%let tempds=%scan(&syslast,2,.); ';
  put '      data _null_; file &fref encoding=''utf-8''; ';
  put '        dsid=open("WORK.&wt",''is''); ';
  put '        nlobs=attrn(dsid,''NLOBS''); ';
  put '        nvars=attrn(dsid,''NVARS''); ';
  put '        rc=close(dsid); ';
  put '        if &i>1 then put '',''@; ';
  put '        put " ""&wt"" : {"; ';
  put '        put ''"nlobs":'' nlobs; ';
  put '        put '',"nvars":'' nvars; ';
  put '      %mp_jsonout(OBJ,&tempds,jref=&fref,dslabel=colattrs,engine=DATASTEP) ';
  put '      %mp_jsonout(OBJ,&wt,jref=&fref,dslabel=first10rows,engine=DATASTEP) ';
  put '      data _null_; file &fref encoding=''utf-8''; ';
  put '        put "}"; ';
  put '    %end; ';
  put '    data _null_; file &fref encoding=''utf-8''; ';
  put '      put "}"; ';
  put '    run; ';
  put '  %end; ';
  put '  /* close off json */ ';
  put '  data _null_;file &fref mod encoding=''utf-8''; ';
  put '    _PROGRAM=quote(trim(resolve(symget(''_PROGRAM'')))); ';
  put '    put ",""SYSUSERID"" : ""&sysuserid"" "; ';
  put '    put ",""MF_GETUSER"" : ""%mf_getuser()"" "; ';
  put '    put ",""_DEBUG"" : ""&_debug"" "; ';
  put '    _METAUSER=quote(trim(symget(''_METAUSER''))); ';
  put '    put ",""_METAUSER"": " _METAUSER; ';
  put '    _METAPERSON=quote(trim(symget(''_METAPERSON''))); ';
  put '    put '',"_METAPERSON": '' _METAPERSON; ';
  put '    put '',"_PROGRAM" : '' _PROGRAM ; ';
  put '    put ",""SYSCC"" : ""&syscc"" "; ';
  put '    put ",""SYSERRORTEXT"" : ""&syserrortext"" "; ';
  put '    put ",""SYSHOSTNAME"" : ""&syshostname"" "; ';
  put '    put ",""SYSJOBID"" : ""&sysjobid"" "; ';
  put '    put ",""SYSSITE"" : ""&syssite"" "; ';
  put '    put ",""SYSWARNINGTEXT"" : ""&syswarningtext"" "; ';
  put '    put '',"END_DTTM" : "'' "%sysfunc(datetime(),datetime20.3)" ''" ''; ';
  put '    put "}" @; ';
  put '  %if %str(&_debug) ge 131 %then %do; ';
  put '    put ''>>weboutEND<<''; ';
  put '  %end; ';
  put '  run; ';
  put '%end; ';
  put ' ';
  put '%mend; ';
  put ' ';
  put '%macro mf_getuser(type=META ';
  put ')/*/STORE SOURCE*/; ';
  put '  %local user metavar; ';
  put '  %if &type=OS %then %let metavar=_secureusername; ';
  put '  %else %let metavar=_metaperson; ';
  put ' ';
  put '  %if %symexist(SYS_COMPUTE_SESSION_OWNER) %then %let user=&SYS_COMPUTE_SESSION_OWNER; ';
  put '  %else %if %symexist(&metavar) %then %do; ';
  put '    %if %length(&&&metavar)=0 %then %let user=&sysuserid; ';
  put '    /* sometimes SAS will add @domain extension - remove for consistency */ ';
  put '    %else %let user=%scan(&&&metavar,1,@); ';
  put '  %end; ';
  put '  %else %let user=&sysuserid; ';
  put ' ';
  put '  %quote(&user) ';
  put ' ';
  put '%mend; ';
/* WEBOUT END */
  put '%macro webout(action,ds,dslabel=,fmt=);';
  put '  %mm_webout(&action,ds=&ds,dslabel=&dslabel,fmt=&fmt)';
  put '%mend;';
run;

/* add precode and code */
%local work tmpfile;
%let work=%sysfunc(pathname(work));
%let tmpfile=__mm_createwebservice.temp;
%local x fref freflist mod;
%let freflist= &adapter &precode &code ;
%do x=1 %to %sysfunc(countw(&freflist));
  %if &x>1 %then %let mod=mod;

  %let fref=%scan(&freflist,&x);
  %put &sysmacroname: adding &fref;
  data _null_;
    file "&work/&tmpfile" lrecl=3000 &mod;
    infile &fref;
    input;
    put _infile_;
  run;
%end;

/* create the metadata folder if not already there */
%mm_createfolder(path=&path)
%if &syscc ge 4 %then %return;

%if %upcase(&replace)=YES %then %do;
  %mm_deletestp(target=&path/&name)
%end;

/* create the web service */
%mm_createstp(stpname=&name
  ,filename=&tmpfile
  ,directory=&work
  ,tree=&path
  ,stpdesc=&desc
  ,mDebug=&mdebug
  ,server=&server
  ,stptype=2)

/* find the web app url */
%local url;
%let url=localhost/SASStoredProcess;
data _null_;
  length url $128;
  rc=METADATA_GETURI("Stored Process Web App",url);
  if rc=0 then call symputx('url',url,'l');
run;

%put ;%put ;%put ;%put ;%put ;%put ;
%put &sysmacroname: STP &name successfully created in &path;
%put ;%put ;%put ;
%put Check it out here:;
%put ;%put ;%put ;
%put &url?_PROGRAM=&path/&name;
%put ;%put ;%put ;%put ;%put ;%put ;

%mend;
/**
  @file mm_deletedocument.sas
  @brief Deletes a Document using path as reference
  @details

  Usage:

    %mm_createdocument(tree=/User Folders/&sysuserid,name=MyNote)
    %mm_deletedocument(target=/User Folders/&sysuserid/MyNote)

  <h4> Dependencies </h4>

  @param target= full path to the document being deleted

  @version 9.4
  @author Allan Bowe

**/

%macro mm_deletedocument(
     target=
)/*/STORE SOURCE*/;

/**
 * Check document exist
 */
%local type;
data _null_;
  length type uri $256;
  rc=metadata_pathobj("","&target",'Note',type,uri);
  call symputx('type',type,'l');
  call symputx('stpuri',uri,'l');
run;
%if &type ne Document %then %do;
  %put WARNING: No Document found at &target;
  %return;
%end;

filename __in temp lrecl=10000;
filename __out temp lrecl=10000;
data _null_ ;
   file __in ;
   put "<DeleteMetadata><Metadata><Document Id='&stpuri'/>";
   put "</Metadata><NS>SAS</NS><Flags>268436480</Flags><Options/>";
   put "</DeleteMetadata>";
run ;
proc metadata in=__in out=__out verbose;run;

/* list the result */
data _null_;infile __out; input; list; run;

filename __in clear;
filename __out clear;

/**
 * Check deletion
 */
%local isgone;
data _null_;
  length type uri $256;
  call missing (of _all_);
  rc=metadata_pathobj("","&target",'Note',type,uri);
  call symputx('isgone',type,'l');
run;
%if &isgone = Document %then %do;
  %put %str(ERR)OR: Document not deleted from &target;
  %let syscc=4;
  %return;
%end;

%mend;
/**
  @file mm_deletestp.sas
  @brief Deletes a Stored Process using path as reference
  @details Will only delete the metadata, not any physical files associated.

  Usage:

    %mm_deletestp(target=/some/meta/path/myStoredProcess)

  <h4> Dependencies </h4>

  @param target= full path to the STP being deleted

  @version 9.4
  @author Allan Bowe

**/

%macro mm_deletestp(
     target=
)/*/STORE SOURCE*/;

/**
 * Check STP does exist
 */
%local cmtype;
data _null_;
  length type uri $256;
  rc=metadata_pathobj("","&target",'StoredProcess',type,uri);
  call symputx('cmtype',type,'l');
  call symputx('stpuri',uri,'l');
run;
%if &cmtype ne ClassifierMap %then %do;
  %put NOTE: No Stored Process found at &target;
  %return;
%end;

filename __in temp lrecl=10000;
filename __out temp lrecl=10000;
data _null_ ;
   file __in ;
   put "<DeleteMetadata><Metadata><ClassifierMap Id='&stpuri'/>";
   put "</Metadata><NS>SAS</NS><Flags>268436480</Flags><Options/>";
   put "</DeleteMetadata>";
run ;
proc metadata in=__in out=__out verbose;run;

/* list the result */
data _null_;infile __out; input; list; run;

filename __in clear;
filename __out clear;

/**
 * Check deletion
 */
%local isgone;
data _null_;
  length type uri $256;
  call missing (of _all_);
  rc=metadata_pathobj("","&target",'Note',type,uri);
  call symputx('isgone',type,'l');
run;
%if &isgone = ClassifierMap %then %do;
  %put %str(ERR)OR: STP not deleted from &target;
  %let syscc=4;
  %return;
%end;

%mend;
/**
  @file mm_getauthinfo.sas
  @brief extracts authentication info
  @details usage:

    %mm_getauthinfo(outds=auths)

  @param outds= the ONE LEVEL work dataset to create

  <h4> Dependencies </h4>
  @li mm_getobjects.sas
  @li mf_getuniquefileref.sas
  @li mm_getdetails.sas

  @version 9.4
  @author Allan Bowe

**/

%macro mm_getauthinfo(outds=mm_getauthinfo
)/*/STORE SOURCE*/;

%if %length(&outds)>30 %then %do;
  %put %str(ERR)OR: Temp tables are created with the &outds prefix, which therefore
  needs to be 30 characters or less;
  %return;
%end;
%if %index(&outds,'.')>0 %then %do;
  %put %str(ERR)OR: Table &outds should be ONE LEVEL (no library);
  %return;
%end;

%mm_getobjects(type=Login,outds=&outds.0)

%local fileref;
%let fileref=%mf_getuniquefileref();

data _null_;
  file &fileref;
  set &outds.0 end=last;
  /* run macro */
  str=cats('%mm_getdetails(uri=',id,",outattrs=&outds.d",_n_
    ,",outassocs=&outds.a",_n_,")");
  put str;
  /* transpose attributes */
  str=cats("proc transpose data=&outds.d",_n_,"(drop=type) out=&outds.da"
    ,_n_,"(drop=_name_);var value;id name;run;");
  put str;
  /* add extra info to attributes */
  str=cats("data &outds.da",_n_,";length login_id login_name $256; login_id="
    ,quote(trim(id)),";set &outds.da",_n_
    ,";login_name=trim(subpad(name,1,256));drop name;run;");
  put str;
  /* add extra info to associations */
  str=cats("data &outds.a",_n_,";length login_id login_name $256; login_id="
    ,quote(trim(id)),";login_name=",quote(trim(name))
    ,";set &outds.a",_n_,";run;");
  put str;
  if last then do;
    /* collate attributes */
	  str=cats("data &outds._logat; set &outds.da1-&outds.da",_n_,";run;");
	  put str;
    /* collate associations */
	  str=cats("data &outds._logas; set &outds.a1-&outds.a",_n_,";run;");
	  put str;
    /* tidy up */
    str=cats("proc delete data=&outds.da1-&outds.da",_n_,";run;");
    put str;
    str=cats("proc delete data=&outds.d1-&outds.d",_n_,";run;");
    put str;
    str=cats("proc delete data=&outds.a1-&outds.a",_n_,";run;");
    put str;
  end;
run;
%inc &fileref;

/* get libraries */
proc sort data=&outds._logas(where=(assoc='Libraries')) out=&outds._temp;
  by login_id;
data &outds._temp;
  set &outds._temp;
  by login_id;
  length library_list $32767;
  retain library_list;
  if first.login_id then library_list=name;
  else library_list=catx(' !! ',library_list,name);
proc sql;
/* get auth domain */
create table &outds._dom as
  select login_id,name as domain
  from &outds._logas
  where assoc='Domain';
create unique index login_id on &outds._dom(login_id);
/* join it all together */
create table &outds._logins as
  select a.*
    ,c.domain
    ,b.library_list
  from &outds._logat (drop=ishidden lockedby usageversion publictype) a
  left join &outds._temp b
  on a.login_id=b.login_id
  left join &outds._dom c
  on a.login_id=c.login_id;
drop table &outds._temp;
drop table &outds._logat;
drop table &outds._logas;

data _null_;
  infile &fileref;
  if _n_=1 then putlog // "Now executing the following code:" //;
  input; putlog _infile_;
run;

filename &fileref clear;

%mend;/**
  @file
  @brief Creates a dataset with all metadata columns for a particular table
  @details

  usage:

    %mm_getcols(tableuri=A5X8AHW1.B40001S5)

  @param outds the dataset to create that contains the list of columns
  @param uri the uri of the table for which to return columns

  @returns outds  dataset containing all columns, specifically:
    - colname
    - coluri
    - coldesc

  @version 9.2
  @author Allan Bowe

**/

%macro mm_getcols(
     tableuri=
    ,outds=work.mm_getcols
)/*/STORE SOURCE*/;

data &outds;
  keep col: SAS:;
  length assoc uri coluri colname coldesc SASColumnType SASFormat SASInformat
      SASPrecision SASColumnLength $256;
  call missing (of _all_);
  uri=symget('tableuri');
  n=1;
  do while (metadata_getnasn(uri,'Columns',n,coluri)>0);
    rc3=metadata_getattr(coluri,"Name",colname);
    rc3=metadata_getattr(coluri,"Desc",coldesc);
    rc4=metadata_getattr(coluri,"SASColumnType",SASColumnType);
    rc5=metadata_getattr(coluri,"SASFormat",SASFormat);
    rc6=metadata_getattr(coluri,"SASInformat",SASInformat);
    rc7=metadata_getattr(coluri,"SASPrecision",SASPrecision);
    rc8=metadata_getattr(coluri,"SASColumnLength",SASColumnLength);
    output;
    call missing(colname,coldesc,SASColumnType,SASFormat,SASInformat
      ,SASPrecision,SASColumnLength);
    n+1;
  end;
run;
proc sort;
  by colname;
run;

%mend;/**
  @file mm_getdetails.sas
  @brief extracts metadata attributes and associations for a particular uri

  @param uri the metadata object for which to return attributes / associations
  @param outattrs= the dataset to create that contains the list of attributes
  @param outassocs= the dataset to contain the list of associations

  @version 9.2
  @author Allan Bowe

**/

%macro mm_getdetails(uri
  ,outattrs=work.attributes
  ,outassocs=work.associations
)/*/STORE SOURCE*/;

data &outassocs;
  keep assoc assocuri name;
  length assoc assocuri name $256;
  call missing(of _all_);
  rc1=1;n1=1;
  do while(rc1>0);
    /* Walk through all possible associations of this object. */
    rc1=metadata_getnasl("&uri",n1,assoc);
    rc2=1;n2=1;
    do while(rc2>0);
      /* Walk through all the associations on this machine object. */
      rc2=metadata_getnasn("&uri",trim(assoc),n2,assocuri);
      if (rc2>0) then do;
        rc3=metadata_getattr(assocuri,"Name",name);
        output;
      end;
      call missing(name,assocuri);
      n2+1;
    end;
    n1+1;
  end;
run;
proc sort;
  by assoc name;
run;

data &outattrs;
  keep type name value;
  length type $4 name $256 value $32767;
  rc1=1;n1=1;type='Prop';
  do while(rc1>0);
    rc1=metadata_getnprp("&uri",n1,name,value);
    if rc1>0 then output;
    n1+1;
  end;
  rc1=1;n1=1;type='Attr';
  do while(rc1>0);
    rc1=metadata_getnatr("&uri",n1,name,value);
    if rc1>0 then output;
    n1+1;
  end;
run;
proc sort;
  by type name;
run;

%mend;/**
  @file
  @brief Returns a dataset with the meta directory object for a physical path
  @details Provide a file path to get matching directory objects, or leave
    blank to return all directories.  The Directory object is used to reference
    a physical filepath (eg when registering a .sas program in a Stored process)

  @param path= the physical path for which to return a meta Directory object
  @param outds= the dataset to create that contains the list of directories
  @param mDebug= set to 1 to show debug messages in the log

  @returns outds  dataset containing the following columns:
   - directoryuri
   - groupname
   - groupdesc

  @version 9.2
  @author Allan Bowe

**/

%macro mm_getDirectories(
     path=
    ,outds=work.mm_getDirectories
    ,mDebug=0
)/*/STORE SOURCE*/;

%local mD;
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing mm_getDirectories.sas;
%&mD.put _local_;

data &outds (keep=directoryuri name directoryname directorydesc );
  length directoryuri name directoryname directorydesc $256;
  call missing(of _all_);
  __i+1;
%if %length(&path)=0 %then %do;
  do while
  (metadata_getnobj("omsobj:Directory?@Id contains '.'",__i,directoryuri)>0);
%end; %else %do;
  do while
  (metadata_getnobj("omsobj:Directory?@DirectoryName='&path'",__i,directoryuri)>0);
%end;
    __rc1=metadata_getattr(directoryuri, "Name", name);
    __rc2=metadata_getattr(directoryuri, "DirectoryName", directoryname);
    __rc3=metadata_getattr(directoryuri, "Desc", directorydesc);
    &mD.putlog (_all_) (=);
    drop __:;
    __i+1;
    if sum(of __rc1-__rc3)=0 then output;
  end;
run;

%mend;
/**
  @file
  @brief Writes the TextStore of a Document Object to an external file
  @details If the document exists, and has a textstore object, the contents
    of that textstore are written to an external file.

  usage:

      %mm_getdocument(tree=/some/meta/path
        ,name=someDocument
        ,outref=/some/unquoted/filename.ext
      )

  <h4> Dependencies </h4>
  @li mp_abort.sas

  @param tree= The metadata path of the document
  @param name= Document object name.
  @param outref= full and unquoted path to the desired text file.  This will be
    overwritten if it already exists.

  @author Allan Bowe

**/

%macro mm_getdocument(
    tree=/User Folders/sasdemo
    ,name=myNote
    ,outref=%sysfunc(pathname(work))/mm_getdocument.txt
    ,mDebug=1
    );

%local mD;
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing &sysmacroname..sas;
%&mD.put _local_;

/**
 * check tree exists
 */

data _null_;
  length type uri $256;
  rc=metadata_pathobj("","&tree","Folder",type,uri);
  call symputx('type',type,'l');
  call symputx('treeuri',uri,'l');
run;

%mp_abort(
  iftrue= (&type ne Tree)
  ,mac=mm_getdocument.sas
  ,msg=Tree &tree does not exist!
)

/**
 * Check object exists
 */
data _null_;
  length type docuri tsuri tsid $256 ;
  rc1=metadata_pathobj("","&tree/&name","Note",type,docuri);
  rc2=metadata_getnasn(docuri,"Notes",1,tsuri);
  rc3=metadata_getattr(tsuri,"Id",tsid);
  call symputx('type',type,'l');
  call symputx("tsid",tsid,'l');
  putlog (_all_)(=);
run;

%mp_abort(
  iftrue= (&type ne Document)
  ,mac=mm_getdocument.sas
  ,msg=Document &name could not be found in &tree!
)

/**
 * Now we can extract the textstore
 */
filename __getdoc temp lrecl=10000000;
proc metadata
 in="<GetMetadata><Reposid>$METAREPOSITORY</Reposid>
    <Metadata><TextStore Id='&tsid'/></Metadata>
    <Ns>SAS</Ns><Flags>1</Flags><Options/></GetMetadata>"
 out=__getdoc ;
run;

/* find the beginning of the text */
data _null_;
  infile __getdoc lrecl=10000;
  input;
  start=index(_infile_,'StoredText="');
  if start then do;
    call symputx("start",start+11);
    put start= "type=&type";
    putlog '"' _infile_ '"';
  end;
  stop;

/* read the content, byte by byte, resolving escaped chars */
filename __outdoc "&outref" lrecl=100000;
data _null_;
 length filein 8 fileid 8;
 filein = fopen("__getdoc","I",1,"B");
 fileid = fopen("__outdoc","O",1,"B");
 rec = "20"x;
 length entity $6;
 do while(fread(filein)=0);
   x+1;
   if x>&start then do;
    rc = fget(filein,rec,1);
    if rec='"' then leave;
    else if rec="&" then do;
      entity=rec;
      do until (rec=";");
        if fread(filein) ne 0 then goto getout;
        rc = fget(filein,rec,1);
        entity=cats(entity,rec);
      end;
      select (entity);
        when ('&amp;' ) rec='&'  ;
        when ('&lt;'  ) rec='<'  ;
        when ('&gt;'  ) rec='>'  ;
        when ('&apos;') rec="'"  ;
        when ('&quot;') rec='"'  ;
        when ('&#x0a;') rec='0A'x;
        when ('&#x0d;') rec='0D'x;
        when ('&#36;' ) rec='$'  ;
        when ('&#x09;') rec='09'x;
        otherwise putlog "WARNING: missing value for " entity=;
      end;
      rc =fput(fileid, substr(rec,1,1));
      rc =fwrite(fileid);
    end;
    else do;
      rc =fput(fileid,rec);
      rc =fwrite(fileid);
    end;
   end;
 end;
 getout:
 rc=fclose(filein);
 rc=fclose(fileid);
run;
filename __getdoc clear;
filename __outdoc clear;

%mend;
/**
  @file mm_getfoldertree.sas
  @brief Returns all folders / subfolder content for a particular root
  @details Shows all members and SubTrees recursively for a particular root.
  Note - for big sites, this returns a lot of data!  So you may wish to reduce
  the logging to speed up the process (see example below)
  Usage:

    options ps=max nonotes nosource;
    %mm_getfoldertree(root=/My/Meta/Path, outds=iwantthisdataset)
    options notes source;
    
  @param root= the parent folder under which to return all contents
  @param outds= the dataset to create that contains the list of directories
  @param mDebug= set to 1 to show debug messages in the log

  <h4> Dependencies </h4>

  @version 9.4
  @author Allan Bowe

**/
%macro mm_getfoldertree(
     root=
    ,outds=work.mm_getfoldertree
    ,mDebug=0
    ,depth=50 /* how many nested folders to query */
    ,level=1 /* system var - to track current level depth */
    ,append=NO  /* system var - when YES means appending within nested loop */
)/*/STORE SOURCE*/;

%if &level>&depth %then %return;

%local mD;
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing &sysmacroname;
%&mD.put _local_;

%if &append=NO %then %do;
  /* ensure table doesn't exist already */
  data &outds; run;
  proc sql; drop table &outds;
%end;

/* get folder contents */
data &outds.TMP/view=&outds.TMP;
  length metauri pathuri $64 name $256 path $1024
    assoctype publictype MetadataUpdated MetadataCreated $32;
  keep metauri assoctype name publictype MetadataUpdated MetadataCreated path;
  call missing(of _all_);
  path="&root";
  rc=metadata_pathobj("",path,"Folder",publictype,pathuri);
  if publictype ne 'Tree' then do;
    putlog "%str(WAR)NING: Tree " path 'does not exist!' publictype=;
    stop;
  end;
  __n1=1;
  do while(metadata_getnasl(pathuri,__n1,assoctype)>0);
    __n1+1;
    /* Walk through all possible associations of this object. */
    __n2=1;
    if assoctype in ('Members','SubTrees') then 
    do while(metadata_getnasn(pathuri,assoctype,__n2,metauri)>0);
      __n2+1;
      call missing(name,publictype,MetadataUpdated,MetadataCreated);
      __rc1=metadata_getattr(metauri,"Name", name);
      __rc2=metadata_getattr(metauri,"MetadataUpdated", MetadataUpdated);
      __rc3=metadata_getattr(metauri,"MetadataCreated", MetadataCreated);
      __rc4=metadata_getattr(metauri,"PublicType", PublicType);
      output;
    end;
    n1+1;
  end;
  drop __:;
run;

proc append base=&outds data=&outds.TMP;
run;

data _null_;
  set &outds.TMP(where=(assoctype='SubTrees'));
  call execute('%mm_getfoldertree(root='
    !!cats(path,"/",name)!!",outds=&outds,mDebug=&mdebug,depth=&depth"
    !!",level=%eval(&level+1),append=YES)");
run;

%mend;
/**
  @file
  @brief Creates dataset with all members of a metadata group
  @details
  
  usage:
  
    %mm_getgroupmembers(someGroupName
      ,outds=work.mm_getgroupmembers 
      ,emails=YES)

  @param group metadata group for which to bring back members
  @param outds= the dataset to create that contains the list of members
  @param emails= set to YES to bring back email addresses
  @param id= set to yes if passing an ID rather than a group name

  @returns outds  dataset containing all members of the metadata group

  @version 9.2
  @author Allan Bowe

**/

%macro mm_getgroupmembers(
    group /* metadata group for which to bring back members */
    ,outds=work.mm_getgroupmembers /* output dataset to contain the results */
    ,emails=NO /* set to yes to bring back emails also */
    ,id=NO /* set to yes if passing an ID rather than group name */
)/*/STORE SOURCE*/;

  data &outds ;
    attrib uriGrp uriMem GroupId GroupName Group_or_Role MemberName MemberType
      euri email           length=$64
      GroupDesc            length=$256
      rcGrp rcMem rc i j   length=3;
    call missing (of _all_);
    drop uriGrp uriMem rcGrp rcMem rc i j arc ;

    i=1;
    * Grab the URI for the first Group ;
    %if &id=NO %then %do;
      rcGrp=metadata_getnobj("omsobj:IdentityGroup?@Name='&group'",i,uriGrp);
    %end;
    %else %do;
      rcGrp=metadata_getnobj("omsobj:IdentityGroup?@Id='&group'",i,uriGrp);
    %end;
    * If Group found, enter do loop ;
    if rcGrp>0 then do;
      call missing (rcMem,uriMem,GroupId,GroupName,Group_or_Role
        ,MemberName,MemberType);
      * get group info ;
      rc = metadata_getattr(uriGrp,"Id",GroupId);
      rc = metadata_getattr(uriGrp,"Name",GroupName);
      rc = metadata_getattr(uriGrp,"PublicType",Group_or_Role);
      rc = metadata_getattr(uriGrp,"Desc",GroupDesc);
      j=1;
      do while (metadata_getnasn(uriGrp,"MemberIdentities",j,uriMem) > 0);
        call missing (MemberName, MemberType, email);
        rc = metadata_getattr(uriMem,"Name",MemberName);
        rc = metadata_getattr(uriMem,"PublicType",MemberType);
        if membertype='User' and "&emails"='YES' then do;
          if metadata_getnasn(uriMem,"EmailAddresses",1,euri)>0 then do;
            arc=metadata_getattr(euri,"Address",email);
          end;
        end;
        output;
        j+1;
      end;
    end;
  run;

%mend;
/**
  @file
  @brief Creates dataset with all groups or just those for a particular user
  @details Provide a metadata user to get groups for just that user, or leave
    blank to return all groups.
  Usage:

    - all groups
    %mm_getGroups()

    - all groups for a particular user
    %mm_getgroups(user=&sysuserid)

  @param user= the metadata user to return groups for.  Leave blank for all
    groups.
  @param outds= the dataset to create that contains the list of groups
  @param repo= the metadata repository that contains the user/group information
  @param mDebug= set to 1 to show debug messages in the log

  @returns outds  dataset containing all groups in a column named "metagroup"
   - groupuri
   - groupname
   - groupdesc

  @version 9.2
  @author Allan Bowe

**/

%macro mm_getGroups(
     user=
    ,outds=work.mm_getGroups
    ,repo=foundation
    ,mDebug=0
)/*/STORE SOURCE*/;

%local mD oldrepo;
%let oldrepo=%sysfunc(getoption(metarepository));
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing mm_getGroups.sas;
%&mD.put _local_;

/* on some sites, user / group info is in a different metadata repo to the default */
%if &oldrepo ne &repo %then %do;
  options metarepository=&repo;
%end;

%if %length(&user)=0 %then %do;
  data &outds (keep=groupuri groupname groupdesc);
    length groupuri groupname groupdesc group_or_role $256;
    call missing(of _all_);
    i+1;
    do while
    (metadata_getnobj("omsobj:IdentityGroup?@Id contains '.'",i,groupuri)>0);
      rc=metadata_getattr(groupuri, "Name", groupname);
      rc=metadata_getattr(groupuri, "Desc", groupdesc);
      rc=metadata_getattr(groupuri,"PublicType",group_or_role);
      if Group_or_Role = 'UserGroup' then output;
      i+1;
    end;
  run;
%end;
%else %do;
  data &outds (keep=groupuri groupname groupdesc);
    length uri groupuri groupname groupdesc group_or_role $256;
    call missing(of _all_);
    rc=metadata_getnobj("omsobj:Person?@Name='&user'",1,uri);
    if rc<=0 then do;
      putlog "%str(WARN)ING: rc=" rc "&user not found "
          ", or there was an issue reading the repository.";
      stop;
    end;
    a=1;
    grpassn=metadata_getnasn(uri,"IdentityGroups",a,groupuri);
    if grpassn in (-3,-4) then do;
      putlog "%str(WARN)ING: No metadata groups found for &user";
      output;
    end;
    else do while (grpassn > 0);
      rc=metadata_getattr(groupuri, "Name", groupname);
      rc=metadata_getattr(groupuri, "Desc", groupdesc);
      a+1;
      rc=metadata_getattr(groupuri,"PublicType",group_or_role);
      if Group_or_Role = 'UserGroup' then output;
      grpassn=metadata_getnasn(uri,"IdentityGroups",a,groupuri);
    end;
  run;
%end;

%if &oldrepo ne &repo %then %do;
  options metarepository=&oldrepo;
%end;

%mend;/**
  @file
  @brief Creates a dataset with all metadata libraries
  @details Will only show the libraries to which a user has the requisite
    metadata access.

  @param outds the dataset to create that contains the list of libraries
  @param mDebug set to anything but * or 0 to show debug messages in the log

  @returns outds  dataset containing all groups in a column named "metagroup"
    (defaults to work.mm_getlibs). The following columns are provided:
    - LibraryId
    - LibraryName
    - LibraryRef
    - Engine

  @warning The following filenames are created and then de-assigned:

      filename sxlemap clear;
      filename response clear;
      libname _XML_ clear;

  @version 9.2
  @author Allan Bowe

**/

%macro mm_getlibs(
    outds=work.mm_getLibs
)/*/STORE SOURCE*/;

/*
  flags:

  OMI_SUCCINCT     (2048) Do not return attributes with null values.
  OMI_GET_METADATA (256)  Executes a GetMetadata call for each object that
                          is returned by the GetMetadataObjects method.
  OMI_ALL_SIMPLE   (8)    Gets all of the attributes of the requested object.
*/
data _null_;
  flags=2048+256+8;
  call symputx('flags',flags,'l');
run;

* use a temporary fileref to hold the response;
filename response temp;
/* get list of libraries */
proc metadata in=
 '<GetMetadataObjects>
  <Reposid>$METAREPOSITORY</Reposid>
  <Type>SASLibrary</Type>
  <Objects/>
  <NS>SAS</NS>
  <Flags>&flags</Flags>
  <Options/>
  </GetMetadataObjects>'
  out=response;
run;

/* write the response to the log for debugging */
data _null_;
  infile response lrecl=32767;
  input;
  put _infile_;
run;

/* create an XML map to read the response */
filename sxlemap temp;
data _null_;
  file sxlemap;
  put '<SXLEMAP version="1.2" name="SASLibrary">';
  put '<TABLE name="SASLibrary">';
  put '<TABLE-PATH syntax="XPath">//Objects/SASLibrary</TABLE-PATH>';
  put '<COLUMN name="LibraryId">><LENGTH>17</LENGTH>';
  put '<PATH syntax="XPath">//Objects/SASLibrary/@Id</PATH></COLUMN>';
  put '<COLUMN name="LibraryName"><LENGTH>256</LENGTH>>';
  put '<PATH syntax="XPath">//Objects/SASLibrary/@Name</PATH></COLUMN>';
  put '<COLUMN name="LibraryRef"><LENGTH>8</LENGTH>';
  put '<PATH syntax="XPath">//Objects/SASLibrary/@Libref</PATH></COLUMN>';
  put '<COLUMN name="Engine">><LENGTH>12</LENGTH>';
  put '<PATH syntax="XPath">//Objects/SASLibrary/@Engine</PATH></COLUMN>';
  put '</TABLE></SXLEMAP>';
run;
libname _XML_ xml xmlfileref=response xmlmap=sxlemap;

/* sort the response by library name */
proc sort data=_XML_.saslibrary out=&outds;
  by libraryname;
run;


/* clear references */
filename sxlemap clear;
filename response clear;
libname _XML_ clear;

%mend;/**
  @file
  @brief Creates a dataset with all metadata objects for a particular type

  @param type= the metadata type for which to return all objects
  @param outds= the dataset to create that contains the list of types

  @returns outds  dataset containing all objects

  @warning The following filenames are created and then de-assigned:

      filename sxlemap clear;
      filename response clear;
      libname _XML_ clear;

  @version 9.2
  @author Allan Bowe

**/

%macro mm_getobjects(
  type=SASLibrary
  ,outds=work.mm_getobjects
)/*/STORE SOURCE*/;


* use a temporary fileref to hold the response;
filename response temp;
/* get list of libraries */
proc metadata in=
 "<GetMetadataObjects><Reposid>$METAREPOSITORY</Reposid>
   <Type>&type</Type><Objects/><NS>SAS</NS>
   <Flags>0</Flags><Options/></GetMetadataObjects>"
  out=response;
run;

/* write the response to the log for debugging */
data _null_;
  infile response lrecl=1048576;
  input;
  put _infile_;
run;

/* create an XML map to read the response */
filename sxlemap temp;
data _null_;
  file sxlemap;
  put '<SXLEMAP version="1.2" name="SASObjects"><TABLE name="SASObjects">';
  put "<TABLE-PATH syntax='XPath'>/GetMetadataObjects/Objects/&type</TABLE-PATH>";
  put '<COLUMN name="id">';
  put "<PATH syntax='XPath'>/GetMetadataObjects/Objects/&type/@Id</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>200</LENGTH>";
  put '</COLUMN><COLUMN name="name">';
  put "<PATH syntax='XPath'>/GetMetadataObjects/Objects/&type/@Name</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>200</LENGTH>";
  put '</COLUMN></TABLE></SXLEMAP>';
run;
libname _XML_ xml xmlfileref=response xmlmap=sxlemap;

proc sort data= _XML_.SASObjects out=&outds;
  by name;
run;

/* clear references */
filename sxlemap clear;
filename response clear;
libname _XML_ clear;

%mend;/**
  @file mm_getpublictypes.sas
  @brief Creates a dataset with all deployable public types
  @details More info: https://support.sas.com/documentation/cdl/en/bisag/65422/HTML/default/viewer.htm#n1nkrdzsq5iunln18bk2236istkb.htm
  
  Usage:

        * dataset will contain one column - publictype ($64);
        %mm_getpublictypes(outds=types)

  @returns outds= dataset containing all types

  @version 9.3
  @author Allan Bowe

**/

%macro mm_getpublictypes(
    outds=work.mm_getpublictypes
)/*/STORE SOURCE*/;

proc sql;
create table &outds (publictype char(64)); /* longest is currently 52 */
insert into &outds values ('ACT');
insert into &outds values ('Action');
insert into &outds values ('Application');
insert into &outds values ('ApplicationServer');
insert into &outds values ('BurstDefinition');
insert into &outds values ('Channel');
insert into &outds values ('Condition');
insert into &outds values ('ConditionActionSet');
insert into &outds values ('ContentSubscriber');
insert into &outds values ('Cube');
insert into &outds values ('DataExploration');
insert into &outds values ('DeployedFlow');
insert into &outds values ('DeployedJob');
insert into &outds values ('Document');
insert into &outds values ('EventSubscriber');
insert into &outds values ('ExternalFile');
insert into &outds values ('FavoritesFolder');
insert into &outds values ('Folder');
insert into &outds values ('Folder.SecuredData');
insert into &outds values ('GeneratedTransform');
insert into &outds values ('InformationMap');
insert into &outds values ('InformationMap.OLAP');
insert into &outds values ('InformationMap.Relational');
insert into &outds values ('JMSDestination (Java Messaging System message queue)');
insert into &outds values ('Job');
insert into &outds values ('Job.Cube');
insert into &outds values ('Library');
insert into &outds values ('MessageQueue');
insert into &outds values ('MiningResults');
insert into &outds values ('MQM.JMS (queue manager for Java Messaging Service)');
insert into &outds values ('MQM.MSMQ (queue manager for MSMQ)');
insert into &outds values ('MQM.Websphere (queue manager for WebSphere MQ)');
insert into &outds values ('Note');
insert into &outds values ('OLAPSchema');
insert into &outds values ('Project');
insert into &outds values ('Project.EG');
insert into &outds values ('Project.AMOExcel');
insert into &outds values ('Project.AMOPowerPoint');
insert into &outds values ('Project.AMOWord');
insert into &outds values ('Prompt');
insert into &outds values ('PromptGroup');
insert into &outds values ('Report');
insert into &outds values ('Report.Component');
insert into &outds values ('Report.Image');
insert into &outds values ('Report.StoredProcess');
insert into &outds values ('Role');
insert into &outds values ('SearchFolder');
insert into &outds values ('SecuredLibrary');
insert into &outds values ('Server');
insert into &outds values ('Service.SoapGenerated');
insert into &outds values ('SharedDimension');
insert into &outds values ('Spawner.Connect');
insert into &outds values ('Spawner.IOM (object spawner)');
insert into &outds values ('StoredProcess');
insert into &outds values ('SubscriberGroup.Content');
insert into &outds values ('SubscriberGroup.Event');
insert into &outds values ('Table');
insert into &outds values ('User');
insert into &outds values ('UserGroup');
quit;

%mend;/**
  @file
  @brief Creates a dataset with all available repositories

  @param outds= the dataset to create that contains the list of repos

  @returns outds  dataset containing all repositories

  @warning The following filenames are created and then de-assigned:

      filename sxlemap clear;
      filename response clear;
      libname _XML_ clear;

  @version 9.2
  @author Allan Bowe

**/

%macro mm_getrepos(
  outds=work.mm_getrepos
)/*/STORE SOURCE*/;


* use a temporary fileref to hold the response;
filename response temp;
/* get list of libraries */
proc metadata in=
 "<GetRepositories><Repositories/><Flags>1</Flags><Options/></GetRepositories>"
  out=response;
run;

/* write the response to the log for debugging */
/*
data _null_;
  infile response lrecl=1048576;
  input;
  put _infile_;
run;
*/

/* create an XML map to read the response */
filename sxlemap temp;
data _null_;
  file sxlemap;
  put '<SXLEMAP version="1.2" name="SASRepos"><TABLE name="SASRepos">';
  put "<TABLE-PATH syntax='XPath'>/GetRepositories/Repositories/Repository</TABLE-PATH>";
  put '<COLUMN name="id">';
  put "<PATH syntax='XPath'>/GetRepositories/Repositories/Repository/@Id</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>200</LENGTH>";
  put '</COLUMN>';
  put '<COLUMN name="name">';
  put "<PATH syntax='XPath'>/GetRepositories/Repositories/Repository/@Name</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>200</LENGTH>";
  put '</COLUMN>';
  put '<COLUMN name="desc">';
  put "<PATH syntax='XPath'>/GetRepositories/Repositories/Repository/@Desc</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>200</LENGTH>";
  put '</COLUMN>';
  put '<COLUMN name="DefaultNS">';
  put "<PATH syntax='XPath'>/GetRepositories/Repositories/Repository/@DefaultNS</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>200</LENGTH>";
  put '</COLUMN>';
  put '<COLUMN name="RepositoryType">';
  put "<PATH syntax='XPath'>/GetRepositories/Repositories/Repository/@RepositoryType</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>20</LENGTH>";
  put '</COLUMN>';
  put '<COLUMN name="RepositoryFormat">';
  put "<PATH syntax='XPath'>/GetRepositories/Repositories/Repository/@RepositoryFormat</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>10</LENGTH>";
  put '</COLUMN>';
  put '<COLUMN name="Access">';
  put "<PATH syntax='XPath'>/GetRepositories/Repositories/Repository/@Access</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>16</LENGTH>";
  put '</COLUMN>';
  put '<COLUMN name="CurrentAccess">';
  put "<PATH syntax='XPath'>/GetRepositories/Repositories/Repository/@CurrentAccess</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>16</LENGTH>";
  put '</COLUMN>';
  put '<COLUMN name="PauseState">';
  put "<PATH syntax='XPath'>/GetRepositories/Repositories/Repository/@PauseState</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>16</LENGTH>";
  put '</COLUMN>';
  put '<COLUMN name="Path">';
  put "<PATH syntax='XPath'>/GetRepositories/Repositories/Repository/@Path</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>256</LENGTH>";
  put '</COLUMN>';
  put '<COLUMN name="Engine">';
  put "<PATH syntax='XPath'>/GetRepositories/Repositories/Repository/@Engine</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>8</LENGTH>";
  put '</COLUMN>';
  put '<COLUMN name="Options">';
  put "<PATH syntax='XPath'>/GetRepositories/Repositories/Repository/@Options</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>32</LENGTH>";
  put '</COLUMN>';
  put '<COLUMN name="MetadataCreated">';
  put "<PATH syntax='XPath'>/GetRepositories/Repositories/Repository/@MetadataCreated</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>24</LENGTH>";
  put '</COLUMN>';
  put '<COLUMN name="MetadataUpdated">';
  put "<PATH syntax='XPath'>/GetRepositories/Repositories/Repository/@MetadataUpdated</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>24</LENGTH>";
  put '</COLUMN>';
  put '</TABLE></SXLEMAP>';
run;
libname _XML_ xml xmlfileref=response xmlmap=sxlemap;

proc sort data= _XML_.SASRepos out=&outds;
  by name;
run;

/* clear references */
filename sxlemap clear;
filename response clear;
libname _XML_ clear;

%mend;/**
  @file mm_getroles.sas
  @brief Creates a table containing a list of roles
  @details

  Usage:

    %mm_getroles()

  @param outds the dataset to create that contains the list of roles

  @returns outds  dataset containing all roles, with the following columns:
    - uri
    - name

  @warning The following filenames are created and then de-assigned:

      filename sxlemap clear;
      filename response clear;
      libname _XML_ clear;

  @version 9.3
  @author Allan Bowe

**/

%macro mm_getroles(
    outds=work.mm_getroles
)/*/STORE SOURCE*/;

filename response temp;
options noquotelenmax;
proc metadata in= '<GetMetadataObjects><Reposid>$METAREPOSITORY</Reposid>
 <Type>IdentityGroup</Type><NS>SAS</NS><Flags>388</Flags>
 <Options>
 <Templates><IdentityGroup Name="" Desc="" PublicType=""/></Templates>
 <XMLSelect search="@PublicType=''Role''"/>
 </Options>
 </GetMetadataObjects>'
  out=response;
run;

filename sxlemap temp;
data _null_;
  file sxlemap;
  put '<SXLEMAP version="1.2" name="roles"><TABLE name="roles">';
  put "<TABLE-PATH syntax='XPath'>/GetMetadataObjects/Objects/IdentityGroup</TABLE-PATH>";
  put '<COLUMN name="roleuri">';
  put "<PATH syntax='XPath'>/GetMetadataObjects/Objects/IdentityGroup/@Id</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>32</LENGTH>";
  put '</COLUMN><COLUMN name="rolename">';
  put "<PATH syntax='XPath'>/GetMetadataObjects/Objects/IdentityGroup/@Name</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>256</LENGTH>";
  put '</COLUMN><COLUMN name="roledesc">';
  put "<PATH syntax='XPath'>/GetMetadataObjects/Objects/IdentityGroup/@Desc</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>500</LENGTH>";
  put '</COLUMN></TABLE></SXLEMAP>';
run;
libname _XML_ xml xmlfileref=response xmlmap=sxlemap;

proc sort data= _XML_.roles out=&outds;
  by rolename;
run;

filename sxlemap clear;
filename response clear;
libname _XML_ clear;

%mend;
/**
  @file mm_getservercontexts.sas
  @brief Creates a dataset with all server contexts in all repos
  @details
  Usage:

    %mm_getservercontexts(outds=mm_getservercontexts)

  @param outds= the dataset to create that contains the list

  @warning The following filenames are created and then de-assigned:

      filename __mc1 clear;
      filename __mc2 clear;
      libname __mc3 clear;

  <h4> Dependencies </h4>
  @li mm_getrepos.sas

  @version 9.3
  @author Allan Bowe

**/

%macro mm_getservercontexts(
  outds=work.mm_getrepos
)/*/STORE SOURCE*/;
%local repo repocnt x;
%let repo=%sysfunc(getoption(metarepository));

/* first get list of available repos */
%mm_getrepos(outds=work.repos)
%let repocnt=0;
data _null_;
  set repos;
  where repositorytype in('CUSTOM','FOUNDATION');
  keep id name ;
  call symputx('repo'!!left(_n_),name,'l');
  call symputx('repocnt',_n_,'l');
run;

filename __mc1 temp;
filename __mc2 temp;
data &outds; length serveruri servername $200; stop;run;
%do x=1 %to &repocnt;
  options metarepository=&&repo&x;
  proc metadata in=
  "<GetMetadataObjects><Reposid>$METAREPOSITORY</Reposid>
  <Type>ServerContext</Type><Objects/><NS>SAS</NS>
  <Flags>0</Flags><Options/></GetMetadataObjects>"
    out=__mc1;
  run;
  /*
  data _null_;
    infile __mc1 lrecl=1048576;
    input;
    put _infile_;
  run;
  */
  data _null_;
    file __mc2;
    put '<SXLEMAP version="1.2" name="SASContexts"><TABLE name="SASContexts">';
    put "<TABLE-PATH syntax='XPath'>/GetMetadataObjects/Objects/ServerContext</TABLE-PATH>";
    put '<COLUMN name="serveruri">';
    put "<PATH syntax='XPath'>/GetMetadataObjects/Objects/ServerContext/@Id</PATH>";
    put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>200</LENGTH>";
    put '</COLUMN>';
    put '<COLUMN name="servername">';
    put "<PATH syntax='XPath'>/GetMetadataObjects/Objects/ServerContext/@Name</PATH>";
    put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>200</LENGTH>";
    put '</COLUMN>';
    put '</TABLE></SXLEMAP>';
  run;
  libname __mc3 xml xmlfileref=__mc1 xmlmap=__mc2;
  proc append base=&outds data=__mc3.SASContexts;run;
  libname __mc3 clear;
%end;

options metarepository=&repo;

filename __mc1 clear;
filename __mc2 clear;

%mend;/**
  @file
  @brief Writes the code of an to an external file, or the log if none provided
  @details Get the

  usage:

      %mm_getstpcode(tree=/some/meta/path
        ,name=someSTP
        ,outloc=/some/unquoted/filename.ext
      )

  @param tree= The metadata path of the Stored Process (can also contain name)
  @param name= Stored Process name.  Leave blank if included above.
  @param outloc= full and unquoted path to the desired text file.  This will be
    overwritten if it already exists.  If not provided, the code will be written
    to the log.

  @author Allan Bowe

**/

%macro mm_getstpcode(
    tree=/User Folders/sasdemo/somestp
    ,name=
    ,outloc=
    ,mDebug=1
    );

%local mD;
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing &sysmacroname..sas;
%&mD.put _local_;

%if %length(&name)>0 %then %let name=/&name;

/* first, check if STP exists */
%local tsuri;
%let tsuri=stopifempty ;

data _null_;
  format type uri tsuri value $200.;
  call missing (of _all_);
  path="&tree&name(StoredProcess)";
  /* first, find the STP ID */
  if metadata_pathobj("",path,"StoredProcess",type,uri)>0 then do;
    /* get sourcecode */
    cnt=1;
    do while (metadata_getnasn(uri,"Notes",cnt,tsuri)>0);
      rc=metadata_getattr(tsuri,"Name",value);
      put tsuri= value=;
      if value="SourceCode" then do;
        /* found it! */
        rc=metadata_getattr(tsuri,"Id",value);
        call symputx('tsuri',value,'l');
        stop;
      end;
      cnt+1;
    end;
  end;
  else put (_all_)(=);
run;

%if &tsuri=stopifempty %then %do;
  %put %str(WARN)ING:  &tree&name.(StoredProcess) not found!;
  %return;
%end;


/**
 * Now we can extract the textstore
 */
filename __getdoc temp lrecl=10000000;
proc metadata
 in="<GetMetadata><Reposid>$METAREPOSITORY</Reposid>
    <Metadata><TextStore Id='&tsuri'/></Metadata>
    <Ns>SAS</Ns><Flags>1</Flags><Options/></GetMetadata>"
 out=__getdoc ;
run;

/* find the beginning of the text */
%local start;
data _null_;
  infile __getdoc lrecl=10000;
  input;
  start=index(_infile_,'StoredText="');
  if start then do;
    call symputx("start",start+11);
    *putlog '"' _infile_ '"';
  end;
  stop;

%local outeng;
%if %length(&outloc)=0 %then %let outeng=TEMP;
%else %let outeng="&outloc";
/* read the content, byte by byte, resolving escaped chars */
filename __outdoc &outeng lrecl=100000;
data _null_;
 length filein 8 fileid 8;
 filein = fopen("__getdoc","I",1,"B");
 fileid = fopen("__outdoc","O",1,"B");
 rec = "20"x;
 length entity $6;
 do while(fread(filein)=0);
   x+1;
   if x>&start then do;
    rc = fget(filein,rec,1);
    if rec='"' then leave;
    else if rec="&" then do;
      entity=rec;
      do until (rec=";");
        if fread(filein) ne 0 then goto getout;
        rc = fget(filein,rec,1);
        entity=cats(entity,rec);
      end;
      select (entity);
        when ('&amp;' ) rec='&'  ;
        when ('&lt;'  ) rec='<'  ;
        when ('&gt;'  ) rec='>'  ;
        when ('&apos;') rec="'"  ;
        when ('&quot;') rec='"'  ;
        when ('&#x0a;') rec='0A'x;
        when ('&#x0d;') rec='0D'x;
        when ('&#36;' ) rec='$'  ;
        when ('&#x09;') rec='09'x;
        otherwise putlog "%str(WARN)ING: missing value for " entity=;
      end;
      rc =fput(fileid, substr(rec,1,1));
      rc =fwrite(fileid);
    end;
    else do;
      rc =fput(fileid,rec);
      rc =fwrite(fileid);
    end;
   end;
 end;
 getout:
 rc=fclose(filein);
 rc=fclose(fileid);
run;

%if &outeng=TEMP %then %do;
  data _null_;
    infile __outdoc lrecl=32767 end=last;
    input;
    if _n_=1 then putlog '>>stpcodeBEGIN<<';
    putlog _infile_;
    if last then putlog '>>stpcodeEND<<';
  run;
%end;

filename __getdoc clear;
filename __outdoc clear;

%mend;
/**
  @file
  @brief Returns a dataset with all Stored Processes, or just those in a
    particular folder / with a  particular name.
  @details Leave blank to get all stps.  Provide a Tree (path or uri) or a
    name (not case sensitive) to filter that way also.
  usage:

      %mm_getstps()

      %mm_getstps(name=My STP)

      %mm_getstps(tree=/My Folder/My STPs)

      %mm_getstps(tree=/My Folder/My STPs, name=My STP)

  <h4> Dependencies </h4>
  @li mm_gettree.sas

  @param tree= the metadata folder location in which to search.  Leave blank
    for all folders.  Does not search subdirectories.
  @param name= Provide the name of an STP to search for just that one.  Can
    combine with the <code>tree=</code> parameter.
  @param outds= the dataset to create that contains the list of stps.
  @param mDebug= set to 1 to show debug messages in the log
  @param showDesc= provide a non blank value to return stored process descriptions
  @param showUsageVersion= provide a non blank value to return the UsageVersion.  This
    is either 1000000 (type 1, 9.2) or 2000000 (type2, 9.3 onwards).

  @returns outds  dataset containing the following columns
   - stpuri
   - stpname
   - treeuri
   - stpdesc (if requested)
   - usageversion (if requested)

  @version 9.2
  @author Allan Bowe

**/

%macro mm_getstps(
     tree=
    ,name=
    ,outds=work.mm_getstps
    ,mDebug=0
    ,showDesc=
    ,showUsageVersion=
)/*/STORE SOURCE*/;

%local mD;
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing mm_getstps.sas;
%&mD.put _local_;

data &outds;
  length stpuri stpname usageversion treeuri stpdesc $256;
  call missing (of _all_);
run;

%if %length(&tree)>0 %then %do;
  /* get tree info */
  %mm_gettree(tree=&tree,inds=&outds, outds=&outds, mDebug=&mDebug)
    %if %mf_nobs(&outds)=0 %then %do;
    %put NOTE:  Tree &tree did not exist!!;
    %return;
  %end;
%end;



data &outds ;
  set &outds(rename=(treeuri=treeuri_compare));
  length treeuri query stpuri $256;
  i+1;
%if %length(&name)>0 %then %do;
  query="omsobj:ClassifierMap?@PublicType='StoredProcess' and @Name='&name'";
  putlog query=;
%end;
%else %do;
  query="omsobj:ClassifierMap?@PublicType='StoredProcess'";
%end;
%if &mDebug=1 %then %do;
  putlog 'start' (_all_)(=);
%end;
  do while(0<metadata_getnobj(query,i,stpuri));
    i+1;
    rc1=metadata_getattr(stpuri,"Name", stpname);
    rc2=metadata_getnasn(stpuri,"Trees",1,treeuri);
  %if %length(&tree)>0 %then %do;
    if treeuri ne treeuri_compare then goto exitloop;
  %end;
  %if %length(&showDesc)>0 %then %do;
    rc3=metadata_getattr(stpuri,"Desc", stpdesc);
    keep stpdesc;
  %end;
  %if %length(&showUsageVersion)>0 %then %do;
    rc4=metadata_getattr(stpuri,"UsageVersion",UsageVersion);
    keep usageversion;
  %end;
    output;
    &mD.put (_all_)(=);
    exitloop:
  end;
  keep stpuri stpname treeuri;
run;

%mend;
/**
  @file mm_gettableid.sas
  @brief Get the metadata id for a particular table
  @details Provide a libref and table name to return the corresponding metadata id
  in an output datataset.

  Usage:

      - get a table id
      %mm_gettableid(libref=METALIB,ds=SOMETABLE,outds=iwant)

  @param libref= The libref to search
  @param ds= The input dataset to check
  @param outds= the dataset to create that contains the `tableuri`
  @param mDebug= set to 1 to show debug messages in the log

  @returns outds  dataset containing `tableuri` and `tablename`

  @version 9.3
  @author Allan Bowe

**/

%macro mm_gettableid(
     libref=
    ,ds=
    ,outds=work.mm_gettableid
    ,mDebug=0
)/*/STORE SOURCE*/;

%local mD;
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing &sysmacroname..sas;
%&mD.put _local_;

data &outds;
  length uri usingpkguri id type tableuri tablename tmpuri $256;
  call missing(of _all_);
  keep tableuri tablename;
  n=1;
  rc=0;
  if metadata_getnobj("omsobj:SASLibrary?@Libref='&libref'",n,uri)<1 then do;
    put "Library &libref not found";
    stop;
  end;
  &mD.putlog "uri is " uri;
  if metadata_getnasn(uri, "UsingPackages", 1, usingpkguri)>0 then do;
    rc=metadata_resolve(usingpkguri,type,id);
    &mD.putlog "Type is " type;
  end;

  if type='DatabaseSchema' then tmpuri=usingpkguri;
  else tmpuri=uri;
  
  t=1;
  do while(metadata_getnasn(tmpuri, "Tables", t, tableuri)>0);
    t+1;
    rc= metadata_getattr(tableuri, "Name", tablename);
    &mD.putlog "Table is " tablename;
    if upcase(tablename)="%upcase(&ds)" then do;
      output;
    end;
  end;
run;

%mend;/**
  @file
  @brief Creates a dataset with all metadata tables for a particular library
  @details Will only show the tables to which a user has the requisite
    metadata access.

  usage:

    %mm_gettables(uri=A5X8AHW1.B40001S5)

  @param outds the dataset to create that contains the list of tables
  @param uri the uri of the library for which to return tables
  @param getauth= YES|NO - fetch the authdomain used in database connections.
  Set to NO to improve runtimes in larger environments, as there can be a
  performance hit on the `metadata_getattr(domainuri, "Name", AuthDomain)` call.

  @returns outds  dataset containing all groups in a column named "metagroup"
    (defaults to work.mm_getlibs). The following columns are provided:
    - tablename
    - tableuri
    - libref
    - libname
    - libdesc

  @version 9.2
  @author Allan Bowe

**/

%macro mm_gettables(
    uri=
    ,outds=work.mm_gettables
    ,getauth=YES
)/*/STORE SOURCE*/;


data &outds;
  length uri serveruri conn_uri domainuri libname ServerContext AuthDomain
    path_schema usingpkguri type tableuri $256 id $17
    libdesc $200 libref engine $8 IsDBMSLibname $1
    tablename $50 /* metadata table names can be longer than $32 */
    ;
  keep libname libdesc libref engine ServerContext path_schema AuthDomain tableuri
    tablename IsPreassigned IsDBMSLibname id;
  call missing (of _all_);

  uri=symget('uri');
  rc= metadata_getattr(uri, "Name", libname);
  if rc <0 then do;
    put 'The library is not defined in this metadata repository.';
    stop;
  end;
  rc= metadata_getattr(uri, "Desc", libdesc);
  rc= metadata_getattr(uri, "Libref", libref);
  rc= metadata_getattr(uri, "Engine", engine);
  rc= metadata_getattr(uri, "IsDBMSLibname", IsDBMSLibname);
  rc= metadata_getattr(uri, "IsPreassigned", IsPreassigned);
  rc= metadata_getattr(uri, "Id", Id);

  /*** Get associated ServerContext ***/
  rc= metadata_getnasn(uri, "DeployedComponents", 1, serveruri);
  if rc > 0 then rc2= metadata_getattr(serveruri, "Name", ServerContext);
  else ServerContext='';

    /*** If the library is a DBMS library, get the Authentication Domain
          associated with the DBMS connection credentials ***/
  if IsDBMSLibname="1" and "&getauth"='YES' then do;
    rc= metadata_getnasn(uri, "LibraryConnection", 1, conn_uri);
    if rc>0 then do;
      rc2= metadata_getnasn(conn_uri, "Domain", 1, domainuri);
      if rc2>0 then rc3= metadata_getattr(domainuri, "Name", AuthDomain);
    end;
  end;

  /*** Get the path/database schema for this library ***/
  rc=metadata_getnasn(uri, "UsingPackages", 1, usingpkguri);
  if rc>0 then do;
    rc=metadata_resolve(usingpkguri,type,id);
    if type='Directory' then
      rc=metadata_getattr(usingpkguri, "DirectoryName", path_schema);
    else if type='DatabaseSchema' then
      rc=metadata_getattr(usingpkguri, "Name", path_schema);
    else path_schema="unknown";
  end;

  /*** Get the tables associated with this library ***/
  /*** If DBMS, tables are associated with DatabaseSchema ***/
  if type='DatabaseSchema' then do;
    t=1;
    ntab=metadata_getnasn(usingpkguri, "Tables", t, tableuri);
    if ntab>0 then do t=1 to ntab;
      tableuri='';
      tablename='';
      ntab=metadata_getnasn(usingpkguri, "Tables", t, tableuri);
      tabrc= metadata_getattr(tableuri, "Name", tablename);
      output;
    end;
    else put 'Library ' libname ' has no tables registered';
  end;
  else if type in ('Directory','SASLibrary') then do;
    t=1;
    ntab=metadata_getnasn(uri, "Tables", t, tableuri);
    if ntab>0 then do t=1 to ntab;
      tableuri='';
      tablename='';
      ntab=metadata_getnasn(uri, "Tables", t, tableuri);
      tabrc= metadata_getattr(tableuri, "Name", tablename);
      output;
    end;
    else put 'Library ' libname ' has no tables registered';
  end;
run;

proc sort;
by tablename tableuri;
run;

%mend;/**
  @file
  @brief Returns the metadata path and object from either the path or object
  @details Provide a metadata BIP tree path, or the uri for the bottom level
  folder, to obtain a dataset (<code>&outds</code>) containing both the path
  and uri.

  Usage:

      %mm_getTree(tree=/User Folders/sasdemo)


  @param tree= the BIP Tree folder path or uri
  @param outds= the dataset to create that contains the tree path & uri
  @param inds= an optional input dataset to augment with treepath & treeuri
  @param mDebug= set to 1 to show debug messages in the log

  @returns outds  dataset containing the following columns:
   - treeuri
   - treepath

  @version 9.2
  @author Allan Bowe

**/

%macro mm_getTree(
     tree=
    ,inds=
    ,outds=work.mm_getTree
    ,mDebug=0
)/*/STORE SOURCE*/;

%local mD;
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing mm_getTree.sas;
%&mD.put _local_;

data &outds;
  length treeuri __parenturi __type __name $256 treepath $512;
%if %length(&inds)>0 %then %do;
  set &inds;
%end;
  __rc1=metadata_resolve("&tree",__type,treeuri);

  if __type='Tree' then do;
    __rc2=metadata_getattr(treeuri,"Name",__name);
    treepath=cats('/',__name);
    /* get parents */
    do while (metadata_getnasn(treeuri,"ParentTree",1,__parenturi)>0);
      __rc3=metadata_getattr(__parenturi,"Name",__name);
      treepath=cats('/',__name,treepath);
      treeuri=__parenturi;
    end;
    treeuri="&tree";
  end;
  else do;
    __rc2=metadata_pathobj(' ',"&tree",'Folder',__type,treeuri);
    treepath="&tree";
  end;

  &mD.put (_all_)(=);
  drop __:;
  if treeuri ne "" and treepath ne "" then output;
  stop;
run;
%mend;/**
  @file
  @brief Creates a dataset with all metadata types
  @details Usage:

    %mm_gettypes(outds=types)

  @param outds the dataset to create that contains the list of types
  @returns outds  dataset containing all types
  @warning The following filenames are created and then de-assigned:

      filename sxlemap clear;
      filename response clear;
      libname _XML_ clear;

  @version 9.2
  @author Allan Bowe

**/

%macro mm_gettypes(
    outds=work.mm_gettypes
)/*/STORE SOURCE*/;

* use a temporary fileref to hold the response;
filename response temp;
/* get list of libraries */
proc metadata in=
 '<GetTypes>
   <Types/>
   <NS>SAS</NS>
   <!-- specify the OMI_SUCCINCT flag -->
   <Flags>2048</Flags>
   <Options>
     <!-- include <REPOSID> XML element and a repository identifier -->
     <Reposid>$METAREPOSITORY</Reposid>
   </Options>
</GetTypes>'
  out=response;
run;

/* write the response to the log for debugging */
data _null_;
  infile response lrecl=1048576;
  input;
  put _infile_;
run;

/* create an XML map to read the response */
filename sxlemap temp;
data _null_;
  file sxlemap;
  put '<SXLEMAP version="1.2" name="SASTypes"><TABLE name="SASTypes">';
  put '<TABLE-PATH syntax="XPath">//GetTypes/Types/Type</TABLE-PATH>';
  put '<COLUMN name="ID"><LENGTH>64</LENGTH>';
  put '<PATH syntax="XPath">//GetTypes/Types/Type/@Id</PATH></COLUMN>';
  put '<COLUMN name="Desc"><LENGTH>256</LENGTH>';
  put '<PATH syntax="XPath">//GetTypes/Types/Type/@Desc</PATH></COLUMN>';
  put '<COLUMN name="HasSubtypes">';
  put '<PATH syntax="XPath">//GetTypes/Types/Type/@HasSubtypes</PATH></COLUMN>';
  put '</TABLE></SXLEMAP>';
run;
libname _XML_ xml xmlfileref=response xmlmap=sxlemap;
/* sort the response by library name */
proc sort data=_XML_.sastypes out=&outds;
  by id;
run;


/* clear references */
filename sxlemap clear;
filename response clear;
libname _XML_ clear;

%mend;/**
  @file mm_getusers.sas
  @brief Creates a table containing a list of all users
  @details Only shows a limited number of attributes as some sites will have a
  LOT of users.

  Usage:

    %mm_getusers()

  @param outds the dataset to create that contains the list of libraries

  @returns outds  dataset containing all users, with the following columns:
    - uri
    - name

  @warning The following filenames are created and then de-assigned:

      filename sxlemap clear;
      filename response clear;
      libname _XML_ clear;

  @version 9.3
  @author Allan Bowe

**/

%macro mm_getusers(
    outds=work.mm_getusers
)/*/STORE SOURCE*/;

filename response temp;
proc metadata in= '<GetMetadataObjects>
 <Reposid>$METAREPOSITORY</Reposid>
 <Type>Person</Type>
 <NS>SAS</NS>
 <Flags>0</Flags>
 <Options>
 <Templates>
 <Person Name=""/>
 </Templates>
 </Options>
 </GetMetadataObjects>'
  out=response;
run;

filename sxlemap temp;
data _null_;
  file sxlemap;
  put '<SXLEMAP version="1.2" name="SASObjects"><TABLE name="SASObjects">';
  put "<TABLE-PATH syntax='XPath'>/GetMetadataObjects/Objects/Person</TABLE-PATH>";
  put '<COLUMN name="uri">';
  put "<PATH syntax='XPath'>/GetMetadataObjects/Objects/Person/@Id</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>32</LENGTH>";
  put '</COLUMN><COLUMN name="name">';
  put "<PATH syntax='XPath'>/GetMetadataObjects/Objects/Person/@Name</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>256</LENGTH>";
  put '</COLUMN></TABLE></SXLEMAP>';
run;
libname _XML_ xml xmlfileref=response xmlmap=sxlemap;

proc sort data= _XML_.SASObjects out=&outds;
  by name;
run;

filename sxlemap clear;
filename response clear;
libname _XML_ clear;

%mend;
/**
  @file
  @brief Retrieves properties of the SAS web app server
  @details
  Usage:

      %mm_getwebappsrvprops(outds= some_ds)
      data _null_;
        set some_ds(where=(name='webappsrv.server.url'));
        put value=;
      run;

  @param outds the dataset to create that contains the list of properties

  @returns outds  dataset containing all properties

  @warning The following filenames are created and then de-assigned:

      filename __in clear;
      filename __out clear;
      libname __shake clear;

  @version 9.4
  @author Allan Bowe https://github.com/sasjs/core

**/

%macro mm_getwebappsrvprops(
    outds= mm_getwebappsrvprops
)/*/STORE SOURCE*/;

filename __in temp lrecl=10000;
filename __out temp lrecl=10000;
filename __shake temp lrecl=10000;
data _null_ ;
   file __in ;
   put '<GetMetadataObjects>' ;
   put '<Reposid>$METAREPOSITORY</Reposid>' ;
   put '<Type>TextStore</Type>' ;
   put '<NS>SAS</NS>' ;
    put '<Flags>388</Flags>' ;
   put '<Options>' ;
    put '<XMLSelect search="TextStore[@Name='@@;
    put "'Public Configuration Properties']" @@;
     put '[Objects/SoftwareComponent[@ClassIdentifier=''webappsrv'']]' ;
   put '"/>';
   put '<Templates>' ;
   put '<TextStore StoredText="">' ;
   put '</TextStore>' ;
   put '</Templates>' ;
   put '</Options>' ;
   put '</GetMetadataObjects>' ;
run ;
proc metadata in=__in out=__out verbose;run;

/* find the beginning of the text */
%local start;
%let start=0;
data _null_;
  infile __out lrecl=10000;
  input;
  length cleartemplate $32000;
  cleartemplate=tranwrd(_infile_,'StoredText=""','');
  start=index(cleartemplate,'StoredText="');
  if start then do;
    call symputx("start",start+11+length('StoredText=""')-1);
    putlog cleartemplate ;
  end;
  stop;
run;
%put &=start;
%if &start>0 %then %do;
  /* read the content, byte by byte, resolving escaped chars */
  data _null_;
  length filein 8 fileid 8;
  filein = fopen("__out","I",1,"B");
  fileid = fopen("__shake","O",1,"B");
  rec = "20"x;
  length entity $6;
  do while(fread(filein)=0);
    x+1;
    if x>&start then do;
      rc = fget(filein,rec,1);
      if rec='"' then leave;
      else if rec="&" then do;
        entity=rec;
        do until (rec=";");
          if fread(filein) ne 0 then goto getout;
          rc = fget(filein,rec,1);
          entity=cats(entity,rec);
        end;
        select (entity);
          when ('&amp;' ) rec='&'  ;
          when ('&lt;'  ) rec='<'  ;
          when ('&gt;'  ) rec='>'  ;
          when ('&apos;') rec="'"  ;
          when ('&quot;') rec='"'  ;
          when ('&#x0a;') rec='0A'x;
          when ('&#x0d;') rec='0D'x;
          when ('&#36;' ) rec='$'  ;
          when ('&#x09;') rec='09'x;
          otherwise putlog "WARNING: missing value for " entity=;
        end;
        rc =fput(fileid, substr(rec,1,1));
        rc =fwrite(fileid);
      end;
      else do;
        rc =fput(fileid,rec);
        rc =fwrite(fileid);
      end;
    end;
  end;
  getout:
  rc=fclose(filein);
  rc=fclose(fileid);
  run;
  data &outds ;
    infile __shake dlm='=' missover;
    length name $50 value $500;
    input name $ value $;
  run;
%end;
%else %do;
  %put NOTE: Unable to retrieve Web App Server Properties;
  data &outds;
    length name $50 value $500;
  run;
%end;

/* clear references */
filename __in clear;
filename __out clear;
filename __shake clear;

%mend;/**
  @file mm_spkexport.sas
  @brief Creates an batch spk export command
  @details Creates a script that will export everything in a metadata folder to 
    a specified location.
    If you have XCMD enabled, then you can use mmx_spkexport (which performs
    the actual export)

    Note - the batch tools require a username and password.  For security,
    these are expected to have been provided in a protected directory.

  Usage:

      %* import the macros (or make them available some other way);
      filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

      %* create sample text file as input to the macro;
      filename tmp temp;
      data _null_;
        file tmp;
        put '%let mmxuser="sasdemo";';
        put '%let mmxpass="Mars321";';
      run;

      filename myref "%sysfunc(pathname(work))/mmxexport.sh";
      %mm_spkexport(metaloc=%str(/my/meta/loc)
          ,outref=myref
          ,secureref=tmp
          ,cmdoutloc=%str(/tmp)
      )

  Alternatively, call without inputs to create a function style output

      filename myref "/tmp/mmscript.sh";
      %mm_spkexport(metaloc=%str(/my/meta/loc)
           outref=myref
          ,cmdoutloc=%str(/tmp)
          ,cmdoutname=mmx
      )

  You can then navigate and execute as follows:

      cd /tmp
      ./mmscript.sh "myuser" "mypass"


  <h4> Dependencies </h4>
  @li mf_loc.sas
  @li mm_tree.sas
  @li mf_getuniquefileref.sas
  @li mf_isblank.sas
  @li mp_abort.sas

  @param metaloc= the metadata folder to export
  @param secureref= fileref containing the username / password (should point to
    a file in a secure location).  Leave blank to substitute $bash type vars.
  @param outref= fileref to which to write the command
  @param cmdoutloc= the directory to which the command will write the SPK 
    (default=WORK)
  @param cmdoutname= the name of the spk / log files to create (will be 
    identical just with .spk or .log extension)

  @version 9.4
  @author Allan Bowe

**/

%macro mm_spkexport(metaloc=
  ,secureref=
  ,outref=
  ,cmdoutloc=%sysfunc(pathname(work))
  ,cmdoutname=mmxport
);

%if &sysscp=WIN %then %do;
  %put %str(WARN)ING: the script has been written assuming a unix system;
  %put %str(WARN)ING- it will run anyway as should be easy to modify;
%end;

/* set creds */
%local mmxuser mmxpath;
%let mmxuser=$1;
%let mmxpass=$2;
%if %mf_isblank(&secureref)=0 %then %do;
  %inc &secureref/nosource;
%end;

/* setup metadata connection options */
%local host port platform_object_path connx_string;
%let host=%sysfunc(getoption(metaserver));
%let port=%sysfunc(getoption(metaport));
%let platform_object_path=%mf_loc(POF);

%let connx_string=%str(-host &host -port &port -user &mmxuser -password &mmxpass);

%mm_tree(root=%str(&metaloc) ,types=EXPORTABLE ,outds=exportable)

%if %mf_isblank(&outref)=1 %then %let outref=%mf_getuniquefileref();

data _null_;
  set exportable end=last;
  file &outref lrecl=32767;
  length str $32767;
  if _n_=1 then do;
    put "cd ""&platform_object_path"" \";
    put "; ./ExportPackage &connx_string -disableX11 \";
    put " -package ""&cmdoutloc/&cmdoutname..spk"" \";
  end;
  str=' -objects '!!cats('"',path,'/',name,"(",publictype,')" \');
  put str;
  if last then put " -log ""&cmdoutloc/&cmdoutname..log"" 2>&1 ";
run;

%mp_abort(iftrue= (&syscc ne 0)
  ,mac=&sysmacroname
  ,msg=%str(syscc=&syscc)
)

%mend;/**
  @file mm_tree.sas
  @brief Returns all folders / subfolder content for a particular root
  @details Shows all members and SubTrees for a particular root.

  Model:

      metauri char(64),
      name char(256) format=$256. informat=$256. label='name',
      path char(1024),
      publictype char(32),
      MetadataUpdated char(32),
      MetadataCreated char(32)

  Usage:

      %* load macros;
      filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

      %* export everything;
      %mm_tree(root= ,outds=iwantthisdataset)

      %* export everything in a specific folder;
      %mm_tree(root=%str(/my/folder) ,outds=stuff)

      %* export only folders;
      %mm_tree(root=%str(/my/folder) ,types=Folder ,outds=stuf)

      %* show only exportable content;
      %mm_tree(root=%str(/) ,types=EXPORTABLE ,outds=exportable)

      %* with specific types;
      %mm_tree(root=%str(/my/folder)
        ,types= 
            DeployedJob 
            ExternalFile 
            Folder 
            Folder.SecuredData 
            GeneratedTransform 
            InformationMap.Relational 
            Job 
            Library 
            Prompt 
            StoredProcess
            Table
        ,outds=morestuff)

  <h4> Dependencies </h4>
  @li mf_getquotedstr.sas
  @li mm_getpublictypes.sas
  @li mf_isblank.sas

  @param root= the parent folder under which to return all contents
  @param outds= the dataset to create that contains the list of directories
  @param types= Space-seperated, unquoted list of types for filtering the 
    output.  Special types:  

    * ALl - return all types (the default)
    * EXPORTABLE - return only the content types that can be exported in an SPK

  @version 9.4
  @author Allan Bowe

**/
%macro mm_tree(
     root=
    ,types=ALL
    ,outds=work.mm_tree
)/*/STORE SOURCE*/;
options noquotelenmax;

%if %mf_isblank(&root) %then %let root=/;

%if %str(&types)=EXPORTABLE %then %do;
  data;run;%local tempds; %let tempds=&syslast;
  %mm_getpublictypes(outds=&tempds)
  proc sql noprint;
  select publictype into: types separated by ' ' from &tempds;
  drop table &tempds;
%end;

* use a temporary fileref to hold the response;
filename response temp;
/* get list of libraries */
proc metadata in=
 '<GetMetadataObjects><Reposid>$METAREPOSITORY</Reposid>
   <Type>Tree</Type><Objects/><NS>SAS</NS>
   <Flags>384</Flags>
   <XMLSelect search="*[@TreeType=&apos;BIP Folder&apos;]"/>
   <Options/></GetMetadataObjects>'
  out=response;
run;
/*
data _null_;
  infile response;
  input;
  put _infile_;
  run;
*/

/* create an XML map to read the response */
filename sxlemap temp;
data _null_;
  file sxlemap;
  put '<SXLEMAP version="1.2" name="SASObjects"><TABLE name="SASObjects">';
  put "<TABLE-PATH syntax='XPath'>/GetMetadataObjects/Objects/Tree</TABLE-PATH>";
  put '<COLUMN name="pathuri">';
  put "<PATH syntax='XPath'>/GetMetadataObjects/Objects/Tree/@Id</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>64</LENGTH>";
  put '</COLUMN><COLUMN name="name">';
  put "<PATH syntax='XPath'>/GetMetadataObjects/Objects/Tree/@Name</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>256</LENGTH>";
  put '</COLUMN></TABLE></SXLEMAP>';
run;
libname _XML_ xml xmlfileref=response xmlmap=sxlemap;

data &outds;
  length metauri pathuri $64 name $256 path $1024
    publictype MetadataUpdated MetadataCreated $32;
  set _XML_.SASObjects;
  keep metauri name publictype MetadataUpdated MetadataCreated path;
  length parenturi pname $128 ;
  call missing(parenturi,pname);
  path=cats('/',name);
  /* get parents */
  tmpuri=pathuri;
  do while (metadata_getnasn(tmpuri,"ParentTree",1,parenturi)>0);
    rc=metadata_getattr(parenturi,"Name",pname);
    path=cats('/',pname,path);
    tmpuri=parenturi;
  end;
  
  if path=:"&root";

  %if "&types"="ALL" or ("&types" ne "ALL" and "&types" ne "Folder") %then %do;
    n=1;
    do while (metadata_getnasn(pathuri,"Members",n,metauri)>0);
      n+1;
      call missing(name,publictype,MetadataUpdated,MetadataCreated);
      rc=metadata_getattr(metauri,"Name", name);
      rc=metadata_getattr(metauri,"MetadataUpdated", MetadataUpdated);
      rc=metadata_getattr(metauri,"MetadataCreated", MetadataCreated);
      rc=metadata_getattr(metauri,"PublicType", PublicType);
    %if "&types" ne "ALL" %then %do;
      if publictype in (%mf_getquotedstr(&types)) then output;
    %end;
    %else output; ;
    end;
  %end;

  rc=metadata_resolve(pathuri,pname,tmpuri);
  metauri=cats('OMSOBJ:',pname,'\',pathuri);
  rc=metadata_getattr(metauri,"Name", name);
  rc=metadata_getattr(pathuri,"MetadataUpdated", MetadataUpdated);
  rc=metadata_getattr(pathuri,"MetadataCreated", MetadataCreated);
  rc=metadata_getattr(pathuri,"PublicType", PublicType);
  path=substr(path,1,length(path)-length(name)-1);
  if publictype ne '' then output;
run;

proc sort;
  by path;
run;

/* clear references */
filename sxlemap clear;
filename response clear;
libname _XML_ clear;

%mend;
/**
  @file
  @brief Add or update an extension to an application component
  @details A SAS Application (SoftwareComponent) is a great place to store app
    specific parameters.  There are two main places those params can be stored:
    1) Configuration, and 2) Extensions.  The second location will enable end
    users to modify parameters even if they don't have the Configuration Manager
    plugin in SMC.  This macro can be used after creating an application with
    the mm_createapplication.sas macro.  If a parameter with the same name
    exists, it is updated.  If it does not, it is created.

  Usage:

    %mm_updateappextension(app=/my/metadata/path/myappname
      ,paramname=My Param
      ,paramvalue=My value
      ,paramdesc=some description)


  @param app= the BIP Tree folder path plus Application Name
  @param paramname= Parameter name
  @param paramvalue= Parameter value
  @param paramdesc= Parameter description

  @param frefin= change default inref if it clashes with an existing one
  @param frefout= change default outref if it clashes with an existing one
  @param mDebug= set to 1 to show debug messages in the log

  @version 9.4
  @author Allan Bowe

**/

%macro mm_updateappextension(app=
  ,paramname=
  ,paramvalue=
  ,paramdesc=Created by mm_updateappextension
  ,frefin=inmeta,frefout=outmeta
  , mdebug=0);


/* first, check if app (and param) exists */
%local appuri exturi;
%let appuri=stopifempty;
%let exturi=createifempty;

data _null_;
  format type uri tsuri value $200.;
  call missing (of _all_);
  paramname=symget('paramname');
  path="&app(Application)";
  /* first, find the STP ID */
  if metadata_pathobj("",path,"Application",type,uri)>0 then do;
    /* we have an app in this location! */
    call symputx('appuri',uri,'l');
    cnt=1;
    do while (metadata_getnasn(uri,"Extensions",cnt,tsuri)>0);
      rc=metadata_getattr(tsuri,"Name",value);
      put tsuri= value=;
      if value=paramname then do;
        putlog "&sysmacroname: found existing param - " tsuri;
        rc=metadata_getattr(tsuri,"Id",value);
        call symputx('exturi',value,'l');
        stop;
      end;
      cnt+1;
    end;
  end;
  else put (_all_)(=);
run;

%if &appuri=stopifempty %then %do;
  %put WARNING:  &app.(Application) not found!;
  %return;
%end;

/* escape the description so it can be stored as XML  */
data _null_;
  length outstr $32767;
  outstr=symget('paramdesc');
  outstr=tranwrd(outstr,'&','&amp;');
  outstr=tranwrd(outstr,'<','&lt;');
  outstr=tranwrd(outstr,'>','&gt;');
  outstr=tranwrd(outstr,"'",'&apos;');
  outstr=tranwrd(outstr,'"','&quot;');
  outstr=tranwrd(outstr,'0A'x,'&#10;');
  outstr=tranwrd(outstr,'0D'x,'&#13;');
  outstr=tranwrd(outstr,'$','&#36;');
  call symputx('paramdesc',outstr,'l');
run;

filename &frefin temp;

%if &exturi=createifempty %then %do;
  /* write header XML */
  data _null_;
    file &frefin;
    pname=quote(trim(symget('paramname')));
    pdesc=quote(trim(symget('paramdesc')));
    pvalue=quote(trim(symget('paramvalue')));
    put "<UpdateMetadata><Reposid>$METAREPOSITORY</Reposid><Metadata>"/
        "  <SoftwareComponent id='&appuri' ><Extensions>" /
        '    <Extension Name=' pname ' Desc=' pdesc ' value= ' pvalue ' />' /
        '  </Extensions></SoftwareComponent>'/
        '</Metadata><NS>SAS</NS><Flags>268435456</Flags></UpdateMetadata>';
  run;

%end;
%else %do;
  data _null_;
    file &frefin;
    pdesc=quote(trim(symget('paramdesc')));
    pvalue=quote(trim(symget('paramvalue')));
    put "<UpdateMetadata><Reposid>$METAREPOSITORY</Reposid><Metadata>"/
        "  <Extension id='&exturi' Desc=" pdesc ' value= ' pvalue ' />' /
        '</Metadata><NS>SAS</NS><Flags>268435456</Flags></UpdateMetadata>';
  run;
%end;

filename &frefout temp;

proc metadata in= &frefin out=&frefout verbose;
run;

%if &mdebug=1 %then %do;
  /* write the response to the log for debugging */
  data _null_;
    infile &frefout lrecl=1048576;
    input;
    put _infile_;
  run;
%end;

%mend;/**
  @file
  @brief Update the TextStore in a Document with the same name
  @details Enables arbitrary content to be stored in a document object

  Usage:

    %mm_updatedocument(path=/my/metadata/path
      ,name=docname
      ,text="/file/system/some.txt")


  @param path= the BIP Tree folder path
  @param name=Document Name
  @param text=a source file containing the text to be added

  @param frefin= change default inref if it clashes with an existing one
  @param frefout= change default outref if it clashes with an existing one
  @param mDebug= set to 1 to show debug messages in the log

  @version 9.3
  @author Allan Bowe

**/

%macro mm_updatedocument(path=
  ,name=
  ,text=
  ,frefin=inmeta
  ,frefout=outmeta
  ,mdebug=0
);
/* first, check if STP exists */
%local tsuri;
%let tsuri=stopifempty ;

data _null_;
  format type uri tsuri value $200.;
  call missing (of _all_);
  path="&path/&name(Note)";
  /* first, find the STP ID */
  if metadata_pathobj("",path,"Note",type,uri)>0 then do;
    /* get sourcetext */
    cnt=1;
    do while (metadata_getnasn(uri,"Notes",cnt,tsuri)>0);
      rc=metadata_getattr(tsuri,"Name",value);
      put tsuri= value=;
      if value="&name" then do;
        /* found it! */
        rc=metadata_getattr(tsuri,"Id",value);
        call symputx('tsuri',value,'l');
        stop;
      end;
      cnt+1;
    end;
  end;
  else put (_all_)(=);
run;

%if &tsuri=stopifempty %then %do;
  %put WARNING:  &path/&name.(Document) not found!;
  %return;
%end;

%if %length(&text)<2 %then %do;
  %put WARNING:  No text supplied!!;
  %return;
%end;

filename &frefin temp recfm=n;

/* escape code so it can be stored as XML */
/* input file may be over 32k wide, so deal with one char at a time */
data _null_;
  file &frefin recfm=n;
  infile &text recfm=n;
  input instr $CHAR1. ;
  if _n_=1 then put "<UpdateMetadata><Reposid>$METAREPOSITORY</Reposid>
    <Metadata><TextStore id='&tsuri' StoredText='" @@;
  select (instr);
    when ('&') put '&amp;';
    when ('<') put '&lt;';
    when ('>') put '&gt;';
    when ("'") put '&apos;';
    when ('"') put '&quot;';
    when ('0A'x) put '&#x0a;';
    when ('0D'x) put '&#x0d;';
    when ('$') put '&#36;';
    otherwise put instr $CHAR1.;
  end;
run;

data _null_;
  file &frefin mod;
  put "'></TextStore></Metadata><NS>SAS</NS><Flags>268435456</Flags>
    </UpdateMetadata>";
run;


filename &frefout temp;

proc metadata in= &frefin
  %if &mdebug=1 %then out=&frefout verbose;
;
run;

%if &mdebug=1 %then %do;
  /* write the response to the log for debugging */
  data _null_;
    infile &frefout lrecl=1048576;
    input;
    put _infile_;
  run;
%end;

%mend;/**
  @file mm_updatestpservertype.sas
  @brief Updates a type 2 stored process to run on STP or WKS context
  @details Only works on Type 2 (9.3 compatible) STPs

  Usage:

    %mm_updatestpservertype(target=/some/meta/path/myStoredProcess
      ,type=WKS)

  <h4> Dependencies </h4>

  @param target= full path to the STP being deleted
  @param type= Either WKS or STP depending on whether Workspace or Stored Process
        type required

  @version 9.4
  @author Allan Bowe

**/

%macro mm_updatestpservertype(
  target=
  ,type=
)/*/STORE SOURCE*/;

/**
 * Check STP does exist
 */
%local cmtype;
data _null_;
  length type uri $256;
  rc=metadata_pathobj("","&target",'StoredProcess',type,uri);
  call symputx('cmtype',type,'l');
  call symputx('stpuri',uri,'l');
run;
%if &cmtype ne ClassifierMap %then %do;
  %put WARNING: No Stored Process found at &target;
  %return;
%end;

%local newtype;
%if &type=WKS %then %let newtype=Wks;
%else %let newtype=Sps;

%local result;
%let result=NOT FOUND;
data _null_;
  length uri name value $256;
  n=1;
  do while(metadata_getnasn("&stpuri","Notes",n,uri)>0);
    n+1;
    rc=metadata_getattr(uri,"Name",name);
    if name='Stored Process' then do;
      rc = METADATA_SETATTR(uri,'StoredText','<?xml version="1.0" encoding="UTF-8"?>'
        !!'<StoredProcess><ServerContext LogicalServerType="'!!"&newtype"
        !!'" OtherAllowed="false"/><ResultCapabilities Package="false" '
        !!' Streaming="true"/><OutputParameters/></StoredProcess>');
      if rc=0 then call symputx('result','SUCCESS');
      stop;
    end;
  end;
run;
%if &result=SUCCESS %then %put NOTE: SUCCESS: STP &target changed to &type type;
%else %put %str(ERR)OR: Issue with &sysmacroname;

%mend;
/**
  @file
  @brief Update the source code of a type 2 STP
  @details Uploads the contents of a text file or fileref to an existing type 2
    STP.  A type 2 STP has its source code saved in metadata.

  Usage:

    %mm_updatestpsourcecode(stp=/my/metadata/path/mystpname
      ,stpcode="/file/system/source.sas")


  @param stp= the BIP Tree folder path plus Stored Process Name
  @param stpcode= the source file (or fileref) containing the SAS code to load
    into the stp.  For multiple files, they should simply be concatenated first.
  @param minify= set to YES in order to strip comments, blank lines, and CRLFs.

  @param frefin= change default inref if it clashes with an existing one
  @param frefout= change default outref if it clashes with an existing one
  @param mDebug= set to 1 to show debug messages in the log

  @version 9.3
  @author Allan Bowe

**/

%macro mm_updatestpsourcecode(stp=
  ,stpcode=
  ,minify=NO
  ,frefin=inmeta
  ,frefout=outmeta
  ,mdebug=0
);
/* first, check if STP exists */
%local tsuri;
%let tsuri=stopifempty ;

data _null_;
  format type uri tsuri value $200.;
  call missing (of _all_);
  path="&stp.(StoredProcess)";
  /* first, find the STP ID */
  if metadata_pathobj("",path,"StoredProcess",type,uri)>0 then do;
    /* get sourcecode */
    cnt=1;
    do while (metadata_getnasn(uri,"Notes",cnt,tsuri)>0);
      rc=metadata_getattr(tsuri,"Name",value);
      put tsuri= value=;
      if value="SourceCode" then do;
        /* found it! */
        rc=metadata_getattr(tsuri,"Id",value);
        call symputx('tsuri',value,'l');
        stop;
      end;
      cnt+1;
    end;
  end;
  else put (_all_)(=);
run;

%if &tsuri=stopifempty %then %do;
  %put WARNING:  &stp.(StoredProcess) not found!;
  %return;
%end;

%if %length(&stpcode)<2 %then %do;
  %put WARNING:  No SAS code supplied!!;
  %return;
%end;

filename &frefin temp lrecl=32767;

/* write header XML */
data _null_;
  file &frefin;
  put "<UpdateMetadata><Reposid>$METAREPOSITORY</Reposid>
    <Metadata><TextStore id='&tsuri' StoredText='";
run;

/* escape code so it can be stored as XML */
/* write contents */
%if %length(&stpcode)>2 %then %do;
  data _null_;
    file &frefin mod;
    infile &stpcode lrecl=32767;
    length outstr $32767;
    input outstr ;
    /* escape code so it can be stored as XML */
    outstr=tranwrd(_infile_,'&','&amp;');
    outstr=tranwrd(outstr,'<','&lt;');
    outstr=tranwrd(outstr,'>','&gt;');
    outstr=tranwrd(outstr,"'",'&apos;');
    outstr=tranwrd(outstr,'"','&quot;');
    outstr=tranwrd(outstr,'0A'x,'&#x0a;');
    outstr=tranwrd(outstr,'0D'x,'&#x0d;');
    outstr=tranwrd(outstr,'$','&#36;');
    %if &minify=YES %then %do;
      outstr=cats(outstr);
      if outstr ne '';
      if not (outstr=:'/*' and subpad(left(reverse(outstr)),1,2)='/*');
    %end;
    outstr=trim(outstr);
    put outstr '&#10;';
  run;
%end;

data _null_;
  file &frefin mod;
  put "'></TextStore></Metadata><NS>SAS</NS><Flags>268435456</Flags>
    </UpdateMetadata>";
run;


filename &frefout temp;

proc metadata in= &frefin out=&frefout;
run;

%if &mdebug=1 %then %do;
  /* write the response to the log for debugging */
  data _null_;
    infile &frefout lrecl=32767;
    input;
    put _infile_;
  run;
%end;

%mend;/**
  @file mm_webout.sas
  @brief Send data to/from SAS Stored Processes
  @details This macro should be added to the start of each Stored Process,
  **immediately** followed by a call to:

        %mm_webout(FETCH)

    This will read all the input data and create same-named SAS datasets in the
    WORK library.  You can then insert your code, and send data back using the
    following syntax:

        data some datasets; * make some data ;
        retain some columns;
        run;

        %mm_webout(OPEN)
        %mm_webout(ARR,some)  * Array format, fast, suitable for large tables ;
        %mm_webout(OBJ,datasets) * Object format, easier to work with ;

    Finally, wrap everything up send some helpful system variables too

        %mm_webout(CLOSE)


  @param action Either FETCH, OPEN, ARR, OBJ or CLOSE
  @param ds The dataset to send back to the frontend
  @param dslabel= value to use instead of the real name for sending to JSON
  @param fmt= set to N to send back unformatted values

  @version 9.3
  @author Allan Bowe

**/
%macro mm_webout(action,ds,dslabel=,fref=_webout,fmt=Y);
%global _webin_file_count _webin_fileref1 _webin_name1 _program _debug 
  sasjs_tables;
%local i tempds;

%if &action=FETCH %then %do;
  %if %str(&_debug) ge 131 %then %do;
    options mprint notes mprintnest;
  %end;
  %let _webin_file_count=%eval(&_webin_file_count+0);
  /* now read in the data */
  %do i=1 %to &_webin_file_count;
    %if &_webin_file_count=1 %then %do;
      %let _webin_fileref1=&_webin_fileref;
      %let _webin_name1=&_webin_name;
    %end;
    data _null_;
      infile &&_webin_fileref&i termstr=crlf;
      input;
      call symputx('input_statement',_infile_);
      putlog "&&_webin_name&i input statement: "  _infile_;
      stop;
    data &&_webin_name&i;
      infile &&_webin_fileref&i firstobs=2 dsd termstr=crlf encoding='utf-8';
      input &input_statement;
      %if %str(&_debug) ge 131 %then %do;
        if _n_<20 then putlog _infile_;
      %end;
    run;
    %let sasjs_tables=&sasjs_tables &&_webin_name&i;
  %end;
%end;

%else %if &action=OPEN %then %do;
  /* fix encoding */
  OPTIONS NOBOMFILE;
  data _null_;
    rc = stpsrv_header('Content-type',"text/html; encoding=utf-8");
  run;

  /* setup json */
  data _null_;file &fref encoding='utf-8';
  %if %str(&_debug) ge 131 %then %do;
    put '>>weboutBEGIN<<';
  %end;
    put '{"START_DTTM" : "' "%sysfunc(datetime(),datetime20.3)" '"';
  run;

%end;

%else %if &action=ARR or &action=OBJ %then %do;
  %if &sysver=9.4 %then %do;
    %mp_jsonout(&action,&ds,dslabel=&dslabel,fmt=&fmt
      ,engine=PROCJSON,dbg=%str(&_debug)
    )
  %end;
  %else %do;
    %mp_jsonout(&action,&ds,dslabel=&dslabel,fmt=&fmt
      ,engine=DATASTEP,dbg=%str(&_debug)
    )
  %end;
%end;
%else %if &action=CLOSE %then %do;
  %if %str(&_debug) ge 131 %then %do;
    /* if debug mode, send back first 10 records of each work table also */
    options obs=10;
    data;run;%let tempds=%scan(&syslast,2,.);
    ods output Members=&tempds;
    proc datasets library=WORK memtype=data;
    %local wtcnt;%let wtcnt=0;
    data _null_;
      set &tempds;
      if not (name =:"DATA");
      i+1;
      call symputx('wt'!!left(i),name,'l');
      call symputx('wtcnt',i,'l');
    data _null_; file &fref encoding='utf-8'; 
      put ",""WORK"":{";
    %do i=1 %to &wtcnt;
      %let wt=&&wt&i;
      proc contents noprint data=&wt
        out=_data_ (keep=name type length format:);
      run;%let tempds=%scan(&syslast,2,.);
      data _null_; file &fref encoding='utf-8';
        dsid=open("WORK.&wt",'is');
        nlobs=attrn(dsid,'NLOBS');
        nvars=attrn(dsid,'NVARS');
        rc=close(dsid);
        if &i>1 then put ','@;
        put " ""&wt"" : {";
        put '"nlobs":' nlobs;
        put ',"nvars":' nvars;
      %mp_jsonout(OBJ,&tempds,jref=&fref,dslabel=colattrs,engine=DATASTEP)
      %mp_jsonout(OBJ,&wt,jref=&fref,dslabel=first10rows,engine=DATASTEP)
      data _null_; file &fref encoding='utf-8';
        put "}";
    %end;
    data _null_; file &fref encoding='utf-8';
      put "}";
    run;
  %end;
  /* close off json */
  data _null_;file &fref mod encoding='utf-8';
    _PROGRAM=quote(trim(resolve(symget('_PROGRAM'))));
    put ",""SYSUSERID"" : ""&sysuserid"" ";
    put ",""MF_GETUSER"" : ""%mf_getuser()"" ";
    put ",""_DEBUG"" : ""&_debug"" ";
    _METAUSER=quote(trim(symget('_METAUSER')));
    put ",""_METAUSER"": " _METAUSER;
    _METAPERSON=quote(trim(symget('_METAPERSON')));
    put ',"_METAPERSON": ' _METAPERSON;
    put ',"_PROGRAM" : ' _PROGRAM ;
    put ",""SYSCC"" : ""&syscc"" ";
    put ",""SYSERRORTEXT"" : ""&syserrortext"" ";
    put ",""SYSHOSTNAME"" : ""&syshostname"" ";
    put ",""SYSJOBID"" : ""&sysjobid"" ";
    put ",""SYSSITE"" : ""&syssite"" ";
    put ",""SYSWARNINGTEXT"" : ""&syswarningtext"" ";
    put ',"END_DTTM" : "' "%sysfunc(datetime(),datetime20.3)" '" ';
    put "}" @;
  %if %str(&_debug) ge 131 %then %do;
    put '>>weboutEND<<';
  %end;
  run;
%end;

%mend;
/**
  @file
  @brief Deletes a metadata folder
  @details Deletes a metadata folder (and contents) using the batch tools, as
    documented here:
    https://documentation.sas.com/?docsetId=bisag&docsetTarget=p0zqp8fmgs4o0kn1tt7j8ho829fv.htm&docsetVersion=9.4&locale=en

  Usage:

    %mmx_deletemetafolder(loc=/some/meta/folder,user=sasdemo,pass=mars345)

  <h4> Dependencies </h4>
  @li mf_loc.sas

  @param loc= the metadata folder to delete
  @param user= username
  @param pass= password

  @version 9.4
  @author Allan Bowe

**/

%macro mmx_deletemetafolder(loc=,user=,pass=);

%local host port path connx_string;
%let host=%sysfunc(getoption(metaserver));
%let port=%sysfunc(getoption(metaport));
%let path=%mf_loc(POF)/tools;

%let connx_string= -host &host -port &port -user '&user' -password '&pass';
/* remove directory */
data _null_;
  infile " &path/sas-delete-objects &connx_string ""&loc"" -deleteContents 2>&1"
    pipe lrecl=10000;
  input;
  putlog _infile_;
run;

%mend;/**
  @file mmx_spkexport.sas
  @brief Exports everything in a particular metadata folder
  @details Will export everything in a metadata folder to a specified location.
    Note - the batch tools require a username and password.  For security,
    these are expected to have been provided in a protected directory.

Usage:

    %* import the macros (or make them available some other way);
    filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
    %inc mc;

    %* create sample text file as input to the macro;
    filename tmp temp;
    data _null_;
      file tmp;
      put '%let mmxuser=sasdemo;';
      put '%let mmxpass=Mars321';
    run;

    filename outref "%sysfunc(pathname(work))";
    %mmx_spkexport(metaloc=%str(/30.Projects/3001.Internal/300115.DataController/dc1)
        ,secureref=tmp
        ,outspkpath=%str(/tmp)
    )

  <h4> Dependencies </h4>
  @li mf_loc.sas
  @li mm_tree.sas
  @li mf_getuniquefileref.sas
  @li mp_abort.sas

  @param metaloc= the metadata folder to export
  @param secureref= fileref containing the username / password (should point to
    a file in a secure location)
  @param outspkname= name of the spk to be created (default is mmxport). 
  @param outspkpath= directory in which to create the SPK.  Default is WORK.

  @version 9.4
  @author Allan Bowe

**/

%macro mmx_spkexport(metaloc=
  ,secureref=
  ,outspkname=mmxport
  ,outspkpath=%sysfunc(pathname(work))
);

%local host port platform_object_path connx_string;
%let host=%sysfunc(getoption(metaserver));
%let port=%sysfunc(getoption(metaport));
%let platform_object_path=%mf_loc(POF);

/* get creds */
%inc &secureref/nosource;

%let connx_string=%str(-host &host -port &port -user '&mmxuser' -password '&mmxpass');

%mm_tree(root=%str(&metaloc) ,types=EXPORTABLE ,outds=exportable)

%local fref1;
%let fref1=%mf_getuniquefileref();
data ;
  set exportable end=last;
  file &fref1 lrecl=32767;
  length str $32767;
  if _n_=1 then do;
    put 'data _null_;';
    put 'infile "cd ""&platform_object_path"" %trim(';
    put ') cd ""&platform_object_path"" %trim(';
    put '); ./ExportPackage &connx_string -disableX11 %trim(';
    put ') -package ""&outspkpath/&outspkname..spk"" %trim(';
  end;
  str=') -objects '!!cats('""',path,'/',name,"(",publictype,')"" %trim(');
  put str;
  if last then do;
    put ') -log ""&outspkpath/&outspkname..log"" 2>&1" pipe lrecl=10000;';
    put 'input;putlog _infile_;run;';
  end;
run;

%mp_abort(iftrue= (&syscc ne 0)
  ,mac=&sysmacroname
  ,msg=%str(syscc=&syscc)
)

%inc &fref1;

%mend;/**
  @file mv_createfolder.sas
  @brief Creates a viya folder if that folder does not already exist
  @details Expects oauth token in a global macro variable (default
  ACCESS_TOKEN).

      options mprint;
      %mv_createfolder(path=/Public)


  @param path= The full path of the folder to be created
  @param access_token_var= The global macro variable to contain the access token
  @param grant_type= valid values are "password" or "authorization_code" (unquoted).
    The default is authorization_code.


  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mf_isblank.sas
  @li mf_getplatform.sas

**/

%macro mv_createfolder(path=
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
  );
%local oauth_bearer;
%if &grant_type=detect %then %do;
  %if %symexist(&access_token_var) %then %let grant_type=authorization_code;
  %else %let grant_type=sas_services;
%end;
%if &grant_type=sas_services %then %do;
    %let oauth_bearer=oauth_bearer=sas_services;
    %let &access_token_var=;
%end;

%put &sysmacroname: grant_type=&grant_type;
%mp_abort(iftrue=(&grant_type ne authorization_code and &grant_type ne password
    and &grant_type ne sas_services
  )
  ,mac=&sysmacroname
  ,msg=%str(Invalid value for grant_type: &grant_type)
)

%mp_abort(iftrue=(%mf_isblank(&path)=1)
  ,mac=&sysmacroname
  ,msg=%str(path value must be provided)
)
%mp_abort(iftrue=(%length(&path)=1)
  ,mac=&sysmacroname
  ,msg=%str(path value must be provided)
)

options noquotelenmax;

%local subfolder_cnt; /* determine the number of subfolders */
%let subfolder_cnt=%sysfunc(countw(&path,/));

%local href; /* resource address (none for root) */
%let href="/folders/folders?parentFolderUri=/folders/folders/none";

%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

%local x newpath subfolder;
%do x=1 %to &subfolder_cnt;
  %let subfolder=%scan(&path,&x,%str(/));
  %let newpath=&newpath/&subfolder;

  %local fname1;
  %let fname1=%mf_getuniquefileref();

  %put &sysmacroname checking to see if &newpath exists;
  proc http method='GET' out=&fname1 &oauth_bearer
      url="&base_uri/folders/folders/@item?path=&newpath";
  %if &grant_type=authorization_code %then %do;
      headers "Authorization"="Bearer &&&access_token_var";
  %end;
  run;
  %local libref1;
  %let libref1=%mf_getuniquelibref();
  libname &libref1 JSON fileref=&fname1;
  %mp_abort(iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 200 and &SYS_PROCHTTP_STATUS_CODE ne 404)
    ,mac=&sysmacroname
    ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
  )
  %if &SYS_PROCHTTP_STATUS_CODE=200 %then %do;
    %put &sysmacroname &newpath exists so grab the follow on link ;
    data _null_;
      set &libref1..links;
      if rel='createChild' then
        call symputx('href',quote("&base_uri"!!trim(href)),'l');
    run;
  %end;
  %else %if &SYS_PROCHTTP_STATUS_CODE=404 %then %do;
    %put &sysmacroname &newpath not found - creating it now;
    %local fname2;
    %let fname2=%mf_getuniquefileref();
    data _null_;
      length json $1000;
      json=cats("'"
        ,'{"name":'
        ,quote(trim(symget('subfolder')))
        ,',"description":'
        ,quote("&subfolder, created by &sysmacroname")
        ,',"type":"folder"}'
        ,"'"
      );
      call symputx('json',json,'l');
    run;

    proc http method='POST'
        in=&json
        out=&fname2
        &oauth_bearer
        url=%unquote(%superq(href));
        headers
      %if &grant_type=authorization_code %then %do;
                "Authorization"="Bearer &&&access_token_var"
      %end;
                'Content-Type'='application/vnd.sas.content.folder+json'
                'Accept'='application/vnd.sas.content.folder+json';
    run;
    %put &=SYS_PROCHTTP_STATUS_CODE;
    %put &=SYS_PROCHTTP_STATUS_PHRASE;
    %mp_abort(iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 201)
      ,mac=&sysmacroname
      ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
    )
    %local libref2;
    %let libref2=%mf_getuniquelibref();
    libname &libref2 JSON fileref=&fname2;
    %put &sysmacroname &newpath now created. Grabbing the follow on link ;
    data _null_;
      set &libref2..links;
      if rel='createChild' then
        call symputx('href',quote(trim(href)),'l');
    run;

    libname &libref2 clear;
    filename &fname2 clear;
  %end;
  filename &fname1 clear;
  libname &libref1 clear;
%end;
%mend;/**
  @file mv_createwebservice.sas
  @brief Creates a JobExecution web service if it doesn't already exist
  @details
  Code is passed in as one or more filerefs.

      %* Step 1 - compile macros ;
      filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

      %* Step 2 - Create some code and add it to a web service;
      filename ft15f001 temp;
      parmcards4;
          %webout(FETCH) %* fetch any tables sent from frontend;
          %* do some sas, any inputs are now already WORK tables;
          data example1 example2;
            set sashelp.class;
          run;
          %* send data back;
          %webout(OPEN)
          %webout(ARR,example1) * Array format, fast, suitable for large tables ;
          %webout(OBJ,example2) * Object format, easier to work with ;
          %webout(CLOSE)
      ;;;;
      %mv_createwebservice(path=/Public/app/common,name=appinit)


  Notes:
    To minimise postgres requests, output json is stored in a temporary file
    and then sent to _webout in one go at the end.

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mv_createfolder.sas
  @li mf_getuniquelibref.sas
  @li mf_getuniquefileref.sas
  @li mf_getplatform.sas
  @li mf_isblank.sas
  @li mv_deletejes.sas

  @param path= The full path (on SAS Drive) where the service will be created
  @param name= The name of the service
  @param desc= The description of the service
  @param precode= Space separated list of filerefs, pointing to the code that
    needs to be attached to the beginning of the service
  @param code= Fileref(s) of the actual code to be added
  @param access_token_var= The global macro variable to contain the access token
  @param grant_type= valid values are "password" or "authorization_code" (unquoted).
    The default is authorization_code.
  @param replace= select NO to avoid replacing any existing service in that location
  @param adapter= the macro uses the sasjs adapter by default.  To use another
    adapter, add a (different) fileref here.
  @param contextname= Choose a specific context on which to run the Job.  Leave
    blank to use the default context.  From Viya 3.5 it is possible to configure
    a shared context - see https://go.documentation.sas.com/?docsetId=calcontexts&docsetTarget=n1hjn8eobk5pyhn1wg3ja0drdl6h.htm&docsetVersion=3.5&locale=en

  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

**/

%macro mv_createwebservice(path=
    ,name=
    ,desc=Created by the mv_createwebservice.sas macro
    ,precode=
    ,code=ft15f001
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
    ,replace=YES
    ,adapter=sasjs
    ,debug=0
    ,contextname=
  );
%local oauth_bearer;
%if &grant_type=detect %then %do;
  %if %symexist(&access_token_var) %then %let grant_type=authorization_code;
  %else %let grant_type=sas_services;
%end;
%if &grant_type=sas_services %then %do;
    %let oauth_bearer=oauth_bearer=sas_services;
    %let &access_token_var=;
%end;
%put &sysmacroname: grant_type=&grant_type;

/* initial validation checking */
%mp_abort(iftrue=(&grant_type ne authorization_code and &grant_type ne password
    and &grant_type ne sas_services
  )
  ,mac=&sysmacroname
  ,msg=%str(Invalid value for grant_type: &grant_type)
)
%mp_abort(iftrue=(%mf_isblank(&path)=1)
  ,mac=&sysmacroname
  ,msg=%str(path value must be provided)
)
%mp_abort(iftrue=(%length(&path)=1)
  ,mac=&sysmacroname
  ,msg=%str(path value must be provided)
)
%mp_abort(iftrue=(%mf_isblank(&name)=1)
  ,mac=&sysmacroname
  ,msg=%str(name value must be provided)
)

options noquotelenmax;

* remove any trailing slash ;
%if "%substr(&path,%length(&path),1)" = "/" %then
  %let path=%substr(&path,1,%length(&path)-1);

/* ensure folder exists */
%put &sysmacroname: Path &path being checked / created;
%mv_createfolder(path=&path)

%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

/* fetching folder details for provided path */
%local fname1;
%let fname1=%mf_getuniquefileref();
proc http method='GET' out=&fname1 &oauth_bearer
  url="&base_uri/folders/folders/@item?path=&path";
%if &grant_type=authorization_code %then %do;
  headers "Authorization"="Bearer &&&access_token_var";
%end;
run;
%if &debug %then %do;
  data _null_;
    infile &fname1;
    input;
    putlog _infile_;
  run;
%end;
%mp_abort(iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 200)
  ,mac=&sysmacroname
  ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
)

/* path exists. Grab follow on link to check members */
%local libref1;
%let libref1=%mf_getuniquelibref();
libname &libref1 JSON fileref=&fname1;

data _null_;
  set &libref1..links;
  if rel='members' then call symputx('membercheck',quote("&base_uri"!!trim(href)),'l');
  else if rel='self' then call symputx('parentFolderUri',href,'l');
run;
data _null_;
  set &libref1..root;
  call symputx('folderid',id,'l');
run;
%local fname2;
%let fname2=%mf_getuniquefileref();
proc http method='GET'
    out=&fname2
    &oauth_bearer
    url=%unquote(%superq(membercheck));
    headers
  %if &grant_type=authorization_code %then %do;
            "Authorization"="Bearer &&&access_token_var"
  %end;
            'Accept'='application/vnd.sas.collection+json'
            'Accept-Language'='string';
%if &debug=1 %then %do;
   debug level = 3;
%end;
run;
/*data _null_;infile &fname2;input;putlog _infile_;run;*/
%mp_abort(iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 200)
  ,mac=&sysmacroname
  ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
)

%if %upcase(&replace)=YES %then %do;
  %mv_deletejes(path=&path, name=&name)
%end;
%else %do;
  /* check that job does not already exist in that folder */
  %local libref2;
  %let libref2=%mf_getuniquelibref();
  libname &libref2 JSON fileref=&fname2;
  %local exists; %let exists=0;
  data _null_;
    set &libref2..items;
    if contenttype='jobDefinition' and upcase(name)="%upcase(&name)" then
      call symputx('exists',1,'l');
  run;
  %mp_abort(iftrue=(&exists=1)
    ,mac=&sysmacroname
    ,msg=%str(Job &name already exists in &path)
  )
  libname &libref2 clear;
%end;

/* set up the body of the request to create the service */
%local fname3;
%let fname3=%mf_getuniquefileref();
data _null_;
  file &fname3 TERMSTR=' ';
  length string $32767;
  string=cats('{"version": 0,"name":"'
  	,"&name"
  	,'","type":"Compute","parameters":[{"name":"_addjesbeginendmacros"'
    ,',"type":"CHARACTER","defaultValue":"false"}');
  context=quote(cats(symget('contextname')));
  if context ne '""' then do;
    string=cats(string,',{"version": 1,"name": "_contextName","defaultValue":'
     ,context,',"type":"CHARACTER","label":"Context Name","required": false}');
  end;
  string=cats(string,'],"code":"');
  put string;
run;

/**
 * Add webout macro
 * These put statements are auto generated - to change the macro, change the
 * source (mv_webout) and run `build.py`
 */
filename sasjs temp lrecl=3000;
data _null_;
  file sasjs;
  put "/* Created on %sysfunc(datetime(),datetime19.) by &sysuserid */";
/* WEBOUT BEGIN */
  put ' ';
  put '%macro mp_jsonout(action,ds,jref=_webout,dslabel=,fmt=Y,engine=PROCJSON,dbg=0 ';
  put ')/*/STORE SOURCE*/; ';
  put '%put output location=&jref; ';
  put '%if &action=OPEN %then %do; ';
  put '  data _null_;file &jref encoding=''utf-8''; ';
  put '    put ''{"START_DTTM" : "'' "%sysfunc(datetime(),datetime20.3)" ''"''; ';
  put '  run; ';
  put '%end; ';
  put '%else %if (&action=ARR or &action=OBJ) %then %do; ';
  put '  options validvarname=upcase; ';
  put '  data _null_;file &jref mod encoding=''utf-8''; ';
  put '    put ", ""%lowcase(%sysfunc(coalescec(&dslabel,&ds)))"":"; ';
  put ' ';
  put '  %if &engine=PROCJSON %then %do; ';
  put '    data;run;%let tempds=&syslast; ';
  put '    proc sql;drop table &tempds; ';
  put '    data &tempds /view=&tempds;set &ds; ';
  put '    %if &fmt=N %then format _numeric_ best32.;; ';
  put '    proc json out=&jref pretty ';
  put '        %if &action=ARR %then nokeys ; ';
  put '        ;export &tempds / nosastags fmtnumeric; ';
  put '    run; ';
  put '    proc sql;drop view &tempds; ';
  put '  %end; ';
  put '  %else %if &engine=DATASTEP %then %do; ';
  put '    %local cols i tempds; ';
  put '    %let cols=0; ';
  put '    %if %sysfunc(exist(&ds)) ne 1 & %sysfunc(exist(&ds,VIEW)) ne 1 %then %do; ';
  put '      %put &sysmacroname:  &ds NOT FOUND!!!; ';
  put '      %return; ';
  put '    %end; ';
  put '    data _null_;file &jref mod ; ';
  put '      put "["; call symputx(''cols'',0,''l''); ';
  put '    proc sort data=sashelp.vcolumn(where=(libname=''WORK'' & memname="%upcase(&ds)")) ';
  put '      out=_data_; ';
  put '      by varnum; ';
  put ' ';
  put '    data _null_; ';
  put '      set _last_ end=last; ';
  put '      call symputx(cats(''name'',_n_),name,''l''); ';
  put '      call symputx(cats(''type'',_n_),type,''l''); ';
  put '      call symputx(cats(''len'',_n_),length,''l''); ';
  put '      if last then call symputx(''cols'',_n_,''l''); ';
  put '    run; ';
  put ' ';
  put '    proc format; /* credit yabwon for special null removal */ ';
  put '      value bart ._ - .z = null ';
  put '      other = [best.]; ';
  put ' ';
  put '    data;run; %let tempds=&syslast; /* temp table for spesh char management */ ';
  put '    proc sql; drop table &tempds; ';
  put '    data &tempds/view=&tempds; ';
  put '      attrib _all_ label=''''; ';
  put '      %do i=1 %to &cols; ';
  put '        %if &&type&i=char %then %do; ';
  put '          length &&name&i $32767; ';
  put '          format &&name&i $32767.; ';
  put '        %end; ';
  put '      %end; ';
  put '      set &ds; ';
  put '      format _numeric_ bart.; ';
  put '    %do i=1 %to &cols; ';
  put '      %if &&type&i=char %then %do; ';
  put '        &&name&i=''"''!!trim(prxchange(''s/"/\"/'',-1, ';
  put '                    prxchange(''s/''!!''0A''x!!''/\n/'',-1, ';
  put '                    prxchange(''s/''!!''0D''x!!''/\r/'',-1, ';
  put '                    prxchange(''s/''!!''09''x!!''/\t/'',-1, ';
  put '                    prxchange(''s/\\/\\\\/'',-1,&&name&i) ';
  put '        )))))!!''"''; ';
  put '      %end; ';
  put '    %end; ';
  put '    run; ';
  put '    /* write to temp loc to avoid _webout truncation - https://support.sas.com/kb/49/325.html */ ';
  put '    filename _sjs temp lrecl=131068 encoding=''utf-8''; ';
  put '    data _null_; file _sjs lrecl=131068 encoding=''utf-8'' mod; ';
  put '      set &tempds; ';
  put '      if _n_>1 then put "," @; put ';
  put '      %if &action=ARR %then "[" ; %else "{" ; ';
  put '      %do i=1 %to &cols; ';
  put '        %if &i>1 %then  "," ; ';
  put '        %if &action=OBJ %then """&&name&i"":" ; ';
  put '        &&name&i ';
  put '      %end; ';
  put '      %if &action=ARR %then "]" ; %else "}" ; ; ';
  put '    proc sql; ';
  put '    drop view &tempds; ';
  put '    /* now write the long strings to _webout 1 byte at a time */ ';
  put '    data _null_; ';
  put '      length filein 8 fileid 8; ';
  put '      filein = fopen("_sjs",''I'',1,''B''); ';
  put '      fileid = fopen("&jref",''A'',1,''B''); ';
  put '      rec = ''20''x; ';
  put '      do while(fread(filein)=0); ';
  put '        rc = fget(filein,rec,1); ';
  put '        rc = fput(fileid, rec); ';
  put '        rc =fwrite(fileid); ';
  put '      end; ';
  put '      rc = fclose(filein); ';
  put '      rc = fclose(fileid); ';
  put '    run; ';
  put '    filename _sjs clear; ';
  put '    data _null_; file &jref mod encoding=''utf-8''; ';
  put '      put "]"; ';
  put '    run; ';
  put '  %end; ';
  put '%end; ';
  put ' ';
  put '%else %if &action=CLOSE %then %do; ';
  put '  data _null_;file &jref encoding=''utf-8''; ';
  put '    put "}"; ';
  put '  run; ';
  put '%end; ';
  put '%mend; ';
  put '%macro mv_webout(action,ds,fref=_mvwtemp,dslabel=,fmt=Y); ';
  put '%global _webin_file_count _webin_fileuri _debug _omittextlog _webin_name ';
  put '  sasjs_tables SYS_JES_JOB_URI; ';
  put '%if %index("&_debug",log) %then %let _debug=131; ';
  put ' ';
  put '%local i tempds; ';
  put '%let action=%upcase(&action); ';
  put ' ';
  put '%if &action=FETCH %then %do; ';
  put '  %if %upcase(&_omittextlog)=FALSE or %str(&_debug) ge 131 %then %do; ';
  put '    options mprint notes mprintnest; ';
  put '  %end; ';
  put ' ';
  put '  %if not %symexist(_webin_fileuri1) %then %do; ';
  put '    %let _webin_file_count=%eval(&_webin_file_count+0); ';
  put '    %let _webin_fileuri1=&_webin_fileuri; ';
  put '    %let _webin_name1=&_webin_name; ';
  put '  %end; ';
  put ' ';
  put '  /* if the sasjs_tables param is passed, we expect param based upload */ ';
  put '  %if %length(&sasjs_tables.XX)>2 %then %do; ';
  put '    filename _sasjs "%sysfunc(pathname(work))/sasjs.lua"; ';
  put '    data _null_; ';
  put '      file _sasjs; ';
  put '      put ''s=sas.symget("sasjs_tables")''; ';
  put '      put ''if(s:sub(1,7) == "%nrstr(")''; ';
  put '      put ''then''; ';
  put '      put '' tablist=s:sub(8,s:len()-1)''; ';
  put '      put ''else''; ';
  put '      put '' tablist=s''; ';
  put '      put ''end''; ';
  put '      put ''for i = 1,sas.countw(tablist) ''; ';
  put '      put ''do ''; ';
  put '      put ''  tab=sas.scan(tablist,i)''; ';
  put '      put ''  sasdata=""''; ';
  put '      put ''  if (sas.symexist("sasjs"..i.."data0")==0)''; ';
  put '      put ''  then''; ';
  put '      /* TODO - condense this logic */ ';
  put '      put ''    s=sas.symget("sasjs"..i.."data")''; ';
  put '      put ''    if(s:sub(1,7) == "%nrstr(")''; ';
  put '      put ''    then''; ';
  put '      put ''      sasdata=s:sub(8,s:len()-1)''; ';
  put '      put ''    else''; ';
  put '      put ''      sasdata=s''; ';
  put '      put ''    end''; ';
  put '      put ''  else''; ';
  put '      put ''    for d = 1, sas.symget("sasjs"..i.."data0")''; ';
  put '      put ''    do''; ';
  put '      put ''      s=sas.symget("sasjs"..i.."data"..d)''; ';
  put '      put ''      if(s:sub(1,7) == "%nrstr(")''; ';
  put '      put ''      then''; ';
  put '      put ''        sasdata=sasdata..s:sub(8,s:len()-1)''; ';
  put '      put ''      else''; ';
  put '      put ''        sasdata=sasdata..s''; ';
  put '      put ''      end''; ';
  put '      put ''    end''; ';
  put '      put ''  end''; ';
  put '      put ''  file = io.open(sas.pathname("work").."/"..tab..".csv", "a")''; ';
  put '      put ''  io.output(file)''; ';
  put '      put ''  io.write(sasdata)''; ';
  put '      put ''  io.close(file)''; ';
  put '      put ''end''; ';
  put '    run; ';
  put '    %inc _sasjs; ';
  put ' ';
  put '    /* now read in the data */ ';
  put '    %do i=1 %to %sysfunc(countw(&sasjs_tables)); ';
  put '      %local table; %let table=%scan(&sasjs_tables,&i); ';
  put '      data _null_; ';
  put '        infile "%sysfunc(pathname(work))/&table..csv" termstr=crlf ; ';
  put '        input; ';
  put '        if _n_=1 then call symputx(''input_statement'',_infile_); ';
  put '        list; ';
  put '      data &table; ';
  put '        infile "%sysfunc(pathname(work))/&table..csv" firstobs=2 dsd termstr=crlf; ';
  put '        input &input_statement; ';
  put '      run; ';
  put '    %end; ';
  put '  %end; ';
  put '  %else %do i=1 %to &_webin_file_count; ';
  put '    /* read in any files that are sent */ ';
  put '    /* this part needs refactoring for wide files */ ';
  put '    filename indata filesrvc "&&_webin_fileuri&i" lrecl=999999; ';
  put '    data _null_; ';
  put '      infile indata termstr=crlf lrecl=32767; ';
  put '      input; ';
  put '      if _n_=1 then call symputx(''input_statement'',_infile_); ';
  put '      %if %str(&_debug) ge 131 %then %do; ';
  put '        if _n_<20 then putlog _infile_; ';
  put '        else stop; ';
  put '      %end; ';
  put '      %else %do; ';
  put '        stop; ';
  put '      %end; ';
  put '    run; ';
  put '    data &&_webin_name&i; ';
  put '      infile indata firstobs=2 dsd termstr=crlf ; ';
  put '      input &input_statement; ';
  put '    run; ';
  put '    %let sasjs_tables=&sasjs_tables &&_webin_name&i; ';
  put '  %end; ';
  put '%end; ';
  put '%else %if &action=OPEN %then %do; ';
  put '  /* setup webout */ ';
  put '  OPTIONS NOBOMFILE; ';
  put '  %if "X&SYS_JES_JOB_URI.X"="XX" %then %do; ';
  put '     filename _webout temp lrecl=999999 mod; ';
  put '  %end; ';
  put '  %else %do; ';
  put '    filename _webout filesrvc parenturi="&SYS_JES_JOB_URI" ';
  put '      name="_webout.json" lrecl=999999 mod; ';
  put '  %end; ';
  put ' ';
  put '  /* setup temp ref */ ';
  put '  %if %upcase(&fref) ne _WEBOUT %then %do; ';
  put '    filename &fref temp lrecl=999999 permission=''A::u::rwx,A::g::rw-,A::o::---'' mod; ';
  put '  %end; ';
  put ' ';
  put '  /* setup json */ ';
  put '  data _null_;file &fref; ';
  put '    put ''{"START_DTTM" : "'' "%sysfunc(datetime(),datetime20.3)" ''"''; ';
  put '  run; ';
  put '%end; ';
  put '%else %if &action=ARR or &action=OBJ %then %do; ';
  put '    %mp_jsonout(&action,&ds,dslabel=&dslabel,fmt=&fmt ';
  put '      ,jref=&fref,engine=PROCJSON,dbg=%str(&_debug) ';
  put '    ) ';
  put '%end; ';
  put '%else %if &action=CLOSE %then %do; ';
  put '  %if %str(&_debug) ge 131 %then %do; ';
  put '    /* send back first 10 records of each work table for debugging */ ';
  put '    options obs=10; ';
  put '    data;run;%let tempds=%scan(&syslast,2,.); ';
  put '    ods output Members=&tempds; ';
  put '    proc datasets library=WORK memtype=data; ';
  put '    %local wtcnt;%let wtcnt=0; ';
  put '    data _null_; set &tempds; ';
  put '      if not (name =:"DATA"); ';
  put '      i+1; ';
  put '      call symputx(''wt''!!left(i),name); ';
  put '      call symputx(''wtcnt'',i); ';
  put '    data _null_; file &fref mod; put ",""WORK"":{"; ';
  put '    %do i=1 %to &wtcnt; ';
  put '      %let wt=&&wt&i; ';
  put '      proc contents noprint data=&wt ';
  put '        out=_data_ (keep=name type length format:); ';
  put '      run;%let tempds=%scan(&syslast,2,.); ';
  put '      data _null_; file &fref mod; ';
  put '        dsid=open("WORK.&wt",''is''); ';
  put '        nlobs=attrn(dsid,''NLOBS''); ';
  put '        nvars=attrn(dsid,''NVARS''); ';
  put '        rc=close(dsid); ';
  put '        if &i>1 then put '',''@; ';
  put '        put " ""&wt"" : {"; ';
  put '        put ''"nlobs":'' nlobs; ';
  put '        put '',"nvars":'' nvars; ';
  put '      %mp_jsonout(OBJ,&tempds,jref=&fref,dslabel=colattrs,engine=DATASTEP) ';
  put '      %mp_jsonout(OBJ,&wt,jref=&fref,dslabel=first10rows,engine=DATASTEP) ';
  put '      data _null_; file &fref mod;put "}"; ';
  put '    %end; ';
  put '    data _null_; file &fref mod;put "}";run; ';
  put '  %end; ';
  put ' ';
  put '  /* close off json */ ';
  put '  data _null_;file &fref mod; ';
  put '    _PROGRAM=quote(trim(resolve(symget(''_PROGRAM'')))); ';
  put '    put ",""SYSUSERID"" : ""&sysuserid"" "; ';
  put '    put ",""MF_GETUSER"" : ""%mf_getuser()"" "; ';
  put '    SYS_JES_JOB_URI=quote(trim(resolve(symget(''SYS_JES_JOB_URI'')))); ';
  put '    put '',"SYS_JES_JOB_URI" : '' SYS_JES_JOB_URI ; ';
  put '    put ",""SYSJOBID"" : ""&sysjobid"" "; ';
  put '    put ",""_DEBUG"" : ""&_debug"" "; ';
  put '    put '',"_PROGRAM" : '' _PROGRAM ; ';
  put '    put ",""SYSCC"" : ""&syscc"" "; ';
  put '    put ",""SYSERRORTEXT"" : ""&syserrortext"" "; ';
  put '    put ",""SYSHOSTNAME"" : ""&syshostname"" "; ';
  put '    put ",""SYSSITE"" : ""&syssite"" "; ';
  put '    put ",""SYSWARNINGTEXT"" : ""&syswarningtext"" "; ';
  put '    put '',"END_DTTM" : "'' "%sysfunc(datetime(),datetime20.3)" ''" ''; ';
  put '    put "}"; ';
  put ' ';
  put '  %if %upcase(&fref) ne _WEBOUT %then %do; ';
  put '    data _null_; rc=fcopy("&fref","_webout");run; ';
  put '  %end; ';
  put ' ';
  put '%end; ';
  put ' ';
  put '%mend; ';
  put ' ';
  put '%macro mf_getuser(type=META ';
  put ')/*/STORE SOURCE*/; ';
  put '  %local user metavar; ';
  put '  %if &type=OS %then %let metavar=_secureusername; ';
  put '  %else %let metavar=_metaperson; ';
  put ' ';
  put '  %if %symexist(SYS_COMPUTE_SESSION_OWNER) %then %let user=&SYS_COMPUTE_SESSION_OWNER; ';
  put '  %else %if %symexist(&metavar) %then %do; ';
  put '    %if %length(&&&metavar)=0 %then %let user=&sysuserid; ';
  put '    /* sometimes SAS will add @domain extension - remove for consistency */ ';
  put '    %else %let user=%scan(&&&metavar,1,@); ';
  put '  %end; ';
  put '  %else %let user=&sysuserid; ';
  put ' ';
  put '  %quote(&user) ';
  put ' ';
  put '%mend; ';
/* WEBOUT END */
  put '/* if calling viya service with _job param, _program will conflict */';
  put '/* so it is provided by SASjs instead as __program */';
  put '%global __program _program;';
  put '%let _program=%sysfunc(coalescec(&__program,&_program));';
  put ' ';
  put '%macro webout(action,ds,dslabel=,fmt=);';
  put '  %mv_webout(&action,ds=&ds,dslabel=&dslabel,fmt=&fmt)';
  put '%mend;';
run;

/* insert the code, escaping double quotes and carriage returns */
%local x fref freflist;
%let freflist= &adapter &precode &code ;
%do x=1 %to %sysfunc(countw(&freflist));
  %let fref=%scan(&freflist,&x);
  %put &sysmacroname: adding &fref;
  data _null_;
    length filein 8 fileid 8;
    filein = fopen("&fref","I",1,"B");
    fileid = fopen("&fname3","A",1,"B");
    rec = "20"x;
    do while(fread(filein)=0);
      rc = fget(filein,rec,1);
      if rec='"' then do;
        rc =fput(fileid,'\');rc =fwrite(fileid);
        rc =fput(fileid,'"');rc =fwrite(fileid);
      end;
      else if rec='0A'x then do;
        rc =fput(fileid,'\');rc =fwrite(fileid);
        rc =fput(fileid,'r');rc =fwrite(fileid);
      end;
      else if rec='0D'x then do;
        rc =fput(fileid,'\');rc =fwrite(fileid);
        rc =fput(fileid,'n');rc =fwrite(fileid);
      end;
      else if rec='09'x then do;
        rc =fput(fileid,'\');rc =fwrite(fileid);
        rc =fput(fileid,'t');rc =fwrite(fileid);
      end;
      else if rec='5C'x then do;
        rc =fput(fileid,'\');rc =fwrite(fileid);
        rc =fput(fileid,'\');rc =fwrite(fileid);
      end;
      else do;
        rc =fput(fileid,rec);
        rc =fwrite(fileid);
      end;
    end;
    rc=fclose(filein);
    rc=fclose(fileid);
  run;
%end;

/* finish off the body of the code file loaded to JES */
data _null_;
  file &fname3 mod TERMSTR=' ';
  put '"}';
run;

/* now we can create the job!! */
%local fname4;
%let fname4=%mf_getuniquefileref();
proc http method='POST'
    in=&fname3
    out=&fname4
    &oauth_bearer
    url="&base_uri/jobDefinitions/definitions?parentFolderUri=&parentFolderUri";
    headers 'Content-Type'='application/vnd.sas.job.definition+json'
  %if &grant_type=authorization_code %then %do;
            "Authorization"="Bearer &&&access_token_var"
  %end;
            "Accept"="application/vnd.sas.job.definition+json";
%if &debug=1 %then %do;
   debug level = 3;
%end;
run;
/*data _null_;infile &fname4;input;putlog _infile_;run;*/
%mp_abort(iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 201)
  ,mac=&sysmacroname
  ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
)
/* clear refs */
filename &fname1 clear;
filename &fname2 clear;
filename &fname3 clear;
filename &fname4 clear;
filename &adapter clear;
libname &libref1 clear;

/* get the url so we can give a helpful log message */
%local url;
data _null_;
  if symexist('_baseurl') then do;
    url=symget('_baseurl');
    if subpad(url,length(url)-9,9)='SASStudio'
      then url=substr(url,1,length(url)-11);
    else url="&systcpiphostname";
  end;
  else url="&systcpiphostname";
  call symputx('url',url);
run;


%put &sysmacroname: Job &name successfully created in &path;
%put &sysmacroname:;
%put &sysmacroname: Check it out here:;
%put &sysmacroname:;%put;
%put    &url/SASJobExecution?_PROGRAM=&path/&name;%put;
%put &sysmacroname:;
%put &sysmacroname:;

%mend;
/**
  @file mv_deletefoldermember.sas
  @brief Deletes an item in a Viya folder
  @details If not executed in Studio 5+  will expect oauth token in a global
  macro variable (default ACCESS_TOKEN).

      filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

      %mv_createwebservice(path=/Public/test, name=blah)
      %mv_deletejes(path=/Public/test, name=blah)


  @param path= The full path of the folder containing the item to be deleted
  @param name= The name of the item to be deleted
  @param contenttype= The contenttype of the item, eg: file, jobDefinition
  @param access_token_var= The global macro variable to contain the access token
  @param grant_type= valid values are "password" or "authorization_code" (unquoted).
    The default is "detect" (which will run in Studio 5+ without a token).


  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mf_isblank.sas

**/

%macro mv_deletefoldermember(path=
    ,name=
    ,contenttype=
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
  );
%local oauth_bearer;
%if &grant_type=detect %then %do;
  %if %symexist(&access_token_var) %then %let grant_type=authorization_code;
  %else %let grant_type=sas_services;
%end;
%if &grant_type=sas_services %then %do;
    %let oauth_bearer=oauth_bearer=sas_services;
    %let &access_token_var=;
%end;
%put &sysmacroname: grant_type=&grant_type;
%mp_abort(iftrue=(&grant_type ne authorization_code and &grant_type ne password
    and &grant_type ne sas_services
  )
  ,mac=&sysmacroname
  ,msg=%str(Invalid value for grant_type: &grant_type)
)
%mp_abort(iftrue=(%mf_isblank(&path)=1)
  ,mac=&sysmacroname
  ,msg=%str(path value must be provided)
)
%mp_abort(iftrue=(%mf_isblank(&name)=1)
  ,mac=&sysmacroname
  ,msg=%str(name value must be provided)
)
%mp_abort(iftrue=(%length(&path)=1)
  ,mac=&sysmacroname
  ,msg=%str(path value must be provided)
)

options noquotelenmax;

%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

%put &sysmacroname: fetching details for &path ;
%local fname1;
%let fname1=%mf_getuniquefileref();
proc http method='GET' out=&fname1 &oauth_bearer
  url="&base_uri/folders/folders/@item?path=&path";
%if &grant_type=authorization_code %then %do;
  headers "Authorization"="Bearer &&&access_token_var";
%end;
run;
%if &SYS_PROCHTTP_STATUS_CODE=404 %then %do;
  %put &sysmacroname: Folder &path NOT FOUND - nothing to delete!;
  %return;
%end;
%else %if &SYS_PROCHTTP_STATUS_CODE ne 200 %then %do;
  /*data _null_;infile &fname1;input;putlog _infile_;run;*/
  %mp_abort(mac=&sysmacroname
    ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
  )
%end;

%put &sysmacroname: grab the follow on link ;
%local libref1;
%let libref1=%mf_getuniquelibref();
libname &libref1 JSON fileref=&fname1;
data _null_;
  set &libref1..links;
  if rel='members' then call symputx('mref',quote("&base_uri"!!trim(href)),'l');
run;

/* get the children */
%local fname1a;
%let fname1a=%mf_getuniquefileref();
proc http method='GET' out=&fname1a &oauth_bearer
  url=%unquote(%superq(mref));
%if &grant_type=authorization_code %then %do;
  headers "Authorization"="Bearer &&&access_token_var";
%end;
run;
%put &=SYS_PROCHTTP_STATUS_CODE;
%local libref1a;
%let libref1a=%mf_getuniquelibref();
libname &libref1a JSON fileref=&fname1a;
%local uri found;
%let found=0;
%put Getting object uri from &libref1a..items;
data _null_;
  set &libref1a..items;
  if contenttype="&contenttype" and upcase(name)="%upcase(&name)" then do;
    call symputx('uri',uri,'l');
    call symputx('found',1,'l');
  end;
run;
%if &found=0 %then %do;
  %put NOTE:;%put NOTE- &sysmacroname: &path/&name NOT FOUND;%put NOTE- ;
  %return;
%end;
proc http method="DELETE" url="&base_uri&uri" &oauth_bearer;
  headers
%if &grant_type=authorization_code %then %do;
      "Authorization"="Bearer &&&access_token_var"
%end;
      "Accept"="*/*";/**/
run;
%if &SYS_PROCHTTP_STATUS_CODE ne 204 %then %do;
  data _null_; infile &fname2; input; putlog _infile_;run;
  %mp_abort(mac=&sysmacroname
    ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
  )
%end;
%else %put &sysmacroname: &path/&name(&contenttype) successfully deleted;

/* clear refs */
filename &fname1 clear;
libname &libref1 clear;
filename &fname1a clear;
libname &libref1a clear;

%mend;/**
  @file mv_deletejes.sas
  @brief Creates a job execution service if it does not already exist
  @details If not executed in Studio 5+  will expect oauth token in a global
  macro variable (default ACCESS_TOKEN).

      filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

      %mv_createwebservice(path=/Public/test, name=blah)
      %mv_deletejes(path=/Public/test, name=blah)


  @param path= The full path of the folder containing the Job Execution Service
  @param name= The name of the Job Execution Service to be deleted
  @param access_token_var= The global macro variable to contain the access token
  @param grant_type= valid values are "password" or "authorization_code" (unquoted).
    The default is "detect" (which will run in Studio 5+ without a token).


  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mf_isblank.sas

**/

%macro mv_deletejes(path=
    ,name=
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
  );
%local oauth_bearer;
%if &grant_type=detect %then %do;
  %if %symexist(&access_token_var) %then %let grant_type=authorization_code;
  %else %let grant_type=sas_services;
%end;
%if &grant_type=sas_services %then %do;
    %let oauth_bearer=oauth_bearer=sas_services;
    %let &access_token_var=;
%end;
%put &sysmacroname: grant_type=&grant_type;
%mp_abort(iftrue=(&grant_type ne authorization_code and &grant_type ne password
    and &grant_type ne sas_services
  )
  ,mac=&sysmacroname
  ,msg=%str(Invalid value for grant_type: &grant_type)
)
%mp_abort(iftrue=(%mf_isblank(&path)=1)
  ,mac=&sysmacroname
  ,msg=%str(path value must be provided)
)
%mp_abort(iftrue=(%mf_isblank(&name)=1)
  ,mac=&sysmacroname
  ,msg=%str(name value must be provided)
)
%mp_abort(iftrue=(%length(&path)=1)
  ,mac=&sysmacroname
  ,msg=%str(path value must be provided)
)

options noquotelenmax;
%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

%put &sysmacroname: fetching details for &path ;
%local fname1;
%let fname1=%mf_getuniquefileref();
proc http method='GET' out=&fname1 &oauth_bearer
  url="&base_uri/folders/folders/@item?path=&path";
%if &grant_type=authorization_code %then %do;
  headers "Authorization"="Bearer &&&access_token_var";
%end;
run;
%if &SYS_PROCHTTP_STATUS_CODE=404 %then %do;
  %put &sysmacroname: Folder &path NOT FOUND - nothing to delete!;
  %return;
%end;
%else %if &SYS_PROCHTTP_STATUS_CODE ne 200 %then %do;
  /*data _null_;infile &fname1;input;putlog _infile_;run;*/
  %mp_abort(mac=&sysmacroname
    ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
  )
%end;

%put &sysmacroname: grab the follow on link ;
%local libref1;
%let libref1=%mf_getuniquelibref();
libname &libref1 JSON fileref=&fname1;
data _null_;
  set &libref1..links;
  if rel='members' then call symputx('mref',quote("&base_uri"!!trim(href)),'l');
run;

/* get the children */
%local fname1a;
%let fname1a=%mf_getuniquefileref();
proc http method='GET' out=&fname1a &oauth_bearer
  url=%unquote(%superq(mref));
%if &grant_type=authorization_code %then %do;
  headers "Authorization"="Bearer &&&access_token_var";
%end;
run;
%put &=SYS_PROCHTTP_STATUS_CODE;
%local libref1a;
%let libref1a=%mf_getuniquelibref();
libname &libref1a JSON fileref=&fname1a;
%local uri found;
%let found=0;
%put Getting object uri from &libref1a..items;
data _null_;
  set &libref1a..items;
  if contenttype='jobDefinition' and upcase(name)="%upcase(&name)" then do;
    call symputx('uri',cats("&base_uri",uri),'l');
    call symputx('found',1,'l');
  end;
run;
%if &found=0 %then %do;
  %put NOTE:;%put NOTE- &sysmacroname: &path/&name NOT FOUND;%put NOTE- ;
  %return;
%end;
proc http method="DELETE" url="&uri" &oauth_bearer;
  headers
%if &grant_type=authorization_code %then %do;
      "Authorization"="Bearer &&&access_token_var"
%end;
      "Accept"="*/*";/**/
run;
%if &SYS_PROCHTTP_STATUS_CODE ne 204 %then %do;
  data _null_; infile &fname2; input; putlog _infile_;run;
  %mp_abort(mac=&sysmacroname
    ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
  )
%end;
%else %put &sysmacroname: &path/&name successfully deleted;

/* clear refs */
filename &fname1 clear;
libname &libref1 clear;
filename &fname1a clear;
libname &libref1a clear;

%mend;/**
  @file mv_deleteviyafolder.sas
  @brief Creates a viya folder if that folder does not already exist
  @details If not running in Studo 5 +, will expect an oauth token in a global
  macro variable (default ACCESS_TOKEN).

      options mprint;
      %mv_createfolder(path=/Public/test/blah)
      %mv_deleteviyafolder(path=/Public/test)


  @param path= The full path of the folder to be deleted
  @param access_token_var= The global macro variable to contain the access token
  @param grant_type= valid values are "password" or "authorization_code" (unquoted).
    The default is authorization_code.


  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mf_isblank.sas

**/

%macro mv_deleteviyafolder(path=
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
  );
%local oauth_bearer;
%if &grant_type=detect %then %do;
  %if %symexist(&access_token_var) %then %let grant_type=authorization_code;
  %else %let grant_type=sas_services;
%end;
%if &grant_type=sas_services %then %do;
    %let oauth_bearer=oauth_bearer=sas_services;
    %let &access_token_var=;
%end;
%put &sysmacroname: grant_type=&grant_type;
%mp_abort(iftrue=(&grant_type ne authorization_code and &grant_type ne password
    and &grant_type ne sas_services
  )
  ,mac=&sysmacroname
  ,msg=%str(Invalid value for grant_type: &grant_type)
)
%mp_abort(iftrue=(%mf_isblank(&path)=1)
  ,mac=&sysmacroname
  ,msg=%str(path value must be provided)
)
%mp_abort(iftrue=(%length(&path)=1)
  ,mac=&sysmacroname
  ,msg=%str(path value must be provided)
)

options noquotelenmax;
%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

%put &sysmacroname: fetching details for &path ;
%local fname1;
%let fname1=%mf_getuniquefileref();
proc http method='GET' out=&fname1 &oauth_bearer
  url="&base_uri/folders/folders/@item?path=&path";
  %if &grant_type=authorization_code %then %do;
    headers "Authorization"="Bearer &&&access_token_var";
  %end;
run;
%if &SYS_PROCHTTP_STATUS_CODE=404 %then %do;
  %put &sysmacroname: Folder &path NOT FOUND - nothing to delete!;
  %return;
%end;
%else %if &SYS_PROCHTTP_STATUS_CODE ne 200 %then %do;
  /*data _null_;infile &fname1;input;putlog _infile_;run;*/
  %mp_abort(mac=&sysmacroname
    ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
  )
%end;

%put &sysmacroname: grab the follow on link ;
%local libref1;
%let libref1=%mf_getuniquelibref();
libname &libref1 JSON fileref=&fname1;
data _null_;
  set &libref1..links;
  if rel='deleteRecursively' then
    call symputx('href',quote("&base_uri"!!trim(href)),'l');
  else if rel='members' then
    call symputx('mref',quote(cats("&base_uri",href,'?recursive=true')),'l');
run;

/* before we can delete the folder, we need to delete the children */
%local fname1a;
%let fname1a=%mf_getuniquefileref();
proc http method='GET' out=&fname1a &oauth_bearer
  url=%unquote(%superq(mref));
%if &grant_type=authorization_code %then %do;
  headers "Authorization"="Bearer &&&access_token_var";
%end;
run;
%put &=SYS_PROCHTTP_STATUS_CODE;
%local libref1a;
%let libref1a=%mf_getuniquelibref();
libname &libref1a JSON fileref=&fname1a;

data _null_;
  set &libref1a..items_links;
  if href=:'/folders/folders' then return;
  if rel='deleteResource' then
    call execute('proc http method="DELETE" url='!!quote("&base_uri"!!trim(href))
    !!'; headers "Authorization"="Bearer &&&access_token_var" '
    !!' "Accept"="*/*";run; /**/');
run;

%put &sysmacroname: perform the delete operation ;
%local fname2;
%let fname2=%mf_getuniquefileref();
proc http method='DELETE' out=&fname2 &oauth_bearer
    url=%unquote(%superq(href));
    headers
  %if &grant_type=authorization_code %then %do;
            "Authorization"="Bearer &&&access_token_var"
  %end;
            'Accept'='*/*'; /**/
run;
%if &SYS_PROCHTTP_STATUS_CODE ne 204 %then %do;
  data _null_; infile &fname2; input; putlog _infile_;run;
  %mp_abort(mac=&sysmacroname
    ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
  )
%end;
%else %put &sysmacroname: &path successfully deleted;

/* clear refs */
filename &fname1 clear;
filename &fname2 clear;
libname &libref1 clear;

%mend; /**
   @file mv_getaccesstoken.sas
   @brief deprecated - replaced by mv_tokenrefresh.sas

   @version VIYA V.03.04
   @author Allan Bowe, source: https://github.com/sasjs/core

   <h4> Dependencies </h4>
   @li mv_tokenrefresh.sas

 **/

 %macro mv_getaccesstoken(client_id=someclient
     ,client_secret=somesecret
     ,grant_type=authorization_code
     ,code=
     ,user=
     ,pass=
     ,access_token_var=ACCESS_TOKEN
     ,refresh_token_var=REFRESH_TOKEN
   );

%mv_tokenrefresh(client_id=&client_id
  ,client_secret=&client_secret
  ,grant_type=&grant_type
  ,user=&user
  ,pass=&pass
  ,access_token_var=&access_token_var
  ,refresh_token_var=&refresh_token_var
)

%mend; /**
   @file
   @brief deprecated - replaced by mv_registerclient.sas

   @version VIYA V.03.04
   @author Allan Bowe, source: https://github.com/sasjs/core

   <h4> Dependencies </h4>
   @li mv_registerclient.sas

 **/

 %macro mv_getapptoken(client_id=someclient
     ,client_secret=somesecret
     ,grant_type=authorization_code
   );

%mv_registerclient(client_id=&client_id
  ,client_secret=&client_secret
  ,grant_type=&grant_type
)

%mend;/**
  @file mv_getclients.sas
  @brief Get a list of Viya Clients
  @details First, be sure you have an access token (which requires an app token).

  Using the macros here:

      filename mc url
        "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

  An administrator needs to set you up with an access code:

      %mv_registerclient(outds=client)

  Navigate to the url from the log (opting in to the groups) and paste the
  access code below:

      %mv_tokenauth(inds=client,code=wKDZYTEPK6)

  Now we can run the macro!

      %mv_getclients()

  @param access_token_var= The global macro variable to contain the access token
  @param grant_type= valid values are "password" or "authorization_code" (unquoted).
    The default is authorization_code.
  @param outds= The library.dataset to be created that contains the list of groups


  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mf_loc.sas

**/

%macro mv_getclients(outds=work.mv_getclients
)/*/STORE SOURCE*/;

options noquotelenmax;
%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

/* first, get consul token needed to get client id / secret */
data _null_;
  infile "%mf_loc(VIYACONFIG)/etc/SASSecurityCertificateFramework/tokens/consul/default/client.token";
  input token:$64.;
  call symputx('consul_token',token);
run;

/* request the client details */
%local fname1;
%let fname1=%mf_getuniquefileref();
proc http method='POST' out=&fname1
    url="&base_uri/SASLogon/oauth/clients/consul?callback=false%str(&)serviceId=app";
    headers "X-Consul-Token"="&consul_token";
run;

%local libref1;
%let libref1=%mf_getuniquelibref();
libname &libref1 JSON fileref=&fname1;

/* extract the token */
data _null_;
  set &libref1..root;
  call symputx('access_token',access_token,'l');
run;

/* fetching folder details for provided path */
%local fname2;
%let fname2=%mf_getuniquefileref();
%let libref2=%mf_getuniquelibref();

proc http method='GET' out=&fname2 oauth_bearer=sas_services
  url="&base_uri/SASLogon/oauth/clients";
  headers "Accept"="application/json";
run;
/*data _null_;infile &fname1;input;putlog _infile_;run;*/
%mp_abort(iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 200)
  ,mac=&sysmacroname
  ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
)
libname &libref2 JSON fileref=&fname1;

data &outds;
  set &libref2..items;
run;



/* clear refs
filename &fname1 clear;
libname &libref1 clear;
*/
%mend;/**
  @file mv_getfoldermembers.sas
  @brief Gets a list of folders (and ids) for a given root
  @details Works for both root level and below, oauth or password. Default is
    oauth, and the token is expected in a global ACCESS_TOKEN variable.

        %mv_getfoldermembers(root=/Public)


  @param root= The path for which to return the list of folders
  @param outds= The output dataset to create (default is work.mv_getfolders)
  @param access_token_var= The global macro variable to contain the access token
  @param grant_type= valid values are "password" or "authorization_code" (unquoted).
    The default is authorization_code.


  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mf_isblank.sas

**/

%macro mv_getfoldermembers(root=/
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
    ,outds=mv_getfolders
  );
%local oauth_bearer;
%if &grant_type=detect %then %do;
  %if %symexist(&access_token_var) %then %let grant_type=authorization_code;
  %else %let grant_type=sas_services;
%end;
%if &grant_type=sas_services %then %do;
    %let oauth_bearer=oauth_bearer=sas_services;
    %let &access_token_var=;
%end;
%put &sysmacroname: grant_type=&grant_type;
%mp_abort(iftrue=(&grant_type ne authorization_code and &grant_type ne password
    and &grant_type ne sas_services
  )
  ,mac=&sysmacroname
  ,msg=%str(Invalid value for grant_type: &grant_type)
)

%if %mf_isblank(&root)=1 %then %let root=/;

options noquotelenmax;

/* request the client details */
%local fname1 libref1;
%let fname1=%mf_getuniquefileref();
%let libref1=%mf_getuniquelibref();

%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

%if "&root"="/" %then %do;
  /* if root just list root folders */
  proc http method='GET' out=&fname1 &oauth_bearer
      url="&base_uri/folders/rootFolders";
  %if &grant_type=authorization_code %then %do;
      headers "Authorization"="Bearer &&&access_token_var";
  %end;
  run;
  libname &libref1 JSON fileref=&fname1;
  data &outds;
    set &libref1..items;
  run;
%end;
%else %do;
  /* first get parent folder id */
  proc http method='GET' out=&fname1 &oauth_bearer
      url="&base_uri/folders/folders/@item?path=&root";
  %if &grant_type=authorization_code %then %do;
      headers "Authorization"="Bearer &&&access_token_var";
  %end;
  run;
  /*data _null_;infile &fname1;input;putlog _infile_;run;*/
  libname &libref1 JSON fileref=&fname1;
  /* now get the followon link to list members */
  %local href;
  %let href=0;
  data _null_;
    set &libref1..links;
    if rel='members' then call symputx('href',quote("&base_uri"!!trim(href)),'l');
  run;
  %if &href=0 %then %do;
    %put NOTE:;%put NOTE-  No members found in &root!!;%put NOTE-;
    %return;
  %end;
  %local fname2 libref2;
  %let fname2=%mf_getuniquefileref();
  %let libref2=%mf_getuniquelibref();
  proc http method='GET' out=&fname2 &oauth_bearer
      url=%unquote(%superq(href));
  %if &grant_type=authorization_code %then %do;
      headers "Authorization"="Bearer &&&access_token_var";
  %end;
  run;
  libname &libref2 JSON fileref=&fname2;
  data &outds;
    set &libref2..items;
  run;
  filename &fname2 clear;
  libname &libref2 clear;
%end;


/* clear refs */
filename &fname1 clear;
libname &libref1 clear;

%mend;/**
  @file mv_getgroupmembers.sas
  @brief Creates a dataset with a list of group members
  @details First, be sure you have an access token (which requires an app token).

  Using the macros here:

      filename mc url
        "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

  Now we can run the macro!

      %mv_getgroupmembers(All Users)

  outputs:

      ordinal_root num,
      ordinal_items num,
      version num,
      id char(43),
      name char(43),
      providerId char(5),
      implicit num

  @param access_token_var= The global macro variable to contain the access token
  @param grant_type= valid values are "password" or "authorization_code" (unquoted).
    The default is authorization_code.
  @param outds= The library.dataset to be created that contains the list of groups


  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas

**/

%macro mv_getgroupmembers(group
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
    ,outds=work.viyagroupmembers
  );
%local oauth_bearer;
%if &grant_type=detect %then %do;
  %if %symexist(&access_token_var) %then %let grant_type=authorization_code;
  %else %let grant_type=sas_services;
%end;
%if &grant_type=sas_services %then %do;
    %let oauth_bearer=oauth_bearer=sas_services;
    %let &access_token_var=;
%end;
%put &sysmacroname: grant_type=&grant_type;
%mp_abort(iftrue=(&grant_type ne authorization_code and &grant_type ne password
    and &grant_type ne sas_services
  )
  ,mac=&sysmacroname
  ,msg=%str(Invalid value for grant_type: &grant_type)
)

options noquotelenmax;

%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

/* fetching folder details for provided path */
%local fname1;
%let fname1=%mf_getuniquefileref();
proc http method='GET' out=&fname1 &oauth_bearer
  url="&base_uri/identities/groups/&group/members?limit=10000";
  headers
  %if &grant_type=authorization_code %then %do;
          "Authorization"="Bearer &&&access_token_var"
  %end;
          "Accept"="application/json";
run;
/*data _null_;infile &fname1;input;putlog _infile_;run;*/
%if &SYS_PROCHTTP_STATUS_CODE=404 %then %do;
  %put NOTE:  Group &group not found!!;
  data &outds;
    length id name $43;
    call missing(of _all_);
  run;
%end;
%else %do;
  %mp_abort(iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 200)
    ,mac=&sysmacroname
    ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
  )
  %let libref1=%mf_getuniquelibref();
  libname &libref1 JSON fileref=&fname1;
  data &outds;
    length id name $43;
    set &libref1..items;
  run;
  libname &libref1 clear;
%end;

/* clear refs */
filename &fname1 clear;

%mend;/**
  @file mv_getgroups.sas
  @brief Creates a dataset with a list of viya groups
  @details First, be sure you have an access token (which requires an app token).

  Using the macros here:

      filename mc url
        "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

  An administrator needs to set you up with an access code:

      %mv_registerclient(outds=client)

  Navigate to the url from the log (opting in to the groups) and paste the
  access code below:

      %mv_tokenauth(inds=client,code=wKDZYTEPK6)

  Now we can run the macro!

      %mv_getgroups()

  @param access_token_var= The global macro variable to contain the access token
  @param grant_type= valid values are "password" or "authorization_code" (unquoted).
    The default is authorization_code.
  @param outds= The library.dataset to be created that contains the list of groups


  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas

**/

%macro mv_getgroups(access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
    ,outds=work.viyagroups
  );
%local oauth_bearer;
%if &grant_type=detect %then %do;
  %if %symexist(&access_token_var) %then %let grant_type=authorization_code;
  %else %let grant_type=sas_services;
%end;
%if &grant_type=sas_services %then %do;
    %let oauth_bearer=oauth_bearer=sas_services;
    %let &access_token_var=;
%end;
%put &sysmacroname: grant_type=&grant_type;
%mp_abort(iftrue=(&grant_type ne authorization_code and &grant_type ne password
    and &grant_type ne sas_services
  )
  ,mac=&sysmacroname
  ,msg=%str(Invalid value for grant_type: &grant_type)
)

options noquotelenmax;
%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

/* fetching folder details for provided path */
%local fname1;
%let fname1=%mf_getuniquefileref();
%let libref1=%mf_getuniquelibref();

proc http method='GET' out=&fname1 &oauth_bearer
  url="&base_uri/identities/groups?limit=10000";
  headers
  %if &grant_type=authorization_code %then %do;
          "Authorization"="Bearer &&&access_token_var"
  %end;
          "Accept"="application/json";
run;
/*data _null_;infile &fname1;input;putlog _infile_;run;*/
%mp_abort(iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 200)
  ,mac=&sysmacroname
  ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
)
libname &libref1 JSON fileref=&fname1;

data &outds;
  set &libref1..items;
run;



/* clear refs */
filename &fname1 clear;
libname &libref1 clear;

%mend; /**
   @file mv_getrefreshtoken.sas
   @brief deprecated - replaced by mv_tokenauth.sas

   @version VIYA V.03.04
   @author Allan Bowe, source: https://github.com/sasjs/core

   <h4> Dependencies </h4>
   @li mv_tokenauth.sas

 **/

 %macro mv_getrefreshtoken(client_id=someclient
     ,client_secret=somesecret
     ,grant_type=authorization_code
     ,code=
     ,user=
     ,pass=
     ,access_token_var=ACCESS_TOKEN
     ,refresh_token_var=REFRESH_TOKEN
   );

%mv_tokenauth(client_id=&client_id
  ,client_secret=&client_secret
  ,grant_type=&grant_type
  ,code=&code
  ,user=&user
  ,pass=&pass
  ,access_token_var=&access_token_var
  ,refresh_token_var=&refresh_token_var
)

%mend;/**
  @file mv_getusergroups.sas
  @brief Creates a dataset with a list of groups for a particular user
  @details If using outside of Viya SPRE, then an access token is needed.

  Compile the macros here:

      filename mc url
        "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

  Then run the macro!

      %mv_getusergroups(&sysuserid,outds=users)

  @param access_token_var= The global macro variable to contain the access token
  @param grant_type= valid values are "password" or "authorization_code" (unquoted).
    The default is authorization_code.
  @param outds= The library.dataset to be created that contains the list of groups


  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas

**/

%macro mv_getusergroups(user
    ,outds=work.mv_getusergroups
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
  );
%local oauth_bearer;
%if &grant_type=detect %then %do;
  %if %symexist(&access_token_var) %then %let grant_type=authorization_code;
  %else %let grant_type=sas_services;
%end;
%if &grant_type=sas_services %then %do;
    %let oauth_bearer=oauth_bearer=sas_services;
    %let &access_token_var=;
%end;
%put &sysmacroname: grant_type=&grant_type;
%mp_abort(iftrue=(&grant_type ne authorization_code and &grant_type ne password
    and &grant_type ne sas_services
  )
  ,mac=&sysmacroname
  ,msg=%str(Invalid value for grant_type: &grant_type)
)
options noquotelenmax;

%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

/* fetching folder details for provided path */
%local fname1;
%let fname1=%mf_getuniquefileref();
%let libref1=%mf_getuniquelibref();

proc http method='GET' out=&fname1 &oauth_bearer
  url="&base_uri/identities/users/&user/memberships?limit=10000";
  headers
%if &grant_type=authorization_code %then %do;
         "Authorization"="Bearer &&&access_token_var"
%end;
          "Accept"="application/json";
run;
/*data _null_;infile &fname1;input;putlog _infile_;run;*/
%if &SYS_PROCHTTP_STATUS_CODE=404 %then %do;
  %put NOTE:  User &user not found!!;
%end;
%else %do;
  %mp_abort(iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 200)
    ,mac=&sysmacroname
    ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
  )
%end;
libname &libref1 JSON fileref=&fname1;

data &outds;
  set &libref1..items;
run;

/* clear refs */
filename &fname1 clear;
libname &libref1 clear;

%mend;/**
  @file mv_getusers.sas
  @brief Creates a dataset with a list of users
  @details First, be sure you have an access token (which requires an app token).

  Using the macros here:

      filename mc url
      "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

  An administrator needs to set you up with an access code:

      %mv_registerclient(outds=client)

  Navigate to the url from the log (opting in to the groups) and paste the
  access code below:

      %mv_tokenauth(inds=client,code=wKDZYTEPK6)

  Now we can run the macro!

      %mv_getusers(outds=users)

  Output (lengths are dynamic):

      ordinal_root num,
      ordinal_items num,
      version num,
      id char(20),
      name char(23),
      providerId char(4),
      type char(4),
      creationTimeStamp char(24),
      modifiedTimeStamp char(24),
      state char(6)

  @param access_token_var= The global macro variable to contain the access token
  @param grant_type= valid values:
   * password
   * authorization_code
   * detect - will check if access_token exists, if not will use sas_services if
    a SASStudioV session else authorization_code.  Default option.
   * sas_services - will use oauth_bearer=sas_services

  @param outds= The library.dataset to be created that contains the list of groups


  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas

**/

%macro mv_getusers(outds=work.mv_getusers
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
  );
%local oauth_bearer;
%if &grant_type=detect %then %do;
  %if %symexist(&access_token_var) %then %let grant_type=authorization_code;
  %else %let grant_type=sas_services;
%end;
%if &grant_type=sas_services %then %do;
    %let oauth_bearer=oauth_bearer=sas_services;
    %let &access_token_var=;
%end;
%put &sysmacroname: grant_type=&grant_type;
%mp_abort(iftrue=(&grant_type ne authorization_code and &grant_type ne password
    and &grant_type ne sas_services
  )
  ,mac=&sysmacroname
  ,msg=%str(Invalid value for grant_type: &grant_type)
)

options noquotelenmax;

%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

/* fetching folder details for provided path */
%local fname1;
%let fname1=%mf_getuniquefileref();
%let libref1=%mf_getuniquelibref();

proc http method='GET' out=&fname1 &oauth_bearer
  url="&base_uri/identities/users?limit=10000";
%if &grant_type=authorization_code %then %do;
  headers "Authorization"="Bearer &&&access_token_var"
          "Accept"="application/json";
%end;
%else %do;
  headers "Accept"="application/json";
%end;
run;
/*data _null_;infile &fname1;input;putlog _infile_;run;*/
%mp_abort(iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 200)
  ,mac=&sysmacroname
  ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
)
libname &libref1 JSON fileref=&fname1;

data &outds;
  set &libref1..items;
run;

/* clear refs */
filename &fname1 clear;
libname &libref1 clear;

%mend;/**
  @file
  @brief Executes a SAS Viya Job
  @details Triggers a SAS Viya Job, with optional URL parameters, using
  the JES web app.

  First, compile the macros:

      filename mc url
      "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

  Then, execute the job!

      %mv_jobexecute(path=/Public/folder
        ,name=somejob
      )

  Example with parameters:

      %mv_jobexecute(path=/Public/folder
        ,name=somejob
        ,paramstring=%str("macvarname":"macvarvalue","answer":42)
      )

  @param access_token_var= The global macro variable to contain the access token
  @param grant_type= valid values:
   * password
   * authorization_code
   * detect - will check if access_token exists, if not will use sas_services if
    a SASStudioV session else authorization_code.  Default option.
   * sas_services - will use oauth_bearer=sas_services

  @param path= The SAS Drive path to the job being executed
  @param name= The name of the job to execute
  @param paramstring= A JSON fragment with name:value pairs, eg: `"name":"value"`
  or "name":"value","name2":42`.  This will need to be wrapped in `%str()`.

  @param contextName= Context name with which to run the job.
    Default = `SAS Job Execution compute context`

  @param outds= The output dataset containing links (Default=work.mv_jobexecute)


  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mv_getfoldermembers.sas

**/

%macro mv_jobexecute(path=0
    ,name=0
    ,contextName=SAS Job Execution compute context
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
    ,paramstring=0
    ,outds=work.mv_jobexecute
  );
%local oauth_bearer;
%if &grant_type=detect %then %do;
  %if %symexist(&access_token_var) %then %let grant_type=authorization_code;
  %else %let grant_type=sas_services;
%end;
%if &grant_type=sas_services %then %do;
    %let oauth_bearer=oauth_bearer=sas_services;
    %let &access_token_var=;
%end;
%put &sysmacroname: grant_type=&grant_type;
%mp_abort(iftrue=(&grant_type ne authorization_code and &grant_type ne password
    and &grant_type ne sas_services
  )
  ,mac=&sysmacroname
  ,msg=%str(Invalid value for grant_type: &grant_type)
)

%mp_abort(iftrue=("&path"="0")
  ,mac=&sysmacroname
  ,msg=%str(Path not provided)
)
%mp_abort(iftrue=("&name"="0")
  ,mac=&sysmacroname
  ,msg=%str(Job Name not provided)
)

options noquotelenmax;

%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

data;run;
%local foldermembers;
%let foldermembers=&syslast;
%mv_getfoldermembers(root=&path
    ,access_token_var=&access_token_var
    ,grant_type=&grant_type
    ,outds=&foldermembers
)

%local joburi;
%let joburi=0;
data _null_;
  set &foldermembers;
  if name="&name" and uri=:'/jobDefinitions/definitions'
    then call symputx('joburi',uri);
run;

%mp_abort(iftrue=("&joburi"="0")
  ,mac=&sysmacroname
  ,msg=%str(Job &path/&name not found)
)

/* prepare request*/
%local fname0 fname1;
%let fname0=%mf_getuniquefileref();
%let fname1=%mf_getuniquefileref();

data _null_;
  file &fname0;
  length joburi contextname $128 paramstring $32765;
  joburi=quote(trim(symget('joburi')));
  contextname=quote(trim(symget('contextname')));
  paramstring=symget('paramstring');
  put '{"jobDefinitionUri":' joburi ;
  put '  ,"arguments":{"_contextName":' contextname;
  if paramstring ne "0" then do;
    put '    ,' paramstring;
  end;
  put '}}';
run;

proc http method='POST' in=&fname0 out=&fname1 &oauth_bearer
  url="&base_uri/jobExecution/jobs";
  headers "Content-Type"="application/vnd.sas.job.execution.job.request+json"
          "Accept"="application/vnd.sas.job.execution.job+json"
  %if &grant_type=authorization_code %then %do;
          "Authorization"="Bearer &&&access_token_var"
  %end;
  ;
run;
%if &SYS_PROCHTTP_STATUS_CODE ne 200 and &SYS_PROCHTTP_STATUS_CODE ne 201 %then
%do;
  data _null_;infile &fname0;input;putlog _infile_;run;
  data _null_;infile &fname1;input;putlog _infile_;run;
  %mp_abort(mac=&sysmacroname
    ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
  )
%end;

%local libref;
%let libref=%mf_getuniquelibref();
libname &libref JSON fileref=&fname1;

data &outds;
  set &libref..links;
run;

/* clear refs */
filename &fname0 clear;
filename &fname1 clear;
libname &libref;

%mend;/**
  @file mv_registerclient.sas
  @brief Register Client and Secret (admin task)
  @details When building apps on SAS Viya, an client id and secret is required.
  This macro will obtain the Consul Token and use that to call the Web Service.

    more info: https://developer.sas.com/reference/auth/#register
    and: http://proc-x.com/2019/01/authentication-to-sas-viya-a-couple-of-approaches/

  The default viyaroot location is /opt/sas/viya/config

  Usage:

      %* compile macros;
      filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

      %* specific client with just openid scope;
      %mv_registerclient(client_id=YourClient
        ,client_secret=YourSecret
        ,scopes=openid
      )

      %* generate random client details with all scopes;
      %mv_registerclient(scopes=openid *)

      %* generate random client with 90/180 second access/refresh token expiry;
      %mv_registerclient(scopes=openid *
        ,access_token_validity=90
        ,refresh_token_validity=180
      )

  @param client_id= The client name.  Auto generated if blank.
  @param client_secret= Client secret  Auto generated if client is blank.
  @param scopes= list of space-seperated unquoted scopes (default is openid)
  @param grant_type= valid values are "password" or "authorization_code" (unquoted)
  @param outds= the dataset to contain the registered client id and secret
  @param access_token_validity= The duration of validity of the access token
    in seconds.  A value of DEFAULT will omit the entry (and use system default)
  @param refresh_token_validity= The duration of validity of the refresh token
    in seconds.  A value of DEFAULT will omit the entry (and use system default)
  @param name= A human readable name for the client
  @param required_user_groups= A list of group names. If a user does not belong
    to all the required groups, the user will not be authenticated and no tokens
    are issued to this client for that user. If this field is not specified,
    authentication and token issuance proceeds normally.
  @param autoapprove= During the auth step the user can choose which scope to
    apply.  Setting this to true will autoapprove all the client scopes.
  @param use_session= If true, access tokens issued to this client will be
    associated with an HTTP session and revoked upon logout or time-out.
  @param outjson= A dataset containing the lines of JSON submitted.  Useful
    for debugging.  Default= _null_.

  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mf_loc.sas
  @li mf_getquotedstr.sas
  @li mf_getuser.sas

**/

%macro mv_registerclient(client_id=
    ,client_secret=
    ,client_name=DEFAULT
    ,scopes=openid
    ,grant_type=authorization_code|refresh_token
    ,required_user_groups=
    ,autoapprove=
    ,use_session=
    ,outds=mv_registerclient
    ,access_token_validity=DEFAULT
    ,refresh_token_validity=DEFAULT
    ,outjson=_null_
  );
%local consul_token fname1 fname2 fname3 libref access_token url;

%if client_name=DEFAULT %then %let client_name=
  Generated by %mf_getuser() on %sysfunc(datetime(),datetime19.) using SASjs;

options noquotelenmax;
/* first, get consul token needed to get client id / secret */
data _null_;
  infile "%mf_loc(VIYACONFIG)/etc/SASSecurityCertificateFramework/tokens/consul/default/client.token";
  input token:$64.;
  call symputx('consul_token',token);
run;

%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

/* request the client details */
%let fname1=%mf_getuniquefileref();
proc http method='POST' out=&fname1
    url="&base_uri/SASLogon/oauth/clients/consul?callback=false%str(&)serviceId=app";
    headers "X-Consul-Token"="&consul_token";
run;

%let libref=%mf_getuniquelibref();
libname &libref JSON fileref=&fname1;

/* extract the token */
data _null_;
  set &libref..root;
  call symputx('access_token',access_token,'l');
run;

/**
 * register the new client
 */
%let fname2=%mf_getuniquefileref();
%if x&client_id.x=xx %then %do;
  %let client_id=client_%sysfunc(ranuni(0),hex16.);
  %let client_secret=secret_%sysfunc(ranuni(0),hex16.);
%end;

%let scopes=%sysfunc(coalescec(&scopes,openid));
%let scopes=%mf_getquotedstr(&scopes,QUOTE=D,indlm=|);
%let grant_type=%mf_getquotedstr(&grant_type,QUOTE=D,indlm=|);
%let required_user_groups=%mf_getquotedstr(&required_user_groups,QUOTE=D,indlm=|);

data _null_;
  file &fname2;
  length clientid clientsecret clientname scope grant_types reqd_groups
    autoapprove $256.;
  clientid='"client_id":'!!quote(trim(symget('client_id')));
  clientsecret=',"client_secret":'!!quote(trim(symget('client_secret')));
  clientname=',"name":'!!quote(trim(symget('client_name')));
  scope=',"scope":['!!symget('scopes')!!']';
  grant_types=symget('grant_type');
  if grant_types = '""' then grant_types ='';
  grant_types=cats(',"authorized_grant_types": [',grant_types,']');
  reqd_groups=symget('required_user_groups');
  if reqd_groups = '""' then reqd_groups ='';
  else reqd_groups=cats(',"required_user_groups":[',reqd_groups,']');
  autoapprove=trim(symget('autoapprove'));
  if not missing(autoapprove) then autoapprove=cats(',"autoapprove":',autoapprove);
  use_session=trim(symget('use_session'));
  if not missing(use_session) then use_session=cats(',"use_session":',use_session);

  put '{'  clientid  ;
  put clientsecret ;
  put clientname;
  put scope;
  put grant_types;
  if not missing(reqd_groups) then put reqd_groups;
  put autoapprove;
  put use_session;
%if &access_token_validity ne DEFAULT %then %do;
  put ',"access_token_validity":' "&access_token_validity";
%end;
%if &refresh_token_validity ne DEFAULT %then %do;
  put  ',"refresh_token_validity":' "&refresh_token_validity";
%end;

  put ',"redirect_uri": "urn:ietf:wg:oauth:2.0:oob"';
  put '}';
run;

%let fname3=%mf_getuniquefileref();
proc http method='POST' in=&fname2 out=&fname3
    url="&base_uri/SASLogon/oauth/clients";
    headers "Content-Type"="application/json"
            "Authorization"="Bearer &access_token";
run;

/* show response */
%local err;
%let err=NONE;
data _null_;
  infile &fname3;
  input;
  if _infile_=:'{"err'!!'or":' then do;
    length message $32767;
    message=scan(_infile_,-2,'"');
    call symputx('err',message,'l');
  end;
run;
%if "&err" ne "NONE" %then %do;
  %put %str(ERR)OR: &err;
%end;

/* prepare url */
%if %index(%superq(grant_type),authorization_code) %then %do;
  data _null_;
    if symexist('_baseurl') then do;
      url=symget('_baseurl');
      if subpad(url,length(url)-9,9)='SASStudio'
        then url=substr(url,1,length(url)-11);
      else url="&systcpiphostname";
    end;
    else url="&systcpiphostname";
    call symputx('url',url);
  run;
%end;

%put Please provide the following details to the developer:;
%put ;
%put CLIENT_ID=&client_id;
%put CLIENT_SECRET=&client_secret;
%put GRANT_TYPE=&grant_type;
%put;
%if %index(%superq(grant_type),authorization_code) %then %do;
  /* cannot use base_uri here as it includes the protocol which may be incorrect externally */
  %put NOTE: The developer must also register below and select 'openid' to get the grant code:;
  %put NOTE- ;
  %put NOTE- &url/SASLogon/oauth/authorize?client_id=&client_id%str(&)response_type=code;
  %put NOTE- ;
%end;

data &outds;
  client_id=symget('client_id');
  client_secret=symget('client_secret');
  error=symget('err');
run;

data &outjson;
  infile &fname2;
  input;
  line=_infile_;
run;

/* clear refs */
filename &fname1 clear;
filename &fname2 clear;
filename &fname3 clear;
libname &libref clear;

%mend;
/**
  @file mv_tokenauth.sas
  @brief Get initial Refresh and Access Tokens
  @details Before a Refresh Token can be obtained, the client must be
    registered by an administrator.  This can be done using the
    `mv_registerclient` macro, after which the user must visit a URL to get an
    additional code (if using oauth).

    That code (or username / password) is used here to get the Refresh Token
    (and an initial Access Token).  THIS MACRO CAN ONLY BE USED ONCE - further
    access tokens can be obtained using the `mv_gettokenrefresh` macro.

    Access tokens expire frequently (every 10 hours or so) whilst refresh tokens
    expire periodically (every month or so).  This is all configurable.

  Usage:

      filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;


      %mv_registerclient(outds=clientinfo)

      %mv_tokenauth(inds=clientinfo,code=LD39EpalOf)

    A great article for explaining all these steps is available here:

    https://blogs.sas.com/content/sgf/2019/01/25/authentication-to-sas-viya/

  @param inds= A dataset containing client_id, client_secret, and auth_code
  @param outds= A dataset containing access_token and refresh_token
  @param client_id= The client name
  @param client_secret= client secret
  @param grant_type= valid values are "password" or "authorization_code" (unquoted).
    The default is authorization_code.
  @param code= If grant_type=authorization_code then provide the necessary code here
  @param user= If grant_type=password then provide the username here
  @param pass= If grant_type=password then provide the password here
  @param access_token_var= The global macro variable to contain the access token
  @param refresh_token_var= The global macro variable to contain the refresh token
  @param base_uri= The Viya API server location

  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mf_existds.sas

**/

%macro mv_tokenauth(inds=mv_registerclient
    ,outds=mv_tokenauth
    ,client_id=someclient
    ,client_secret=somesecret
    ,grant_type=authorization_code
    ,code=
    ,user=
    ,pass=
    ,access_token_var=ACCESS_TOKEN
    ,refresh_token_var=REFRESH_TOKEN
    ,base_uri=#NOTSET#
  );
%global &access_token_var &refresh_token_var;

%local fref1 fref2 libref;

/* test the validity of inputs */
%mp_abort(iftrue=(&grant_type ne authorization_code and &grant_type ne password)
  ,mac=&sysmacroname
  ,msg=%str(Invalid value for grant_type: &grant_type)
)

%if %mf_existds(&inds) %then %do;
  data _null_;
    set &inds;
    call symputx('client_id',client_id,'l');
    call symputx('client_secret',client_secret,'l');
    if not missing(auth_code) then call symputx('code',auth_code,'l');
  run;
%end;

%mp_abort(iftrue=(&grant_type=authorization_code and %str(&code)=%str())
  ,mac=&sysmacroname
  ,msg=%str(Authorization code required)
)

%mp_abort(iftrue=(&grant_type=password and (%str(&user)=%str() or %str(&pass)=%str()))
  ,mac=&sysmacroname
  ,msg=%str(username / password required)
)

/* prepare appropriate grant type */
%let fref1=%mf_getuniquefileref();

data _null_;
  file &fref1;
  if "&grant_type"='authorization_code' then string=cats(
   'grant_type=authorization_code&code=',symget('code'));
  else string=cats('grant_type=password&username=',symget('user')
    ,'&password=',symget(pass));
  call symputx('grantstring',cats("'",string,"'"));
run;
/*data _null_;infile &fref1;input;put _infile_;run;*/

/**
 * Request access token
 */
%if &base_uri=#NOTSET# %then %let base_uri=%mf_getplatform(VIYARESTAPI);

%let fref2=%mf_getuniquefileref();
proc http method='POST' in=&grantstring out=&fref2
  url="&base_uri/SASLogon/oauth/token"
  WEBUSERNAME="&client_id"
  WEBPASSWORD="&client_secret"
  AUTH_BASIC;
  headers "Accept"="application/json"
          "Content-Type"="application/x-www-form-urlencoded";
run;
/*data _null_;infile &fref2;input;put _infile_;run;*/

/**
 * Extract access / refresh tokens
 */

%let libref=%mf_getuniquelibref();
libname &libref JSON fileref=&fref2;

/* extract the tokens */
data &outds;
  set &libref..root;
  call symputx("&access_token_var",access_token);
  call symputx("&refresh_token_var",refresh_token);
run;


libname &libref clear;
filename &fref1 clear;
filename &fref2 clear;

%mend;/**
  @file mv_tokenrefresh.sas
  @brief Get an additional access token using a refresh token
  @details Before an access token can be obtained, a refresh token is required
    For that, check out the `mv_tokenauth` macro.

  Usage:

      * prep work - register client, get refresh token, save it for later use ;
      %mv_registerclient(outds=client)
      %mv_tokenauth(inds=client,code=wKDZYTEPK6)
      data _null_;
      file "~/refresh.token";
      put "&refresh_token";
      run;

      * now do the things n stuff;
      data _null_;
        infile "~/refresh.token";
        input;
        call symputx('refresh_token',_infile_);
      run;
      %mv_tokenrefresh(client_id=&client
        ,client_secret=&secret
      )

  A great article for explaining all these steps is available here:

  https://blogs.sas.com/content/sgf/2019/01/25/authentication-to-sas-viya/

  @param inds= A dataset containing client_id and client_secret
  @param outds= A dataset containing access_token and refresh_token
  @param client_id= The client name (alternative to inds)
  @param client_secret= client secret (alternative to inds)
  @param grant_type= valid values are "password" or "authorization_code" (unquoted).
    The default is authorization_code.
  @param user= If grant_type=password then provide the username here
  @param pass= If grant_type=password then provide the password here
  @param access_token_var= The global macro variable to contain the access token
  @param refresh_token_var= The global macro variable containing the refresh token

  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mf_existds.sas

**/

%macro mv_tokenrefresh(inds=mv_registerclient
    ,outds=mv_tokenrefresh
    ,client_id=someclient
    ,client_secret=somesecret
    ,grant_type=authorization_code
    ,user=
    ,pass=
    ,access_token_var=ACCESS_TOKEN
    ,refresh_token_var=REFRESH_TOKEN
  );
%global &access_token_var &refresh_token_var;
options noquotelenmax;

%local fref1 libref;

/* test the validity of inputs */
%mp_abort(iftrue=(&grant_type ne authorization_code and &grant_type ne password)
  ,mac=&sysmacroname
  ,msg=%str(Invalid value for grant_type: &grant_type)
)

%mp_abort(iftrue=(&grant_type=password and (%str(&user)=%str() or %str(&pass)=%str()))
  ,mac=&sysmacroname
  ,msg=%str(username / password required)
)

%if %mf_existds(&inds) %then %do;
  data _null_;
    set &inds;
    call symputx('client_id',client_id,'l');
    call symputx('client_secret',client_secret,'l');
    call symputx("&refresh_token_var",&refresh_token_var,'l');
  run;
%end;

%mp_abort(iftrue=(%str(&client_id)=%str() or %str(&client_secret)=%str())
  ,mac=&sysmacroname
  ,msg=%str(client / secret must both be provided)
)

/**
 * Request access token
 */
%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

%let fref1=%mf_getuniquefileref();
proc http method='POST'
  in="grant_type=refresh_token%nrstr(&)refresh_token=&&&refresh_token_var"
  out=&fref1
  url="&base_uri/SASLogon/oauth/token"
  WEBUSERNAME="&client_id"
  WEBPASSWORD="&client_secret"
  AUTH_BASIC;
  headers "Accept"="application/json"
          "Content-Type"="application/x-www-form-urlencoded";
run;
/*data _null_;infile &fref1;input;put _infile_;run;*/

/**
 * Extract access / refresh tokens
 */

%let libref=%mf_getuniquelibref();
libname &libref JSON fileref=&fref1;

/* extract the token */
data &outds;
  set &libref..root;
  call symputx("&access_token_var",access_token);
  call symputx("&refresh_token_var",refresh_token);
run;


libname &libref clear;
filename &fref1 clear;

%mend;/**
  @file mv_webout.sas
  @brief Send data to/from the SAS Viya Job Execution Service
  @details This macro should be added to the start of each Job Execution
  Service, **immediately** followed by a call to:

        %mv_webout(FETCH)

    This will read all the input data and create same-named SAS datasets in the
    WORK library.  You can then insert your code, and send data back using the
    following syntax:

        data some datasets; * make some data ;
        retain some columns;
        run;

        %mv_webout(OPEN)
        %mv_webout(ARR,some)  * Array format, fast, suitable for large tables ;
        %mv_webout(OBJ,datasets) * Object format, easier to work with ;
        %mv_webout(CLOSE)


  @param action Either OPEN, ARR, OBJ or CLOSE
  @param ds The dataset to send back to the frontend
  @param _webout= fileref for returning the json
  @param fref= temp fref
  @param dslabel= value to use instead of the real name for sending to JSON
  @param fmt= change to N to strip formats from output

  <h4> Dependencies </h4>
  @li mp_jsonout.sas
  @li mf_getuser.sas

  @version Viya 3.3
  @author Allan Bowe, source: https://github.com/sasjs/core

**/
%macro mv_webout(action,ds,fref=_mvwtemp,dslabel=,fmt=Y);
%global _webin_file_count _webin_fileuri _debug _omittextlog _webin_name
  sasjs_tables SYS_JES_JOB_URI;
%if %index("&_debug",log) %then %let _debug=131;

%local i tempds;
%let action=%upcase(&action);

%if &action=FETCH %then %do;
  %if %upcase(&_omittextlog)=FALSE or %str(&_debug) ge 131 %then %do;
    options mprint notes mprintnest;
  %end;

  %if not %symexist(_webin_fileuri1) %then %do;
    %let _webin_file_count=%eval(&_webin_file_count+0);
    %let _webin_fileuri1=&_webin_fileuri;
    %let _webin_name1=&_webin_name;
  %end;

  /* if the sasjs_tables param is passed, we expect param based upload */
  %if %length(&sasjs_tables.XX)>2 %then %do;
    filename _sasjs "%sysfunc(pathname(work))/sasjs.lua";
    data _null_;
      file _sasjs;
      put 's=sas.symget("sasjs_tables")';
      put 'if(s:sub(1,7) == "%nrstr(")';
      put 'then';
      put ' tablist=s:sub(8,s:len()-1)';
      put 'else';
      put ' tablist=s';
      put 'end';
      put 'for i = 1,sas.countw(tablist) ';
      put 'do ';
      put '  tab=sas.scan(tablist,i)';
      put '  sasdata=""';
      put '  if (sas.symexist("sasjs"..i.."data0")==0)';
      put '  then';
      /* TODO - condense this logic */
      put '    s=sas.symget("sasjs"..i.."data")';
      put '    if(s:sub(1,7) == "%nrstr(")';
      put '    then';
      put '      sasdata=s:sub(8,s:len()-1)';
      put '    else';
      put '      sasdata=s';
      put '    end';
      put '  else';
      put '    for d = 1, sas.symget("sasjs"..i.."data0")';
      put '    do';
      put '      s=sas.symget("sasjs"..i.."data"..d)';
      put '      if(s:sub(1,7) == "%nrstr(")';
      put '      then';
      put '        sasdata=sasdata..s:sub(8,s:len()-1)';
      put '      else';
      put '        sasdata=sasdata..s';
      put '      end';
      put '    end';
      put '  end';
      put '  file = io.open(sas.pathname("work").."/"..tab..".csv", "a")';
      put '  io.output(file)';
      put '  io.write(sasdata)';
      put '  io.close(file)';
      put 'end';
    run;
    %inc _sasjs;

    /* now read in the data */
    %do i=1 %to %sysfunc(countw(&sasjs_tables));
      %local table; %let table=%scan(&sasjs_tables,&i);
      data _null_;
        infile "%sysfunc(pathname(work))/&table..csv" termstr=crlf ;
        input;
        if _n_=1 then call symputx('input_statement',_infile_);
        list;
      data &table;
        infile "%sysfunc(pathname(work))/&table..csv" firstobs=2 dsd termstr=crlf;
        input &input_statement;
      run;
    %end;
  %end;
  %else %do i=1 %to &_webin_file_count;
    /* read in any files that are sent */
    /* this part needs refactoring for wide files */
    filename indata filesrvc "&&_webin_fileuri&i" lrecl=999999;
    data _null_;
      infile indata termstr=crlf lrecl=32767;
      input;
      if _n_=1 then call symputx('input_statement',_infile_);
      %if %str(&_debug) ge 131 %then %do;
        if _n_<20 then putlog _infile_;
        else stop;
      %end;
      %else %do;
        stop;
      %end;
    run;
    data &&_webin_name&i;
      infile indata firstobs=2 dsd termstr=crlf ;
      input &input_statement;
    run;
    %let sasjs_tables=&sasjs_tables &&_webin_name&i;
  %end;
%end;
%else %if &action=OPEN %then %do;
  /* setup webout */
  OPTIONS NOBOMFILE;
  %if "X&SYS_JES_JOB_URI.X"="XX" %then %do;
     filename _webout temp lrecl=999999 mod;
  %end;
  %else %do;
    filename _webout filesrvc parenturi="&SYS_JES_JOB_URI"
      name="_webout.json" lrecl=999999 mod;
  %end;

  /* setup temp ref */
  %if %upcase(&fref) ne _WEBOUT %then %do;
    filename &fref temp lrecl=999999 permission='A::u::rwx,A::g::rw-,A::o::---' mod;
  %end;

  /* setup json */
  data _null_;file &fref;
    put '{"START_DTTM" : "' "%sysfunc(datetime(),datetime20.3)" '"';
  run;
%end;
%else %if &action=ARR or &action=OBJ %then %do;
    %mp_jsonout(&action,&ds,dslabel=&dslabel,fmt=&fmt
      ,jref=&fref,engine=PROCJSON,dbg=%str(&_debug)
    )
%end;
%else %if &action=CLOSE %then %do;
  %if %str(&_debug) ge 131 %then %do;
    /* send back first 10 records of each work table for debugging */
    options obs=10;
    data;run;%let tempds=%scan(&syslast,2,.);
    ods output Members=&tempds;
    proc datasets library=WORK memtype=data;
    %local wtcnt;%let wtcnt=0;
    data _null_; set &tempds;
      if not (name =:"DATA");
      i+1;
      call symputx('wt'!!left(i),name);
      call symputx('wtcnt',i);
    data _null_; file &fref mod; put ",""WORK"":{";
    %do i=1 %to &wtcnt;
      %let wt=&&wt&i;
      proc contents noprint data=&wt
        out=_data_ (keep=name type length format:);
      run;%let tempds=%scan(&syslast,2,.);
      data _null_; file &fref mod;
        dsid=open("WORK.&wt",'is');
        nlobs=attrn(dsid,'NLOBS');
        nvars=attrn(dsid,'NVARS');
        rc=close(dsid);
        if &i>1 then put ','@;
        put " ""&wt"" : {";
        put '"nlobs":' nlobs;
        put ',"nvars":' nvars;
      %mp_jsonout(OBJ,&tempds,jref=&fref,dslabel=colattrs,engine=DATASTEP)
      %mp_jsonout(OBJ,&wt,jref=&fref,dslabel=first10rows,engine=DATASTEP)
      data _null_; file &fref mod;put "}";
    %end;
    data _null_; file &fref mod;put "}";run;
  %end;

  /* close off json */
  data _null_;file &fref mod;
    _PROGRAM=quote(trim(resolve(symget('_PROGRAM'))));
    put ",""SYSUSERID"" : ""&sysuserid"" ";
    put ",""MF_GETUSER"" : ""%mf_getuser()"" ";
    SYS_JES_JOB_URI=quote(trim(resolve(symget('SYS_JES_JOB_URI'))));
    put ',"SYS_JES_JOB_URI" : ' SYS_JES_JOB_URI ;
    put ",""SYSJOBID"" : ""&sysjobid"" ";
    put ",""_DEBUG"" : ""&_debug"" ";
    put ',"_PROGRAM" : ' _PROGRAM ;
    put ",""SYSCC"" : ""&syscc"" ";
    put ",""SYSERRORTEXT"" : ""&syserrortext"" ";
    put ",""SYSHOSTNAME"" : ""&syshostname"" ";
    put ",""SYSSITE"" : ""&syssite"" ";
    put ",""SYSWARNINGTEXT"" : ""&syswarningtext"" ";
    put ',"END_DTTM" : "' "%sysfunc(datetime(),datetime20.3)" '" ';
    put "}";

  %if %upcase(&fref) ne _WEBOUT %then %do;
    data _null_; rc=fcopy("&fref","_webout");run;
  %end;

%end;

%mend;
/**
  @file ml_json2sas.sas
  @brief Creates the json2sas.lua file
  @details Writes json2sas.lua to the work directory
  Usage:

      %ml_json2sas()

**/

%macro ml_json2sas();
data _null_;
  file "%sysfunc(pathname(work))/json2sas.lua";
  put '-- ';
  put '-- json2sas.lua  (modified from json.lua) ';
  put '-- ';
  put '-- Copyright (c) 2019 rxi ';
  put '-- ';
  put '-- Permission is hereby granted, free of charge, to any person obtaining a copy of ';
  put '-- this software and associated documentation files (the "Software"), to deal in ';
  put '-- the Software without restriction, including without limitation the rights to ';
  put '-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies ';
  put '-- of the Software, and to permit persons to whom the Software is furnished to do ';
  put '-- so, subject to the following conditions: ';
  put '-- ';
  put '-- The above copyright notice and this permission notice shall be included in all ';
  put '-- copies or substantial portions of the Software. ';
  put '-- ';
  put '-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR ';
  put '-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, ';
  put '-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE ';
  put '-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER ';
  put '-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, ';
  put '-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE ';
  put '-- SOFTWARE. ';
  put '-- ';
  put ' ';
  put 'local json2sas = { _version = "0.1.2" } ';
  put ' ';
  put '------------------------------------------------------------------------------- ';
  put '-- Encode ';
  put '------------------------------------------------------------------------------- ';
  put ' ';
  put 'local encode ';
  put ' ';
  put 'local escape_char_map = { ';
  put '  [ "\\" ] = "\\\\", ';
  put '  [ "\"" ] = "\\\"", ';
  put '  [ "\b" ] = "\\b", ';
  put '  [ "\f" ] = "\\f", ';
  put '  [ "\n" ] = "\\n", ';
  put '  [ "\r" ] = "\\r", ';
  put '  [ "\t" ] = "\\t", ';
  put '} ';
  put ' ';
  put 'local escape_char_map_inv = { [ "\\/" ] = "/" } ';
  put 'for k, v in pairs(escape_char_map) do ';
  put '  escape_char_map_inv[v] = k ';
  put 'end ';
  put ' ';
  put 'local function escape_char(c) ';
  put '  return escape_char_map[c] or string.format("\\u%04x", c:byte()) ';
  put 'end ';
  put ' ';
  put 'local function encode_nil(val) ';
  put '  return "null" ';
  put 'end ';
  put ' ';
  put 'local function encode_table(val, stack) ';
  put '  local res = {} ';
  put '  stack = stack or {} ';
  put ' ';
  put '  -- Circular reference? ';
  put '  if stack[val] then error("circular reference") end ';
  put ' ';
  put '  stack[val] = true ';
  put ' ';
  put '  if rawget(val, 1) ~= nil or next(val) == nil then ';
  put '    -- Treat as array -- check keys are valid and it is not sparse ';
  put '    local n = 0 ';
  put '    for k in pairs(val) do ';
  put '      if type(k) ~= "number" then ';
  put '        error("invalid table: mixed or invalid key types") ';
  put '      end ';
  put '      n = n + 1 ';
  put '    end ';
  put '    if n ~= #val then ';
  put '      error("invalid table: sparse array") ';
  put '    end ';
  put '    -- Encode ';
  put '    for i, v in ipairs(val) do ';
  put '      table.insert(res, encode(v, stack)) ';
  put '    end ';
  put '    stack[val] = nil ';
  put '    return "[" .. table.concat(res, ",") .. "]" ';
  put '  else ';
  put '    -- Treat as an object ';
  put '    for k, v in pairs(val) do ';
  put '      if type(k) ~= "string" then ';
  put '        error("invalid table: mixed or invalid key types") ';
  put '      end ';
  put '      table.insert(res, encode(k, stack) .. ":" .. encode(v, stack)) ';
  put '    end ';
  put '    stack[val] = nil ';
  put '    return "{" .. table.concat(res, ",") .. "}" ';
  put '  end ';
  put 'end ';
  put ' ';
  put 'local function encode_string(val) ';
  put '  return ''"'' .. val:gsub(''[%z\1-\31\\"]'', escape_char) .. ''"'' ';
  put 'end ';
  put ' ';
  put 'local function encode_number(val) ';
  put '  -- Check for NaN, -inf and inf ';
  put '  if val ~= val or val <= -math.huge or val >= math.huge then ';
  put '    error("unexpected number value ''" .. tostring(val) .. "''") ';
  put '  end ';
  put '  return string.format("%.14g", val) ';
  put 'end ';
  put ' ';
  put 'local type_func_map = { ';
  put '  [ "nil"     ] = encode_nil, ';
  put '  [ "table"   ] = encode_table, ';
  put '  [ "string"  ] = encode_string, ';
  put '  [ "number"  ] = encode_number, ';
  put '  [ "boolean" ] = tostring, ';
  put '} ';
  put ' ';
  put 'encode = function(val, stack) ';
  put '  local t = type(val) ';
  put '  local f = type_func_map[t] ';
  put '  if f then ';
  put '    return f(val, stack) ';
  put '  end ';
  put '  error("unexpected type ''" .. t .. "''") ';
  put 'end ';
  put ' ';
  put 'function json2sas.encode(val) ';
  put '  return ( encode(val) ) ';
  put 'end ';
  put ' ';
  put '------------------------------------------------------------------------------- ';
  put '-- Decode ';
  put '------------------------------------------------------------------------------- ';
  put 'local parse ';
  put 'local function create_set(...) ';
  put '  local res = {} ';
  put '  for i = 1, select("#", ...) do ';
  put '    res[ select(i, ...) ] = true ';
  put '  end ';
  put '  return res ';
  put 'end ';
  put ' ';
  put 'local space_chars   = create_set(" ", "\t", "\r", "\n") ';
  put 'local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",") ';
  put 'local escape_chars  = create_set("\\", "/", ''"'', "b", "f", "n", "r", "t", "u") ';
  put 'local literals      = create_set("true", "false", "null") ';
  put ' ';
  put 'local literal_map = { ';
  put '  [ "true"  ] = true, ';
  put '  [ "false" ] = false, ';
  put '  [ "null"  ] = nil, ';
  put '} ';
  put ' ';
  put 'local function next_char(str, idx, set, negate) ';
  put '  for i = idx, #str do ';
  put '    if set[str:sub(i, i)] ~= negate then ';
  put '      return i ';
  put '    end ';
  put '  end ';
  put '  return #str + 1 ';
  put 'end ';
  put ' ';
  put 'local function decode_error(str, idx, msg) ';
  put '  local line_count = 1 ';
  put '  local col_count = 1 ';
  put '  for i = 1, idx - 1 do ';
  put '    col_count = col_count + 1 ';
  put '    if str:sub(i, i) == "\n" then ';
  put '      line_count = line_count + 1 ';
  put '      col_count = 1 ';
  put '    end ';
  put '  end ';
  put '  error( string.format("%s at line %d col %d", msg, line_count, col_count) ) ';
  put 'end ';
  put ' ';
  put 'local function codepoint_to_utf8(n) ';
  put '  -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa ';
  put '  local f = math.floor ';
  put '  if n <= 0x7f then ';
  put '    return string.char(n) ';
  put '  elseif n <= 0x7ff then ';
  put '    return string.char(f(n / 64) + 192, n % 64 + 128) ';
  put '  elseif n <= 0xffff then ';
  put '    return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128) ';
  put '  elseif n <= 0x10ffff then ';
  put '    return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128, ';
  put '                       f(n % 4096 / 64) + 128, n % 64 + 128) ';
  put '  end ';
  put '  error( string.format("invalid unicode codepoint ''%x''", n) ) ';
  put 'end ';
  put ' ';
  put 'local function parse_unicode_escape(s) ';
  put '  local n1 = tonumber( s:sub(3, 6),  16 ) ';
  put '  local n2 = tonumber( s:sub(9, 12), 16 ) ';
  put '  -- Surrogate pair? ';
  put '  if n2 then ';
  put '    return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000) ';
  put '  else ';
  put '    return codepoint_to_utf8(n1) ';
  put '  end ';
  put 'end ';
  put ' ';
  put 'local function parse_string(str, i) ';
  put '  local has_unicode_escape = false ';
  put '  local has_surrogate_escape = false ';
  put '  local has_escape = false ';
  put '  local last ';
  put '  for j = i + 1, #str do ';
  put '    local x = str:byte(j) ';
  put '    if x < 32 then ';
  put '      decode_error(str, j, "control character in string") ';
  put '    end ';
  put '    if last == 92 then -- "\\" (escape char) ';
  put '      if x == 117 then -- "u" (unicode escape sequence) ';
  put '        local hex = str:sub(j + 1, j + 5) ';
  put '        if not hex:find("%x%x%x%x") then ';
  put '          decode_error(str, j, "invalid unicode escape in string") ';
  put '        end ';
  put '        if hex:find("^[dD][89aAbB]") then ';
  put '          has_surrogate_escape = true ';
  put '        else ';
  put '          has_unicode_escape = true ';
  put '        end ';
  put '      else ';
  put '        local c = string.char(x) ';
  put '        if not escape_chars[c] then ';
  put '          decode_error(str, j, "invalid escape char ''" .. c .. "'' in string") ';
  put '        end ';
  put '        has_escape = true ';
  put '      end ';
  put '      last = nil ';
  put '    elseif x == 34 then -- ''"'' (end of string) ';
  put '      local s = str:sub(i + 1, j - 1) ';
  put '      if has_surrogate_escape then ';
  put '        s = s:gsub("\\u[dD][89aAbB]..\\u....", parse_unicode_escape) ';
  put '      end ';
  put '      if has_unicode_escape then ';
  put '        s = s:gsub("\\u....", parse_unicode_escape) ';
  put '      end ';
  put '      if has_escape then ';
  put '        s = s:gsub("\\.", escape_char_map_inv) ';
  put '      end ';
  put '      return s, j + 1 ';
  put '    else ';
  put '      last = x ';
  put '    end ';
  put '  end ';
  put '  decode_error(str, i, "expected closing quote for string") ';
  put 'end ';
  put ' ';
  put 'local function parse_number(str, i) ';
  put '  local x = next_char(str, i, delim_chars) ';
  put '  local s = str:sub(i, x - 1) ';
  put '  local n = tonumber(s) ';
  put '  if not n then ';
  put '    decode_error(str, i, "invalid number ''" .. s .. "''") ';
  put '  end ';
  put '  return n, x ';
  put 'end ';
  put ' ';
  put 'local function parse_literal(str, i) ';
  put '  local x = next_char(str, i, delim_chars) ';
  put '  local word = str:sub(i, x - 1) ';
  put '  if not literals[word] then ';
  put '    decode_error(str, i, "invalid literal ''" .. word .. "''") ';
  put '  end ';
  put '  return literal_map[word], x ';
  put 'end ';
  put ' ';
  put 'local function parse_array(str, i) ';
  put '  local res = {} ';
  put '  local n = 1 ';
  put '  i = i + 1 ';
  put '  while 1 do ';
  put '    local x ';
  put '    i = next_char(str, i, space_chars, true) ';
  put '    -- Empty / end of array? ';
  put '    if str:sub(i, i) == "]" then ';
  put '      i = i + 1 ';
  put '      break ';
  put '    end ';
  put '    -- Read token ';
  put '    x, i = parse(str, i) ';
  put '    res[n] = x ';
  put '    n = n + 1 ';
  put '    -- Next token ';
  put '    i = next_char(str, i, space_chars, true) ';
  put '    local chr = str:sub(i, i) ';
  put '    i = i + 1 ';
  put '    if chr == "]" then break end ';
  put '    if chr ~= "," then decode_error(str, i, "expected '']'' or '',''") end ';
  put '  end ';
  put '  return res, i ';
  put 'end ';
  put ' ';
  put 'local function parse_object(str, i) ';
  put '  local res = {} ';
  put '  i = i + 1 ';
  put '  while 1 do ';
  put '    local key, val ';
  put '    i = next_char(str, i, space_chars, true) ';
  put '    -- Empty / end of object? ';
  put '    if str:sub(i, i) == "}" then ';
  put '      i = i + 1 ';
  put '      break ';
  put '    end ';
  put '    -- Read key ';
  put '    if str:sub(i, i) ~= ''"'' then ';
  put '      decode_error(str, i, "expected string for key") ';
  put '    end ';
  put '    key, i = parse(str, i) ';
  put '    -- Read '':'' delimiter ';
  put '    i = next_char(str, i, space_chars, true) ';
  put '    if str:sub(i, i) ~= ":" then ';
  put '      decode_error(str, i, "expected '':'' after key") ';
  put '    end ';
  put '    i = next_char(str, i + 1, space_chars, true) ';
  put '    -- Read value ';
  put '    val, i = parse(str, i) ';
  put '    -- Set ';
  put '    res[key] = val ';
  put '    -- Next token ';
  put '    i = next_char(str, i, space_chars, true) ';
  put '    local chr = str:sub(i, i) ';
  put '    i = i + 1 ';
  put '    if chr == "}" then break end ';
  put '    if chr ~= "," then decode_error(str, i, "expected ''}'' or '',''") end ';
  put '  end ';
  put '  return res, i ';
  put 'end ';
  put ' ';
  put 'local char_func_map = { ';
  put '  [ ''"'' ] = parse_string, ';
  put '  [ "0" ] = parse_number, ';
  put '  [ "1" ] = parse_number, ';
  put '  [ "2" ] = parse_number, ';
  put '  [ "3" ] = parse_number, ';
  put '  [ "4" ] = parse_number, ';
  put '  [ "5" ] = parse_number, ';
  put '  [ "6" ] = parse_number, ';
  put '  [ "7" ] = parse_number, ';
  put '  [ "8" ] = parse_number, ';
  put '  [ "9" ] = parse_number, ';
  put '  [ "-" ] = parse_number, ';
  put '  [ "t" ] = parse_literal, ';
  put '  [ "f" ] = parse_literal, ';
  put '  [ "n" ] = parse_literal, ';
  put '  [ "[" ] = parse_array, ';
  put '  [ "{" ] = parse_object, ';
  put '} ';
  put ' ';
  put 'parse = function(str, idx) ';
  put '  local chr = str:sub(idx, idx) ';
  put '  local f = char_func_map[chr] ';
  put '  if f then ';
  put '    return f(str, idx) ';
  put '  end ';
  put '  decode_error(str, idx, "unexpected character ''" .. chr .. "''") ';
  put 'end ';
  put ' ';
  put 'function json2sas.decode(str) ';
  put '  if type(str) ~= "string" then ';
  put '    error("expected argument of type string, got " .. type(str)) ';
  put '  end ';
  put '  local res, idx = parse(str, next_char(str, 1, space_chars, true)) ';
  put '  idx = next_char(str, idx, space_chars, true) ';
  put '  if idx <= #str then ';
  put '    decode_error(str, idx, "trailing garbage") ';
  put '  end ';
  put '  return res ';
  put 'end ';
  put ' ';
  put '-- convert macro variable array into one variable and decode ';
  put 'function json2sas.go(macvar) ';
  put '  local x=1 ';
  put '  local cnt=0 ';
  put '  local mac=sas.symget(macvar..''0'') ';
  put '  local newstr='''' ';
  put '  if mac and mac ~= '''' then ';
  put '    cnt=mac ';
  put '    for x=1,cnt,1 do ';
  put '      mac=sas.symget(macvar..x) ';
  put '      if mac and mac ~= '''' then ';
  put '        newstr=newstr..mac ';
  put '      else ';
  put '        return print(macvar..x..'' NOT FOUND!!'') ';
  put '      end ';
  put '    end ';
  put '  else ';
  put '    return print(macvar..''0 NOT FOUND!!'') ';
  put '  end ';
  put '  -- print(''mac:''..mac..''cnt:''..cnt..''newstr''..newstr) ';
  put '  local oneVar=json2sas.decode(newstr) ';
  put '  local jsdata=oneVar["data"] ';
  put '  local meta={} ';
  put '  local attrs={} ';
  put '  for tablename, data in pairs(jsdata) do -- each table ';
  put '    print("Processing table: "..tablename) ';
  put '    attrs[tablename]={} ';
  put '    for k, v in ipairs(data) do -- each row ';
  put '      if(k==1) then  -- column names ';
  put '        for a, b in pairs(v) do ';
  put '          attrs[tablename][a]={} ';
  put '          attrs[tablename][a]["name"]=b ';
  put '        end ';
  put '      elseif(k==2) then  -- get types ';
  put '        for a, b in pairs(v) do ';
  put '  	      if type(b)==''number'' then ';
  put '  	        attrs[tablename][a]["type"]="N" ';
  put '  	        attrs[tablename][a]["length"]=8 ';
  put '  	      else ';
  put '            attrs[tablename][a]["type"]="C" ';
  put '            attrs[tablename][a]["length"]=string.len(b) ';
  put '  	      end ';
  put '        end ';
  put '      else  --update lengths ';
  put '        for a, b in pairs(v) do ';
  put '          if (type(b)==''string'' and string.len(b)>attrs[tablename][a]["length"]) ';
  put '          then ';
  put '            attrs[tablename][a]["length"]=string.len(b) ';
  put '          end ';
  put '        end ';
  put '  	  end ';
  put '  	end ';
  put '    print(json2sas.encode(attrs[tablename])) -- show results ';
  put ' ';
  put '    -- Now create the SAS table ';
  put '    sas.new_table("work."..tablename,attrs[tablename]) ';
  put '    local dsid=sas.open("work."..tablename, "u") ';
  put '    for k, v in ipairs(data) do ';
  put '      if k>1 then ';
  put '        sas.append(dsid) ';
  put '        for a, b in pairs(v) do ';
  put '          sas.put_value(dsid, attrs[tablename][a]["name"], b) ';
  put '        end ';
  put '        sas.update(dsid) ';
  put '      end ';
  put '    end ';
  put '    sas.close(dsid) ';
  put '  end ';
  put '  return json2sas.decode(newstr) ';
  put 'end ';
  put ' ';
  put ' ';
  put 'function quote(str) ';
  put '  return sas.quote(str) ';
  put 'end ';
  put 'function sasvar(str) ';
  put '  print("processing: "..str) ';
  put '  print(sas.symexist(str)) ';
  put '  if sas.symexist(str)==1 then ';
  put '    return quote(str)..'':''..quote(sas.symget(str))..'','' ';
  put '  end ';
  put '  return '''' ';
  put 'end ';
  put ' ';
  put 'return json2sas ';
run;
%mend;
