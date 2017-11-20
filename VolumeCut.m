%% VolumeCut: Cut images along custom surfaces
% |Copyright 2017, Luca Della Santina|
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
% |*VolumeCut cuts a three dimensional image stack along an arbitrary
% surface. The surface is defined by the user that specifies reference
% point coordinates in a MATLAB matrix. The program then fits a surface 
% passing through all reference points and uses the fitted surface to split
% the image stack in two halves.*|
%
% Each row of the reference points' matrix is the [X,Y,Z] coordinates of 
% each point on the cutting surface. VolumeCut will fit the missing points. 
%
% The program performs the following main operations:
%
% # Ask user to load the TIF image stack file from disk 
% # Ask user to load matrix containing coordinates of reference cut points
% # A surface if fitted across all reference points
% # If there are two reference matrixes, the average surface is computed
% # The image volume is cut in hald along the plane
% # Image halves are saved with suffixes "-Part1.tif" and "-Part2.tif"
%
% <<VolumeCutSingleSurface.PNG>>
%
% If one matrix of reference points is provided, the program cuts the
% image stack along that surface. 
% Pixels from Surface#1 to half-way surface are saved in "-part1.tif"
% Pixels from half-way surface to Surface#2 are saved in "-part2.tif"
% 
% <<VolumeCutTwoSurfaces.PNG>>
%
% If two matrixes of reference points are provided, the user is asked to
% select the mode of cutting:'
%
% # *Inside to halfway between planes:* 
%  Pixels from Surface#1 to half-way surface are saved in "-part1.tif" 
%  Pixels from half-way surface to Surface#2 are saved in "-part2.tif"
% # *Beginning to halfway between planes:* 
%  Pixels from beginning of stack to half-way surface are saved in "-part1.tif" 
%  Pixels from half-way surface to end of stack are saved in "-part2.tif"
% # *Inside/outside planes:* 
%  Pixels inside surfaces are saved in "-part1.tif" 
%  Pixels outside surfaces are saved in "-part2.tif"
%
% *Input:*
%
% * Image file: a 3D TIF image stack of the volume to cut
% * Reference points: one or two matrixes containing reference points
%  
% *Output:*
%
% * "imageFileName-part1.tif" containing pixels above the final cut surface
% * "imageFileName-part2.tif" containing pixels below the final cut surface
%
% *Dependencies:*
%
% * gridfit.m (surface fitting from reference points)
% * saveastiff.m (TIFF image writer more robust than imwrite)
% * txtBar.m (display progress a text progress bar in the command window)

% Choose the TIF image stack to slice
disp('----- VolumeCut 1.4 -----');
[FileName, PathName] = uigetfile('*.tif', 'Select the image to slice');

% Read the image size and resolution from file
tmpImInfo = imfinfo([PathName FileName]);
tmpImSizeZ = numel(tmpImInfo);
tmpImSizeX = tmpImInfo.Width;
tmpImSizeY = tmpImInfo.Height;
tmpXYres = 1/tmpImInfo(1).XResolution;
if contains(tmpImInfo(1).ImageDescription, 'spacing=')
    tmpPos = strfind(tmpImInfo(1).ImageDescription,'spacing=');
    tmpZres = tmpImInfo(1).ImageDescription(tmpPos+8:end);
    tmpZres = regexp(tmpZres,'\n','split');
    tmpZres = str2double(tmpZres{1});
else
    tmpZres = 0.3; % otherwise use default value
end

% Load the image data into matlab
txtBar('Loading image stack... ');
I = uint8(ones(tmpImSizeX, tmpImSizeY, tmpImSizeZ));
for j = 1:tmpImSizeZ
   I(:,:,j)=imread([PathName FileName], j);
   txtBar(100*j/tmpImSizeZ);
end
txtBar('DONE');

% Load the points delimiting the upper and lower surfaces, surfaceFit them.
[FileNamePoints, PathNamePoints] = uigetfile('*.mat', 'Select the reference slice points', 'MultiSelect', 'on');
if iscell(FileNamePoints)
    nbfiles = length(FileNamePoints);
elseif FileNamePoints ~= 0
    nbfiles = 1;
else
    nbfiles = 0;
end

% Choose the cutting mode depending number of files
if nbfiles ==1
    % If only one set of coordinates split the volume along that plane
    load([PathNamePoints FileNamePoints]);
    SpotsXYZ=double(SpotsXYZ);
    x=SpotsXYZ(:,1);
    y=SpotsXYZ(:,2);
    z=SpotsXYZ(:,3);
    gx=1:2:tmpImSizeX; % fitted surface is a 2x downsample version of original image
    gy=1:2:tmpImSizeY; % fitted surface is a 2x downsample version of original image
    g1=gridfit(x,y,z,gx,gy, 'smoothness', 75); % default smoothness=1
    g1=ceil(g1);
    figure
    colormap(hot(256));
    surf(gx,gy,g1);
    camlight right;
    lighting phong;
    shading interp;
    line(x,y,z,'marker','.','markersize',4,'linestyle','none');
    title('Reference points are used to recreate a surface');
    
    % Slice the image in two halves along the reference surface g3
    clear x y z;
    I1 = I;
    I2 = I;
    txtBar('Slicing the volume... ');
    for x=1:size(I,1)
        for y=1:size(I,2)
            for z=1:size(I,3)
                if z >= g1(ceil(x/2),ceil(y/2))
                    I1(x,y,z)=0;
                else
                    I2(x,y,z)=0;
                end
            end
        end
        txtBar(100*x/size(I,1));
    end
    txtBar('DONE');
elseif nbfiles == 2 
    % if 2 sets of coordinates ask user what to do
    load([PathNamePoints FileNamePoints{1}]);
    fprintf('Fitting a surface to reference points #1...');
    SpotsXYZ=double(SpotsXYZ);
    x=SpotsXYZ(:,1);
    y=SpotsXYZ(:,2);
    z=SpotsXYZ(:,3);
    gx=1:2:tmpImSizeX; % fitted surface is a 2x downsample version of original image
    gy=1:2:tmpImSizeY; % fitted surface is a 2x downsample version of original image
    g1=gridfit(x,y,z,gx,gy, 'smoothness', 75); %default smoothness=1
    g1=ceil(g1);
    fprintf('DONE \n');
    figure
    colormap(hot(256));
    surf(gx,gy,g1);
    camlight right;
    lighting phong;
    shading interp;
    line(x,y,z,'marker','.','markersize',4,'linestyle','none');
    title('Reference points are used to recreate a surface');
    
    load([PathNamePoints FileNamePoints{2}]);
    fprintf('Fitting a surface to reference points #2...');
    SpotsXYZ=double(SpotsXYZ);
    x=SpotsXYZ(:,1);
    y=SpotsXYZ(:,2);
    z=SpotsXYZ(:,3);
    gx=1:2:tmpImSizeX; % fitted surface is a 2x downsample version of original image
    gy=1:2:tmpImSizeY; % fitted surface is a 2x downsample version of original image
    g2=gridfit(x,y,z,gx,gy, 'smoothness', 75); %default smoothness=1
    g2=ceil(g2); % retain only integer part of fitted z-values since in pixel
    fprintf('DONE \n');
    hold on;
    surf(gx,gy,g2);
    camlight right;
    lighting phong;
    shading interp;
    line(x,y,z,'marker','.','markersize',4,'linestyle','none');

    % Make sure g1 and g2 are not inverted (g1 must have smaller values than g2)
    if min(min(g2)) < min(min(g1))
        disp('Spots1 and Spots2 order opposite than expected');
        gx = g1;
        g1 = g2;
        g2 = gx;
    end
    % Proceed with cutting
    mode = input('How to cut? (1: Plane# 1<->middle<->2,  2: Stack Start<->middle<->End,  3: Inside/outside planes): ');
    switch mode
        case 1
            offset1 = input('How many µm after plane #1 shall I start to cut? (0: precisely at plane): ');
            offset1 = ceil(offset1/tmpZres); % convert microns to pixels
            offset2 = input('How many µm before plane #2 shall I stop cutting? (0: precisely at plane): ');
            offset2 = ceil(offset2/tmpZres); % convert microns to pixels
            % calculate the surface exactly half way between those two limit surfaces
            g3 = ceil((g2+g1)/2);
            hold on;
            surf(gx,gy,g3);
            camlight right;
            lighting phong;
            shading interp;
            
            % Slice the image in two halves along the reference surface g1-g3 and g3-g2
            clear x y z;
            I1 = I;
            I2 = I;
            txtBar('Slicing the volume... ');
            for x=1:size(I,1)
                for y=1:size(I,2)
                    for z=1:size(I,3)
                        if z <= (g1(ceil(x/2),ceil(y/2))+offset1)
                            I1(x,y,z)=0;
                        end
                        if z >= g3(ceil(x/2),ceil(y/2))
                            I1(x,y,z)=0;
                        else
                            I2(x,y,z)=0;
                        end
                        if z >= (g2(ceil(x/2),ceil(y/2))-offset2)
                            I2(x,y,z)=0;
                        end
                    end
                end
                txtBar(100*x/size(I,1));
            end
            txtBar('DONE');
        case 2
            % calculate the surface exactly half way between those two limit surfaces
            g3 = ceil((g2+g1)/2);
            hold on;
            surf(gx,gy,g3);
            camlight right;
            lighting phong;
            shading interp;
            
            % Slice the image in two halves along the reference surface g1-g3 and g3-g2
            clear x y z;
            I1 = I;
            I2 = I;
            txtBar('Slicing the volume... ');
            for x=1:size(I,1)
                for y=1:size(I,2)
                    for z=1:size(I,3)
                        if z >= g3(ceil(x/2),ceil(y/2))
                            I1(x,y,z)=0;
                        else
                            I2(x,y,z)=0;
                        end
                    end
                end
                txtBar(100*x/size(I,1));
            end
            txtBar('DONE');
        case 3
            % Slice the image in two halves along the reference surface g1-g3 and g3-g2
            clear x y z;
            I1 = I;
            I2 = I;
            txtBar('Slicing the volume... ');
            for x=1:size(I,1)
                for y=1:size(I,2)
                    for z=1:size(I,3)
                        if z < g1(ceil(x/2),ceil(y/2))
                            I1(x,y,z)=0;
                        end
                        if z > g2(ceil(x/2),ceil(y/2))
                            I1(x,y,z)=0;
                        end
                        if (z >= g1(ceil(x/2),ceil(y/2))) && (z <= g2(ceil(x/2),ceil(y/2)))
                            I2(x,y,z)=0;
                        end
                    end
                end
                txtBar(100*x/size(I,1));
            end
            txtBar('DONE');
    end
else
    disp('no file or more than 2 files selected');
end

[~,FileName,ext] = fileparts(FileName);

% Save resulting halves of the image I into I1.tif and I2.tif
fprintf('Saving sliced volume -part1 ... ');
saveastiff(I1, [PathName FileName '-part1' ext]);
fprintf('Saving sliced volume -part2 ... ');
saveastiff(I2, [PathName FileName '-part2' ext]);
disp('----- VolumeCut operation done! -----');
%% Changelog
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