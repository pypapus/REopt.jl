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
`ExistingBoiler` results keys:
- `year_one_fuel_consumption_mmbtu_per_hour` 
- `year_one_fuel_consumption_mmbtu`
- `year_one_thermal_production_mmbtu_per_hour`
- `year_one_thermal_production_mmbtu`
- `thermal_to_tes_series_mmbtu_per_hour`
- `year_one_thermal_to_load_series_mmbtu_per_hour`
- `lifecycle_fuel_cost_after_tax`
- `year_one_fuel_cost_before_tax`
"""
function add_existing_boiler_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    r = Dict{String, Any}()

    # TODO all of these time series assume hourly time steps
    # TODO we convert KWH_PER_MMBTU from user inputs to the model, and then back to mmbtu in outputs: why not stay in mmbtu?
	r["year_one_fuel_consumption_mmbtu_per_hour"] = 
        round.(value.(m[:dvFuelUsage]["ExistingBoiler", ts] for ts in p.time_steps) / KWH_PER_MMBTU, digits=3)
    r["year_one_fuel_consumption_mmbtu"] = round(sum(r["year_one_fuel_consumption_mmbtu_per_hour"]), digits=3)

	r["year_one_thermal_production_mmbtu_per_hour"] = 
        round.(value.(m[:dvThermalProduction]["ExistingBoiler", ts] for ts in p.time_steps) / KWH_PER_MMBTU, digits=3)
	r["year_one_thermal_production_mmbtu"] = round(sum(r["year_one_thermal_production_mmbtu_per_hour"]), digits=3)

	if !isempty(p.s.storage.types.hot)
        @expression(m, BoilerToHotTESKW[ts in p.time_steps],
		    sum(m[:dvProductionToStorage][b,"ExistingBoiler",ts] for b in p.s.storage.types.hot)
            )
    else
        BoilerToHotTESKW = zeros(length(p.time_steps))
    end
	r["thermal_to_tes_series_mmbtu_per_hour"] = round.(value.(BoilerToHotTESKW / KWH_PER_MMBTU), digits=3)

    # if !isempty(p.SteamTurbineTechs)
    #     @expression(m, BoilerToSteamTurbine[ts in p.time_steps], m[:dvThermalToSteamTurbine]["ExistingBoiler",ts])
    #     r["boiler_thermal_to_steamturbine_series"] = round.(value.(BoilerToSteamTurbine), digits=3)
    # else
    #     BoilerToSteamTurbine = zeros(p.time_stepsCount)
    #     r["boiler_thermal_to_steamturbine_series"] = round.(BoilerToSteamTurbine, digits=3)
    # end

	@expression(m, BoilerToLoad[ts in p.time_steps],
		m[:dvThermalProduction]["ExistingBoiler",ts] - BoilerToHotTESKW[ts] #- BoilerToSteamTurbine[ts]
    )
	r["year_one_thermal_to_load_series_mmbtu_per_hour"] = round.(value.(BoilerToLoad / KWH_PER_MMBTU), digits=3)

	r["lifecycle_fuel_cost_after_tax"] = round(value(m[:TotalExistingBoilerFuelCosts]) * (1 - p.s.financial.offtaker_tax_pct), digits=3)
	r["year_one_fuel_cost_before_tax"] = round(value(m[:TotalExistingBoilerFuelCosts]) / p.pwf_fuel["ExistingBoiler"], digits=3)

    d["ExistingBoiler"] = r
	nothing
end