function [Phi,Phi_T,SLambda,lambdas, dPhi_T] = hilbert_approxSE(l,sig_f,m,L,x_test,x_obs)
%   l: length scales
%   sig_f: prior std
%   m: number of basis functions
%   x_test: test points to estimate at
%   x_obs: observation points
[x_obs,xrange] = scaleInput(x_obs);
x_test = (x_test - xrange(1))/(xrange(2)-xrange(1));

lambdas = pi * [0:m-1]/2/L;
Phi =  1/sqrt(L)*sin(bsxfun(@times,x_obs+L,lambdas));
Phi_T = 1/sqrt(L)*sin(bsxfun(@times,x_test+L,lambdas));
dPhi_T = lambdas .* cos(bsxfun(@times,x_test+L,lambdas))/sqrt(L);
SLambda = sig_f^2*l*sqrt(2*pi)*exp(-lambdas.^2*l^2/2); 

end

