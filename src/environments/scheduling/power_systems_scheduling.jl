export PowerSystemsBehavior, calculate_initial_time, get_possible_components, get_components_by_type, PowerUpdateInfo

using Mango
using PowerSystems
using UUIDs
using PowerSystems.InfrastructureSystems: get_initial_timestamp
using Dates
using PowerSystems.InfrastructureSystems: get_uuid

struct PowerUpdateInfo end

@kwdef mutable struct PowerSystemsBehavior <: Behavior
    system::System
    relevant_components::Vector{DataType}
end

function get_components_by_type(behavior::PowerSystemsBehavior, types::Vector{DataType})
    nodes = []
    for c in iterate_components(behavior.system)
        if typeof(c) in types
            push!(nodes, c)
        end
    end
    
    return nodes
end

function get_possible_components(behavior::PowerSystemsBehavior)
    return get_components_by_type(behavior, behavior.relevant_components)
end

function Mango.initialize(behavior::PowerSystemsBehavior, env::Environment, clock::Clock)
    # schedule all value changes imposed by timeseries data@components
    for c in iterate_components(behavior.system)
        if typeof(c) in behavior.relevant_components
            if !supports_time_series(c)
                continue
            end
            for ts in get_time_series_multiple(c)
                date_to_value = Dict()
                dates = []
                res = get_resolution(ts)
                for (time,series) in get_data(ts)
                    for (i,value) in enumerate(series)
                        date = time + res*(i-1)
                        push!(dates, date) # for order
                        date_to_value[date] = value
                    end
                end
                schedule(env, TimeseriesTaskData(dates)) do date
                    own_data = date_to_value
                    own_component = c
                    value_to_set = own_data[date]
                    if typeof(own_component) == RenewableDispatch
                        set_rating!(own_component, value_to_set)
                    else
                        set_max_active_power!(own_component, value_to_set)
                    end
                    # notify agent of update
                    emit_agent_event(env, PowerUpdateInfo(), get_uuid(own_component))
                end
            end
        end
    end
end

function Mango.install(behavior::PowerSystemsBehavior, agent::Agent; id::UUID, type::Symbol)
    device = get_component(behavior.system, id)
    type = typeof(device)
    
    install_observer(agent, :statics) do 
        return Dict(f => getfield(device, f) for f in fieldnames(type))
    end
    install_observer(agent, :max_active_power) do 
        return get_max_active_power(device)
    end
    install_observer(agent, :active_power) do 
        return get_active_power(device)
    end

    if type == ThermalStandard || type == RenewableDispatch || type == EnergyReservoirStorage
        install_action(agent, :regulate) do active_power
            set_active_power!(device, active_power)
        end
    end
end

function calculate_initial_time(behavior::PowerSystemsBehavior)::Dates.DateTime
    initial_date = DateTime(9999)
    for c in iterate_components(behavior.system)
        if typeof(c) in behavior.relevant_components
            if !supports_time_series(c)
                continue
            end
            for ts in get_time_series_multiple(c)
                date = get_initial_timestamp(ts)
                if date < initial_date
                    initial_date = date
                end
            end
        end
    end
    return initial_date
end

function solve_central(behavior::PowerSystemsBehavior, time_horizon=Hour(24))
    template_ed = ProblemTemplate()

    set_device_model!(template_ed, ThermalStandard, ThermalDispatchNoMin)
    set_device_model!(template_ed, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template_ed, PowerLoad, StaticPowerLoad)

    set_network_model!(template_ed, NetworkModel(CopperPlatePowerModel))

    solver = optimizer_with_attributes(HiGHS.Optimizer)

    problem = DecisionModel(
        template_ed,
        behavior.system;
        optimizer = solver,
        horizon = time_horizon, 
    )

    build!(problem; output_dir = mktempdir())
    solve!(problem)

    return OptimizationProblemResults(problem)
end