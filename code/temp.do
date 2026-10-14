clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. The CTD liquidity gap drawn, raw and within cells of remaining maturity and age, US bonds and notes
* for each CTD bond day the spread minus the mean spread of the non CTD bonds on the day, in the same remaining maturity bin, and in the same bin of remaining maturity and age
* averaged over the CTDs of the day, equal weights, the regression table as a time series

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
gen ttmbin = floor((maturitydate - date)/365)
gen agebin = min(floor((date - issuedate)/365*2), 20)

* the three comparison means, non CTD bonds only, and the gaps of the CTD bonds
gen b0 = bidask if isctd == 0
bysort date: egen m_day = mean(b0)
bysort date ttmbin: egen m_ttm = mean(b0)
bysort date ttmbin agebin: egen m_cell = mean(b0)
keep if isctd
gen gap_day = bidask - m_day
gen gap_ttm = bidask - m_ttm
gen gap_cell = bidask - m_cell /*missing when the CTD is alone in its cell*/
collapse (mean) gap_day gap_ttm gap_cell, by(date)

* time series on the left
tw (line gap_day date)(line gap_ttm date)(line gap_cell date), ///
	legend(order(1 "Same day" 2 "Same remaining maturity" 3 "Same remaining maturity and age") pos(6) cols(1) size(small) symxsize(6)) ///
	ytitle("CTD minus comparison, bp") xtitle("") yline(0) name(ts, replace)

* means with Newey West standard errors over 20 trading days
sort date
gen t = _n
tsset t
foreach g in day ttm cell {
	newey gap_`g', lag(20)
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
graph combine ts bar, cols(2)
