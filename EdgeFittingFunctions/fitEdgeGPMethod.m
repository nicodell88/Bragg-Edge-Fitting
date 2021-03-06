function [edgePos,sigma,TrFit,fitinfo,opts] = fitEdgeGPMethod(Tr,tof,opts)
%fitEdgeGPMethod fits a bragg-edge using the method presented in: 
%Hendriks, J., O'Dell, N., Wills, A., Tremsin, A., Wensrich, C., & Shinohara, T.
%(2020). Bayesian Non-parametric Bragg-edge Fitting for Neutron
%Transmission Strain Imaging. arXiv preprint arXiv:2004.11526.
%Pre-print available https://arxiv.org/pdf/2004.11526
%
% Inputs:
%   - Tr is a 1xN double containing the normalised transmisssion curve
%   for a single projection
%   - tof is an 1xN array of wave-lengths or time-of-flight.
%   - options is a structure containing
%       opts.a00    :   Initial guess
%       opts.b00    :   Initial guess
%       opts.a_hkl0 :   Initial guess
%       opts.b_hkl0 :   Initial guess
%       opts.sig_f  :   Squared-Exponential Kernel Hyperparameter, output variance
%       opts.l      :   Squared-Exponential Kernel Hyperparameter, lengthscale
%       opts.ns     :   Number of samples to use in MC step.
%       opts.nx      :   Number test points.
% Outputs:
%   - edgePos is the location of the braggEdge
%   - sigma is the estimated standard deviation
%   - TrFit is is the Bragg edge model evaluated at tof
%   - fitinfo contains additional information about the quality of the fit
%       fitinfo.lengthscale     : the lengthscale used
%       fitinfo.std_residual    : the standard deviaton of the residual
%       fitinfo.rms_residual    : the root mean square of the residual
%       fitinfo.fitqual         : an estimate of the fit quality given by
%                                   the radio sig_m / std(residual)
%       fitinfo.widthathalfheight: the peak width at half height
%
%See also fitEdges.

% Copyright (C) 2020 The University of Newcastle, Australia
% Authors:
%   Nicholas O'Dell <Nicholas.Odell@newcastle.edu.au>
%   Johannes Hendriks <Johannes.Hendriks@newcastle.edu.au>
% Last modified: 18/03/2020
% This program is licensed under GNU GPLv3, see LICENSE for more details.

%% least squares fitting options
optionsFit              = optimoptions('lsqcurvefit','Algorithm','levenberg-marquardt');
optionsFit.Algorithm    = 'Levenberg-Marquardt';
optionsFit.Jacobian     = 'off';
optionsFit.Display      = 'off';
%% Initial guess
a00     = 0.5;
b00     = 0.5;
a_hkl0  = 0.5;
b_hkl0  = 0.5;
sig_f   = 1;    
l       = 1e-4;     % GP lengthscale
ns      = 3000;     % number of samples to draw to compute variance
nx      = 2500;     % number of points to predict at
useInterp = true;   % uses an interpolation procedure to reduce the size of matrix inversion
optimiseHP = 'none';  % if true optimises the lengthscale for each Transmission spectra

if isfield(opts,'a00')
    a00 = opts.a00;
end
if isfield(opts,'b00')
    b00 = opts.b00;
end
if isfield(opts,'a_hkl0')
    a_hkl0 = opts.a_hkl0;
end
if isfield(opts,'b_hkl0')
    b_hkl0 = opts.b_hkl0;
end

%GP
if isfield(opts,'sig_f')
    sig_f = opts.sig_f;
end
if isfield(opts,'l')
    l = opts.l;
end
if isfield(opts,'ns')
    ns = opts.ns;
end
if isfield(opts,'nx')
    nx = opts.nx;
end
if isfield(opts,'GPscheme')
   GPscheme = opts.GPscheme; 
   if strcmpi(GPscheme,'interp')
      useInterp = true; 
   elseif strcmpi(GPscheme,'full')
       useInterp = false;
   elseif strcmpi(GPscheme,'hilbertspace')
       error('Should not have gotten here')
   else
       error('Invalide GP scheme specified, should be one of full, interp, or hilbertspace')
   end
end

if isfield(opts,'optimiseHP')
    optimiseHP = opts.optimiseHP;
end

if isfield(opts,'covfunc')
    covfunc = opts.covfunc;
    if ~strcmpi(covfunc,'se')
        error('Full and interp GP scheme are only implemented for squared-exponential covariance function')
    end
end


%% Fit edge
try
%% 1) fit to the far right of the edge where B = 1, so only fit exp([-(a0+b0.*t)])
fit1 = @(p,x) exp(-(p(1) + p(2).*x));
[p,~,~,~,~,~,~] = lsqcurvefit(fit1,[a00;b00],tof(opts.endIdx(1):opts.endIdx(2)),Tr(opts.endIdx(1):opts.endIdx(2)),[],[],optionsFit);
a0 = p(1); b0 = p(2);
%% 2) fit to the far left of the edge where B = 0;
fit2 = @(p,x) exp(-(a0 + b0.*x)).*exp(-(p(1)+p(2).*x));
[p,~,~,~,~,~,~] = lsqcurvefit(fit2,[a_hkl0;b_hkl0],tof(opts.startIdx(1):opts.startIdx(2)),Tr(opts.startIdx(1):opts.startIdx(2)),[],[],optionsFit);
a_hkl = p(1); b_hkl = p(2);

%% 3) fit the transition function as a GP
g1 = @(x) exp(-(a0 + b0.*x)).*exp(-(a_hkl+b_hkl.*x));
g2 = @(x) exp(-(a0 + b0.*x));

y = (Tr - g1(tof)).';
x = tof.';
ny = length(tof);
sig_m = std([Tr(opts.endIdx(1):opts.endIdx(2)) - g2(tof(opts.endIdx(1):opts.endIdx(2))),...
    Tr(opts.startIdx(1):opts.startIdx(2))-g1(tof(opts.startIdx(1):opts.startIdx(2)))]);
% Hyperparameters
if strcmpi(optimiseHP,'all')
    fminopts = optimoptions('fminunc','SpecifyObjectiveGradient',true,'display','none');
    nlM = @(l) LogMarginalSE(l,x,y,g1(x),g2(x),sig_m);
    logl = fminunc(nlM,0,fminopts);
    l = max((tof(2)-tof(1))*10,exp(logl));      % ensure a sensible result
end

%GP
if useInterp
   nh = nx;
   nx = length(tof); 
   xt_interp = linspace(tof(opts.startIdx(2)),tof(opts.endIdx(1)),nh)';
end

xt = linspace(tof(opts.startIdx(2)),tof(opts.endIdx(1)),nx)';

% scale input data across range [0,1] for calcultion of covariance matrices
[xsc,xrange] = scaleInput(x);
xtsc = (xt - xrange(1))/(xrange(2)-xrange(1));

K = sig_f^2 * exp(-0.5*(xsc - xsc').^2/l^2) .* ((g2(x) - g1(x)) .*(g2(x') - g1(x')));
Kyy = K + eye(ny)*sig_m^2;
Kfy = sig_f^2 * exp(-0.5*(xtsc - xsc').^2/l^2).*(g2(x') - g1(x'));
dKfy = -(xtsc - xsc')/l^2 .* Kfy;
ddKff = sig_f^2 * (1 - (xtsc-xtsc').^2/l^2)/l^2 .* exp(-0.5*(xtsc - xtsc').^2/l^2);
Kfyp = sig_f^2 * exp(-0.5*(xsc - xsc').^2/l^2).*(g2(x') - g1(x'));
 
C = chol(Kyy,'upper');

festp = Kfyp*(C\(C.'\y));           % estimated edge shape

g = dKfy*(C\(C.'\y));

alpha = (C.'\dKfy');
V = ddKff- alpha'*alpha;



[sV, p] = chol(V+1e-10*eye(size(V)),'upper');
if p
    warning('was not about to use chol')
    sV = sqrtm(V+1e-10*eye(size(V)));
    sg = g + sV*randn(nx,ns);     % notice this one is not tranposed (for good reason)
else
    sg = g + sV.'*randn(nx,ns);
end

if useInterp
    g_interp = interp1(xt,g,xt_interp,'v5cubic');
    sg_interp = interp1(xt,sg,xt_interp,'v5cubic');
    [~,Is] = max([g_interp sg_interp]);
    sLams = xt_interp(Is);
else
    [~,Is] = max([g sg]);
    sLams = xt(Is);
end

catch e
    fprintf(1,'Error during fitting process. The message was:\n%s',e.message);
    edgePos = NaN;
    sigma = NaN;
    fitinfo.lengthscale = NaN;                            
    fitinfo.std_residual = NaN;               
    fitinfo.rms_residual = NaN;   
    fitinfo.fitqual = NaN;
    fitinfo.widthathalfheight = NaN;
    return 
end

%% Collect Results
edgePos = mean(sLams);
sigma = std(sLams);
TrFit = exp(-a0-b0*tof).*...
	(exp(-a_hkl-b_hkl*tof) + (1-exp(-a_hkl - b_hkl*tof)) .*festp.');

% check fit quality
fitqual = sig_m/std(Tr-TrFit);
if fitqual > 2
    warning('The ratio of sig_m/std(residual) is high ( %s), indicating that the data may have been overfit. Consider increasing the lengthscale',num2str(fitqual))
end
if fitqual < 0.5
    warning('The ratio of sig_m/std(residual) is low ( %s), indicating that the data may have been overfit. Consider increasing the lengthscale',num2str(fitqual))
end


fitinfo.lengthscale = l;                            % store the lengthscale used
fitinfo.std_residual = std(Tr-TrFit);               % standard deviation of the residual
fitinfo.rms_residual = sqrt(mean((Tr-TrFit).^2));   % root mean square of hte residual
fitinfo.fitqual = fitqual;
half_height = max(g)/2;
[xi,~] = polyxpoly(xt,g,[xt(1);xt(end)],[half_height;half_height]);
if length(xi) == 2
    widthathalfheight = max(xi) - min(xi);
else
    widthathalfheight = nan;
end
fitinfo.widthathalfheight = widthathalfheight;
    



end