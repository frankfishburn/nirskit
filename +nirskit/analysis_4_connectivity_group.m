function analysis_4_connectivity_group(varargin)
% NIRSKIT.ANALYSIS_4_CONNECTIVITY_GROUP - Batch script for group-level NIRS connectivity analysis
%
% Usage:
%   % Non-robust, fixed-effects of condition only
%   nirskit.analysis_4_connectivity_group;
%
%   % Robust, effects of condition group & interaction, subject as a random effect
%   nirskit.analysis_4_connectivity_group('Formula','beta ~ -1 + cond:group + (1|subject)','Robust',true);
%
% List of optional key-value parameters:
%   InputDirectory   - Location of prepared Results.mat file            (default: current directory)
%   OutputPrefix     - String to prepend to output folder               (default: 2_preprocessed)
%   Conditions       - Cell array of conditions to use                  (default: all)
%   Formula          - Mixed effects formula                            (default: 'beta ~ -1 + cond')
%   Robust           - Flag to perform robust fitting                   (default: false)
%
% Note:
%   The default options are minimalistic, so you will most likely want to supply parameters
%
%   See also
%   NIRSKIT.ANALYSIS_3_CONNECTIVITY_INDIV
%   NIRSKIT.ANALYSIS_5_DRAW

%% Set defaults
defaultInputDirectory = pwd;
defaultOutputPrefix = '4_connectivity-group';
defaultConditions = {};
defaultFormula = 'beta ~ -1 + cond';
defaultRobust = false;

%% Parse inputs
p = inputParser;
addParameter(p,'InputDirectory',defaultInputDirectory,@isdir);
addParameter(p,'OutputPrefix',defaultOutputPrefix,@isstr);
addParameter(p,'Conditions',defaultConditions,@iscell);
addParameter(p,'Formula',defaultFormula,@isstr);
addParameter(p,'Robust',defaultRobust,@islogical);

parse(p,varargin{:});

%% Check input file
in_dir = GetFullPath(p.Results.InputDirectory);
in_file = [in_dir filesep 'Results.mat'];
assert(exist(in_file,'file')==2,sprintf('Input file not found: %s',in_file));

%% Set output file
out_dir = fullfile(in_dir,p.Results.OutputPrefix);
out_dir = strcat( out_dir , '_' , strrep(p.Results.Formula,' ','') );
if ~isempty(p.Results.Conditions)
    out_dir = strcat( out_dir , '_' , strjoin(p.Results.Conditions,'-') );
end
if p.Results.Robust
    out_dir = strcat( out_dir , '_Robust' );
end

if ~exist(out_dir,'dir'), mkdir(out_dir); end
out_file = fullfile(out_dir,'Results.mat');
if exist(out_file,'file'), warning('Output file already exists. Skipping.'); return; end

%% Load data
data = load(in_file,'SubjStats');
SubjStats = data.SubjStats;

%% Compute input data hash
hashopt.Method = 'SHA-256';
SubjStats_hash = DataHash( SubjStats , hashopt );

%% Activation
job_groupconn = [];

if ~isempty(p.Results.Conditions)
    job_groupconn = nirs.modules.KeepStims( job_groupconn );
        job_groupconn.listOfStims = p.Results.Conditions;
end

job_groupconn = nirs.modules.MixedEffectsConnectivity( job_groupconn );
    job_groupconn.formula = p.Results.Formula;
    job_groupconn.robust = p.Results.Robust;

fprintf('Running job:\n')
disp(job_groupconn);
fprintf(' ');

GroupModel = job_groupconn.run(SubjStats);

%% Save results
save(out_file,'GroupModel','job_groupconn','SubjStats_hash','in_file');

end