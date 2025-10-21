![lifecycle](https://img.shields.io/badge/lifecycle-experimental-blue.svg)
[![MIT License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/Digitalized-Energy-Systems/MangoEnergyEnvironments.jl/blob/development/LICENSE)

# Mango Energy Environments

This package contains environments for Mango.jl from the energy domain. Currently there are the following environments:
* A Multi-Energy Restoration Environment (based on monee)

## Concept

The general idea of this package is publishing the concrete environment implementations used for different agent-based systems. These environment are typically implemented using the Mango.jl world environment API, and are provided as `EnvironmentBehaviors`. 

## Multi-Energy Restoration Environment

The MES Restoration Environment uses monee to simulate the underlying environment (a coupled energy system) and contains some usefull functions to apply agent to the energy restoration problem, such as topology creations (based on the physical network) and observers and actions to interact with the physical simulations. Further you can use `schedule_failure` to implement a failure at a specified time. The physicial environment will update itself when appropriate. 

### Note:
To use this environment it is necessary to install `monee` (pypi) in the PyCall Python environment.

### Example

```julia
using MangoEnergyEnvironments
using Mango
using Dates

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
```