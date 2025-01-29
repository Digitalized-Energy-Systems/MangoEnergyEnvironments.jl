export Failure,
    NodeFailureEvent,
    BranchFailureEvent,
    RestorationEnvironmentBehavior,
    schedule_failure,
    topology_based_on_grid,
    topology_based_on_grid_groups,
    on_node_failure,
    on_branch_failure,
    create_branch_aid

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

@kwdef mutable struct RestorationEnvironmentBehavior <: Behavior
    net::PyObject
    net_results::Union{PyObject,Nothing} = nothing
    failures::Vector{Failure} = Vector()
    on_branch_failure::Function = (branch_id) -> nothing
    on_node_failure::Function = (node_id) -> nothing
end

function on_node_failure(f::Function, behavior::RestorationEnvironmentBehavior)
    behavior.on_node_failure = f
end

function on_branch_failure(f::Function, behavior::RestorationEnvironmentBehavior)
    behavior.on_branch_failure = f
end

failures(behavior::RestorationEnvironmentBehavior) = behavior.failures
net(behavior::RestorationEnvironmentBehavior) = behavior.net

function on_failure(behavior::RestorationEnvironmentBehavior, env::Environment, failures::Vector{Failure})
    for failure in failures
        for branch_id in failure.branch_ids
            net(behavior).branch_by_id(branch_id).active = false
            behavior.on_branch_failure(branch_id)
            emit_global_event(env, BranchFailureEvent(branch_id))
        end
        for node_id in failure.node_ids
            net(behavior).node_by_id(node_id).active = false
            behavior.on_node_failure(node_id)
            emit_global_event(env, NodeFailureEvent(node_id))
        end
    end
end

function schedule_failure(behavior::RestorationEnvironmentBehavior, world::World, clock::Clock, failure::Failure)
    push!(behavior.failures, failure)

    schedule(env(world), DateTimeTaskData((clock.simulation_time) + Second(failure.delay_s))) do
        on_failure(behavior, env(world), [failure])
    end
end

function Mango.on_step(behavior::RestorationEnvironmentBehavior, env::Environment, clock::Clock, time_step_s::Real)
    @info "Energyflow executed $(clock.simulation_time) + $(time_step_s)"
    behavior.net_results = energyflow(behavior.net)
end

function Mango.initialize(behavior::RestorationEnvironmentBehavior)
    @info "Energyflow initialized"
    behavior.net_results = energyflow(behavior.net)
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

function topology_based_on_grid(monee_net::PyObject, topology::Topology, world::World)
    for node in monee_net.nodes
        agents = []
        node_aid = "node-$(string(node.id))"
        if haskey(world.container.agents, node_aid)
            push!(agents, world[node_aid])
        end
        for id in node.child_ids
            child_aid = "child-$(string(id))"
            if haskey(world.container.agents, child_aid)
                push!(agents, world[child_aid])
            end
        end
        add_node!(topology, agents..., id=node.id)
    end
    for branch in monee_net.branches
        state = branch.active ? Mango.NORMAL : Mango.INACTIVE
        add_edge!(topology, branch.from_node_id, branch.to_node_id, state)
    end
end

function topology_based_on_grid_groups(monee_net::PyObject, topology::Topology, world::World)
    components = connected_components(monee_net)
    for component in components
        id_list = []
        for component_id in component
            node = monee_net.node_by_id(component_id)
            agents = []
            node_aid = "node-$(string(node.id))"
            if haskey(world.container.agents, node_aid)
                push!(agents, world[node_aid])
            end
            for id in node.child_ids
                child_aid = "child-$(string(id))"
                if haskey(world.container.agents, child_aid)
                    push!(agents, world[child_aid])
                end
            end
            push!(id_list, (node.id, agents))
        end
        added_node_id = []
        for (id, agents) in id_list
            add_node!(topology, agents..., id=id)
            push!(added_node_id, id)
            for other_id in added_node_id
                if id != other_id
                    add_edge!(topology, id, other_id, Mango.NORMAL)
                end
            end
        end
    end
end