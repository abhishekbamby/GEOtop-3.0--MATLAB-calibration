Files needed to run the GEOtop soil-temperature calibration

computeKGE_combined_calib.m is the objective function for a PSO calibration of GEOtop soil temperatures. Each call writes a candidate parameter set into the soil and config files, runs GEOtop, reads the simulated output, and returns the negative sum of KGE across the observation depths (the optimizer minimizes this).

It is not standalone. It needs a specific run folder, several files it does not create, and outside code that launches GEOtop.

The thing most likely to stop a new user is not the files listed below. It is that the run folder must already contain a full, working GEOtop project. Make sure GEOtop runs on its own and produces output-tabs/soiltemp0001.txt before you connect the calibration. See section 4.

1. Run folder

Everything is built from one root path at the top of the function:

matlab
input_folder = 'E:\...\geotop_run';

Expected layout (Brzydal example; counts differ by site, see section 5):

<input_folder>/
  geotop.inpts                   GEOtop config    (read and rewritten each call)
  soil_temp_brzydal_daily.mat    observations     (read)
  soil/
    soil0001.txt                 soil parameters  (read and rewritten each call)
  output-tabs/
    soiltemp0001.txt             GEOtop output    (read; produced by GEOtop)

Point input_folder at your own directory. The four sub-paths are fixed relative to it.

2. Files the script reads or writes

soil/soil0001.txt Soil hydraulic parameters, one row per soil layer. You provide the starting file; the script overwrites values on every call. It needs a header row and columns named exactly Kh, Kv, res, wilt, fc, sat, a, n, SS, with at least 24 rows (the sum of block_sizes).

geotop.inpts The GEOtop config. The script replaces only the two lines that start with ThermalConductivitySoilSolids = and ThermalCapacitySoilSolids =. If either string is missing, the thermal parameters go nowhere and the script does not warn you.

soil_temp_brzydal_daily.mat Observed soil temperatures. It must hold a table variable named soil_temp_brzydal_daily (the load depends on that name), with a DateTime column and columns T20cm through T1000cm matching the layers list. Column names are case sensitive.


3. Code and tools not included in this file
run_geotop.m, on the MATLAB path. It runs GEOtop against the folder and is called with no arguments. Not part of this file.
The GEOtop executable that run_geotop calls.
The driver that calls computeKGE_combined_calib(x) with a 66-element vector. The bounds lb and ub are built inside this function but never used here, so the driver defines its own. Keep the two copies matching.
Statistics and Machine Learning Toolbox, for corr. The rest is base MATLAB.
4. Files GEOtop needs that this script never names

geotop.inpts is only the top-level config. GEOtop reads more inputs named inside it: meteorological forcing, soil and horizon files, initial and boundary conditions, and an output section that has to produce soiltemp0001.txt. None of that appears in the script, so this README cannot list it.

The .m file plus the five files above is not a complete setup. You also need a GEOtop project that already runs start to finish. The calibration only edits two inputs and reads one output; it does not build the model.