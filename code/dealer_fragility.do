clear all
snapshot erase _all

global key "C:\Users\hermesf\Projects\HF_Strategies\key dataframe"
global data "C:\Users\hermesf\Projects\HF_Strategies\Data"
global tab "C:\Users\hermesf\Projects\HF_Strategies\Tables"

**# CDS country-specific shocks

tempfile cds
local first = 1
foreach c in Germany France Italy Spain {
	import delimited "$data/`c'_CDS.csv", varnames(1) clear
	capture drop v3
	gen country = cond("`c'"=="Germany","DE", cond("`c'"=="France","FR", cond("`c'"=="Italy","IT","ES")))
	if `first' == 0 append using `cds'
	local first = 0
	save `cds', replace
}
gen date = date(period, "DMY")
format date %td
sort country date
by country: gen dcds = cds - cds[_n-1]
drop if missing(dcds)
bysort date: egen totdcds = total(dcds)
bysort date: gen ncds = _N
keep if ncds == 4
gen shock = dcds - (totdcds - dcds)/3 /*minus leave-one-out mean = country-specific component*/
keep country date shock
reshape wide shock, i(date) j(country) string
tempfile shocks
save `shocks'

**# Dealer collateral weights, lagged quarter

import delimited "$key/dealer_country_day.csv", varnames(1) clear
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
keep dealer_id date dshock
tempfile dealershock
save `dealershock'

**# Fund funding weights across dealers, lagged quarter

import delimited "$key/fund_dealer_isin_day.csv", varnames(1) clear
capture drop v1
replace borrowing_volume = 0 if missing(borrowing_volume)
gen date = date(business_date, "YMD")
gen qtr = qofd(date) + 1
collapse (sum) borrowing_volume, by(fund_id dealer_id qtr)
bysort fund_id qtr: egen tot = total(borrowing_volume)
gen fdshare = borrowing_volume/tot
keep fund_id dealer_id qtr fdshare
tempfile fund_w
save `fund_w'

**# Fund exposure to dealer shocks, fund x day

use `dealershock', clear
gen qtr = qofd(date)
joinby dealer_id qtr using `fund_w'
gen prod = fdshare*dshock
collapse (sum) fexp = prod, by(fund_id date)
tempfile fundexp
save `fundexp'

**# Panel

import delimited "$key/fund_dealer_isin_day.csv", varnames(1) clear
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

gen lvol = log(borrowing_volume)

egen fcd = group(fund_id country date)
egen dcd = group(dealer_id country date)
egen bond_day = group(security_isin date)
egen fund_n = group(fund_id)
egen dealer_n = group(dealer_id)

label var dexp "Dealer exposure"
label var fexp "Fund exposure (other dealers)"

**# Hop 1: shock -> dealer -> fund, within fund x country x day

reghdfe borrowing_rate dexp, a(fcd bond_day) vce(cluster dealer_n date)
	estadd local fcdfe "Yes"
	estadd local bdfe "Yes"
	estadd local dcdfe "No"
	estadd local ffe "No"
	est sto h1
reghdfe lvol dexp, a(fcd bond_day) vce(cluster dealer_n date)
	estadd local fcdfe "Yes"
	estadd local bdfe "Yes"
	estadd local dcdfe "No"
	estadd local ffe "No"
	est sto h2

**# Hop 2: shocked dealers -> fund -> other dealer, within dealer x country x day

reghdfe borrowing_rate fexp, a(dcd bond_day fund_n) vce(cluster fund_n date)
	estadd local fcdfe "No"
	estadd local bdfe "Yes"
	estadd local dcdfe "Yes"
	estadd local ffe "Yes"
	est sto h3
reghdfe lvol fexp, a(dcd bond_day fund_n) vce(cluster fund_n date)
	estadd local fcdfe "No"
	estadd local bdfe "Yes"
	estadd local dcdfe "Yes"
	estadd local ffe "Yes"
	est sto h4

esttab h1 h2 h3 h4 using "$tab/dealer_fragility.tex", replace star(* 0.10 ** 0.05 *** 0.01) ///
	b(3) t(3) label nogaps booktabs ar2 mtitles("Rate" "Log volume" "Rate" "Log volume") ///
	stats(fcdfe bdfe dcdfe ffe r2_a N, label("Fund x Country x Day FE" "Bond x Day FE" "Dealer x Country x Day FE" "Fund FE" "Adj.\ R$^2$" "Obs") ///
	fmt(0 0 0 0 3 %9.0gc) layout("\multicolumn{1}{c}{@}" "\multicolumn{1}{c}{@}" "\multicolumn{1}{c}{@}" "\multicolumn{1}{c}{@}" "@" "\multicolumn{1}{c}{@}")) ///
	eqlabels(none) nonotes
