using Test

using MangoEnergyEnvironments
using Mango
using Dates

using PowerSystems
using PowerSimulations
using PowerSystemCaseBuilder
using Logging

# dl = ConsoleLogger(stderr, Logging.Debug)
# global_logger(dl)

@role struct PowerSystemComponentManager 
    counter::Int = 0
end

function Mango.on_step(role::PowerSystemComponentManager, env::Environment, clock::Clock, step_size::Real)
    role.counter += 1
end

@role struct PowerLoadAggregator
    cluster_demand_map::Dict{AgentAddress, Dict{DateTime, <:Real}}
end

@role struct PowerLoadMonitoring 
    demand_map::Dict{DateTime, <:Real}
end

function Mango.on_step(role::PowerLoadMonitoring, env::Environment, clock::Clock, step_size::Real)

end

struct PowerLoadInfo
    power_load::Real
    time::DateTime
end

function Mango.handle_message(role::PowerLoadMonitoring, message::PowerLoadInfo, meta::Any)
    sender = sender_address(meta)

    load = message.power_load
    time = message.time

    role.demand_map[sender][time] = power_load
    sender_map = get!(role.demand, sender, default=Dict(time=>load))
    get!(sender_map, time, default=load)
end

@testset "PowerSystemEnvironment" begin 
    sys = build_system(PSITestSystems, "c_sys5_bat")
    behavior = PowerSystemsBehavior(sys, [ThermalStandard, RenewableDispatch, PowerLoad])
    initial_time = calculate_initial_time(behavior)
    world = create_world(initial_time, behavior=behavior, 
        communication_sim=SimpleCommunicationSimulation(default_delay_s=0.02))
    
    # Every node has one agent
    components = get_possible_components(behavior)
    for component in components
        add_agent_composed_of(world, PowerSystemComponentManager(); suggested_aid=get_name(component))
    end 

    # topology
    topo = complete_topology(length(components))
    auto_assign!(topo, world)

    # simulate the world with failures
    activate(world) do
        # step until simulation_duration_s reached with given step_size
        discrete_step_until(world, Second(Day(1)).value)
    end
    
    @test world[1][1].counter == 25
end