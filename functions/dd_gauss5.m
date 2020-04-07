%
% DD_GAUSS5 Sum of five Gaussian distributions parametric model
%
%   info = DD_GAUSS5
%   Returns an (info) structure containing the specifics of the model.
%
%   P = DD_GAUSS5(r,param)
%   Computes the N-point model (P) from the N-point distance axis (r) according to 
%   the paramteres array (param). The required parameters can also be found 
%   in the (info) structure.
%
% PARAMETERS
% name      symbol default lower bound upper bound
% --------------------------------------------------------------------------
% param(1)  <r1>   2.5     1.5         20         center of 1st Gaussian
% param(2)  w1     0.5     0.2         5          FWHM of 1st Gaussian
% param(3)  <r2>   3.0     1.5         20         center of 2nd Gaussian
% param(4)  w2     0.5     0.2         5          FWHM of 2nd Gaussian
% param(5)  <r3>   3.5     1.5         20         center of 3rd Gaussian
% param(6)  w3     0.5     0.2         5          FWHM of 3rd Gaussian
% param(7)  <r4>   4.5     1.5         20         center of 4th Gaussian
% param(8)  w4     0.5     0.2         5          FWHM of 4th Gaussian
% param(9)  <r5>   5.0     1.5         20         center of 5th Gaussian
% param(10) w5     0.5     0.2         5          FWHM of 5th Gaussian
% param(11) p1     0.2     0           1          amplitude of 1st Gaussian
% param(12) p2     0.2     0           1          amplitude of 2nd Gaussian
% param(13) p3     0.2     0           1          amplitude of 3rd Gaussian
% param(14) p4     0.2     0           1          amplitude of 4th Gaussian
%--------------------------------------------------------------------------
%

% This file is a part of DeerLab. License is MIT (see LICENSE.md). 
% Copyright(c) 2019: Luis Fabregas, Stefan Stoll, Gunnar Jeschke and other contributors.


function output = dd_gauss5(r,param)

nParam = 14;

if nargin~=0 && nargin~=2
    error('Model requires two input arguments.')
end

if nargin==0
    %If no inputs given, return info about the parametric model
    info.model  = 'Five-Gaussian distribution';
    info.nparam  = nParam;
    info.parameters(1).name = 'Center <r1> of 1st Gaussian';
    info.parameters(1).range = [1 20];
    info.parameters(1).default = 2.5;
    info.parameters(1).units = 'nm';
    
    info.parameters(2).name = 'FWHM w1 of 1st Gaussian';
    info.parameters(2).range = [0.2 5];
    info.parameters(2).default = 0.5;
    info.parameters(2).units = 'nm';
    
    info.parameters(3).name = 'Center <r2> of 2nd Gaussian';
    info.parameters(3).range = [1 20];
    info.parameters(3).default = 3;
    info.parameters(3).units = 'nm';
    
    info.parameters(4).name = 'FWHM w2 of 2nd Gaussian';
    info.parameters(4).range = [0.2 5];
    info.parameters(4).default = 0.5;
    info.parameters(4).units = 'nm';
    
    info.parameters(5).name = 'Center <r3> of 3rd Gaussian';
    info.parameters(5).range = [1 20];
    info.parameters(5).default = 3.5;
    info.parameters(5).units = 'nm';
    
    info.parameters(6).name = 'FWHM w3 of 3rd Gaussian';
    info.parameters(6).range = [0.2 5];
    info.parameters(6).default = 0.5;
    info.parameters(6).units = 'nm';
    
    info.parameters(7).name = 'Center <r4> of 4th Gaussian';
    info.parameters(7).range = [1 20];
    info.parameters(7).default = 4;
    info.parameters(7).units = 'nm';
    
    info.parameters(8).name = 'FWHM w4 of 4th Gaussian';
    info.parameters(8).range = [0.2 5];
    info.parameters(8).default = 0.5;
    info.parameters(8).units = 'nm';
    
    info.parameters(9).name = 'Center <r4> of 4th Gaussian';
    info.parameters(9).range = [1 20];
    info.parameters(9).default = 5;
    info.parameters(9).units = 'nm';
    
    info.parameters(10).name = 'FWHM w4 of 4th Gaussian';
    info.parameters(10).range = [0.2 5];
    info.parameters(10).default = 0.5;
    info.parameters(10).units = 'nm';
    
    info.parameters(11).name = 'Relative amplitude A1 of 1st Gaussian';
    info.parameters(11).range = [0 1];
    info.parameters(11).default = 0.2;
    
    info.parameters(12).name = 'Relative amplitude A2 of 2nd Gaussian';
    info.parameters(12).range = [0 1];
    info.parameters(12).default = 0.2;
    
    info.parameters(13).name = 'Relative amplitude A3 of 3rd Gaussian';
    info.parameters(13).range = [0 1];
    info.parameters(13).default = 0.2;
       
    info.parameters(14).name = 'Relative amplitude A4 of 4th Gaussian';
    info.parameters(14).range = [0 1];
    info.parameters(14).default = 0.2;
    
    output = info;
    return
end

if nargin~=2
    error('Model requires two input arguments.')
end

% Parse input
validateattributes(r,{'numeric'},{'nonnegative','increasing','nonempty'},mfilename,'r')

% Compute the model distance distribution
fwhm = param([2 4 6 8 10]);
r0 = param([1 3 5 7 9]);
a = param([11 12 13 14]);
a(5) = max(1-sum(a),0);
P = multigaussfun(r,r0,fwhm,a);

output = P;

return