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
function add_absorption_chiller_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    r = Dict{String, Any}()

	# @expression(m, ELECCHLtoTES[ts in p.time_steps],
	# 	sum(m[:dvProductionToStorage][b, "ExistingChiller", ts] for b in p.ColdTES)
    # )
	# r["existing_chiller_to_tes_series"] = round.(value.(ELECCHLtoTES), digits=3)

	r["absorpchl_kw"] = value(sum(m[:dvSize][t] for t in p.techs.absorption_chiller))
	@expression(m, ABSORPCHLtoTES[ts in p.time_steps],
		sum(m[:dvProductionToStorage][b,t,ts] for b in p.s.storage.types.cold, t in p.techs.absorption_chiller))
	r["absorption_chiller_to_tes_series"] = round.(value.(ABSORPCHLtoTES), digits=3)
	@expression(m, ABSORPCHLtoLoad[ts in p.time_steps],
		sum(m[:dvThermalProduction][t,ts] for t in p.techs.absorption_chiller)
			- ABSORPCHLtoTES[ts])
	r["absorption_chiller_to_load_series"] = round.(value.(ABSORPCHLtoLoad), digits=3)
	@expression(m, ABSORPCHLThermalConsumptionSeries[ts in p.time_steps],
		sum(m[:dvThermalProduction][t,ts] / p.thermal_cop[t] for t in p.techs.absorption_chiller))
	r["absorption_chiller_consumption_series"] = round.(value.(ABSORPCHLThermalConsumptionSeries), digits=3)
	@expression(m, Year1ABSORPCHLThermalConsumption,
		p.hours_per_timestep * sum(m[:dvThermalProduction][t,ts] / p.thermal_cop[t]
			for t in p.techs.absorption_chiller, ts in p.time_steps))
	r["year_one_absorp_chiller_thermal_consumption_kwh"] = round(value(Year1ABSORPCHLThermalConsumption), digits=3)
	@expression(m, Year1ABSORPCHLThermalProd,
		p.hours_per_timestep * sum(m[:dvThermalProduction][t,ts]
			for t in p.techs.absorption_chiller, ts in p.time_steps))
	r["year_one_absorp_chiller_thermal_prod_kwh"] = round(value(Year1ABSORPCHLThermalProd), digits=3)
    @expression(m, ABSORPCHLElectricConsumptionSeries[ts in p.time_steps],
        sum(m[:dvThermalProduction][t,ts] / p.cop[t] for t in p.techs.absorption_chiller))
    r["absorption_chiller_electric_consumption_series"] = round.(value.(ABSORPCHLElectricConsumptionSeries), digits=3)
    @expression(m, Year1ABSORPCHLElectricConsumption,
        p.hours_per_timestep * sum(m[:dvThermalProduction][t,ts] / p.cop[t] 
            for t in p.techs.absorption_chiller, ts in p.time_steps))
    r["year_one_absorp_chiller_electric_consumption_kwh"] = round(value(Year1ABSORPCHLElectricConsumption), digits=3)
    
	d["absorption_chiller"] = r
	nothing
end