function [sum_kge] = computeKGE_combined_calib(x)
    % Input:  x = 66 parameters = 54 hydraulic (9 params x 6 blocks)
    %                           +  6 thermal conductivity (1 per block)
    %                           +  6 thermal capacity     (1 per block)
    % Output: Negative sum of KGE (for optimization; calibration on year <= 2020)

    % =====================================================================
    %  HOW TO ADAPT THIS SCRIPT FOR ANOTHER SITE / BOREHOLE / USER
    %  This function hard-codes THREE independent counts in several places.
    %  Change one and you MUST update every line listed under it, or the
    %  indexing misaligns silently (or throws). They are NOT the same number:
    %    nBlocks   = 6  (parameter groups)
    %    nSoil     = 24 (= sum(block_sizes); rows in soil0001.txt / geotop)
    %    nObs      = 14 (sensor depths being compared)
    %
    %  (A) PATHS & NAMES (site-specific strings):
    %      - input_folder ................ your run directory
    %      - obs_file .................... your observation .mat
    %      - the loaded variable name (soil_temp_brzydal_daily) must match
    %        what is inside that .mat, in BOTH the load and the line
    %        'observed_temp = soil_temp_brzydal_daily;'
    %      - observed_temp.DateTime ...... case-sensitive; match your column
    %
    %  (B) nBlocks (=6): one set of 9 hydraulic + 1 K + 1 C per group. Update:
    %      - repmat(hyd_*, 1, 6) and repmat(therm_*, 1, 6)   -> 1, nBlocks
    %      - length(block_sizes) must equal nBlocks
    %      - the length(x) ~= 66 check           -> 9*nBlocks + 2*nBlocks
    %      - thermal_k = x(param_idx : param_idx + nBlocks-1)
    %      - thermal_c = x(param_idx+nBlocks : param_idx + 2*nBlocks-1)
    %
    %  (C) block_sizes (=[5 8 5 4 1 1]): its SUM (=nSoil=24) must equal the
    %      number of layers in soil0001.txt AND the length of the thermal
    %      arrays written to geotop.inpts. Set to your own vertical layering.
    %
    %  (D) nObs (=14): the comparison/sensor depths, NOT the soil layers. Update:
    %      - layers = { ... } : one entry per depth; names must match the
    %        T<depth> columns in your observation table
    %      - sim_temp = sim_data(:, 7:20)  -> 7 : (6+nObs)  [geotop temp cols]
    %      - the three  for i = 1:14  loops -> 1 : nObs
    %      - zeros(1, 14)                   -> zeros(1, nObs)
    %
    %  (E) BOUNDS (hyd_lb/ub order: Kh,Kv,res,wilt,fc,sat,a,n,SS; therm_*_lb/ub)
    %      are site-specific ranges. Re-check for your soils/lithology.
    %
    %  (F) calib_idx = year(dates) <= 2020 is the calibration WINDOW (2020 and
    %      earlier, not only 2020). Change the cutoff; uncomment the commented
    %      validation block to score the held-out years.
    % =====================================================================

    % --- File Paths ---
    input_folder = 'input_folder';
    soil_file = fullfile(input_folder, 'soil', 'soil0001.txt');
    output_file = fullfile(input_folder, 'output-tabs', 'soiltemp0001.txt');
    obs_file = fullfile(input_folder, 'observations.mat');
    geotop_inpts_file = fullfile(input_folder, 'geotop.inpts');
    load(obs_file)
    hyd_lb = [1.0E-10, 1.0E-10, 0.02, 0.03, 0.10, 0.10, 0.005, 1.6, 1.0E-10];  %Kh,Kv,res,wilt,fc,sat,a,n,SS
    hyd_ub = [1.0E-5, 1.0E-6, 0.08, 0.12, 0.3, 0.80, 0.05,  2.35, 1.0E-8]; 
    
    % --- Thermal Parameter Bounds ---
    therm_k_lb = 0.5; therm_k_ub = 3.5;          % Conductivity bounds (W/m/K)
    therm_c_lb = 1E+4; therm_c_ub = 3.5E+6;   % Capacity bounds (J/m³/K)
    
    % --- Total Bounds (66 params over 6 blocks / 24 soil layers: 5+8+5+4+1+1) ---
    lb = [repmat(hyd_lb, 1, 6), repmat(therm_k_lb, 1, 6), repmat(therm_c_lb, 1, 6)]';
    ub = [repmat(hyd_ub, 1, 6), repmat(therm_k_ub, 1, 6), repmat(therm_c_ub, 1, 6)]';

    layers = {'20cm','40cm','80cm','120cm','160cm','200cm','250cm','300cm','350cm','400cm','500cm','700cm','900cm','1000cm'};

    if length(x) ~= 66
        error('Input x must contain exactly 66 parameters.');
    end

    block_sizes = [5, 8, 5, 4, 1,1];
    hyd_params_per_block = 9;

    % --- Update soil0001.txt ---
    soil0001 = readtable(soil_file);
    layer_idx = 1;
    param_idx = 1;
    for b = 1:length(block_sizes)
        block_size = block_sizes(b);
        params = x(param_idx : param_idx + hyd_params_per_block - 1);
        for j = 0:block_size - 1
            soil0001.Kh(layer_idx + j)   = params(1);
            soil0001.Kv(layer_idx + j)   = params(2);
            soil0001.res(layer_idx + j)  = params(3);
            soil0001.wilt(layer_idx + j) = params(4);
            soil0001.fc(layer_idx + j)   = params(5);
            soil0001.sat(layer_idx + j)  = params(6);
            soil0001.a(layer_idx + j)    = params(7);
            soil0001.n(layer_idx + j)    = params(8);
            soil0001.SS(layer_idx + j)   = params(9);
        end
        layer_idx = layer_idx + block_size;
        param_idx = param_idx + hyd_params_per_block;
    end
    writetable(soil0001, soil_file);

    % --- Thermal parameters (see adaptation note B: widths depend on nBlocks) ---
    thermal_k = x(param_idx : param_idx + 5);        % nBlocks values
    thermal_c = x(param_idx + 6 : param_idx + 11);   % nBlocks values
    thermal_k_full = repelem(thermal_k, block_sizes)';   % expands to nSoil (=24)
    thermal_c_full = repelem(thermal_c, block_sizes)';

    % --- Update geotop.inpts ---
    fileID = fopen(geotop_inpts_file, 'r');
    geotop_lines = textscan(fileID, '%s', 'Delimiter', '\n'); fclose(fileID);
    geotop_lines = geotop_lines{1};

    k_str = sprintf('%.1f,', thermal_k_full); k_str = k_str(1:end-1);
    c_str = sprintf('%.1E,', thermal_c_full); c_str = c_str(1:end-1);

    for i = 1:length(geotop_lines)
        if contains(geotop_lines{i}, 'ThermalConductivitySoilSolids =')
            geotop_lines{i} = ['ThermalConductivitySoilSolids = ' k_str];
        elseif contains(geotop_lines{i}, 'ThermalCapacitySoilSolids =')
            geotop_lines{i} = ['ThermalCapacitySoilSolids = ' c_str];
        end
    end

    fileID = fopen(geotop_inpts_file, 'w');
    fprintf(fileID, '%s\n', geotop_lines{:});
    fclose(fileID);

    % --- Run GeoTOP ---
    run_geotop();

    % --- Load observations and simulations ---
    observed_temp= soil_temp_brzydal_daily;   % <- rename to your loaded variable
    %observed_temp = obs_data.soil_temp_meteo;
    sim_data = readmatrix(output_file, 'NumHeaderLines', 1);
    sim_temp = sim_data(:, 7:20);             % nObs columns (see adaptation note D)
    dates = datetime(observed_temp.DateTime);  % <- case-sensitive column name

    calib_idx = year(dates) <= 2020;   % 2020 AND earlier (calibration window)
    %valid_idx = year(dates) >= 2021;

    % --- Prepare structures for calibration and validation ---
    obs_calib = struct(); 
    %obs_valid = struct();
    for i = 1:14
        layer_field = ['T' layers{i}];
        obs_calib.(layer_field) = observed_temp.(layer_field)(calib_idx);
        %obs_valid.(layer_field) = observed_temp.(layer_field)(valid_idx);
    end
    sim_calib = sim_temp(calib_idx, :);
    %sim_valid = sim_temp(valid_idx, :);

    % --- Calibration KGE ---
    kge_layers = zeros(1, 14);
    for i = 1:14
        obs = obs_calib.(['T' layers{i}]);
        sim = sim_calib(:, i);
        valid = ~isnan(obs) & ~isnan(sim);
        if sum(valid) < 2
            kge_layers(i) = NaN;
            continue;
        end
        r = corr(sim(valid), obs(valid));
        alpha = std(sim(valid)) / std(obs(valid));
        beta = mean(sim(valid)) / mean(obs(valid));
        kge_layers(i) = 1 - sqrt((r - 1)^2 + (alpha - 1)^2 + (beta - 1)^2);
    end
    sum_kge = -sum(kge_layers, 'omitnan');

    % % --- Optional: Validation KGE (2021–2024) ---
    % kge_val_layers = zeros(1, 14);
    % for i = 1:14
    %     obs = obs_valid.(['T' layers{i}]);
    %     sim = sim_valid(:, i);
    %     valid = ~isnan(obs) & ~isnan(sim);
    %     if sum(valid) < 2
    %         kge_val_layers(i) = NaN;
    %         continue;
    %     end
    %     r = corr(sim(valid), obs(valid));
    %     alpha = std(sim(valid)) / std(obs(valid));
    %     beta = mean(sim(valid)) / mean(obs(valid));
    %     kge_val_layers(i) = 1 - sqrt((r - 1)^2 + (alpha - 1)^2 + (beta - 1)^2);
    % end

    % --- Display results ---
    disp('Calibration KGE (year <= 2020):');
    for i = 1:14
        disp(['KGE at ' layers{i} ': ' num2str(kge_layers(i))]);
    end
    disp(['Sum of KGE (calibration): ' num2str(sum_kge)]);

    % disp('Validation KGE (2021–2024):');
    % for i = 1:14
    %     disp(['KGE at ' layers{i} ': ' num2str(kge_val_layers(i))]);
    % end
    % val_kge_sum = -sum(kge_val_layers, 'omitnan');
    % disp(['Sum of KGE (validation): ' num2str(val_kge_sum)]);

    % --- Track optimization progress ---
    persistent kge_history
    if isempty(kge_history), kge_history = []; end
    kge_history(end + 1) = sum_kge;
    fig_handle = figure(35); % Create the figure with the handle
    set(fig_handle, 'Visible', 'on', 'WindowState', 'minimize'); % Set properties
    plot(kge_history, '-o', 'LineWidth', 1.5);
    xlabel('Iteration'); ylabel('Sum of KGE');
    title('Optimization Progress (Calibration)');
    drawnow;
end