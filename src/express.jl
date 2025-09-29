
function create_restoration_world(monee_net; with_comunication::Bool=true, start_date::DateTime=DateTime(2024, 08, 1, 0, 0, 0), static_delay_s::Real=0.02)
    behavior = RestorationEnvironmentBehavior(net=monee_net)

    world = create_world(start_date, behavior=behavior, communication_sim=SimpleCommunicationSimulation(default_delay_s=static_delay_s))
    if with_comunication
        enable_poisson_com_for_monee(world, monee_net)
    end
    return world
end

function create_small_benchmark_restoration_world(; 
    with_comunication::Bool=True, 
    start_date::DateTime=DateTime(2024, 08, 1, 0, 0, 0), 
    static_delay_s::Real=0.02)
    
    monee_net = fetch_example_net()
    return create_restoration_environment(monee_net, with_comunication=with_comunication, start_date=start_date, static_delay_s=static_delay_s)
end

function create_cigre_benchmark_restoration_world(; 
    with_comunication::Bool=True, 
    start_date::DateTime=DateTime(2024, 08, 1, 0, 0, 0), 
    static_delay_s::Real=0.02)
    
    monee_net = fetch_cigre_net()
    return create_restoration_environment(monee_net, with_comunication=with_comunication, start_date=start_date, static_delay_s=static_delay_s)
end