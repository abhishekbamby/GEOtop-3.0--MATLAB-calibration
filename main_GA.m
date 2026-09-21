clear; clc;



%%
% --- Hydraulic Parameter Bounds ---
     hyd_lb = [1.0E-10, 1.0E-10, 0.01, 0.01, 0.11, 0.11, 1.0E-6, 1.3, 1.0E-10];  %Kh,Kv,res,wilt,fc,sat,a,n,SS
     hyd_ub = [1.0E-5, 1.0E-2, 0.1, 0.1, 0.8, 0.8, 1.0E-2,  2.35, 1.0E-8]; 
    % 
    % % --- Thermal Parameter Bounds ---
     therm_k_lb = 0.2; therm_k_ub = 6;          % Conductivity bounds (W/m/K)
    therm_c_lb = 8E+5; therm_c_ub = 4E+6;   % Capacity bounds (J/m³/K)
    % Negative for permafrost (downward heat flow), adjust range as needed
    heat_flux_lb = 0.01;
    heat_flux_ub =  0.07;

% Total bounds for 10 hydraulic blocks, 10 thermal k, 10 thermal c, and 1 heat flux
lb = [repmat(hyd_lb, 1, 10), repmat(therm_k_lb, 1, 10), repmat(therm_c_lb, 1, 10), heat_flux_lb];
ub = [repmat(hyd_ub, 1, 10), repmat(therm_k_ub, 1, 10), repmat(therm_c_ub, 1, 10), heat_flux_ub];


n_var = length(lb);  % Should now be 111 (90 + 10 + 10 + 1)
%% 
opts = optimoptions('particleswarm', ...
    'Display', 'iter', ...
    'SwarmSize', 100, ...
    'MaxIterations', 110, ...
    'FunctionTolerance', 1e-6, ...
    'InertiaRange', [0.7, 1.2], ...
    'MaxStallIterations', 30, ...
    'SelfAdjustmentWeight', 1.49, ...
    'SocialAdjustmentWeight', 1.49, ...
    'UseParallel', false, ...
    'PlotFcn', 'pswplotbestf');


    %% 

[x_opt, fval, exitflag, output] = particleswarm(@computeRMSE_combined_calib, 111, lb, ub, opts);
