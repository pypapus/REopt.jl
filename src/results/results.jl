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
function reopt_results(m::JuMP.AbstractModel, p::REoptInputs; _n="")
	tstart = time()
    d = Dict{String, Any}()
    for b in p.s.storage.types
        if p.s.storage.max_kw[b] > 0
            add_storage_results(m, p, d, b; _n)
        end
    end

    add_electric_tariff_results(m, p, d; _n)
    add_electric_utility_results(m, p, d; _n)
    add_financial_results(m, p, d; _n)

	if !isempty(p.pvtechs)
        add_pv_results(m, p, d; _n)
	end

    if "Wind" in p.techs
        add_wind_results(m, p, d; _n)
    end
	
	time_elapsed = time() - tstart
	@info "Base results processing took $(round(time_elapsed, digits=3)) seconds."
	
	if !isempty(p.gentechs) && isempty(_n)  # generators not included in multinode model
        tstart = time()
		add_generator_results(m, p, d)
        time_elapsed = time() - tstart
        @info "Generator results processing took $(round(time_elapsed, digits=3)) seconds."
	end
	
	if !isempty(p.s.electric_utility.outage_durations) && isempty(_n)  # outages not included in multinode model
        tstart = time()
		add_outage_results(m, p, d)
        time_elapsed = time() - tstart
        @info "Outage results processing took $(round(time_elapsed, digits=3)) seconds."
	end
	return d
end


"""

Combine two results dictionaries into one using BAU and optimal scenario results.
"""
function combine_results(bau::Dict, opt::Dict,; _n="")
    # TODO not all API names have "_bau" at the end of the output keys
    bau_outputs = (
        ("Financial", "lcc"),
        ("ElectricTariff", "year_one_energy_cost"),
        ("ElectricTariff", "year_one_demand_cost"),
        ("ElectricTariff", "year_one_fixed_cost"),
        ("ElectricTariff", "year_one_min_charge_adder"),
        ("ElectricTariff", "total_energy_cost"),
        ("ElectricTariff", "total_demand_cost"),
        ("ElectricTariff", "total_fixed_cost"),
        ("ElectricTariff", "total_min_charge_adder"),
        ("ElectricTariff", "total_export_benefit"),
        ("ElectricTariff", "year_one_bill"),
        ("ElectricTariff", "year_one_export_benefit"),
        ("ElectricTariff", "year_one_to_load_series_kw"),  
        ("ElectricTariff", "year_one_energy_supplied_kwh"),
        ("PV", "average_yearly_energy_produced_kwh"),
        ("PV", "year_one_energy_produced_kwh"),
        ("Generator", "fuel_used_gal"),
    )

    for t in bau_outputs
        if t[1] in keys(opt) && t[1] in keys(bau)
            if t[2] in keys(bau[t[1]])
                opt[t[1]][t[2] * "_bau"] = bau[t[1]][t[2]]
            end
        end
    end
    opt["Financial"]["net_om_costs_bau"] = bau["Financial"]["total_om_costs_after_tax"]
    opt["Financial"]["npv"] = opt["Financial"]["lcc_bau"] - opt["Financial"]["lcc"]

    return opt
end