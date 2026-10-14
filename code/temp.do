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
* the duration story predicts that the premium vanishes once bonds of the same tenor and age on the same day are compared, and that it exists only from 2022 when the CTD became the recent high coupon issue

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

* tenor buckets aligned with the contracts, age in half year bins capped at ten years, on the run bins
gen ormat = (maturitydate - issuedate)/365
gen bucket = cond(ormat < 6, 1, cond(ormat < 12, 2, 3))
gen age = (date - issuedate)/365
gen agebin = min(floor(age*2), 20)
gen otrbin = cond(otr_number <= 2, 1, cond(otr_number <= 5, 2, cond(otr_number <= 10, 3, 4))) if !missing(otr_number)
encode isin, gen(bond)
egen contract = group(deliverable_contract1)
gen post = date >= td(01jan2022)
label var isctd "CTD"

* five specifications, the fourth and fifth are the test, the fifth compares the CTD with its basket mates of the same age
foreach s in full post {
	local cond = cond("`s'" == "post", "post == 1", "1")
	eststo `s'1: reghdfe bidask isctd if `cond', absorb(date) vce(cluster bond date)
	eststo `s'2: reghdfe bidask isctd if `cond', absorb(date#bucket) vce(cluster bond date)
	eststo `s'3: reghdfe bidask isctd if `cond', absorb(date#bucket#otrbin) vce(cluster bond date)
	eststo `s'4: reghdfe bidask isctd if `cond', absorb(date#bucket#agebin) vce(cluster bond date)
	eststo `s'5: reghdfe bidask isctd if `cond' & isdlv, absorb(date#contract#agebin) vce(cluster bond date)
}
local titles mtitles("Day" "Day x tenor" "Day x tenor x on the run" "Day x tenor x age" "Day x contract x age, deliverables")
esttab full1 full2 full3 full4 full5, b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) keep(isctd) stats(N r2_within, fmt(%9.0fc %9.3f) labels("Bond days" "Within R squared")) `titles' title("Full sample")
esttab post1 post2 post3 post4 post5, b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) keep(isctd) stats(N r2_within, fmt(%9.0fc %9.3f) labels("Bond days" "Within R squared")) `titles' title("From 2022")
eststo clear
