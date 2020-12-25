/**
  @file mm_deletedocument.sas
  @brief Deletes a Document using path as reference
  @details

  Usage:

    %mm_createdocument(tree=/User Folders/&sysuserid,name=MyNote)
    %mm_deletedocument(target=/User Folders/&sysuserid/MyNote)

  <h4> SAS Macros </h4>

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
