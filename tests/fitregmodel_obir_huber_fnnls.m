function [pass,maxerr] = test(opt)

% Check that OBIR works with Huber regularization using the fnnls solver

rng(1)
t = linspace(0,3,200);
r = linspace(2,7,100);
P = dd_gauss2(r,[3.7,0.5,0.5,4.3,0.3,0.5]);
K = dipolarkernel(t,r);

V = K*P + whitegaussnoise(t,0.05);

Pfit = fitregmodel(V,K,r,'huber','aic','obir',true);

% Pass: OBIR fits the distribution
pass = all(abs(Pfit - P)<4e-1);
maxerr = max(abs(Pfit - P));
 
if opt.Display
    plot(r,P,'k',r,Pfit,'r')
    legend('truth','OBIR')
    xlabel('r [nm]')
    ylabel('P(r) [nm^{-1}]')
    grid on, axis tight, box on
end

end