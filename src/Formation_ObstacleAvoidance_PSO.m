%% Communication-aware Formation Control
clear all;
close all;
clc;

% Initialize all parameters
max_iter    = 500;
h           = 1;
swarm_size  = 7;
alpha       = 10^(-5);                 % system parameter about antenna characteristics
delta       = 2;                       % required application data rate
beta        = alpha*(2^delta-1);
v           = 3;                       % path loss exponent
r0          = 5;                       % reference antenna near-field
PT          = 0.94;                    % reception probability threshold
rho_ij      = 0;
formation_speed = 1;
travel_speed = 0.5; % was 0.5
communication_qualities = zeros(swarm_size, swarm_size);
am         = 0.2; % was 0.2
bm         = 1;
a0         = 0.6; % was 0.6
b0         = 20; % was 20
bf         = 0;
af         = 1; % was 1
backstep_when_jammed = 1.2;


% The position of the destination
dest_x = 70;
dest_y = 120;

% The position of the obstacle
obs_x = 50;
obs_y = 50;
obs_side_length = 50;

avoid_directions = zeros(swarm_size);
swarm_obs = [];


%% ---Initialize Agents' Positions---
swarm = [
     7, 0;
    7, -20;
    0,   -10;
    35,  -20;
    58,   0;
    52,  13;
    52, -18;
    ];


%% ---Initialize the velocity---
for j = 1:swarm_size
    speed(j,1) = rand();
    speed(j,2) = rand();
    prev_speed(j,1) = rand();
    prev_speed(j,2) = rand();
end

% PSO Variables
personal_best_values = ones(swarm_size) * 10000;
global_best_value = 100000;

personal_best_locs = swarm;
global_best_loc = [0,0];

% PSO Constants
goal_w = 1;
obs_w = 65;
curr_vel_w = 0.1;
c1 = 0.1;
c2 = 0.13;


%% ---Performance Indicators---
t_Elapsed = 0;
Jn        = 0;
rn        = 0;

% Define the figure positions
figure_positions = [
    %Left Bottom Right Width Height
    
    750, 480, 500, 400;    % Position for Figure 2
    200, 10, 500, 400;    % Position for Figure 3
    
    200, 480, 500, 400;   % Position for Figure 1
    750, 10, 500, 400;    % Position for Figure 4
    
    
    ];

% Plot Jn
figure(1)
Jn_Plot = plot(t_Elapsed, Jn);
set(gcf, 'Position', figure_positions(1, :));
xlabel('$t(s)$', 'Interpreter','latex', 'FontSize', 12, 'Rotation', 0)
ylabel('$J_n$', 'Interpreter','latex', 'FontSize', 12, 'Rotation', 0)
title('Average Communication Performance Indicator');
hold on
Jn_Text = text(t_Elapsed(end), Jn(end), sprintf('Jn: %.4f', Jn(end)), 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');

% Plot rn
figure(2)
rn_Plot = plot(t_Elapsed, rn);
set(gcf, 'Position', figure_positions(2, :));
xlabel('$t(s)$', 'Interpreter','latex', 'FontSize', 12, 'Rotation', 0)
ylabel('$r_n$', 'Interpreter','latex', 'FontSize', 12, 'Rotation', 0)
title('Average Distance Indicator');
hold on
rn_Text = text(t_Elapsed(end), rn(end), sprintf('rn: %.4f', rn(end)), 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');

figure(4)
hold on
%Jam zone
fill(obs_x + [-obs_side_length/2 obs_side_length/2 obs_side_length/2 -obs_side_length/2 -obs_side_length/2], obs_y + [-obs_side_length/2 -obs_side_length/2 obs_side_length/2 obs_side_length/2 -obs_side_length/2], 'r', 'FaceAlpha', 0.3, 'EdgeColor', 'none');
%Destination
fill([dest_x - 2, dest_x + 2, dest_x + 2, dest_x - 2, dest_x - 2], [dest_y - 2, dest_y - 2, dest_y + 2, dest_y + 2, dest_y - 2], 'w', 'LineWidth', 2);
hold off
axis equal

drawnow                                         % Force a graphics refresh so that isn't counted in our elapsed time

tic

% Assign a different color to each edge-label pair
line_colors = rand(swarm_size, swarm_size, 3);
label_colors = line_colors;

% Define the color matrix with predefined colors
node_colors = [
    108 155 207;  % Light Blue
    247 147 39;   % Orange
    242 102 171;  % Light Pink
    122 168 116;  % Green
    255 217 90;   % Light Gold
    147 132 209;  % Purple
    245 80 80     % Red
    ] / 255;  % Divide by 255 to scale the RGB values to the [0, 1] range

[img, map, alphachannel] = imread('drone','png');
markersize = [3, 3];

%% ---Simulation---
for k=1:max_iter

    % Plot the node trace inside the loop
    figure(4)
    set(gcf, 'Position', figure_positions(4, :));
    xlabel('$x$', 'Interpreter','latex', 'FontSize', 12, 'Rotation', 0)
    ylabel('$y$', 'Interpreter','latex', 'FontSize', 12, 'Rotation', 0)
    title('Node Trace');
    hold on;

    % Plot all nodes as markers
    scatter(swarm(:, 1), swarm(:, 2), 16, node_colors, 'filled');

    %--- Formation Scene + Node Trace---
    for i = 1:swarm_size
        % Plot the node trace
        swarm_trace(k, i, :) = swarm(i, :);

        trace_x = squeeze(swarm_trace(:, i, 1));
        trace_y = squeeze(swarm_trace(:, i, 2));
        plot(trace_x, trace_y, 'Color', node_colors(i, :));

        % Add arrows to indicate node movement
        arrow_x = trace_x(1:end-1);
        arrow_y = trace_y(1:end-1);
        arrow_dx = diff(trace_x);
        arrow_dy = diff(trace_y);

        % Normalize the arrow displacements
        arrow_magnitudes = sqrt(arrow_dx.^2 + arrow_dy.^2);
        max_arrow_magnitude = max(arrow_magnitudes);
        scaling_factor = 2;  % Adjust the scaling factor for arrow size
        normalized_arrow_dx = arrow_dx * scaling_factor / max_arrow_magnitude;
        normalized_arrow_dy = arrow_dy * scaling_factor / max_arrow_magnitude;

        quiver(arrow_x, arrow_y, normalized_arrow_dx, normalized_arrow_dy, 0, 'Color', node_colors(i, :), 'LineWidth', 1.5, 'MaxHeadSize', 2);
       
        if size(swarm_obs, 1)
            plot(swarm_obs(:, 1), swarm_obs(:, 2), 'r*');
        end
    end

    fill([dest_x - 2, dest_x + 2, dest_x + 2, dest_x - 2, dest_x - 2], [dest_y - 2, dest_y - 2, dest_y + 2, dest_y + 2, dest_y - 2], 'w', 'LineWidth', 2);

    figure(3);
    clf; % Clear the figure
    set(gcf, 'Position', figure_positions(3, :));
    xlabel('$x$', 'Interpreter','latex', 'FontSize', 12, 'Rotation', 0)
    ylabel('$y$', 'Interpreter','latex', 'FontSize', 12, 'Rotation', 0)
    title('Formation Scene');
    axis equal;
    hold on

    % Plot the obstacle
    fill(obs_x + [-obs_side_length/2 obs_side_length/2 obs_side_length/2 -obs_side_length/2 -obs_side_length/2], obs_y + [-obs_side_length/2 -obs_side_length/2 obs_side_length/2 obs_side_length/2 -obs_side_length/2], 'r', 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    hold on;

    % Plot the destination
    fill([dest_x - 2, dest_x + 2, dest_x + 2, dest_x - 2, dest_x - 2], [dest_y - 2, dest_y - 2, dest_y + 2, dest_y + 2, dest_y - 2], 'w', 'LineWidth', 2);
    if size(swarm_obs, 1)
        plot(swarm_obs(:, 1), swarm_obs(:, 2), 'r*');
    end

    plot(global_best_loc(1, 1), global_best_loc(1, 2), 'b*');


    
    
    for l = 1:swarm_size
        x_low = swarm(l, 1) - markersize(1)/2;
        x_high = swarm(l, 1) + markersize(1)/2;
        y_low = swarm(l, 2) - markersize(2)/2;
        y_high = swarm(l, 2) + markersize(2)/2;

        imagesc([x_low x_high], [y_low y_high], img, 'AlphaData', alphachannel, 'CData', repmat(reshape(node_colors(l, :), [1 1 3]), [size(img, 1), size(img, 2), 1]));
    end


    %--- Formation Scene Edge+Label ---
    for i = 1:swarm_size
        for j= 1:swarm_size
            if i ~= j && communication_qualities(i, j) > PT

                hold on;

                % Get the line color and label color for the current pair
                line_color = line_colors(i, j, :);
                label_color = label_colors(i, j, :);

                a1 = swarm(i,:);
                a2 = swarm(j,:);
                plot([a1(1), a2(1)], [a1(2), a2(2)], '--', 'Color', line_color);


                % Calculate the position for the label
                scaling_factor = 0.2;  % Adjust the scaling factor for the label positioning
                midpoint_x = (a1(1) + a2(1)) / 2;
                midpoint_y = (a1(2) + a2(2)) / 2;
                displacement_x = (a2(1) - a1(1)) * scaling_factor;
                displacement_y = (a2(2) - a1(2)) * scaling_factor;
                label_x = midpoint_x + displacement_x;
                label_y = midpoint_y + displacement_y + 2;

                % Add the number label at the midpoint of the line
                label = communication_qualities(i, j);
                label_str = sprintf('%.4f', label);

               % text(label_x, label_y, label_str, 'HorizontalAlignment', 'center', 'Color', label_color);
                hold off;

                % Remove quality value for refresh
                communication_qualities(i, j) = 0;
                communication_qualities(j, i) = 0;
            end
        end
    end

    hold off;

    axis equal;

    % Calculate the distances between each node and the destination
    distances = vecnorm(swarm - repmat([dest_x, dest_y], swarm_size, 1), 2, 2);

    % Find the index of the node with the minimum distance
    [~, closest_node_index] = min(distances);



    %--- Controller ---
    for i=1:swarm_size
        rho_ij=0;
        phi_rij=0;
        rij=0;
        for j=[1:(i-1),(i+1):swarm_size]
            rij=sqrt((swarm(i,1)-swarm(j,1))^2+(swarm(i,2)-swarm(j,2))^2);
            aij=exp(-alpha*(2^delta-1)*(rij/r0)^v);
            gij=rij/sqrt(rij^2+r0^2);

            % Check if communication link is in Jam Area
            if lineCrossesSquare([swarm(i, 1), swarm(i, 2)], [swarm(j, 1), swarm(j, 2)], [obs_x, obs_y], obs_side_length)
                % Half the quality values when jammed
                aij = aij * 0.5; 
                gij = gij * 0.5;
            end

            if aij>=PT
                rho_ij=(-beta*v*rij^(v+2)-beta*v*(r0^2)*(rij^v)+r0^(v+2))*exp(-beta*(rij/r0)^v)/sqrt((rij^2+r0^2)^3);
            else
                rho_ij=0;
            end

            phi_rij=gij*aij;
            communication_qualities(i,j) = phi_rij;
            qi=[swarm(i,1),swarm(i,2)];
            qj=[swarm(j,1),swarm(j,2)];
            nd=(qi-qj)/sqrt(1+norm(qi-qj)*formation_speed);

            speed(i,1)=speed(i,1)+rho_ij * nd(1) * travel_speed;
            speed(i,2)=speed(i,2)+rho_ij * nd(2) * travel_speed;

            

            
            % Wait 25 interations to allow swarm to reach steady state
            if k >= 25 && false
                %--- Destination Vector ---
                
                destination_vector = [dest_x - swarm(i, 1), dest_y - swarm(i, 2)];
                dist_vector = norm(destination_vector);
                destination_speed = destination_vector / norm(destination_vector);
    
                if dist_vector > bm
                    contr_param = am;
                else
                    contr_param = am * (dist_vector/bm);
                end
    
                speed(i, 1) = speed(i, 1) + (destination_speed(1) * contr_param);
                speed(i, 2) = speed(i, 2) + (destination_speed(2) * contr_param);
    
    
                %--- Avoidance Vector ---
                if size(swarm_obs) > 0
                    
                    obs = findClosestObstacle(swarm(i, :), swarm_obs);
                    
                    swarm_obs_y = obs(2);
                    swarm_obs_x = obs(1);
                    avoidance_vec = [swarm_obs_y - swarm(i, 2), -(swarm_obs_x - swarm(i, 1))];
                    obs_dist = norm(avoidance_vec);
                    avoid_direction = avoid_directions(i);
    
                    % X direction
                    if obs_dist <= b0 && avoid_direction == 0
                        if swarm_obs_y - swarm(i, 2) < 0 % Destination is above obstacle
                            if swarm_obs_x - swarm(i, 1) < 0
                                avoid_direction = 1;
                            else
                                avoid_direction = 1;
                            end
                        
                        else % Destination is below Obstacle
                            if swarm_obs_x - swarm(i, 1) < 0 
                                avoid_direction = 1;
                            else
                                avoid_direction = 1;
                            end
                        end
                    end
    
                    % if obs_dist > b0 && avoid_direction ~= 0
                    %     avoid_direction = 0;
                    % end
                    
                    if avoid_direction ~= 0
                        avoidance_vec = avoid_direction * avoidance_vec;
                        avoid_directions(i) = avoid_direction;
                    end
            
                    % Normalize the avoidance vector
                    avoidance_speed = avoidance_vec / norm(avoidance_vec);
    
            
                    if obs_dist >= bf && obs_dist <= b0
                        % fprintf("Avoiding Obstacle\n")
                        contr_param = a0 * ( obs_dist/(bf-b0) + b0/(b0-bf) );
                    else
                        contr_param = 0;
                    end
    
                    if obs_dist < 5
                        % fprintf("Wall Following\n")
                        wall_follow = af;
                    else
                        wall_follow = 0;
                    end
        
                    % Update the speed with obstacle avoidance
                    speed(i, :) = speed(i, :) + avoidance_speed * contr_param + avoidance_speed * wall_follow;
                end
                
            end
            
        end

        if k >= 5
            for l=1:swarm_size
                X = [dest_x,dest_y; swarm(l, 1),swarm(l, 2)];
                distance_to_goal = pdist(X,'euclidean');
                proximity_to_obstacle = 0;
    
                if size(swarm_obs) > 0
                    obs = findClosestObstacle(swarm(l, :), swarm_obs);
                    X = [obs(1),obs(1); swarm(l, 1),swarm(l, 2)];
                    proximity_to_obstacle = pdist(X,'euclidean');
                    if proximity_to_obstacle > 80
                        fprintf("In HERE!!!: ");
                        proximity_to_obstacle = 80;
                    end
                    proximity_to_obstacle = log(proximity_to_obstacle);
                end
    
                % Evaluate Agent Fitness
                   
               fitness = goal_w * distance_to_goal - obs_w * proximity_to_obstacle;
               fprintf("Fitness: %d, ", fitness);
               fprintf("Goal: %d, ", goal_w * distance_to_goal);
               fprintf("Obs: %d \n", obs_w * proximity_to_obstacle);
                   
                
             
                if fitness < personal_best_values(l)
                    personal_best_values(l) = fitness;
                    personal_best_locs(l, :) = swarm(l, :);
                end
    
                if fitness < global_best_value
                    global_best_value = fitness;
                    global_best_loc(1, :) = swarm(l, :);
                    % fprintf("NEW GLOBAL BEST: %d, ", global_best_value);
                    % fprintf("Location X: %d, ", global_best_loc(1, 1));
                    % fprintf("Y: %d\n", global_best_loc(1, 2));
                end
            end
            
            

            

            new_velocity_x = curr_vel_w * prev_speed(i, 1) + c1 * rand() * (personal_best_locs(i, 1) - swarm(i, 1)) + c2 * rand() * (global_best_loc(1, 1) - swarm(i, 1));
            new_velocity_y = curr_vel_w * prev_speed(i, 2) + c1 * rand() * (personal_best_locs(i, 2) - swarm(i, 2)) + c2 * rand() * (global_best_loc(1, 2) - swarm(i, 2));
            
           
            % if abs(new_velocity_x) > 10
            %     if new_velocity_x > 0
            %         new_velocity_x = 1;
            %     else
            %         new_velocity_x = -1;
            %     end
            % end
            % 
            % if abs(new_velocity_y) > 10
            %     if new_velocity_y > 0
            %         new_velocity_y = 1;
            %     else
            %         new_velocity_y = -1;
            %     end
            % end
            fprintf("New Velocity X: %d, ", new_velocity_x);
            fprintf("Y: %d\n", new_velocity_y);

            speed(i, 1) = speed(i, 1) + new_velocity_x;
            speed(i, 2) = speed(i, 2) + new_velocity_y;
        end


        if all(communication_qualities(i, :) < PT)
            % fprintf("Agent %d:HIT JAM ZONE\n", i);
            % fprintf("Jam area location: %d\n", swarm(i, :));
            % fprintf("Prev Speed: %d\n\n", prev_speed(i,1));
            if ~ismember(swarm(i, :), swarm_obs) 
                swarm_obs = [swarm_obs; swarm(i, :)];
                % global_best_value = 0;
                personal_best_values = zeros(swarm_size);
                fprintf("Obstacle found, new size: %d\n", size(swarm_obs, 1));
            end
            speed(i,:) = -prev_speed(i,:) * backstep_when_jammed;;
            % swarm(i,1)=swarm(i,1)-prev_speed(i,1) * 1.2;
            % swarm(i,2)=swarm(i,2)-prev_speed(i,2) * 1.2;
            
        end

        swarm(i,:)=swarm(i,:)+speed(i,:)*h;

        prev_speed(i,:) = speed(i,:)*h;
        
        speed(i,:)=0;

        t_Elapsed=cat(1, t_Elapsed, toc);

        %---Average Communication Performance Indicator---%
        Jn=cat(1, Jn, phi_rij);
        Jn=smooth(Jn);
        set(Jn_Plot, 'xdata', t_Elapsed, 'ydata', Jn);      % Plot Jn
        set(Jn_Text, 'Position', [t_Elapsed(end), Jn(end)], 'String', sprintf('Jn: %.4f', Jn(end)));
        pause(0);

        %---Average Neighboring Distance Indicator---%
        rn=cat(1, rn, rij);
        rn=smooth(rn);
        set(rn_Plot, 'xdata', t_Elapsed, 'ydata', rn);      % Plot rn
        set(rn_Text, 'Position', [t_Elapsed(end), rn(end)], 'String', sprintf('rn: %.4f', rn(end)));

        pause(0);

    end

    pause(0)

end
figure(1)
axis([0 300  0, 1]);  % Update the limits for Figure 1

figure(2)
axis([0 300 min(rn) max(rn)+5]);  % Update the limits for Figure 2

% Plot the final node trace outside the loop
figure(4)
hold on;
for i = 1:swarm_size
    trace_x = squeeze(swarm_trace(:, i, 1));
    trace_y = squeeze(swarm_trace(:, i, 2));
    plot(trace_x, trace_y);
end
hold off;