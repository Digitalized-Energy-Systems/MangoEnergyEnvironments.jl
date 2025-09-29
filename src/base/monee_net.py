import random

import monee.model as mm
from monee.model.branch import PowerLine
from monee.model.node import Bus
from monee.model.child import PowerGenerator, ExtPowerGrid, PowerLoad, Source
from monee.io.from_pandapower import from_pandapower_net
import monee.express as mx
import monee.network.mes as mes
import monee

import pandapower.networks as pn
import networkx as nx

def edge_centrality(net):
    return nx.edge_betweenness_centrality(net.graph)

def connected_components(net):
    return list(nx.connected_components(net.graph))

def create_monee_bench():
    return mes.create_monee_benchmark_net()

def create_cigre():
    random.seed(9002)
    pnet = pn.create_cigre_network_mv(with_der="pv_wind")

    monee_net = from_pandapower_net(pnet)
    new_mes = monee_net.copy()
    bus_to_gas_junc = mes.create_gas_net_for_power(monee_net, new_mes, 1, scaling=1)
    bus_index_to_junction_index, bus_index_to_end_junction_index = (
        mes.create_heat_net_for_power(monee_net, new_mes, 1)
    )
    return new_mes

def create_monee_net(network_name):
    if network_name == "monee":
        return create_monee_bench()
    if network_name == "cigre":
        return create_cigre()


if __name__ == "__main__":
    # mn = create_monee_net("monee")

    # print(mn.statistics())
    # print(mn.as_dataframe_dict_str())
    # print(monee.run_energy_flow(mn))
    # print([(type(node.grid), type(node.model)) for node in mn.childs])

    mn = create_monee_net("cigre")

    print(mn.statistics())
    print(mn.as_dataframe_dict_str())
    print(monee.run_energy_flow(mn))
    print([(type(node.grid), type(node.model)) for node in mn.childs])
