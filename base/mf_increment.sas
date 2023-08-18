/**
  @file
  @brief Increments a macro variable
  @details Useful outside of do-loops - will increment a macro variable every
  time it is called.

  Example:

      %let cnt=1;
      %put We have run %mf_increment(cnt) lines;
      %put Now we have run %mf_increment(cnt) lines;
      %put There are %mf_increment(cnt) lines in total;

  @param [in] macro_name The name of the macro variable to increment
  @param [in] incr= (1) The amount to add or subtract to the macro

  <h4> Related Files </h4>
  @li mf_increment.test.sas

**/

%macro mf_increment(macro_name,incr=1);

  /* iterate the value */
  %let &macro_name=%eval(&&&macro_name+&incr);
  /* return the value */
  &&&macro_name

%mend mf_increment;
