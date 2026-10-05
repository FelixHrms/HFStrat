clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. Positions on one day. Do hedge funds hold bills, and how large is the biggest bond weight

local day = td(15jan2025)

use "$int/sftds.dta", clear
keep if date == `day'
drop if bank_indicator == 1
merge m:1 isin using "$int/bond_info.dta", keep(1 3) keepusing(bondtype) nogen
gen bill = inlist(bondtype, "4", "GTC", "LET", "FTB", "BOT")
gen absnet = abs(net)
gen region = cond(country == "US", "US", "EA")

* bills versus everything else by region, number of positions and gross and net volume in bn
preserve
	collapse (count) positions = net (sum) absnet net, by(region bill)
	list, noobs sepby(region)
restore
tab country bill if absnet > 0

* largest weight in the aggregate hedge fund portfolio of each region, gross positions
preserve
	collapse (sum) absnet net (first) bondtype country, by(region isin)
	bysort region: egen total = sum(absnet)
	gen weight = absnet / total
	gsort region -weight
	by region: gen rank = _n
	list region isin country bondtype net weight if rank <= 10, noobs sepby(region)
restore

* largest weight inside each fund's own portfolio, separately for the US and euro area part
preserve
	collapse (sum) absnet, by(region entity_id isin)
	bysort region entity_id: egen total = sum(absnet)
	gen weight = absnet / total
	collapse (max) weight (count) nbonds = absnet, by(region entity_id)
	bysort region: sum weight nbonds, detail
	hist weight, by(region)
restore
