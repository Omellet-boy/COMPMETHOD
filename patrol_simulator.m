clc;
clear;

% === CONFIGURATION ===
num_vehicles = input('Enter number of vehicles: ');
disp("Random Number Generator Options:");
disp("1. Built-in rand()");
disp("2. Linear Congruential Generator (LCG)");
rng_choice = input('Choose RNG (1 or 2): ');

% === RANDOM NUMBER GENERATOR SETUP ===
function r = lcg(seed, n)
    a = 1664525;
    c = 1013904223;
    m = 2^32;
    r = zeros(1, n);
    r(1) = mod(a * seed + c, m);
    for i = 2:n
        r(i) = mod(a * r(i-1) + c, m);
    end
    r = r / m; % normalize to [0,1]
end

if rng_choice == 1
    rng = rand(1, num_vehicles * 4);
else
    seed = round(rand() * 1e6);
    rng = lcg(seed, num_vehicles * 4);
end

% === DATA SETUP ===
petrol_types = {"RON95", "RON97", "Dynamic Diesel"};
petrol_probs = [0.5, 0.3, 0.2];
petrol_prices = [2.05, 3.10, 2.15];

arrival_rng = rng(1:num_vehicles);
petrol_rng = rng(num_vehicles+1:2*num_vehicles);
quantity_rng = rng(2*num_vehicles+1:3*num_vehicles);
refuel_rng = rng(3*num_vehicles+1:end);

inter_arrival_time = ceil(1 + arrival_rng * 3); % normal hour
%inter_arrival_time = ones(1, num_vehicles); % peak hour
arrival_time = cumsum([0, inter_arrival_time(2:end)]);

% === SIMULATION STATE ===
pump_busy_until = zeros(1, 4); % 4 pumps
vehicle_data = [];

% === SIMULATION LOOP ===
for i = 1:num_vehicles
    % Petrol type
    if petrol_rng(i) <= petrol_probs(1)
        type = 1;
    elseif petrol_rng(i) <= sum(petrol_probs(1:2))
        type = 2;
    else
        type = 3;
    end

    quantity = ceil(20 + quantity_rng(i) * 30); % 20–50L
    price = quantity * petrol_prices(type);
    refuel_time = ceil(4 + refuel_rng(i) * 6); % 4–10 mins realistic refueling
    linger_time = ceil(rand() * 6); % 0–5 mins loitering time
    total_time = refuel_time + linger_time;
    arrive = arrival_time(i);

    % Determine which lane is better (earliest free pump)
    lane1_next = min(pump_busy_until([1 2]));
    lane2_next = min(pump_busy_until([3 4]));

    if lane1_next <= lane2_next
        lane = 1;
        pump_ids = [1, 2];
    else
        lane = 2;
        pump_ids = [3, 4];
    end

    % Pick the soonest available pump in selected lane
    available_times = pump_busy_until(pump_ids);
    [soonest_free, idx] = min(available_times);
    pump = pump_ids(idx);

    start_time = max(arrive, soonest_free);
    end_time = start_time + total_time;
    waiting_time = start_time - arrive;
    time_in_system = end_time - arrive;

    pump_busy_until(pump) = end_time;

    % Record
    vehicle_data(i,:) = [i, type, quantity, price, arrive, ...
                     lane, pump, refuel_time, linger_time, total_time, ...
                     start_time, end_time, waiting_time];


    % Log events
    printf("Vehicle %d arrived at minute %d and began refueling with %s at Pump %d.\n", ...
        i, arrive, petrol_types{type}, pump);
    printf("Vehicle %d finished refueling and departed at minute %d.\n\n", ...
        i, end_time);
end

% === PRINT TABLE (CLEAN FORMATTING) ===
printf("\n%-8s %-15s %-8s %-10s %-8s %-6s %-6s %-12s %-12s %-12s %-10s %-13s %-13s\n", ...
    "Vehicle", "PetrolType", "Qty(L)", "Price(RM)", "Arrival", ...
    "Lane", "Pump", "RefuelTime", "LingerTime", "TotalTime", ...
    "Start", "End", "WaitTime");

for i = 1:size(vehicle_data, 1)
    v = vehicle_data(i,:);
    printf("%-8d %-15s %-8d %-10.2f %-8d %-6d %-6d %-12d %-12d %-12d %-10d %-13d %-13d\n", ...
        v(1), petrol_types{v(2)}, v(3), v(4), v(5), v(6), v(7), v(8), ...
        v(9), v(10), v(11), v(12), v(13));
end


% === EVALUATION ===
avg_wait = mean(vehicle_data(:,11));
avg_system = mean(vehicle_data(:,12));
prob_wait = sum(vehicle_data(:,11) > 0) / num_vehicles;

printf("\n=== Simulation Evaluation ===\n");
printf("Average Waiting Time: %.2f minutes\n", avg_wait);
printf("Average Time in System: %.2f minutes\n", avg_system);
printf("Probability a Vehicle Waits: %.2f%%\n", prob_wait * 100);

for p = 1:4
    times = vehicle_data(vehicle_data(:,7)==p, 8);
    if isempty(times)
        printf("Pump %d - No vehicles\n", p);
    else
        printf("Pump %d - Average Service Time: %.2f mins\n", p, mean(times));
    end
end

