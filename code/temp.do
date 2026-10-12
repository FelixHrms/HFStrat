clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. On the run status of CTD bonds against all other bonds held by funds, US only, weighted by borrowing positions
* the on the run number ranks the lines of a country, bond type and maturity group by issue date, 1 is the newest
* four classes, first, second and third on the run and off the run, the outcome is the position weighted share of each class within the CTD and the non CTD book

use "$int/sftds.dta", clear
keep if country == "US" & borrowing_volume > 0
keep date isin borrowing_volume
merge m:1 date isin using "$int/sftds_agg.dta", keep(match) keepusing(isctd otr_number) nogen
count if missing(otr_number)
drop if missing(otr_number)
gen otrclass = min(otr_number, 4)

* share of each class in the positions of the group on the day
collapse (sum) borrowing_volume, by(date isctd otrclass)
bysort date isctd: egen total = sum(borrowing_volume)
gen share = borrowing_volume/total
keep date isctd otrclass share
reshape wide share, i(date isctd) j(otrclass)
foreach k in 1 2 3 4 {
	replace share`k' = 0 if missing(share`k')
}
bysort date: drop if _N < 2 /*keep days with both groups*/
label define ctdlab 0 "Not CTD" 1 "CTD"
label values isctd ctdlab

* stacked shares over time on the left, one panel per group, the first on the run at the bottom
gen c1 = share1
gen c2 = c1 + share2
gen c3 = c2 + share3
gen c4 = 1
tw (area c4 date)(area c3 date)(area c2 date)(area c1 date), by(isctd, rows(1) note("") legend(pos(6))) ///
	legend(order(4 "First" 3 "Second" 2 "Third" 1 "Off the run") rows(1)) ytitle("Share of positions") xtitle("") name(ts, replace)

* mean share of each class by group with Newey West standard errors over 20 trading days
foreach g in 0 1 {
	preserve
		keep if isctd == `g'
		sort date
		gen t = _n
		tsset t
		foreach k in 1 2 3 4 {
			newey share`k', lag(20)
			local m`g'`k' = _b[_cons]
			local s`g'`k' = _se[_cons]
		}
	restore
}

* grouped bars, CTD on the left of each pair as in the other charts
clear
set obs 8
gen isctd = _n > 4
gen otrclass = mod(_n - 1, 4) + 1
gen mean = .
gen se = .
foreach g in 0 1 {
	foreach k in 1 2 3 4 {
		replace mean = `m`g'`k'' if isctd == `g' & otrclass == `k'
		replace se = `s`g'`k'' if isctd == `g' & otrclass == `k'
	}
}
gen lo = mean - 1.96*se
gen hi = mean + 1.96*se
gen x = otrclass + cond(isctd == 1, -0.2, 0.2)
tw (bar mean x if isctd == 1, barwidth(0.35))(bar mean x if isctd == 0, barwidth(0.35))(rcap lo hi x, lcolor(black)), ///
	xlabel(1 "First" 2 "Second" 3 "Third" 4 "Off the run") xtitle("") yscale(range(0)) ylabel(#5) ytitle("Share of positions") legend(order(1 "CTD" 2 "Not CTD") pos(6) rows(1)) name(bar, replace)
graph combine ts bar, cols(2)
