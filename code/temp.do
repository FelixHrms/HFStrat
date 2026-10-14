clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. The CTD liquidity gap drawn, raw and within moving windows of remaining maturity and age, US bonds and notes
* for each CTD bond day the spread minus the kernel weighted mean spread of the non CTD bonds on the day, within half a year of its remaining maturity, and within that and a quarter year of its age
* the windows move with the bond and the kernel lets a bond enter and leave gradually, so the comparison group never changes in steps
* equal weights over bonds and over the CTDs of a day, the regression table as a time series

use "$key/bond_bidask.dta", clear
gen bidask = (ask_price - bid_price)/(duration*(ask_price + bid_price)/2)*10000
keep date isin bidask
tempfile bidask
save `bidask'

use "$key/bond_day.dta", clear
keep if country == "US" & inlist(bondtype, "1", "2") & inrange(date, td(04jan2021), td(30sep2025))
keep date isin cusip8 issuedate maturitydate
gen cusip = cusip8
merge 1:1 date cusip using "$key/day_bond_deliverable_ctd.dta", keep(1 3) keepusing(ctd1 ctd2) nogen
gen isctd = ctd1 != "" | ctd2 != ""
merge 1:1 date isin using `bidask', keep(match) nogen
gen ttm = (maturitydate - date)/365
gen age = (date - issuedate)/365
keep date isin isctd bidask ttm age

* the CTD bond days and the non CTD bond days, joined within the day
preserve
	keep if isctd
	keep date isin bidask ttm age
	rename (isin bidask ttm age) (isin_ctd bidask_ctd ttm_ctd age_ctd)
	tempfile ctd
	save `ctd'
restore
keep if isctd == 0
drop isctd
joinby date using `ctd'

* comparison means per CTD bond day, triangular kernels in remaining maturity and age so a bond enters the group gradually as it moves towards the CTD
* the kernel is one at the CTD and zero half a year away in remaining maturity, a quarter year away in age, the same widths as the bins of the regression table
gen k_day = 1
gen k_ttm = max(0, 1 - abs(ttm - ttm_ctd)/0.5)
gen k_cell = k_ttm*max(0, 1 - abs(age - age_ctd)/0.25)
foreach g in day ttm cell {
	gen w_`g' = k_`g'
	gen b_`g' = bidask*k_`g'
}
collapse (sum) w_* b_*, by(date isin_ctd bidask_ctd)
foreach g in day ttm cell {
	gen gap_`g' = bidask_ctd - b_`g'/w_`g' if w_`g' > 0
}
collapse (mean) gap_*, by(date)

* time series on the left
tw (line gap_day date)(line gap_ttm date)(line gap_cell date), ///
	legend(order(1 "Same day" 2 "Same remaining maturity" 3 "Same remaining maturity and age") pos(6) cols(1) size(small) symxsize(6)) ///
	ytitle("CTD minus comparison, bp") xtitle("") yline(0) name(ts, replace)

* means with Newey West standard errors over 20 trading days, each series on its own consecutive index over the days where it exists
foreach g in day ttm cell {
	preserve
		keep if !missing(gap_`g')
		sort date
		gen long t = _n
		tsset t
		newey gap_`g', lag(20)
		local m_`g' = _b[_cons]
		local s_`g' = _se[_cons]
	restore
}

* one bar per comparison, CTD minus the comparison mean, with 95 percent bands
clear
set obs 3
gen x = _n
gen mean = cond(x == 1, `m_day', cond(x == 2, `m_ttm', `m_cell'))
gen se = cond(x == 1, `s_day', cond(x == 2, `s_ttm', `s_cell'))
gen lo = mean - 1.96*se
gen hi = mean + 1.96*se
tw (bar mean x if x == 1, barwidth(0.6))(bar mean x if x == 2, barwidth(0.6))(bar mean x if x == 3, barwidth(0.6))(rcap lo hi x, lcolor(black)), ///
	xlabel(1 "Same day" 2 `""Same remaining" "maturity""' 3 `""Same remaining" "maturity and age""', labsize(small)) xtitle("") ///
	ytitle("CTD minus comparison, bp") yline(0) legend(off) name(bar, replace)
graph combine ts bar, cols(2)
