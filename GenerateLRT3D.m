function [Tr,wl,tof,entry,exit,L,nhat,yInds,nSegs] = GenerateLRT3D(ProjIdx,ProjFileSpec,OBfile,stlFile,stlUnit,mask_all,rODn_all,Rno_all,nPix,nanThresh,varargin)
%GenerateLRT2D generates the geometric properties of the LRT measurement,
%i.e., entry and exit of beam into sample, irradiated length, beam
%direction. Each of these will be associated with downsampled time of
%flight data. After calling this function edges can be fit to the time of
%flight data.
%[Tr,wl,entry,exit,L,nhat,yInds,nSegs] = GenerateLRT2D(ProjIdx,ProjFileSpec,OBfile,rBOo,mask_all,rODn_all,Rno_all,rowRange,nCol)
%
%   Inputs: 
%       - ProjIdx is a vector of indicies indicating which files will be
%           processed, e.g., ProjIdx = 1:5;
%       - ProjFileSpec is a character-array or string defining the file
%           name specifier for the .mat files containing the time of flight
%           data for each projection. This MUST contain the type specifier
%           for the projection number. E.g.,
%           ProjFileSpec = "/path/to/Sample2018_proj_%03d.mat", I.e, if
%           ProjIdx = 1:5;, the following files will be processed;
%           /path/to/Sample2018_proj_001.mat, ... ,
%           /path/to/Sample2018_proj_005.mat.
%       -   OBfile is a character-array or string containing the absolute
%           or relative path to the open beam .mat file.
%       - stlFile is a char-array or string containing a relative or absolute
%           filepath to the stl file of the sample.
%       - stlUnits is a char-array or string which indicates the unit of the
%           CAD model, must be {'mm','m','inch'}
%       - mask_all is a 512-by-512-by-M matrix of logicals, each column of
%           mask_all is a bit-mask indicating which pixel columns are
%           behind the sample.
%       - rODn_all is a 3-by-M matrix, each column is a 2-by-1 vector
%           defining the sample origin (O) with respect to the centre of
%           the detector (D) in beam coordinates {n}, for each projection.
%       - Rno_all is a 3-by-3-by-M array, where each page is a rotation matrix defining the rotation between beam
%           coordinates {n} and sample coordiantes {o}, such that
%           Rno.'*rABn would rotate the vector rABn from beam coordinates
%           {n} to sample coordinates {o}, producing rABo. Each page is
%           associated with a projection.
%       - nPix specifies to use nPix-by-nPix pixels for
%           downsampling.
%       - nanThresh specifies the fraction of pixels that must be within
%           the mask for the measurement to be counted.
%       Two optional inputs:
%       - trig_delay delay in seconds between receiving the trigger signal
%           and TODO. Default is 1.243e-5 [seconds] (JPARC MLF, beam line 22 RADEN)
%       - source_dist is the distance of the sample from the target.
%           Defualt is 17.7971 [metres] 
%   Oututs:
%       - Tr is a cell array, each cell contains a matrix, of which the
%           rows correspond to measurements and the columns correspond to
%           time-of-flight.
%       - wl is a N-by-1 vector containing the wavelength associated with
%           each time-of-flight;
%       - tof is a N-by-1 vector containing the recorded spectra. - entry
%           is a cell array where each cell contains, a G-by-H matrix defining
%           where each beam enters the sample, where H is the number of
%           measurements and G is two-times the maximum number of entrances
%           into the sample, H is the number of measurements. For convex
%           polygons G=2, but for non-convex polygons, annular shapes or
%           multi-body samples G may be greater. Where G is greater than 2
%           - columns associated with measurements that correspond to rays
%           that only enter the sample once are padded with NaNs.
%       - exit is also a cell array, each cell contains a G-by-H matrix,
%           defning where each beam leaves the sample. See above.
%       - nhat is a cell array, each cell containing a set of unit vectors
%           defining the beam direction for each measurement.
%       - L is a cell array, each cell containing an H-by-1 vector, where
%           each element is the total irradiated length of each measurement.
%       - yInds is a cell array, each cell contains a vector of indicies
%           indicating which measurements were valid, i.e., if a ray does not
%           intersect the sample at all, or intersects the sample an odd number
%           of times the measurement is discarded.
%       - nSegs is cell array where each cell contains a H-by-1 vector indicating how many disjoint line
%           segments make up the ray path.
%
%See also downsample3D_LRT, find_intersects_3D.


% Copyright (C) 2020 The University of Newcastle, Australia
% Authors:
%   Nicholas O'Dell <Nicholas.Odell@newcastle.edu.au>
% Last modified: 15/07/2020
% This program is licensed under GNU GPLv3, see LICENSE for more details.
TBdir = fileparts(mfilename('fullpath'));
addpath(fullfile(TBdir,'LRT_processing'));
addpath(genpath(fullfile(TBdir,'utility_functions')))
%%
np = length(ProjIdx);
%%
p = inputParser;
%% Inputs
addRequired(p,'ProjIdx',...
    @(x) validateattributes(x,{'numeric'},{'vector','nonnegative','increasing','integer'}));

addRequired(p,'ProjFileSpec',...
    @(x) validateattributes(x,{'string','char'},{}));

addRequired(p,'OBfile',...
    @(x) validateattributes(x,{'string','char'},{}));

addRequired(p,'stlFile',...
    @(x) validateattributes(x,{'string','char'},{}));

addRequired(p,'stlUnit',@(x) any(validatestring(x,{'mm','m','inch'})));

addRequired(p,'mask_all',...
    @(x) validateattributes(x,{'numeric'},{'size',[512,512,np]}));

addRequired(p,'rODn_all',...
    @(x) validateattributes(x,{'numeric'},{'size',[3,np]}));

addRequired(p,'Rno_all',...
    @(x) validateattributes(x,{'numeric'},{'size',[3,3,np]}));

addRequired(p,'nPix',...
    @(x) validateattributes(x,{'numeric'},{'positive','integer','<=',512}));

addRequired(p,'nanThresh',...
    @(x) validateattributes(x,{'numeric'},{'scalar','positive','<=',1}));

addOptional(p,'trig_delay',1.243e-5,...
    @(x) validateattributes(x,{'numeric'},{'scalar','positive'}));

addOptional(p,'source_dist',17.7971,...
    @(x) validateattributes(x,{'numeric'},{'scalar','positive'}));

%Parse
%      (ProjIdx,ProjFileSpec,OBfile,stlFile,stlUnit,mask_all,rODn_all,Rno_all,nPix,nanThresh,varargin)
parse(p,ProjIdx,ProjFileSpec,OBfile,stlFile,stlUnit,mask_all,rODn_all,Rno_all,nPix,nanThresh,varargin{:});

%% Check Open Beam file exsits
FailMessage = sprintf('The matlab data file ''%s'' does not exist.',p.Results.OBfile);
assert(2==exist(p.Results.OBfile,'file'),FailMessage);
%% Check STL exists
FailMessage = sprintf('The STL file ''%s'' does not exist.',p.Results.stlFile);
assert(2==exist(p.Results.stlFile,'file'),FailMessage);
%% Check Projection file exists
for i = 1:np
    msg = sprintf(p.Results.ProjFileSpec,p.Results.ProjIdx(i));
    FailMessage = sprintf('The matlab data file ''%s'' does not exist.\nMake sure ''ProjFileSpec'' contains the correct type-specifier for the projection number. I.e., ''%%03d''.',msg);
    assert(2==exist(msg,'file'),FailMessage);
end
%% Process Open Beam
OB_unpro = load(p.Results.OBfile);
OB_pro = ProcessMat(OB_unpro,p.Results.trig_delay,p.Results.source_dist);
%% Load STL

%% Conversion factor
switch lower(p.Results.stlUnit)
    case 'm'
        convert2m = 1;
    case 'mm'
        convert2m = 1e-3;
    case 'inch'
        convert2m = 25.4e-3;
end
%% read STL
[sample.F,sample.V,sample.N] = stlread(p.Results.stlFile);
sample.V = sample.V*convert2m;
cx = mean(reshape(sample.V(sample.F.',1),3,[]));
cy = mean(reshape(sample.V(sample.F.',2),3,[]));
cz = mean(reshape(sample.V(sample.F.',3),3,[]));
sample.C = [cx.',cy.',cz.'];
%remember to convert dimensions

%% Intialise outputs
Tr = cell(np,1);
entry = cell(np,1);
exit = cell(np,1);
nhat = cell(np,1);
L = cell(np,1);
yInds = cell(np,1);
nSegs = cell(np,1);
wl = OB_pro.lambda;
tof = OB_unpro.tof;
%% Options
opts.nPix = p.Results.nPix;
opts.nanThresh = p.Results.nanThresh;
%% Loop over projections
wh      = waitbar(0,'Downsampling', ...
    'Name', '', ...
    'CreateCancelBtn', 'setappdata(gcbf,''cancelling'',1)');
try
    for i=1:np
        %Check to see if user cancelled operation
        if getappdata(wh,'cancelling') % Check if waitbar cancel button clicked
            delete(wh);
            error('User cancelled operation.')
        end
        
        % Load and process projection
        msg = sprintf('Loading projection %d/%d',i,np);
        waitbar(i/np,wh,msg)
        msg = sprintf(p.Results.ProjFileSpec,p.Results.ProjIdx(i));
        Proj_unpro = load(msg);
        Proj_pro = ProcessMat(Proj_unpro,p.Results.trig_delay,p.Results.source_dist);
        % Downsample Projection
        msg = sprintf('Downsampling projection %d/%d',i,np);
        waitbar(i/np,wh,msg)
        [Tr{i},wl,entry{i},exit{i},L{i},nhat{i},yInds{i},nSegs{i}] = ...
            downSample3D_LRT(OB_pro,Proj_pro,sample,p.Results.mask_all(:,:,i),p.Results.rODn_all(:,i),p.Results.Rno_all(:,:,i),opts);
    end
catch me
    delete(wh);
    rethrow(me);
end
%% Prepare a data structure for output.
processed.projs = p.Results.ProjIdx;
processed.Tr = Tr;
processed.wl = wl;
processed.entry = entry;
processed.exit = exit;
processed.nhat = nhat;
processed.L = L;
processed.yInds = yInds;
processed.nsegs = nSegs;
processed.nCol = p.Results.nPix;
%% Save the results
save(['projs_' num2str(min(p.Results.ProjIdx)) '_to_' num2str(max(p.Results.ProjIdx)) '_preprocessed_average_over_' num2str(p.Results.nPix) '-by-' num2str(p.Results.nPix)],'processed')
end