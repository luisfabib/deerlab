function [pass,maxerr] = test(opt)

% Test a distance-domain fit of one Rician

t = linspace(0,3,200);
r = linspace(2,6,100);
parIn = [3 0.5];
P = dd_rice(r,parIn);
K = dipolarkernel(t,r);
S = K*P;
par0 = [2 0.1];

[parFit,Pfit] = fitparamodel(S,@dd_rice,r,K,par0');

% Pass 1: distance distribution is well fitted
pass(1) = all(abs(Pfit - P) < 1e-5);
% Pass 2: model parameters are well fitted
pass(2) = all(abs(parFit - parIn) < 1e-3);

pass = all(pass);

maxerr = max(abs(Pfit - P));
 
if opt.Display
   plot(r,P,'k',r,Pfit,'r')
   legend('truth','fit')
   xlabel('r [nm]')
   ylabel('P(r) [nm^{-1}]')
   grid on, axis tight, box on
end

end