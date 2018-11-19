function analysis_3_activation_indiv(varargin)
% NIRSKIT.ANALYSIS_3_ACTIVATION_INDIV - Batch script for calculating 1st-level activation
%
% Usage:
%   % Using default settings
%   nirskit.analysis_3_activation_indiv;
%
%   % Overriding some defaults
%   nirskit.analysis_3_activation_indiv('Type','OLS','PeakTime',6,'InclDeriv',true,'SaveResiduals',true);
%
% List of optional key-value parameters:
%   InputDirectory    - Location of prepared Results.mat file              (default: current directory)
%   OutputPrefix      - String to prepend to output folder                 (default: 3_activation-indiv)
%   Conditions        - List of conditions to use                          (default: all)
%   Blocks2Conditions - Convert each task block to a separate condition    (default: false)
%   ModelNull         - Create a null task condition from empty time       (default: false)
%   Type              - GLM approach: 'OLS','NIRS-SPM','AR-IRLS'           (default: 'AR-IRLS')
%                                     'MV-GLM','Nonlinear'
%   PeakTime          - Time (seconds) until canonical HRF peak            (default: 4)
%   InclDeriv         - Whether to include temporal/dispersion derivatives (default: false)
%   SumDeriv          - Whether to sum canonical+temporal+dispersion       (default: false)
%   TrendFunc         - Function for detrending:
%                       Ex. @(t) nirs.design.trend.dctmtx(t,1/128)         (default: [])
%   SaveResiduals     - Whether to save residuals                          (default: false)
%                       in <output_dir>/residuals/Results.mat
%
%   See also
%   NIRSKIT.ANALYSIS_2_PREPROCESS
%   NIRSKIT.ANALYSIS_4_ACTIVATION_GROUP

%% Set defaults
defaultInputDirectory = pwd;
defaultOutputPrefix = '3_activation-indiv';
defaultConditions = {};
defaultBlocks2Conditions = false;
defaultModelNull = false;
defaultType = 'AR-IRLS';
defaultPeakTime = 4;
defaultInclDeriv = false;
defaultSumDeriv = false;
defaultTrendFunc = [];
defaultSaveResiduals = false;

%% Parse inputs
p = inputParser;
isfunc = @(x) assert(isa(x,'function_handle')||isempty(x),sprintf('TrendFunc is not a function handle'));
addParameter(p,'InputDirectory',defaultInputDirectory,@isdir);
addParameter(p,'OutputPrefix',defaultOutputPrefix,@isstr);
addParameter(p,'Conditions',defaultConditions,@iscell);
addParameter(p,'Blocks2Conditions',defaultBlocks2Conditions,@islogical);
addParameter(p,'ModelNull',defaultModelNull,@islogical);
addParameter(p,'Type',defaultType,@isstr);
addParameter(p,'PeakTime',defaultPeakTime,@isnumeric);
addParameter(p,'InclDeriv',defaultInclDeriv,@islogical);
addParameter(p,'SumDeriv',defaultSumDeriv,@islogical);
addParameter(p,'TrendFunc',defaultTrendFunc,isfunc);
addParameter(p,'SaveResiduals',defaultSaveResiduals,@islogical);
parse(p,varargin{:});

%% Check input file
in_dir = GetFullPath(p.Results.InputDirectory);
in_file = [in_dir filesep 'Results.mat'];
if ~exist(in_file,'file'), error('Input file not found: %s',in_file); end

%% Set output file
out_dir = p.Results.OutputPrefix;
if ~isempty(p.Results.Conditions)
    out_dir = strcat( out_dir , '_' , strjoin(p.Results.Conditions,'-') );
end
if p.Results.Blocks2Conditions
    out_dir = strcat( out_dir , '_blocks' );
else
    out_dir = strcat( out_dir , '_conditions' );
end
if p.Results.ModelNull
    out_dir = strcat( out_dir , '_nullcond' );
end
out_dir = strcat( out_dir , '_' , p.Results.Type );
out_dir = strcat( out_dir , '_Peak-' , num2str(p.Results.PeakTime) , 's' );
if p.Results.InclDeriv
    out_dir = strcat( out_dir , '-deriv');
    if p.Results.SumDeriv
        out_dir = strcat( out_dir , '-sum');
    end
end
if ~isempty(p.Results.TrendFunc)
    out_dir = strcat( out_dir , '_' , func2str(p.Results.TrendFunc) );
end

out_dir = fullfile(in_dir,strrep(out_dir,'/','÷'));
if ~exist(out_dir,'dir'), mkdir(out_dir); end
out_file = fullfile(out_dir,'Results.mat');
if exist(out_file,'file'), warning('Output file already exists. Skipping.'); return; end

if p.Results.SaveResiduals
    resid_dir = fullfile(out_dir,'residuals');
    if ~exist(resid_dir,'dir'), mkdir(resid_dir); end
    resid_file = fullfile(resid_dir,'Results.mat');
    if exist(resid_file,'file'), warning('Residuals file already exists. Skipping.'); return; end
end

disp(p.Results);

%% Load data
data = load(in_file,'hb');
hb = data.hb;

%% Compute input data hash
hashopt.Method = 'SHA-256';
hb_hash = DataHash( hb , hashopt );

%% Filter conditions
if ~isempty(p.Results.Conditions)
    job = nirs.modules.KeepStims();
    job.listOfStims = p.Results.Conditions;
    job.required = true;
    hb = job.run(hb);
    if isempty(hb)
        return;
    end
end

%% Split blocks into separate conditions if specified
if p.Results.Blocks2Conditions
    job = advanced.nirs.modules.BlocksToConditions();
    hb = job.run(hb);
end

%% Create a null condition
if p.Results.ModelNull
    job = nirs.modules.CreateNullCondition();
    hb = job.run(hb);
end

%% Subject-Level estimation
canon = nirs.design.basis.Canonical();
canon.peakTime = p.Results.PeakTime;
canon.incDeriv = p.Results.InclDeriv;
basis = Dictionary();
basis('default') = canon;

job_glm = nirs.modules.GLM();
    job_glm.type = p.Results.Type;
    job_glm.verbose = true;
    job_glm.basis = basis;
    job_glm.trend_func = p.Results.TrendFunc;

SubjStats = job_glm.run( hb );

%% If derivatives were estimated, discard and keep only canonical
if p.Results.InclDeriv
    conds = sort(hb(1).stimulus.keys);
    if p.Results.SumDeriv
        % don't let ttest() know about the blocks
        for i=1:length(SubjStats)
            SubjStats(i).variables.cond=strrep(strrep(SubjStats(i).variables.cond,'-',''),' ◄ ','α');
        end
        conds = strrep(strrep(conds,'-',''),' ◄ ','α');
        deriv_conds = strcat( conds , ':01+' , conds , ':02+' , conds , ':03' );
        SubjStats = SubjStats.ttest(deriv_conds,[],conds);
        for i=1:length(SubjStats)
            SubjStats(i).variables.cond=strrep(SubjStats(i).variables.cond,'α',' ◄ ');
        end      
    else
        deriv_conds = strcat( conds , ':01' );
        j = nirs.modules.RenameStims();
        j.listOfChanges = [deriv_conds' conds'];
        j = nirs.modules.KeepStims(j);
        j.listOfStims = conds';
        SubjStats = j.run(SubjStats);
    end
end

save(out_file,'SubjStats','job_glm','hb_hash','in_file');

%% Save residuals
if p.Results.SaveResiduals
    job_resid = advanced.nirs.modules.GLMResiduals();
        job_resid.GLMjob = job_glm;

    hb = job_resid.run( hb );

    save(resid_file,'hb','job_resid','hb_hash','in_file');
end
end
