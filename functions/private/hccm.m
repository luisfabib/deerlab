function C = hccm(J,res,mode)
%
% HCCM  Heteroscedasticity Consistent Covariance Matrix (HCCM)
%
%   C = HCCM(J,res,mode)
%
%   Estimates the heteroscedasticity consistent covariance matrix (HCCM) of
%   a given LSQ problem given by the Jacobian matrix and the corresponding residual
%   vector. The HCCM matrices are valid for both heteroscedasticit and
%   homoscedasticit residual vectors. 
%
%  Input:
%    J         Jacobian (NxM matrix)
%    res       vector of residuals (Nx1 array)
%    mode      HCCM estimator (string)
%                 'HC0' - White, H. (1980)
%                 'HC1' - MacKinnon and White, (1985)
%                 'HC2' - MacKinnon and White, (1985)
%                 'HC3' - Davidson and MacKinnon, (1993)
%                 'HC4' - Cribari-Neto, (2004)
%                 'HC5' - Cribari-Neto, (2007)
%
%  Output:
%    C     heteroscedasticity consistent covariance matrix (MxM matrix)
%
% REFERENCES: 
% [1] White, H. (1980). A heteroskedasticity-consistent covariance matrix
%     estimator and a direct test for heteroskedasticity. Econometrica, 48(4), 817-838
%     DOI: 10.2307/1912934
%
% [2] MacKinnon and White, (1985). Some heteroskedasticity-consistent covariance
%     matrix estimators with improved finite sample properties. Journal of Econometrics, 
%     29 (1985), pp. 305-325. DOI: 10.1016/0304-4076(85)90158-7
%
% [3] Davidson and MacKinnon, (1993). Estimation and Inference in Econometrics
%     Oxford University Press, New York. 
%
% [4] Cribari-Neto, F. (2004). Asymptotic inference under heteroskedasticity of
%     unknown form. Computational Statistics & Data Analysis, 45(1), 215-233
%     DOI: 10.1016/s0167-9473(02)00366-3
%
% [5] Cribari-Neto, F., Souza, T. C., & Vasconcellos, K. L. P. (2007). Inference
%     under heteroskedasticity and leveraged data. Communications in Statistics –
%     Theory and Methods, 36(10), 1877-1888. DOI: 10.1080/03610920601126589

% Hat matrix
H = J*pinv(J.'*J)*J.';
% Get leverage
h = diag(H);
% Number of parameters
k = size(J,2);
% Number of variables
n = size(J,1);

% Select estimation method using established nomenclature
switch upper(mode)
    
    case 'HC0' % White,(1980),[1]
        % Estimate the data covariance matrix
        V = diag(res.^2);
    
    case 'HC1' % MacKinnon and White,(1985),[2]
        % Estimate the data covariance matrix
        V = n/(n-k)*diag(res.^2);
    
    case 'HC2' % MacKinnon and White,(1985),[2] 
        % Estimate the data covariance matrix
        V = diag(res.^2./(1-h));

    case 'HC3' % Davidson and MacKinnon,(1993),[3]
        % Estimate the data covariance matrix
        V = diag(res./(1-h)).^2;
        
    case 'HC4' % Cribari-Neto,(2004),[4] 
        % Compute discount factor
        delta = min(4,n*h/k);
        % Estimate the data covariance matrix
        V = diag(res.^2./((1 - h).^delta));
        
    case 'HC5' % Cribari-Neto,(2007),[5]
        % Compute inflation factor
        k = 0.7;
        alpha = min(max(4,k*max(h)/mean(h)),h/mean(h));
        % Estimate the data covariance matrix
        V = diag(res.^2./(sqrt((1 - h).^alpha)));
        
    otherwise
        error('HCCM estimation mode not found.')
end

% Suppress warnings for a moment
warning('off','MATLAB:nearlySingularMatrix'), warning('off','MATLAB:singularMatrix')
lastwarn('');

% Heteroscedasticity Consistent Covariance Matrix (HCCM) estimator
C = pinv(J.'*J)*J.'*V*J*pinv(J.'*J);

% Detect if there was a 'nearly singular' warning...
[~, warnId] = lastwarn;
if strcmp(warnId,'MATLAB:nearlySingularMatrix') || strcmp(warnId,'MATLAB:singularMatrix')
    % ...and if there was, then use a pseudoinverse instead of inverse
    C = sparse(pinv(J.'*J)*J.'*V*J*pinv(J.'*J));
    lastwarn('');
end
warning('on','MATLAB:nearlySingularMatrix'), warning('on','MATLAB:singularMatrix')
        


end
