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

**# Euro area, repo rate of CTD bonds against all other bonds as a spread over ESTR, by side, overnight positions, weighted by fund positions
* funds are short the cash bond for most of the sample and lend cash against it, so the lending side carries the trade there, the borrowing side carries it after the flip

* ESTR, day month year dates
import delimited "$data/ESTR.csv", varnames(1) clear
gen date2 = date(date, "DMY")
drop date
rename date2 date
format date %td
keep date estr
tempfile estr
save `estr'

use "$int/sftds.dta", clear
keep if country != "US"
keep date entity_id isin borrowing_volume lending_volume borrowing_rate lending_rate borrowing_term lending_term
rename (borrowing_volume lending_volume borrowing_rate lending_rate borrowing_term lending_term) (volume1 volume0 rate1 rate0 term1 term0)
gen id = _n
reshape long volume rate term, i(id) j(borrowing)
keep if !missing(rate) & volume > 0 & term <= 1 /*overnight positions only*/
merge m:1 date isin using "$int/sftds_agg.dta", keep(match) keepusing(isctd) nogen
merge m:1 date using `estr', keep(match) nogen
gen spread = (rate - estr)*100 /*basis points*/

* drop the days around ECB rate changes, the decision Thursday through the Wednesday a week later when the new rate applies and two days beyond
gen ecb = 0
foreach d in 21jul2022 8sep2022 27oct2022 15dec2022 2feb2023 16mar2023 4may2023 15jun2023 27jul2023 14sep2023 6jun2024 12sep2024 17oct2024 12dec2024 30jan2025 6mar2025 17apr2025 5jun2025 {
	replace ecb = 1 if inrange(date, td(`d'), td(`d') + 9)
}
drop if ecb == 1

* trim the fund bond day spreads at the first and last percentile within year and side
gen year = year(date)
bysort year borrowing: egen p1 = pctile(spread), p(1)
bysort year borrowing: egen p99 = pctile(spread), p(99)
drop if spread < p1 | spread > p99

collapse (mean) spread [aw = volume], by(date borrowing isctd)
keep if date >= td(1jan2024) /*after the collateral scarcity period*/
label define ctd 0 "Not CTD" 1 "CTD"
label values isctd ctd
tempfile daily
save `daily'

* lending on top and borrowing below, time series on the left and means with Newey West bands on the right
foreach s in 0 1 {
	local lab = cond(`s' == 1, "Borrowing", "Lending")
	use `daily', clear
	keep if borrowing == `s'
	bysort date: drop if _N < 2 /*keep days with both groups*/
	di as text _n "`lab' side"
	tabstat spread, by(isctd) stat(mean n)
	tw (line spread date if isctd==1)(line spread date if isctd==0), legend(order(1 "CTD" 2 "Not CTD") pos(6) rows(1)) ytitle("`lab' rate minus ESTR, bp") xtitle("") yline(0) title("`lab'") name(ts`s', replace)
	reshape wide spread, i(date) j(isctd)
	sort date
	gen t = _n
	tsset t
	foreach g in 0 1 {
		newey spread`g', lag(20)
		local m`g' = _b[_cons]
		local s`g' = _se[_cons]
	}
	gen gap = spread1 - spread0
	newey gap, lag(20)
	clear
	set obs 2
	gen isctd = _n - 1
	gen mean = cond(isctd == 1, `m1', `m0')
	gen se = cond(isctd == 1, `s1', `s0')
	gen lo = mean - 1.96*se
	gen hi = mean + 1.96*se
	gen x = 1 - isctd
	tw (bar mean x if isctd == 1, barwidth(0.6))(bar mean x if isctd == 0, barwidth(0.6))(rcap lo hi x, lcolor(black)), xlabel(0 "CTD" 1 "Not CTD") xtitle("") ylabel(#5) ytitle("`lab' rate minus ESTR, bp") legend(off) title("`lab'") name(bar`s', replace)
}
graph combine ts0 bar0 ts1 bar1, cols(2)
