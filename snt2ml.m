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
% Convert Fiji's Simple Neurite Tracer skeleton file to matlab
% Skeleton files are GZipped XML .skel, specifications available at:
% http://fiji.lbl.gov/mediawiki/phase3/index.php/Simple_Neurite_Tracer:_.skel_File_Format
%
% Resulting matlab structure is composed by the following fields:
%
% skel
% |
% |- calib = (x,y,z) micron/pixel calibration of the skeletonized image
% |- imgsize = (width, height, depth) pixel size of the skeletonized image
% |- totalLength = total dendritic length of the skeleton in micron
% |- branches = individual branches skeletonized, each item is a polygon
%     |- id = unique identifier for the branch
%     |- idParent = id for the parent of this branch (-1 = primary branch)
%     |- idPrimary = id of the primary branch connected to this
%     |- order = branching order (1 = primary branch = originating at soma)
%     |- length = length of the current segment
%     |- Points = coordinates of each node (rows)[x um,y um ,z um,x um,y um ,z um,radius]
%
% Parameters
%
% plotSkel (boolean): if true, the XY projection of the skeleton is plotted
%
function skel = snt2ml(PathName, FileName, plotSkel)
%%
fprintf('Loading skeleton file...');
tmpName = gunzip(fullfile(PathName, FileName));
tmpDoc = xmlread(fullfile(PathName, char(tmpName)));

skel = struct;

tmpTracings = tmpDoc.getDocumentElement;                       % Get the 'tracings' node
tmpEntries = tmpTracings.getChildNodes;

% Load skeleton file
tmpNode = tmpEntries.getFirstChild;
while ~isempty(tmpNode)
    if strcmp(tmpNode.getNodeName, 'samplespacing')
        % Get image calibration

        skel.calib.x = str2double(tmpNode.getAttributes.getNamedItem('x').getNodeValue);
        skel.calib.y = str2double(tmpNode.getAttributes.getNamedItem('y').getNodeValue);
        skel.calib.z = str2double(tmpNode.getAttributes.getNamedItem('z').getNodeValue);
    elseif strcmp(tmpNode.getNodeName, 'imagesize')
        % Get image size

        skel.imgsize.width = str2double(tmpNode.getAttributes.getNamedItem('width').getNodeValue);
        skel.imgsize.height = str2double(tmpNode.getAttributes.getNamedItem('height').getNodeValue);
        skel.imgsize.depth = str2double(tmpNode.getAttributes.getNamedItem('depth').getNodeValue);
    elseif strcmp(tmpNode.getNodeName, 'path')
        % Get skeleton branches

        if tmpNode.hasAttribute('fittedversionof')
            tmpNode = tmpNode.getNextSibling;
            continue; % skip the note if we're dealing with a fitted version
        end
        tmpBranch = struct;

        % General properties of the branch
        tmpBranch.id = str2double(tmpNode.getAttributes.getNamedItem('id').getNodeValue);
        tmpBranch.length = str2double(tmpNode.getAttributes.getNamedItem('reallength').getNodeValue);
        if isempty(tmpNode.getAttributes.getNamedItem('startson'))
            tmpBranch.idParent = -1;
        else
            tmpBranch.idParent = str2double(tmpNode.getAttributes.getNamedItem('startson').getNodeValue);
            % write here code to store branching position from parent dendrite
        end

        % Individual points constituting the branch
        tmpBranch.points = ones(1, 7);
        tmpPoints = tmpNode.getChildNodes;
        tmpPoint = tmpPoints.getFirstChild;
        i = 0;
        while ~isempty(tmpPoint)
            if strcmp(tmpPoint.getNodeName, 'point')
                tmpPos = struct;
                tmpPos.x = str2double(tmpPoint.getAttributes.getNamedItem('x').getNodeValue);
                tmpPos.y = str2double(tmpPoint.getAttributes.getNamedItem('y').getNodeValue);
                tmpPos.z = str2double(tmpPoint.getAttributes.getNamedItem('z').getNodeValue);
                tmpPos.xd = str2double(tmpPoint.getAttributes.getNamedItem('xd').getNodeValue);
                tmpPos.yd = str2double(tmpPoint.getAttributes.getNamedItem('yd').getNodeValue);
                tmpPos.zd = str2double(tmpPoint.getAttributes.getNamedItem('zd').getNodeValue);

                tmpPos.r = 0;

                i = i+1;
                % x and y positions are inverted in the file as
                % compare to original image stacks, inverting here
                % their positions in the final vector
                tmpBranch.points(i, :)= [tmpPos.y, tmpPos.x, tmpPos.z, tmpPos.yd, tmpPos.xd, tmpPos.zd, tmpPos.r];
            end
            tmpPoint = tmpPoint.getNextSibling;
        end

        % Append branch to current cell branches list
        if ~isfield(skel,'branches')            
            skel.branches(1) = tmpBranch;
        else
            skel.branches(numel(skel.branches)+1) = tmpBranch;
        end
    end

    tmpNode = tmpNode.getNextSibling;


end

% Calculate additional parameters for the skeleton

% Total dendritic length
tmpTotalLen = 0;
for i=1:numel(skel.branches)
    tmpBranch = skel.branches(i);
    tmpTotalLen = tmpTotalLen + tmpBranch.length;
end
skel.totalLength = tmpTotalLen;

% Branching order (1= primary dendrite)
tmpOrd = 1;
tmpOrdIdx = -1;
tmpNextOrdIdx = [];

while ~isempty(tmpOrdIdx)

    for i=1:numel(skel.branches)
        if ismember(skel.branches(i).idParent, tmpOrdIdx)
            skel.branches(i).order = tmpOrd;                              % Store branching order value
            tmpNextOrdIdx = cat(1, tmpNextOrdIdx, skel.branches(i).id);   % Populate nodes of the next order
        end
    end
    skel.maxOrder = tmpOrd;
    tmpOrd = tmpOrd + 1;
    tmpOrdIdx = tmpNextOrdIdx;
    tmpNextOrdIdx = [];
end

% Primary dendrite generating each branch
tmpPrim = [];
tmpPrimVertex = []; % initial point of primary dendrites (to find soma)

for i=1:numel(skel.branches)
    if skel.branches(i).idParent == -1
        tmpPrim = cat(1,tmpPrim, skel.branches(i).id);
        tmpPrimVertex(numel(tmpPrim), :) = skel.branches(i).points(1,:); %#ok
    end
end

for i=1:numel(tmpPrim)
    tmpBranchList = tmpPrim(i);
    for j=1:numel(skel.branches)
        if ismember(skel.branches(j).idParent, tmpBranchList) || ...
                ismember(skel.branches(j).id, tmpBranchList)

            tmpBranchList = cat(1, tmpBranchList, skel.branches(j).id);
            skel.branches(j).idPrimary = tmpPrim(i);
        end
    end
end
skel.primaryDendrites = numel(tmpPrim);


% Load fitted values
tmpNode = tmpEntries.getFirstChild;
while ~isempty(tmpNode)
    if strcmp(tmpNode.getNodeName, 'path') && tmpNode.hasAttribute('fittedversionof')
        tmpId = str2double(tmpNode.getAttributes.getNamedItem('fittedversionof').getNodeValue);
        for i=1:numel(skel.branches)
            if skel.branches(i).id == tmpId
                % Reload points constituting the branch from the fitted version
                
                tmpBranch         = struct;
                tmpBranch.points  = ones(1, 7);
                tmpPoints         = tmpNode.getChildNodes;
                tmpPoint          = tmpPoints.getFirstChild;
                j                 = 0;
                
                while ~isempty(tmpPoint)
                    if strcmp(tmpPoint.getNodeName, 'point')
                        tmpPos    = struct;
                        tmpPos.x  = str2double(tmpPoint.getAttributes.getNamedItem('x').getNodeValue);
                        tmpPos.y  = str2double(tmpPoint.getAttributes.getNamedItem('y').getNodeValue);
                        tmpPos.z  = str2double(tmpPoint.getAttributes.getNamedItem('z').getNodeValue);
                        tmpPos.xd = str2double(tmpPoint.getAttributes.getNamedItem('xd').getNodeValue);
                        tmpPos.yd = str2double(tmpPoint.getAttributes.getNamedItem('yd').getNodeValue);
                        tmpPos.zd = str2double(tmpPoint.getAttributes.getNamedItem('zd').getNodeValue);

                        tmpPos.r  = str2double(tmpPoint.getAttributes.getNamedItem('r').getNodeValue);
                        
                        j = j+1;
                        % x and y positions are inverted in the file as
                        % compare to original image stacks, inverting here
                        % their positions in the final vector
                        tmpBranch.points(j, :)= [tmpPos.y, tmpPos.x, tmpPos.z, tmpPos.yd, tmpPos.xd, tmpPos.zd, tmpPos.r];
                    end
                    tmpPoint = tmpPoint.getNextSibling;
                end
                skel.branches(i).points = tmpBranch.points;
                
            end
        end
    end
    tmpNode = tmpNode.getNextSibling;
end
fprintf('DONE\n');

% Plot 2D view of the skeleton coloring branches by primary dendrite
if exist('plotSkel', 'var') && plotSkel
    figure('Name', char(tmpName) ,'units', 'normalized','position', [0.4 0.12 0.5 0.8]); hold on;
    
    % identify primary dendrites indexes
    tmpPrim = [];
    for i=1:numel(skel.branches)
        if skel.branches(i).idParent == -1
            tmpPrim = cat(1,tmpPrim, skel.branches(i).id);
        end
    end
    
    % Plot all the branches coloring them by primary dendrite
    for i=1:numel(tmpPrim)
        tmpCol = [rand, rand, rand];
        for j=1:numel(skel.branches)
            if skel.branches(j).idPrimary == tmpPrim(i)
                plot(skel.branches(j).points(:,1),...
                    skel.imgsize.height - skel.branches(j).points(:,2),...
                    'color', tmpCol);
            end
        end
    end
    
    xlim([0 skel.imgsize.height]);
    ylim([0 skel.imgsize.width]);
    pbaspect([1 1 1]); box on;
    set(gca,'xtick',[]); set(gca,'xticklabel',[]);
    set(gca,'ytick',[]); set(gca,'yticklabel',[]);
    whitebg([0 0 0]);
    title('Skeleton XY projection color coded by primary dendrite origin');
end

clear tmp* i j;
end
