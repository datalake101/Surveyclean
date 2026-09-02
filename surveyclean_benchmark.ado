*! surveyclean_benchmark.ado - version 1.0.0 - 30aug2026
*! compares unweighted and weighted sample shares of a categorical
*! variable against known population shares supplied by the user
program define surveyclean_benchmark, rclass
    version 14.0
    syntax varname [if] [in], WEIGHT(varname) POPSHARE(numlist)

    marksample touse
    capture confirm string variable `varlist'
    local isstr = (_rc == 0)

    quietly levelsof `varlist' if `touse', local(levels)
    local nlev : word count `levels'
    local npop : word count `popshare'
    if `nlev' != `npop' {
        di as error "popshare() must supply exactly `nlev' values, one per level of `varlist' (ascending order): `levels'"
        exit 198
    }

    quietly count if `touse'
    local N = r(N)
    quietly summarize `weight' if `touse'
    local totalwt = r(sum)

    di as text ""
    di as text "{hline 78}"
    di as text "Benchmark check: `varlist' vs. supplied population shares (all in %)"
    di as text "{hline 78}"
    local line `"%-14s "Level""'
    local line `"`line' %12s "Unweighted""'
    local line `"`line' %12s "Weighted""'
    local line `"`line' %12s "Population""'
    local line `"`line' %10s "Wtd - Pop""'
    di as text `line'
    di as text "{hline 78}"

    local li = 0
    foreach lv of local levels {
        local li = `li' + 1
        local pop : word `li' of `popshare'

        if `isstr' {
            quietly count if `varlist' == "`lv'" & `touse'
        }
        else {
            quietly count if `varlist' == `lv' & `touse'
        }
        local nunw = r(N)
        local pctunw = `nunw' / `N' * 100

        if `isstr' {
            quietly summarize `weight' if `varlist' == "`lv'" & `touse'
        }
        else {
            quietly summarize `weight' if `varlist' == `lv' & `touse'
        }
        local wtsum = r(sum)
        local pctwtd = `wtsum' / `totalwt' * 100
        local diff = `pctwtd' - `pop'

        local line `"%-14s "`lv'""'
        local line `"`line' %12s "`=string(`pctunw',"%6.2f")'""'
        local line `"`line' %12s "`=string(`pctwtd',"%6.2f")'""'
        local line `"`line' %12s "`=string(`pop',"%6.2f")'""'
        local line `"`line' %10s "`=string(`diff',"%6.2f")'""'
        di as text `line'
    }
    di as text "{hline 78}"

    return scalar n_levels = `nlev'
end
