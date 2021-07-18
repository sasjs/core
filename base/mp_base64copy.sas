/**
  @file
  @brief Convert a file to/from base64 format
  @details Creates a new version of a file either encoded or decoded using
  Base64.  Inspired by this post by Michael Dixon:
  https://support.selerity.com.au/hc/en-us/articles/223345708-Tip-SAS-and-Base64

  Usage:

        filename tmp temp;
        data _null_;
          file tmp;
          put 'base ik ally';
        run;
        %mp_base64copy(inref=tmp, outref=myref, action=ENCODE)

        data _null_;
          infile myref;
          input;
          put _infile_;
        run;

        %mp_base64copy(inref=myref, outref=mynewref, action=DECODE)

        data _null_;
          infile mynewref;
          input;
          put _infile_;
        run;

  @param [in] inref= Fileref of the input file (should exist)
  @param [out] outref= Output fileref. If it does not exist, it is created.
  @param [in] action= (ENCODE) The action to take. Valid values:
    @li ENCODE - Convert the file to base64 format
    @li DECODE - Decode the file from base64 format

  @version 9.2
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> SAS Macros </h4>
  @li mp_abort.sas


**/

%macro mp_base64copy(
  inref=0,
  outref=0,
  action=ENCODE
)/*/STORE SOURCE*/;

%let inref=%upcase(&inref);
%let outref=%upcase(&outref);
%let action=%upcase(&action);
%local infound outfound;
%let infound=0;
%let outfound=0;
data _null_;
  set sashelp.vextfl(where=(fileref="&inref" or fileref="&outref"));
  if fileref="&inref" then call symputx('infound',1,'l');
  if fileref="&outref" then call symputx('outfound',1,'l');
run;

%mp_abort(iftrue= (&infound=0)
  ,mac=&sysmacroname
  ,msg=%str(INREF &inref NOT FOUND!)
)
%mp_abort(iftrue= (&outref=0)
  ,mac=&sysmacroname
  ,msg=%str(OUTREF NOT PROVIDED!)
)
%mp_abort(iftrue= (&action ne ENCODE and &action ne DECODE)
  ,mac=&sysmacroname
  ,msg=%str(Invalid action! Should be ENCODE OR DECODE)
)

%if &outfound=0 %then %do;
  filename &outref temp lrecl=2097088;
%end;

%if &action=ENCODE %then %do;
  data _null_;
    length b64 $ 76 line $ 57;
    retain line "";
    infile &inref recfm=F lrecl= 1 end=eof;
    input @1 stream $char1.;
    file &outref recfm=N;
    substr(line,(_N_-(CEIL(_N_/57)-1)*57),1) = byte(rank(stream));
    if mod(_N_,57)=0 or EOF then do;
      if eof then b64=put(trim(line),$base64X76.);
      else b64=put(line, $base64X76.);
      put b64 + (-1) @;
      line="";
    end;
  run;
%end;
%else %if &action=DECODE %then %do;
  data _null_;
    length filein 8 fileout 8;
    filein = fopen("&inref",'I',4,'B');
    fileout = fopen("&outref",'O',3,'B');
    char= '20'x;
    do while(fread(filein)=0);
      length raw $4;
      do i=1 to 4;
        rc=fget(filein,char,1);
        substr(raw,i,1)=char;
      end;
      rc = fput(fileout,input(raw,$base64X4.));
      rc = fwrite(fileout);
    end;
    rc = fclose(filein);
    rc = fclose(fileout);
  run;
%end;

%mend mp_base64copy;