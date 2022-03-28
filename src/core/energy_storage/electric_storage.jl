# *********************************************************************************
# REopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
# *********************************************************************************
"""
    Degradation

Inputs used when `ElectricStorage.model_degradation` is `true`:
- `calendar_fade_coefficient::Float64 = 2.46E-03`
- `cycle_fade_coefficient::Float64 = 7.82E-05`
- `installed_cost_per_kwh_declination_rate::loat64 = 0.05`
- `maintenance_strategy::String = "augmentation"  # one of ["augmentation", "replacement"]`
- `maintenance_cost_per_kwh::Vector{<:Real} = Real[]`

None of the above values are required. If `ElectricStorage.model_degradation` is `true` then the 
defaults above are used.
If the `maintenance_cost_per_kwh` is not provided then it is determined using the `ElectricStorage.installed_cost_per_kwh`
and the `installed_cost_per_kwh_declination_rate` along with a present worth factor ``f`` to account for the present cost
of buying a battery in the future. The present worth factor for each day is:

``
f(day) = \\frac{ (1-r_g)^\\frac{day}{365} } { (1+r_d)^\\frac{day}{365} }
``

where ``r_g`` = `installed_cost_per_kwh_declination_rate` and ``r_d`` = `p.s.financial.owner_discount_pct`.

The present worth factor is used in two different ways, depending on the `maintenance_strategy`, 
which is described below.

!!! warn
    When modeling degradation the following ElectricStorage inputs are not used:
    - `replace_cost_per_kw`
    - `replace_cost_per_kwh`
    - `inverter_replacement_year`
    - `battery_replacement_year`
    The are replaced by the `maintenance_cost_per_kwh` vector.

!!! note
    When providing the `maintenance_cost_per_kwh` it must have a lenght equal to `Financial.analysis_years*365`.


# Battery State Of Health
The state of health [`SOH`] is a linear function of the daily average state of charge [`Eavg`] and
the daily equivalent full cycles [`EFC`]. The initial `SOH` is set to the optimal battery energy capacity 
(in kWh). The evolution of the `SOH` beyond the first day is:

``
SOH[d] = SOH[d-1] - h\\left(
    \\frac{1}{2} k_{cal} Eavg[d-1] / \\sqrt{d} + k_{cyc} EFC[d-1] \\quad \\forall d \\in \\{2\\dots D\\}
\\right)
``

where:
- ``k_{cal}`` is the `calendar_fade_coefficient`
- ``k_{cyc}`` is the `cycle_fade_coefficient`
- ``h`` is the hours per time step
- ``D`` is the total number of days, 365 * `analysis_years`

The `SOH` is used to determine the maintence cost of the storage system, which depends on the `maintenance_strategy`.

# Augmentation Maintenance Strategy
The augmentation maintenance strategy assumes that the battery energy capacity is maintained by replacing
degraded cells daily in terms of cost. Using the definition of the `SOH` above the maintenance cost is:

``
C_{\\text{aug}} = \\sum_{d \\in \\{2\\dots D\\}} 0.8 C_{\\text{install}} f(day) \\left( SOH[d-1] - SOH[d] \\right)
``

where
- the ``0.8`` factor accounts for sunk costs that do not need to be paid;
- ``C_{\\text{install}}`` is the `ElectricStorage.installed_cost_per_kwh`; and
- ``SOH[d-1] - SOH[d]`` is the incremental amount of battery capacity lost in a day.


The ``C_{\\text{aug}}`` is added to the objective function to be minimized with all other costs.

# Replacement Maintenance Strategy
Modeling the replacment maintenance strategy is more complex than the augmentation strategy.
Effectively the replacment strategy says that the battery has to be replaced once the `SOH` hits 80%
of the optimal, purchased capacity. It is possible that multiple replacements could be required under
this strategy.

!!! warn
    The "replacement" maintenance strategy requires integer variables and indicator constraints.
    Not all solvers support indicator constraints and some solvers are slow with integer variables.

The replacement strategy cost is:

``
C_{\\text{repl}} = B_{\\text{kWh}} N_{\\text{repl}} f(d_{80}) C_{\\text{install}}
``

where:
- ``B_{\\text{kWh}}`` is the optimal battery capacity (`ElectricStorage.size_kwh` in the results dictionary);
- ``N_{\\text{repl}}`` is the number of battery replacments required (a function of the month in which the `SOH` reaches 80% of original capacity);
-  ``f(d_{80})`` is the present worth factor at approximately the 15th day of the month that the `SOH` reaches 80% of original capacity.

The ``C_{\\text{repl}}`` is added to the objective function to be minimized with all other costs.

# Example of inputs
```javascript
{
    ...
    "ElectricStorage": {
        ...
        "model_degradation": true,
        "degradation": {
            "maintenance_strategy": "replacment",
            ...
        }
    },
    ...
}
```
"""
Base.@kwdef mutable struct Degradation
    calendar_fade_coefficient::Float64 = 2.46E-03
    cycle_fade_coefficient::Float64 = 7.82E-05
    installed_cost_per_kwh_declination_rate::Float64 = 0.05
    maintenance_strategy::String = "augmentation"  # one of ["augmentation", "replacement"]
    maintenance_cost_per_kwh::Vector{<:Real} = Real[]
end


"""
    ElectricStorageDefaults

Electric storage system defaults. Overridden by user inputs.

```julia
Base.@kwdef struct ElectricStorageDefaults
    min_kw::Float64 = 0.0
    max_kw::Float64 = 1.0e4
    min_kwh::Float64 = 0.0
    max_kwh::Float64 = 1.0e6
    internal_efficiency_pct::Float64 = 0.975
    inverter_efficiency_pct::Float64 = 0.96
    rectifier_efficiency_pct::Float64 = 0.96
    soc_min_pct::Float64 = 0.2
    soc_init_pct::Float64 = 0.5
    can_grid_charge::Bool = true
    installed_cost_per_kw::Float64 = 840.0
    installed_cost_per_kwh::Float64 = 420.0
    replace_cost_per_kw::Float64 = 410.0
    replace_cost_per_kwh::Float64 = 200.0
    inverter_replacement_year::Int = 10
    battery_replacement_year::Int = 10
    macrs_option_years::Int = 7
    macrs_bonus_pct::Float64 = 1.0
    macrs_itc_reduction::Float64 = 0.5
    total_itc_pct::Float64 = 0.0
    total_rebate_per_kw::Float64 = 0.0
    total_rebate_per_kwh::Float64 = 0.0
    charge_efficiency::Float64 = rectifier_efficiency_pct * internal_efficiency_pct^0.5
    discharge_efficiency::Float64 = inverter_efficiency_pct * internal_efficiency_pct^0.5
    grid_charge_efficiency::Float64 = can_grid_charge ? charge_efficiency : 0.0
    model_degradation::Bool = false
    degradation::Dict = Dict()
end
```
"""
Base.@kwdef struct ElectricStorageDefaults
    min_kw::Float64 = 0.0
    max_kw::Float64 = 1.0e4
    min_kwh::Float64 = 0.0
    max_kwh::Float64 = 1.0e6
    internal_efficiency_pct::Float64 = 0.975
    inverter_efficiency_pct::Float64 = 0.96
    rectifier_efficiency_pct::Float64 = 0.96
    soc_min_pct::Float64 = 0.2
    soc_init_pct::Float64 = 0.5
    can_grid_charge::Bool = true
    installed_cost_per_kw::Float64 = 840.0
    installed_cost_per_kwh::Float64 = 420.0
    replace_cost_per_kw::Float64 = 410.0
    replace_cost_per_kwh::Float64 = 200.0
    inverter_replacement_year::Int = 10
    battery_replacement_year::Int = 10
    macrs_option_years::Int = 7
    macrs_bonus_pct::Float64 = 1.0
    macrs_itc_reduction::Float64 = 0.5
    total_itc_pct::Float64 = 0.0
    total_rebate_per_kw::Float64 = 0.0
    total_rebate_per_kwh::Float64 = 0.0
    charge_efficiency::Float64 = rectifier_efficiency_pct * internal_efficiency_pct^0.5
    discharge_efficiency::Float64 = inverter_efficiency_pct * internal_efficiency_pct^0.5
    grid_charge_efficiency::Float64 = can_grid_charge ? charge_efficiency : 0.0
    model_degradation::Bool = false
    degradation::Dict = Dict()
end


"""
    function ElectricStorage(d::Dict, f::Financial, settings::Settings)

Construct ElectricStorage struct from Dict with keys-val pairs from the 
REopt ElectricStorage and Financial inputs.
"""
struct ElectricStorage <: AbstractElectricStorage
    min_kw::Float64
    max_kw::Float64
    min_kwh::Float64
    max_kwh::Float64
    internal_efficiency_pct::Float64
    inverter_efficiency_pct::Float64
    rectifier_efficiency_pct::Float64
    soc_min_pct::Float64
    soc_init_pct::Float64
    can_grid_charge::Bool
    installed_cost_per_kw::Float64
    installed_cost_per_kwh::Float64
    replace_cost_per_kw::Float64
    replace_cost_per_kwh::Float64
    inverter_replacement_year::Int
    battery_replacement_year::Int
    macrs_option_years::Int
    macrs_bonus_pct::Float64
    macrs_itc_reduction::Float64
    total_itc_pct::Float64
    total_rebate_per_kw::Float64
    total_rebate_per_kwh::Float64
    charge_efficiency::Float64
    discharge_efficiency::Float64
    grid_charge_efficiency::Float64
    net_present_cost_per_kw::Float64
    net_present_cost_per_kwh::Float64
    model_degradation::Bool
    degradation::Degradation

    function ElectricStorage(d::Dict, f::Financial)  
        s = ElectricStorageDefaults(;d...)

        net_present_cost_per_kw = effective_cost(;
            itc_basis = s.installed_cost_per_kw,
            replacement_cost = s.replace_cost_per_kw,
            replacement_year = s.inverter_replacement_year,
            discount_rate = f.owner_discount_pct,
            tax_rate = f.owner_tax_pct,
            itc = s.total_itc_pct,
            macrs_schedule = s.macrs_option_years == 7 ? f.macrs_seven_year : f.macrs_five_year,
            macrs_bonus_pct = s.macrs_bonus_pct,
            macrs_itc_reduction = s.macrs_itc_reduction,
            rebate_per_kw = s.total_rebate_per_kw
        )
        net_present_cost_per_kwh = effective_cost(;
            itc_basis = s.installed_cost_per_kwh,
            replacement_cost = s.replace_cost_per_kwh,
            replacement_year = s.battery_replacement_year,
            discount_rate = f.owner_discount_pct,
            tax_rate = f.owner_tax_pct,
            itc = s.total_itc_pct,
            macrs_schedule = s.macrs_option_years == 7 ? f.macrs_seven_year : f.macrs_five_year,
            macrs_bonus_pct = s.macrs_bonus_pct,
            macrs_itc_reduction = s.macrs_itc_reduction
        )

        net_present_cost_per_kwh -= s.total_rebate_per_kwh

        if haskey(d, :degradation)
            degr = Degradation(;dictkeys_tosymbols(d[:degradation])...)
        else
            degr = Degradation()
        end

        # copy the replace_costs in case we need to change them
        replace_cost_per_kw = s.replace_cost_per_kw 
        replace_cost_per_kwh = s.replace_cost_per_kwh
        if s.model_degradation
            if haskey(d, :replace_cost_per_kw) && d[:replace_cost_per_kw] != 0.0 || 
                haskey(d, :replace_cost_per_kwh) && d[:replace_cost_per_kwh] != 0.0
                @warn "Setting ElectricStorage replacment costs to zero. \nUsing degradation.maintenance_cost_per_kwh instead."
            end
            replace_cost_per_kw = 0.0
            replace_cost_per_kwh = 0.0
        end
    
        return new(
            s.min_kw,
            s.max_kw,
            s.min_kwh,
            s.max_kwh,
            s.internal_efficiency_pct,
            s.inverter_efficiency_pct,
            s.rectifier_efficiency_pct,
            s.soc_min_pct,
            s.soc_init_pct,
            s.can_grid_charge,
            s.installed_cost_per_kw,
            s.installed_cost_per_kwh,
            replace_cost_per_kw,
            replace_cost_per_kwh,
            s.inverter_replacement_year,
            s.battery_replacement_year,
            s.macrs_option_years,
            s.macrs_bonus_pct,
            s.macrs_itc_reduction,
            s.total_itc_pct,
            s.total_rebate_per_kw,
            s.total_rebate_per_kwh,
            s.charge_efficiency,
            s.discharge_efficiency,
            s.grid_charge_efficiency,
            net_present_cost_per_kw,
            net_present_cost_per_kwh,
            s.model_degradation,
            degr
        )
    end
end
