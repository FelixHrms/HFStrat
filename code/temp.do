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

**# Haircut of CTD bonds against all other bonds, US only, overnight positions, weighted by fund positions
* the haircut is the average over the fund's borrowing trades in the bond on the day, as reported in the SFTDS

* coverage of the source file by month without the term filter, rows, rows with a term and overnight rows, and whether the day survives in the aggregate panel
use "$int/sftds.dta", clear
keep if country == "US" & borrowing_volume > 0
merge m:1 date isin using "$int/sftds_agg.dta", keep(master match) keepusing(isctd)
gen month = mofd(date)
format month %tm
gen hasterm = !missing(borrowing_term)
gen overnight = borrowing_term <= 1
gen inagg = _merge == 3
tabstat borrowing_term if inrange(month, tm(2024m10), tm(2025m5)), by(month) stat(min p5 p50 p95 max n) col(stat)
collapse (count) n = borrowing_volume (sum) hasterm overnight inagg, by(month)
list, noobs

use "$int/sftds.dta", clear
keep if country == "US" & borrowing_volume > 0 & borrowing_term <= 1 /*overnight positions only*/
keep date isin borrowing_volume borrowing_haircut
merge m:1 date isin using "$int/sftds_agg.dta", keep(match) keepusing(isctd) nogen
label define ctd 0 "Not CTD" 1 "CTD"
label values isctd ctd

* coverage by month, overnight fund bond days and how many of them carry a haircut, suffix 1 for CTD and 0 for the rest
preserve
	gen month = mofd(date)
	format month %tm
	gen hashc = !missing(borrowing_haircut)
	collapse (count) n = borrowing_volume (sum) nhc = hashc, by(month isctd)
	reshape wide n nhc, i(month) j(isctd)
	list month n0 nhc0 n1 nhc1, noobs
restore
keep if !missing(borrowing_haircut)

* distribution of the raw haircuts
tabstat borrowing_haircut, by(isctd) stat(min p1 p5 p50 p95 p99 max n) col(stat)

collapse (mean) haircut = borrowing_haircut [aw = borrowing_volume], by(date isctd)
bysort date: drop if _N < 2 /*keep days with both groups*/

* the two means over the sample
tabstat haircut, by(isctd) stat(mean n)

* time series on the left, means with 95 percent confidence bands on the right
tw (line haircut date if isctd==1)(line haircut date if isctd==0), legend(order(1 "CTD" 2 "Not CTD") pos(6) rows(1)) ytitle("Haircut, percent") xtitle("") yline(0) name(ts, replace)

* means and the gap with Newey West standard errors over 20 trading days, the daily haircuts are autocorrelated
reshape wide haircut, i(date) j(isctd)
sort date
gen t = _n
tsset t
foreach g in 0 1 {
	newey haircut`g', lag(20)
	local m`g' = _b[_cons]
	local s`g' = _se[_cons]
}
gen gap = haircut1 - haircut0
newey gap, lag(20)

* CTD on the left as in the legend of the time series, one bar plot per group so the colours follow the same order as the lines
clear
set obs 2
gen isctd = _n - 1
gen mean = cond(isctd == 1, `m1', `m0')
gen se = cond(isctd == 1, `s1', `s0')
gen lo = mean - 1.96*se
gen hi = mean + 1.96*se
gen x = 1 - isctd
tw (bar mean x if isctd == 1, barwidth(0.6))(bar mean x if isctd == 0, barwidth(0.6))(rcap lo hi x, lcolor(black)), xlabel(0 "CTD" 1 "Not CTD") xtitle("") yscale(range(0)) ylabel(#5) ytitle("Haircut, percent") legend(off) name(bar, replace)
graph combine ts bar, cols(2)
