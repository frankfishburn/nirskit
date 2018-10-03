function analysis_4_activation_group(varargin)
% NIRSKIT.ANALYSIS_4_ACTIVATION_GROUP - Batch script for group-level NIRS activation analysis
%
% Usage:
%   % Non-robust, fixed-effects of condition only
%   nirskit.analysis_4_activation_group;
%
%   % Robust, effects of condition group & interaction, subject as a random effect
%   nirskit.analysis_4_activation_group('Formula','beta ~ -1 + cond:group + (1|subject)','Robust',true);
%
% List of optional key-value parameters:
%   InputDirectory   - Location of prepared Results.mat file            (default: current directory)
%   OutputPrefix     - String to prepend to output folder               (default: 2_preprocessed)
%   Conditions       - Cell array of conditions to use                  (default: all)
%   ROIs             - Table of ROIs (see nirs.modules.ApplyROI)        (default: none)
%   Formula          - Mixed effects formula                            (default: 'beta ~ -1 + cond')
%   Weighted         - Flag to use variance-weighted least squares      (default: true)
%   Robust           - Flag to perform robust fitting                   (default: false)
%   InclDiag         - Flag to include fitlm models in output           (default: false)
%   SubjectThreshold - P-value for removing high-leverage subjects      (default: 1)
%
% Note:
%   The default options are minimalistic, so you will most likely want to supply parameters
%
%   See also NIRSKIT.ANALYSIS_1_PREPARE,
%   NIRSKIT.ANALYSIS_2_PREPROCESSING,
%   NIRSKIT.ANALYSIS_3_ACTIVATION_INDIV,
%   NIRSKIT.ANALYSIS_5a_CONNECTIVITY_INDIV,
%   NIRSKIT.ANALYSIS_5b_HYPERSCANNING_INDIV

%% Set defaults
defaultInputDirectory = pwd;
defaultOutputPrefix = '4_activation-group';
defaultConditions = {};
defaultROIs = table({},{},{},'VariableNames',{'source','detector','name'});
defaultFormula = 'beta ~ -1 + cond';
defaultWeighted = true;
defaultRobust = false;
defaultInclDiag = false;
defaultSubjectThreshold = 1;

%% Parse inputs
p = inputParser;
ismodule = @(x) assert(isempty(x) || exist(['nirs.modules.' x],'class'),sprintf('%s is not a detected module in nirs-toolbox.',x));
isROItable = @(x) assert(istable(x) && isequal(x.Properties.VariableNames,{'source','detector','name'}),'Bad ROI table');
addParameter(p,'InputDirectory',defaultInputDirectory,@isdir);
addParameter(p,'OutputPrefix',defaultOutputPrefix,@isstr);
addParameter(p,'Conditions',defaultConditions,@iscell);
addParameter(p,'ROIs',defaultROIs,isROItable);
addParameter(p,'Formula',defaultFormula,@isstr);
addParameter(p,'Weighted',defaultWeighted,@islogical);
addParameter(p,'Robust',defaultRobust,@islogical);
addParameter(p,'InclDiag',defaultInclDiag,@islogical);
addParameter(p,'SubjectThreshold',defaultSubjectThreshold,@isnumeric);

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
if ~isempty(p.Results.ROIs)
    out_dir = strcat( out_dir , '_' , sprintf('ROI-%i',height(p.Results.ROIs)) );
end
if ~p.Results.Weighted
    out_dir = strcat( out_dir , '_Unweighted' );
end
if p.Results.Robust
    out_dir = strcat( out_dir , '_Robust' );
end
if p.Results.InclDiag
    out_dir = strcat( out_dir , '_InclDiag' );
end
if p.Results.SubjectThreshold>0 && p.Results.SubjectThreshold<1
    out_dir = strcat( out_dir , sprintf('_SubjectThreshold-%g',p.Results.SubjectThreshold) );
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
job = [];

if ~isempty(p.Results.Conditions)
    job = nirs.modules.KeepStims( job );
        job.listOfStims = p.Results.Conditions;
end

if ~isempty(p.Results.ROIs)
    job = nirs.modules.ApplyROI(job);
        job.listOfROIs = p.Results.ROIs;
end

if p.Results.SubjectThreshold>0 && p.Results.SubjectThreshold<1
    job = nirs.modules.RemoveOutlierSubjects(job);
    job.formula = p.Results.Formula;
    job.allow_partial_removal = false;
    job.cutoff = p.Results.SubjectThreshold;
end

job = nirs.modules.MixedEffects( job );
    job.verbose = false;
    job.formula = p.Results.Formula;
    job.weighted = p.Results.Weighted;
    job.robust = p.Results.Robust;
    job.include_diagnostics = p.Results.InclDiag;

fprintf('Running job:\n')
disp(job);
fprintf(' ');

GroupModel = job.run(SubjStats);

%% Save results
job_groupact = job;
save(out_file,'GroupModel','job_groupact','SubjStats_hash','in_file');

end