function analysis_5_draw(varargin)
% NIRSKIT.ANALYSIS_5_DRAW - Batch script for rendering figures
%
% Usage:
%   % Use defaults
%   nirskit.analysis_5_draw;
%
%   % Draw two specific contrasts, change threshold, save results to disk
%   nirskit.analysis_5_draw('Contrasts',{'2back-1back','NoGo-Motor},'Threshold','q<.01','Save',true);
%
% List of optional key-value parameters:
%   InputDirectory   - Location of prepared Results.mat file            (default: current directory)
%   OutputPrefix     - String to prepend to output folder               (default: 5_figures)
%   Types            - Cell array of hb types                           (default: all)
%   Contrasts        - Cell array of contrasts                          (default: 1 per condition)
%   RespVar          - Which variable to display                        (default: 'tstat')
%   Threshold        - String of significance threshold                 (default: 'p<.05')
%   CLim             - Color scale limits                               (default: [-5 5])
%   Save             - Boolean of whether to save to disk               (default: false)
%   View             - View specification ("2D", "3D mesh (Frontal)")   (default: probe default)
%
%   See also NIRSKIT.ANALYSIS_1_PREPARE,
%   NIRSKIT.ANALYSIS_2_PREPROCESSING,
%   NIRSKIT.ANALYSIS_3_ACTIVATION_INDIV,
%   NIRSKIT.ANALYSIS_4_ACTIVATION_GROUP,

%% Set defaults
defaultInputDirectory = pwd;
defaultOutputPrefix = '5_figures';
defaultTypes = {};
defaultContrasts = {};
defaultRespvar = 'tstat';
defaultThreshold = 'p<.05';
defaultCLim = [-5 5];
defaultSave = false;
defaultView = '';

%% Parse inputs
p = inputParser;
iscellorstr=@(s) (iscell(s) || ischar(s));
isclim=@(c) numel(c)==2 && isnumeric(c);
addParameter(p,'InputDirectory',defaultInputDirectory,@isdir);
addParameter(p,'OutputPrefix',defaultOutputPrefix,@isstr);
addParameter(p,'Types',defaultTypes,iscellorstr);
addParameter(p,'Contrasts',defaultContrasts,iscellorstr);
addParameter(p,'Respvar',defaultRespvar,@isstr);
addParameter(p,'Threshold',defaultThreshold,@isstr);
addParameter(p,'CLim',defaultCLim,isclim);
addParameter(p,'Save',defaultSave,@islogical);
addParameter(p,'View',defaultView,@ischar);

parse(p,varargin{:});

%% Check input file
in_dir = GetFullPath(p.Results.InputDirectory);
in_file = [in_dir filesep 'Results.mat'];
assert(exist(in_file,'file')==2,sprintf('Input file not found: %s',in_file));

%% Set output file
out_dir = fullfile(in_dir,p.Results.OutputPrefix);

if p.Results.Save
    if ~exist(out_dir,'dir'), mkdir(out_dir); end
    out_file = fullfile(out_dir,'Results.mat');
    if exist(out_file,'file'), warning('Output file already exists. Skipping.'); return; end
end

%% Load data
data = load(in_file,'GroupModel');
GroupModel = data.GroupModel;

%% Set view
if ~isempty(p.Results.View)
    GroupModel.probe.defaultdrawfcn = p.Results.View;
end

%% Keep hb types
job = nirs.modules.KeepTypes();
if ~isempty(p.Results.Types)
    if iscell(p.Results.Types)
        job.types = p.Results.Types;
    else
        job.types = {p.Results.Types};
    end
    GroupModel = job.run(GroupModel);
else
    types = unique(GroupModel.variables.type,'stable');
    GroupModel_orig = GroupModel;
    for i=1:length(types)
        job.types = types(i);
        GroupModel(i) = job.run(GroupModel_orig);
    end
end

%% Calculate contrasts
if ~isempty(p.Results.Contrasts)
    GroupStats = GroupModel.ttest(p.Results.Contrasts);
else
    GroupStats = GroupModel;
end

%% Generate figures
for i = 1:length(GroupStats)
    if p.Results.Save
        if isa(GroupStats,'nirs.core.ChannelStats')
            GroupStats(i).printAll(p.Results.Respvar,p.Results.CLim,p.Results.Threshold,p.Results.OutputPrefix,'png');

        elseif isa(GroupStats,'nirs.core.ChannelFStats')
            GroupStats(i).printAll(max(p.Results.CLim),p.Results.Threshold,p.Results.OutputPrefix,'png');

        elseif isa(GroupStats,'nirs.core.sFCStats')
            GroupStats(i).printAll(p.Results.Respvar(1),p.Results.CLim,p.Results.Threshold,p.Results.OutputPrefix,'png');
        else
            error('Unknown type')
        end
    else
        if isa(GroupStats,'nirs.core.ChannelStats')
            GroupStats(i).draw(p.Results.Respvar,p.Results.CLim,p.Results.Threshold);

        elseif isa(GroupStats,'nirs.core.ChannelFStats')
            GroupStats(i).draw(max(p.Results.CLim),p.Results.Threshold);

        elseif isa(GroupStats,'nirs.core.sFCStats')
            GroupStats(i).draw(p.Results.Respvar(1),p.Results.CLim,p.Results.Threshold);

        else
            error('Unknown type')
        end
    end
end
end