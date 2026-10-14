clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. Bid ask spread by on the run number, CTD against other bonds within original maturity buckets, US bonds and notes
* the test of the duration story, a CTD and a non CTD bond of the same tenor and the same on the run status should carry the same spread
* equal weights over bond days, three buckets aligned with the contracts, the other deliverable bonds of the same contracts as the sharpest control group

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

* three groups, the CTD, the other deliverable bonds of the same contracts, and the bonds no contract delivers
gen grp = cond(isctd, 1, cond(isdlv, 2, 3))
label define grplab 1 "CTD" 2 "Other deliverable" 3 "Not deliverable"
label values grp grplab

* original maturity buckets aligned with the contracts
gen ormat = (maturitydate - issuedate)/365
gen bucket = cond(ormat < 6, 1, cond(ormat < 12, 2, 3))
label define bucketlab 1 "2 to 5 year notes" 2 "7 and 10 year notes" 3 "20 and 30 year bonds"
label values bucket bucketlab

* on the run number with 12 and above pooled
drop if missing(otr_number)
gen otrclass = min(otr_number, 12)
tab bucket grp

collapse (mean) bidask (count) n = bidask, by(bucket grp otrclass)
drop if n < 20 /*a lone CTD on a few days does not draw a point*/
tw (connected bidask otrclass if grp == 1)(connected bidask otrclass if grp == 2)(connected bidask otrclass if grp == 3), ///
	by(bucket, rows(1) yrescale note("") legend(pos(6))) legend(order(1 "CTD" 2 "Other deliverable" 3 "Not deliverable") rows(1)) ///
	xlabel(1(1)12) xtitle("On the run number, 12 and above pooled") ytitle("Yield bid ask spread, bp")
