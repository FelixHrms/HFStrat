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
keep if country == "US" & !missing(borrowing_rate) & borrowing_volume > 0
keep date entity_id isin borrowing_volume borrowing_rate borrowing_term
merge m:1 date isin using "$int/sftds_agg.dta", keep(match) keepusing(isctd) nogen
label define ctd 0 "Not CTD" 1 "CTD"
label values isctd ctd

* share of borrowing volume by term, the term is the average contractual maturity in days and is missing for open positions
gen termgroup = cond(missing(borrowing_term), 2, cond(borrowing_term <= 1, 1, 3))
label define termgroup 1 "Overnight" 2 "Open" 3 "Term"
label values termgroup termgroup
tab termgroup [aw = borrowing_volume]

* term by CTD, share of volume in each term group and the average term of the term positions
tab isctd termgroup [aw = borrowing_volume], row nofreq
tabstat borrowing_term [aw = borrowing_volume] if termgroup == 3, by(isctd) stat(mean p50 n)

* keep overnight positions only, their rates are set fresh every day, term positions carry the rate of their start date and open positions may have a notice period
keep if termgroup == 1
merge m:1 date using `sofr', keep(match) nogen
gen spread = (borrowing_rate - sofr)*100 /*basis points*/

* drop the days around FOMC rate changes, the decision day and the three days after, SOFR moves the day after the decision and the reported rates lag
gen fomc = 0
foreach d in 16mar2022 4may2022 15jun2022 27jul2022 21sep2022 2nov2022 14dec2022 1feb2023 22mar2023 3may2023 26jul2023 18sep2024 7nov2024 18dec2024 17sep2025 29oct2025 10dec2025 {
	replace fomc = 1 if inrange(date, td(`d'), td(`d') + 3)
}
drop if fomc == 1

* trim the fund bond day spreads at the first and last percentile within each year, reporting errors in single rates pull the daily averages far off
gen year = year(date)
bysort year: egen p1 = pctile(spread), p(1)
bysort year: egen p99 = pctile(spread), p(99)
drop if spread < p1 | spread > p99

* diagnostics for the spikes in the CTD line, the 25 days with the largest absolute CTD spread and what sits behind them
* npos, nfunds and nbonds are the positions, funds and bonds in the CTD group, maxshare the share of the largest position in its volume
* dsofr is the change in SOFR from the previous day, eom flags the last three days of a month, dlv a futures delivery month and fnd a first notice month
preserve
	bysort date isctd: egen npos = count(spread)
	bysort date isctd: egen nfunds = nvals(entity_id)
	bysort date isctd: egen nbonds = nvals(isin)
	bysort date isctd: egen voltot = total(borrowing_volume)
	gen share = borrowing_volume/voltot
	bysort date isctd: egen maxshare = max(share)
	collapse (mean) spread (first) npos nfunds nbonds maxshare sofr [aw = borrowing_volume], by(date isctd)
	keep if isctd == 1
	sort date
	gen dsofr = (sofr - sofr[_n-1])*100
	gen eom = day(date) > day(dofm(mofd(date) + 1) - 1) - 3
	gen dlv = inlist(month(date), 3, 6, 9, 12)
	gen fnd = inlist(month(date), 2, 5, 8, 11)
	gen absspread = abs(spread)
	gsort -absspread
	format spread dsofr maxshare %6.1f
	list date spread dsofr npos nfunds nbonds maxshare eom dlv fnd in 1/25, noobs
restore

collapse (mean) spread [aw = borrowing_volume], by(date isctd)
bysort date: drop if _N < 2 /*keep days with both groups*/

* the two means over the sample
tabstat spread, by(isctd) stat(mean n)

* time series on the left, means with 95 percent confidence bands on the right
tw (line spread date if isctd==1)(line spread date if isctd==0), legend(order(1 "CTD" 2 "Not CTD") pos(6) rows(1)) ytitle("Borrowing repo rate minus SOFR, bp") xtitle("") yline(0) name(ts, replace)

* means and the gap with Newey West standard errors over 20 trading days, the daily spreads are autocorrelated
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

* CTD on the left as in the legend of the time series, one bar plot per group so the colours follow the same order as the lines
clear
set obs 2
gen isctd = _n - 1
gen mean = cond(isctd == 1, `m1', `m0')
gen se = cond(isctd == 1, `s1', `s0')
gen lo = mean - 1.96*se
gen hi = mean + 1.96*se
gen x = 1 - isctd
tw (bar mean x if isctd == 1, barwidth(0.6))(bar mean x if isctd == 0, barwidth(0.6))(rcap lo hi x, lcolor(black)), xlabel(0 "CTD" 1 "Not CTD") xtitle("") yscale(range(0)) ylabel(#5) ytitle("Borrowing repo rate minus SOFR, bp") legend(off) name(bar, replace)
graph combine ts bar, cols(2)
