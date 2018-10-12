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
%
% *Change log*
%
% _*Version 2.2*            created on 2018-10-11 by Luca Della Santina_
%
%  + 3D Rendering of reference points and fitted surfaces 
%  + MIP projections on the walls of the 3D scene
%
% _*Version 2.1*            created on 2018-10-09 by Luca Della Santina_
%
%  + Correct rendering of anisotropic voxels
%  + New cut modes: Cut in Two/Three/Four parts
%
% _*Version 2.0*            created on 2018-10-07 by Luca Della Santina_
%
%  + Added Graphical interface using appdesigner
%  + Packaged into a matlab App
%  + Render the source and cut volumes using MATLAB's 3D renderer
%  + Added custom smoothing of interpolated surfaces
%  + Added custom Z offset for each individual surface
%  + Added project website
%
% _*Version 1.5*            created on 2018-09-19 by Luca Della Santina_
%
%  + Offset1 and offset2 can nowbe appliedto all cutting modes
%  + Both masks used to slice the volume are saved as -part1mask -part2mask
%
% _*Version 1.4.1*            created on 2017-11-29 by Luca Della Santina_
%
%  + Fixed bug in applying offset1 and offset2 to calculade midle plane
%
% _*Version 1.4*             created on 2017-11-20 by Luca Della Santina_
%
%  + Allows to cut at a custom distance from references planes when mode=1
%  + Added progress bars and verbose output for all the processing steps
%  + Added copyright statement
%  % Exmplained the three cutting modes more clearly
%
% _*Version 1.3*             created on 2017-10-01 by Luca Della Santina_
%
%  % Fixed double extension inserted into filenames, i.e. ".tif-part1.tif"
%  + Added new modes of slicing when using 2 set of coordinates
%
%    Plane #1<->middle<->#2
%    Part1: From beginning of plane #1 to halfway between planes
%    Part2: From halfway between planes to plane #2
%
%    Stack Start<->middle<->End mode:
%    Part1: From beginning of volume to halfway between planes
%    Part2: From halfway between planes to end of volume
%
%    Inside/Outside planes mode:
%    Part1: volume outside the planes delimited by the coordinate sets
%    Part2: volume inside the planes delimited by the coordinate sets
%
% _*Version 1.2.1*             created on 2017-09-07 by Luca Della Santina_
%
%  + Reformatted documentation using proper MATLAB markup format
%
% _*Version 1.2*               created on 2017-09-07 by Luca Della Santina_
%
%  + When cutting with 2 set of reference points output stacks are:
%    "-part1.tif" voxels between top and middle surfaces (g1<->g3)
%    "-part2.tif" voxels between middle and bottom surfaces (g3<->g2)
%  + Allow Surface 1 and Surface 2 to be loaded opposite than expected
%
% _*Version 1.1*               created on 2017-09-01 by Luca Della Santina_
%
%  % bug fixed the file selector for reference points
%
% _*Version 1.0*               created on 2017-09-01 by Luca Della Santina_
%