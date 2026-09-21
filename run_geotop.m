function status = run_geotop(input_folder, timeout_sec)
%RUN_GEOTOP Run GEOtop silently with timeout and GLIBCXX handling
%   input_folder : path to GEOtop input folder
%   timeout_sec  : maximum allowed run time in seconds (optional)
%
%   Returns status = 0 if successful, 1 if failed or timed out

if nargin < 2
    timeout_sec = 300; % default 5 minutes
end

% Path to system libstdc++
sys_libstdc_path = '/usr/lib/x86_64-linux-gnu/libstdc++.so.6';
setenv('LD_PRELOAD', sys_libstdc_path); 

% GEOtop executable
geotop_exec = '/home/bamby/geotop/meson-build/geotop';

% Command string with silent execution (suppress stdout & stderr)
cmd = sprintf('%s %s > /dev/null 2>&1 & echo $!', geotop_exec, input_folder);

status = 1; % default = failed

try
    % Start GEOtop in background and get its PID
    [~, pid_str] = system(cmd);
    pid = str2double(strtrim(pid_str));

    % Wait for the allowed timeout
    elapsed = 0;
    dt = 1; % check every 1 sec
    while elapsed < timeout_sec
        % Check if process is still running
        [~, result] = system(sprintf('ps -p %d', pid));
        if contains(result, num2str(pid))
            pause(dt);
            elapsed = elapsed + dt;
        else
            % Process finished successfully
            status = 0;
            return;
        end
    end

    % Timeout reached → kill process
    system(sprintf('kill -9 %d', pid));
    warning('GEOtop run exceeded timeout of %d seconds and was terminated.', timeout_sec);
    status = 1;
catch ME
    warning('GEOtop execution error: %s', E.message);
    status = 1;
end

end
