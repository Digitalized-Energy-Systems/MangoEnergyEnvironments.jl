from monee.model.core import Network
from monee.model.grid import PowerGrid
from monee.model.branch import PowerLine
from monee.model.node import Bus
from monee.model.child import PowerGenerator, ExtPowerGrid, PowerLoad

import networkx as nx


def edge_centrality(net):
    return nx.edge_betweenness_centrality(net.graph)


def create_four_line_example():
    pn = Network(PowerGrid(name="power", sn_mva=1))

    node_0 = pn.node(
        Bus(base_kv=1),
        child_ids=[pn.child(PowerGenerator(p_mw=1, q_mvar=0))],
    )
    node_1 = pn.node(
        Bus(base_kv=1),
        child_ids=[pn.child(ExtPowerGrid(p_mw=0.1, q_mvar=0, vm_pu=1, va_degree=0))],
    )
    node_2 = pn.node(
        Bus(base_kv=1),
        child_ids=[pn.child(PowerLoad(p_mw=1, q_mvar=0))],
    )
    node_3 = pn.node(
        Bus(base_kv=1),
    )
    node_4 = pn.node(
        Bus(base_kv=1),
        child_ids=[pn.child(PowerLoad(p_mw=1, q_mvar=0))],
    )
    node_5 = pn.node(
        Bus(base_kv=1),
        child_ids=[pn.child(PowerGenerator(p_mw=1, q_mvar=0))],
    )
    node_6 = pn.node(
        Bus(base_kv=1),
        child_ids=[pn.child(PowerGenerator(p_mw=1, q_mvar=0))],
    )

    pn.branch(
        PowerLine(length_m=100, r_ohm_per_m=0.00007, x_ohm_per_m=0.00007, parallel=1),
        node_0,
        node_1,
    )
    pn.branch(
        PowerLine(length_m=100, r_ohm_per_m=0.00007, x_ohm_per_m=0.00007, parallel=1),
        node_1,
        node_2,
    )
    pn.branch(
        PowerLine(length_m=100, r_ohm_per_m=0.00007, x_ohm_per_m=0.00007, parallel=1),
        node_1,
        node_5,
    )
    pn.branch(
        PowerLine(length_m=100, r_ohm_per_m=0.00007, x_ohm_per_m=0.00007, parallel=1),
        node_2,
        node_3,
    )
    pn.branch(
        PowerLine(length_m=100, r_ohm_per_m=0.00007, x_ohm_per_m=0.00007, parallel=1),
        node_3,
        node_4,
    )
    pn.branch(
        PowerLine(length_m=100, r_ohm_per_m=0.00007, x_ohm_per_m=0.00007, parallel=1),
        node_3,
        node_6,
    )

    # TIE SWITCH LINES

    branch = pn.branch(
        PowerLine(length_m=100, r_ohm_per_m=0.00007, x_ohm_per_m=0.00007, parallel=1),
        node_4,
        node_0,
    )
    pn.branch_by_id(branch).active = False
    branch = pn.branch(
        PowerLine(length_m=100, r_ohm_per_m=0.00007, x_ohm_per_m=0.00007, parallel=1),
        node_6,
        node_2,
    )
    pn.branch_by_id(branch).active = False
    return pn


def create_monee_net(network_name):
    if network_name == "example":
        return create_four_line_example()
