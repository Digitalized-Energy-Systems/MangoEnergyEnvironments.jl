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

def create_mv_multi_cigre():
    return mes.create_mv_multi_cigre()

def create_monee_net(network_name):
    if network_name == "monee":
        return create_monee_bench()
    if network_name == "cigre":
        return create_mv_multi_cigre()

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
