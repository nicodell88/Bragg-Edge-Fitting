%
% runAlignment.m
%
% Copyright (C) 2020 The University of Newcastle, Australia
% Authors:
%   Nicholas O'Dell <Nicholas.Odell@newcastle.edu.au>
% Last modified: 25/01/2020
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
clear all
close all
%% House Keeping
tickFontSize = 12;
set(0,'defaultAxesFontsize',tickFontSize)
set(0,'defaultAxesLabelFontsize',18/tickFontSize)
set(0,'defaultAxesTitleFontsize',25/tickFontSize)
set(0,'defaultTextInterpreter','latex')
set(0,'defaultLegendInterpreter', 'latex')
set(0,'defaultAxesTickLabelInterpreter', 'latex')
set(0,'defaultLineLinewidth',2)
set(0,'defaultFigureColor','w')
%%
addpath(genpath('../utility_functions'))
%% Options (these should all be set using input parser)
opts.sigma = 3e-4;      %Length scale for scan matching (m)
opts.plotGrid = [3 4];   %Will produce an MxN grid of subplots for plotting the optimisation progress
opts.Nnodes = 1500; %Nominal number of nodes in FE mesh
opts.Npix      = 1500; %number of pixels after downsampling
opts.thresh = 0.05; %Threshold for deciding whether a pixel is behind the sample or not
%% Edges
edges = load('edges_new.mat'); %Load the edges file saved after running getEdges.
%% Known Rotations
T = readtable('angles_revised.xlsx');
nProj       = 55;
PhiDeg      = T.Chi_deg_(1:nProj);
thetaDeg    = T.Phi_deg_(1:nProj);

Rsh = zeros(3,3,nProj);
for i =1:nProj
    Rsh(:,:,i) = stage_rotation(deg2rad(thetaDeg(i)),deg2rad(PhiDeg(i)));
end
rHSs = zeros(3,nProj);
%% Initial Conditions (to be optimised)
x0.Theta_ns     = [0 0 0].';    %[radians] - Defines Rns1, coordinate transform between the beam coordinates and the stage coordinates.
x0.Theta_ho     = [0 0 0].';    %[radians] - Defines Rso1, the rotation between sample coordinates and the stage coordinates
x0.rSDn         = [0 0].';      %[m] - the vector to S (stage reference) from D (centre of detector) in beam coordinates (n). (only y z... x is not observable from the detector).
x0.rOHh         = [0 0 0].';    %[m] - the vector to O (origin of sample coordinate system) from H (reference point on sample holder) expressed sample holder coordinates (h).
%% STL Model
STLmodel.file = 'cubePlugCorrected.stl'; %Path and filename of sample STL
STLmodel.units = 'mm'; %Units used in the STL, must be either 'mm', 'm', or 'inch' otherwise perform manual conversion to one of these.
%% Inputs to alignment procedure should be limited to
% edge file
% known rotations and translations.
% opts
%   sigma
%   stl things
%   initial Thetas and offsets
% Thresholds for 
%% Everything below here should go into a function
%% Call to function
alignmentProcedure(STLmodel.file,STLmodel.units,rHSs,Rsh,edges.edges(:,:,1:55))
return
%% Import Geometry
model = createpde(1);
importGeometry(model,STLmodel.file);
mesh = generateMesh(model,'Hmax',3.8);
%% Import STL
[sample.F,sample.V] = stlread(STLmodel.file);





