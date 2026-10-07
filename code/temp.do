clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. Do hedge funds hold bills, and what is the share of the most held bond

use "$int/sftds.dta", clear
merge m:1 isin using "$int/bond_info.dta", keep(1 3) keepusing(bondtype) nogen
gen bill = inlist(bondtype, "4", "GTC", "LET", "FTB", "BOT")
gen newcountry = cond(country == "US", "US", "EU")

* net positions in bills versus all other bonds, same set up as the CTD chart
preserve
	collapse (sum) net, by(date newcountry bill)
	tw (scatter net date if bill==1)(scatter net date if bill==0), by(newcountry) legend(order(1 "Bills" 2 "Not bills")) yline(0)
restore

* share of the most held bond on one day, net position summed across funds
keep if date == td(15jan2025)
collapse (sum) net (count) nfunds = net (first) bondtype country, by(newcountry isin)
gen absnet = abs(net)

* across the whole region
bysort newcountry: egen total = sum(absnet)
gen weight = absnet / total
gsort newcountry -weight
by newcountry: gen rank = _n
list newcountry isin country bondtype net weight nfunds if rank <= 10, noobs sepby(newcountry)

* one example bond per bill code
use "$int/bond_info.dta", clear
keep if inlist(bondtype, "4", "GTC", "LET", "FTB", "BOT")
gen ormat = (maturitydate - issuedate) / 365
bysort bondtype (isin): keep if _n == 1
list bondtype country isin issuedate maturitydate ormat couponrate, noobs

**# Repo rate of CTD bonds against all other bonds

* bond day flags from the aggregate panel, CTD, deliverable, near OTR, ILB, region and country
use "$int/sftds_agg.dta", clear
keep date isin isctd isdlv isnearotr ilb ttm country newcountry
tempfile flags
save `flags'

* hedge fund repo rates by fund, bond, day and side, from the SFTDS panel
* rates are in percent, so differences times 100 are basis points
use "$int/sftds.dta", clear
keep date entity_id isin borrowing_volume lending_volume borrowing_rate lending_rate
* make_dta.do flips the volumes of these two entities before April 2021 but not the rates, so flip the rates here too
gen flip = inlist(entity_id, "P5XEQYFJP74DYQX88M80", "O1XNTICYRCAHEAMEQI31") & date < td(24apr2021)
gen tmp = borrowing_rate
replace borrowing_rate = lending_rate if flip
replace lending_rate = tmp if flip
drop tmp flip
rename (borrowing_volume lending_volume borrowing_rate lending_rate) (volume1 volume0 rate1 rate0)
reshape long volume rate, i(date entity_id isin) j(borrowing)
drop if missing(rate) | volume <= 0
merge m:1 date isin using `flags', keep(match) nogen
drop if ilb == 1
drop if abs(rate) > 20 /*light sanity filter on reported rates*/
label define side 0 "Fund lends cash" 1 "Fund borrows cash"
label values borrowing side
egen bond = group(isin)
egen datecountry = group(date country)
tempfile rates
save `rates'

* daily mean rate of CTD and other bonds, by region and side
preserve
	collapse (mean) rate, by(date newcountry borrowing isctd)
	tw (scatter rate date if isctd==1, msize(vsmall))(scatter rate date if isctd==0, msize(vsmall)), by(newcountry borrowing) legend(order(1 "CTD" 2 "Not CTD")) ytitle("Repo rate, percent")
restore

* daily gap in basis points, CTD minus all other bonds of the same country and side
preserve
	collapse (mean) rate, by(date country borrowing isctd)
	reshape wide rate, i(date country borrowing) j(isctd)
	gen gap = (rate1 - rate0)*100
	drop if missing(gap)
	forvalues s = 1(-1)0 {
		di as text _n "CTD minus other bonds, basis points, side `s' (1 fund borrows cash, 0 fund lends cash)"
		tabstat gap if borrowing == `s', by(country) stat(mean p10 p50 p90 n) col(stat)
	}
	tw (line gap date if borrowing==1)(line gap date if borrowing==0), by(country) yline(0) legend(order(1 "Fund borrows cash" 2 "Fund lends cash")) ytitle("CTD minus other bonds, bp")
restore

* same gap against the other deliverable bonds only
preserve
	keep if isdlv == 1
	collapse (mean) rate, by(date country borrowing isctd)
	reshape wide rate, i(date country borrowing) j(isctd)
	gen gap = (rate1 - rate0)*100
	drop if missing(gap)
	forvalues s = 1(-1)0 {
		di as text _n "CTD minus other deliverable bonds, basis points, side `s'"
		tabstat gap if borrowing == `s', by(country) stat(mean p10 p50 p90 n) col(stat)
	}
restore

* regressions with date by country fixed effects, the CTD coefficient is the within day gap in percent
use `rates', clear
foreach r in US EU {
	di as text _n "Region `r', both sides pooled with a side fixed effect"
	reghdfe rate isctd if newcountry == "`r'", a(datecountry borrowing) vce(cluster date bond)
	reghdfe rate isctd isdlv if newcountry == "`r'", a(datecountry borrowing) vce(cluster date bond)
	reghdfe rate isctd isdlv isnearotr ttm if newcountry == "`r'", a(datecountry borrowing) vce(cluster date bond)
	forvalues s = 1(-1)0 {
		di as text _n "Region `r', side `s' (1 fund borrows cash, 0 fund lends cash)"
		reghdfe rate isctd if newcountry == "`r'" & borrowing == `s', a(datecountry) vce(cluster date bond)
		reghdfe rate isctd isdlv if newcountry == "`r'" & borrowing == `s', a(datecountry) vce(cluster date bond)
		reghdfe rate isctd isdlv isnearotr ttm if newcountry == "`r'" & borrowing == `s', a(datecountry) vce(cluster date bond)
	}
}

* cross check with the market wide bond day rate over all sectors, EUR bonds only
import delimited "$key/bond_day_rate.csv", varnames(1) clear
capture drop v1
gen date = date(business_date, "YMD")
format date %td
rename security_isin isin
keep date isin market_rate market_trades
merge 1:1 date isin using `flags', keep(match) nogen
drop if ilb == 1
drop if abs(market_rate) > 20
preserve
	collapse (mean) market_rate, by(date country isctd)
	reshape wide market_rate, i(date country) j(isctd)
	gen gap = (market_rate1 - market_rate0)*100
	drop if missing(gap)
	di as text _n "Market rate, CTD minus other bonds, basis points"
	tabstat gap, by(country) stat(mean p10 p50 p90 n) col(stat)
	tw (line gap date), by(country) yline(0) ytitle("CTD minus other bonds, bp")
restore
egen bond = group(isin)
egen datecountry = group(date country)
reghdfe market_rate isctd [aw = market_trades], a(datecountry) vce(cluster date bond)
reghdfe market_rate isctd isdlv [aw = market_trades], a(datecountry) vce(cluster date bond)
reghdfe market_rate isctd isdlv isnearotr ttm [aw = market_trades], a(datecountry) vce(cluster date bond)
