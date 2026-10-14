clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. Does the carry survive the funding cost, a proxy for the cash futures disconnect against the repo spread hedge funds pay, US
* a long basis position earns the implied repo of the futures and pays the repo rate on the bond, so the trade carries when the implied repo exceeds the funding rate
* Bloomberg's implied repo appears to run to the last delivery day, while a trader delivers on the first day whenever carry is negative, as from 2023
* the implied repo to the first day follows from the one to the last day with only the coupon of the CTD, since the invoice price differs by one month of accrual, the trader takes the better of the two
* second contracts as in Barth and Kahn, three to six months to delivery, benchmark the SOFR realized from the date to the chosen delivery day, averaged over the six contracts, the funding spread as in the repo chart

* SOFR, date in the second column and the rate in percent in the fourth, and its cumulative sum on calendar days for realized averages
import delimited "$data/SOFR.csv", varnames(nonames) rowrange(2) clear
keep v2 v4
rename (v2 v4) (sofrdate sofr)
gen date = date(sofrdate, "YMD")
format date %td
destring sofr, replace
keep date sofr
tempfile sofr
save `sofr'
tsset date
tsfill
replace sofr = sofr[_n-1] if missing(sofr)
gen cum = sum(sofr)
keep date cum
tempfile cum
save `cum'

* the raw Bloomberg file, one header row, dates written month first, five fields per generic contract, keep the second contracts
import delimited "$data/usbasis.csv", varnames(1) clear
rename date datestr
gen date = date(datestr, "MDY")
format date %td
drop datestr
tempfile raw
local first = 1
foreach b in ty2 fv2 tu2 uxy2 wn2 us2 {
	preserve
		keep date `b'_fut_implied_repo_rt `b'_fut_cur_gen_ticker `b'_fut_ctd_cusip
		rename (`b'_fut_implied_repo_rt `b'_fut_cur_gen_ticker `b'_fut_ctd_cusip) (implied_repo contract cusip8)
		capture destring implied_repo, replace force
		gen root = upper(substr("`b'", 1, strlen("`b'") - 1))
		if `first' == 0 append using `raw'
		save `raw', replace
	restore
	local first = 0
}
use `raw', clear
drop if missing(implied_repo) | missing(date)
keep if inrange(date, td(04jan2021), td(30sep2025))

* delivery month from the ticker, first delivery day the first of the month, last delivery day the last of the month
gen mcode = ustrregexs(1) if ustrregexm(contract, "^[A-Z]+([HMUZ])[0-9]{1,2}$")
gen ydig = ustrregexs(1) if ustrregexm(contract, "^[A-Z]+[HMUZ]([0-9]{1,2})$")
gen dmonth = cond(mcode == "H", 3, cond(mcode == "M", 6, cond(mcode == "U", 9, 12)))
gen dyear = cond(strlen(ydig) == 2, 2000 + real(ydig), 2020 + real(ydig))
gen firstdelivery = mdy(dmonth, 1, dyear)
gen lastdelivery = dofm(mofd(firstdelivery) + 1) - 1
format firstdelivery lastdelivery %td
gen dfirst = firstdelivery - date
gen dlast = lastdelivery - date
keep if dfirst > 30

* coupon and price of the CTD from the bond day panel
merge m:1 date cusip8 using "$key/bond_day.dta", keep(1 3) keepusing(couponrate refprice) nogen
count if missing(couponrate)
replace refprice = 100 if missing(refprice)
gen cy = couponrate/refprice*100 /*current yield in percent*/

* implied repo to the first delivery day from the one to the last, the trader takes the better of the two
gen irr_last = implied_repo
gen irr_first = (irr_last*dlast - cy*(dlast - dfirst))/dfirst
gen irr_best = max(irr_first, irr_last)
gen delivery = cond(irr_first > irr_last, firstdelivery, lastdelivery)
format delivery %td

* SOFR realized from the date to the chosen delivery day
merge m:1 date using `cum', keep(match) nogen
rename cum cum0
rename date date0
rename delivery date
merge m:1 date using `cum', keep(1 3) nogen
rename cum cum1
rename date delivery
rename date0 date
gen sofr_real = (cum1 - cum0)/(delivery - date) /*missing when delivery lies beyond the SOFR series*/
merge m:1 date using `sofr', keep(match) nogen

* the disconnect, raw and adjusted, against spot and realized SOFR, by year and root
gen year = year(date)
gen dis_raw = (irr_last - sofr)*100
gen dis_adj = (irr_best - sofr)*100
gen dis_adj_real = (irr_best - sofr_real)*100
table year root, stat(median dis_raw) nformat(%6.0f)
table year root, stat(median dis_adj) nformat(%6.0f)
table year root, stat(median dis_adj_real) nformat(%6.0f)
tab year delivery if delivery == firstdelivery, nofreq
* one line, the average over the six contracts with equal weights per day
collapse (mean) disconnect = dis_adj_real, by(date)
tempfile dis
save `dis'

* the repo spread funds pay, overnight borrowing positions
use "$int/sftds.dta", clear
keep if country == "US" & !missing(borrowing_rate) & borrowing_volume > 0 & borrowing_term <= 1
keep date isin borrowing_volume borrowing_rate
merge m:1 date using `sofr', keep(match) nogen
gen spread = (borrowing_rate - sofr)*100
gen fomc = 0
foreach d in 16mar2022 4may2022 15jun2022 27jul2022 21sep2022 2nov2022 14dec2022 1feb2023 22mar2023 3may2023 26jul2023 18sep2024 7nov2024 18dec2024 17sep2025 29oct2025 10dec2025 {
	replace fomc = 1 if inrange(date, td(`d'), td(`d') + 3)
}
drop if fomc == 1
gen year = year(date)
bysort year: egen p1 = pctile(spread), p(1)
bysort year: egen p99 = pctile(spread), p(99)
drop if spread < p1 | spread > p99
collapse (mean) spread [aw = borrowing_volume], by(date)
merge 1:1 date using `dis', keep(match) nogen

* the average disconnect against the funding spread, both over SOFR, the gap between the two lines is the carry net of funding
tw (line disconnect date)(line spread date, lc(black) lw(medthick)), ///
	legend(order(1 "Implied repo of the futures, average over the six contracts" 2 "Repo spread paid by funds") pos(6) cols(1) size(small) symxsize(6)) ///
	ytitle("Rate minus SOFR, bp") xtitle("") yline(0)

* the carry net of funding, mean with Newey West standard errors over 20 trading days
gen carry = disconnect - spread
keep if !missing(carry)
sort date
gen long t = _n
tsset t
newey carry, lag(20)
