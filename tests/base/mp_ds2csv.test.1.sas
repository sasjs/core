/**
  @file
  @brief Testing mp_ds2csv.sas macro

  <h4> SAS Macros </h4>
  @li mp_ds2csv.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

data work.somedata;
  x=1;
  y='  t"w"o';
  z=.z;
  label x='x factor';
run;

/**
  * Test 1 - default CSV
  */
%mp_assertscope(SNAPSHOT)
%mp_ds2csv(work.somedata,outfile="&sasjswork/test1.csv")
%mp_assertscope(COMPARE)

%let test1b=FAIL;
data _null_;
  infile "&sasjswork/test1.csv";
  input;
  list;
  if _n_=1 then call symputx('test1a',_infile_);
  else if _infile_=:'1,"  t""w""o",.Z' then call symputx('test1b','PASS');
run;

%mp_assert(
  iftrue=("&test1a"="x factor, Y, Z"),
  desc=Checking header row Test 1,
  outds=work.test_results
)
%mp_assert(
  iftrue=("&test1b"="PASS"),
  desc=Checking data row Test 1,
  outds=work.test_results
)

/**
  * Test 2 - NAME header with fileref and semicolons
  */
filename test2 "&sasjswork/test2.csv";
%mp_ds2csv(work.somedata,outref=test2,dlm=SEMICOLON,headerformat=NAME)

%let test2b=FAIL;
data _null_;
  infile test2;
  input;
  list;
  if _n_=1 then call symputx('test2a',_infile_);
  else if _infile_=:'1;"  t""w""o";.Z' then call symputx('test2b','PASS');
run;

%mp_assert(
  iftrue=("&test2a"="X; Y; Z"),
  desc=Checking header row Test 2,
  outds=work.test_results
)
%mp_assert(
  iftrue=("&test2b"="PASS"),
  desc=Checking data row Test 2,
  outds=work.test_results
)

/**
  * Test 3 - SASjs format
  */
filename test3 "&sasjswork/test3.csv";
%mp_ds2csv(work.somedata,outref=test3,headerformat=SASJS)

%let test3b=FAIL;
data _null_;
  infile test3;
  input;
  list;
  if _n_=1 then call symputx('test3a',_infile_);
  else if _infile_=:'1,"  t""w""o",.Z' then call symputx('test3b','PASS');
run;

%mp_assert(
  iftrue=("&test3a"="X:best32. Y:$char7. Z:best32."),
  desc=Checking header row Test 3,
  outds=work.test_results
)
%mp_assert(
  iftrue=("&test3b"="PASS"),
  desc=Checking data row Test 3,
  outds=work.test_results
)

/* test 4 - sasjs with compare */
data work.baseball ;
attrib
Name                             length= $18 label="Player's Name"
Team                             length= $14 label="Team at the End of 1986"
nAtBat                           length= 8 label="Times at Bat in 1986"
nHits                            length= 8 label="Hits in 1986"
nHome                            length= 8 label="Home Runs in 1986"
nRuns                            length= 8 label="Runs in 1986"
nRBI                             length= 8 label="RBIs in 1986"
nBB                              length= 8 label="Walks in 1986"
YrMajor                          length= 8 label="Years in the Major Leagues"
CrAtBat                          length= 8 label="Career Times at Bat"
CrHits                           length= 8 label="Career Hits"
CrHome                           length= 8 label="Career Home Runs"
CrRuns                           length= 8 label="Career Runs"
CrRbi                            length= 8 label="Career RBIs"
CrBB                             length= 8 label="Career Walks"
League                           length= $8 label="League at the End of 1986"
Division                         length= $8 label="Division at the End of 1986"
Position                         length= $8 label="Position(s) in 1986"
nOuts                            length= 8 label="Put Outs in 1986"
nAssts                           length= 8 label="Assists in 1986"
nError                           length= 8 label="Errors in 1986"
Salary                           length= 8 label="1987 Salary in $ Thousands"
Div                              length= $16 label="League and Division"
logSalary                        length= 8 label="Log Salary"
;
infile cards dsd;
input
  Name                             :$char.
  Team                             :$char.
  nAtBat
  nHits
  nHome
  nRuns
  nRBI
  nBB
  YrMajor
  CrAtBat
  CrHits
  CrHome
  CrRuns
  CrRbi
  CrBB
  League                           :$char.
  Division                         :$char.
  Position                         :$char.
  nOuts
  nAssts
  nError
  Salary
  Div                              :$char.
  logSalary
;
missing a b c d e f g h i j k l m n o p q r s t u v w x y z _;
/* fix precision issues */
if not missing(logSalary) then logsalary=logSalary*1;
datalines4;
"Allanson, Andy",Cleveland,293,66,1,30,29,14,1,293,66,1,30,29,14,American,East,C,446,33,20,.,AE,.
"Ashby, Alan",Houston,315,81,7,24,38,39,14,3449,835,69,321,414,375,National,West,C,632,43,10,475,NW,6.16331480403464
"Davis, Alan",Seattle,479,130,18,66,72,76,3,1624,457,63,224,266,263,American,West,1B,880,82,14,480,AW,6.17378610390193
"Dawson, Andre",Montreal,496,141,20,65,78,37,11,5628,1575,225,828,838,354,National,East,RF,200,11,3,500,NE,6.21460809842219
"Galarraga, Andres",Montreal,321,87,10,39,42,30,2,396,101,12,48,46,33,National,East,1B,805,40,4,91.5,NE,4.51633897228147
"Griffin, Alfredo",Oakland,594,169,4,74,51,35,11,4408,1133,19,501,336,194,American,West,SS,282,421,25,750,AW,6.62007320653035
"Newman, Al",Montreal,185,37,1,23,8,21,2,214,42,1,30,9,24,National,East,2B,76,127,7,70,NE,4.24849524204936
"Salazar, Argenis",Kansas City,298,73,0,24,24,7,3,509,108,0,41,37,12,American,West,SS,121,283,9,100,AW,4.60517018598809
"Thomas, Andres",Atlanta,323,81,6,26,32,8,2,341,86,6,32,34,8,National,West,SS,143,290,19,75,NW,4.31748811353631
"Thornton, Andre",Cleveland,401,92,17,49,66,65,13,5206,1332,253,784,890,866,American,East,DH,0,0,0,1100,AE,7.00306545878646
"Trammell, Alan",Detroit,574,159,21,107,75,59,10,4631,1300,90,702,504,488,American,East,SS,238,445,22,517.143,AE,6.24831943200756
"Trevino, Alex",Los Angeles,202,53,4,31,26,27,9,1876,467,15,192,186,161,National,West,C,304,45,11,512.5,NW,6.23930071101256
"Van Slyke, Andy",St Louis,418,113,13,48,61,47,4,1512,392,41,205,204,203,National,East,RF,211,11,7,550,NE,6.30991827822651
"Wiggins, Alan",Baltimore,239,60,0,30,11,22,6,1941,510,4,309,103,207,American,East,2B,121,151,6,700,AE,6.5510803350434
"Almon, Bill",Pittsburgh,196,43,7,29,27,30,13,3231,825,36,376,290,238,National,East,UT,80,45,8,240,NE,5.48063892334199
"Beane, Billy",Minneapolis,183,39,3,20,15,11,3,201,42,3,20,16,11,American,West,OF,118,0,0,.,AW,.
"Bell, Buddy",Cincinnati,568,158,20,89,75,73,15,8068,2273,177,1045,993,732,National,West,3B,105,290,10,775,NW,6.65286302935334
"Biancalana, Buddy",Kansas City,190,46,2,24,8,15,5,479,102,5,65,23,39,American,West,SS,102,177,16,175,AW,5.16478597392351
"Bochte, Bruce",Oakland,407,104,6,57,43,65,12,5233,1478,100,643,658,653,American,West,1B,912,88,9,.,AW,.
;;;;
run;
filename example temp lrecl=5000;
%mp_ds2csv(work.baseball,outref=example,headerformat=SASJS)
data _null_; infile example; input;put _infile_; if _n_>5 then stop;run;

data _null_;
  infile example;
  input;
  call symputx('stmnt',_infile_);
  stop;
run;
data work.want;
  infile example dsd firstobs=2;
  input &stmnt;
run;

%mp_assert(
  iftrue=(&syscc =0),
  desc=Checking syscc prior to compare of work.baseball,
  outds=work.test_results
)

proc compare base=want compare=work.baseball
  method = absolute criterion = 0.0000000001   ;
run;
%mp_assert(
  iftrue=(&sysinfo le 41),
  desc=Checking compare of work.baseball,
  outds=work.test_results
)

/* test 5 - sasjs with time/datetime/date */
filename f2 temp;
data work.test5;
  do x=1 to 5;
    y=x;
    z=x;
  end;
  format x date9. y datetime19. z time.;
run;
%mp_ds2csv(work.test5,outref=f2,headerformat=SASJS)
data _null_; infile example; input;put _infile_; if _n_>5 then stop;run;

data _null_;
  infile f2;
  input;
  putlog _infile_;
  call symputx('stmnt2',_infile_);
  stop;
run;
data work.want5;
  infile f2 dsd firstobs=2;
  input &stmnt2;
  putlog _infile_;
run;

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking syscc prior to compare of test5,
  outds=work.test_results
)

proc compare base=want5 compare=work.test5;
run;
%mp_assert(
  iftrue=(&sysinfo le 41),
  desc=Checking compare of work.test5,
  outds=work.test_results
)

