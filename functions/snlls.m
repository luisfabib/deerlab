%
% SNNLS  Separable Non-linear Least Squares Solver
%
%   [pnlin,plin,paramuq] = SNNLS(___)
%   __ = SNNLS(y,Amodel,par0,lb,ub,lbl,ubl)
%   __ = SNNLS(y,Amodel,par0,lb,ub,lbl)
%   __ = SNNLS(y,Amodel,par0,lb,ub)
%   __ = SNNLS(y,Amodel,par0,lb)
%   __ = SNNLS(y,Amodel,par0)
%   __ = SNNLS(___,'Name',Values,___)
%
%   Fits a linear set of parameters (x) and non-linear parameters (p)
%   by solving the following non-linear least squares problem:
%
%           [x,p] = argmin || A(p)*x - y||^2
%                    s.t.   x in [lbl,ubl]
%                           p in [lb,ub]
%
%  When solving the linear problem: argmin_x ||y - A*x||^2  the solver will
%  identify and adapt automatically to the following scenarios:
%    - Well-conditioned + unconstrained       x = A\y;
%    - Well-conditioned + constrained         x = lsqlin(A,y,lb,ub)
%    - Ill-conditioned  + unconstrained       x = (AtA + alpha^2*LtL)\Kty
%    - Ill-conditioned  + constrained         x = lsqlin(AtA + alpha^2*LtL,Kty,lb,ub)
%    - Ill-conditioned  + non-negativity      x = fnnls((AtA + alpha^2*LtL),Kty)
%  By default, for poorly conditioned cases, Tikhonov regularization with
%  automatic AIC-based regularization parameter selection is used.
%
%  Input:
%    y         N-element vector of input data to be fitted
%    Amodel    Function handle accepting non-linear parameters and returning
%              a NxM-element matrix
%    par0      W-element vector, start values of the non-linear parameters
%    lb        W-element vector of lower bounds for the non-linear parameters
%    ub        W-element vector of upper bounds for the non-linear parameters
%    lbl       M-element vector of lower bounds for the linear parameters
%    ubl       M-element vector of lower bounds for the linear parameters
%
%  Output:
%    pnlin     fitted non-linear parameters
%    nlin      fitted linear parameters
%    paramuq   uncertainty quantification structure
%
%  Name-value pairs:
%
%   'forcePenalty'  -(true/false) Forces use of regularization penalties on the linear optimization
%   'RegType'       -Regularization functional type ('tikh','tv','huber')
%   'RegOrder'      -Order of the regularization operator
%   'RegParam'      -Regularization parameter selection ('lr','lc','cv','gcv',
%                      'rgcv','srgcv','aic','bic','aicc','rm','ee','ncp','gml','mcl')
%                       or value of the regularization parameter
%   'alphaOptThreshold' -Relative parameter change threshold for reoptimizing
%                          the regularization parameter
%   'MultiStart'    -Number of starting points for global optimization
%   'LinSolver'     -Linear LSQ solver
%                         'lsqlin' - Requires Optimization Toolbox
%                         'minq'   - Free
%   'nonLinSolver'  -Non-linear LSQ solver
%                         'lsqnonlin' - Requires Optimization Toolbox
%                         'lmlsqnonlin'   - Free
%   'nonLinMaxIter' -Non-linear solver maximal number of iterations
%   'nonLinTolFun'  -Non-linear solver function tolerance
%   'LinMaxIter'    -Linear solver maximal number of iterations
%   'LinTolFun'     -Linear solver function tolerance

% This file is a part of DeerLab. License is MIT (see LICENSE.md).
% Copyright(c) 2019-2020: Luis Fabregas, Stefan Stoll and other contributors.

function [nonlinfit,linfit,paramuq] = snlls(y,Amodel,par0,varargin)

% Parse inputs in the varargin
[ubl,lbl,lb,ub,options] = parseinputs(varargin);

% Default optional settings
alphaOptThreshold = 1e-3;
RegOrder = 2;
RegType = 'tikhonov';
RegParam = 'aic';
multiStarts = 1;
forcePenalty = false;
nonLinTolFun = 1e-5;
nonLinMaxIter = 1e4;
LinTolFun = 1e-5;
LinMaxIter = 1e4;
if optimtoolbox_installed
    nonLinSolver = 'lsqnonlin';
    LinSolver = 'lsqlin';
else
    nonLinSolver = 'lmlsqnonlin';
    LinSolver = 'minq';
end

% Parse and validate options passed by the user, if the user has specified
% any, this call will overwrite the defaults above
parsevalidate(options)

%Pre-allocate static workspace variables to share between subfunctions
[illConditioned,linearConstrained,nonLinearConstrained,nonNegativeOnly,L,...
    par_prev,regparam_prev,linfit] = deal([]);

% Setup non-linear solver
switch nonLinSolver
    case 'lsqnonlin'
        nonLinSolverFcn = @lsqnonlin;
        nonLinSolverOpts = optimoptions(@lsqnonlin,'Display','off','MaxIter',nonLinMaxIter,...
            'MaxFunEvals',1e4,'TolFun',nonLinTolFun,...
            'DiffMinChange',0,'DiffMaxChange',Inf);
    case 'lmlsqnonlin'
        nonLinSolverFcn = @lmlsqnonlin;
        nonLinSolverOpts = struct('Display','off','MaxIter',nonLinMaxIter,'MaxFunEvals',1e4,'TolFun',nonLinTolFun);
end

% Setup linear solver
switch LinSolver
    case 'lsqlin'
        linSolverFcn = @(A,y,lbl,ubl,opts)lsqlin(A,y,[],[],[],[],lbl,ubl,[],opts);
        linSolverOpts = optimoptions(@lsqlin,'Display','off','MaxIter',LinMaxIter,'TolFun',LinTolFun);
    case 'minq'
        linSolverFcn = @lsqlin_QP;
        linSolverOpts = [];
end

% Get conditioning of the non-linear operator
A0 = Amodel(par0);
illConditioned = cond(A0)>10;

% Get number of parameters
Nnonlin = numel(par0);
Nlin = size(A0,2);

% Validate the box constraints
checkbounds;

% Preprare multiple start global optimization if requested
if multiStarts>1 && ~nonLinearConstrained
    error('Multistart optimization cannot be used with unconstrained non-linear parameters.')
end
multiStartPar0 = multistarts(multiStarts,par0,lb,ub);

% Pre-allocate containers for multi-start run
fvals = zeros(1,multiStarts);
[nonlinfits,linfits] = deal(cell(1,multiStarts));

% Multi-start global optimization
for runIdx = 1:multiStarts
    
    % Get start values for current run
    par0 = multiStartPar0(runIdx,:);
    
    % Run the non-linear solver
    [nonlinfit,fval]  = nonLinSolverFcn(@ResidualsFcn,par0,lb,ub,nonLinSolverOpts);
    
    % Store the optimization results
    fvals(runIdx) = fval;
    nonlinfits{runIdx} = nonlinfit;
    linfits{runIdx} = linfit;
end

% Find global minimum from multiple runs
[~,globmin] = min(fvals);
nonlinfit = nonlinfits{globmin};
linfit = linfits{globmin};

% Uncertainty analysis (if requested)
if nargout>2
    paramuq = uncertainty(nonlinfit);
end

% Return all parameter vectors are row columns
linfit = linfit(:).';
nonlinfit = nonlinfit(:).';

% Residual vector function
% ------------------------------------------------------------------
% Function that provides vector of residuals, which is the objective
% function for the least-squares solvers
    function res = ResidualsFcn(p)
        
        % Non-linear model evaluation
        % ===============================
        A = Amodel(p);
        
        % Regularization components
        % ===============================
        if illConditioned || forcePenalty
            % Use an arbitrary axis
            ax = (1:1:size(A,2));
            % Get regularization operator
            RegOrder = min(size(A,2)-1,RegOrder);
            L = regoperator(ax,RegOrder);
            if ischar(RegParam)
                % If the parameter vector has not changed by much...
                if ~isempty(par_prev) && all(abs(par_prev-p)./p < alphaOptThreshold)
                    % ...use the alpha optimized in the previous iteration
                    alpha = regparam_prev;
                else
                    % ...otherwise optimize with current settings
                    alpha = selregparam(y,A,ax,RegType,RegParam,'RegOrder',RegOrder);
                end
            else
                % Fixed regularization parameter
                alpha =  RegParam;
            end
            % Get components for LSQ fitting
            [AtAreg,Aty] = lsqcomponents(y,A,L,alpha,RegType);
            
            % Store current iteration data for next one
            par_prev = p;
            regparam_prev = alpha;
            
            % Non-linear operator with penalty
            A_ = AtAreg;
            y_ = Aty;
            penalty = alpha*L*linfit;
        else
            % Non-linear operator without penalty
            A_ = A;
            y_ = y;
            penalty = [];
        end
        
        if ~linearConstrained
            % Unconstrained linear LSQ
            % ====================================
            linfit = A_\y_;
            
        elseif linearConstrained && ~nonNegativeOnly
            % Constrained linear LSQ
            % ====================================
            linfit = linSolverFcn(A_,y_,lbl,ubl,linSolverOpts);
            
        elseif linearConstrained && nonNegativeOnly
            % Non-negative linear LSQ
            % ====================================
            linfit = fnnls(A_,y_);
        end
        
        % Evaluate full model residual
        % ===============================
        yfit = A*linfit;
        % Adjust overall scale of the fit
        yfit = (yfit\y)*yfit;
        % Compute residual vector
        res = yfit - y;
        % Augmented residual
        res = [res; penalty];
    end


% Uncertainty quantification
% ------------------------------------------------------------------
% Function that computes the covariance-based uncertainty quantification
% and returns the corresponding uncertainty structure
    function [paramuq] = uncertainty(parfit)
        
        % Compute the jacobian of the signal fit with respect to parameter set
        subidx_pnonlin = 1:numel(parfit);
        subidx_plin = numel(parfit)+[1:numel(linfit)];
        
        % Augmented Jacobian
        Jnonlin = jacobianest(@(p)Amodel(p)*linfit,parfit);
        Jlin = Amodel(parfit);
        if illConditioned
            Jreg = [zeros(size(L,1),numel(parfit)) regparam_prev*L];
        else
            Jreg = [];
        end
        J = [Jnonlin, Jlin; Jreg];
        
        % Suppress warnings for a moment
        warning('off','MATLAB:nearlySingularMatrix'), warning('off','MATLAB:singularMatrix')
        lastwarn('');
        
        % Estimate variance on experimental signal
        sigma2 = std(ResidualsFcn(parfit)).^2;
        
        % Estimate the covariance matrix by means of the inverse of Fisher information matrix
        covmatrix = sigma2.*inv(J.'*J);
        
        % Detect if there was a 'nearly singular' warning...
        [~, warnId] = lastwarn;
        if strcmp(warnId,'MATLAB:nearlySingularMatrix') || strcmp(warnId,'MATLAB:singularMatrix')
            % ...and if there was, then use a pseudoinverse instead of inverse
            covmatrix = sigma2.*sparse(pinv(full(J.'*J)));
            lastwarn('');
        end
        warning('on','MATLAB:nearlySingularMatrix'), warning('on','MATLAB:singularMatrix')
        
        % Construct uncertainty quantification structure for fitted parameters
        paramuq = uqst('covariance',[parfit(:); linfit(:)],covmatrix,[lb(:); lbl(:)],[ub(:); ubl(:)]);
    end


% Constrained linear least squares solver (toolbox-free)
% ------------------------------------------------------------------
% Alternative solver to lsqlin.m (Optimization toolbox). Solves the linear
% problem argmin_x ||Ax - y||^2 in its quadratic programming form, i.e.
% argmin_x 1/2 xt(2AtA)x+(-2Aty)tx using the open-source MINQ package:
% W. Huyer and A. Neumaier, MINQ8 (2017)
% General Definite and Bound Constrained Indefinite Quadratic Programming
    function [x,eval,exitflag] = lsqlin_QP(A,y,lbl,ubl,~)
        
        % MINQ is sensitive to vector orientation
        ubl = ubl(:);
        lbl = lbl(:);
        
        % Get Hessian
        H = 2*(A.')*A;
        % Get linear term
        c = -2*A.'*y;
        
        % Unused settings
        gam = 0;
        print = 0;
        
        % Solve QP
        [x,eval,exitflag] = minq(gam,c,H,lbl,ubl,print);
    end

% Checks on the box constraints for all parameters
% ------------------------------------------------------------------
% This function does the bookkeeping on the box boundaries of the nonlinear
% and linear parameters to ensure they are valid and to set
    function checkbounds()
        % If passed empty, set unbounded box constraints
        if isempty(ubl)
            ubl = inf(Nlin,1);
        else
            ubl = ubl(:);
        end
        if isempty(lbl)
            lbl = -inf(Nlin,1);
        else
            lbl = lbl(:);
        end
        if isempty(ub)
            ub = inf(Nnonlin,1);
        else
            ub = ub(:);
        end
        if isempty(lb)
            lb = -inf(Nnonlin,1);
        else
            lb = lb(:);
        end
        % Check if the linear problem is constrained
        linearConstrained = ~all(isinf(lbl)) || ~all(isinf(ubl));
        % Check if the nonlinear problem is constrained
        nonLinearConstrained = ~all(isinf(lb)) || ~all(isinf(ub));
        % Check for non-negativity constraints on the linear solution
        nonNegativeOnly = all(lbl==0) && all(isinf(ubl));
        
        % Check that the boundaries are valid
        if any(ub<lb) || any(ubl<lbl)
            error('The upper bounds cannot be larger than the lower bounds.')
        end
        % Check that the non-linear start values are inside the box constraint
        if any(par0(:)>ub) || any(par0(:)<lb)
            error('The start values are outside of the specified bounds.')
        end
    end


% Input parsing
% ------------------------------------------------------------------
% This function parses the different input schemes
    function [ubl,lbl,lb,ub,options] = parseinputs(inputs)
        % Prepare empty containers
        [ubl,lbl,lb,ub] = deal([]);
        % Parse the varargin cell array
        optionstart = numel(inputs);
        for i=1:numel(inputs)
            if ischar(inputs{i})
                optionstart = i-1;
                break
            end
            switch i
                case 1
                    lb = inputs{i};
                case 2
                    ub = inputs{i};
                case 3
                    lbl = inputs{i};
                case 4
                    ubl = inputs{i};
            end
        end
        inputs(1:optionstart) = [];
        options = inputs;
    end


% Parsing and validation of options
% ------------------------------------------------------------------
% This function parses the name-value pairs or structures with options
% passes to the main function in the varargin. If the options pass, the
% default values are overwritten by the user-specified values.
    function parsevalidate(varargin)
        
        % Parse options
        [alphaOptThreshold_,RegOrder_,RegParam_,RegType_,nonLinSolver_,LinSolver_,...
            forcePenalty_,nonLinMaxIter_,nonLinTolFun_,LinMaxIter_,LinTolFun_,...
            multiStarts_] = parseoptions(varargin);
        
        if ~isempty(alphaOptThreshold_)
            validateattributes(alphaOptThreshold_,{'numeric'},{'scalar'})
            alphaOptThreshold = alphaOptThreshold_;
        end
        if ~isempty(RegOrder_)
            validateattributes(RegOrder_,{'numeric'},{'scalar','integer'})
            RegOrder = RegOrder_;
        end
        if ~isempty(RegParam_)
            if ~ischar(RegParam_)
                validateattributes(RegParam_,{'numeric'},{'scalar'})
                RegParam = RegParam_;
            else
                validateattributes(RegParam_,{'char'},{'nonempty'})
                RegParam = RegParam_;
            end
        end
        if ~isempty(RegType_)
            validateattributes(RegType_,{'char'},{'nonempty'})
            RegType = validatestring(RegType_,{'tikhonov','tv','huber','custom'});
        end
        if ~isempty(nonLinSolver_)
            validateattributes(nonLinSolver_,{'char'},{'nonempty'})
            nonLinSolver = validatestring(nonLinSolver_,{'lsqnonlin','lmlsqnonlin'});
            if strcmp(nonLinSolver,'lsqnonlin') && ~optimtoolbox_installed
                error('The ''lsqnonlin'' solver requies a valid license and installation of MATLAB''s Optimization Toolbox.')
            end
        end
        if ~isempty(LinSolver_)
            validateattributes(LinSolver_,{'char'},{'nonempty'})
            LinSolver = validatestring(LinSolver_,{'lsqlin','minq'});
            if strcmp(LinSolver,'lsqlin') && ~optimtoolbox_installed
                error('The ''lsqlin'' solver requies a valid license and installation of MATLAB''s Optimization Toolbox.')
            end
        end
        if ~isempty(forcePenalty_)
            validateattributes(forcePenalty_,{'logical'},{'nonempty'})
            forcePenalty = forcePenalty_;
        end
        if ~isempty(nonLinMaxIter_)
            validateattributes(nonLinMaxIter_,{'numeric'},{'scalar','nonnegative','nonempty'})
            nonLinMaxIter = nonLinMaxIter_;
        end
        if ~isempty(nonLinTolFun_)
            validateattributes(nonLinTolFun_,{'numeric'},{'scalar','nonnegative','nonempty'})
            nonLinTolFun = nonLinTolFun_;
        end
        if ~isempty(LinMaxIter_)
            validateattributes(LinMaxIter_,{'numeric'},{'scalar','nonnegative','nonempty'})
            LinMaxIter = LinMaxIter_;
        end
        if ~isempty(LinTolFun_)
            validateattributes(LinTolFun_,{'numeric'},{'scalar','nonnegative','nonempty'})
            LinTolFun = LinTolFun_;
        end
        if ~isempty(multiStarts_)
            validateattributes(multiStarts_,{'numeric'},{'scalar','nonnegative','integer'})
            multiStarts = multiStarts_;
        end
    end
end
