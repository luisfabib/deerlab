% 
% CORRECTSCALE Amplitude offset correction
%
%       [Vc,V0] = CORRECTSCALE(V,t) 
%       Fits the amplitude (V0) of the experimental dipolar signal
%       (V) on a given time axis (t). The experimental signal is then 
%       normalized with respect to the fitted offset. The normalized signal
%       is returned a the main output (Vc).
%

function [V,V0] = correctscale(V,t)

if ~isreal(V)
   error('Input signal cannot be complex.') 
end

%Validate input
validateattributes(t,{'numeric'},{'nonempty','increasing'},mfilename,'t')
validateattributes(V,{'numeric'},{'nonempty'},mfilename,'V')

% Convert time step to microseconds if given in nanoseconds
usesNanoseconds = mean(diff(t))>=0.5;
if usesNanoseconds
    t = round(t)/1000; % ns->us
end

%Convert time to distance axis
r = time2dist(t);

%Get the maximum value of the signal
Amp0 = max(V);

%Time-domain fitting of Gaussian distribution, exponential background,
%modulation depth and the overall amplitude
K = dipolarkernel(t,r);
fitmodel = @(t,param)param(1)*td_exp(t,param(5)).*((1-param(2)) + param(2)*K*rd_onegaussian(r,param(3:4)));
%Set the initial values for the fitting
param0 = [Amp0 0.5 3 0.3 0.2];
%Run the parametric model fitting
paramfit = fitparamodel(V,fitmodel,t,param0,...
    'Upper',[1e100 1 20 5 100],...
    'Lower',[0 eps 0 0 0]);

% Get the fitted signal amplitude
V0 = paramfit(1);

% Normalize the signal by the fitted amplitude
V = V/V0;

end