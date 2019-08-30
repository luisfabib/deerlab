%
% TD_POLY1 Polynomial 1st-order background model 
%
%   info = TD_POLY1
%   Returns an (info) structure containing the specifics of the model.
%
%   B = TD_POLY1(t,param)
%   Computes the N-point model (B) from the N-point time axis (t) according to 
%   the paramteres array (param). The required parameters can also be found 
%   in the (info) structure.
%
% PARAMETERS
% name    symbol default lower bound upper bound
% ------------------------------------------------------------------
% PARAM(1)  p0     1        0            200        Intercept
% PARAM(2)  p1     -1     -200           200        1st order weight
% ------------------------------------------------------------------
%
% Copyright(C) 2019  Luis Fabregas, DeerAnalysis2
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License 3.0 as published by
% the Free Software Foundation.


function output = td_poly1(t,param)

nParam = 2;

if nargin==0
    %If no inputs given, return info about the parametric model
    info.Model  = 'Polynomial 1st Order';
    info.Equation  = 'p0 + p1*t';
    info.nParam  = nParam;
    info.parameters(1).name = 'Intercept p0';
    info.parameters(1).range = [0 200];
    info.parameters(1).default = 1;
    info.parameters(1).units = ' ';

    info.parameters(2).name = 'Slope p1';
    info.parameters(2).range = [-200 200];
    info.parameters(2).default = -1;
    info.parameters(2).units = 'us^-1';
    
    output = info;
    
elseif nargin == 2
    
    %If user passes them, check that the number of parameters matches the model
    if length(param)~=nParam
        error('The number of input parameters does not match the number of model parameters.')
    end    
    
    %If necessary inputs given, compute the model distance distribution
    t = abs(t);
    Background = polyval(fliplr(param),t);
    if ~iscolumn(Background)
        Background = Background';
    end
    output = Background;
else
    
    %Else, the user has given wrong number of inputs
    error('Model requires two input arguments.')
end

return