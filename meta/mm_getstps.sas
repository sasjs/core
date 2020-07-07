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
  @showDesc= provide a non blank value to return stored process descriptions
  @showUsageVersion= provide a non blank value to return the UsageVersion.  This
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
