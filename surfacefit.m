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

function [S, Sfit] = surfacefit(x,y,z, gx, gy)
% Fits a surface to points [x,y,z] and returns the fitted meshgrid

Sfit = fit([x, y], z, 'thinplateinterp');
[X,Y] = meshgrid(gx, gy);
S = feval(Sfit, X, Y);
end