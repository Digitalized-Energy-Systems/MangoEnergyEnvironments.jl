using Test

using MangoEnergyEnvironments
using Mango
using Dates

@role struct BranchFailureHandler 
    counter::Int = 0
    msg_counter::Int = 0
end

@testset "MESEnvironmentShallowTest" begin 
    monee_net = fetch_example_net()
    behavior = RestorationEnvironmentBehavior(net=monee_net)
    world = create_world(DateTime(2024, 08, 1, 0, 0, 0), behavior=behavior, 
            communication_sim=SimpleCommunicationSimulation(default_delay_s=0.02))
    
    # Every node has one agent
    for node in monee_net.nodes
        add_agent_composed_of(world, BranchFailureHandler(); suggested_aid=node.tid)
    end 

    # topology based on grid
    topology_grid = create_topology((topology) -> topology_based_on_grid(monee_net, topology, world))

    # system behavior to handle branch failures
    behavior_in(world, on_global_event=BranchFailureEvent, role_types=BranchFailureHandler) do role, _
        # remember the failure
        role.counter += 1

        # inform neighbors about the failure
        send_messages(role, "Failure attention!", topology_neighbors(role))
    end
    behavior_in(world, on_message=String, role_types=BranchFailureHandler) do role, msg,_
        # just count the messages received
        role.msg_counter += 1
    end

    # define the failure event
    failures = [Failure(delay_s=2, branch_ids=[(monee_net.branches[3].id, monee_net.branches[3].nid)])]

    # simulate the world with failures
    activate(world) do
        # schedule all failures for the whole simulation
        for failure in failures
            schedule_failure(behavior, world, clock(world), failure)
        end
        # step until simulation_duration_s reached with given step_size
        discrete_step_until(world, 10)
    end
    
    @test world[1][1].counter == 1
    @test world[1][1].msg_counter == 1
    @test world[2][1].counter == 1
end