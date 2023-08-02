# *********************************************************************************
# REopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met
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
transition_prob(start_gen::Vector{Int}, end_gen::Vector{Int}, fail_prob_vec::Vector{<:Real})::Vector{Float64}

Transition probability for multiple generator types. 
Return the probability of having ``end_gen`` working generators at the end of a period given ``start_gen`` generators are working at the start of the period and
given generators have a failure probability of ``fail_prob_vec``. 

``start_gen``, ``end_gen``, and fail_prob_vec are vectors of the form [x_1, ..., x_t] given there are t generator types.  

Function used to create transition probabilities in Markov matrix.

# Examples
```repl-julia
fail_prob_vec = [0.2, 0.5]; num_generators = [1,1]
num_generators_working = reshape(collect(Iterators.product((0:g for g in num_generators)...)), :, 1)
starting_gens = vec(repeat(num_generators_working, outer = prod(num_generators .+ 1)))
ending_gens = repeat(vec(num_generators_working), inner = prod(num_generators .+ 1))

julia> transition_prob(starting_gens, ending_gens, fail_prob_vec)
16-element Vector{Float64}:
 1.0
 0.2
 ...
 0.4
```
"""
function transition_prob(start_gen::Vector, end_gen::Vector, fail_prob_vec::Vector{<:Real})::Vector{Float64} 
    start_gen_matrix = hcat(collect.(start_gen)...)
    end_gen_matrix = hcat(collect.(end_gen)...)

    transitions =  [binomial.(start_gen_matrix[i, :], end_gen_matrix[i, :]).*(1-fail_prob_vec[i]).^(end_gen_matrix[i, :]).*(fail_prob_vec[i]).^(start_gen_matrix[i, :].-end_gen_matrix[i, :]) for i in eachindex(fail_prob_vec)]
    return .*(transitions...)
end


"""
    markov_matrix(num_generators::Vector{Int}, fail_prob_vec::Vector{<:Real})::Matrix{Float64} 

Markov Matrix for multiple generator types. 
Return an prod(``num_generators``.+1) by prod(``num_generators``.+1) matrix of transition probabilities of going from n (column) to n' (row) given probability ``fail_prob_vec``

Columns denote starting generators and rows denote ending generators. 
Generator availability scenarios are ordered such that the number of the leftmost generator type increments fastest.
For example, if `num_generators` = [2, 1], then the rows of the returned matrix correspond to the number of working generators by type as follows:
row    working generators
1           (0, 0) 
2           (1, 0)
3           (2, 0)
4           (0, 1)
5           (1, 1)
6           (2, 1)

# Arguments
- `num_generators::Vec{Int}`: Vector of the number of generators of each type 
- `fail_prob::Vec{Real}`: vector of probability of failure of each generator type

# Examples
```repl-julia
julia> markov_matrix([2, 1], [0.1, 0.25])
6×6 Matrix{Float64}:
 1.0   0.1     0.1     0.0   0.9     0.18
 0.0   0.0     0.81    0.25  0.025   0.0025
 0.0   0.225   0.045   0.0   0.0     0.2025
 0.0   0.0     0.0     0.0   0.0     0.0
 0.0   0.0     0.0     0.75  0.075   0.0075
 0.0   0.675   0.135   0.0   0.0     0.6075
```
"""
function markov_matrix(num_generators::Vector{Int}, fail_prob_vec::Vector{<:Real})::Matrix{Float64} 
    # num_generators_working is a vector of tuples, each tuple indicating a number of each gen type that is working
    num_generators_working = vec(collect(Iterators.product((0:g for g in num_generators)...)))
    starting_gens = repeat(num_generators_working, inner = prod(num_generators .+ 1))
    ending_gens = repeat(num_generators_working, outer = prod(num_generators .+ 1))

    #Creates Markov matrix for generator transition probabilities
    M = reshape(transition_prob(starting_gens, ending_gens, fail_prob_vec), prod(num_generators.+1), prod(num_generators .+1))
    replace!(M, NaN => 0)
    return M
end

"""
    starting_probabilities(num_generators::Vector{Int}, generator_operational_availability::Vector{<:Real}, generator_failure_to_start::Vector{<:Real})::Vector{Float64}

Starting Probabilities for multiple generator types. 
Return a prod(``num_generators`` .+ 1) length vector of the probability that each number of generators 
(differentiated by generator type) is both operationally available (``generator_operational_availability``) 
and avoids a Failure to Start (``failure_to_start``) in an inital time step

Generator availability scenarios are ordered such that the number of the leftmost generator type increments fastest.
For example, if `num_generators` = [2, 1], then the columns of the returned matrix correspond to the number of working generators by type as follows:
col    working generators
1           (0, 0) 
2           (1, 0)
3           (2, 0)
4           (0, 1)
5           (1, 1)
6           (2, 1)

# Arguments
- `num_generators::Vec{Int}`: the number of generators of each type 
- `generator_operational_availability::Vec{Real}`: Operational Availability. The chance that a generator will be available (not down for maintenance) at the start of the outage
- `generator_failure_to_start::Vec{Real}`: Failure to Start. The chance that a generator fails to successfully start and take load.

# Examples
```repl-julia
julia> starting_probabilities([2, 1], [0.99,0.95], [0.05, 0.1])
6-element Vector{Float64}:
    0.000513336  
    0.0162283  
    0.128258  
    0.00302691  
    0.0956912  
    0.756282
```
"""
function starting_probabilities(num_generators::Vector{Int}, generator_operational_availability::Vector{<:Real}, generator_failure_to_start::Vector{<:Real})::Vector{Float64} 
    # num_generators_working is a vector of tuples, each tuple indicating a number of each gen type that is working
    num_generators_working = vec(collect(Iterators.product((0:g for g in num_generators)...)))
    starting_gens = repeat([num_generators_working[end]], prod(num_generators .+ 1))
    ending_gens = num_generators_working
    starting_vec = transition_prob(starting_gens, 
                            ending_gens, 
                            (1 .- generator_operational_availability) .+ (generator_failure_to_start .* generator_operational_availability)
                        )
    replace!(starting_vec, NaN => 0)
    # starting_vec = markov_matrix(
    #     num_generators, 
    #     (1 .- generator_operational_availability) .+ (generator_failure_to_start .* generator_operational_availability)
    # )[:, end]
    return starting_vec
end

"""
    bin_storage_charge(storage_soc_kwh::Vector, num_bins::Int, storage_size_kwh::Real)::Vector{Int}

Return a vector the same length as ``storage_soc_kwh`` of discritized battery charge bins,
or a ones vector of length 8760 if storage_soc_kwh is empty or num_bins ==1.

The first bin denotes zero battery charge, and each additional bin has size of ``storage_size_kwh``/(``num_bins``-1)
Values are rounded to nearest bin.

# Arguments
- `storage_soc_kwh::Vector`: the state of charge, in kWh or the same units as the storage size is measured in
- `num_bins::Int`: number of bins storage is divided into
- `storage_size_kwh::Real`: capacity of the storage

# Examples
```repl-julia
julia>  bin_storage_charge([30, 100, 170.5, 250, 251, 1000], 11, 1000)
6-element Vector{Int64}:
  1
  2
  3
  3
  4
 11
```
"""
function bin_storage_charge(storage_soc_kwh::Vector, num_bins::Int, storage_size_kwh::Real)::Vector{Int}  
    #Bins battery into discrete portions. Zero is one of the bins. 
    if isempty(storage_soc_kwh) || num_bins == 1
        return ones(Int64,8760)
    end
    bin_size = storage_size_kwh / (num_bins-1)
    return min.(num_bins, round.(storage_soc_kwh./bin_size).+1)
end


"""
    generator_output(num_generators::Vector{Int}, generator_size_kw::Vector{<:Real})::Vector{Float64} 

Generator output for multiple generator types
Return a prod(``num_generators`` .+ 1) length vector of maximum generator capacity given 0 to ``num_generators`` of each type are available

Generator availability scenarios are ordered such that the number of the leftmost generator type increments fastest.
For example, if `num_generators` = [2, 1], then the elements of the returned vector correspond to the number of working generators by type as follows:
index    working generators
1           (0, 0) 
2           (1, 0)
3           (2, 0)
4           (0, 1)
5           (1, 1)
6           (2, 1)

#Examples
```repl-julia
generator_output([2,1], [250, 300])
6-element Vector{Float64}:
   0.0
 250.0
 500.0
 300.0
 550.0
 800.0
```
"""
function generator_output(num_generators::Vector{Int}, generator_size_kw::Vector{<:Real})::Vector{Float64} 
    gens_working = (0:g for g in num_generators)
    num_generators_working = reshape(collect(Iterators.product(gens_working...)), :, 1)
    #Returns vector of maximum generator output
    return vec([sum(gw[i] * generator_size_kw[i] for i in eachindex(generator_size_kw)) for gw in num_generators_working])
end


"""
    get_maximum_generation(battery_size_kw::Real, H2_size_kw::Real, generator_size_kw::Vector{<:Real}, 
        battery_bin_size::Real, battery_num_bins::Int, H2_bin_size::Real, H2_num_bins::Int, num_generators::Vector{Int}, 
        battery_discharge_efficiency::Real, H2_discharge_efficiency::Real)::Array{Float64,3}

Maximum generation calculation for multiple generator types
Return an array of maximum total system output.

The first dimension denotes available generators, the second dimension battery state of charge bin, and the third H2 state of charge bin.

# Arguments
- `battery_size_kw::Real`: battery inverter size
- `H2_size_kw::Real`: hydrogen fuel cell output size
- `generator_size_kw::Vector{Real}`: maximum output from single generator for each generator type. 
- `battery_bin_size::Real`: size of discretized battery SOC bin, equal to battery_size_kwh / (battery_num_bins - 1) 
- `battery_num_bins::Int`: number of battery bins
- `H2_bin_size::Real`: size of discretized H2 storage SOC bin, equal to H2_size_kw / (H2_num_bins - 1) 
- `H2_num_bins::Int`: number of H2 storage bins
- `num_generators::Vector{Int}`: number of generators by type in microgrid.
- `battery_discharge_efficiency::Real`: battery_discharge_efficiency = battery discharge / reduction in battery SOC
- `H2_discharge_efficiency::Real`: H2_discharge_efficiency = H2 discharge / reduction in H2 SOC

# Examples
```repl-julia
julia>  get_maximum_generation(100, 100, [50, 125], 50, 5, 400, 3, [2, 1], 0.98, 0.9)
6×5×3 Array{Float64, 3}:
[:, :, 1] =
   0.0   49.0   98.0  100.0  100.0
  50.0   99.0  148.0  150.0  150.0
 100.0  149.0  198.0  200.0  200.0
 125.0  174.0  223.0  225.0  225.0
 175.0  224.0  273.0  275.0  275.0
 225.0  274.0  323.0  325.0  325.0

[:, :, 2] =
 100.0  149.0  198.0  200.0  200.0
 150.0  199.0  248.0  250.0  250.0
 200.0  249.0  298.0  300.0  300.0
 225.0  274.0  323.0  325.0  325.0
 275.0  324.0  373.0  375.0  375.0
 325.0  374.0  423.0  425.0  425.0

[:, :, 3] =
 100.0  149.0  198.0  200.0  200.0
 150.0  199.0  248.0  250.0  250.0
 200.0  249.0  298.0  300.0  300.0
 225.0  274.0  323.0  325.0  325.0
 275.0  324.0  373.0  375.0  375.0
 325.0  374.0  423.0  425.0  425.0
```
"""
function get_maximum_generation(battery_size_kw::Real, H2_size_kw::Real, generator_size_kw::Vector{<:Real}, 
    battery_bin_size::Real, battery_num_bins::Int, H2_bin_size::Real, H2_num_bins::Int, num_generators::Vector{Int}, 
    battery_discharge_efficiency::Real, H2_discharge_efficiency::Real)::Array{Float64,3}
    N = prod(num_generators .+ 1)
    M_b = battery_num_bins
    M_H2 = H2_num_bins
    max_system_output = zeros(N, M_b, M_H2)
    for i_b in 1:M_b
        for i_H2 in 1:M_H2
            max_system_output[:, i_b, i_H2] = generator_output(num_generators, generator_size_kw) .+ 
                                            min(battery_size_kw, (i_b-1)*battery_bin_size*battery_discharge_efficiency) .+ 
                                            min(H2_size_kw, (i_H2-1)*H2_bin_size*H2_discharge_efficiency)
        end
    end
    return max_system_output
end

"""
    storage_bin_shift(excess_generation_kw::Vector{<:Real}, bin_size::Real,
                                charge_size_kw::Real, discharge_size_kw::Real,
                                charge_efficiency::Real, discharge_efficiency::Real)::Tuple{Vector{Int},Vector{<:Real}}
Return a tuple containing:
- A vector of number of bins storage (electric or H2) is shifted by, where each index of the vector corresponds to the number of working generators
- A vector of kW remaining from argument excess_generation_kw after storage shift due to (dis)charge limits, where each index of the vector corresponds to the number of working generators

Bins are the discritized storage kWh size, with the first bin denoting empty and the last bin denoting full. Thus, if there are 101 bins, then each bin denotes 
a one percent difference in SOC. The storage will attempt to dispatch to meet critical loads not met by other generation sources, and will charge from excess generation. 

# Arguments
- `excess_generation_kw::Vector`: maximum generator output minus net critical load for each number of working generators
- `bin_size::Real`: size of battery bin
- `size_kw::Real`: inverter size
- `charge_efficiency::Real`: charge_efficiency = increase in SOC / kWh in 
- `discharge_efficiency::Real`: discharge_efficiency = kWh out / reduction in SOC

#Examples
```repl-julia
julia>
excess_generation_kw = [-500, -120, 0, 50, 175, 400]
bin_size = 100
battery_size_kw = 300
storage_bin_shift(excess_generation_kw, bin_size, battery_size_kw, battery_size_kw, 1, 1)
([-3, -1, 0, 0, 2, 3], [-200, 0, 0, 0, 0, 100])
  ```
"""
function storage_bin_shift(excess_generation_kw::Vector{<:Real}, bin_size::Real,
                                charge_size_kw::Real, discharge_size_kw::Real,
                                charge_efficiency::Real, discharge_efficiency::Real)::Tuple{Vector{Int},Vector{<:Real}}
    #Determines how many bins to shift storage SOC by
    #Lose energy charging battery/producing H2 and use more energy discharging battery/using H2
    
    if charge_size_kw == 0 || discharge_size_kw == 0 || bin_size == 0
        return zeros(length(excess_generation_kw)), excess_generation_kw
    end

    kw_to_storage = copy(excess_generation_kw)
    #Cannot charge or discharge more than power rating
    kw_to_storage[kw_to_storage .> charge_size_kw] .= charge_size_kw
    kw_to_storage[kw_to_storage .< -discharge_size_kw] .= -discharge_size_kw
    #Account for (dis)charge efficiency
    kw_to_storage[kw_to_storage .> 0] = kw_to_storage[kw_to_storage .> 0] .* charge_efficiency
    kw_to_storage[kw_to_storage .< 0] = kw_to_storage[kw_to_storage .< 0] ./ discharge_efficiency

    shift = round.(kw_to_storage ./ bin_size)
    remaining_kw = excess_generation_kw .- kw_to_storage
    return shift, remaining_kw
end

"""
    shift_gen_storage_prob_matrix!(gen_storage_prob_matrix::Array, 
                                    excess_generation_kw::Vector{<:Real}, 
                                    battery_bin_size::Real,
                                    battery_size_kw::Real,
                                    battery_charge_efficiency::Real, 
                                    battery_discharge_efficiency::Real,
                                    H2_bin_size::Real,
                                    H2_charge_size_kw::Real,
                                    H2_discharge_size_kw::Real,
                                    H2_charge_efficiency::Real,
                                    H2_discharge_efficiency::Real)
Updates ``gen_storage_prob_matrix`` in place to account for change in battery and H2 storage state of charge bins.
Based on the net power available (excess_generation_kw), shifts elements along the battery 
and H2 storage SOC dimensions (dims 2 and 3), accounting for accumulation at 0 or full soc.

#Examples
```repl-julia
gen_storage_prob_matrix = Array{Float64}(undef,2,4,3)
gen_storage_prob_matrix[1,:,:] = [0.1 0.0 0.0;
                            0.0 0.3 0.0;
                            0.0 0.0 0.0;
                            0.0 0.0 0.1]
gen_storage_prob_matrix[2,:,:] = [0.0 0.0 0.2;
                            0.0 0.0 0.1;
                            0.0 0.0 0.0;
                            0.0 0.2 0.0]
excess_generation_kw = [-2, 6]
battery_bin_size = 1
battery_size_kw = 2
battery_charge_efficiency = 1
battery_discharge_efficiency = 1
H2_bin_size = 1
H2_charge_size_kw = 1
H2_discharge_size_kw = 1
H2_charge_efficiency = 1
H2_discharge_efficiency = 1
shift_gen_storage_prob_matrix!(gen_storage_prob_matrix, excess_generation_kw, battery_bin_size, 
                            battery_size_kw, battery_charge_efficiency, battery_discharge_efficiency, 
                            H2_bin_size, H2_charge_size_kw, H2_discharge_size_kw, 
                            H2_charge_efficiency, H2_discharge_efficiency)
gen_storage_prob_matrix
2×4×3 Array{Float64, 3}:
[:, :, 1] =
 0.4  0.0  0.0  0.0
 0.0  0.0  0.0  0.0
[:, :, 2] =
 0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0
[:, :, 3] =
 0.0  0.1  0.0  0.0
 0.0  0.0  0.2  0.3
```
"""
function shift_gen_storage_prob_matrix!(gen_storage_prob_matrix::Array, 
                                        excess_generation_kw::Vector{<:Real}, 
                                        battery_bin_size::Real,
                                        battery_size_kw::Real,
                                        battery_charge_efficiency::Real, 
                                        battery_discharge_efficiency::Real,
                                        H2_bin_size::Real,
                                        H2_charge_size_kw::Real,
                                        H2_discharge_size_kw::Real,
                                        H2_charge_efficiency::Real,
                                        H2_discharge_efficiency::Real)

    M_b = size(gen_storage_prob_matrix, 2)
    M_H2 = size(gen_storage_prob_matrix, 3)

    battery_shift, remaining_kw_after_batt_shift = storage_bin_shift(
                excess_generation_kw, 
                battery_bin_size, 
                battery_size_kw, 
                battery_size_kw,
                battery_charge_efficiency, 
                battery_discharge_efficiency
            )

    for i_gen in 1:length(battery_shift) 
        s_b = battery_shift[i_gen]
        if s_b != 0
            for i_H2 in 1:M_H2
                gen_storage_prob_matrix[i_gen, :, i_H2] = circshift(view(gen_storage_prob_matrix, i_gen, :, i_H2), s_b)
            end
            wrap_indices_b = s_b < 0 ? (max(2,M_b+s_b+1):M_b) : (1:min(s_b,M_b-1))
            accumulate_index_b = s_b < 0 ? 1 : M_b
            excess_kw = remaining_kw_after_batt_shift[i_gen] .+ battery_bin_size .* (collect(wrap_indices_b) .- (s_b < 0 ? (M_b + 1) : 0)) #negative values if unmet kw
            H2_shift, remaining_kw_after_H2_shift = storage_bin_shift(
                    excess_kw, 
                    H2_bin_size, 
                    H2_charge_size_kw, 
                    H2_discharge_size_kw,
                    H2_charge_efficiency, 
                    H2_discharge_efficiency
                )
            for (i_shift, i_b) in enumerate(wrap_indices_b)
                s_H2 = H2_shift[i_shift]
                if s_H2 != 0
                    gen_storage_prob_matrix[i_gen, i_b, :] = circshift(view(gen_storage_prob_matrix, i_gen, i_b, :), s_H2)
                    wrap_indices_H2 = s_H2 < 0 ? (max(2,M_H2+s_H2+1):M_H2) : (1:min(s_H2,M_H2-1))
                    accumulate_index_H2 = s_H2 < 0 ? 1 : M_H2
                    gen_storage_prob_matrix[i_gen, i_b, accumulate_index_H2] += sum(view(gen_storage_prob_matrix, i_gen, i_b, wrap_indices_H2))
                    gen_storage_prob_matrix[i_gen, i_b, wrap_indices_H2] .= 0
                end
            end
            gen_storage_prob_matrix[i_gen, accumulate_index_b, :] .+= vec(sum(view(gen_storage_prob_matrix, i_gen, wrap_indices_b, :), dims=1))
            gen_storage_prob_matrix[i_gen, wrap_indices_b, :] .= 0
        end
    end
end

"""
update_survival!(survival, maximum_generation, net_critical_loads_kw_at_time_h)::Matrix{Int}

In place update of survival matrix with 0 in states where generation cannot meet load and 1 in states where it can.
"""
function update_survival!(survival, maximum_generation, net_critical_loads_kw_at_time_h)
    @inbounds for i in eachindex(maximum_generation)
        survival[i] = 1 * (maximum_generation[i] - net_critical_loads_kw_at_time_h >= 0)
    end
end

"""
survival_chance_mult(prob_matrix, survival)

More efficient implementation of sum(prob_matrix .* survival)
"""
function survival_chance_mult(prob_matrix, survival)::Real
    s = 0
    @inbounds for i in eachindex(prob_matrix)
        s += prob_matrix[i] * survival[i]
    end
    return s
end

"""
prob_matrix_update!(prob_matrix, survival)

More efficient implementation of prob_matrix = prob_matrix .* survival
"""
function prob_matrix_update!(prob_matrix, survival)
    @inbounds for i in eachindex(prob_matrix)
        prob_matrix[i] *= survival[i]
    end
end


"""
    survival_gen_only(;critical_load::Vector, generator_operational_availability::Real, generator_failure_to_start::Real, generator_mean_time_to_failure::Real, num_generators::Int,
                                generator_size_kw::Real, max_outage_duration::Int, marginal_survival = false)::Matrix{Float64}

Return a matrix of probability of survival with rows denoting outage start timestep and columns denoting outage duration

Solves for probability of survival given only backup generators (no battery backup). 
If ``marginal_survival`` = true then result is chance of surviving in given outage timestep, 
if ``marginal_survival`` = false then result is chance of surviving up to and including given outage timestep.

# Arguments
- `net_critical_loads_kw::Vector`: Vector of system critical loads. 
- `generator_operational_availability::Vector{<:Real}`: Operational Availability of backup generators.
- `generator_failure_to_start::Vector{<:Real}`: probability of generator Failure to Start and support load. 
- `generator_mean_time_to_failure::Vector{<:Real}`: Average number of time steps between a generator's failures. 1/(failure to run probability). 
- `num_generators::Vector{Int}`: number of generators in microgrid.
- `generator_size_kw::Vector{<:Real}`: size of generator.
- `max_outage_duration::Int`: maximum outage duration in timesteps.
- `marginal_survival::Bool`: indicates whether results are probability of survival in given outage duration timestep or probability of surviving up to and including the given timestep.

# Examples
Given generator_mean_time_to_failure = 5, the chance of no generators failing in 0.64 in time step 1, 0.4096 in time step 2, and 0.262144 in time step 3
Chance of 2 generators failing is 0.04 in time step 1, 0.1296 by time step 1, and 0.238144 by time step 3   
```repl-julia
julia> net_critical_loads_kw = [1,2,2,1]; generator_operational_availability = 1; failure_to_start = 0.0; MTTF = 0.2; num_generators = 2; generator_size_kw = 1; max_outage_duration = 3;
julia> survival_gen_only(net_critical_loads_kw=net_critical_loads_kw, generator_operational_availability=generator_operational_availability, 
                                generator_failure_to_start=failure_to_start, generator_mean_time_to_failure=MTTF, num_generators=num_generators, 
                                generator_size_kw=generator_size_kw, max_outage_duration=max_outage_duration, marginal_survival = true)
4×3 Matrix{Float64}:
 0.96  0.4096  0.262144
 0.64  0.4096  0.761856
 0.96  0.8704  0.761856
 0.96  0.8704  0.262144

julia> survival_gen_only(net_critical_loads_kw=net_critical_loads_kw, generator_operational_availability=generator_operational_availability, 
                                generator_failure_to_start=failure_to_start, generator_mean_time_to_failure=MTTF, num_generators=num_generators, 
                                generator_size_kw=generator_size_kw, max_outage_duration=max_outage_duration, marginal_survival = false)
4×3 Matrix{Float64}:
 0.96  0.4096  0.262144
 0.64  0.4096  0.393216
 0.64  0.6144  0.557056
 0.96  0.8704  0.262144
```
"""
function survival_gen_only(;
    net_critical_loads_kw::Vector, 
    generator_operational_availability::Vector{<:Real}, 
    generator_failure_to_start::Vector{<:Real}, 
    generator_mean_time_to_failure::Vector{<:Real},
    num_generators::Vector{Int}, 
    generator_size_kw::Vector{<:Real},
    max_outage_duration::Int,
    marginal_survival = false)::Matrix{Float64} 

    t_max = length(net_critical_loads_kw)
    
    generator_production = generator_output(num_generators, generator_size_kw) 
    #Initialize lost load matrix
    survival_probability_matrix = zeros(t_max, max_outage_duration)
    #initialize amount of extra generation for each critical load time step and each amount of generators
    generator_markov_matrix = markov_matrix(num_generators, 1 ./ generator_mean_time_to_failure)
  
    #Get starting generator vector
    starting_gens = starting_probabilities(num_generators, generator_operational_availability, generator_failure_to_start) #initialize gen battery prob matrix

    Threads.@threads for t = 1:t_max
        
        survival_probability_matrix[t, :] = gen_only_survival_single_start_time(
            t, starting_gens, net_critical_loads_kw, generator_production,
            generator_markov_matrix, max_outage_duration, t_max, marginal_survival) 
 
    end
    return survival_probability_matrix
end

"""
    survival_gen_only_single_start_time(t::Int, starting_gens::Vector{Float64}, net_critical_loads_kw::Vector{Real}, generator_production::Vector{Float64}, 
    generator_markov_matrix::Matrix{Float64}, max_outage_duration::Int, t_max::Int, marginal_survival::Bool)::Vector{Float64}

Return a vector of probability of survival with for all outage durations given outages start time t. 
    Function is for internal loop of survival_gen_only
"""
function gen_only_survival_single_start_time(
    t::Int, 
    starting_gens::Vector{Float64},
    net_critical_loads_kw::Vector, 
    generator_production::Vector{Float64},
    generator_markov_matrix::Matrix{Float64},
    max_outage_duration::Int,
    t_max::Int,
    marginal_survival::Bool)::Vector{Float64}

    survival_chances = zeros(max_outage_duration)
    gen_prob_array = [copy(starting_gens), copy(starting_gens)]
    survival = ones(length(generator_production), 1)

    for d in 1:max_outage_duration
        h = mod(t + d - 2, t_max) + 1 #determines index accounting for looping around year
        update_survival!(survival, generator_production, net_critical_loads_kw[h])

        #Update probabilities to account for generator failures
        #This is a more memory efficient way of implementing gen_battery_prob_matrix *= generator_markov_matrix
        gen_matrix_counter_start = ((d-1) % 2) + 1 
        gen_matrix_counter_end = (d % 2) + 1 
        mul!(gen_prob_array[gen_matrix_counter_end], generator_markov_matrix, gen_prob_array[gen_matrix_counter_start])
        
        if marginal_survival == false
            prob_matrix_update!(gen_prob_array[gen_matrix_counter_end], survival) 
            survival_chances[d] = sum(gen_prob_array[gen_matrix_counter_end])
        else
            survival_chances[d] = survival_chance_mult(gen_prob_array[gen_matrix_counter_end], survival)
        end

    end
    return survival_chances
end

"""
    survival_with_storage(;net_critical_loads_kw::Vector, battery_starting_soc_kwh::Vector, H2_starting_soc_kwh::Vector, generator_operational_availability::Vector{<:Real}, generator_failure_to_start::Vector{<:Real}, 
                        generator_mean_time_to_failure::Vector{<:Real}, num_generators::Vector{Int}, generator_size_kw::Vector{<:Real}, battery_size_kwh::Real, battery_size_kw::Real, num_bins::Int, 
                        H2_size_kwh::Real, H2_electrolyzer_size_kw::Real, H2_fuelcell_size_kw::Real, num_H2_bins::Int, max_outage_duration::Int, 
                        battery_charge_efficiency::Real, battery_discharge_efficiency::Real, H2_charge_efficiency::Real, H2_discharge_efficiency::Real, 
                        marginal_survival::Bool = false, time_steps_per_hour::Real = 1)::Matrix{Float64} 

Return a matrix of probability of survival with rows denoting outage start and columns denoting outage duration

Solves for probability of survival given both networked generators and battery backup. 
If ``marginal_survival`` = true then result is chance of surviving in given outage time step, 
if ``marginal_survival`` = false then result is chance of surviving up to and including given outage time step.

# Arguments
- `net_critical_loads_kw::Vector`: Vector of system critical loads minus solar generation.
- `battery_starting_soc_kwh::Vector`: Vector of battery charge (kwh) for each time step of year. 
- `H2_starting_soc_kwh::Vector`: Vector of H2 storage charge (kwh) for each time step of year. 
- `generator_operational_availability::Vector{<:Real}`: Operational Availability of backup generators.
- `generator_failure_to_start::Vector{<:Real}`: Probability of generator Failure to Start and support load. 
- `generator_mean_time_to_failure::Vector{<:Real}`: Average number of time steps between failures. 1/MTTF (failure to run probability). 
- `num_generators::Vector{Int}`: number of generators in microgrid.
- `generator_size_kw::Vector{<:Real}`: size of generator.
- `battery_size_kwh::Vector{<:Real}`: energy capacity of battery system.
- `battery_size_kw::Vector{<:Real}`: battery system inverter size.
- `num_battery_bins::Int`: number of battery bins. 
- `H2_size_kwh::Real`: energy capacity of H2 storage system.
- `H2_electrolyzer_size_kw::Real`: H2 system electrolyzer size.
- `H2_fuelcell_size_kw::Real`: H2 system fuel cell size.
- `num_H2_bins::Int`: number of H2 storage bins.
- `max_outage_duration::Int`: maximum outage duration in time steps (time step is generally hourly but could be other values such as 15 minutes).
- `battery_charge_efficiency::Real`: battery_charge_efficiency = increase in SOC / charge input to battery
- `battery_discharge_efficiency::Real`: battery_discharge_efficiency = discharge from battery / reduction in SOC
- `H2_charge_efficiency::Real`: H2_charge_efficiency = increase in SOC / charge input to H2 system
- `H2_discharge_efficiency::Real`: H2_discharge_efficiency = discharge from H2 system / reduction in SOC
- `marginal_survival::Bool`: indicates whether results are probability of survival in given outage time step or probability of surviving up to and including time step.

# Examples
Given MTTF = 0.2, the chance of no generators failing in 0.64 in time step 1, 0.4096 in time step 2, and 0.262144 in time step 3
Chance of 2 generators failing is 0.04 in time step 1, 0.1296 by time step 2, and 0.238144 by time step 3   
```repl-julia
julia> net_critical_loads_kw = [1,2,2,1]; battery_starting_soc_kwh = [1,1,1,1];  max_outage_duration = 3;
julia> num_generators = 2; generator_size_kw = 1; generator_operational_availability = 1; failure_to_start = 0.0; MTTF = 0.2;
julia> num_battery_bins = 3; battery_size_kwh = 2; battery_size_kw = 1;  battery_charge_efficiency = 1; battery_discharge_efficiency = 1;

julia> survival_with_storage(net_critical_loads_kw=net_critical_loads_kw, battery_starting_soc_kwh=battery_starting_soc_kwh, 
                            generator_operational_availability=generator_operational_availability, generator_failure_to_start=failure_to_start, 
                            generator_mean_time_to_failure=MTTF, num_generators=num_generators, generator_size_kw=generator_size_kw, 
                            battery_size_kwh=battery_size_kwh, battery_size_kw = battery_size_kw, num_battery_bins=num_battery_bins, 
                            H2_starting_soc_kwh=[], H2_size_kwh=0, H2_electrolyzer_size_kw=0, H2_fuelcell_size_kw=0, num_H2_bins=1,
                            max_outage_duration=max_outage_duration, battery_charge_efficiency=battery_charge_efficiency, 
                            battery_discharge_efficiency=battery_discharge_efficiency, H2_charge_efficiency=1, H2_discharge_efficiency=1, marginal_survival = false)
4×3 Matrix{Float64}:
1.0   0.8704  0.557056
0.96  0.6144  0.57344
0.96  0.896   0.8192
1.0   0.96    0.761856
```
"""
function survival_with_storage(;
    net_critical_loads_kw::Vector, 
    battery_starting_soc_kwh::Vector, 
    H2_starting_soc_kwh::Vector,
    generator_operational_availability::Vector{<:Real}, 
    generator_failure_to_start::Vector{<:Real},
    generator_mean_time_to_failure::Vector{<:Real},
    num_generators::Vector{Int},
    generator_size_kw::Vector{<:Real}, 
    battery_size_kwh::Real, 
    battery_size_kw::Real, 
    num_battery_bins::Int, 
    H2_size_kwh::Real, 
    H2_electrolyzer_size_kw::Real, 
    H2_fuelcell_size_kw::Real, 
    num_H2_bins::Int, 
    max_outage_duration::Int, 
    battery_charge_efficiency::Real,
    battery_discharge_efficiency::Real,
    H2_charge_efficiency::Real,
    H2_discharge_efficiency::Real,
    marginal_survival::Bool = false,
    time_steps_per_hour::Real = 1)::Matrix{Float64} 

    t_max = length(net_critical_loads_kw)
    
    #bin size is battery storage divided by num bins-1 because zero is also a bin
    battery_bin_size = battery_size_kwh / (num_battery_bins-1)
    H2_bin_size = H2_size_kwh / (num_H2_bins-1)
     
    #bin initial battery and H2 storage
    starting_battery_bins = bin_storage_charge(battery_starting_soc_kwh, num_battery_bins, battery_size_kwh)
    starting_H2_bins = bin_storage_charge(H2_starting_soc_kwh, num_H2_bins, H2_size_kwh)
    #Size of generators state dimension
    N = prod(num_generators .+ 1)
    #Initialize survival probability matrix
    survival_probability_matrix = zeros(t_max, max_outage_duration) 
    #initialize vectors and matrices
    generator_markov_matrix = markov_matrix(num_generators, 1 ./ generator_mean_time_to_failure) 
    generator_production = generator_output(num_generators, generator_size_kw)
    maximum_generation = get_maximum_generation(battery_size_kw, 0.0, generator_size_kw, battery_bin_size, num_battery_bins, 0.0, 1, num_generators, battery_discharge_efficiency, 1)
    starting_gens = starting_probabilities(num_generators, generator_operational_availability, generator_failure_to_start) 

    Threads.@threads for t = 1:t_max
        survival_probability_matrix[t, :] = survival_with_storage_single_start_time(t, 
        net_critical_loads_kw, max_outage_duration, battery_size_kw, battery_charge_efficiency,
        battery_discharge_efficiency, H2_electrolyzer_size_kw, H2_fuelcell_size_kw, H2_charge_efficiency, H2_discharge_efficiency, num_battery_bins, num_H2_bins, N, starting_gens, generator_production,
        generator_markov_matrix, maximum_generation, t_max, starting_battery_bins, battery_bin_size, starting_H2_bins, H2_bin_size, marginal_survival, time_steps_per_hour)
    end
    return survival_probability_matrix
end


"""
survival_with_storage_single_start_time(t::Int, net_critical_loads_kw::Vector, max_outage_duration::Int, 
    generator_size_kw::Vector{<:Real}, battery_charge_efficiency::Real, battery_discharge_efficiency::Real, 
    H2_electrolyzer_size_kw::Real, H2_fuelcell_size_kw::Real, H2_charge_efficiency::Real, 
    H2_discharge_efficiency::Real, M_b::Int, M_H2::Int, N::Int, starting_gens::Vector{Float64}, 
    generator_production::Vector{Float64}, generator_markov_matrix::Matrix{Float64}, maximum_generation::Matrix{Float64}, 
    t_max::Int, starting_battery_bins::Vector{Int}, battery_bin_size::Real, starting_H2_bins::Vector{Int}, 
    H2_bin_size::Real, marginal_survival::Bool, time_steps_per_hour::Real)::Vector{Float64}

Return a vector of probability of survival with for all outage durations given outages start time t. 
    Function is for internal loop of survival_with_storage
"""
function survival_with_storage_single_start_time(
    t::Int, 
    net_critical_loads_kw::Vector, 
    max_outage_duration::Int, 
    battery_size_kw::Real, 
    battery_charge_efficiency::Real,
    battery_discharge_efficiency::Real,
    H2_electrolyzer_size_kw::Real, 
    H2_fuelcell_size_kw::Real, 
    H2_charge_efficiency::Real,
    H2_discharge_efficiency::Real,
    M_b::Int,
    M_H2::Int,
    N::Int,
    starting_gens::Vector{Float64},
    generator_production::Vector{Float64},
    generator_markov_matrix::Matrix{Float64},
    maximum_generation::Array{Float64,3},
    t_max::Int,
    starting_battery_bins::Vector{Int},
    battery_bin_size::Real,
    starting_H2_bins::Vector{Int},
    H2_bin_size::Real,
    marginal_survival::Bool, 
    time_steps_per_hour::Real)::Vector{Float64}

    gen_battery_prob_matrix_array = [zeros(N, M_b, M_H2), zeros(N, M_b, M_H2)]
    gen_battery_prob_matrix_array[1][:, starting_battery_bins[t], starting_H2_bins[t]] = starting_gens
    gen_battery_prob_matrix_array[2][:, starting_battery_bins[t], starting_H2_bins[t]] = starting_gens
    return_survival_chance_vector = zeros(max_outage_duration)
    survival = ones(N, M_b, M_H2)

    for d in 1:max_outage_duration 
        h = mod(t + d - 2, t_max) + 1 #determines index accounting for looping around year
        
        update_survival!(survival, maximum_generation, net_critical_loads_kw[h])
        
        #Update probabilities to account for generator failures
        #This is a more memory efficient way of implementing gen_battery_prob_matrix *= generator_markov_matrix
        gen_matrix_counter_start = ((d-1) % 2) + 1 
        gen_matrix_counter_end = (d % 2) + 1 
        for i_H2 in 1:M_H2
            mul!(view(gen_battery_prob_matrix_array[gen_matrix_counter_end],:,:,i_H2), generator_markov_matrix, view(gen_battery_prob_matrix_array[gen_matrix_counter_start],:,:,i_H2))
        end

        if marginal_survival == false
            # @timeit to "survival chance" gen_battery_prob_matrix_array[gen_matrix_counter_end] = gen_battery_prob_matrix_array[gen_matrix_counter_end] .* survival 
            prob_matrix_update!(gen_battery_prob_matrix_array[gen_matrix_counter_end], survival) 
            return_survival_chance_vector[d] = sum(gen_battery_prob_matrix_array[gen_matrix_counter_end])
        else
            return_survival_chance_vector[d] = survival_chance_mult(gen_battery_prob_matrix_array[gen_matrix_counter_end], survival)
        end

        #Update generation battery probability matrix to account for battery shifting
        # shift_gen_storage_prob_matrix!(
        #     gen_battery_prob_matrix_array[gen_matrix_counter_end], 
        #     storage_bin_shift(
        #         (generator_production .- net_critical_loads_kw[h]) / time_steps_per_hour, 
        #         battery_bin_size, 
        #         battery_size_kw, 
        #         battery_size_kw,
        #         battery_charge_efficiency, 
        #         battery_discharge_efficiency
        #     )
        # )
        shift_gen_storage_prob_matrix!(
            gen_battery_prob_matrix_array[gen_matrix_counter_end],
            (generator_production .- net_critical_loads_kw[h]) / time_steps_per_hour,
            battery_bin_size,#TODO: don't need all three of bin size, size, and num bins
            battery_size_kw,
            battery_charge_efficiency, 
            battery_discharge_efficiency,
            H2_bin_size,
            H2_electrolyzer_size_kw, 
            H2_fuelcell_size_kw, 
            H2_charge_efficiency,
            H2_discharge_efficiency
        )
    end
    return return_survival_chance_vector
end

"""
    backup_reliability_reopt_inputs(;d::Dict, p::REoptInputs, r::Dict)::Dict

Return a dictionary of inputs required for backup reliability calculations. 

# Arguments
-d::Dict: REopt results dictionary.
-p::REoptInputs: REopt inputs struct.  
-r::Dict: Dictionary of inputs for reliability calculations. If r not included then uses all defaults. values read from dictionary:
    -generator_operational_availability::Union{Real, Vector{<:Real}} = 0.995    Fraction of year generators not down for maintenance
    -generator_failure_to_start::Union{Real, Vector{<:Real}} = 0.0094           Chance of generator starting given outage
    -generator_mean_time_to_failure::Union{Real, Vector{<:Real}} = 1100         Average number of time steps between a generator's failures. 1/(failure to run probability). 
    -num_generators::Union{Int, Vector{Int}} = 1                                                    Number of generators. 
    -generator_size_kw::Union{Real, Vector{<:Real}} = 0.0                       Backup generator capacity. 
    -num_battery_bins::Int                                                      Number of bins for discretely modeling battery state of charge
    -max_outage_duration::Int = 96                                              Maximum outage time step modeled
    -microgrid_only::Bool = false                                               Boolean to specify if only microgrid upgraded technologies run during grid outage
    -battery_minimum_soc_fraction::Real = 0.0                                   The minimum battery state of charge (represented as a fraction) allowed during outages.
    -fuel_limit:Union{Real, Vector{<:Real}} = 1e9                               Amount of fuel available, either by generator type or per generator, depending on fuel_limit_is_per_generator. Change generator_fuel_burn_rate_per_kwh for different fuel efficiencies. Fuel units should be consistent with generator_fuel_intercept_per_hr and generator_fuel_burn_rate_per_kwh.
    -generator_fuel_intercept_per_hr::Union{Real, Vector{<:Real}} = 0.0         Amount of fuel burned each time step while idling. Fuel units should be consistent with fuel_limit and generator_fuel_burn_rate_per_kwh.
    -fuel_limit_is_per_generator::Union{Bool, Vector{Bool}} = false             Boolean to determine whether fuel limit is given per generator or per generator type
    -generator_fuel_burn_rate_per_kwh::Union{Real, Vector{<:Real}} = 0.076      Amount of fuel used per kWh generated. Fuel units should be consistent with fuel_limit and generator_fuel_intercept_per_hr.
"""
function backup_reliability_reopt_inputs(;d::Dict, p::REoptInputs, r::Dict = Dict())::Dict

    r2 = dictkeys_tosymbols(r)
    zero_array = zeros(length(p.time_steps))
    r2[:critical_loads_kw] = p.s.electric_load.critical_loads_kw

    r2[:time_steps_per_hour] = 1 / p.hours_per_time_step
    microgrid_only = get(r, "microgrid_only", false)

    if haskey(d, "PV") && !(
            microgrid_only && 
            !Bool(get(d, "PV_upgraded", false)) #TODO: PV_upgraded doesn't exist anymore and would be in Outages anyway
        ) 
        pv_kw_ac_time_series = (
            get(d["PV"], "electric_to_storage_series_kw", zero_array)
            + get(d["PV"], "electric_curtailed_series_kw", zero_array)
            + get(d["PV"], "electric_to_load_series_kw", zero_array)
            + get(d["PV"], "electric_to_grid_series_kw", zero_array)
        )
        r2[:pv_kw_ac_time_series] = pv_kw_ac_time_series
    end

    if haskey(d, "ElectricStorage") && !(
        microgrid_only && 
        !Bool(get(d, "Storage_upgraded", false)) #TODO: Storage_upgraded doesn't exist anymore and would be in Outages anyway
    )
        r2[:battery_charge_efficiency] = p.s.storage.attr["ElectricStorage"].charge_efficiency
        r2[:battery_discharge_efficiency] = p.s.storage.attr["ElectricStorage"].discharge_efficiency
        r2[:battery_size_kw] = get(d["ElectricStorage"], "size_kw", 0)

        #ERP tool uses effective battery size so need to subtract minimum SOC
        battery_size_kwh = get(d["ElectricStorage"], "size_kwh", 0)
        

        init_soc = get(d["ElectricStorage"], "soc_series_fraction", [])
        battery_starting_soc_kwh = init_soc .* battery_size_kwh
        
        battery_minimum_soc_kwh = battery_size_kwh * get(r2, :battery_minimum_soc_fraction, 0)
        r2[:battery_size_kwh] = battery_size_kwh - battery_minimum_soc_kwh
        r2[:battery_starting_soc_kwh] = battery_starting_soc_kwh .- battery_minimum_soc_kwh
        if minimum(r2[:battery_starting_soc_kwh]) < 0
            @warn("Some battery starting states of charge are less than the provided minimum state of charge.")
        end
    end
    
    if microgrid_only
        diesel_kw = get(get(d, "Outages", Dict()), "generator_microgrid_size_kw", 0)
        # prime_kw = get(get(d, "Outages", Dict()), "chp_microgrid_size_kw", 0)
    else
        diesel_kw = get(get(d, "Generator", Dict()), "size_kw", 0)
        # prime_kw = get(get(d, "CHP", Dict()), "size_kw", 0)
    end
    
    #TODO: add parsing of chp/prime gen from reopt results

    num_generators = get!(r2, :num_generators, [1]*length(get(r2, :generator_size_kw, [nothing])))
    if length(get(r2, :generator_size_kw, [nothing])) != length(num_generators)
        throw(@error("Input num_generators must be the same length as generator_size_kw or a scalar if generator_size_kw not provided."))
    end
    generator_size_kw = get!(r2, :generator_size_kw, replace!([diesel_kw] ./ num_generators, Inf => 0))

    return r2
end

"""
    backup_reliability_inputs(;r::Dict)::Dict

Return a dictionary of inputs required for backup reliability calculations. 
***NOTE*** PV production only added if battery storage is also available to manage variability

# Arguments
- `r::Dict`: Dictionary of inputs for reliability calculations.
    inputs of r:
    -critical_loads_kw::Array                                                   Critical loads per time step. (Required input)
    -microgrid_only::Bool = false                                               Boolean to specify if only microgrid upgraded technologies run during grid outage 
    -chp_size_kw::Real                                                          CHP capacity. 
    -pv_size_kw::Real                                                           Size of PV System
    -pv_production_factor_series::Array                                         PV production factor per time step (required if pv_size_kw in dictionary)
    -pv_migrogrid_upgraded::Bool                                                If true then PV runs during outage if microgrid_only = TRUE (defaults to false)
    -battery_operational_availability::Real = 0.97                              Likelihood battery will be available at start of outage       
    -pv_operational_availability::Real = 0.98                                   Likelihood PV will be available at start of outage    -battery_size_kw::Real                                  Battery capacity. If no battery installed then PV disconnects from system during outage
    -battery_size_kwh::Real                                                     Battery energy storage capacity
    -battery_size_kw::Real                                                      Battery power capacity
    -charge_efficiency::Real                                                    Battery charge efficiency
    -discharge_efficiency::Real                                                 Battery discharge efficiency
    -battery_starting_soc_series_fraction                                       Battery state of charge in each time step (if not input then defaults to battery size)
    -battery_minimum_soc_fraction = 0.0                                         The minimum battery state of charge (represented as a fraction) allowed during outages.
    -generator_operational_availability::Union{Real, Vector{<:Real}} = 0.995    Likelihood generator being available in given time step
    -generator_failure_to_start::Union{Real, Vector{<:Real}} = 0.0094           Chance of generator starting given outage
    -generator_mean_time_to_failure::Union{Real, Vector{<:Real}} = 1100         Average number of time steps between a generator's failures. 1/(failure to run probability). 
    -num_generators::Union{Int, Vector{Int}} = 1                                Number of generators. 
    -generator_size_kw::Union{Real, Vector{<:Real}} = 0.0                       Backup generator capacity.
    -num_battery_bins::Int                                                      Number of bins for discretely modeling battery state of charge
    -max_outage_duration::Int = 96                                              Maximum outage duration modeled
    -fuel_limit:Union{Real, Vector{<:Real}} = 1e9                               Amount of fuel available, either by generator type or per generator, depending on fuel_limit_is_per_generator. Change generator_fuel_burn_rate_per_kwh for different fuel efficiencies. Fuel units should be consistent with generator_fuel_intercept_per_hr and generator_fuel_burn_rate_per_kwh.
    -generator_fuel_intercept_per_hr::Union{Real, Vector{<:Real}} = 0.0         Amount of fuel burned each time step while idling. Fuel units should be consistent with fuel_limit and generator_fuel_burn_rate_per_kwh.
    -fuel_limit_is_per_generator::Union{Real, Vector{<:Real}} = false           Boolean to determine whether fuel limit is given per generator or per generator type
    -generator_fuel_burn_rate_per_kwh::Union{Real, Vector{<:Real}} = 0.076      Amount of fuel used per kWh generated. Fuel units should be consistent with fuel_limit and generator_fuel_intercept_per_hr.
    
#Examples
```repl-julia
julia> r = Dict("critical_loads_kw" => [1,2,1,1], "generator_operational_availability" => 1, "generator_failure_to_start" => 0.0,
                "generator_mean_time_to_failure" => 5, "num_generators" => 2, "generator_size_kw" => 1, 
                "max_outage_duration" => 3, "battery_size_kw" =>2, "battery_size_kwh" => 4)
julia>    backup_reliability_inputs(r = r)
Dict{Any, Any} with 11 entries:
  :num_generators                       => 2
  :battery_starting_soc_kwh             => [4.0, 4.0, 4.0, 4.0]
  :max_outage_duration                  => 3
  :generator_size_kw                    => 1
  :generator_failure_to_start           => 0.0
  :battery_size_kwh                     => 4
  :battery_size_kw                      => 2
  :net_critical_loads_kw                => Real[1.0, 2.0, 1.0, 1.0]
  :generator_mean_time_to_failure       => 5
  :generator_operational_availability   => 1
  :critical_loads_kw                    => Real[1.0, 2.0, 1.0, 1.0]
```
"""
function backup_reliability_inputs(;r::Dict)::Dict

    invalid_args = String[]
    r2 = dictkeys_tosymbols(r)

    if haskey(r2, :num_generators)
        num_gen_types = length(r2[:num_generators])
        if !haskey(r2, :fuel_limit)
            #If multiple generators and no fuel input, then remove fuel constraint
            r2[:fuel_limit] = [1e9 for _ in 1:num_gen_types]
        end 
        if !haskey(r2, :generator_fuel_intercept_per_hr)
            r2[:generator_fuel_intercept_per_hr] = [0.0 for _ in 1:num_gen_types]
        end
        if !haskey(r2, :generator_fuel_burn_rate_per_kwh)
            r2[:generator_fuel_burn_rate_per_kwh] = [0.076 for _ in 1:num_gen_types]
        end
    end

    microgrid_only = get(r2, :microgrid_only, false)

    pv_size_kw = get(r2, :pv_size_kw, 0.0) 
    if pv_size_kw > 0
        if haskey(r2, :pv_production_factor_series)
            if length(r2[:pv_production_factor_series]) != length(r2[:critical_loads_kw])
                push!(invalid_args, "The lengths of pv_production_factor_series and critical_loads_kw do not match.")
            end
            if !microgrid_only || Bool(get(r2, :pv_migrogrid_upgraded, false))
                r2[:pv_kw_ac_time_series] = pv_size_kw .* r2[:pv_production_factor_series]
            end
        else
            push!(invalid_args, "Non-zero pv_size_kw is included in inputs but no pv_production_factor_series is provided.")
        end
    end

    if haskey(r2, :battery_size_kw)
        if !microgrid_only || Bool(get(r2, :storage_microgrid_upgraded, false))
            #check if minimum state of charge added. If so, then change battery size to effective size, and reduce starting SOC accordingly
            if haskey(r2, :battery_starting_soc_series_fraction) 
                init_soc = r2[:battery_starting_soc_series_fraction]
            else
                @warn("No battery soc series provided to reliability inputs. Assuming battery fully charged at start of outage.")
                init_soc = ones(length(r2[:critical_loads_kw]))
            end
            r2[:battery_starting_soc_kwh] = init_soc .* r2[:battery_size_kwh]
            
            if haskey(r2, :battery_minimum_soc_fraction) 
                battery_minimum_soc_kwh = r2[:battery_size_kwh] * r2[:battery_minimum_soc_fraction]
                r2[:battery_size_kwh] -= battery_minimum_soc_kwh
                if minimum(r2[:battery_starting_soc_kwh]) < battery_minimum_soc_kwh
                    @warn("Some battery starting states of charge are less than the provided minimum state of charge.")
                end
                r2[:battery_starting_soc_kwh] .-= battery_minimum_soc_kwh
            end
            
            if !haskey(r2, :battery_size_kwh)
                push!(invalid_args, "Battery kW provided to reliability inputs but no kWh provided.")
            end
        end
    end

    if length(invalid_args) > 0
        error("Invalid argument values: $(invalid_args)")
    end

    return r2
end

"""
    backup_reliability_single_run(; critical_loads_kw::Vector, generator_operational_availability::Vector{<:Real} = [0.995], generator_failure_to_start::Vector{<:Real} = [0.0094], 
        generator_mean_time_to_failure::Vector{<:Real} = [1100], num_generators::Vector{Int} = [1], generator_size_kw::Vector{<:Real} = [0.0], num_battery_bins::Int = 101, max_outage_duration::Int = 96,
        battery_size_kw::Real = 0.0, battery_size_kwh::Real = 0.0, battery_charge_efficiency::Real = 0.948, battery_discharge_efficiency::Real = 0.948, time_steps_per_hour::Real = 1)::Matrix

Return an array of backup reliability calculations. Inputs can be unpacked from backup_reliability_inputs() dictionary
# Arguments
-net_critical_loads_kw::Vector                     Vector of net critical loads                     
-battery_starting_soc_kwh::Vector   = []           Battery kWh state of charge time series during normal grid-connected usage
-generator_operational_availability::Vector{<:Real}    = [0.995]         Fraction of year generators not down for maintenance
-generator_failure_to_start::Vector{<:Real}            = [0.0094]        Chance of generator starting given outage
-generator_mean_time_to_failure::Vector{<:Real}        = [1100]          Average number of time steps between a generator's failures. 1/(failure to run probability). 
-num_generators::Vector{Int}                            = [1]             Number of generators
-generator_size_kw::Vector{<:Real}                     = [0.0]           Backup generator capacity
-num_battery_bins::Int              = num_battery_bins_default(battery_size_kw,battery_size_kwh)     Number of bins for discretely modeling battery state of charge
-max_outage_duration::Int           = 96           Maximum outage duration modeled
-battery_size_kw::Real              = 0.0          Battery kW of power capacity
-battery_size_kwh::Real             = 0.0          Battery kWh of energy capacity
-battery_charge_efficiency::Real    = 0.948        Efficiency of charging battery
-battery_discharge_efficiency::Real = 0.948        Efficiency of discharging battery
-time_steps_per_hour::Real          = 1            Used to determine amount battery gets shifted.
```
"""
function backup_reliability_single_run(; 
    net_critical_loads_kw::Vector, 
    battery_starting_soc_kwh::Vector = [],
    generator_operational_availability::Vector{<:Real} = [0.995], 
    generator_failure_to_start::Vector{<:Real} = [0.0094], 
    generator_mean_time_to_failure::Vector{<:Real} = [1100], 
    num_generators::Vector{Int} = [1], 
    generator_size_kw::Vector{<:Real} = [0.0], 
    max_outage_duration::Int = 96,
    battery_size_kw::Real = 0.0,
    battery_size_kwh::Real = 0.0,
    num_battery_bins::Int = num_battery_bins_default(battery_size_kw,battery_size_kwh),
    battery_charge_efficiency::Real = 0.948, 
    battery_discharge_efficiency::Real = 0.948,
    time_steps_per_hour::Real = 1,
    kwargs...)::Matrix
     
    #No reliability calculations if no outage duration
    if max_outage_duration == 0
        return []
    
    elseif battery_size_kw < 0.1
        return survival_gen_only(
                net_critical_loads_kw=net_critical_loads_kw,
                generator_operational_availability=generator_operational_availability, 
                generator_failure_to_start=generator_failure_to_start, 
                generator_mean_time_to_failure=generator_mean_time_to_failure, 
                num_generators=num_generators, 
                generator_size_kw=generator_size_kw, 
                max_outage_duration=max_outage_duration, 
                marginal_survival = false)

    else
        return survival_with_storage(
                net_critical_loads_kw=net_critical_loads_kw,
                battery_starting_soc_kwh=battery_starting_soc_kwh, 
                H2_starting_soc_kwh=[], 
                generator_operational_availability=generator_operational_availability, 
                generator_failure_to_start=generator_failure_to_start, 
                generator_mean_time_to_failure=generator_mean_time_to_failure,
                num_generators=num_generators,
                generator_size_kw=generator_size_kw, 
                battery_size_kw=battery_size_kw,
                battery_size_kwh=battery_size_kwh,
                H2_electrolyzer_size_kw=0,
                H2_fuelcell_size_kw=0,
                H2_size_kwh=0,
                num_battery_bins=num_battery_bins,
                num_H2_bins=1,
                max_outage_duration=max_outage_duration, 
                battery_charge_efficiency=battery_charge_efficiency,
                battery_discharge_efficiency=battery_discharge_efficiency,
                H2_charge_efficiency=1,
                H2_discharge_efficiency=1,
                marginal_survival = false,
                time_steps_per_hour = time_steps_per_hour
            )

    end
end

"""
fuel_use(; net_critical_loads_kw::Vector, num_generators::Vector{Int} = [1], generator_size_kw::Vector{<:Real} = [0.0],
            fuel_limit::Vector{<:Real} = [1e9], generator_fuel_intercept_per_hr::Vector{<:Real} = [0.0],
            fuel_limit_is_per_generator::Vector{Bool} = [false], generator_fuel_burn_rate_per_kwh::Vector{<:Real} = [0.076],
            max_outage_duration::Int = 96, battery_starting_soc_kwh::Vector = [], battery_size_kw::Real = 0.0, battery_size_kwh::Real = 0.0,
            battery_charge_efficiency::Real = 0.948, battery_discharge_efficiency::Real = 0.948, time_steps_per_hour::Int = 1, kwargs...)::Matrix{Int}

# Returns
-A matrix of fuel survival, with rows corresponding to start times and columns to duration.
-The total fuel used, if no components fail.

# Arguments
-net_critical_loads_kw::Vector                                              vector of net critical loads
-num_generators::Vector{Int} = [1],                               number of backup generators of each type
-generator_size_kw::Vector{<:Real} = [0.0],                      capacity of each generator type
-fuel_limit:Vector{<:Real} = [1e9]                               Amount of fuel available, either by generator type or per generator, depending on fuel_limit_is_per_generator. Change generator_fuel_burn_rate_per_kwh for different fuel efficiencies. Fuel units should be consistent with generator_fuel_intercept_per_hr and generator_fuel_burn_rate_per_kwh.
-generator_fuel_intercept_per_hr::Vector{<:Real} = [0.0]        Amount of fuel burned each time step while idling. Fuel units should be consistent with fuel_limit and generator_fuel_burn_rate_per_kwh.
-fuel_limit_is_per_generator::Vector{Bool} = [false]             Boolean to determine whether fuel limit is given per generator or per generator type
-generator_fuel_burn_rate_per_kwh::Vector{<:Real} = [0.076]      Amount of fuel used per kWh generated. Fuel units should be consistent with fuel_limit and generator_fuel_intercept_per_hr.
-max_outage_duration::Int = 96,                                             maximum outage duration
-battery_starting_soc_kwh::Vector = [],                                     battery time series of starting charge
-battery_size_kw::Real = 0.0,                                               inverter capacity of battery
-battery_size_kwh::Real = 0.0,                                              energy capacity of battery
-battery_charge_efficiency::Real = 0.948,                                   battery charging efficiency
-battery_discharge_efficiency::Real = 0.948,                                battery discharge efficiency
-time_steps_per_hour::Real = 1,                                             number of time steps per hour

```
"""
function fuel_use(;    
    net_critical_loads_kw::Vector, 
    num_generators::Vector{Int} = [1], 
    generator_size_kw::Vector{<:Real} = [0.0],
    fuel_limit::Vector{<:Real} = [1e9],
    generator_fuel_intercept_per_hr::Vector{<:Real} = [0.0],
    fuel_limit_is_per_generator::Vector{Bool} = [false],
    generator_fuel_burn_rate_per_kwh::Vector{<:Real} = [0.076],
    max_outage_duration::Int = 96,
    battery_starting_soc_kwh::Vector = [],
    battery_size_kw::Real = 0.0,
    battery_size_kwh::Real = 0.0,
    battery_charge_efficiency::Real = 0.948, 
    battery_discharge_efficiency::Real = 0.948,
    time_steps_per_hour::Real = 1,
    kwargs...
    )::Tuple{Matrix{Int}, Matrix{Float64}}

    fuel_limit = convert.(Float64, fuel_limit)
    if isa(fuel_limit_is_per_generator, Bool)
        if fuel_limit_is_per_generator
            fuel_limit *= num_generators
        end
    else
        for i in eachindex(fuel_limit_is_per_generator)
            if fuel_limit_is_per_generator[i]
                fuel_limit[i] *= num_generators[i]
            end
        end
    end

    generator_fuel_intercept_per_hr = generator_fuel_intercept_per_hr .* num_generators
    # Sort based on ratio of fuel available to fuel burn
    total_generator_capacity_kw = num_generators .* generator_size_kw
    fuel_order = sortperm(fuel_limit ./ (total_generator_capacity_kw .* generator_fuel_burn_rate_per_kwh .+ generator_fuel_intercept_per_hr))
    generator_fuel_burn_rate_per_kwh = generator_fuel_burn_rate_per_kwh[fuel_order] 
    generator_fuel_intercept_per_hr = generator_fuel_intercept_per_hr[fuel_order]
    total_generator_capacity_kw = total_generator_capacity_kw[fuel_order]

    t_max = length(net_critical_loads_kw)
    survival_matrix = zeros(t_max, max_outage_duration) 
    fuel_used = zeros(t_max, length(fuel_limit))

    battery_included = battery_size_kw > 0

    for t in 1:t_max
        fuel_remaining = copy(fuel_limit)

        if battery_included 
            battery_soc_kwh = battery_starting_soc_kwh[t]
        end

        for d in 1:max_outage_duration
            h = mod(t + d - 2, t_max) + 1 #determines index accounting for looping around year
            load_kw = net_critical_loads_kw[h]
            
            if (load_kw < 0) && battery_included && (battery_soc_kwh < battery_size_kwh)  # load is met
                battery_soc_kwh += minimum([
                    battery_size_kwh - battery_soc_kwh,     # room available
                    battery_size_kw / time_steps_per_hour * battery_charge_efficiency,  # inverter capacity
                    -load_kw / time_steps_per_hour * battery_charge_efficiency  # excess energy
                ])
            else  # check if we can meet load with generator then storage
                for i in eachindex(fuel_remaining)
                    remaining_gen = sum(total_generator_capacity_kw[i:end])
                    
                    if remaining_gen == 0
                        generation = 0
                    else
                        generation = minimum([
                            total_generator_capacity_kw[i],  #generator capacity
                            load_kw * total_generator_capacity_kw[i] / remaining_gen, #generator type share of load (spits between remaining generators)
                            maximum([0, (fuel_remaining[i] * time_steps_per_hour - generator_fuel_intercept_per_hr[i]) / generator_fuel_burn_rate_per_kwh[i]]) #fuel remaining
                        ])
                    end

                    fuel_remaining[i] = maximum([0, fuel_remaining[i] - (generation * generator_fuel_burn_rate_per_kwh[i] + generator_fuel_intercept_per_hr[i]) / time_steps_per_hour])  
                    load_kw -= generation
                end

                if battery_included
                    battery_dispatch = minimum([
                            load_kw, 
                            battery_soc_kwh * time_steps_per_hour * battery_discharge_efficiency, 
                            battery_size_kw
                        ])
                    load_kw -= battery_dispatch
                    battery_soc_kwh -= battery_dispatch  / (time_steps_per_hour * battery_discharge_efficiency)
                end
            end
            if (d > 1 && survival_matrix[t, d-1] == 0) || round(load_kw, digits=5) > 0  # failed to meet load in this time step or any previous
                survival_matrix[t, d] = 0
            else
                survival_matrix[t, d] = 1
            end
        end
        fuel_used[t,:] = fuel_limit - fuel_remaining
    end

    return survival_matrix, fuel_used
end

"""
    return_backup_reliability(; critical_loads_kw::Vector, battery_operational_availability::Real = 0.97,
            pv_operational_availability::Real = 0.98, pv_kw_ac_time_series::Vector = [],
            pv_can_dispatch_without_battery::Bool = false, kwargs...)
Return an array of backup reliability calculations, accounting for operational availability of PV and battery. 
# Arguments
-critical_loads_kw::Vector                          Vector of critical loads
-battery_operational_availability::Real = 1.0       Likelihood battery will be available at start of outage       
-pv_operational_availability::Real      = 0.98      Likelihood PV will be available at start of outage
-pv_kw_ac_time_series::Vector = []                  timeseries of PV dispatch
-pv_can_dispatch_without_battery::Bool  = false     Boolian determining whether net load subtracts PV if battery is unavailable.
-battery_size_kw::Real                  = 0.0       Battery kW of power capacity
-battery_size_kwh::Real                 = 0.0       Battery kWh of energy capacity
-kwargs::Dict                                       Dictionary of additional inputs.  
```
"""
function return_backup_reliability(;
    critical_loads_kw::Vector, 
    battery_operational_availability::Real = 0.97,
    pv_operational_availability::Real = 0.98,
    pv_can_dispatch_without_battery::Bool = false,
    battery_size_kw::Real = 0.0,
    battery_size_kwh::Real = 0.0,
    kwargs...)

    
    
    if haskey(kwargs, :pv_kw_ac_time_series)
        pv_included = true
        net_critical_loads_kw = critical_loads_kw - kwargs[:pv_kw_ac_time_series]
    else
        net_critical_loads_kw = critical_loads_kw
        pv_included = false
    end
    
    #Four systems are 1) no PV + no battery, 2) PV + battery, 3) PV + no battery, and 4) no PV + battery
    system_characteristics = Dict(
        "gen" => Dict(
            "probability" => 1,
            "net_critical_loads_kw" => critical_loads_kw,
            "battery_size_kw" => 0,
            "battery_size_kwh" => 0),
        "gen_pv_battery" => Dict(
            "probability" => 0,
            "net_critical_loads_kw" => net_critical_loads_kw,
            "battery_size_kw" => battery_size_kw,
            "battery_size_kwh" => battery_size_kwh),
        "gen_battery" => Dict(
            "probability" => 0,
            "net_critical_loads_kw" => critical_loads_kw,
            "battery_size_kw" => battery_size_kw,
            "battery_size_kwh" => battery_size_kwh),
        "gen_pv" => Dict(
            "probability" => 0,
            "net_critical_loads_kw" => net_critical_loads_kw,
            "battery_size_kw" => 0,
            "battery_size_kwh" => 0)
    )
    #Sets probabilities for each potential system configuration
    if battery_size_kw > 0 && pv_included
        system_characteristics["gen_pv_battery"]["probability"] = 
            battery_operational_availability * pv_operational_availability
        system_characteristics["gen_battery"]["probability"] = 
            battery_operational_availability * (1 - pv_operational_availability)
        if pv_can_dispatch_without_battery
            system_characteristics["gen_pv"]["probability"] = 
                (1 - battery_operational_availability) * pv_operational_availability
            system_characteristics["gen"]["probability"] = 
                (1 - battery_operational_availability) * (1 - pv_operational_availability)
        else
            #gen_pv probability stays zero and that case is combined with gen only
            system_characteristics["gen"]["probability"] = 
                (1 - battery_operational_availability) 
        end
    elseif battery_size_kw > 0
        system_characteristics["gen_battery"]["probability"] = 
            battery_operational_availability
        system_characteristics["gen"]["probability"] = 
            (1 - battery_operational_availability)
    elseif pv_included && pv_can_dispatch_without_battery
        system_characteristics["gen_pv"]["probability"] = 
            pv_operational_availability
        system_characteristics["gen"]["probability"] = 
            (1 - pv_operational_availability)
    end

    results_no_fuel_limit = []
    for (description, system) in system_characteristics
        if system["probability"] != 0
            run_survival_probs = backup_reliability_single_run(;
                net_critical_loads_kw = system["net_critical_loads_kw"],
                battery_size_kw = system["battery_size_kw"],
                battery_size_kwh = system["battery_size_kwh"],
                kwargs...)
            #If no results then add results, else append to them
            if length(results_no_fuel_limit) == 0
                #survival probs weighted by probability
                results_no_fuel_limit = run_survival_probs .* system["probability"]
            else
                results_no_fuel_limit += run_survival_probs .* system["probability"]
            end
        end
    end

    fuel_survival, fuel_used = fuel_use(; net_critical_loads_kw = net_critical_loads_kw, battery_size_kw=battery_size_kw, battery_size_kwh=battery_size_kwh, kwargs...)
    return results_no_fuel_limit, fuel_survival, fuel_used
end

"""
process_reliability_results(cumulative_results::Matrix, fuel_survival::Matrix, fuel_used::Matrix)::Dict

Return dictionary of processed backup reliability results.

# Arguments
- `cumulative_results::Matrix`: cumulative survival probabilities matrix from function return_backup_reliability. 
- `fuel_survival::Matrix`: fuel survival probabilities matrix from function return_backup_reliability.
- `fuel_used::Vector`: quantity of fuels used in outage of max duration for each start time.
"""
function process_reliability_results(cumulative_results::Matrix, fuel_survival::Matrix, fuel_used::Matrix)::Dict
    cumulative_duration_means = round.(vec(mean(cumulative_results, dims = 1)), digits=6)
    cumulative_duration_mins = round.(vec(minimum(cumulative_results, dims = 1)), digits=6)
    cumulative_final_resilience = round.(cumulative_results[:, end], digits=6)
    fuel_duration_means = round.(vec(mean(fuel_survival, dims = 1)), digits =6)
    fuel_final_survival = round.(fuel_survival[:, end], digits=6)

    total_cumulative_duration_means = round.(vec(mean(cumulative_results .* fuel_survival, dims = 1)), digits=6)
    total_cumulative_duration_mins = round.(vec(minimum(cumulative_results .* fuel_survival, dims = 1)), digits=6)
    total_cumulative_final_resilience = round.(cumulative_results[:,end] .* fuel_survival[:,end], digits=6)

    total_cumulative_final_resilience_mean = round(mean(total_cumulative_final_resilience), digits=6)
    time_steps_per_hour = length(total_cumulative_final_resilience)/8760
    if time_steps_per_hour < 1
        calc_monthly_quartiles = false
    else
        calc_monthly_quartiles = true
        total_cumulative_final_resilience_monthly = zeros(12,5)
        ts_by_month = get_monthly_time_steps(2022; time_steps_per_hour=time_steps_per_hour)
        for mth in 1:12
            t0 = Int(ts_by_month[mth][1])
            tf = Int(ts_by_month[mth][end])
            total_cumulative_final_resilience_monthly[mth,:] = quantile(total_cumulative_final_resilience[t0:tf], (0:4)/4)
        end
    end
    return Dict(
        "unlimited_fuel_mean_cumulative_survival_by_duration"  => cumulative_duration_means,
        "unlimited_fuel_min_cumulative_survival_by_duration"   => cumulative_duration_mins,
        "unlimited_fuel_cumulative_survival_final_time_step" => cumulative_final_resilience,

        "mean_fuel_survival_by_duration" => fuel_duration_means,
        "fuel_outage_survival_final_time_step" => fuel_final_survival,

        "mean_cumulative_survival_by_duration" => total_cumulative_duration_means,
        "min_cumulative_survival_by_duration" => total_cumulative_duration_mins,
        "cumulative_survival_final_time_step" => total_cumulative_final_resilience,

        "mean_cumulative_survival_final_time_step" => total_cumulative_final_resilience_mean,
        
        "monthly_min_cumulative_survival_final_time_step" => calc_monthly_quartiles ? total_cumulative_final_resilience_monthly[:,1] : [],
        "monthly_lower_quartile_cumulative_survival_final_time_step" => calc_monthly_quartiles ? total_cumulative_final_resilience_monthly[:,2] : [],
        "monthly_median_cumulative_survival_final_time_step" => calc_monthly_quartiles ? total_cumulative_final_resilience_monthly[:,3] : [],
        "monthly_upper_quartile_cumulative_survival_final_time_step" => calc_monthly_quartiles ? total_cumulative_final_resilience_monthly[:,4] : [],
        "monthly_max_cumulative_survival_final_time_step" => calc_monthly_quartiles ? total_cumulative_final_resilience_monthly[:,5] : []
    )
end


"""
	backup_reliability(d::Dict, p::REoptInputs, r::Dict)

Return dictionary of backup reliability results.

# Arguments
- `d::Dict`: REopt results dictionary. 
- `p::REoptInputs`: REopt Inputs Struct.
- `r::Dict`: Dictionary of inputs for reliability calculations. If r not included then uses all defaults. 
Possible keys in r:
    -generator_operational_availability::Real = 0.995       Fraction of year generators not down for maintenance
    -generator_failure_to_start::Real = 0.0094              Chance of generator starting given outage
    -generator_mean_time_to_failure::Real = 1100            Average number of time steps between a generator's failures. 1/(failure to run probability). 
    -num_generators::Int = 1                                Number of generators.
    -generator_size_kw::Real = 0.0                          Backup generator capacity. 
    -num_battery_bins::Int = depends on battery sizing      Number of bins for discretely modeling battery state of charge
    -battery_operational_availability::Real = 0.97          Likelihood battery will be available at start of outage       
    -pv_operational_availability::Real = 0.98               Likelihood PV will be available at start of outage
    -max_outage_duration::Int = 96                          Maximum outage duration modeled
    -microgrid_only::Bool = false                           Determines how generator, PV, and battery act during islanded mode

"""
function backup_reliability(d::Dict, p::REoptInputs, r::Dict)
    reliability_inputs = backup_reliability_reopt_inputs(d=d, p=p, r=r)
    cumulative_results, fuel_survival, fuel_used = return_backup_reliability(; reliability_inputs... )
    process_reliability_results(cumulative_results, fuel_survival, fuel_used)
end


"""
	backup_reliability(r::Dict)

Return dictionary of backup reliability results.

# Arguments
- `r::Dict`: Dictionary of inputs for reliability calculations. If r not included then uses all defaults. 
Possible keys in r:
-critical_loads_kw::Array                               Critical loads per time step. (Required input)
-microgrid_only::Bool                                   Boolean to check if only microgrid runs during grid outage (defaults to false)
-chp_size_kw::Real                                      CHP capacity. 
-pv_size_kw::Real                                       Size of PV System
-pv_production_factor_series::Array                     PV production factor per time step (required if pv_size_kw in dictionary)
-pv_migrogrid_upgraded::Bool                            If true then PV runs during outage if microgrid_only = TRUE (defaults to false)
-battery_size_kw::Real                                  Battery capacity. If no battery installed then PV disconnects from system during outage
-battery_size_kwh::Real                                 Battery energy storage capacity
-charge_efficiency::Real                                Battery charge efficiency
-discharge_efficiency::Real                             Battery discharge efficiency
-battery_starting_soc_series_fraction::Array            Battery percent state of charge time series during normal grid-connected usage
-generator_failure_to_start::Real = 0.0094              Chance of generator starting given outage
-generator_mean_time_to_failure::Real = 1100            Average number of time steps between a generator's failures. 1/(failure to run probability). 
-num_generators::Int = 1                                Number of generators. 
-generator_size_kw::Real = 0.0                          Backup generator capacity. 
-num_battery_bins::Int = num_battery_bins_default(r[:battery_size_kw],r[:battery_size_kwh])     Number of bins for discretely modeling battery state of charge
-max_outage_duration::Int = 96                          Maximum outage duration modeled

"""
function backup_reliability(r::Dict)
    reliability_inputs = backup_reliability_inputs(r=r)
	cumulative_results, fuel_survival, fuel_used = return_backup_reliability(; reliability_inputs... )
	process_reliability_results(cumulative_results, fuel_survival, fuel_used)
end


function num_battery_bins_default(size_kw::Real, size_kwh::Real)::Int
    if size_kw == 0
        return 1
    else
        duration = size_kwh / size_kw
        return Int(duration * 20)
    end
end
