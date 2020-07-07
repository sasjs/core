/**
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
%mend;