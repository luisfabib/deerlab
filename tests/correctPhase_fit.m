function [err,data] = test(opt,olddata)

%======================================================
% Phase correction function
%======================================================

originalData = 1:100;
inputPhase = pi/4;

phasedData = originalData.*exp(-1i*inputPhase);

[correctedData,outputPhase] = correctphase(phasedData);


err(1) = any(abs(imag(correctedData) - imag(originalData))>1e-10);
err(2) = abs(inputPhase - outputPhase)>1e-5;

err = any(err);
data = [];

end