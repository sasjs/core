/**
  @file mp_runddl.sas
  @brief An opinionated way to execute DDL files in SAS.
  @details When delivering projects there should be seperation between the DDL
    used to generate the tables and the sample data used to populate them.

  This macro expects certain folder structure - eg:

    rootlib
    |-- LIBREF1
    |   |__ mytable.ddl
    |   |__ someothertable.ddl
    |-- LIBREF2
    |   |__ table1.ddl
    |   |__ table2.ddl
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



%mend mp_runddl;