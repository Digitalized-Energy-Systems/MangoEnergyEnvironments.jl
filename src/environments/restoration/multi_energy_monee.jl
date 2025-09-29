export Failure,
NodeFailureEvent,
BranchFailureEvent,
CustomFailureEvent,
RestorationEnvironmentBehavior,
schedule_failure,
topology_based_on_grid,
topology_based_on_grid_groups,
on_node_failure,
on_branch_failure,
on_custom_failure,
create_branch_aid,
results,
apply_failures

using Dates
using Mango
using PyCall

@kwdef struct Failure
    delay_s::Real
    branch_ids::Vector{Tuple} = Vector()
    node_ids::Vector{Int} = Vector()
    custom::Union{Function,Nothing} = nothing
    custom_id::Union{Int,Nothing} = nothing
end

struct BranchFailureEvent
    branch_id::Tuple
end
struct NodeFailureEvent
    node_id::Int
end
struct CustomFailureEvent
    custom_id::Any
end

@kwdef mutable struct RestorationEnvironmentBehavior <: Behavior
    net::PyObject
    net_results::Union{PyObject,Nothing} = nothing
    failures::Vector{Failure} = Vector()
    on_branch_failure::Function = (branch_id) -> nothing
    on_node_failure::Function = (node_id) -> nothing
    on_custom_failure::Function = (custom_id) -> nothing
    dirty::Bool = false
end

function Mango.on_step(behavior::RestorationEnvironmentBehavior, env::DefaultEnvironment, clock::Clock, time_step_s::Real)
    if behavior.dirty
        @debug"Energyflow executed $(clock.simulation_time) + $(time_step_s)"
        behavior.net_results = energyflow(behavior.net)
        env_net = results(behavior).network
        behavior.dirty = false
    end
end

function Mango.initialize(behavior::RestorationEnvironmentBehavior)
    @debug "Energyflow initialized"
    behavior.net_results = energyflow(behavior.net)
end

function Mango.install(behavior::RestorationEnvironmentBehavior, agent::Agent; id::Any, type::Symbol)

    if type == :child
        install_observer(agent) do 
            env_net = results(behavior).network
            child = env_net.child_by_id(id)
            node = env_net.node_by_id(child.node_id)

            return merge(node.model.values, child.model.values)
        end
        install_action(agent, :regulate) do regulation_factor
            env_net = net(behavior)
            child = env_net.child_by_id(id)

            child.model.regulation = regulation_factor
            behavior.dirty = true
        end
    elseif type == :node
        install_observer(agent) do 
            env_net = results(behavior).network
            node = env_net.node_by_id(id)

            return node.model.values
        end        
        if haskey(net(behavior).node_by_id(id).model.values, "regulation")
            install_action(agent, :regulate) do regulation_factor
                env_net = net(behavior)
                node = env_net.node_by_id(id)

                node.model.regulation = regulation_factor
                behavior.dirty = true
            end
        end

    elseif type == :branch
        install_observer(agent) do 
            env_net = results(behavior).network
            branch = env_net.branch_by_id(id)

            return branch.model.values
        end
        install_action(agent, :switch) do 
            env_net = net(behavior)
            branch = env_net.branch_by_id(id)

            branch.model.on_off = branch.model.on_off == 0 ? 1 : 0
            behavior.dirty = true
        end
        if haskey(net(behavior).branch_by_id(id).model.values, "regulation")
            install_action(agent, :regulate) do regulation_factor
                env_net = net(behavior)
                branch = env_net.branch_by_id(id)

                branch.model.regulation = regulation_factor
                behavior.dirty = true
            end
        end
    end
end

function on_node_failure(f::Function, behavior::RestorationEnvironmentBehavior)
    behavior.on_node_failure = f
end

function on_branch_failure(f::Function, behavior::RestorationEnvironmentBehavior)
    behavior.on_branch_failure = f
end

function on_custom_failure(f::Function, behavior::RestorationEnvironmentBehavior)
    behavior.on_custom_failure = f
end

failures(behavior::RestorationEnvironmentBehavior) = behavior.failures
net(behavior::RestorationEnvironmentBehavior) = behavior.net
results(behavior::RestorationEnvironmentBehavior) = behavior.net_results

function apply_failures(net, failures::Vector{Failure})
    for failure in failures
        for (branch_id, nid) in failure.branch_ids            
            net.branch_by_id(branch_id).active = false
        end
        for node_id in failure.node_ids
            net.node_by_id(node_id).active = false
        end
        if !isnothing(failure.custom)
            failure.custom(net)
        end
    end
end

function on_failure(behavior::RestorationEnvironmentBehavior, env::Environment, failures::Vector{Failure})
    for failure in failures
        for (branch_id, nid) in failure.branch_ids            
            net(behavior).branch_by_id(branch_id).active = false
            
            behavior.dirty = true
            behavior.on_branch_failure(branch_id)
            @info "Emit global event $branch_id, $nid"
            emit_global_event(env, BranchFailureEvent(branch_id))
        end
        for node_id in failure.node_ids
            net(behavior).node_by_id(node_id).active = false
            
            behavior.dirty = true
            behavior.on_node_failure(node_id)
            @info "Emit global event $node_id"
            emit_global_event(env, NodeFailureEvent(node_id))
        end
        if !isnothing(failure.custom)
            failure.custom(net(behavior))

            behavior.dirty = true
            behavior.on_custom_failure(failure.custom_id)
            @info "Emit global child event $(failure.custom_id)"
            emit_global_event(env, CustomFailureEvent(failure.custom_id))
        end
    end
end

function schedule_failure(behavior::RestorationEnvironmentBehavior, world::World, clock::Clock, failure::Failure)
    push!(behavior.failures, failure)

    @info "Schedule Failure $(failure.delay_s)" clock.simulation_time
    schedule(env(world), DateTimeTaskData((clock.simulation_time) + Millisecond(trunc(Int, failure.delay_s * 1000)))) do
        @info "Activating Failure $(failure.delay_s)"
        on_failure(behavior, env(world), [failure])
    end
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

function topology_based_on_grid(monee_net::PyObject, topology::Topology, world::World; include_childs=false, include_cps=false)
    for node in monee_net.nodes
        agents = []
        if haskey(world.container.agents, node.tid)
            push!(agents, world[node.tid])
        end
        if include_childs
            for child in monee_net.childs_by_ids(node.child_ids)
                if haskey(world.container.agents, child.tid)
                    push!(agents, world[child.tid])
                end
            end
        end
        add_node!(topology, agents..., id=node.id)
    end
    for branch in monee_net.branches
        if !include_cps && branch.model.is_cp()
            continue
        end
        state = branch.active && branch.model.on_off == 1 ? Mango.NORMAL : Mango.INACTIVE # not active = not working, on_off = controllable state
        add_edge!(topology, branch.from_node_id, branch.to_node_id, state)
    end
end

function _topology_based_grid_groups_by_sector(components, 
    monee_net::PyObject, 
    topology::Topology, 
    world::World, 
    sector::Union{Nothing,String}=nothing;
    include_nodes=false,
    include_childs=true,
    include_cps=false,
    include_branches::Vector{String}=Vector{String}())
    
    for component in components
        id_list = []
        added = []
        for component_id in component
            
            node = monee_net.node_by_id(component_id)
            # skip if provided sector is not present
            if !isnothing(sector) && (node.grid isa Vector || !occursin(sector, pystr(node.grid)))
                continue
            end
            
            agent_ids = []
            if include_nodes
                if haskey(world.container.agents, node.tid)
                    push!(agent_ids, node.tid)
                end
            end
            if include_childs
                for child in monee_net.childs_by_ids(node.child_ids)
                    if haskey(world.container.agents, child.tid)
                        push!(agent_ids, child.tid)
                    end
                end
            end
            if include_cps
                comps = monee_net.components_connected_to(node.id)
                for comp in comps
                    if comp.model.is_cp() && comp.tid ∉ added
                        push!(agent_ids, comp.tid)
                    end
                end
                if node.model.is_cp()
                    push!(agent_ids, node.tid)
                end
            end
            for branch_type in include_branches
                branches = monee_net.branches_connected_to(node.id)
                for branch in branches
                    if occursin(branch_type, pystr(branch.model)) && branch.tid ∉ added
                        push!(agent_ids, branch.tid)
                    end
                end
            end
            push!(id_list, (node.id, agent_ids))
            append!(added, agent_ids)
        end
        added_node_id = []
        for (id, agent_ids) in id_list
            if length(agent_ids) == 0
                continue
            end
            agents = [world[aid] for aid in agent_ids]
            nid = add_node!(topology, agents..., id=id)
            
            if length(added_node_id) == 0
                set_characteristic!(topology, nid, agents[1], :leader)
            end
            
            push!(added_node_id, id)
            for other_id in added_node_id
                if id != other_id
                    add_edge!(topology, id, other_id, Mango.NORMAL)
                end
            end
        end
    end
end

function topology_based_on_grid_groups(monee_net::PyObject, topology::Topology, world::World; 
    separate_sectors::Union{Nothing,Vector{String}}=nothing,
    include_cps::Bool=false, 
    include_nodes::Bool=false,
    include_childs::Bool=true,
    include_branches::Vector{String}=Vector{String}())
    components = connected_components(monee_net)
    if isnothing(separate_sectors)
        return _topology_based_grid_groups_by_sector(components, monee_net, topology, world, include_cps=include_cps, include_nodes=include_nodes, include_childs=include_childs, include_branches=include_branches)
    else
        for sector in separate_sectors
            _topology_based_grid_groups_by_sector(components, monee_net, topology, world, sector, include_cps=include_cps, include_nodes=include_nodes, include_childs=include_childs, include_branches=include_branches)
        end
    end
end
