/**
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

  <h4> SAS Macros </h4>
  @li mf_getengine.sas
  @li mp_abort.sas

  @param [in] libref the libref (not name) of the metadata library
  @param [in] open_passthrough= () Provide an alias to produce the CONNECT TO
    statement for the relevant external database
  @param [in] sql_options= () Add any options to add to proc sql statement,
    eg outobs= (only valid for pass through)
  @param [in] mDebug= (0) set to 1 to show debug messages in the log
  @param [in] mAbort= (0) set to 1 to call %mp_abort().

  @returns libname statement

  @version 9.2
  @author Allan Bowe

**/

%macro mm_assigndirectlib(
    libref
    ,open_passthrough=
    ,sql_options=
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
    length rcCon rcProp rc k 3 uriCon uriProp PropertyValue PropertyName
      Delimiter $256 properties $2048;
    retain properties;
    rcCon = metadata_getnasn("&liburi", "LibraryConnection", 1, uriCon);

    rcProp = metadata_getnasn(uriCon, "Properties", 1, uriProp);

    k = 1;
    rcProp = metadata_getnasn(uriCon, "Properties", k, uriProp);
    do while (rcProp > 0);
      rc = metadata_getattr(uriProp , "DefaultValue",PropertyValue);
      rc = metadata_getattr(uriProp , "PropertyName",PropertyName);
      rc = metadata_getattr(uriProp , "Delimiter",Delimiter);
      properties = trim(properties) !! " " !! trim(PropertyName)
        !! trim(Delimiter) !! trim(PropertyValue);
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
      else if value='Connection.OLE.Property.PROPERTIES.Name.xmlKey.txt' then
      do;
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
    length connx_uri conprop_uri value datasource up_uri schema domprop_uri authdomain $256.;
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

    /* get auth domain */
    autrc=metadata_getnasn(connx_uri,"Domain",1,domprop_uri);
    arc=metadata_getattr(domprop_uri,"Name",authdomain);
    if not missing(authdomain) then authdomain=cats('AUTHDOMAIN=',authdomain);
    call symputx('authdomain',authdomain,'l');

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
    libname &libref ODBC DATASRC=&sql_dsn SCHEMA=&sql_schema &authdomain;
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
    if server^='' then server='server='!!quote(cats(server));
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
    %put %str(WARN)ING: Passthrough option for postgres not yet supported;
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
    rc=metadata_getprop(assocuri1,
      'Connection.Oracle.Property.PATH.Name.xmlKey.txt',path);
    call symputx('path',path,'l');

    /* schema */
    rc=metadata_getnasn("&liburi",'UsingPackages',1,assocuri3);
    rc=metadata_getattr(assocuri3,'SchemaName',schema);
    call symputx('schema',schema,'l');
  run;
  %put NOTE: Executing the following:/; %put NOTE-;
  %put NOTE- libname &libref ORACLE path=&path schema=&schema;
  %put NOTE-     authdomain=&authdomain;
  %put NOTE-;
  libname &libref ORACLE path=&path schema=&schema authdomain=&authdomain;
%end;
%else %if &engine=SQLSVR %then %do;
  %put NOTE: Obtaining &engine library details;
  data _null;
    length assocuri1 assocuri2 assocuri3 authdomain path schema userid
      passwd $256;
    call missing (of _all_);

    rc=metadata_getnasn("&liburi",'DefaultLogin',1,assocuri1);
    rc=metadata_getattr(assocuri1,"UserID",userid);
    rc=metadata_getattr(assocuri1,"Password",passwd);
    call symputx('user',userid,'l');
    call symputx('pass',passwd,'l');

    /* path */
    rc=metadata_getnasn("&liburi",'LibraryConnection',1,assocuri2);
    rc=metadata_getprop(assocuri2,
      'Connection.SQL.Property.Datasrc.Name.xmlKey.txt',path);
    call symputx('path',path,'l');

    /* schema */
    rc=metadata_getnasn("&liburi",'UsingPackages',1,assocuri3);
    rc=metadata_getattr(assocuri3,'SchemaName',schema);
    call symputx('schema',schema,'l');
  run;

  %put NOTE: Executing the following:/; %put NOTE-;
  %put NOTE- libname &libref SQLSVR datasrc=&path schema=&schema ;
  %put NOTE-    user="&user" pass="XXX";
  %put NOTE-;

  libname &libref SQLSVR datasrc=&path schema=&schema user="&user" pass="&pass";
%end;
%else %if &engine=TERADATA %then %do;
  %put NOTE: Obtaining &engine library details;
  data _null;
    length assocuri1 assocuri2 assocuri3 authdomain path schema userid
      passwd $256;
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
    rc=metadata_getprop(assocuri2,
      'Connection.Teradata.Property.SERVER.Name.xmlKey.txt',path);
    call symputx('path',path,'l');

    /* schema */
    rc=metadata_getnasn("&liburi",'UsingPackages',1,assocuri3);
    rc=metadata_getattr(assocuri3,'SchemaName',schema);
    call symputx('schema',schema,'l');
  run;

  %put NOTE: Executing the following:/; %put NOTE-;
  %put NOTE- libname &libref TERADATA server="&path" schema=&schema ;
  %put NOTe-   authdomain=&authdomain;
  %put NOTE-;

  libname &libref TERADATA server="&path" schema=&schema authdomain=&authdomain;
%end;
%else %if &engine= %then %do;
  %put NOTE: Libref &libref is not registered in metadata;
  %&mAbort.mp_abort(
    msg=%str(ERR)OR: Libref &libref is not registered in metadata
    ,mac=mm_assigndirectlib.sas);
  %return;
%end;
%else %do;
  %put %str(WARN)ING: Engine &engine is currently unsupported;
  %put %str(WARN)ING- Please contact your support team.;
  %return;
%end;

%mend mm_assigndirectlib;
