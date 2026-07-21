import delimited "C:\Users\hermesf\Projects\HF_Strategies\key dataframe\sftds_dataframe.csv", clear
count

* convert business_date (string) to a proper Stata daily date called 'date'
gen date = date(business_date, "YMD")
format date %td
drop business_date

rename security_isin isin

preserve
import delimited "C:\Users\hermesf\Projects\HF_Strategies\key dataframe\fund_countries.csv", ///
    varnames(1) clear
keep entity_id fund_country
duplicates drop
tempfile fund_countries
save `fund_countries'
restore

merge m:1 entity_id using `fund_countries', ///
    keep(master match) nogen

merge m:1 isin date using "C:\Users\hermesf\Projects\HF_Strategies\key dataframe\bond_day.dta", ///
    keepusing(otr_number CUSIP) keep(master match) nogen
count

rename CUSIP cusip
count

gen otr1 = (otr_number == 1) if !missing(otr_number)
replace otr1 = 0 if missing(otr1)
drop otr_number

* truncate cusip to match basis_stacked's format 
gen cusip_short = substr(cusip, 1, 8)

preserve
use "C:\Users\hermesf\Projects\HF_Strategies\key dataframe\basis_stacked.dta", clear
keep cusip Date
duplicates drop
rename cusip cusip_short
tempfile basis_unique
save `basis_unique'
restore

rename date Date
merge m:1 cusip_short Date using `basis_unique', ///
    keep(master match) generate(_m_ctd)
rename Date date
count

* == 3 indicates a match (1 would be master, 2 would be other side)
gen ctd = (_m_ctd == 3)
drop _m_ctd cusip_short

* those without a cusip seem to be bonds that have already matured but are still showing up in SFTDS
drop if missing(cusip) 

gen gross_pos = (borrowing_volume + lending_volume)/1e9
gen net_pos = (borrowing_volume - lending_volume)/1e9

gen ccy = substr(isin, 1, 2) == "US"


* ============================================================
* OTR only
* ============================================================

* GROSS POSITION
preserve

collapse (sum) gross_pos, by(date otr1 ccy)

reshape wide gross_pos, i(date ccy) j(otr1)

replace gross_pos0 = 0 if missing(gross_pos0)
replace gross_pos1 = 0 if missing(gross_pos1)

gen total = gross_pos1 + gross_pos0

twoway (area total date if ccy == 1, color(navy)) ///
       (area gross_pos1 date if ccy == 1, color(orange)), ///
    ytitle("Gross position (billions)") xtitle("") ///
    title("USD") ///
    legend(order(2 "on-the-run" 1 "not on-the-run") position(6) rows(1)) ///
    name(usa, replace)

twoway (area total date if ccy == 0, color(navy)) ///
       (area gross_pos1 date if ccy == 0, color(orange)), ///
    ytitle("Gross position (billions)") xtitle("") ///
    title("EUR") ///
    legend(order(2 "on-the-run" 1 "not on-the-run") position(6) rows(1)) ///
    name(nonus, replace)

restore

* in percentage
preserve

collapse (sum) gross_pos, by(date otr1 ccy)

reshape wide gross_pos, i(date ccy) j(otr1)

replace gross_pos0 = 0 if missing(gross_pos0)
replace gross_pos1 = 0 if missing(gross_pos1)

gen total = gross_pos1 + gross_pos0
gen share1 = 100 * gross_pos1 / total
gen share_total = 100

twoway (area share_total date if ccy == 1, color(navy)) ///
       (area share1 date if ccy == 1, color(orange)), ///
    ytitle("Share of gross position (%)") xtitle("") ///
    ylabel(0(20)100) ///
    title("USD") ///
    legend(order(2 "on-the-run" 1 "not on-the-run") position(6) rows(1)) ///
    name(us_pct, replace)

twoway (area share_total date if ccy == 0, color(navy)) ///
       (area share1 date if ccy == 0, color(orange)), ///
    ytitle("Share of gross position (%)") xtitle("") ///
    ylabel(0(20)100) ///
    title("EUR") ///
    legend(order(2 "on-the-run" 1 "not on-the-run") position(6) rows(1)) ///
    name(nonus_pct, replace)

restore


* Net position area graph
preserve

collapse (sum) net_pos, by(date otr1 ccy)
reshape wide net_pos, i(date ccy) j(otr1)
replace net_pos0 = 0 if missing(net_pos0)
replace net_pos1 = 0 if missing(net_pos1)
gen total = net_pos0 + net_pos1
twoway (area net_pos0 date if ccy == 1, color(navy%60)) ///
       (area net_pos1 date if ccy == 1, color(orange%60)) ///
       (line total date if ccy == 1, lcolor(black) lwidth(medium)), ///
    ytitle("Net position (billions)") xtitle("") ///
    yline(0, lcolor(black) lwidth(thin)) ///
    title("USD") ///
    legend(order(2 "on-the-run" 1 "not on-the-run" 3 "total") position(6) rows(1)) ///
    name(us_net, replace)
twoway (area net_pos0 date if ccy == 0, color(navy%60)) ///
       (area net_pos1 date if ccy == 0, color(orange%60)) ///
       (line total date if ccy == 0, lcolor(black) lwidth(medium)), ///
    ytitle("Net position (billions)") xtitle("") ///
    yline(0, lcolor(black) lwidth(thin)) ///
    title("EUR") ///
    legend(order(2 "on-the-run" 1 "not on-the-run" 3 "total") position(6) rows(1)) ///
    name(nonus_net, replace)
restore


* ============================================================
* CTD only
* ============================================================

* Creating area graph
preserve

collapse (sum) gross_pos, by(date ctd ccy)

reshape wide gross_pos, i(date ccy) j(ctd)

replace gross_pos0 = 0 if missing(gross_pos0)
replace gross_pos1 = 0 if missing(gross_pos1)

gen total = gross_pos1 + gross_pos0

twoway (area total date if ccy == 1, color(navy)) ///
       (area gross_pos1 date if ccy == 1, color(orange)), ///
    ytitle("Gross position (billions)") xtitle("") ///
    title("USD") ///
    legend(order(2 "CTD" 1 "not CTD") position(6) rows(1)) ///
    name(usa, replace)

twoway (area total date if ccy == 0, color(navy)) ///
       (area gross_pos1 date if ccy == 0, color(orange)), ///
    ytitle("Gross position (billions)") xtitle("") ///
    title("EUR") ///
    legend(order(2 "CTD" 1 "not CTD") position(6) rows(1)) ///
    name(nonus, replace)

restore

* in percentage
preserve

collapse (sum) gross_pos, by(date ctd ccy)

reshape wide gross_pos, i(date ccy) j(ctd)

replace gross_pos0 = 0 if missing(gross_pos0)
replace gross_pos1 = 0 if missing(gross_pos1)

gen total = gross_pos1 + gross_pos0
gen share1 = 100 * gross_pos1 / total
gen share_total = 100

twoway (area share_total date if ccy == 1, color(navy)) ///
       (area share1 date if ccy == 1, color(orange)), ///
    ytitle("Share of gross position (%)") xtitle("") ///
    ylabel(0(20)100) ///
    title("USD") ///
    legend(order(2 "CTD" 1 "not CTD") position(6) rows(1)) ///
    name(us_pct, replace)

twoway (area share_total date if ccy == 0, color(navy)) ///
       (area share1 date if ccy == 0, color(orange)), ///
    ytitle("Share of gross position (%)") xtitle("") ///
    ylabel(0(20)100) ///
    title("EUR") ///
    legend(order(2 "CTD" 1 "not CTD") position(6) rows(1)) ///
    name(nonus_pct, replace)

restore


* Net position area graph
preserve

collapse (sum) net_pos, by(date ctd ccy)
reshape wide net_pos, i(date ccy) j(ctd)
replace net_pos0 = 0 if missing(net_pos0)
replace net_pos1 = 0 if missing(net_pos1)
gen total = net_pos0 + net_pos1
twoway (area net_pos0 date if ccy == 1, color(navy%60)) ///
       (area net_pos1 date if ccy == 1, color(orange%60)) ///
       (line total date if ccy == 1, lcolor(black) lwidth(medium)), ///
    ytitle("Net position (billions)") xtitle("") ///
    yline(0, lcolor(black) lwidth(thin)) ///
    title("USD") ///
    legend(order(2 "on-the-run" 1 "not on-the-run" 3 "total") position(6) rows(1)) ///
    name(us_net, replace)
twoway (area net_pos0 date if ccy == 0, color(navy%60)) ///
       (area net_pos1 date if ccy == 0, color(orange%60)) ///
       (line total date if ccy == 0, lcolor(black) lwidth(medium)), ///
    ytitle("Net position (billions)") xtitle("") ///
    yline(0, lcolor(black) lwidth(thin)) ///
    title("EUR") ///
    legend(order(2 "CTD" 1 "not CTD" 3 "total") position(6) rows(1)) ///
    name(nonus_net, replace)
restore




* Net position area graph - Germany
preserve
gen germany = substr(isin, 1, 2) == "DE"
keep if fund_country == "KY" | bank_indicator == 1
collapse (sum) net_pos, by(date ctd germany)
reshape wide net_pos, i(date germany) j(ctd)
replace net_pos0 = 0 if missing(net_pos0)
replace net_pos1 = 0 if missing(net_pos1)
gen total = net_pos0 + net_pos1

twoway (area net_pos0 date if germany == 1, color(navy%60)) ///
       (area net_pos1 date if germany == 1, color(orange%60)) ///
       (line total date if germany == 1, lcolor(black) lwidth(medium)), ///
    ytitle("Net position (billions)") xtitle("") ///
    yline(0, lcolor(black) lwidth(thin)) ///
    title("EUR - Germany") ///
    legend(order(2 "CTD" 1 "not CTD" 3 "total") position(6) rows(1)) ///
    name(germany_net, replace)
restore



* ============================================================
* both
* ============================================================

preserve
gen active = (otr1 == 1 | ctd == 1)
collapse (sum) gross_pos, by(date active ccy)
reshape wide gross_pos, i(date ccy) j(active)
replace gross_pos0 = 0 if missing(gross_pos0)
replace gross_pos1 = 0 if missing(gross_pos1)
gen total = gross_pos1 + gross_pos0
gen share1 = 100 * gross_pos1 / total
gen share_total = 100
twoway (area share_total date if ccy == 1, color(navy)) ///
       (area share1 date if ccy == 1, color(orange)), ///
    ytitle("Share of gross position (%)") xtitle("") ///
    ylabel(0(20)100) ///
    title("USD") ///
    legend(order(2 "OTR or CTD" 1 "neither") position(6) rows(1)) ///
    name(us_pct, replace)
twoway (area share_total date if ccy == 0, color(navy)) ///
       (area share1 date if ccy == 0, color(orange)), ///
    ytitle("Share of gross position (%)") xtitle("") ///
    ylabel(0(20)100) ///
    title("EUR") ///
    legend(order(2 "OTR or CTD" 1 "neither") position(6) rows(1)) ///
    name(nonus_pct, replace)
restore


