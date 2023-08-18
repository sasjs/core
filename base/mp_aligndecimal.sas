/**
  @file
  @brief Apply leading blanks to align numbers vertically in a char variable
  @details This is particularly useful when storing numbers (as character) that
  need to be sorted.

  It works by splitting the number left and right of the decimal place, and
  aligning it accordingly.  A temporary variable is created as part of this
  process (which is automatically dropped)

  The macro can be used only in data step, eg as follows:

      data _null_;
        length myvar $50;
        do i=1 to 1000 by 50;
          if mod(i,2)=0 then j=ranuni(0)*i*100;
          else j=i*100;

          %mp_aligndecimal(myvar,width=7)

          leading_spaces=length(myvar)-length(cats(myvar));
          putlog +leading_spaces myvar;
        end;
      run;

  The generated code will look something like this:

      length aligndp4e49996 $7;
      if index(myvar,'.') then do;
        aligndp4e49996=cats(scan(myvar,1,'.'));
        aligndp4e49996=right(aligndp4e49996);
        myvar=aligndp4e49996!!'.'!!cats(scan(myvar,2,'.'));
      end;
      else do;
        aligndp4e49996=myvar;
        aligndp4e49996=right(aligndp4e49996);
        myvar=aligndp4e49996;
      end;
      drop aligndp4e49996;

  Results (myvar variable):

                0.7683559324
              122.8232796
            99419.50552
            42938.5143414
              763.3799189
            15170.606073
            15083.285773
            85443.198707
          2022999.2251
            12038.658867
          1350582.6734
            52777.258221
            11723.347628
            33101.268376
          6181622.8603
          7390614.0669
            73384.537893
          1788362.1016
          2774586.2219
          7998580.8415


  @param [in] var The (data step, character) variable to modify
  @param [in] width= (8) The number of characters BEFORE the decimal point

  <h4> SAS Macros </h4>
  @li mf_getuniquename.sas

  <h4> Related Programs </h4>
  @li mp_aligndecimal.test.sas

  @version 9.2
  @author Allan Bowe
**/

%macro mp_aligndecimal(var,width=8);

  %local tmpvar;
  %let tmpvar=%mf_getuniquename(prefix=aligndp);
  length &tmpvar $&width;
  if index(&var,'.') then do;
    &tmpvar=cats(scan(&var,1,'.'));
    &tmpvar=right(&tmpvar);
    &var=&tmpvar!!'.'!!cats(scan(&var,2,'.'));
  end;
  else do;
    &tmpvar=cats(&var);
    &tmpvar=right(&tmpvar);
    &var=&tmpvar;
  end;
  drop &tmpvar;

%mend mp_aligndecimal;
