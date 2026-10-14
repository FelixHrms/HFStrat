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

* remaining maturity in one year bins, age in half year bins capped at ten years, the on the run number enters as its own set of dummies since inside a cell of day and remaining maturity the exact rank identifies the bond
gen ttm = (maturitydate - date)/365
gen ttmbin = floor(ttm)
gen ttmbin2 = floor(ttm*2) /*half years*/
gen age = (date - issuedate)/365
gen agebin = min(floor(age*2), 20) /*half years, capped at ten years*/
gen agebin4 = min(floor(age*4), 40) /*quarter years, capped at ten years*/
encode isin, gen(bond)
label var isctd "CTD"
bysort isctd: sum bidask

* five specifications, within a cell of day, remaining maturity and age the comparison is between consecutive issues of the same tenor, the last column tightens the cells
eststo c1: reghdfe bidask isctd, absorb(date) vce(cluster bond date)
eststo c2: reghdfe bidask isctd, absorb(date#ttmbin) vce(cluster bond date)
eststo c3: reghdfe bidask isctd, absorb(date#ttmbin otr_number) vce(cluster bond date)
eststo c4: reghdfe bidask isctd, absorb(date#ttmbin#agebin) vce(cluster bond date)
eststo c5: reghdfe bidask isctd, absorb(date#ttmbin2#agebin4) vce(cluster bond date)
esttab c1 c2 c3 c4 c5, b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) keep(isctd) stats(N r2_within, fmt(%9.0fc %9.3f) labels("Bond days" "Within R squared")) ///
	mtitles("Day" "Day x remaining" "Day x remaining, on the run number" "Day x remaining x age" "Half year remaining x quarter year age")
eststo clear
