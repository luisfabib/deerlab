function [err,data,maxerr] = test(opt,olddata)

%=======================================
% Check Tikhonov regularization
%=======================================

Dimension = 100;
TimeStep = 0.008;
TimeAxis = linspace(0,TimeStep*Dimension,Dimension);
DistanceAxis = time2dist(TimeAxis);
Distribution = gaussfcn(DistanceAxis,3,0.5);
Distribution = Distribution/sum(Distribution);

Kernel = dipolarkernel(TimeAxis,DistanceAxis);
RegMatrix =  regoperator(Dimension,2);
DipEvoFcn = Kernel*Distribution;
rng(2);
Noise = rand(Dimension,1);
Noise = Noise - mean(Noise);
Noise = 0.25*Noise;
NoiseLevel = std(Noise);
Signal = DipEvoFcn+Noise;

%Set optimal regularization parameter (found numerically lambda=0.13)
RegParam = 50;
Result = obir(Signal,Kernel,'tikhonov',RegMatrix,RegParam,NoiseLevel);

OVL = 1 - metrics(Result,Distribution,'overlap');
err = any(OVL < 0.9);
maxerr = OVL;
data = [];

if opt.Display
 	figure(8),clf
    hold on
    plot(DistanceAxis,Distribution,'k') 
    plot(DistanceAxis,Result,'b')
    Result = regularize(Signal,Kernel,RegMatrix,'tikhonov',RegParam);
    plot(DistanceAxis,Result,'r')

end

end