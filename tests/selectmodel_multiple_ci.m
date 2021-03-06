function [pass,maxerr] = test(opt)

% Test that multiple confidence levels can be requested via options

rng(1)
t = linspace(0,8,300);
r = linspace(1,8,300);
parIn  = [4.5,0.5];
P = dd_gauss(r,parIn);

K = dipolarkernel(t,r);
S = K*P + whitegaussnoise(t,0.05);

[~,~,parfit,cistruct] = selectmodel({@dd_gauss,@dd_gauss2},S,r,K,'aic');

paruq1 = cistruct{1}.ci(50);
paruq2 = cistruct{1}.ci(95);

% Pass 1-2: confidence intervals behave as expected
pass = all(all(abs(parfit{1} - paruq1.') < abs(parfit{1} - paruq2.')));

maxerr = NaN;


end