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
* the duration story predicts that the premium vanishes once bonds of the same remaining maturity and age on the same day are compared, and that it is weaker in 2021 when the CTD was the seasoned bond of its basket

use "$key/bond_bidask.dta", clear
gen bidask = (ask_price - bid_price)/(duration*(ask_price + bid_price)/2)*10000
keep date isin bidask
tempfile bidask
save `bidask'

use "$key/bond_day.dta", clear
keep if country == "US" & inlist(bondtype, "1", "2") & inrange(date, td(04jan2021), td(30sep2025))
keep date isin cusip8 issuedate maturitydate otr_number
gen cusip = cusip8
merge 1:1 date cusip using "$key/day_bond_deliverable_ctd.dta", keep(1 3) keepusing(ctd1 ctd2 deliverable_contract1 deliverable_contract2) nogen
gen isctd = ctd1 != "" | ctd2 != ""
gen isdlv = deliverable_contract1 != "" | deliverable_contract2 != ""
merge 1:1 date isin using `bidask', keep(match) nogen

* remaining maturity in one year bins, age in half year bins capped at ten years, on the run bins
* remaining maturity and age pin down the bond without reference to the baskets, the deliverable dummy then tests whether the basket matters on top
gen ttm = (maturitydate - date)/365
gen ttmbin = floor(ttm)
gen age = (date - issuedate)/365
gen agebin = min(floor(age*2), 20)
gen otrbin = cond(otr_number <= 2, 1, cond(otr_number <= 5, 2, cond(otr_number <= 10, 3, 4))) if !missing(otr_number)
encode isin, gen(bond)
egen contract = group(deliverable_contract1)
gen year2021 = year(date) == 2021
label var isctd "CTD"
label var isdlv "Deliverable"
bysort isctd: sum bidask

* six specifications, the third and fourth are the test, the fifth asks whether the basket matters beyond remaining maturity and age, the sixth compares the CTD with its basket mates
foreach s in full y2021 later {
	local cond = cond("`s'" == "y2021", "year2021 == 1", cond("`s'" == "later", "year2021 == 0", "1"))
	eststo `s'1: reghdfe bidask isctd if `cond', absorb(date) vce(cluster bond date)
	eststo `s'2: reghdfe bidask isctd if `cond', absorb(date#ttmbin) vce(cluster bond date)
	eststo `s'3: reghdfe bidask isctd if `cond', absorb(date#ttmbin#otrbin) vce(cluster bond date)
	eststo `s'4: reghdfe bidask isctd if `cond', absorb(date#ttmbin#agebin) vce(cluster bond date)
	eststo `s'5: reghdfe bidask isctd isdlv if `cond', absorb(date#ttmbin#agebin) vce(cluster bond date)
	eststo `s'6: reghdfe bidask isctd if `cond' & isdlv, absorb(date#contract#agebin) vce(cluster bond date)
}
local opts b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) keep(isctd isdlv) stats(N r2_within, fmt(%9.0fc %9.3f) labels("Bond days" "Within R squared")) mtitles("Day" "Day x remaining" "Day x remaining x on the run" "Day x remaining x age" "with deliverable" "Day x contract x age, deliverables")
esttab full1 full2 full3 full4 full5 full6, `opts' title("Full sample")
esttab y20211 y20212 y20213 y20214 y20215 y20216, `opts' title("2021, the CTD is the seasoned bond of the basket")
esttab later1 later2 later3 later4 later5 later6, `opts' title("2022 to 2025, the CTD is the recent high coupon bond")
eststo clear
