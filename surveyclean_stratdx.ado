*! surveyclean_stratdx.ado - version 1.0.0 - 30aug2026
*! checks a stratum/PSU design for singleton strata and PSU codes that
*! are not uniquely nested within a single stratum
program define surveyclean_stratdx, rclass
    version 14.0
    syntax [if] [in], STRATA(varname) PSU(varname)

    marksample touse

    quietly count if `touse'
    local N = r(N)

    * --- PSUs per stratum ---
    tempvar psutag
    quietly egen byte `psutag' = tag(`strata' `psu') if `touse'

    tempname memhold
    tempfile sfile
    postfile `memhold' double stratum long n_psu using "`sfile'", replace

    quietly levelsof `strata' if `touse', local(slevels)
    foreach s of local slevels {
        quietly count if `psutag' == 1 & `strata' == `s' & `touse'
        post `memhold' (`s') (r(N))
    }
    postclose `memhold'

    local nstrata = 0
    local nsingle = 0
    local minpsu = .
    local maxpsu = .
    local meanpsu = .
    preserve
    use "`sfile'", clear
    local nstrata = _N
    quietly count if n_psu == 1
    local nsingle = r(N)
    quietly summarize n_psu
    local minpsu = r(min)
    local maxpsu = r(max)
    local meanpsu = r(mean)
    restore

    * --- total unique PSUs across the whole sample ---
    tempvar psutagall
    quietly egen byte `psutagall' = tag(`psu') if `touse'
    quietly count if `psutagall' == 1
    local npsu_total = r(N)

    * --- PSU codes appearing in more than one stratum (bad nesting) ---
    local nbadpsu = 0
    preserve
    quietly keep if `touse'
    quietly duplicates drop `psu' `strata', force
    quietly bysort `psu': gen byte __nstrat = _N
    quietly egen byte __badpsutag = tag(`psu') if __nstrat > 1
    quietly count if __badpsutag == 1
    local nbadpsu = r(N)
    restore

    di as text ""
    di as text "{hline 60}"
    di as text "Stratification / PSU structure check"
    di as text "{hline 60}"
    di as text "Observations:                  " as result %9.0f `N'
    di as text "Strata:                        " as result %9.0f `nstrata'
    di as text "Unique PSUs:                   " as result %9.0f `npsu_total'
    di as text "PSUs per stratum -- min/mean/max: " as result %4.0f `minpsu' as text " / " as result %4.1f `meanpsu' as text " / " as result %4.0f `maxpsu'
    di as text "Singleton strata (only 1 PSU): " as result %9.0f `nsingle'
    di as text "PSUs spanning >1 stratum:      " as result %9.0f `nbadpsu'
    di as text "{hline 60}"

    if `nsingle' > 0 {
        di as error "WARNING: singleton strata found -- linearized variance estimation may fail;"
        di as error "  consider svyset's singleunit() option (e.g. singleunit(certainty) or scaled)"
    }
    if `nbadpsu' > 0 {
        di as error "WARNING: some PSU codes are not uniquely nested within a stratum --"
        di as error "  PSU IDs are usually only unique within a stratum, not across the whole sample;"
        di as error "  consider using stratum#psu as a combined PSU identifier"
    }
    di as text "{hline 60}"

    return scalar n_strata = `nstrata'
    return scalar n_psu = `npsu_total'
    return scalar n_singleton = `nsingle'
    return scalar n_badpsu_nesting = `nbadpsu'
end
