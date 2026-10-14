clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. The CTD liquidity gap drawn, raw and within moving windows of remaining maturity and age, US bonds and notes
* for each CTD bond day the spread minus the mean spread of the non CTD bonds on the day, in the same remaining maturity cell, and in the same cell of remaining maturity and age
* two definitions of the cells, the fixed bins of the regression table and moving kernels of the same width, drawn side by side
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

* comparison means per CTD bond day under two definitions of the comparison group
* bins, the cells of the regression table, the same whole year of remaining maturity and the same half year of age as the CTD
* kernel, triangular weights that are one at the CTD and zero half a year away in remaining maturity and a quarter year away in age
gen k_day = 1
gen k_ttm_bins = floor(ttm) == floor(ttm_ctd)
gen k_cell_bins = k_ttm_bins & min(floor(age*2), 20) == min(floor(age_ctd*2), 20)
gen k_ttm_kernel = max(0, 1 - abs(ttm - ttm_ctd)/0.5)
gen k_cell_kernel = k_ttm_kernel*max(0, 1 - abs(age - age_ctd)/0.25)
gen w_day = k_day
gen b_day = bidask*k_day
foreach v in bins kernel {
	foreach g in ttm cell {
		gen w_`g'_`v' = k_`g'_`v'
		gen b_`g'_`v' = bidask*k_`g'_`v'
	}
}
collapse (sum) w_* b_*, by(date isin_ctd bidask_ctd)
gen gap_day = bidask_ctd - b_day/w_day if w_day > 0
foreach v in bins kernel {
	foreach g in ttm cell {
		gen gap_`g'_`v' = bidask_ctd - b_`g'_`v'/w_`g'_`v' if w_`g'_`v' > 0
	}
}
collapse (mean) gap_*, by(date)
tempfile gaps
save `gaps'

* one double chart per definition
foreach v in bins kernel {
	use `gaps', clear
	tw (line gap_day date)(line gap_ttm_`v' date)(line gap_cell_`v' date), ///
		legend(order(1 "Same day" 2 "Same remaining maturity" 3 "Same remaining maturity and age") pos(6) cols(1) size(small) symxsize(6)) ///
		ytitle("CTD minus comparison, bp") xtitle("") yline(0) name(ts, replace)

	* means with Newey West standard errors over 20 trading days, each series on its own consecutive index over the days where it exists
	foreach g in day ttm cell {
		local var = cond("`g'" == "day", "gap_day", "gap_`g'_`v'")
		preserve
			keep if !missing(`var')
			sort date
			gen long t = _n
			tsset t
			newey `var', lag(20)
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
	graph combine ts bar, cols(2) title("Comparison group, `v'", size(small)) name(`v', replace)
}
