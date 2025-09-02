import random

import monee.model as mm
from monee.model.branch import PowerLine
from monee.model.node import Bus
from monee.model.child import PowerGenerator, ExtPowerGrid, PowerLoad, Source
import monee.express as mx
import monee.network.mes as mes
import monee

import networkx as nx

def edge_centrality(net):
    return nx.edge_betweenness_centrality(net.graph)

def connected_components(net):
    return list(nx.connected_components(net.graph))

def create_four_line_example():
    random.seed(9002)
    pn = mm.Network()

    node_0 = pn.node(
        Bus(base_kv=1),
        mm.EL,
        child_ids=[pn.child(PowerGenerator(p_mw=0.1, q_mvar=0, regulation=0.5))],
    )
    node_1 = pn.node(
        Bus(base_kv=1),
        mm.EL,
        child_ids=[pn.child(ExtPowerGrid(p_mw=0.1, q_mvar=0, vm_pu=1, va_degree=0))],
    )
    node_2 = pn.node(
        Bus(base_kv=1),
        mm.EL,
        child_ids=[pn.child(PowerLoad(p_mw=0.1, q_mvar=0))],
    )
    node_3 = pn.node(
        Bus(base_kv=1),
        mm.EL,
        child_ids=[pn.child(PowerLoad(p_mw=0.2, q_mvar=0))],
    )
    node_4 = pn.node(
        Bus(base_kv=1),
        mm.EL,
        child_ids=[pn.child(PowerLoad(p_mw=0.2, q_mvar=0))],
    )
    node_5 = pn.node(
        Bus(base_kv=1),
        mm.EL,
        child_ids=[pn.child(PowerGenerator(p_mw=0.3, q_mvar=0, regulation=0.5))],
    )
    node_6 = pn.node(
        Bus(base_kv=1),
        mm.EL,
        child_ids=[pn.child(PowerGenerator(p_mw=0.2, q_mvar=0, regulation=0.5))],
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

    new_mes = pn.copy()

    # gas
    bus_to_gas_junc = mes.create_gas_net_for_power(pn, new_mes, 1)
    new_mes.childs_by_type(Source)[0].model.mass_flow = -10
    new_mes.childs_by_type(Source)[0].model.regulation = 1

    # heat
    bus_index_to_junction_index, bus_index_to_end_junction_index = (
        mes.create_heat_net_for_power(pn, new_mes, 0)
    )
    new_water_junc = mx.create_water_junction(new_mes)
    mx.create_sink(
        new_mes,
        new_water_junc,
        mass_flow=0.075,
    )
    new_water_junc_2 = mx.create_water_junction(new_mes)
    mx.create_sink(
        new_mes,
        new_water_junc_2,
        mass_flow=0.075,
    )
    mx.create_heat_exchanger(
        new_mes,
        from_node_id=new_water_junc,
        to_node_id=new_water_junc_2,
        diameter_m=0.20,
        q_mw=0.001,
    )
    new_water_junc_3 = mx.create_water_junction(new_mes)
    mx.create_sink(
        new_mes,
        new_water_junc_3,
        mass_flow=0.075,
    )
    mx.create_heat_exchanger(
        new_mes,
        from_node_id=new_water_junc_2,
        to_node_id=new_water_junc_3,
        diameter_m=0.20,
        q_mw=0.001,
    )

    mx.create_p2g(
        new_mes,
        from_node_id=node_4,
        to_node_id=bus_to_gas_junc[node_4],
        efficiency=0.7,
        mass_flow_setpoint=0.005,
        regulation=0,
    )
    mx.create_chp(
        new_mes,
        power_node_id=node_1,
        heat_node_id=bus_index_to_junction_index[node_0],
        heat_return_node_id=new_water_junc,
        gas_node_id=bus_to_gas_junc[node_3],
        mass_flow_setpoint=0.0005,
        diameter_m=0.3,
        efficiency_power=0.5,
        efficiency_heat=0.5,
    )
    mx.create_g2p(
        new_mes,
        from_node_id=bus_to_gas_junc[node_1],
        to_node_id=node_1,
        efficiency=0.9,
        p_mw_setpoint=0.3,
        regulation=0,
    )
    mx.create_g2p(
        new_mes,
        from_node_id=bus_to_gas_junc[node_6],
        to_node_id=node_6,
        efficiency=0.9,
        p_mw_setpoint=1.5,
        regulation=0,
    )
    new_mes.branch(
        PowerLine(
            length_m=100,
            r_ohm_per_m=0.00007,
            x_ohm_per_m=0.00007,
            parallel=1,
            backup=True,
            on_off=0
        ),
        node_4,
        node_0,
    )
    new_mes.branch(
        PowerLine(
            length_m=100,
            r_ohm_per_m=0.00007,
            x_ohm_per_m=0.00007,
            parallel=1,
            backup=True,
            on_off=0
        ),
        node_6,
        node_2,
    )
    return new_mes


def create_monee_net(network_name):
    if network_name == "example":
        return create_four_line_example()


if __name__ == "__main__":
    mn = create_monee_net("example")

    print(mn.statistics())
    print(mn.as_dataframe_dict_str())
    print(monee.run_energy_flow(mn))
    print([(type(node.grid), type(node.model)) for node in mn.childs])
