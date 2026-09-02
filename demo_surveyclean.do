* demo_surveyclean.do
* Demonstrates all surveyclean subcommands on a synthetic complex-survey
* dataset. Run after installing surveyclean (see README.md).

clear all
set more off
set seed 4820

* --- build a synthetic complex-survey dataset --------------------------------
set obs 500
gen byte stratum = mod(_n, 4) + 1
gen byte psu = ceil(_n / 20)           // ~25 obs per PSU, nested in stratum
gen byte region = mod(_n, 4) + 1       // 4 regions, for the benchmark demo

gen pweight = rgamma(4,4)
replace pweight = pweight * 50
replace pweight = pweight * 15 in 1/3   // plant a few extreme weights
replace pweight = 0 in 10               // plant an invalid zero weight
replace pweight = . in 20               // plant a missing weight

* make stratum 4 a singleton-PSU stratum for the demo
replace psu = 999 if stratum == 4

* --- wtcheck demo -------------------------------------------------------------
surveyclean wtcheck pweight, threshold(8)

* --- stratdx demo ---------------------------------------------------------------
surveyclean stratdx, strata(stratum) psu(psu)

* --- benchmark demo -----------------------------------------------------------
* suppose the true population shares of region 1-4 are 20% / 30% / 30% / 20%
surveyclean benchmark region, weight(pweight) popshare(20 30 30 20)

* --- trimwt demo ------------------------------------------------------------------
surveyclean trimwt pweight, method(median) mult(5)
surveyclean trimwt pweight, method(percentile) pctile(99) generate(trimw99_pweight)

di as text ""
di as text "Demo complete."
