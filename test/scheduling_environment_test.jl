using Test
using Dates

using InfrastructureSystems
using PowerSystems
using PowerSimulations
using PowerSystemCaseBuilder

using Mango
using MangoEnergyEnvironments
using DistributedResourceOptimization

@role struct PowerLoadMonitoring 
    counter::Int = 0
end

function Mango.on_agent_event(role::PowerLoadMonitoring, clock::Clock, event::PowerUpdateInfo)
    role.counter += 1
end

@testset "PowerSystemsShallowTest" begin
    sys = build_system(PSITestSystems, "c_sys5_bat")
    behavior = PowerSystemsBehavior(sys, [ThermalStandard, RenewableDispatch, PowerLoad])
    initial_time = calculate_initial_time(behavior)
    world = create_world(initial_time, behavior=behavior, 
        communication_sim=SimpleCommunicationSimulation(default_delay_s=0.1, loss_percent=0))

    # Load agents
    load_components = get_components_by_type(behavior, [PowerLoad])
    for component in load_components
        agent = GeneralAgent()
        register(world, agent, get_name(component))
        add(agent, PowerLoadMonitoring())
    
        install(world.env, agent, id=InfrastructureSystems.get_uuid(component), type=:component)
    end

    # simulate the world with failures
    activate(world) do
        # step until two days are over
        discrete_step_until(world, Day(3))
    end

    @test world[1][PowerLoadMonitoring].counter == 48
end
