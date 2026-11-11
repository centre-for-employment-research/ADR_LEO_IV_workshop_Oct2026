# Post-16 pathways in LEO: IV code snippets

Min Zhang, Centre for Employment Research, University of Westminster

Code snippets shared after the ADR England *Youth Transitions* workshop on Longitudinal Education Outcomes (LEO) data, 22 October 2026. They come from a study of post-16 pathways for young people who did not achieve grade C (4) in GCSE English and/or maths (2011 Key Stage 4 cohort), using LEO Iteration 2 in the ONS Secure Research Service (SRS).

The snippets show the logic of the instrumental variables (IV) analysis. They are not a complete pipeline and will not run on their own: the input files are built in earlier steps that are not included here (see [What is not included](#what-is-not-included)).

## File

| File | What it does |
|---|---|
| `snippets_IV_2011_cohort.do` | IV estimates of the effect of attending a General FE college at 17, using distance to the nearest General FE college in the young person's post-16 choice set as the instrument. Builds the analysis sample, takes a first look at the instrument, then loops over subgroups and outcomes (OLS, IV, IV for rural and for urban areas), saves first-stage F statistics and writes tables for each subgroup. |

## Inputs

The snippets expect Stata files built earlier in the project. File names in the snippets are illustrative.

| Input | Content | Where it comes from |
|---|---|---|
| Outcomes file | LEO outcomes at age 24 (employment, earnings, benefits, days in education) | FFT Education Datalab's `metrics` tables |
| Choice-set file | Distance to the nearest General FE college in the choice set, General FE attendance in October at 17, MSOA | Choice sets built for the project from where similar young people from the same MSOA went in the current and two previous cohorts (project code, not public) |
| Qualifications file | Highest qualification by age 19 | Project code (not included) |
| Demographics file | Prior attainment, FSM, SEN, gender, ethnicity, region | National Pupil Database (School Census and attainment) |
| Area lookups | 2011 rural-urban classification and household income decile by MSOA | ONS open data, brought into the SRS |

FFT Education Datalab's scripts for loading LEO tables are published separately: [github.com/Youth-Transitions/resources](https://github.com/Youth-Transitions/resources).

## Requirements

- Stata 17
- From SSC: `ivreg2`, `ranktest`, `estout`
- Globals pointing to your own folders: `${data}` and `${output}`

## What is not included

- SQL that extracts the LEO tables in the SRS
- Construction of the post-16 choice sets and of the distances (distances are calculated outside the SRS and brought in through ONS ingestion)
- Any data or results: LEO data are available only to accredited researchers through the ONS SRS, and all outputs go through ONS output checking before release

## Notes

- The snippets were tidied for sharing: paths replaced by globals, exploratory lines removed, and only the models in the final report kept (OLS, IV, IV rural, IV urban). The file lists its changes in its header.
- Standard errors in the IV models are robust to heteroskedasticity, not clustered. Because the instrument varies by MSOA, clustering by MSOA is worth considering.
- Stata can hold at most 300 stored estimates, so the snippet writes and clears the tables for each subgroup before moving to the next.

## Contact

Min Zhang, Centre for Employment Research, University of Westminster.
