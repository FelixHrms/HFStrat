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

**# Borrowing repo rate of CTD bonds against all other bonds as a spread over SOFR, US only, overnight positions, weighted by fund positions

* SOFR, date in the second column and the rate in percent in the fourth
import delimited "$data/SOFR.csv", varnames(nonames) rowrange(2) clear
keep v2 v4
rename (v2 v4) (sofrdate sofr)
gen date = date(sofrdate, "YMD")
format date %td
destring sofr, replace
keep date sofr
tempfile sofr
save `sofr'

use "$int/sftds.dta", clear
keep if country == "US" & !missing(borrowing_rate) & borrowing_volume > 0 & borrowing_term <= 1 /*overnight positions only, the term is the average contractual maturity in days*/
keep date isin borrowing_volume borrowing_rate
merge m:1 date isin using "$int/sftds_agg.dta", keep(match) keepusing(isctd) nogen
merge m:1 date using `sofr', keep(match) nogen
gen spread = (borrowing_rate - sofr)*100 /*basis points*/

* drop the days around FOMC rate changes, the decision day and the three days after, SOFR moves the day after the decision and the reported rates lag
gen fomc = 0
foreach d in 16mar2022 4may2022 15jun2022 27jul2022 21sep2022 2nov2022 14dec2022 1feb2023 22mar2023 3may2023 26jul2023 18sep2024 7nov2024 18dec2024 17sep2025 29oct2025 10dec2025 {
	replace fomc = 1 if inrange(date, td(`d'), td(`d') + 3)
}
drop if fomc == 1

collapse (mean) spread [aw = borrowing_volume], by(date isctd)
bysort date: drop if _N < 2 /*keep days with both groups*/
label define ctd 0 "Not CTD" 1 "CTD"
label values isctd ctd

* the two means over the sample
tabstat spread, by(isctd) stat(mean n)

* time series on the left, bar chart on the right
tw (line spread date if isctd==1)(line spread date if isctd==0), legend(order(1 "CTD" 2 "Not CTD") pos(6) rows(1)) ytitle("Borrowing repo rate minus SOFR, bp") xtitle("") yline(0) name(ts, replace)
graph bar (mean) spread, over(isctd) ytitle("Borrowing repo rate minus SOFR, bp") name(bar, replace)
graph combine ts bar, cols(2)
