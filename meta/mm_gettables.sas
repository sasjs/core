/**
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

%mend;