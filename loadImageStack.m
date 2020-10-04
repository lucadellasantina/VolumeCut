%% VolumeCut: Cut images along custom surfaces
% Copyright (C) 2017,2018 Luca Della Santina
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
function [I, Isize, Ires] = loadImageStack(PathName, FileName)
    % Read the image size and resolution from file
    tmpImInfo = imfinfo([PathName FileName]);
    tmpImSizeZ = numel(tmpImInfo);
    tmpImSizeX = tmpImInfo.Width;
    tmpImSizeY = tmpImInfo.Height;
    Isize = [tmpImSizeX, tmpImSizeY, tmpImSizeZ];
    
    % Read image resolution data
    try
        tmpXYres = 1/tmpImInfo(1).XResolution;
        if contains(tmpImInfo(1).ImageDescription, 'spacing=')
            tmpPos = strfind(tmpImInfo(1).ImageDescription,'spacing=');
            tmpZres = tmpImInfo(1).ImageDescription(tmpPos+8:end);
            tmpZres = regexp(tmpZres,'\n','split');
            tmpZres = str2double(tmpZres{1});
        else
            tmpZres = 0.3; % otherwise use default value
        end
        Ires = [tmpXYres, tmpXYres, tmpZres];
    catch
        Ires = [1,1,1];
    end
    
    % Load the image data into matlab
    fprintf('Loading image stack... ');
    I = tiffreadVolume([PathName FileName]);
    I = uint8(I);
    fprintf('DONE\n');
end