clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. Does the CTD liquidity premium survive tenor and age, bond day regressions, US bonds and notes
* spread on the CTD dummy with the fixed effects tightened step by step, equal weights over bond days, standard errors clustered by bond and date
* the duration story predicts that the premium vanishes once bonds of the same remaining maturity and age on the same day are compared

use "$key/bond_bidask.dta", clear
gen bidask = (ask_price - bid_price)/(duration*(ask_price + bid_price)/2)*10000
keep date isin bidask
tempfile bidask
save `bidask'

use "$key/bond_day.dta", clear
keep if country == "US" & inlist(bondtype, "1", "2") & inrange(date, td(04jan2021), td(30sep2025))
keep date isin cusip8 issuedate maturitydate otr_number
gen cusip = cusip8
merge 1:1 date cusip using "$key/day_bond_deliverable_ctd.dta", keep(1 3) keepusing(ctd1 ctd2) nogen
gen isctd = ctd1 != "" | ctd2 != ""
merge 1:1 date isin using `bidask', keep(match) nogen

* remaining maturity and age, the cell of day, remaining maturity and age holds consecutive issues of the same tenor
gen ttm = (maturitydate - date)/365
gen age = (date - issuedate)/365
gen ttmbin = floor(ttm)
gen agebin = min(floor(age*2), 20) /*half years, capped at ten years*/
encode isin, gen(bond)
label var isctd "CTD"
bysort isctd: sum bidask

* the three columns
eststo c1: reghdfe bidask isctd, absorb(date) vce(cluster bond date)
count if isctd & e(sample)
estadd scalar nctd = r(N)
eststo c2: reghdfe bidask isctd, absorb(date#ttmbin) vce(cluster bond date)
count if isctd & e(sample)
estadd scalar nctd = r(N)
eststo c3: reghdfe bidask isctd, absorb(date#ttmbin#agebin) vce(cluster bond date)
count if isctd & e(sample)
estadd scalar nctd = r(N)
esttab c1 c2 c3, b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) keep(isctd) stats(N nctd r2_within, fmt(%9.0fc %9.0fc %9.3f) labels("Bond days" "CTD bond days" "Within R squared")) ///
	mtitles("Day" "Day x remaining maturity" "Day x remaining maturity x age")
eststo clear

* bin widths for the third column, finer cells compare closer bonds but drop CTD bond days that end up alone in their cell
* remaining maturity in one year and half year bins, age in one year, half year and quarter year bins capped at ten years
local col = 0
foreach tw in 1 0.5 {
	foreach aw in 1 0.5 0.25 {
		local ++col
		gen tb = floor(ttm/`tw')
		gen ab = min(floor(age/`aw'), 10/`aw')
		eststo b`col': reghdfe bidask isctd, absorb(date#tb#ab) vce(cluster bond date)
		count if isctd & e(sample)
		estadd scalar nctd = r(N)
		estadd local tbin "`tw'"
		estadd local abin "`aw'"
		drop tb ab
	}
}
esttab b1 b2 b3 b4 b5 b6, b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) keep(isctd) stats(tbin abin N nctd, fmt(%s %s %9.0fc %9.0fc) labels("Remaining maturity bin, years" "Age bin, years" "Bond days" "CTD bond days")) nomtitles
eststo clear
