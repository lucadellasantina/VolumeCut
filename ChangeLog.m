%% VolumeCut: Cut images along custom surfaces
% Copyright (C) 2017-2019 Luca Della Santina
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
% _*Version 6.0*            created on 2020-09-19 by Luca Della Santina_ 
%
%  + MATLAB R2020b required
%  + New fitting algorithm near 15X faster, requires curve fitting toolbox
%  + New reference point drawing near 2X faster
%  + loadImageStack uses memory-efficient tiffreadVolume()
%  + New slicing algorithm, near 4X faster
%  + Single instance of the app allowed
%
% _*Version 5.2*            created on 2020-09-19 by Luca Della Santina_ 
%
%  + Removed Refine tool
%  + Fixed misalignment of sensitive point on crossbar
%  + Improved redrawing speed by passing only current frame to redraw
%  + Selecting a reference point on-screen selects corresponding on table
%
% _*Version 5.1*            created on 2020-09-15 by Luca Della Santina_ 
%
%  + Optional saving of different cut parts
%  + Delete objects from graphical editor
%  + Renamed loadImage.m to loadImageStack.m to disambiguate among apps
%
% _*Version 5.0*            created on 2020-09-14 by Luca Della Santina_ 
%
%  + Visual editor for fiducial cut points
%  + Removed Log and Lamp component at the bottom of UI
%  + Added progress dialogs for all operations
%
% _*Version 4.9*            created on 2020-08-07 by Luca Della Santina_ 
%
%  + Batch recursion into all subfolder levels
%
% _*Version 4.8*            created on 2020-04-13 by Luca Della Santina_ 
%
%  + Version in app title
%  + New Batch operation: Keep only largest object
%
% _*Version 4.7*            created on 2020-01-31 by Luca Della Santina_ 
%
%  + Support for 2D binary masks
%
% _*Version 4.5*            created on 2019-12-18 by Luca Della Santina_ 
%
%  + New Automation option to intensity histograms within masked volume
%  + App now starts centered within the screen
%  + During batch processing a cancellable progressbar informs of status
%
% _*Version 4.5*            created on 2019-11-20 by Luca Della Santina_ 
%
%  + New Automation option to calculate voxel "Density by depth" percentage
%
% _*Version 4.4*            created on 2019-01-26 by Luca Della Santina_ 
%
%  + New Automation tab allows batch processing of masks
%
% _*Version 4.3*            created on 2019-01-23 by Luca Della Santina_ 
%
%  + Fixed bug causing missing interactivity with 3D plots
%
%_*Version 4.2*            created on 2019-01-16 by Luca Della Santina_
%
%  + Fixed error of Spots not recognized when only one set is loaded
%  + Fixed error of 3D plot not visualized due to mispositioned hold(on)
%
% _*Version 4.1*            created on 2019-01-09 by Luca Della Santina_
%
%  + Inverted x y coordinates when importing skeletons from SNT .traces
%
% _*Version 4.0*            created on 2019-01-06 by Luca Della Santina_
%
%  + Skeleton tab allows visualization of digital skeletons
%  + Support for skeletons created with ImageJ's Simple Neurite Tracer
%  + Create binary mask from skeleton according to skeleton's radius
%  + Reflect skeletons along the cardinal axis of the containing volume
%  + Recalibrate and Rescale skeleton
%  + Display skeleton statistics
%
% _*Version 3.3*            created on 2019-01-02 by Luca Della Santina_
%
% Changed imclose and imfill to operate in 3D by iterating each plane in 2D
%
% _*Version 3.0*            created on 2018-10-16 by Luca Della Santina_
%
%  + New Mask visualization and math functions
%  + Scroll wheel in mask tab moves current Z plane visualized
%  + Logical operations between masks: unite, exclude, subtract, intersect
%  + Operations on mask: Revert to original, trace edges, invert
%
% _*Version 2.3*            created on 2018-10-12 by Luca Della Santina_
%
%  + Keep track on screen of file names of image and cut reference points 
%  + Automatically change matlab current working directory to Image file's
%  + Allows reuse of calculated surfaces to cut additional image stacks
%  + Units of measurements can be switched from pixels to microns
%  + Render volume generated a new plot every time is pressed
%  + Render window's title matches the type of rendered content(e.g Cut I)
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
