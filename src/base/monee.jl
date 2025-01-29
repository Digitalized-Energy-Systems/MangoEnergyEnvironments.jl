export fetch_monee_net, fetch_example_net, nx_edge_centrality, connected_components, energyflow, upper

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
    return fetch_monee_net("example")
end