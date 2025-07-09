%% VolumeCut: Cut images along custom surfaces
% Copyright (C) 2017-2025 Luca Della Santina
%
%  This file is part of VolumeCut
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
% along with this program.  If not, see <http://www.gnu.org/licenses/>.
% This software is released under the terms of the GPL v3 software license
%
function skelMask = skel2mask(skel, rXYextra, rZextra, plotMask, saveMask)
%% Creates elipsoidal mask around the passed skeleton

szX          = skel.imgsize.width;
szY          = skel.imgsize.height;
szZ          = skel.imgsize.depth;
skelMask     = zeros(szX, szY, szZ, 'uint8');

for i=1:numel(skel.branches)
    for p=1:size(skel.branches(i).points,1)
        pX   = skel.branches(i).points(p,1);
        pY   = skel.branches(i).points(p,2);
        pZ   = skel.branches(i).points(p,3);
        pRxy = ceil((skel.branches(i).points(p,7)+rXYextra)/skel.calib.x);
        pRz  = ceil((skel.branches(i).points(p,7)+rZextra) /skel.calib.z);
        
        skelMask(max(pX-pRxy, 1) : min(pX+pRxy, szX),...
            max(pY-pRxy, 1) : min(pY+pRxy, szY),...
            max(pZ-pRz,  1) : min(pZ+pRz, szZ)) = 1;
    end
end

if exist('plotMask', 'var') && plotMask
    MIP = max(skelMask, [], 3);
    imagesc(MIP);
end
if exist('saveMask', 'var') && saveMask
    saveastiff(skelMask, [pwd filesep 'skelMask.tif']);
end
end