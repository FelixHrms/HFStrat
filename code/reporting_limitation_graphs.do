* ============================================================
* DE: Average net position by country group
* ============================================================

drop _all
clear all 

import delimited "C:\\Users\\hermesf\\Projects\\HF_Strategies\\Data\\germany_fund_location.csv", clear

* --- pre-2023 ---
preserve
keep if business_date < "2023-01-01"

* --- Step 1: sum net_pos within (date, group) ---
collapse (sum) net_pos, by(business_date group)

* --- Step 2: average across dates within group ---
collapse (mean) net_pos, by(group)

* --- Impose plotting order (top -> bottom) ---
gen order = .
replace order = 1 if group == "DE"
replace order = 2 if group == "FR"
replace order = 3 if group == "IE"
replace order = 4 if group == "LU"
replace order = 5 if group == "Other EA"
replace order = 6 if group == "GB"
replace order = 7 if group == "KY"
replace order = 8 if group == "Other non-EA"

* Color split: positive = green, negative = red
gen pos = net_pos if net_pos >= 0
gen neg = net_pos if net_pos <  0

* Total for the title
sum net_pos, meanonly
local total : display %12.0fc r(sum)

* --- Horizontal bar chart ---
graph hbar (asis) pos neg, ///
    over(group, sort(order)) ///
    bar(1, color(green%85)) ///
    bar(2, color(red%85)) ///
    blabel(bar, format(%12.0fc)) ///
    legend(off) ///
    ytitle("Average net position") ///
    title("DE: Average net position by country group (2021 & 2022)") ///
    subtitle("Net total: `total'") ///
    yline(0, lcolor(black)) ///
	yscale(range(-35 5))

restore


* --- post-2025 ---
preserve
keep if business_date > "2025-01-01"

* --- Step 1: sum net_pos within (date, group) ---
collapse (sum) net_pos, by(business_date group)

* --- Step 2: average across dates within group ---
collapse (mean) net_pos, by(group)

* --- Impose plotting order (top -> bottom) ---
gen order = .
replace order = 1 if group == "DE"
replace order = 2 if group == "FR"
replace order = 3 if group == "IE"
replace order = 4 if group == "LU"
replace order = 5 if group == "Other EA"
replace order = 6 if group == "GB"
replace order = 7 if group == "KY"
replace order = 8 if group == "Other non-EA"

* Color split: positive = green, negative = red
gen pos = net_pos if net_pos >= 0
gen neg = net_pos if net_pos <  0

* Total for the title
sum net_pos, meanonly
local total : display %12.0fc r(sum)

* --- Horizontal bar chart ---
graph hbar (asis) pos neg, ///
    over(group, sort(order)) ///
    bar(1, color(green%85)) ///
    bar(2, color(red%85)) ///
    blabel(bar, format(%12.0fc)) ///
    legend(off) ///
    ytitle("Average net position") ///
    title("DE: Average net position by country group (2025)") ///
    subtitle("Net total: `total'") ///
    yline(0, lcolor(black)) ///
	yscale(range(-5 35))

restore















* ============================================================
* US: Average net position by country group
* ============================================================

drop _all
clear all 

import delimited "C:\\Users\\hermesf\\Projects\\HF_Strategies\\Data\\us_fund_location.csv", clear

* --- pre-2023 ---
preserve
keep if business_date < "2023-01-01"

* --- Step 1: sum net_pos within (date, group) ---
collapse (sum) net_pos, by(business_date group)

* --- Step 2: average across dates within group ---
collapse (mean) net_pos, by(group)

* --- Impose plotting order (top -> bottom) ---
gen order = .
replace order = 1 if group == "DE"
replace order = 2 if group == "FR"
replace order = 3 if group == "IE"
replace order = 4 if group == "LU"
replace order = 5 if group == "Other EA"
replace order = 6 if group == "GB"
replace order = 7 if group == "KY"
replace order = 8 if group == "Other non-EA"

* Color split: positive = green, negative = red
gen pos = net_pos if net_pos >= 0
gen neg = net_pos if net_pos <  0

* Total for the title
sum net_pos, meanonly
local total : display %12.0fc r(sum)

* --- Horizontal bar chart ---
graph hbar (asis) pos neg, ///
    over(group, sort(order)) ///
    bar(1, color(green%85)) ///
    bar(2, color(red%85)) ///
    blabel(bar, format(%12.0fc)) ///
    legend(off) ///
    ytitle("Average net position") ///
    title("US: Average net position by country group (2021 & 2022)") ///
    subtitle("Net total: `total'") ///
    yline(0, lcolor(black)) ///
	ylabel(-5(2.5)5) ///
	yscale(range(-5 5))

restore


* --- post-2025 ---
preserve
keep if business_date > "2025-01-01"

* --- Step 1: sum net_pos within (date, group) ---
collapse (sum) net_pos, by(business_date group)

* --- Step 2: average across dates within group ---
collapse (mean) net_pos, by(group)

* --- Impose plotting order (top -> bottom) ---
gen order = .
replace order = 1 if group == "DE"
replace order = 2 if group == "FR"
replace order = 3 if group == "IE"
replace order = 4 if group == "LU"
replace order = 5 if group == "Other EA"
replace order = 6 if group == "GB"
replace order = 7 if group == "KY"
replace order = 8 if group == "Other non-EA"

* Color split: positive = green, negative = red
gen pos = net_pos if net_pos >= 0
gen neg = net_pos if net_pos <  0

* Total for the title
sum net_pos, meanonly
local total : display %12.0fc r(sum)

* --- Horizontal bar chart ---
graph hbar (asis) pos neg, ///
    over(group, sort(order)) ///
    bar(1, color(green%85)) ///
    bar(2, color(red%85)) ///
    blabel(bar, format(%12.0fc)) ///
    legend(off) ///
    ytitle("Average net position") ///
    title("US: Average net position by country group (2025)") ///
    subtitle("Net total: `total'") ///
    yline(0, lcolor(black)) ///
	yscale(range(-45 35))

restore






* ============================================================
* Repo and futures net
* ============================================================

drop _all
clear all 

import delimited "C:\\Users\\hermesf\\Projects\\HF_Strategies\\Data\\broadest_netpositions_limitations.csv", clear

gen bdate = date(business_date, "YMD")
format bdate %td
drop business_date
rename bdate business_date

gen net_futures_plot = net_futures
replace net_futures_plot = 400  if net_futures >  400 & !missing(net_futures)
replace net_futures_plot = -400 if net_futures < -400

gen net_repo_plot = net_repo
replace net_repo_plot = 400  if net_repo >  400 & !missing(net_repo)
replace net_repo_plot = -400 if net_repo < -400

twoway ///
    (area net_futures_plot business_date, color(blue%50)) ///
    (area net_repo_plot    business_date, color(orange%50)), ///
    legend(order(1 "Futures positions" 2 "Repo positions") ///
           position(6) rows(1)) ///
    ytitle("Net position") ///
    xtitle("") ///
    title("Net futures and repo positions of UK banks and Cayman funds") ///
    yline(0, lcolor(black)) ///
    ylabel(-400(100)400)
	
	
	
	
	
	
	
* ============================================================
* Repo and futures net - DE
* ============================================================

drop _all
clear all 

import delimited "C:\\Users\\hermesf\\Projects\\HF_Strategies\\Data\\DE_netpositions_limitations.csv", clear

gen bdate = date(business_date, "YMD")
format bdate %td
drop business_date
rename bdate business_date

gen net_futures_plot = net_futures
replace net_futures_plot = 400  if net_futures >  400 & !missing(net_futures)
replace net_futures_plot = -400 if net_futures < -400

gen net_repo_plot = net_repo
replace net_repo_plot = 400  if net_repo >  400 & !missing(net_repo)
replace net_repo_plot = -400 if net_repo < -400

twoway ///
    (area net_futures_plot business_date, color(blue%50)) ///
    (area net_repo_plot    business_date, color(orange%50)), ///
    legend(order(1 "Futures positions" 2 "Repo positions") ///
           position(6) rows(1)) ///
    ytitle("Net position") ///
    xtitle("") ///
    title("Net german futures and repo positions of UK banks and Cayman funds") ///
    yline(0, lcolor(black)) ///
    ylabel(-400(100)400)
	
	
	
* ============================================================
* Repo and futures net - IT
* ============================================================

drop _all
clear all 

import delimited "C:\\Users\\hermesf\\Projects\\HF_Strategies\\Data\\IT_netpositions_limitations.csv", clear

gen bdate = date(business_date, "YMD")
format bdate %td
drop business_date
rename bdate business_date

gen net_futures_plot = net_futures
replace net_futures_plot = 400  if net_futures >  400 & !missing(net_futures)
replace net_futures_plot = -400 if net_futures < -400

gen net_repo_plot = net_repo
replace net_repo_plot = 400  if net_repo >  400 & !missing(net_repo)
replace net_repo_plot = -400 if net_repo < -400

twoway ///
    (area net_futures_plot business_date, color(blue%50)) ///
    (area net_repo_plot    business_date, color(orange%50)), ///
    legend(order(1 "Futures positions" 2 "Repo positions") ///
           position(6) rows(1)) ///
    ytitle("Net position") ///
    xtitle("") ///
    title("Net italian futures and repo positions of UK banks and Cayman funds") ///
    yline(0, lcolor(black)) ///
    ylabel(-400(100)400)
	
	
	
	
	
	
	
* ============================================================
* German futures - sectors
* ============================================================

drop _all
clear all 

import delimited "C:\\Users\\hermesf\\Projects\\HF_Strategies\\Data\\sector_breakdown_german_futures.csv", clear


* Convert business_date to Stata date format
gen bdate = date(business_date, "YMD")
format bdate %td
drop business_date
rename bdate business_date
replace sector = subinstr(sector, "-", "", .)

* Reshape so each sector becomes its own variable
reshape wide net long_pos short_pos, i(business_date) j(sector) string
local sectors "BANK_EA BANK_nonEA GOVT_EA GOVT_nonEA HF_EA HF_nonEA ICPF_EA ICPF_nonEA IF_EA IF_nonEA OFI_EA OFI_nonEA Other_EA Other_nonEA"

* Replace missing with 0 so stacking works
foreach s of local sectors {
    replace net`s' = 0 if missing(net`s')
}

* Cumulative stacks: positives go up, negatives go down
gen pos1  = max(netBANK_EA, 0)
gen pos2  = pos1  + max(netBANK_nonEA, 0)
gen pos3  = pos2  + max(netGOVT_EA, 0)
gen pos4  = pos3  + max(netGOVT_nonEA, 0)
gen pos5  = pos4  + max(netHF_EA, 0)
gen pos6  = pos5  + max(netHF_nonEA, 0)
gen pos7  = pos6  + max(netICPF_EA, 0)
gen pos8  = pos7  + max(netICPF_nonEA, 0)
gen pos9  = pos8  + max(netIF_EA, 0)
gen pos10 = pos9  + max(netIF_nonEA, 0)
gen pos11 = pos10 + max(netOFI_EA, 0)
gen pos12 = pos11 + max(netOFI_nonEA, 0)
gen pos13 = pos12 + max(netOther_EA, 0)
gen pos14 = pos13 + max(netOther_nonEA, 0)

gen neg1  = min(netBANK_EA, 0)
gen neg2  = neg1  + min(netBANK_nonEA, 0)
gen neg3  = neg2  + min(netGOVT_EA, 0)
gen neg4  = neg3  + min(netGOVT_nonEA, 0)
gen neg5  = neg4  + min(netHF_EA, 0)
gen neg6  = neg5  + min(netHF_nonEA, 0)
gen neg7  = neg6  + min(netICPF_EA, 0)
gen neg8  = neg7  + min(netICPF_nonEA, 0)
gen neg9  = neg8  + min(netIF_EA, 0)
gen neg10 = neg9  + min(netIF_nonEA, 0)
gen neg11 = neg10 + min(netOFI_EA, 0)
gen neg12 = neg11 + min(netOFI_nonEA, 0)
gen neg13 = neg12 + min(netOther_EA, 0)
gen neg14 = neg13 + min(netOther_nonEA, 0)

* Cap at +/- 500
foreach v of varlist pos1-pos14 {
    replace `v' = 500 if `v' > 500 & !missing(`v')
}
foreach v of varlist neg1-neg14 {
    replace `v' = -500 if `v' < -500 & !missing(`v')
}

* Plot - outermost layers drawn first, inner layers on top
* Color scheme: each sector has a distinct hue; EA = darker, non-EA = lighter
twoway ///
    (area pos14 business_date, color("128 0 128"%70))    /// Other non-EA - light purple
    (area pos13 business_date, color("64 0 64"%70))      /// Other EA - dark purple
    (area pos12 business_date, color("160 82 45"%70))    /// OFI non-EA - light brown
    (area pos11 business_date, color("90 40 20"%70))     /// OFI EA - dark brown
    (area pos10 business_date, color("100 200 100"%70))  /// IF non-EA - light green
    (area pos9  business_date, color("0 100 0"%70))      /// IF EA - dark green
    (area pos8  business_date, color("255 165 0"%70))    /// ICPF non-EA - light orange
    (area pos7  business_date, color("200 80 0"%70))     /// ICPF EA - dark orange
    (area pos6  business_date, color("64 224 208"%70))   /// HF non-EA - light teal
    (area pos5  business_date, color("0 110 110"%70))    /// HF EA - dark teal
    (area pos4  business_date, color("220 20 60"%70))    /// GOVT non-EA - light red
    (area pos3  business_date, color("120 0 20"%70))     /// GOVT EA - dark red
    (area pos2  business_date, color("100 180 230"%70))  /// BANK non-EA - light blue
    (area pos1  business_date, color("0 50 130"%70))     /// BANK EA - dark blue
    (area neg14 business_date, color("128 0 128"%70))    ///
    (area neg13 business_date, color("64 0 64"%70))      ///
    (area neg12 business_date, color("160 82 45"%70))    ///
    (area neg11 business_date, color("90 40 20"%70))     ///
    (area neg10 business_date, color("100 200 100"%70))  ///
    (area neg9  business_date, color("0 100 0"%70))      ///
    (area neg8  business_date, color("255 165 0"%70))    ///
    (area neg7  business_date, color("200 80 0"%70))     ///
    (area neg6  business_date, color("64 224 208"%70))   ///
    (area neg5  business_date, color("0 110 110"%70))    ///
    (area neg4  business_date, color("220 20 60"%70))    ///
    (area neg3  business_date, color("120 0 20"%70))     ///
    (area neg2  business_date, color("100 180 230"%70))  ///
    (area neg1  business_date, color("0 50 130"%70)),    ///
    legend(order(14 "BANK EA" 13 "BANK non-EA" 12 "GOVT EA" 11 "GOVT non-EA" ///
                 10 "HF EA" 9 "HF non-EA" 8 "ICPF EA" 7 "ICPF non-EA" ///
                 6 "IF EA" 5 "IF non-EA" 4 "OFI EA" 3 "OFI non-EA" ///
                 2 "Other EA" 1 "Other non-EA") ///
           position(6) rows(4) size(small)) ///
    ytitle("Net position") ///
    xtitle("") ///
    title("Net German futures positions by sector") ///
    yline(0, lcolor(black)) ///
    ylabel(-500(100)500)
	
	
	
	
* ============================================================
* German futures - sectors
* ============================================================

drop _all
clear all 

import delimited "C:\\Users\\hermesf\\Projects\\HF_Strategies\\Data\\sector_breakdown_german_futures.csv", clear


* Convert business_date to Stata date format
gen bdate = date(business_date, "YMD")
format bdate %td
drop business_date
rename bdate business_date
replace sector = subinstr(sector, "-", "", .)

* Reshape so each sector becomes its own variable
reshape wide net long_pos short_pos, i(business_date) j(sector) string
local sectors "BANK_EA BANK_nonEA GOVT_EA GOVT_nonEA HF_EA HF_nonEA ICPF_EA ICPF_nonEA IF_EA IF_nonEA OFI_EA OFI_nonEA Other_EA Other_nonEA UCIT_EA UCIT_nonEA"

* Replace missing with 0 so stacking works
foreach s of local sectors {
    replace net`s' = 0 if missing(net`s')
}

* Cumulative stacks: positives go up, negatives go down
gen pos1  = max(netBANK_EA, 0)
gen pos2  = pos1  + max(netBANK_nonEA, 0)
gen pos3  = pos2  + max(netGOVT_EA, 0)
gen pos4  = pos3  + max(netGOVT_nonEA, 0)
gen pos5  = pos4  + max(netHF_EA, 0)
gen pos6  = pos5  + max(netHF_nonEA, 0)
gen pos7  = pos6  + max(netICPF_EA, 0)
gen pos8  = pos7  + max(netICPF_nonEA, 0)
gen pos9  = pos8  + max(netIF_EA, 0)
gen pos10 = pos9  + max(netIF_nonEA, 0)
gen pos11 = pos10 + max(netOFI_EA, 0)
gen pos12 = pos11 + max(netOFI_nonEA, 0)
gen pos13 = pos12 + max(netOther_EA, 0)
gen pos14 = pos13 + max(netOther_nonEA, 0)
gen pos15 = pos14 + max(netUCIT_EA, 0)
gen pos16 = pos15 + max(netUCIT_nonEA, 0)

gen neg1  = min(netBANK_EA, 0)
gen neg2  = neg1  + min(netBANK_nonEA, 0)
gen neg3  = neg2  + min(netGOVT_EA, 0)
gen neg4  = neg3  + min(netGOVT_nonEA, 0)
gen neg5  = neg4  + min(netHF_EA, 0)
gen neg6  = neg5  + min(netHF_nonEA, 0)
gen neg7  = neg6  + min(netICPF_EA, 0)
gen neg8  = neg7  + min(netICPF_nonEA, 0)
gen neg9  = neg8  + min(netIF_EA, 0)
gen neg10 = neg9  + min(netIF_nonEA, 0)
gen neg11 = neg10 + min(netOFI_EA, 0)
gen neg12 = neg11 + min(netOFI_nonEA, 0)
gen neg13 = neg12 + min(netOther_EA, 0)
gen neg14 = neg13 + min(netOther_nonEA, 0)
gen neg15 = neg14 + min(netUCIT_EA, 0)
gen neg16 = neg15 + min(netUCIT_nonEA, 0)

* Cap at +/- 500
foreach v of varlist pos1-pos16 {
    replace `v' = 500 if `v' > 500 & !missing(`v')
}
foreach v of varlist neg1-neg16 {
    replace `v' = -500 if `v' < -500 & !missing(`v')
}

* Plot - outermost layers drawn first, inner layers on top
* Color scheme: each sector has a distinct hue; EA = darker, non-EA = lighter
twoway ///
    (area pos16 business_date, color("255 150 200"%70))  /// UCIT non-EA - light pink
    (area pos15 business_date, color("160 30 90"%70))    /// UCIT EA - dark magenta
    (area pos14 business_date, color("128 0 128"%70))    /// Other non-EA - light purple
    (area pos13 business_date, color("64 0 64"%70))      /// Other EA - dark purple
    (area pos12 business_date, color("160 82 45"%70))    /// OFI non-EA - light brown
    (area pos11 business_date, color("90 40 20"%70))     /// OFI EA - dark brown
    (area pos10 business_date, color("100 200 100"%70))  /// IF non-EA - light green
    (area pos9  business_date, color("0 100 0"%70))      /// IF EA - dark green
    (area pos8  business_date, color("255 165 0"%70))    /// ICPF non-EA - light orange
    (area pos7  business_date, color("200 80 0"%70))     /// ICPF EA - dark orange
    (area pos6  business_date, color("64 224 208"%70))   /// HF non-EA - light teal
    (area pos5  business_date, color("0 110 110"%70))    /// HF EA - dark teal
    (area pos4  business_date, color("220 20 60"%70))    /// GOVT non-EA - light red
    (area pos3  business_date, color("120 0 20"%70))     /// GOVT EA - dark red
    (area pos2  business_date, color("100 180 230"%70))  /// BANK non-EA - light blue
    (area pos1  business_date, color("0 50 130"%70))     /// BANK EA - dark blue
    (area neg16 business_date, color("255 150 200"%70))  ///
    (area neg15 business_date, color("160 30 90"%70))    ///
    (area neg14 business_date, color("128 0 128"%70))    ///
    (area neg13 business_date, color("64 0 64"%70))      ///
    (area neg12 business_date, color("160 82 45"%70))    ///
    (area neg11 business_date, color("90 40 20"%70))     ///
    (area neg10 business_date, color("100 200 100"%70))  ///
    (area neg9  business_date, color("0 100 0"%70))      ///
    (area neg8  business_date, color("255 165 0"%70))    ///
    (area neg7  business_date, color("200 80 0"%70))     ///
    (area neg6  business_date, color("64 224 208"%70))   ///
    (area neg5  business_date, color("0 110 110"%70))    ///
    (area neg4  business_date, color("220 20 60"%70))    ///
    (area neg3  business_date, color("120 0 20"%70))     ///
    (area neg2  business_date, color("100 180 230"%70))  ///
    (area neg1  business_date, color("0 50 130"%70)),    ///
    legend(order(16 "BANK EA" 15 "BANK non-EA" 14 "GOVT EA" 13 "GOVT non-EA" ///
                 12 "HF EA" 11 "HF non-EA" 10 "ICPF EA" 9 "ICPF non-EA" ///
                 8 "IF EA" 7 "IF non-EA" 6 "OFI EA" 5 "OFI non-EA" ///
                 4 "Other EA" 3 "Other non-EA" 2 "UCIT EA" 1 "UCIT non-EA") ///
           position(6) rows(4) size(small)) ///
    ytitle("Net position") ///
    xtitle("") ///
    title("Net German futures positions by sector") ///
    yline(0, lcolor(black)) ///
    ylabel(-500(100)500)
	
	
	
	
	
	
