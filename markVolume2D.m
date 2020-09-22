%% ObjectFinder - Recognize 3D structures in image stacks
%  Copyright (C) 2016-2020 Luca Della Santina
%
%  This file is part of ObjectFinder
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
function Dots = markVolume2D(I, Dots)

    % Default parameter values
    CutNumVox  = ceil(size(I)); % Magnify a zoom region of this size
    Isize      = size(I); % Store Image size since we're using it a lot 
    nFrames    = Isize(3);
    actionType = 'Add';

    Pos        = ceil([Isize(2)/2, Isize(1)/2, Isize(3)/2]); % Initial position is middle of the stack
    PosRect    = ceil([Isize(2)/2-CutNumVox(2)/2, Isize(1)/2-CutNumVox(1)/2]); % Initial position of zoomed rectangle (top-left vertex)
    PosZoom    = [-1, -1, -1];    % Initial position in zoomed area
    click      = 0;               % Initialize click status
    frame      = ceil(nFrames/2); % Current frame
    Iframe     = I(:,:,frame);
    Iframe     = cat(3,Iframe,Iframe,Iframe);
    SelObjID   = 0;               % Initialize selected object ID#
    brushSize  = ceil(Isize(1)/50);
	
	% Initialize GUI
	fig_handle = figure('Name','Sliced Volume inspector (green: valid object, red: rejected object, yellow: selected object)','NumberTitle','off','Color',[.3 .3 .3], 'MenuBar','none', 'Units','pixel', ...
		'WindowButtonDownFcn',@button_down, 'WindowButtonUpFcn',@button_up, 'WindowButtonMotionFcn', @on_click, 'KeyPressFcn', @key_press, 'KeyReleaseFcn', @key_release,'windowscrollWheelFcn', @wheel_scroll);
	
	% Add custom scroll bar
	scroll_axes = axes('Parent',fig_handle, 'Position',[0 0 0.9 0.045], 'Visible','off', 'Units', 'normalized');
	axis([0 1 0 1]); axis off
	scroll_bar_width = max(1 / nFrames, 0.01);
	scroll_handle = patch([0 1 1 0] * scroll_bar_width, [0 0 1 1], [.8 .8 .8], 'Parent',scroll_axes, 'EdgeColor','none', 'ButtonDownFcn', @on_click);

    % Add GUI conmponents
    set(gcf,'units', 'normalized', 'position', [0.05 0.1 0.90 0.76]);
    pnlSettings     = uipanel(  'Title','Objects'   ,'Units','normalized','Position',[.903,.005,.095,.99]); %#ok, unused variable
    btnLoad         = uicontrol('Style','Pushbutton','Units','normalized','position',[.907,.920,.088,.05],'String','Load objects','Callback',@btnLoad_clicked); %#ok, unused variable    
    txtAction       = uicontrol('Style','text'      ,'Units','normalized','position',[.912,.875,.020,.02],'String','Tool:'); %#ok, unused handle
    cmbAction       = uicontrol('Style','popup'     ,'Units','normalized','Position',[.935,.860,.055,.04],'String', {'Add (a)','Select (s)'},'Callback', @cmbAction_changed);
    chkShowObjects  = uicontrol('Style','checkbox'  ,'Units','normalized','position',[.912,.830,.085,.02],'String','Show (spacebar)', 'Value',1,'Callback',@chkShowObjects_changed);
    chkShowAllZ     = uicontrol('Style','checkbox'  ,'Units','normalized','position',[.912,.790,.085,.02],'String','Ignore Z (Z)', 'Value',1,'Callback',@chkShowAllZ_changed);
    lstDots         = uicontrol('Style','listbox'   ,'Units','normalized','position',[.907,.530,.085,.25],'String',[],'Callback',@lstDots_valueChanged);
    btnDelete       = uicontrol('Style','Pushbutton','Units','normalized','position',[.907,.480,.088,.04],'String','Delete Item (d)','Callback',@btnDelete_clicked); %#ok, unused variable

    txtValidObjs    = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.440,.085,.02],'String',['Total: ' num2str(size(Dots,3))]);
    txtSelObj       = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.410,.085,.02],'String','Selected Object info'); %#ok, unused variable
    txtSelObjID     = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.380,.085,.02],'String','ID# :');
    txtSelObjPos    = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.350,.085,.02],'String','Pos : ');
    txtSelObjPix    = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.320,.085,.02],'String','Voxels : ');

    txtZoom         = uicontrol('Style','text'      ,'Units','normalized','position',[.925,.290,.050,.02],'String','Zoom level:'); %#ok, unused variable
    btnZoomOut      = uicontrol('Style','Pushbutton','Units','normalized','position',[.920,.230,.030,.05],'String','-','Callback',@btnZoomOut_clicked); %#ok, unused variable
    btnZoomIn       = uicontrol('Style','Pushbutton','Units','normalized','position',[.950,.230,.030,.05],'String','+','Callback',@btnZoomIn_clicked); %#ok, unused variable
    btnSave         = uicontrol('Style','Pushbutton','Units','normalized','position',[.907,.050,.088,.05],'String','Save objects','Callback',@btnSave_clicked); %#ok, unused variable    
    
    
	% Main drawing and related handles
	axes_handle     = axes('Position',[0 0.03 0.90 1]);
	frame_handle    = 0;
    rect_handle     = 0;
    PosMouse        = [0,0]; % mouse pointer position in screen coordinates
    Hotkey          = {}; % Hotkey pressed on keyboard (e.g. {'control'})
    brush           = rectangle(axes_handle,'Curvature', [1 1],'EdgeColor', [1 1 0],'LineWidth',2,'LineStyle','-');
    animatedLine    = animatedline('LineWidth', 1, 'Color', 'blue');
    cmbAction_assign(actionType);

    lstDotsRefresh;
    set(fig_handle, 'Units', 'pixels');
    scroll(frame, 'both');
    uiwait;

    function lstDotsRefresh
        % Updates list of available Objects (Objects are ROIs in the image)
        set(lstDots, 'String', 1:numel(Dots.Filter));
        set(txtValidObjs,'string',['Total: ' num2str(numel(find(Dots.Filter)))]);
        
        if SelObjID > 0 && SelObjID <= numel(Dots.Filter)            
            PosZoom = [Dots.Pos(SelObjID, 2), Dots.Pos(SelObjID, 1)];
            set(lstDots, 'Value', SelObjID);
            lstDots_valueChanged(lstDots, []);
            
        elseif SelObjID > numel(Dots.Filter)
            SelObjID = numel(Dots.Filter);
            set(lstDots, 'Value', SelObjID);
            disp('dot was out of range');
        end
        
        scroll(frame, 'right');
    end
    
    function lstDots_valueChanged(src,event) %#ok, unused arguments
        % Update on-screen info of selected object        
        SelObjID = get(src, 'Value');
        
        if SelObjID > 0 && numel(Dots.Filter)>0
            set(txtSelObjID ,'string',['ID#: ' num2str(SelObjID)]);
            set(txtSelObjPos,'string',['Pos X:' num2str(Dots.Pos(SelObjID,1)) ', Y:' num2str(Dots.Pos(SelObjID,2)) ', Z:' num2str(Dots.Pos(SelObjID,3))]);
            set(txtSelObjPix,'string',['Volume : ' num2str(numel(Dots.Vox(SelObjID).Ind))]);
        else
            set(txtSelObjID    ,'string','ID#: ');
            set(txtSelObjPos   ,'string','Pos : ');
            set(txtSelObjPix   ,'string','Volume : ');
        end

        % Store Zoom rectangle verteces coodinates (clockwise from top-left)
        Rect(1,:) = [PosRect(1), PosRect(2)];
        Rect(2,:) = [PosRect(1)+CutNumVox(2), PosRect(2)];
        Rect(3,:) = [PosRect(1)+CutNumVox(2), PosRect(2)+CutNumVox(1)];
        Rect(4,:) = [PosRect(1), PosRect(2)+CutNumVox(1)];

        if SelObjID > 0 && (~inpolygon_fast(Dots.Pos(SelObjID,1), Dots.Pos(SelObjID,2),Rect(:,1), Rect(:,2)) || frame ~= Dots.Pos(SelObjID,3))
            Pos = [Dots.Pos(SelObjID,1), Dots.Pos(SelObjID,2), Dots.Pos(SelObjID,3)];
            % Ensure new position is within boundaries of the image
            Pos     = [max(Pos(1),CutNumVox(2)/2), max(Pos(2), CutNumVox(1)/2), Dots.Pos(SelObjID,3)];
            Pos     = [min(Pos(1),Isize(2)-CutNumVox(2)/2), min(Pos(2), Isize(1)-CutNumVox(1)/2), Dots.Pos(SelObjID,3)];
            PosRect = [Pos(1)-CutNumVox(2)/2, Pos(2)-CutNumVox(1)/2, Dots.Pos(SelObjID,3)];
            PosZoom = [-1 -1 -1];
            frame = Dots.Pos(SelObjID,3);
            scroll(frame, 'both');
            
        else
            scroll(frame, 'right');
        end
    end

    function btnDelete_clicked(src,event) %#ok, unused arguments
        % Remove selected object from the list
        if SelObjID > 0
            Dots.Pos(SelObjID, :) = [];
            Dots.Vox(SelObjID)    = [];
            Dots.Filter(SelObjID) = [];

            if SelObjID > numel(Dots.Filter)
                SelObjID = numel(Dots.Filter);
                set(lstDots, 'Value', 1);
            end
            PosZoom = [-1, -1];
            lstDotsRefresh;            
            scroll(frame, 'right');    
        end
    end

    function ID = addDot(X, Y, D)
        % Creates a new object #ID from pixels within R radius
        % X,Y: center coordinates, R: radius in zoomed region pixels 
        
        % Convert radius from zoomed to image units region scaling factor
        ZoomFactor = Isize(1) / CutNumVox(1);
        r = D / ZoomFactor /2;
        
        % Create a circular mask around the pixel [xc,yc] of radius r
        [x, y] = meshgrid(1:Isize(2), 1:Isize(1));
        mask = (x-X).^2 + (y-Y).^2 < r^2;
        
        % Generate statistics of the new dot and add to Dots
        if isempty(Dots.Pos)
            Dots.Pos(1,:)       = [X,Y,frame];            
            
            [Dots.Vox(1).Pos(:,1), Dots.Vox(1).Pos(:,2)] = ind2sub(size(mask), find(mask));            
            Dots.Vox(1).Pos(:,3) = frame;
            Dots.Vox(1).Ind     = sub2ind(Isize,Dots.Vox(1).Pos(:,1), Dots.Vox(1).Pos(:,2), Dots.Vox(1).Pos(:,3));
            Dots.Filter         = 1;
        else
            Dots.Pos(end+1,:)   = [X,Y, frame];
            [Dots.Vox(end+1).Pos(:,1), Dots.Vox(end+1).Pos(:,2)] = ind2sub(size(mask), find(mask));
            Dots.Vox(end).Pos(:,3) = frame;            
            Dots.Vox(end).Ind     = sub2ind(Isize, Dots.Vox(end).Pos(:,1), Dots.Vox(end).Pos(:,2), Dots.Vox(end).Pos(:,3));
            Dots.Filter(end+1)  = 1;
        end 
                
        SelObjID = numel(Dots.Filter);
        ID = SelObjID;

        Dots.Vox(ID).RawBright = I(Dots.Vox(ID).Ind);
        lstDotsRefresh;
    end

    function cmbAction_changed(src,event) %#ok, unused parameters
        switch get(src,'Value')
            case 1, actionType = 'Add';
            case 2, actionType = 'Select';
        end
    end

    function cmbAction_assign(newType)
        switch newType
            case 'Add',    set(cmbAction, 'Value', 1);
            case 'Select', set(cmbAction, 'Value', 2);
        end
    end

    function chkShowObjects_changed(src,event) %#ok, unused arguments
        scroll(frame, 'right');
    end

    function chkShowAllZ_changed(src,event) %#ok, unused arguments
        scroll(frame, 'right');
    end

    function btnZoomOut_clicked(src, event) %#ok, unused arguments        
        % Ensure new zoomed region is still within image borders
        CutNumVox = [min(CutNumVox(1)*2, Isize(1)), min(CutNumVox(2)*2, Isize(2))];
        Pos       = [min(Pos(1),Isize(2)-CutNumVox(2)/2), min(Pos(2),Isize(1)-CutNumVox(1)/2), frame];       
        PosRect   = [max(1,Pos(1)-CutNumVox(2)/2), max(1,Pos(2)-CutNumVox(1)/2)];
        PosZoom   = [-1, -1, -1];
        scroll(frame, 'both');
    end

    function btnZoomIn_clicked(src, event) %#ok, unused arguments
        CutNumVox = [max(round(CutNumVox(1)/2,0), 32), max(round(CutNumVox(2)/2,0),32)];
        PosRect   = [max(1,Pos(1)-CutNumVox(2)/2), max(1,Pos(2)-CutNumVox(1)/2)];        
        PosZoom   = [-1, -1, -1];
        scroll(frame, 'both');
    end

    function btnSave_clicked(src, event) %#ok, unused arguments
        Path = uigetdir;
        FileName = [Path filesep Dots.Name '.mat'];
        save(FileName, '-struct', 'Dots');
        msgbox('Fiducial points saved.', 'Saved', 'help');
    end

    function btnLoad_clicked(src, event) %#ok, unused arguments
        FileName = uigetfile('*.mat');
        Dots = load(FileName);
        lstDotsRefresh;
        scroll(frame, 'right');
        msgbox('Fiducial points Loaded.', 'Complete', 'help');
    end

    function btnPlus_clicked(src, event) %#ok, unused arguments
        new_thresh = thresh + 1;
        set(txtThresh,'string',num2str(new_thresh));
        applyFilter(new_thresh, thresh2);
    end

    function btnMinus_clicked(src, event) %#ok, unused arguments
        new_thresh = max(thresh - 1, 0);
        set(txtThresh,'string',num2str(new_thresh));
        applyFilter(new_thresh, thresh2);
    end

    function selectDotsWithinPolyArea(xv, yv)
        % Find indeces of Dots with voxels within passed polygon area
        % xv,yv: coordinates of the polygon vertices
        
        % Switch mouse pointer to hourglass while computing
        oldPointer = get(fig_handle, 'Pointer');
        set(fig_handle, 'Pointer', 'watch'); pause(0.3);

        if numel(xv) == 0 || numel(yv) == 0
            % If user clicked without drawing polygon, query that position
            set(fig_handle, 'Units', 'pixels');
            click_point = get(gca, 'CurrentPoint');
            
            PosX     = ceil(click_point(1,1));
            PosZoomX = PosX - Isize(2) -1;
            PosZoomX = ceil(PosZoomX * CutNumVox(2)/(Isize(2)-1));

            PosY     = ceil(click_point(1,2));                        
            PosZoomY = Isize(1) - PosY;
            PosZoomY = CutNumVox(1)-ceil(PosZoomY*CutNumVox(1)/(Isize(1)-1));

            PosZoom  = [PosZoomX, PosZoomY frame];
            Pos      = [Pos(1), Pos(2) frame];
            SelObjID = 0;
        else        
            % Create mask inside the passed polygon coordinates
            [x, y] = meshgrid(1:Isize(2), 1:Isize(1));
            mask   = inpolygon_fast(x,y,xv,yv); % ~75x faster than inpolygon
            
            % Select Dot IDs id their voxels fall within the polygon arel
            %tic;
            SelObjID = [];
            
            % Restrict search only to objects within the zoomed area
            fxmin = max(ceil(Pos(1) - CutNumVox(2)/2)+1, 1);
            fxmax = min(ceil(Pos(1) + CutNumVox(2)/2), Isize(2));
            fymin = max(ceil(Pos(2) - CutNumVox(1)/2)+1, 1);
            fymax = min(ceil(Pos(2) + CutNumVox(1)/2), Isize(1));            
            valIcut = Dots.Filter;
            rejIcut = ~Dots.Filter;
            for i = 1:numel(valIcut)
                valIcut(i) = valIcut(i) && Dots.Pos(i,2)>=fxmin && Dots.Pos(i,2)<=fxmax && Dots.Pos(i,1)>=fymin && Dots.Pos(i,1)<=fymax;
                rejIcut(i) = rejIcut(i) && Dots.Pos(i,2)>=fxmin && Dots.Pos(i,2)<=fxmax && Dots.Pos(i,1)>=fymin && Dots.Pos(i,1)<=fymax;
            end
            ValObjIDs = find(valIcut); % IDs of valid objects within field of view  
            RejObjIDs = find(rejIcut); % IDs of rejected objects within field of view 
            VisObjIDs = [ValObjIDs; RejObjIDs]; % IDs of objects within field of view 

            for i=1:numel(VisObjIDs)
                VoxPos = Dots.Vox(VisObjIDs(i)).Pos;
                for j = 1:size(VoxPos,1)
                    if VoxPos(j,3) == frame && VoxPos(j,2)>=fxmin && VoxPos(j,2)<=fxmax && VoxPos(j,1)>=fymin && VoxPos(j,1)<=fymax
                        ind = sub2ind(size(mask), VoxPos(j,1), VoxPos(j,2));
                        if mask(ind) && isempty(SelObjID)
                            SelObjID = VisObjIDs(i);
                            break
                        elseif mask(ind) && ~isempty(SelObjID)
                            SelObjID(end+1) = VisObjIDs(i); %#ok
                            break
                        end
                    end
                end
            end
            %disp(['Time elapsed: ' num2str(toc)]);
        end
        
        % Switch back mouse pointer to the original shape
        set(fig_handle, 'Pointer', oldPointer);
    end

    function refineDotWithPolyArea(xv, yv)
        % Add voxels within the polygon area to those belonging to curr dot
        % xv,yv: coordinates of the polygon vertices
        
        % Switch mouse pointer to hourglass while computing
        oldPointer = get(fig_handle, 'Pointer');
        set(fig_handle, 'Pointer', 'watch'); pause(0.3);

        if numel(xv) == 0 || numel(yv) == 0
            % If user clicked without drawing polygon, query that position
            set(fig_handle, 'Units', 'pixels');
            click_point = get(gca, 'CurrentPoint');
            
            PosX     = ceil(click_point(1,1));
            PosZoomX = PosX - Isize(2)+1;
            PosZoomX = ceil(PosZoomX * CutNumVox(2)/Isize(2));

            PosY     = ceil(click_point(1,2));                        
            PosZoomY = Isize(1) - PosY;
            PosZoomY = CutNumVox(1)-ceil(PosZoomY*CutNumVox(1)/Isize(1));

            PosZoom  = [PosZoomX, PosZoomY frame];
            Pos      = [Pos(1), Pos(2) frame];
            SelObjID = 0;
        else        
            % Create mask of pixels inside the passed polygon coordinates
            [x, y] = meshgrid(1:Isize(2), 1:Isize(1));
            mask   = inpolygon_fast(x,y,xv,yv); % ~75x faster than inpolygon
            
            if numel(SelObjID)>1
                return
            end
            
            clickType = get(fig_handle, 'SelectionType');
            
            if isempty(SelObjID) || SelObjID==0
                % Create a new object to append to the list of objects
                
                [MaskSub2Dx, MaskSub2Dy] = ind2sub(size(mask), find(mask)); % 2D coordinates (x,y) of pixels within polygon
                MaskInd3D = sub2ind(Isize, MaskSub2Dx, MaskSub2Dy, ones(size(MaskSub2Dx))*frame); % Index of those pixels within the 3D image stack
                SelObjID = numel(Dots.Vox)+1;
                Dots.Vox(SelObjID).Ind = MaskInd3D;
                Dots.Vox(SelObjID).Pos = zeros(numel(Dots.Vox(SelObjID).Ind), 2);
                [Dots.Vox(SelObjID).Pos(:,1), Dots.Vox(SelObjID).Pos(:,2), Dots.Vox(SelObjID).Pos(:,3)] = ind2sub(Isize, Dots.Vox(SelObjID).Ind);            
                Dots.Vox(SelObjID).RawBright = I(Dots.Vox(SelObjID).Ind);
                Dots.Pos(SelObjID, :) = median(Dots.Vox(SelObjID).Pos);
                Dots.Vol(SelObjID) = numel(Dots.Vox(SelObjID).Ind);
                Dots.MeanBright(SelObjID) = mean(Dots.Vox(SelObjID).RawBright);
                Dots.ITMax(SelObjID) = 255;
                Dots.ITSim(SelObjID) = 255;
                
                % Update total amount of available objects
                Dots.Num = Dots.Num +1;
                Dots.Filter(SelObjID) = true;
                set(txtValidObjs, 'String',['Valid: ' num2str(numel(find(Dots.Filter)))]);
                
            elseif strcmp(clickType,'normal') 
                % User left-clicked Add pixels to current object (SelObjID)
                
                [MaskSub2Dx, MaskSub2Dy] = ind2sub(size(mask), find(mask)); % 2D coordinates (x,y) of pixels within polygon
                MaskInd3D = sub2ind(Isize, MaskSub2Dx, MaskSub2Dy, ones(size(MaskSub2Dx))*frame); % Index of those pixels within the 3D image stack
                Dots.Vox(SelObjID).Ind = union(Dots.Vox(SelObjID).Ind, MaskInd3D, 'sorted');
                Dots.Vox(SelObjID).Pos = zeros(numel(Dots.Vox(SelObjID).Ind), 2);
                [Dots.Vox(SelObjID).Pos(:,1), Dots.Vox(SelObjID).Pos(:,2), Dots.Vox(SelObjID).Pos(:,3)] = ind2sub(Isize, Dots.Vox(SelObjID).Ind);            
                Dots.Vox(SelObjID).RawBright = I(Dots.Vox(SelObjID).Ind);
                Dots.Vol(SelObjID) = numel(Dots.Vox(SelObjID).Ind);
                % Recalculate ITMax and ITSum and Pos
                Dots.MeanBright(SelObjID) = mean(Dots.Vox(SelObjID).RawBright);
                
            elseif strcmp(clickType,'alt') 
                % User right-clicked Add pixels to current object (SelObjID)

                [MaskSub2Dx, MaskSub2Dy] = ind2sub(size(mask), find(mask)); % 2D coordinates (x,y) of pixels within polygon
                MaskInd3D = sub2ind(Isize, MaskSub2Dx, MaskSub2Dy, ones(size(MaskSub2Dx))*frame); % Index of those pixels within the 3D image stack
                Dots.Vox(SelObjID).Ind = setdiff(Dots.Vox(SelObjID).Ind, MaskInd3D, 'sorted');
                Dots.Vox(SelObjID).Pos = zeros(numel(Dots.Vox(SelObjID).Ind), 2);
                [Dots.Vox(SelObjID).Pos(:,1), Dots.Vox(SelObjID).Pos(:,2), Dots.Vox(SelObjID).Pos(:,3)] = ind2sub(Isize, Dots.Vox(SelObjID).Ind);            
                Dots.Vox(SelObjID).RawBright = I(Dots.Vox(SelObjID).Ind);
                Dots.Vol(SelObjID) = numel(Dots.Vox(SelObjID).Ind);
                % Recalculate ITMax and ITSum and Pos
                Dots.MeanBright(SelObjID) = mean(Dots.Vox(SelObjID).RawBright);                
            end
        end
        
        % Switch back mouse pointer to the original shape
        set(fig_handle, 'Pointer', oldPointer);
    end

    function wheel_scroll(src, event) %#ok, unused arguments
        if contains(Hotkey, 'control')

            % Change size of brush
            if event.VerticalScrollCount < 0
                brushSize = brushSize +1;
            elseif event.VerticalScrollCount > 0
                brushSize = brushSize -1;
            end
            
            if brushSize < 1
                brushSize = 1;
            end
            
            % Adjust brush to the new size and redraw it onscreen
            ZoomFactor = Isize(1) / CutNumVox(1);
            brushSizeScaled = brushSize * ZoomFactor;
            PosXfenced = max(brushSizeScaled/2, min(PosMouse(1)-brushSizeScaled/2, Isize(2)*2-brushSizeScaled-2));
            PosYfenced = max(brushSizeScaled/2, min(PosMouse(2)-brushSizeScaled/2, Isize(1)*2-brushSizeScaled-2));
            brushPos = [PosXfenced, PosYfenced, brushSizeScaled, brushSizeScaled];
            
            if ~isvalid(brush)
                brush = rectangle(axes_handle,'Position', brushPos,'Curvature',[1 1],'EdgeColor',[1 1 0],'LineWidth',2,'LineStyle','-');
            else
                set(brush, 'Position',  brushPos);
            end
            click = false;
            
        else
            
            % Scroll Z plane
            if event.VerticalScrollCount < 0
                %position = get(scroll_handle, 'XData');
                %disp(position);
                scroll(frame+1, 'both'); % Scroll up
            elseif event.VerticalScrollCount > 0
                scroll(frame-1, 'both'); % Scroll down
            end
        end
          
    end
    
    function key_press(src, event) %#ok, unused arguments
        %event.Key % displays the name of the pressed key
        Hotkey = event.Modifier;
        
        switch event.Key  % Process shortcut keys
            case 'space'
                chkShowObjects.Value = ~chkShowObjects.Value;
                chkShowObjects_changed();
            case {'leftarrow','a'}
                Pos = [max(CutNumVox(2)/2, Pos(1)-CutNumVox(1)+ceil(CutNumVox(2)/5)), Pos(2),frame];
                PosZoom = [-1, -1, -1];
                scroll(frame, 'both');
            case {'rightarrow','d'}
                Pos = [min(Isize(2)-1-CutNumVox(2)/2, Pos(1)+CutNumVox(2)-ceil(CutNumVox(2)/5)), Pos(2),frame];
                PosZoom = [-1, -1, -1];
                scroll(frame, 'both');
            case {'uparrow','w'}
                Pos = [Pos(1), max(CutNumVox(1)/2, Pos(2)-CutNumVox(1)+ceil(CutNumVox(1)/5)),frame];
                PosZoom = [-1, -1, -1];
                scroll(frame,'both');
            case {'downarrow','s'}
                Pos = [Pos(1), min(Isize(1)-1-CutNumVox(1)/2, Pos(2)+CutNumVox(1)-ceil(CutNumVox(1)/5)),frame];
                PosZoom = [-1, -1, -1];
                scroll(frame, 'both');
            case 'equal' , btnZoomIn_clicked;
            case 'hyphen', btnZoomOut_clicked;
        end
    end

    function key_release(src, event) %#ok, unused arguments
        Hotkey = event.Modifier; % Contains 'control, 'alt', 'shift'
    end

	function button_down(src, event)
		set(src,'Units','norm')
		click_pos = get(src, 'CurrentPoint');
        if click_pos(2) <= 0.035
            click = 1; % click happened on the scroll bar
            on_click(src,event);
        else
            click = 2; % click happened somewhere else
            on_click(src,event);
        end
	end

	function button_up(src, event)  %#ok, unused arguments
        click = 0;
        click_point = get(gca, 'CurrentPoint');
        MousePosX   = ceil(click_point(1,1));
        switch actionType
            case {'Select'}                
                if MousePosX > Isize(2) && isvalid(animatedLine)
                    [x,y] = getpoints(animatedLine);

                    % Locate position of points in respect to zoom area
                    PosZoomX = x - Isize(2)-1;
                    PosZoomX = ceil(PosZoomX * CutNumVox(2)/(Isize(2)-1));                
                    PosZoomY = Isize(1) - y;
                    PosZoomY = CutNumVox(1)-ceil(PosZoomY*CutNumVox(1)/(Isize(1)-1));

                    % Locate position of points in respect to original img
                    absX = PosZoomX + PosRect(1);
                    absY = PosZoomY + PosRect(2);

                    % Fill every point within delimited perimeter
                    selectDotsWithinPolyArea(absX, absY);
                    delete(animatedLine);
                end
            case {'Add', 'Refine'}
                if MousePosX > Isize(2) && isvalid(animatedLine)
                    [x,y] = getpoints(animatedLine);

                    % Locate position of points in respect to zoom area
                    PosZoomX = x - Isize(2)-1;
                    PosZoomX = ceil(PosZoomX * CutNumVox(2)/(Isize(2)-1));                
                    PosZoomY = Isize(1) - y;
                    PosZoomY = CutNumVox(1)-ceil(PosZoomY*CutNumVox(1)/(Isize(1)-1));

                    % Locate position of points in respect to original img
                    absX = PosZoomX + PosRect(1);
                    absY = PosZoomY + PosRect(2);

                    % Fill every point within delimited perimeter
                    refineDotWithPolyArea(absX, absY);
                    delete(animatedLine);
                end
        end

        scroll(frame, 'right');
	end

	function on_click(src, event)  %#ok, unused arguments
        switch click
            case 0 
                % ** User moved the mouse without clicking anywhere **
                
                % Set the proper mouse pointer appearance
                set(fig_handle, 'Units', 'pixels');
                click_point = get(gca, 'CurrentPoint');
                PosX = ceil(click_point(1,1));
                PosY = ceil(click_point(1,2));

                if PosY <= 0 || PosY >= Isize(1)
                    % Display the default arrow everywhere else
                    set(fig_handle, 'Pointer', 'arrow');
                    if isvalid(brush), delete(brush); end 
                    return;
                end
                
                if PosX <= Isize(2)
                    % Mouse in Left Panel, display a hand
                    
                    oldPointer = get(fig_handle, 'Pointer');
                    if ~strcmp(oldPointer, 'watch')
                        set(fig_handle, 'Pointer', 'fleur');
                    end
                    if isvalid(brush), delete(brush); end

                elseif PosX <= Isize(2)*2
                    % Mouse in Right Panel, act depending of the selected tool
                    switch actionType
                        case 'Select'
                            oldPointer = get(fig_handle, 'Pointer');
                            if ~strcmp(oldPointer, 'watch')
                                [PCData, PHotSpot] = getPointerCrosshair;
                                set(fig_handle, 'Pointer', 'custom', 'PointerShapeCData', PCData, 'PointerShapeHotSpot', PHotSpot, 'Units', 'pixel');
                            end
                            if isvalid(brush), delete(brush); end
                            return
                            
                        case 'Add'                            
                            % Recreate the brush because frame is redrawn otherwise
                            % just redraw the brush in the new location
                            ZoomFactor = Isize(1) / CutNumVox(1);
                            
                            brushSizeScaled = brushSize * ZoomFactor;                                                        
                            PosXfenced = max(brushSizeScaled/2, min(PosX-brushSizeScaled/2, Isize(2)*2-brushSizeScaled-2));
                            PosYfenced = max(brushSizeScaled/8, min(PosY-brushSizeScaled/2, Isize(1)*2-brushSizeScaled-2));
                            brushPos = [PosXfenced, PosYfenced, brushSizeScaled, brushSizeScaled];
                            
                            PosMouse = [PosX, PosY];
                            % disp(['X:' num2str(PosX) ' brushX:' num2str(brushPos(1)) ' Y:' num2str(PosY) ' brushY:' num2str(brushPos(2)) ' brushSize:' num2str(brushSizeScaled)]);
                            
                            if ~isvalid(brush)
                                brush = rectangle(axes_handle,'Position', brushPos,'Curvature',[1 1],'EdgeColor',[1 1 0],'LineWidth',2,'LineStyle','-');
                            else
                                set(brush, 'Position',  brushPos);
                            end
                            
                            if PosY <= 0 || PosY > Isize(1)-brushSizeScaled/2
                                % Display the default arrow everywhere else
                                set(fig_handle, 'Pointer', 'arrow');
                                if isvalid(brush), delete(brush); end 
                                return;
                            end                            
                    end
                else
                    % Display the default arrow everywhere else
                    oldPointer = get(fig_handle, 'Pointer');
                    if ~strcmp(oldPointer, 'watch')
                        set(fig_handle, 'Pointer', 'arrow');
                    end
                    if isvalid(brush), delete(brush); end
                end
                
                if PosY < 0 || PosY > Isize(1)
                    % Display the default arrow everywhere else
                    set(fig_handle, 'Pointer', 'arrow');
                    return;
                end

                if exist('oldPointer', 'var') && strcmp(oldPointer, 'watch')
                    return;
                elseif PosX <= Isize(2)
                    % Mouse in Left Panel, display a hand
                    set(fig_handle, 'Pointer', 'fleur');
                elseif PosX <= Isize(2)*2
                    % Mouse in Right Panel, act depending of the selected tool
                    [PCData, PHotSpot] = getPointerCrosshair;
                    set(fig_handle, 'Pointer', 'custom', 'PointerShapeCData', PCData, 'PointerShapeHotSpot', PHotSpot, 'Units', 'pixel');
                else
                    % Display the default arrow everywhere else
                    set(fig_handle, 'Pointer', 'arrow');
                end
            case 1 % Clicked on the scroll bar, move to new frame                
                set(fig_handle, 'Units', 'normalized');
                click_point = get(fig_handle, 'CurrentPoint');
                set(fig_handle, 'Units', 'pixels');
                x = click_point(1) / 0.9; % scroll bar size = 0.9 of window
                
                % get corresponding frame number
                new_f = floor(1 + x * nFrames);
                
                if new_f < 1 || new_f > nFrames || new_f == frame
                    return
                end
                set(fig_handle, 'Units', 'pixels');
                scroll(new_f, 'both');
                
            case 2  % User clicked on image
                set(fig_handle, 'Units', 'pixels');
                click_point = get(gca, 'CurrentPoint');
                PosX = ceil(click_point(1,1));
                PosY = ceil(click_point(1,2));
                
                if PosX <= Isize(2) % User clicked on LEFT-panel
                    ClickPos = [max(CutNumVox(2)/2+1, PosX),...
                                max(CutNumVox(1)/2+1, PosY)];
                    
                    % Make sure zoom rectangle is within image area
                    Pos = [max(CutNumVox(2)/2, PosX),...
                           max(CutNumVox(1)/2, PosY), frame];
                    
                    Pos = [min(Isize(2)-CutNumVox(2)/2,ClickPos(1)),...
                           min(Isize(1)-CutNumVox(1)/2,ClickPos(2)), frame];
                    PosZoom  = [-1, -1, -1];
                    PosRect  = [ClickPos(1)-CutNumVox(2)/2, ClickPos(2)-CutNumVox(1)/2];
                    scroll(frame, 'left');
                    
                else % User clicked in the RIGHT-panel (zoomed region)                    
                    % Detect coordinates of the point clicked in PosZoom
                    % Note: x,y coordinates are inverted in ImStk
                    % Note: x,y coordinates are inverted in CutNumVox
                    PosZoomX = PosX - Isize(2)-1;
                    PosZoomX = ceil(PosZoomX * CutNumVox(2)/(Isize(2)-1));
                    
                    PosZoomY = Isize(1) - PosY;
                    PosZoomY = CutNumVox(1)-ceil(PosZoomY*CutNumVox(1)/(Isize(1)-1));

                    % Do different things depending whether left/right-clicked
                    clickType = get(fig_handle, 'SelectionType');
                    
                    if strcmp(clickType, 'alt')
                        % User RIGHT-clicked in the right panel (zoomed region)
                        switch actionType
                            case 'Select'
                                % Move the view to that position
                                PosZoom = [-1, -1, -1];
                                Pos     = [Pos(1)+PosZoomX-CutNumVox(2)/2,...
                                           Pos(2)+PosZoomY-CutNumVox(1)/2, frame];

                                % Make sure zoom rectangle is within image area
                                Pos = [max(CutNumVox(2)/2+1,Pos(1)),...
                                       max(CutNumVox(1)/2+1,Pos(2)), frame];
                                Pos = [min(Isize(2)-CutNumVox(2)/2,Pos(1)),...
                                       min(Isize(1)-CutNumVox(1)/2,Pos(2)),frame];
                        end
                        
                        
                    elseif strcmp(clickType, 'normal')
                        % User LEFT-clicked in the right panel (zoomed region)
                        
                        PosZoom = [PosZoomX, PosZoomY frame];
                        Pos     = [Pos(1), Pos(2) frame];
                        
                        % Absolute position on image of point clicked on right panel
                        % position Pos. Note: Pos(2) is X, Pos(1) is Y
                        fymin = max(ceil(Pos(2) - CutNumVox(1)/2), 1);
                        fymax = min(ceil(Pos(2) + CutNumVox(1)/2), Isize(1));
                        fxmin = max(ceil(Pos(1) - CutNumVox(2)/2), 1);
                        fxmax = min(ceil(Pos(1) + CutNumVox(2)/2), Isize(2));
                        fxpad = CutNumVox(1) - (fxmax - fxmin); % add padding if position of selected rectangle fall out of image
                        fypad = CutNumVox(2) - (fymax - fymin); % add padding if position of selected rectangle fall out of image
                        absX  = fxpad+fxmin+PosZoom(1);
                        absY  = fypad+fymin+PosZoom(2);
                        
                        if absX>0 && absX<=Isize(2) && absY>0 && absY<=Isize(1)
                            switch actionType         
                                case 'Add'
                                    % Create a new Dot in this location
                                    ZoomFactor = Isize(1) / CutNumVox(1);
                                    brushSizeScaled = brushSize * ZoomFactor;                                
                                    addDot(absX, absY, brushSizeScaled);                                
                                
                                case 'Select'
                                    % Locate position of points in respect to zoom area
                                    PosZoomX = PosX - Isize(2)-1;
                                    PosZoomX = round(PosZoomX * CutNumVox(2)/(Isize(2)-1));                
                                    PosZoomY = Isize(1) - PosY;
                                    PosZoomY = CutNumVox(1)-round(PosZoomY*CutNumVox(1)/(Isize(1)-1));
                                    PosZoom = [PosZoomX, PosZoomY];

                                    % Select the Dot below mouse pointer
                                    set(fig_handle, 'CurrentAxes', axes_handle);
                                    Iframe = I(:,:,frame);
                                    Iframe = cat(3, Iframe, Iframe, Iframe); % Create an RGB version of I

                                    SelObjID = redraw(frame_handle, rect_handle, frame, chkShowObjects.Value, Pos, PosZoom, Iframe, CutNumVox, Dots, Dots.Filter, 0, 'right', chkShowAllZ.Value);
                                    if SelObjID > 0
                                        set(lstDots, 'Value', SelObjID);
                                    end
                                    return
                            end
                        end
                    end
                    
                    scroll(frame, 'right');
                end
        end
	end

	function scroll(new_f, WhichPanel)
        if new_f < 1 || new_f > nFrames
            return
        end
        
    	% Move scroll bar to new position
        if new_f ~= frame
            % Update current frame
            frame = new_f;
            Iframe = I(:,:,frame);
            Iframe = cat(3, Iframe, Iframe, Iframe); % Create an RGB version of I
            
        end

        scroll_x = (frame - 1) / nFrames;
        set(scroll_handle, 'XData', scroll_x + [0 1 1 0] * scroll_bar_width);
        
        %set to the right axes and call the custom redraw function
        set(fig_handle, 'CurrentAxes', axes_handle);
        set(fig_handle,'DoubleBuffer','off');


        switch WhichPanel
            case 'both',  [SelObjID, frame_handle, rect_handle] = redraw(frame_handle, rect_handle, frame, chkShowObjects.Value, Pos, PosZoom, Iframe, CutNumVox, Dots, Dots.Filter, SelObjID, 'both', chkShowAllZ.Value);
            case 'left',  [SelObjID, frame_handle, rect_handle] = redraw(frame_handle, rect_handle, frame, chkShowObjects.Value, Pos, PosZoom, Iframe, CutNumVox, Dots, Dots.Filter, SelObjID, 'left', chkShowAllZ.Value);                
            case 'right', [SelObjID, frame_handle, rect_handle] = redraw(frame_handle, rect_handle, frame, chkShowObjects.Value, Pos, PosZoom, Iframe, CutNumVox, Dots, Dots.Filter, SelObjID, 'right', chkShowAllZ.Value);                
        end        
        
        if numel(SelObjID) == 1 && SelObjID > 0
            set(txtSelObjID     ,'string',['ID#: '          num2str(SelObjID)]);
            set(txtSelObjPos,'string',['Pos X:' num2str(Dots.Pos(SelObjID,1)) ', Y:' num2str(Dots.Pos(SelObjID,2)) ', Z:' num2str(Dots.Pos(SelObjID,3))]);
            set(txtSelObjPix,'string',['Volume : ' num2str(numel(Dots.Vox(SelObjID).Ind))]);
        else
            set(txtSelObjID     ,'string','ID#: '       );
            set(txtSelObjPos    ,'string','Pos : '    );
            set(txtSelObjPix    ,'string','Volume : '   );
        end
    end
end

function [SelObjID, image_handle, navi_handle] = redraw(image_handle, navi_handle, frameNum, ShowObjects, Pos, PosZoom, F, NaviRectSize, Dots, passF, SelectedObjIDs, WhichPanel, ShowAllZ)
%% Redraw function, full image on left panel, zoomed area on right panel
% Note: Pos(1), PosZoom(1) is X
% Dots.Pos(:,1), I(1), PostCut(1), NaviRectSize(1) = Y
%tic;

SelObjID        = 0;
SelObjColor     = uint8([255 255 0])'; % Yellow
ValObjColor     = uint8([0 255 0])'; % Green
RejObjColor     = uint8([255 0 0])'; % Red

PostCut         = ones(NaviRectSize(1), NaviRectSize(2), 3, 'uint8');
PostCutResized  = zeros(size(F,1), size(F,2), 3, 'uint8');
PostVoxMapCut   = PostCut;

if (Pos(1) > 0) && (Pos(2) > 0) && (Pos(1) < size(F,2)) && (Pos(2) < size(F,1))
    % Find borders of the area to zoom according to passed mouse position
    fxmin = max(ceil(Pos(1) - NaviRectSize(2)/2)+1, 1);
    fxmax = min(ceil(Pos(1) + NaviRectSize(2)/2), size(F,2));
    fymin = max(ceil(Pos(2) - NaviRectSize(1)/2)+1, 1);
    fymax = min(ceil(Pos(2) + NaviRectSize(1)/2), size(F,1));
    fxpad = NaviRectSize(2) - (fxmax - fxmin); % padding if out of image
    fypad = NaviRectSize(1) - (fymax - fymin); % padding if out of image
    
    % Find indeces of objects visible within the zoomed area
    valIcut = passF;
    rejIcut = ~passF;
    for i = 1:numel(valIcut)
        valIcut(i) = valIcut(i) && Dots.Pos(i,2)>=fxmin && Dots.Pos(i,2)<=fxmax && Dots.Pos(i,1)>=fymin && Dots.Pos(i,1)<=fymax;
        rejIcut(i) = rejIcut(i) && Dots.Pos(i,2)>=fxmin && Dots.Pos(i,2)<=fxmax && Dots.Pos(i,1)>=fymin && Dots.Pos(i,1)<=fymax;
    end
    ValObjIDs = find(valIcut); % IDs of valid objects within field of view  
    RejObjIDs = find(rejIcut); % IDs of rejected objects within field of view 
    
    % Concatenate objects lists depending on whether they are in columns or rows
    if size(ValObjIDs,1) == 1
        VisObjIDs = [ValObjIDs, RejObjIDs]; % IDs of objects within field of view 
    else
        VisObjIDs = [ValObjIDs; RejObjIDs]; % IDs of objects within field of view 
    end
    
    % Flag valid and rejected object IDs within zoomed area    
    for i=1:numel(ValObjIDs)
        VoxPos = Dots.Vox(ValObjIDs(i)).Pos;
        for j = 1:size(VoxPos,1)
            if VoxPos(j,3) ~= frameNum && ~ShowAllZ
                continue
            elseif VoxPos(j,2)>=fxmin && VoxPos(j,2)<=fxmax && VoxPos(j,1)>=fymin && VoxPos(j,1)<=fymax                
                PostVoxMapCut(VoxPos(j,1)+fypad-fymin,VoxPos(j,2)+fxpad-fxmin, :) = ValObjColor;
            end
        end
    end
    for i=1:numel(RejObjIDs)
        VoxPos = Dots.Vox(RejObjIDs(i)).Pos;
        for j = 1:size(VoxPos,1)
            if VoxPos(j,3) ~= frameNum && ~ShowAllZ
                continue
            elseif VoxPos(j,2)>=fxmin && VoxPos(j,2)<=fxmax && VoxPos(j,1)>=fymin && VoxPos(j,1)<=fymax
                PostVoxMapCut(VoxPos(j,1)+fypad-fymin,VoxPos(j,2)+fxpad-fxmin,:) = RejObjColor;
            end
        end
    end
    
    if ~isempty(SelectedObjIDs) && (numel(SelectedObjIDs)>1 || SelectedObjIDs > 0)
        % If user requested objects within the zoomed region, select them
        
        SelObjID = SelectedObjIDs;        
        for i = 1: numel(SelectedObjIDs)
            VoxPos = Dots.Vox(SelectedObjIDs(i)).Pos;
            %disp(['SelectedObjID: ' num2str(SelectedObjIDs(i))]);
            for j = 1:size(VoxPos,1)
                if VoxPos(j,3) ~= frameNum && ~ShowAllZ
                    continue
                elseif VoxPos(j,2)>=fxmin && VoxPos(j,2)<=fxmax && VoxPos(j,1)>=fymin && VoxPos(j,1)<=fymax            
                    PostVoxMapCut(VoxPos(j,1)+fypad-fymin,VoxPos(j,2)+fxpad-fxmin, :) = SelObjColor;
                end
            end
        end
    elseif PosZoom(1) > 0 && PosZoom(2) > 0
        % If user queried for objects at a specific location coordinates
        %disp(['X:' num2str(PosZoom(1)) ' Y:' num2str(PosZoom(2)) ' xmin:' num2str(fxmin) ' ymin:' num2str(fymin)]);
        absX = fxpad+fxmin+PosZoom(1)-2;            
        absY = fypad+fymin+PosZoom(2)-2;
        for i=1:numel(VisObjIDs)
            VoxPos  = Dots.Vox(VisObjIDs(i)).Pos;
            for j = 1:size(VoxPos,1)   
                if VoxPos(j,3) ~= frameNum && ~ShowAllZ
                    continue
                elseif VoxPos(j,1)==absY && VoxPos(j,2)==absX
                    SelObjID = VisObjIDs(i); % Return ID of selected object
                    for k = 1:size(VoxPos,1)
                        if VoxPos(k,3) ~= frameNum && ~ShowAllZ
                            continue
                        elseif VoxPos(k,2)>=fxmin && VoxPos(k,2)<=fxmax && VoxPos(k,1)>=fymin && VoxPos(k,1)<=fymax
                            PostVoxMapCut(VoxPos(k,1)+fypad-fymin, VoxPos(k,2)+fxpad-fxmin, :) = SelObjColor;
                        end
                    end
                    break
                end
            end
        end
        
    end
    
    % Draw the right panel containing a zoomed version of selected area
    PostCut(fypad : fypad+fymax-fymin, fxpad : fxpad+fxmax-fxmin,:) = F(fymin:fymax, fxmin:fxmax, :);
    if ShowObjects
        PostCutResized = imresize(PostCut.*PostVoxMapCut,[size(F,1), size(F,2)], 'nearest');
    else
        PostCutResized = imresize(PostCut,[size(F,1), size(F,2)], 'nearest');        
    end
    
    % Separate left and right panel visually with a vertical line
    PostCutResized(1:end, 1:4, 1:3) = 75;
end

if image_handle == 0
    % Draw the full image if it is the first time
    image_handle = image(cat(2, F, PostCutResized));
    axis image off
    % Draw a rectangle border over the selected area (left panel)
    navi_handle = rectangle(gca, 'Position',[fxmin,fymin,NaviRectSize(2),NaviRectSize(1)],'EdgeColor', [1 1 0],'LineWidth',2,'LineStyle','-');
else
    % If we already drawn the image once, just update WhichPanel is needed
    switch  WhichPanel       
        case 'both'
            CData = get(image_handle, 'CData');
            CData(:, 1:size(CData,2)/2,:) = F; % redraw left panel
            CData(:, size(CData,2)/2+1:size(CData,2),:) = PostCutResized; % redraw right panel
            set(image_handle, 'CData', CData);   
            set(navi_handle, 'Position',[fxmin,fymin,NaviRectSize(2),NaviRectSize(1)]);
        case 'left'            
            set(navi_handle, 'Position',[fxmin,fymin,NaviRectSize(2),NaviRectSize(1)]);
        case 'right'
            CData = get(image_handle, 'CData');
            CData(:, size(CData,2)/2+1:size(CData,2),:) = PostCutResized;
            set(image_handle, 'CData', CData);   
    end
end
%disp(num2str(toc));
end

function [ShapeCData, HotSpot] = getPointerCrosshair
    %% Custom mouse crosshair pointer sensitive at arms intersection point 
    ShapeCData          = zeros(32,32);
    ShapeCData(:,:)     = NaN;
    ShapeCData(15:17,:) = 1;
    ShapeCData(:, 15:17)= 1;
    ShapeCData(16,:)    = 2;
    ShapeCData(:, 16)   = 2;
    HotSpot             = [16,16];
end