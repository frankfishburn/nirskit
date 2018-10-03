# nirskit
## About
**nirskit** is a filesystem-based command line wrapper for the NIRS Brain AnalyzIR toolbox. It was designed with the objective of trading flexibility for ease-of-use.

The main design principles are:
- Each function should map onto a cohesive stage of the pipeline (preprocessing, subject-level, group-level, etc)
- Mandatory steps (e.g., optical density conversion, Beer-Lambert law) should be done automatically
- Analysis parameters should be passed in as key-value pairs
- Directories containing a `Results.mat` file are the input/output for each function

## Usage
This design allows much faster and easier execution of typical pipelines. For example:

```matlab
% Preprocess with TDDR motion correction, resample to 5Hz, and high-pass filter with a cutoff of .01 Hz
nirskit.analysis_2_preprocess('MotionCorrection','TDDR','Resample',5, HPF,.01);
```
```matlab
% Subject-level activation with estimation of temporal/dispersion derivatives, and HRF peak at 6 seconds
nirskit.analysis_3_activation_indiv('InclDeriv',true,'PeakTime',6);
```
```matlab
% Group-level activation treating condition as a fixed effect and subject ID as a random effect
nirskit.analysis_4_activation_group('Formula','beta~-1+cond+(1|subject)');
```

In addition, it simplifies the task of varying a parameter over a range to test its effect:
```matlab
% Preprocess with high-pass filter cutoffs varying from .001 Hz to .5 Hz, in intervals of .001 Hz
for cutoff=.001:.001:.5
    nirskit.analysis_2_preprocess('HPF',cutoff);
end
```

## Output
Each function takes in a directory that contains a `Results.mat` file for its input. The expected contents of this file depends on the function (e.g., preprocessing expects `raw`, subject-level activation expects `hb`, group-level activation expects `SubjStats`). The output is then written to a new directory within the input directory, with the directory name specified by the function and its configuration parameters. Therefore the path to any given `Results.mat` file will reflect the entire processing pipeline used. For example, preprocessed data in the example above would end up in a location like this: 

`<datadir>\2_preprocessed_MotionCorrection-TDDR_Resample-5Hz_HPF-0.01Hz\Results.mat`

And the corresponding group-level results would end up in a location like this:

`<datadir>\2_preprocessed_MotionCorrection-TDDR_Resample-5Hz_HPF-0.01Hz\3_activation-indiv_conditions_Peak-6s-deriv\4_activation-group_beta~-1+cond+(1|Name)\Results.mat`
