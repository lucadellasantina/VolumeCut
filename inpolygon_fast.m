%% VolumeCut: Cut images along custom surfaces
% Copyright (C) 2017-2025 Luca Della Santina
%
%  This file is part of VolumeCut
%
%  ObjectFinder is free software: you can redistribute it and/or modify
%  it under the terms of the GNU General Public License as published by
%  the Free Software Foundation, either version 3 of the License, or
%  (at your option) any later version.
%
%  This program is distributed in the hope that it will be useful,
%  but WITHOUT ANY WARRANTY; without even the implied warranty of
%  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%  GNU General Public License for more details.
%
%  You should have received a copy of the GNU General Public License
%  along with this program.  If not, see <https://www.gnu.org/licenses/>.
%

%% Wrapper to use inpoly2 with the same syntax as MATLAB's inpolygon
% https://github.com/dengwirda/inpoly
function in = inpolygon_fast(x,y,xv,yv,varargin) 

    in = reshape(inpoly2([x(:) y(:)],[xv(:) yv(:)],varargin{:}),size(x));
end