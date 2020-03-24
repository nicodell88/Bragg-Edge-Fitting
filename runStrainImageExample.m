%
% runStrainImageExample.m 
%
% Copyright (C) 2020 The University of Newcastle, Australia
% Authors:
%   Nicholas O'Dell <Nicholas.Odell@newcastle.edu.au>
% Last modified: 05/03/2020
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <https://www.gnu.org/licenses/>.

restoredefaultpath
clc
clear
close all



%% House Keeping
tickFontSize = 12;
set(0,'defaultAxesFontsize',tickFontSize)
set(0,'defaultAxesLabelFontsize',18/tickFontSize)
set(0,'defaultAxesTitleFontsize',25/tickFontSize)
set(0,'defaultTextInterpreter','latex')
set(0,'defaultLegendInterpreter', 'latex')
set(0,'defaultAxesTickLabelInterpreter', 'latex')
set(0, 'defaultLineLinewidth',2)
set(0,'defaultFigureColor','w')


%% Options
opts.ObFile     = '/Users/megatron/Dropbox/Strain Tomography 2020/J-PARC 2020 Working Folder/Data/OpenBeam/OpenBeamImg__proj001_idx.mat';   %Open Beam File location
opts.ProjFile   = '/Users/megatron/Dropbox/Strain Tomography 2020/J-PARC 2020 Working Folder/Data/SteelCube/SteelCube__proj005_idx.mat';    %Projection File location
% opts.ProjFile   = './Data/SteelCube/SteelCube__proj051_idx.mat';    %Projection File location
% opts.ProjFile = '/Users/megatron/Dropbox/Strain Tomography 2020/J-PARC 2020 Working Folder/Data/SteelCube/SteelCube__proj060_idx.mat'

OB      = load(opts.ObFile);    %Load open beam
Proj    = load(opts.ProjFile);  %Load projection
%%
% opts.supplyMask = 'supply';
% opts.supplyMask = 'gui';
opts.supplyMask = 'auto';

opts.rangeRight = [0.0190 0.0198];  %Range for averaging on right of edge for guessing mask
opts.rangeLeft  = [0.0175 0.0185];  %Range for averaging on left of edge for guessing mask
opts.d0         =  0.018821361897845;           %Unstrained tof/wl
opts.nPix       = 20;               %Macro-pixel size
opts.Thresh     = 0.05;             %More than 80% of a macro-pixel must be within the mask before a bragg edge will be fit to it
opts.maskThresh = 0.02;             %Threshold edge height for mask
% Insert Bragg Edge Fitting Options here
opts.BraggOpts.startRange = [0.0175 0.0180];  %Fitting left side of edge
opts.BraggOpts.endRange   = [0.019 0.0195];   %Fitting right side of edge
opts.BraggOpts.method     = 'attenuation';             %Fitting algorithm
opts.BraggOpts.plot       = false;             %plot results along the way
opts.BraggOpts.a00    = 0.5;          %Initial guess for a0
opts.BraggOpts.b00    = 0.5;          %Initial guess for b0
opts.BraggOpts.a_hkl0 = 0.5;          %Initial guess for a_hkl
opts.BraggOpts.b_hkl0 = 0.5;          %Initial guess for b_hkl
opts.BraggOpts.sig_f  = 1;            %Squared-Exponential Kernel Hyperparameter, output variance
opts.BraggOpts.l      = 1e-4;         %Squared-Exponential Kernel Hyperparameter, lengthscale
opts.BraggOpts.ns     = 3000;         %Number of MC samples used to estimate bragg-edge location and variance.
opts.BraggOpts.n      = 2500;         %Number of points to sample the Bragg-Edge function.

%% Calculate Strain Image
opts.figNum = 1;
[StrainImage,SigmaImage,opts]= makeStrainImage(OB,Proj,opts);
%% Plot Strain Image
plotStrainImage(StrainImage,SigmaImage,opts)
%% Save Figure
msg = sprintf('strainImage_%s',datestr(now,'yy_mm_dd_hh_MM_ss'));
saveas(gcf,msg,'png')






