function analysis_3_connectivity_indiv(varargin)
% NIRSKIT.ANALYSIS_3_CONNECTIVITY_INDIV - Batch script for calculating 1st-level connectivity
%
% Usage:
%   % Using default settings
%   nirskit.analysis_3_connectivity_indiv;
%
%   % Overriding some defaults
%   nirskit.analysis_3_connectivity_indiv('DivideEvents',true,'Ignore',15,'ModelOrder','8xFs','Robust',false);
%
% List of optional key-value parameters:
%   InputDirectory    - Location of prepared Results.mat file              (default: current directory)
%   OutputPrefix      - String to prepend to output folder                 (default: 3_connectivity-indiv)
%   DivideEvents      - Flag to calculate connectivity for each condition  (default: true)
%   Conditions        - List of conditions to use                          (default: all)
%   Ignore            - Amount of time at start and end to ignore          (default: 0)
%   MinEventDuration  - Minimum duration (s) needed for inclusion          (default: 10)
%   ModelOrder        - AR model order as a numeric number of samples      (default: '4xFs')
%                       or a string multiple of sample rate
%                       (0 disables AR modeling)
%   Robust            - Whether to use robust correlation                  (default: true)
%
%   See also NIRSKIT.ANALYSIS_2_PREPROCESSING,
%   NIRSKIT.ANALYSIS_4_CONNECTIVITY_GROUP

%% Set defaults
defaultInputDirectory = pwd;
defaultOutputPrefix = '3_connectivity-indiv';
defaultDivideEvents = true;
defaultConditions = {};
defaultIgnore = 0;
defaultMinEventDuration = 10;
defaultModelOrder = '4xFs';
defaultRobust = true;

%% Parse inputs
p = inputParser;
ismodelorder = @(x) isnumeric(x) || (ischar(x) && ~isnan(str2double(strrep(x,'xFs',''))));
addParameter(p,'InputDirectory',defaultInputDirectory,@isdir);
addParameter(p,'OutputPrefix',defaultOutputPrefix,@isstr);
addParameter(p,'DivideEvents',defaultDivideEvents,@islogical);
addParameter(p,'Conditions',defaultConditions,@iscell);
addParameter(p,'Ignore',defaultIgnore,@isnumeric);
addParameter(p,'MinEventDuration',defaultMinEventDuration,@isnumeric);
addParameter(p,'ModelOrder',defaultModelOrder,ismodelorder);
addParameter(p,'Robust',defaultRobust,@islogical);
parse(p,varargin{:});

%% Construct corrfcn
if ischar(p.Results.ModelOrder) || p.Results.ModelOrder>0
    if ischar(p.Results.ModelOrder)
        corrfcn = sprintf('@(data) nirs.sFC.ar_corr(data,''%s''',p.Results.ModelOrder);
    else
        corrfcn = sprintf('@(data) nirs.sFC.ar_corr(data,%g',p.Results.ModelOrder);
    end
else
    corrfcn = '@(data) nirs.sFC.corr(data';
end

if p.Results.Robust
    corrfcn = [corrfcn ',true)'];
else
    corrfcn = [corrfcn ',false)'];
end

%% Check input file
in_dir = GetFullPath(p.Results.InputDirectory);
in_file = [in_dir filesep 'Results.mat'];
if ~exist(in_file,'file'), error('Input file not found: %s',in_file); end

%% Set output file
out_dir = p.Results.OutputPrefix;
if ~p.Results.DivideEvents
    out_dir = strcat( out_dir , '_wholescan' );
else
    out_dir = strcat( out_dir , '_conditions' );
    if ~isempty(p.Results.Conditions)
        out_dir = strcat( out_dir , '_' , strjoin(p.Results.Conditions,'-') );
    end
end
out_dir = strcat( out_dir , sprintf('_ignore-%g',p.Results.Ignore) );
out_dir = strcat( out_dir , sprintf('_mindur-%g',p.Results.MinEventDuration) );
out_dir = strcat( out_dir , '_' , strrep(corrfcn,'''','') );

if ~exist(out_dir,'dir'), mkdir(out_dir); end
out_file = fullfile(out_dir,'Results.mat');
if exist(out_file,'file'), warning('Output file already exists. Skipping.'); return; end

%% Load data
data = load(in_file,'hb');
hb = data.hb;

for i = 1:length(hb)
    hb(i).stimulus = hb(i).stimulus.rehash();
end

%% Compute input data hash
hashopt.Method = 'SHA-256';
hb_hash = DataHash( hb , hashopt );

%% Filter conditions
if ~isempty(p.Results.Conditions)
    job = nirs.modules.KeepStims();
    job.listOfStims = p.Results.Conditions;
    hb = job.run(hb);
end

%% Subject-Level estimation
job_conn = nirs.modules.Connectivity();
    job_conn.divide_events = p.Results.DivideEvents;
    job_conn.ignore = p.Results.Ignore;
    job_conn.min_event_duration = p.Results.MinEventDuration;
    job_conn.corrfcn = str2func(corrfcn);

SubjStats = job_conn.run( hb );

save(out_file,'SubjStats','job_conn','hb_hash','in_file');

end
