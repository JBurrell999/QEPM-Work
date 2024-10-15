* Load the data from Sheet1
import excel "/Users/jamesburrell/Desktop/shillerdata/data.xlsx", sheet("Sheet1") firstrow clear

* Rename the SPCompP column for easier handling
rename SPCompP sp500

* Generate a new date variable by splitting the year and month
gen year = floor(Date)
gen month = round((Date - year) * 100)

* Combine the year and month into a proper monthly date format
gen proper_date = ym(year, month)
format proper_date %tmMon_CCYY

* Drop intermediate variables but keep proper_date
drop Date year month

* Generate a year-only date variable from proper_date
gen year_date = year(dofm(proper_date))
format year_date %ty

* Collapse the dataset to get year-end S&P 500 value and sum of real dividends for each year
collapse (sum) RealDividend (last) sp500, by(year_date)

* Check for missing or zero real dividends
list year_date RealDividend if RealDividend == 0 | missing(RealDividend)

* Set the dataset as a time series using the year_date variable
tsset year_date, yearly

* Create a real discount rate (assuming 5% for this example, Shiller used around 4-6%)
local real_discount_rate = 0.05

* Extend the horizon for future dividend calculations to 100 years
local horizon = 100

* Create a placeholder for dynamic dividend growth rate
gen growth_rate = .

* Loop through the dataset to calculate the dynamic growth rate over the past 20 years
forvalues t = 21/`=_N' {
    
    * Calculate growth rate over the last 20 years
    summarize RealDividend in `=`t'-19' / `t'
    local end_dividend = r(mean)
    
    * Calculate starting point 20 years earlier
    summarize RealDividend in `=`t'-39' / `t'-20'
    local start_dividend = r(mean)
    
    * Calculate the growth rate over the past 20 years
    local growth = ((`end_dividend' / `start_dividend') ^ (1 / 20)) - 1
    replace growth_rate = `growth' in `t'
}

* Fill in missing growth rates with a default (2%) for earlier periods
replace growth_rate = 0.02 if missing(growth_rate)

* Loop through the dataset to calculate PDV for each year
forvalues t = 1/`=_N' {
    
    * Initialize PDV for each year
    local PDV = 0

    * Apply the discounted value for each future year up to the extended horizon
    forvalues k = `t'/min(`t' + `horizon', `=_N')' {
        
        * Calculate the difference in years
        local year_diff = `k' - `t'

        * Apply the discount factor only if year_diff is within the horizon
        if `year_diff' <= `horizon' {
            * Calculate the present discounted value for future dividends
            local discounted_dividend = RealDividend[`k'] / (1 + `real_discount_rate')^(`year_diff')

            * Accumulate the discounted dividend for year t
            local PDV = `PDV' + `discounted_dividend'
        }
    }

    * Apply the dynamic dividend growth rate beyond the horizon
    local future_dividend = RealDividend[`=_N'] * (1 + growth_rate[`t'])^`horizon'

    * Calculate the discounted value of the growing dividend after the horizon
    local discounted_future_dividend = `future_dividend' / (`real_discount_rate' - growth_rate[`t'])

    * Add the discounted growing future dividend to PDV
    local PDV = `PDV' + `discounted_future_dividend'

    * Store the accumulated PDV for year t
    replace PDV_SP500 = `PDV' in `t'
}

* Save the dataset with the calculated PDV values
save "/Users/jamesburrell/Desktop/shillerdata/PDV_real.dta", replace

* Normalize both series so they start at the same value
summarize sp500
local sp500_start = r(min)
summarize PDV_SP500
local pdv_start = r(min)

* Normalize the PDV series by scaling it to match the starting value of S&P 500
gen PDV_SP500_normalized = PDV_SP500 * (`sp500_start' / `pdv_start')

* Optionally, multiply the normalized PDV by a constant to adjust the scale (e.g., multiply by 2)
* gen PDV_SP500_normalized_scaled = PDV_SP500_normalized * 2

* Plot actual S&P 500 vs Normalized PDV of Real Dividends
twoway (line sp500 year_date) (line PDV_SP500_normalized year_date), ///
    legend(label(1 "Actual S&P 500") label(2 "Normalized PDV of Real Dividends")) ///
    title("S&P 500 vs Normalized PDV of Real Dividends with Dynamic Growth")
