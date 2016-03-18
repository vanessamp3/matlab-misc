function [out_data] = eeg_mlr(in_data, regressors, timewindow)
%--------------------------------------------------------------------------
% Name : R:\ERP Research\Vanessa\scripts\eeg_mlr.m
% 
% Author : Vanessa
% 
% Creation Date : 10/15/2015
% 
% Purpose : This will perform Multiple Linear Regression (MLR) similar to
% De Vos (2012) for one of the methods they compared for single trial peak
% estimation. The details of the procedure are from Hu (2011).
%
% Essentially, we are estimating each trial based on the average ERP
% components and their derivatives. Each trial should then be a composite measure of how well
% each average ERP component maps onto the trial. Our predicted is the
% average ERP, while the regressors are the ERP components + their
% derivatives.
%
% Inputs:
%       in_data: an array with a single subject's single trial single electrode data
%       (timepoints x trials)
%       regressors: an array containing grand average ERPs and their
%       derivatives (num of regressors x timepoints)
%       timewindow: the timepoints provided in the in_data input
%
% Output: 
%       out_data: modelled data estimated by the regression model
%
% Last modified: Vanessa
% 
% Last run : 10/16/2015
%--------------------------------------------------------------------------

% Determine size of inputs
numTrials = size(in_data,2);
numTimepoints = size(in_data,1);

% Initialize output data array
out_data = zeros(numTimepoints,numTrials);

% For each trial, do the regression
for t = 1:numTrials
    
    % Get data for this current trial
    trial = in_data(:,t);
    
    % Run the regression
    stats = regstats(trial, regressors', 'linear');
    % stats.yhat will be the predicted result    
    out_data(:,t) = stats.yhat;
    
    % Overlay the original ERP waveform with the predicted waveform
    plot(timewindow, trial, 'b');
    hold on; plot(timewindow, stats.yhat,'r');
    close;
    
end