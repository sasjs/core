/**
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
%mend;