export fetch_cigre_net, fetch_monee_net, fetch_example_net, nx_edge_centrality, connected_components, 
    energyflow, upper, solve_load_shedding_optimization, calc_general_resilience_performance, py_print,
    solve_load_shedding_optimization_relaxed

using PyCall

function energyflow(monee_net::PyObject)
    monee = pyimport("monee")
    return monee.run_energy_flow(monee_net)
end

function upper(value)
    monee = pyimport("monee")
    return monee.model.upper(value)
end

function edge_centrality(net)
    nx = pyimport("networkx")
    return nx.edge_betweenness_centrality(net.graph)
end

function connected_components(net)
    nx = pyimport("networkx")
    return list(nx.connected_components(net.graph))
end

function create_monee_bench()
    mes = pyimport("monee.network.mes")
    return mes.create_monee_benchmark_net()
end

function create_mv_multi_cigre()
    mes = pyimport("monee.network.mes")
    return mes.create_mv_multi_cigre()
end

function create_monee_net(network_name)
    if network_name == "monee"
        return create_monee_bench()
    end
    if network_name == "cigre"
        return create_mv_multi_cigre()
    end
end

function fetch_example_net()
    return create_monee_net("monee")
end

function fetch_cigre_net()
    return create_monee_net("cigre")
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
        (0.5,1.5),
        (0.5,1.5),
        (0.5,1.5),
        (0,10),
        (0,10),
        use_ext_grid_bounds=false,
    )
end

function calc_general_resilience_performance(net)
    monee = pyimport("monee")
    monee.problem.calc_general_resilience_performance(net, inv=true)
end

function py_print(data)
    pyprint(data)
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