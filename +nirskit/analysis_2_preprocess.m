function analysis_2_preprocess(varargin)
% NIRSKIT.ANALYSIS_2_PREPROCESS - Batch script for NIRS preprocessing
%
% Usage:
%   % Minimalistic approach (not recommended)
%   nirskit.analysis_2_preprocessing;
%
%   % More typical approach with reasonable parameters supplied
%   nirskit.analysis_2_preprocessing('PreTrim',3,'PostTrim',12,'MotionCorrection','TDDR','DCTPeriod',128,'ResampleRate',4);
%
% List of optional key-value parameters:
%   InputDirectory   - Location of prepared Results.mat file            (default: current directory)
%   OutputPrefix     - String to prepend to output folder               (default: 2_preprocessed)
%   PreTrim          - # of seconds to keep before first stim           (default: disabled)
%   PostTrim         - # of seconds to keep before last stim            (default: disabled)
%   MotionCorrection - Name of module to use for motion correction      (default: disabled)
%   LPF              - Cutoff in Hz for low-pass IIR filter             (default: disabled)
%   HPF              - Cutoff in Hz for high-pass IIR filter            (default: disabled)
%   DCTPeriod        - # of seconds DCT detrending cutoff               (default: disabled)
%   ResampleRate     - Target sample rate for resampling                (default: disabled)
%   ARPrewhiten      - max model order (in seconds) for AR prewhitening (default: disabled)
%
% Note:
%   The default options are minimalistic, so you will most likely want to supply parameters
%
%   See also NIRSKIT.ANALYSIS_1_PREPARE,
%   NIRSKIT.ANALYSIS_3_ACTIVATION_INDIV,
%   NIRSKIT.ANALYSIS_5a_CONNECTIVITY_INDIV
%   NIRSKIT.ANALYSIS_5b_HYPERSCANNING_INDIV

%% Set defaults
defaultInputDirectory = pwd;
defaultOutputPrefix = '2_preprocessed';
defaultPreTrim = [];
defaultPostTrim = [];
defaultMotionCorrection = [];
defaultLPF = [];
defaultHPF = [];
defaultDCTPeriod = [];
defaultResampleRate = [];
defaultARPrewhiten = [];

%% Parse inputs
p = inputParser;
ismodule = @(x) assert(isempty(x) || exist(['nirs.modules.' x],'class'),sprintf('%s is not a detected module in nirs-toolbox.',x));
addParameter(p,'InputDirectory',defaultInputDirectory,@isdir);
addParameter(p,'OutputPrefix',defaultOutputPrefix,@isstr);
addParameter(p,'PreTrim',defaultPreTrim,@isnumeric);
addParameter(p,'PostTrim',defaultPostTrim,@isnumeric);
addParameter(p,'MotionCorrection',defaultMotionCorrection,ismodule);
addParameter(p,'LPF',defaultLPF,@isnumeric);
addParameter(p,'HPF',defaultHPF,@isnumeric);
addParameter(p,'DCTPeriod',defaultDCTPeriod,@isnumeric);
addParameter(p,'ResampleRate',defaultResampleRate,@isnumeric);
addParameter(p,'ARPrewhiten',defaultARPrewhiten,@isnumeric);

parse(p,varargin{:});

%% Check input file
in_dir = GetFullPath(p.Results.InputDirectory);
in_file = [in_dir filesep 'Results.mat'];
assert(exist(in_file,'file')==2,sprintf('Input file not found: %s',in_file));

%% Set output file
out_dir = fullfile(in_dir,p.Results.OutputPrefix);
if ~isempty(p.Results.PreTrim)
    out_dir = strcat( out_dir , '_PreTrim-' , num2str(p.Results.PreTrim)  , 's' );
end
if ~isempty(p.Results.PostTrim)
    out_dir = strcat( out_dir , '_PostTrim-' , num2str(p.Results.PostTrim)  , 's' );
end
if ~isempty(p.Results.MotionCorrection)
    out_dir = strcat( out_dir , '_MotionCorrection-' , p.Results.MotionCorrection );
end
if ~isempty(p.Results.ResampleRate)
    out_dir = strcat( out_dir , '_ResampleRate-' , num2str(p.Results.ResampleRate)  , 'Hz' );
end
if ~isempty(p.Results.LPF)
    out_dir = strcat( out_dir , '_LPF-' , num2str(p.Results.LPF)  , 'Hz' );
end
if ~isempty(p.Results.HPF)
    out_dir = strcat( out_dir , '_HPF-' , num2str(p.Results.HPF)  , 'Hz' );
end
if ~isempty(p.Results.DCTPeriod)
    out_dir = strcat( out_dir , '_DCTPeriod-' , num2str(p.Results.DCTPeriod)  , 's' );
end
if ~isempty(p.Results.ARPrewhiten)
    out_dir = strcat( out_dir , '_ARPrewhiten-' , num2str(p.Results.ARPrewhiten)  , 's' );
end

if ~exist(out_dir,'dir'), mkdir(out_dir); end
out_file = fullfile(out_dir,'Results.mat');
if exist(out_file,'file'), warning('Output file already exists. Skipping.'); return; end

%% Load data
data = load(in_file,'raw');
raw = data.raw;

%% Compute input data hash
hashopt.Method = 'SHA-256';
raw_hash = DataHash( raw , hashopt );

%% Remove subjects with NaNs or Infs
nsub_orig = length(raw);
for i = length(raw):-1:1
    tmp = raw(i).data;
    if any( isnan(tmp(:)) | ~isfinite(tmp(:)) )
        raw(i)=[];
    end
end
if nsub_orig~=length(raw)
    warning('%i subjects removed due to bad values',nsub_orig-length(raw));
end

%% Preprocessing
job = [];

% Trimming
if ~isempty(p.Results.PreTrim) || ~isempty(p.Results.PostTrim)
    job = nirs.modules.TrimBaseline( job );
        job.preBaseline = inf;
        job.postBaseline = inf;
    
    if ~isempty(p.Results.PreTrim)
        job.preBaseline = p.Results.PreTrim;
    end
    if ~isempty(p.Results.PostTrim)
        job.postBaseline = p.Results.PostTrim;
    end
end

% Intensity to optical density
job = nirs.modules.OpticalDensity( job );

% Motion correction
if ~isempty(p.Results.MotionCorrection)
    job = nirs.modules.(p.Results.MotionCorrection)( job );
end

% Low-pass filter
if ~isempty(p.Results.LPF)
    job = eeg.modules.BandPassFilter( job );
    job.lowpass = p.Results.LPF;
    job.highpass = [];
end

% Resampling
if ~isempty(p.Results.ResampleRate)
    job = nirs.modules.Resample( job );
        job.antialias = true;
        job.Fs = p.Results.ResampleRate;
end

% High-pass filter
if ~isempty(p.Results.HPF)
    job = eeg.modules.BandPassFilter( job );
    job.lowpass = [];
    job.highpass = p.Results.HPF;
end

% DCT detrending
if ~isempty(p.Results.DCTPeriod)
    job = advanced.nirs.modules.DCTFilter( job );
        job.cutoff = p.Results.DCTPeriod;
end

% Conversion to oxy/deoxy Hb
job = nirs.modules.BeerLambertLaw( job );

% Autoregressive prewhitening
if ~isempty(p.Results.ARPrewhiten)
    job = advanced.nirs.modules.AR_Prewhiten( job );
        job.modelorder = p.Results.ARPrewhiten;
        job.verbose = true;
end

fprintf('Running pipeline:\n')
disp(nirs.modules.pipelineToList(job));

hb = job.run(raw);
job_preproc = job;
save(out_file,'hb','job_preproc','raw_hash','in_file');

end