/*Useful Stata codes*/

**********************
* ADMIN
**********************

*Admin for the beginning of a do file
clear

*Change directory so Stata points at the folder you'd like to save your datasets in
cd "xxx"

*Set up log file to capture the results of running your do file in plain text
capture log close
log using "Filename_Date.log", replace
*At the end of your do file, repeat the "capture log close" command to close your log file
*Log files can be read in Notepad

set more off //so that Stata will run commands continuously without stopping for large tables

use "xxx" clear

*Make a data dictionary
describe, replace
export excel name varlab vallab using "Data Dictionary.xlsx", firstrow(variables) sheet("Data Dictionary") sheetmodify


*********************
* DATA CLEANING
*********************

*Labelling variables
label var xxx "xxx" //Naming variable
label define xyz 0 "x" 1 "y" 2 "z" //Creating list of values
label values var xyz //Applying list of values to variable

*Changing variable formats
*Converting from numeric to string using the labels for each category
foreach var of varlist Forename Surname radiographerComments additionalRadiologyNotes rq_traveldetails rq_conditionsotherdetails rq_healthcaredeptotherdetails rq_pedeptotherdetails rq_completedby rq_staffinitialscxr rq_additionalinfo {
decode `var', gen(`var'_st)
drop `var'
rename `var'_st `var'
}

*Removing all spaces
gen postcode_clean=subinstr(postcode," ","",.)


*********************
* COMBINING DATASETS - WORKED EXAMPLE
*********************

*Open 2018 TB annual report dataset
use "G:\TOPICS\TB\TB ENHANCED SURVEILLANCE PROJECTS\AnnualDatasets\2019\2018 TB datasets\TB annual report 2018 data v2 no denotified.dta", clear

*Append ETS dataset
*Append command adds data to the bottom (ie new rows to existing columns)
append using "ETSCaseDataDownload_residents Jan-Dec19 14Jan20.dta", force

*Merge NTBS enhanced line list dataset
*Merge command adds data to the side (ie new columns to existing rows)
*NB merge command keeps original var values and DOES NOT overwrite with values from "using" file
merge 1:1 id using "Enhanced Line List_residents Jan-Dec19 14Jan20.dta", force
*unmatched case 241409 no access on ETS so remove from analysis
*examine which records have and haven't merged correctly to identify any problems

save "xxx.dta", replace


********************
* DATES
********************

*Creating date variable from numeric variable
tostring rq_dateentryuk, gen(entry)
replace entry="" if rq_dateentryuk==.
replace entry="011959" if rq_dateentryuk==1959
gen entry2=date(entry, "MY")
format entry2 %td
drop rq_dateentryuk entry
rename entry2 rq_dateentryuk
label var rq_dateentryuk "RQ11 Date of entry to UK"

*Using specific dates/times without having to calculate days since 1jan1960
replace rq_dateofscreen=tc(16jan2020 00:00:00) if rq_dateofscreen==tc(15jan2012 00:00:00)

*Converting from stata time to stata date
*For other conversions look at SIF to SIF conversions in Stata help files
gen eventdate = dofc(eventtime)
format eventdate %td

********************
* MISSING VALUES
********************

*General command to set particular value to missing
*eg "Don't know"=.
foreach var of varlist rq_travelledoutsideuk rq_pasttb rq_preventerinhaler rq_hiv rq_smoketobacco rq_vapenicotine rq_illicitdrugs rq_continuousbasis rq_prisonoutsideuk rq_attendedhealthcare rq_religiousservices rq_counsellingvictimawareness rq_education rq_pedept rq_bcg rq_bcgscarseen rq_sputumresult {
mvdecode `var', mv(3=.)
}

*or
mvdecode _all, mv(-9 -99)


********************
* EXPORTING DATA
********************

*Putexcel
putexcel set "20200309 Analysis HMP The Mount.xlsx", sheet ("Description") modify 
count
putexcel B3=(r(N))
sleep 2000

*Export whole dataset (after collapse)
gen count=1
collapse (sum)count, by(Describes igraResult_cat2)
reshape wide count, i(igraResult_cat2) j(Describes)
rename count1 res
rename count2 staff
gen total=res+staff
export excel total using "20200309 Analysis HMP The Mount.xlsx", sheet("Description") sheetmodify cell (J3)
sleep 2000

********************
* LOOPING COMMANDS
********************

foreach var of varlist rq_ethnicOrigin rq_otherorigin rq_countryofbirth {
replace rq=1 if `var'!=.
}


*****************************************
* DESCRIPTIVE ANALYSIS - CONTINUOUS VARS
*****************************************

hist age_yrs if Describes==1, by(igra_binary)
qnorm age_yrs if Describes==1
graph box age_yrs if Describes==1, over(igra_binary)
summ age_yrs if Describes==1
summ age_yrs if Describes==1 & igra_binary==0
summ age_yrs if Describes==1 & igra_binary==1
*ttest (if normally distributed)
ttest age_yrs, by(igra_binary)
*wilcoxon rank-sum test for age (if non-normally distributed)
ranksum age_yrs, by(igra_binary)


*****************************************
* DESCRIPTIVE ANALYSIS - CATEGORICAL VARS
*****************************************

tab1 gp - nhsone


*****************************************
* UNIVARIATE ANALYSIS - CATEGORICAL VARS
*****************************************

* food v1 (1 = eat any)

*Note: 
* if values in the 2x2 expected table are <5 use fishers exact test to derive p-values
* if values in the 2x2 expected table are >=5  use chi-squared test to derive p-values
* to find values in the 2x2 expected table (and therefore decide the appropriate test)
* either use the ,exp command (as below) or alternatively use the expected.table.checker.xlsx 
* excel sheet 

foreach v of var oysters01v1 - caramel01v1 prosecco- stillwater{
tab case `v', exp
}

* Risk Ratios
cstable case oysters01v1 - caramel01v1 prosecco- stillwater, exact
cstable case oysters01v1 - caramel01v1 prosecco- stillwater

* Odds Ratios (also useful for determining proportion of cases explained by given exposure)
cctable case oysters01v1 - caramel01v1 prosecco- stillwater, exact
cctable case oysters01v1 - caramel01v1 prosecco- stillwater

* food v2 (1 = eat a portion or more ) 
cstable case oysters01v2 - caramel01v2

* Note:
* if in the 2x2 table there is a 0 value cell, can use exact logistic regression 
* to derive point estimate/confidence interval
* the original p-value should be used from the either the cstable/cctable command
* NOTE - getting error RE: collinear variables
exlogistic case caramel01v2, nolog

********************
*Stratified analysis
********************

* to investigate potential confounding and effect modification
csinter case ketchup01v1, by (sausage01v1)


********************
*Dose response 
********************

* using logistic regression
* using dummy variables to represent each level of oyster consumption 
* eating no oysters taken as the baseline
tab oysters case
xi:logistic case i.oysters

* using alternative baseline level as the baseline
char oysters[omit] 1
xi:logistic case i.oysters

* using poisson regression
tab lemonwedge case
xi:poisson case i.lemonwedge, irr

********************
*Multivariable analysis 
********************
*Use poisson (robust) if response rate is 'high' and logistic/glm if response rate is not as high. 
*Odds Ratios give a more accurate estimate when there is likely different sampling ratios between case and non-cases, 
*which is the case when response rate is 'low'. If unsure, refine model using both approaches (RR and OR) and if they tell the same story then report RRs; 
*if they tell a different story then report ORs

* create new age variables to determine which best fits the data. Investigate age first.

gen age2 = age^2
gen age3 = age^3

* Use likelihood ratio test to identify factors to consider dropping; only drop if the point estimates change by 20% or more
* when variable of interest has been removed (in comparison to model that includes variable of interest). Must also be driven by missing data when
* review how much data is missing when deciding which variable to drop (unless all exposure questions are mandatory).
* When dropping variables and make the comparison in point estimates between models base don the same numbers, which can be achieved by using an inline 
* if statement 'if [variable dropped]<.'

fitint logit case age age2 age3 sex oysters01v1 lemonwedge01v1

fitint logit case age age2 sex oysters01v1 lemonwedge01v1

fitint logit case age sex oysters01v1 lemonwedge01v1

fitint logit case age sex oysters01v1 

* use exact logistic regression when there cells with 0 value
*exlogistic case oysters01v1 , condvars (age sex) 

*Stop refining model when there are a sufficient number of observations per variable (or level if categorical variables included), i.e. approx 10 obs per
*level/variable. Perfectly fine that not all variables in teh reported model make a 'significant difference' to the mdoel if they were removed (base don p val)

* other alternatives include logit or glm  commands (or robust poisson/neg binomial if reporting RRs)
logistic case age sex oysters01v1 lemonwedge01v1
glm case  age sex oysters01v1 lemonwedge01v1, eform fam(bin) asis



foreach var of varlist rq_symptomsweightloss rq_symptomsfatigue rq_symptomsnightsweats rq_symptomslossofappetite rq_symptomscough rq_symptomscoughingupmaterial rq_symptomscoughedupbloodever rq_symptomsnoneofabove rq_symptomsany {
tab `var' igra_binary
meglm igra_binary `var' ||wingName: ||describesWingLanding:,fam(bin) eform asis
est store a
meglm igra_binary if `var'<. ||wingName: ||describesWingLanding:,fam(bin) eform asis
est store b
lrtest a b
}

summ rq_pedeptavg if igra_binary==0, d
summ rq_pedeptavg if igra_binary==1, d

gen pe2=rq_pedeptavg^2
label var pe2 "Avg monthly gym attendance squared"
gen pe3=rq_pedeptavg^3
label var pe3 "Avg monthly gym attendance cubed"

meglm igra_binary rq_pedeptavg pe2 pe3 ||wingName: ||describesWingLanding:,fam(bin) eform
est store a
meglm igra_binary rq_pedeptavg pe2 ||wingName: ||describesWingLanding:,fam(bin) eform
est store b
lrtest a b
//p=0.0068 - cubic function explains sig more variation than quadratic function


