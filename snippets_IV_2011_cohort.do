********************************************************************************
* IV analysis of General FE attendance: code snippets
* Min Zhang, Centre for Employment Research, University of Westminster
* Shared after the ADR England "Youth Transitions" LEO workshop (22 Oct 2026)
*
* WHAT THIS IS
*   Extracts from the analysis do-file used for the Nuffield-funded study of
*   post-16 pathways for young people who missed grade C (4) in GCSE English
*   and/or maths (2011 KS4 cohort, LEO Iteration 2, ONS Secure Research Service).
*   They show the logic, not a complete pipeline: earlier steps that build the
*   input files (SQL extracts, choice sets, qualifications) are not included.
*
* INPUTS (built earlier in the project; names are illustrative)
*   ${data}/2011_outcomes.dta      one row per person: LEO outcomes at a given
*                                  age, from Datalab's metrics tables
*   ${data}/2011_choice_sets.dta   one row per person: distance (metres) to the
*                                  nearest General FE college in their choice
*                                  set, attended_gen_fe (treatment), dest_type,
*                                  msoa_id
*   ${data}/2011_qualifications_age19.dta   highest qualification by age 19
*   ${data}/analysis_demographics.dta       prior attainment, FSM, SEN, etc.
*   ${data}/msoa_urban_lookup.dta           2011 rural-urban class of the MSOA
*   ${data}/household_income_msoa2018.dta   MSOA household income decile
*
* DEPENDENCIES
*   ssc install ivreg2
*   ssc install ranktest      // required by ivreg2
*   ssc install estout        // esttab
*
* CHANGES FROM THE ANALYSIS DO-FILE (for transparency)
*   - Paths replaced by ${data}/${output}; logging and exploratory lines removed.
*   - One urban/rural definition (urban2) for the rural and urban subsamples;
*     one distance cut-off (${maxdist}) used throughout.
*   - Only the models reported in the final report are kept: OLS, IV, IV rural,
*     IV urban. The do-file also ran comparison-group and mainstream-only models.
*   - The subgroup loop is the outer loop, so each subgroup's tables are
*     written and cleared before the next (Stata holds at most 300 stored
*     estimates). PLEASE TEST-RUN THIS VERSION BEFORE RELYING ON IT.
********************************************************************************

version 17
global maxdist 25        // km: keep young people within 25 km of their nearest GFE


********************************************************************************
* 1. Build the analysis sample
********************************************************************************
use "${data}/2011_outcomes.dta", clear
keep if age == 24                    // outcome age

* Choice sets: built only for young people without A*-C in both English and
* maths, so merging keeps that group. This is the _pup4 version of the choice
* sets (providers with fewer than 4 such pupils dropped in the choice-set step).
merge m:1 pupil_id using "${data}/2011_choice_sets.dta", keep(3) nogen

merge m:1 msoa_id  using "${data}/household_income_msoa2018.dta", keepusing(hhinc_dec) keep(1 3) nogen
merge m:1 msoa_id  using "${data}/msoa_urban_lookup.dta", keep(3) nogen
merge m:1 pupil_id using "${data}/2011_qualifications_age19.dta", keep(3) nogen
merge m:1 pupil_id using "${data}/analysis_demographics.dta", keep(3) nogen

* Rural-urban classification 2011 (MSOA)
* urban2: urban = A1, B1, C1 (major conurbation, minor conurbation, city and town)
gen urban2 = 0 if ru11cd != ""
replace urban2 = 1 if inlist(ru11cd, "A1", "B1", "C1")

* Four-way version used as a control
gen urbrural = .
replace urbrural = 1 if inlist(ru11cd, "A1", "B1")
replace urbrural = 2 if inlist(ru11cd, "C1", "C2")
replace urbrural = 3 if inlist(ru11cd, "D1", "D2")
replace urbrural = 4 if inlist(ru11cd, "E1", "E2")
lab def urbrural 1 "A1/B1" 2 "C1/C2" 3 "D1/D2" 4 "E1/E2"
lab val urbrural urbrural

* Region dummies (reg1 = East is the reference)
tab region, gen(reg)

* Instrument: distance in km, plus log and banded versions (the first-stage
* relationship is not linear, so these were tried as alternatives)
gen dist_km    = distance/1000
gen ln_dist_km = ln(dist_km)
egen dist_cut   = cut(dist_km), group(5)
egen dist_cut10 = cut(dist_km), group(10)

* Area disadvantage: share of ever-FSM pupils in the MSOA
bys msoa_id: gen  tot     = _N
bys msoa_id: egen tot_fsm = total(ever_fsm)
gen pctfsm = tot_fsm/tot

* Earnings per day: implausible values set to missing
* (kept if at least 10 pounds a day and no more than the mean + 3 SD)
su earnings_per_day_2015
gen earning_range = earnings_per_day_2015 >= 10 & earnings_per_day_2015 <= r(mean) + 3*r(sd)
gen lnpayd2015 = ln(earnings_per_day_2015) if earning_range == 1

* Education outcomes
gen l3    = (highest_qual_lev >= 3) if highest_qual_lev < .       // Level 3 by 19
gen atthe = (days_in_higher_education > 0 & days_in_higher_education < .)

* Short names (stored-estimate names have a length limit)
clonevar attfe   = attended_gen_fe      // treatment: in GFE in October at 17
clonevar hasemp  = has_employment
clonevar daysoutb = days_on_out_of_work_benefits

* Sample restrictions
keep if attrition == 0                  // flag supplied with the Datalab outcomes
keep if good_e_and_m == 0               // missed grade C in English and/or maths

* Subgroups by GCSE grades in English and maths
gen at_least_one_D = inlist(ks4_group, 2, 4, 5, 6, 8)


********************************************************************************
* 2. A first look at the instrument
********************************************************************************
global controls1 "zks2 zks3 ever_sen ever_fsm female reg2-reg9 i.urbrural ib1.ethn5 hhinc_dec pctfsm"

* Distance and GFE attendance: linear, log and banded
reg attfe dist_km      if dist_km < ${maxdist}, robust
reg attfe ln_dist_km   if dist_km < ${maxdist}, robust
reg attfe i.dist_cut   if dist_km < ${maxdist}, robust
lpoly attfe dist_km if dist_km < ${maxdist} & urban2 == 0, noscatter bw(1)   // rural
lpoly attfe dist_km if dist_km < ${maxdist} & urban2 == 1, noscatter bw(1)   // urban

* Wald estimator: (outcome on instrument) / (treatment on instrument)
* equals the 2SLS coefficient
reg hasemp dist_km $controls1 if dist_km < ${maxdist}, robust     // reduced form
reg attfe  dist_km $controls1 if dist_km < ${maxdist}, robust     // first stage
ivregress 2sls hasemp (attfe = dist_km) $controls1 if dist_km < ${maxdist}, first vce(robust)


********************************************************************************
* 3. Main models: for each subgroup, run every outcome, then save the tables
********************************************************************************
global eduout "ks4_level2 l3 atthe"
global labout "lnpayd2015 hasemp daysoutb"     // run separately: swap in below

* esttab options (second stage; first stage adds nobase)
global spec2nd `"replace cells("b(star fmt(3)) se(fmt(3)) p(fmt(3))") label mtitle("KS4 Level 2" "Level 3 by 19" "HE attendance")"'
global spec1st `"replace cells("b(star fmt(3)) se(fmt(3)) p(fmt(3))") label nobase mtitle("KS4 Level 2" "Level 3 by 19" "HE attendance")"'

estimates clear
putexcel set "${output}/F_stat_IV.xlsx", replace     // first-stage F, all subgroups
local p = 1

forvalues i = 0/3 {

    * subgroup switch: sets the condition and the output folder for this pass
    if `i' == 0 {
        local cond ""
        global outdir "${output}/everyone"
    }
    if `i' == 1 {
        local cond "& hard_fail == 1"         // E, F or G in both
        global outdir "${output}/EFG"
    }
    if `i' == 2 {
        local cond "& soft_fail == 1"         // two Ds
        global outdir "${output}/two_Ds"
    }
    if `i' == 3 {
        local cond "& at_least_one_D == 1"    // at least one D
        global outdir "${output}/at_least_one_D"
    }
    capture mkdir "${outdir}"

    foreach v of varlist $eduout {

        * OLS
        reg `v' attfe $controls1 if dist_km < ${maxdist} `cond', robust
        est sto ols_`v'

        * 2SLS: distance to the nearest GFE instruments GFE attendance
        ivreg2 `v' (attfe = dist_km) $controls1 if dist_km < ${maxdist} `cond', robust savefirst
        est sto iv_`v'
        putexcel A`p' = "iv_`i'_`v'"
        putexcel B`p' = `e(widstat)'          // Kleibergen-Paap Wald F (robust)
        est restore _ivreg2_attfe              // first stage saved by savefirst
        est sto fiv_`v'

        * Rural areas only
        ivreg2 `v' (attfe = dist_km) $controls1 if dist_km < ${maxdist} & urban2 == 0 `cond', robust savefirst
        est sto ivR_`v'
        putexcel C`p' = "ivR_`i'_`v'"
        putexcel D`p' = `e(widstat)'
        est restore _ivreg2_attfe
        est sto fivR_`v'

        * Urban areas only
        ivreg2 `v' (attfe = dist_km) $controls1 if dist_km < ${maxdist} & urban2 == 1 `cond', robust savefirst
        est sto ivU_`v'
        putexcel E`p' = "ivU_`i'_`v'"
        putexcel F`p' = `e(widstat)'
        est restore _ivreg2_attfe
        est sto fivU_`v'

        local p = `p' + 3
    }

    * tables for this subgroup: one column per outcome
    esttab ols_*  using "${outdir}/ols.csv",        $spec2nd
    esttab iv_*   using "${outdir}/iv.csv",         $spec2nd
    esttab ivR_*  using "${outdir}/iv_rural.csv",   $spec2nd
    esttab ivU_*  using "${outdir}/iv_urban.csv",   $spec2nd
    esttab fiv_*  using "${outdir}/iv_first.csv",   $spec1st
    esttab fivR_* using "${outdir}/iv_rural_first.csv", $spec1st
    esttab fivU_* using "${outdir}/iv_urban_first.csv", $spec1st

    estimates clear      // free the stored models before the next subgroup
}
