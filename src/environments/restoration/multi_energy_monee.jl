using Dates
using Mango
using PyCall

@kwdef struct Failure
    delay_s::Real
    branch_ids::Vector{Tuple} = Vector()
    node_ids::Vector{Int} = Vector()
end

struct BranchFailureEvent
    branch_id::Tuple
end
struct NodeFailureEvent
    node_id::Int
end

@kwdef mutable struct MultiEnergyRestorationEnvironment <: Environment
    net::PyObject
    failures::Vector{Failure} = Vector()
    on_branch_failure::Function = (branch_id) -> nothing
    on_node_failure::Function = (node_id) -> nothing
end

function on_node_failure(f::Function, restoration_env::MultiEnergyRestorationEnvironment)
    restoration_env.on_node_failure = f
end
function on_branch_failure(f::Function, restoration_env::MultiEnergyRestorationEnvironment)
    restoration_env.on_branch_failure = f
end

failures(restoration_env::MultiEnergyRestorationEnvironment) = restoration_env.failures
net(restoration_env::MultiEnergyRestorationEnvironment) = restoration_env.net

function on_failure(restoration_env::MultiEnergyRestorationEnvironment, world::World, failures::Vector{Failure})
    for failure in failures
        for branch_id in failure.branch_ids
            net(restoration_env).branch_by_id(branch_id).active = false
            restoration_env.on_branch_failure(branch_id)
            emit_global_event(world, BranchFailureEvent(branch_id))
        end
        for node_id in failure.node_ids
            net(restoration_env).node_by_id(node_id).active = false
            restoration_env.on_node_failure(node_id)
            emit_global_event(world, NodeFailureEvent(node_id))
        end
    end
end

function schedule_failure(restoration_env::MultiEnergyRestorationEnvironment, world::World, clock::Clock, failure::Failure)
    push!(restoration_env.failures, failure)

    schedule(world, DateTimeTaskData((clock.simulation_time) + Second(failure.delay_s))) do
        on_failure(restoration_env, world, [failure])
    end
end

function Mango.on_step(space::MultiEnergyRestorationEnvironment, world::World, clock::Clock, time_step_s::Real)
    energyflow(space.net)
end

"""
Convention: branch-id1-id2 

The higher id is always first. With this convention the branch agent is always known when
the node as neighbor is known.
"""
function create_branch_aid(branch_id::Tuple)
    if branch_id[1] > branch_id[2]
        return "branch-$(branch_id[1])-$(branch_id[2])"
    else
        return "branch-$(branch_id[2])-$(branch_id[1])"
    end
end

function convert_to_topology(monee_net::PyObject, topology::Topology, container::SimulationContainer)
    for node in monee_net.nodes
        add_node!(topology, container[string(node.id)], id=node.id)
    end
    for branch in monee_net.branches
        state = branch.active ? Mango.NORMAL : Mango.INACTIVE
        add_edge!(topology, branch.from_node_id, branch.to_node_id, state)
    end
end