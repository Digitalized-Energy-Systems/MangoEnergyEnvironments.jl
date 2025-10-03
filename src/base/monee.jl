export fetch_cigre_net, fetch_monee_net, fetch_example_net, nx_edge_centrality, connected_components, 
    energyflow, upper, solve_load_shedding_optimization, calc_general_resilience_performance, py_print,
    solve_load_shedding_optimization_relaxed

using PyCall

C_DIR = @__DIR__
PY_NETWORK = C_DIR * "/monee_net.py"

function energyflow(monee_net::PyObject)
    monee = pyimport("monee")
    return monee.run_energy_flow(monee_net)
end

function upper(value)
    monee = pyimport("monee")
    return monee.model.upper(value)
end

function nx_edge_centrality(monee_net::PyObject)
    @pyinclude(PY_NETWORK)
    return py"edge_centrality"(monee_net)
end

function connected_components(monee_net::PyObject)
    @pyinclude(PY_NETWORK)
    return py"connected_components"(monee_net)
end

function fetch_monee_net(network_name::String)
    @pyinclude(PY_NETWORK)
    return py"create_monee_net"(network_name)
end

function fetch_example_net()
    return fetch_monee_net("monee")
end

function fetch_cigre_net()
    return fetch_monee_net("cigre")
end

function solve_load_shedding_optimization(net; 
    bound_vm=(0.9, 1.1), 
    bound_t=(0.95, 1.05), 
    bound_pressure=(0.9, 2), 
    ext_el_grid_bound=(-0.0, 1), 
    ext_gas_grid_bound=(-0.0, 1))
    
    monee = pyimport("monee")
    monee.solve_load_shedding_problem(net, bound_vm, 
        bound_t, 
        bound_pressure, 
        ext_el_grid_bound, 
        ext_gas_grid_bound)
end

function solve_load_shedding_optimization_relaxed(net)
    monee = pyimport("monee")
    monee.solve_load_shedding_problem(net, 
        (0,2),
        (0,2),
        (0,2),
        (0,10),
        (0,10)
    )
end

function calc_general_resilience_performance(net)
    monee = pyimport("monee")
    monee.problem.calc_general_resilience_performance(net, inv=true)
end

function py_print(data)
    py"print"(data)
end

function enable_poisson_com_for_monee(world, monee_net; base_delay_per_message=20)
    topology_grid_all = create_topology((topology) -> topology_based_on_grid(monee_net, topology, world, include_childs=true, include_cps=true), tid=:all)
    aid_graph = topology_to_aid_graph(topology_grid_all)
    poisson_com_provider = create_distribution_based_com_sim(aid_graph, agents(world), base_delay_per_message=base_delay_per_message, label_replacer=(label) -> begin
        if occursin("branch", label)
            label_splitted = split(label, "-")
            label = "node-$(label_splitted[2])"
        end
        return label
    end)
    world.communication_sim = poisson_com_provider
end