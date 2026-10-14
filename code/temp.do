clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. The CTD liquidity gap drawn, raw and within moving windows of remaining maturity and age, US bonds and notes
* for each CTD bond day the spread minus the mean spread of the non CTD bonds on the day, within half a year of its remaining maturity, and within that and a quarter year of its age
* windows move with the bond, so the comparison group changes one bond at a time and not at bin boundaries, the widths match the bins of the regression table
* two comparison groups, all non CTD bonds with equal weights, and the bonds funds hold weighted by their borrowing positions

use "$key/bond_bidask.dta", clear
gen bidask = (ask_price - bid_price)/(duration*(ask_price + bid_price)/2)*10000
keep date isin bidask
tempfile bidask
save `bidask'

use "$int/sftds.dta", clear
keep if country == "US" & borrowing_volume > 0
collapse (sum) borrowing_volume, by(date isin)
tempfile funds
save `funds'

use "$key/bond_day.dta", clear
keep if country == "US" & inlist(bondtype, "1", "2") & inrange(date, td(04jan2021), td(30sep2025))
keep date isin cusip8 issuedate maturitydate
gen cusip = cusip8
merge 1:1 date cusip using "$key/day_bond_deliverable_ctd.dta", keep(1 3) keepusing(ctd1 ctd2) nogen
gen isctd = ctd1 != "" | ctd2 != ""
merge 1:1 date isin using `bidask', keep(match) nogen
merge 1:1 date isin using `funds', keep(1 3) nogen
replace borrowing_volume = 0 if missing(borrowing_volume)
gen ttm = (maturitydate - date)/365
gen age = (date - issuedate)/365
keep date isin isctd bidask ttm age borrowing_volume

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

* comparison means per CTD bond day, equal weights and fund weights
gen in_ttm = abs(ttm - ttm_ctd) <= 0.5
gen in_cell = in_ttm & abs(age - age_ctd) <= 0.25
foreach g in day ttm cell {
	local cond = cond("`g'" == "day", "1", "in_`g'")
	gen b_`g' = bidask if `cond'
	gen w_`g' = borrowing_volume if `cond'
	gen bw_`g' = bidask*borrowing_volume if `cond'
}
collapse (mean) b_day b_ttm b_cell (sum) w_day w_ttm w_cell bw_day bw_ttm bw_cell, by(date isin_ctd bidask_ctd)
foreach g in day ttm cell {
	gen gap_eq_`g' = bidask_ctd - b_`g'
	gen gap_hf_`g' = bidask_ctd - bw_`g'/w_`g' if w_`g' > 0
}
collapse (mean) gap_eq_* gap_hf_*, by(date)
tempfile gaps
save `gaps'

* one double chart per comparison group
foreach v in eq hf {
	use `gaps', clear
	local title = cond("`v'" == "eq", "all other bonds, equal weights", "bonds funds hold, weighted by positions")
	tw (line gap_`v'_day date)(line gap_`v'_ttm date)(line gap_`v'_cell date), ///
		legend(order(1 "Same day" 2 "Same remaining maturity" 3 "Same remaining maturity and age") pos(6) cols(1) size(small) symxsize(6)) ///
		ytitle("CTD minus comparison, bp") xtitle("") yline(0) name(ts, replace)
	sort date
	gen t = _n
	tsset t
	foreach g in day ttm cell {
		newey gap_`v'_`g', lag(20)
		local m_`g' = _b[_cons]
		local s_`g' = _se[_cons]
	}
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
	graph combine ts bar, cols(2) title("Comparison group, `title'", size(small)) name(`v', replace)
}
