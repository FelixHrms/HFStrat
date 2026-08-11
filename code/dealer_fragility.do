clear all
snapshot erase _all

global key "C:\\Users\\hermesf\\Projects\\HF_Strategies\\key dataframe"

cap log close
log using "$key\\dealer_fragility.log", replace text

**# CDS country-specific shocks

tempfile cds
local first = 1
foreach c in Germany France Italy Spain {
	import delimited "$key\\`c'_CDS.csv", varnames(1) clear
	capture drop v3
	gen country = cond("`c'"=="Germany","DE", cond("`c'"=="France","FR", cond("`c'"=="Italy","IT","ES")))
	if `first' == 0 append using `cds'
	local first = 0
	save `cds', replace
}
gen date = date(period, "DMY")
format date %td
sort country date
by country: gen dlcds = log(cds) - log(cds[_n-1])
by country: gen lagcds = cds[_n-1]
drop if missing(dlcds)
bysort date: egen totdl = total(dlcds)
bysort date: gen ncds = _N
keep if ncds == 4
gen relshock = dlcds - (totdl - dlcds)/3 /*LOO-demeaned log change = country-specific, scale-free*/
gen shock = relshock*lagcds /*rescaled to bp by lagged own level*/
local W = 20 /*business-day window for cumulated shocks*/
bysort country: egen sdrel = sd(relshock)
gen eshock = shock*(abs(relshock) > 2*sdrel) /*tail shocks only, tail defined in relative space*/
sort country date
by country: gen runs = sum(shock)
by country: gen rune = sum(eshock)
by country: replace shock = runs - runs[_n-`W']
by country: replace eshock = rune - rune[_n-`W']
drop if missing(shock)
keep country date shock eshock
reshape wide shock eshock, i(date) j(country) string
tempfile shocks
save `shocks'

**# Dealer collateral weights, lagged quarter

import delimited "$key\\dealer_country_day.csv", varnames(1) clear
capture drop v1
keep if inlist(collateral_country, "DE", "FR", "IT", "ES")
foreach v in borrowing_volume lending_volume {
	replace `v' = 0 if missing(`v')
}
gen vol = borrowing_volume + lending_volume
gen date = date(business_date, "YMD")
gen qtr = qofd(date) + 1 /*weights used one quarter later*/
collapse (sum) vol, by(dealer_id collateral_country qtr)
bysort dealer_id qtr: egen tot = total(vol)
gen share = vol/tot
drop vol tot
reshape wide share, i(dealer_id qtr) j(collateral_country) string
foreach c in DE FR IT ES {
	replace share`c' = 0 if missing(share`c')
}
tempfile dealer_w
save `dealer_w'

**# Dealer shock: portfolio-weighted CDS shock, dealer x day

use `shocks', clear
gen qtr = qofd(date)
joinby qtr using `dealer_w'
gen dshock = shareDE*shockDE + shareFR*shockFR + shareIT*shockIT + shareES*shockES
gen edshock = shareDE*eshockDE + shareFR*eshockFR + shareIT*eshockIT + shareES*eshockES
keep dealer_id date dshock edshock
tempfile dealershock
save `dealershock'

**# Fund funding weights across dealers (two-sided), lagged quarter

import delimited "$key\\fund_dealer_isin_day.csv", varnames(1) clear
capture drop v1
foreach v in borrowing_volume lending_volume {
	replace `v' = 0 if missing(`v')
}
gen vol = borrowing_volume + lending_volume
gen date = date(business_date, "YMD")
gen qtr = qofd(date) + 1
collapse (sum) vol, by(fund_id dealer_id qtr)
bysort fund_id qtr: egen tot = total(vol)
gen fdshare = vol/tot
keep fund_id dealer_id qtr fdshare
tempfile fund_w
save `fund_w'

**# Fund exposure to dealer shocks, fund x day

use `dealershock', clear
gen qtr = qofd(date)
joinby dealer_id qtr using `fund_w'
gen prod = fdshare*dshock
gen eprod = fdshare*edshock
collapse (sum) fexp = prod efexp = eprod, by(fund_id date)
tempfile fundexp
save `fundexp'

**# Panel

import delimited "$key\\fund_dealer_isin_day.csv", varnames(1) clear
capture drop v1
gen date = date(business_date, "YMD")
format date %td
gen country = substr(security_isin, 1, 2)
keep if inlist(country, "DE", "FR", "IT", "ES")
gen qtr = qofd(date)

merge m:1 date using `shocks', keep(match) nogen
merge m:1 dealer_id qtr using `dealer_w', keep(match) nogen
gen dexp = 0
foreach c in DE FR IT ES {
	replace dexp = dexp + share`c'*shock`c' if country != "`c'" /*exclude collateral country*/
}

merge m:1 fund_id date using `fundexp', keep(master match) nogen
merge m:1 fund_id dealer_id qtr using `fund_w', keep(master match) nogen
merge m:1 dealer_id date using `dealershock', keep(master match) nogen
replace fexp = fexp - fdshare*dshock if !missing(fexp) & !missing(fdshare) & !missing(dshock) /*leave out own dealer*/
replace efexp = efexp - fdshare*edshock if !missing(efexp) & !missing(fdshare) & !missing(edshock)

foreach v in borrowing_volume lending_volume {
	replace `v' = 0 if missing(`v')
}
gen net_long = (borrowing_volume - lending_volume)/10^9 /*net long position in bn*/
gen ltot = log(borrowing_volume + lending_volume) /*intermediation volume*/

gen month = mofd(date)
egen fcd = group(fund_id country date)
egen dcd = group(dealer_id country date)
egen bond_day = group(security_isin date)
egen fund_n = group(fund_id)
egen dealer_n = group(dealer_id)

label var dexp "Dealer exposure (20d cum.)"
label var fexp "Fund exposure (other dealers, 20d cum.)"
label var efexp "Fund exposure (other dealers, >2sd)"

**# Support: multi-dealer / multi-fund cells, both-sided pairs

bysort fcd (dealer_n): gen multidealer = dealer_n[1] != dealer_n[_N]
bysort dcd (fund_n): gen multifund = fund_n[1] != fund_n[_N]
gen bothsides = borrowing_volume > 0 & lending_volume > 0
tab multidealer if !missing(dexp)
tab multifund if !missing(fexp)
tab bothsides

**# Hop 1: shock -> dealer -> fund, within fund x country x day

reghdfe net_long dexp, a(fcd bond_day dealer_n) vce(cluster month)
reghdfe ltot dexp, a(fcd bond_day dealer_n) vce(cluster month)
reghdfe borrowing_rate dexp if borrowing_term <= 2, a(fcd bond_day dealer_n) vce(cluster month) /*fresh rates: stock is ON/open*/
reghdfe lending_rate dexp if lending_term <= 2, a(fcd bond_day dealer_n) vce(cluster month)
reghdfe net_long dexp, a(fcd bond_day dealer_n) vce(cluster dealer_n) /*headline, unit-clustered*/

**# Hop 2: shocked dealers -> fund -> other dealer, within dealer x country x day

reghdfe net_long fexp, a(dcd bond_day fund_n) vce(cluster month)
reghdfe ltot fexp, a(dcd bond_day fund_n) vce(cluster month)
reghdfe borrowing_rate fexp if borrowing_term <= 2, a(dcd bond_day fund_n) vce(cluster month)
reghdfe lending_rate fexp if lending_term <= 2, a(dcd bond_day fund_n) vce(cluster month)
reghdfe net_long fexp, a(dcd bond_day fund_n) vce(cluster fund_n) /*headline, unit-clustered*/
reghdfe net_long efexp, a(dcd bond_day fund_n) vce(cluster month) /*tail robustness*/

**# Fund aggregate: does the shock reach the fund's total book

preserve
	collapse (sum) net_long, by(fund_id date month)
	merge m:1 fund_id date using `fundexp', keep(match) nogen
	egen fund_n = group(fund_id)
	reghdfe net_long fexp, a(fund_n date) vce(cluster month)
restore

log close
