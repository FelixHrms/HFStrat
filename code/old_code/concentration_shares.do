clear all
snapshot erase _all

**# Concentration of positions, the share of the five largest funds and dealers
* Rebuilds the two concentration figures of the slides separately for the euro
* area and the US. The fund figure follows Graph.do, the dealer figure follows
* dealer_fragility_qe.do, only the split by market, the missing titles and the
* export lines are new.

global key "C:\\Users\\hermesf\\Projects\\HF_Strategies\\key dataframe"
global fig "C:\\Users\\hermesf\\Projects\\HF_Strategies\\Figures" /*figures for the slides, the Figures folder of the repository*/
capture mkdir "$fig"

**# Funds: each day funds are ranked by the absolute value of their net repo
* position, the figure shows the share of the five largest in the total across
* all funds trading directly, same filters as Graph.do

import delimited "$key\\sftds_dataframe.csv", clear
gen date = date(business_date, "YMD")
format date %td
drop business_date
rename security_isin isin

drop if borrowing_volume > 3*10^9
drop if lending_volume > 3*10^9
gen net = (borrowing_volume - lending_volume)/10^9
gen us = substr(isin, 1, 2) == "US"

* days with a thin cross section of bonds are dropped, as in Graph.do
egen tag = tag(date isin)
bysort date: egen nbonds = total(tag)
drop if nbonds < 600

* positions routed via banks are dropped, the figure is about funds trading directly
drop if bank_indicator == 1

tempfile funds
save `funds'

foreach m in EA US {
	use `funds', clear
	if "`m'" == "EA" drop if us == 1
	if "`m'" == "US" drop if us == 0
	collapse (sum) net, by(date entity_id)
	gen absnet = abs(net)
	gsort date -absnet
	by date: gen n = _n
	by date: egen sumtop = sum(absnet*(n<=5))
	by date: egen sumall = sum(absnet)
	gen frac = sumtop/sumall
	keep date frac
	duplicates drop
	scatter frac date, ///
		ytitle("Share of the five largest funds") xtitle("") ///
		ylabel(0(.2)1)
	graph export "$fig\\frac_top5_funds_`m'.png", replace width(3220)
	sum frac
}

**# Dealers: each day dealers are ranked by the absolute value of their net repo
* position with all hedge funds, the figure shows the share of the five largest
* in the total across all dealers, same cleaning as dealer_fragility_qe.do
* inputs are fund_dealer_day.csv (EUR) and fund_dealer_day_USD.csv (USD), both
* from dealer_fragility_data.ipynb

foreach m in EA US {
	if "`m'" == "EA" import delimited "$key\\fund_dealer_day.csv", varnames(1) clear
	if "`m'" == "US" import delimited "$key\\fund_dealer_day_USD.csv", varnames(1) clear
	capture drop v1
	gen date = date(business_date, "YMD")
	format date %td
	foreach v in borrowing_volume lending_volume {
		replace `v' = 0 if missing(`v')
	}
	* two funds report borrowing and lending the wrong way round at the beginning
	* of the sample, flip the two sides for them before 24 April 2021 as in DT.do
	gen flip = inlist(fund_id, "P5XEQYFJP74DYQX88M80", "O1XNTICYRCAHEAMEQI31") & date < td(24apr2021)
	gen tmp = borrowing_volume
	replace borrowing_volume = lending_volume if flip
	replace lending_volume = tmp if flip
	drop tmp flip

	collapse (sum) borrowing_volume lending_volume, by(date dealer_id)
	gen net = borrowing_volume - lending_volume
	gen absnet = abs(net)
	gsort date -absnet
	by date: gen n = _n
	by date: egen sumtop = sum(absnet*(n<=5))
	by date: egen sumall = sum(absnet)
	gen frac = sumtop/sumall
	keep date frac
	duplicates drop
	scatter frac date, ///
		ytitle("Share of the five largest dealers") xtitle("") ///
		ylabel(0(.2)1)
	graph export "$fig\\frac_top5_dealers_`m'.png", replace width(3220)
	sum frac
}
