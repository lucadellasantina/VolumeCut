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
    CutNumVox  = size(I); % Magnify a zoom region of this size
    Isize      = size(I);
    nFrames    = Isize(3);
    Surface    = [];
    actionType = 'Add';

    Pos        = ceil([Isize(2)/2, Isize(1)/2, Isize(3)/2]); % Initial position is middle of the stack
    PosRect    = ceil([Isize(2)/2-CutNumVox(2)/2, Isize(1)/2-CutNumVox(1)/2]); % Initial position of zoomed rectangle (top-left vertex)
    PosZoom    = [-1, -1, -1];
    click      = 0; % 0: no click, 1:clicked scrollbar, 2:anywhere else
    frame      = ceil(nFrames/2); % Current frame
    Iframe     = I(:,:,frame);
    Iframe     = cat(3,Iframe,Iframe,Iframe);
    SelObjID   = 0;
    brushSize  = ceil(Isize(1)/50);
	
    % Load icons
    IconZoomIn      = imread('48px-Zoom-in.png');
    IconZoomOut     = imread('48px-Zoom-out.png');
    IconZoomFit     = imread('48px-Zoom-fit.png');    
    IconSurface     = imread('48px-fitsurface.png');    
    IconDelete      = imread('48px-delete.png');    
    IconLoad        = imread('48px-open.png');    
    IconScreenshot  = imread('48px-screenshot.png'); 
    IconSave        = imread('48px-floppy.png');
    IconMoveUp      = imread('48px-up.png');
    IconMoveDown    = imread('48px-down.png');
    IconMoveLeft    = imread('48px-left.png');
    IconMoveRight   = imread('48px-right.png');
    IconMoveCenter  = imread('48px-center.png');
    
	% Initialize GUI
    % MATLAB Bug workaround: need to resize window under units=pixels 
    % and by multiple of 2 in order for mouse pointer location to read correctly
    screen = get(0,'ScreenSize');
    window_sz = ceil([screen(3)/4 screen(4)/4 screen(3)/2 screen(4)*3/4]);
    
    fig_handle = figure('NumberTitle','off','Color',[.3 .3 .3],...
        'MenuBar','none', 'Units','pixels', 'Position', window_sz,...
		'WindowButtonDownFcn', @button_down, 'WindowButtonUpFcn',@button_up,...
        'WindowButtonMotionFcn', @on_click, 'KeyPressFcn', @key_press,...
        'KeyReleaseFcn', @key_release, 'windowscrollWheelFcn', @wheel_scroll);
    
	% Add custom scroll bar
	scroll_axes = axes('Parent',fig_handle, 'Position',[0.2 0 0.8 0.045],...
        'Visible','off', 'Units', 'normalized');
	axis([0 1 0 1]); 
    axis off;
	scroll_bar_width = max(1 / nFrames, 0.01);
	scroll_handle = patch([0 1 1 0] * scroll_bar_width, [0 0 1 1], [.8 .8 .8], 'Parent',scroll_axes, 'EdgeColor','none', 'ButtonDownFcn', @on_click);

    % Add GUI conmponents
    pnlSettings     = uipanel('Title','Objects'     ,'Units','normalized','Position',[.003,.005,.195,.99]); %#ok, unused variable
    cmbAction       = uicontrol('Style','popup'     ,'Units','normalized','Position',[.010,.920,.180,.04],'String', {'Add', 'Select'}, 'tooltip', 'Current Action','Callback', @cmbAction_changed);    
    txtValidObjs    = uicontrol('Style','text'      ,'Units','normalized','position',[.007,.890,.185,.02],'String',['Valid: ' num2str(numel(find(Dots.Filter)))]);
    txtSelObjID     = uicontrol('Style','text'      ,'Units','normalized','position',[.007,.865,.185,.02],'String','Object#: N/A');
    txtSelObjPos    = uicontrol('Style','text'      ,'Units','normalized','position',[.007,.840,.185,.02],'String','Volume: N/A');
    chkShowObjects  = uicontrol('Style','checkbox'  ,'Units','normalized','position',[.007,.800,.090,.02],'String','Show/Hide', 'Value',1, 'tooltip', 'Color Objects (spacebar)','Callback',@chkShowObjects_changed);
    chkShowAllZ     = uicontrol('Style','checkbox'  ,'Units','normalized','position',[.110,.800,.080,.02],'String','Ignore Z', 'Value',1,'Callback',@chkShowAllZ_changed);
    lstDots         = uicontrol('Style','listbox'   ,'Units','normalized','position',[.007,.570,.185,.22],'String',[],'Callback',@lstDots_valueChanged);    

    btnLoad         = uicontrol('Style','Pushbutton','Units','normalized','position',[.007,.490,.060,.07],'cdata',IconLoad,    'tooltip', 'Load Objects','Callback',@btnLoad_clicked); %#ok, unused variable
    btnDelete       = uicontrol('Style','Pushbutton','Units','normalized','position',[.069,.490,.060,.07],'cdata',IconDelete,  'tooltip', 'Delete Object','Callback',@btnDelete_clicked); %#ok, unused variable
    btnFitSurf      = uicontrol('Style','Pushbutton','Units','normalized','position',[.132,.490,.060,.07],'cdata',IconSurface, 'tooltip', 'Fit Surface','Callback',@btnFitSurface_clicked); %#ok, unused variable

    btnMoveLeft     = uicontrol('Style','Pushbutton','Units','normalized','position',[.007,.320,.060,.07],'cdata',IconMoveLeft,  'tooltip', 'Move Left (a)','Callback',@move_left); %#ok, unused variable
    btnMoveUp       = uicontrol('Style','Pushbutton','Units','normalized','position',[.069,.390,.060,.07],'cdata',IconMoveUp,    'tooltip', 'Move Up (w)','Callback',@move_up); %#ok, unused variable
    btnMoveCenter   = uicontrol('Style','Pushbutton','Units','normalized','position',[.069,.320,.060,.07],'cdata',IconMoveCenter,'tooltip', 'Move to Center','Callback',@move_center); %#ok, unused variable
    btnMoveDown     = uicontrol('Style','Pushbutton','Units','normalized','position',[.069,.250,.060,.07],'cdata',IconMoveDown,  'tooltip', 'Move Down (s)','Callback',@move_down); %#ok, unused variable
    btnMoveRight    = uicontrol('Style','Pushbutton','Units','normalized','position',[.132,.320,.060,.07],'cdata',IconMoveRight, 'tooltip', 'Move Right (d)','Callback',@move_right); %#ok, unused variable
        
    btnZoomIn       = uicontrol('Style','Pushbutton','Units','normalized','position',[.007,.130,.060,.07],'cdata',IconZoomIn,   'tooltip', 'Zoom In (+)','Callback',@btnZoomIn_clicked); %#ok, unused variable
    btnZoomOut      = uicontrol('Style','Pushbutton','Units','normalized','position',[.069,.130,.060,.07],'cdata',IconZoomOut,  'tooltip', 'Zoom Out (-)','Callback',@btnZoomOut_clicked); %#ok, unused variable
    btnZoomFit      = uicontrol('Style','Pushbutton','Units','normalized','position',[.132,.130,.060,.07],'cdata',IconZoomFit,  'tooltip', 'Full Image','Callback',@btnZoomFit_clicked); %#ok, unused variable

    btnSave         = uicontrol('Style','Pushbutton','Units','normalized','position',[.040,.015,.060,.07],'cdata',IconSave, 'tooltip', 'Save Points','Callback',@btnSave_clicked); %#ok, unused variable    
    btnSnapshot     = uicontrol('Style','Pushbutton','Units','normalized','position',[.102,.015,.060,.07],'cdata',IconScreenshot, 'tooltip', 'Take a Screenshot','Callback',@btnSnapshot_clicked); %#ok, unused variable
    
	% Main drawing and related handles
	axes_handle     = axes('Position',[0.2 0.05 .80 .94]);
	frame_handle    = 0;
    rect_handle     = 0;
    PosMouse        = [0,0]; % mouse pointer position in screen coordinates
    Hotkey          = {}; % Contains 'control, 'alt', 'shift'
    brush           = rectangle(axes_handle,'Curvature', [1 1],'EdgeColor', [1 1 0],'LineWidth',2,'LineStyle','-');
    simulatedClick  = false; % if true the current click is simulated by SimulateClick function
    cmbAction_assign(actionType);

    lstDotsRefresh;    
    scroll(frame, 'right');
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
        else
            set(txtSelObjID    ,'string','ID#: ');
            set(txtSelObjPos   ,'string','Pos : ');
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
            simulatedClick = true;        
            SimulateClick;
            simulatedClick = false;         
            scroll(Dots.Pos(SelObjID,3), 'right');
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
        simulatedClick = true;        
        SimulateClick;
        simulatedClick = false; 
    end

    function cmbAction_assign(newType)
        switch newType
            case 'Add', set(cmbAction, 'Value', 1);
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
        if CutNumVox == Isize(1:2)
            % disp('full image');
            Pos = [ceil(Isize(2)/2), ceil(Isize(1)/2), frame];
            PosRect = [max(1,Pos(1)-CutNumVox(2)/2), max(1,Pos(2)-CutNumVox(1)/2)];                   
        else
            Pos       = [min(Pos(1),Isize(2)-CutNumVox(2)/2), min(Pos(2),Isize(1)-CutNumVox(1)/2), frame];       
            PosRect   = [max(1,Pos(1)-CutNumVox(2)/2), max(1,Pos(2)-CutNumVox(1)/2)];
        end
        PosZoom   = [-1, -1, -1];
        scroll(frame, 'left');
        pause(0.5);
        scroll(frame, 'right');
        simulatedClick = true;
        SimulateClick;
        simulatedClick = false;        
    end

    function btnZoomFit_clicked(src, event) %#ok, unused arguments        
        % Ensure new zoomed region is still within image borders
        CutNumVox = Isize;
        Pos = [ceil(Isize(2)/2), ceil(Isize(1)/2), frame];
        PosRect = [max(1,Pos(1)-CutNumVox(2)/2), max(1,Pos(2)-CutNumVox(1)/2)];
        PosZoom   = [-1, -1, -1];
        scroll(frame, 'left');
        pause(0.5);
        scroll(frame, 'right');
        simulatedClick = true;        
        SimulateClick;
        simulatedClick = false;
    end

    function btnZoomIn_clicked(src, event) %#ok, unused arguments
        CutNumVox = [max(round(CutNumVox(1)/2), 32), max(round(CutNumVox(2)/2),32)];
        PosRect   = [max(1,Pos(1)-round(CutNumVox(2)/2)), max(1,Pos(2)-round(CutNumVox(1)/2))];        
        PosZoom   = [-1, -1, -1];
        scroll(frame, 'left');
        pause(0.5);
        scroll(frame, 'right');
        simulatedClick = true;        
        SimulateClick;
        simulatedClick = false;          
    end

    function btnFitSurface_clicked(src, event) %#ok, unused arguments
        if isempty(Dots.Pos)
            return
        end
        
        tic;
        disp('Fitting surface...');

        x       = Dots.Pos(:,1);
        y       = Dots.Pos(:,2);
        z       = Dots.Pos(:,3);
        Surface = surfacefit(x,y,z, 1:4:Isize(1), 1:4:Isize(2));
        Surface = imresize(Surface, [size(I,1), size(I,2)]);
        
        disp(['Surface fitted in:' num2str(toc) ' seconds']);
        scroll(frame, 'right');
    end

    function btnSnapshot_clicked(src, event) %#ok, unused arguments
        % Retrieve and tile the current Zoomed Fullsize images
        CData = get(frame_handle, 'CData');
        Screenshot = cat(2,Iframe,CData);
        
        % Highight the zoomed region in the full-size image
        Screenshot = insertShape(Screenshot, 'rectangle', [PosRect(1), PosRect(2), CutNumVox(1), CutNumVox(2)]);

        % Save screenshot into Results folder with current date & time
        Path = uigetdir;
        FileName = [Path filesep 'Screenshot_' datestr(now, 'yyyy-mm-dd_HH-MM_AM') '.tif'];
        imwrite(Screenshot, FileName);
        msgbox(['Screenshot saved in: ' FileName], 'Saved', 'help');
    end

    function btnSave_clicked(src, event) %#ok, unused arguments
        Path = uigetdir;
        FileName = [Path filesep Dots.Name '.mat'];
        save(FileName, '-struct', 'Dots');
        msgbox('Fiducial points saved.', 'Screenshot', 'help');
    end

    function btnLoad_clicked(src, event) %#ok, unused arguments
        FileName = uigetfile('*.mat');
        Dots = load(FileName);
        lstDotsRefresh;
        scroll(frame, 'right');
        msgbox('Fiducial points Loaded.', 'Complete', 'help');
    end

    function wheel_scroll(src, event) %#ok, unused arguments
        if ~isempty(Hotkey) && contains(Hotkey, 'shift')
            WhichPanel = 'left';
        else
            WhichPanel = 'right';
        end
        
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
            PosXfenced = max(0, min(PosMouse(1)-brushSizeScaled/2, Isize(2)*2-brushSizeScaled-2));
            PosYfenced = max(0, min(PosMouse(2)-brushSizeScaled/2, Isize(1)*2-brushSizeScaled-2));
            brushPos = [PosXfenced, PosYfenced, brushSizeScaled, brushSizeScaled];
            
            if ~isvalid(brush)
                brush = rectangle(axes_handle,'Position', brushPos,'Curvature',[1 1],'EdgeColor',[1 1 0],'LineWidth',2,'LineStyle','-');
            else
                set(brush, 'Position',  brushPos);
            end
            click = false;
        else  
            % Scroll to the next slice
            
            if event.VerticalScrollCount < 0
                %position = get(scroll_handle, 'XData');
                %disp(position);
                scroll(frame+1, WhichPanel); % Scroll up
            elseif event.VerticalScrollCount > 0
                scroll(frame-1, WhichPanel); % Scroll down
            end
        end
    end

    function move_center(src, event) %#ok, unused arguments
        Pos = [ceil(Isize(2)/2), ceil(Isize(1)/2), frame];
        PosRect = [max(1,Pos(1)-CutNumVox(2)/2), max(1,Pos(2)-CutNumVox(1)/2)];        
        PosZoom = [-1, -1, -1];
        scroll(frame, 'left');
        pause(0.5);
        scroll(frame, 'right');        

        simulatedClick = true;
        SimulateClick;
        simulatedClick = false;        
    end

    function move_left(src, event) %#ok, unused arguments
        Pos = [max(CutNumVox(2)/2, Pos(1)-CutNumVox(1)+ceil(CutNumVox(2)/5)), Pos(2),frame];
        PosRect = [max(1,Pos(1)-CutNumVox(2)/2), max(1,Pos(2)-CutNumVox(1)/2)];        
        PosZoom = [-1, -1, -1];
        scroll(frame, 'left');
        pause(0.5);
        scroll(frame, 'right');        

        simulatedClick = true;
        SimulateClick;
        simulatedClick = false;        
    end

    function move_right(src, event) %#ok, unused arguments
        Pos = [min(Isize(2)-1-CutNumVox(2)/2, Pos(1)+CutNumVox(2)-ceil(CutNumVox(2)/5)), Pos(2),frame];
        PosRect = [max(1,Pos(1)-CutNumVox(2)/2), max(1,Pos(2)-CutNumVox(1)/2)];        
        PosZoom = [-1, -1, -1];
        scroll(frame, 'left');
        pause(0.5);
        scroll(frame, 'right');

        simulatedClick = true;
        SimulateClick;
        simulatedClick = false;        
    end

    function move_up(src, event) %#ok, unused arguments
        Pos = [Pos(1), max(CutNumVox(1)/2, Pos(2)-CutNumVox(1)+ceil(CutNumVox(1)/5)),frame];
        PosRect = [max(1,Pos(1)-CutNumVox(2)/2), max(1,Pos(2)-CutNumVox(1)/2)];        
        PosZoom = [-1, -1, -1];
        scroll(frame, 'left');
        pause(0.5);
        scroll(frame, 'right');

        simulatedClick = true;
        SimulateClick;
        simulatedClick = false;        
    end

    function move_down(src, event) %#ok, unused arguments
        Pos = [Pos(1), min(Isize(1)-1-CutNumVox(1)/2, Pos(2)+CutNumVox(1)-ceil(CutNumVox(1)/5)),frame];
        PosRect = [max(1,Pos(1)-CutNumVox(2)/2), max(1,Pos(2)-CutNumVox(1)/2)];        
        PosZoom = [-1, -1, -1];
        scroll(frame, 'left');
        pause(0.5);
        scroll(frame, 'right');        

        simulatedClick = true;
        SimulateClick;
        simulatedClick = false;        
    end

    function key_press(src, event) %#ok, unused arguments
        %event.Key % displays the name of the pressed key
        if isempty(Hotkey) && ~isempty(event.Modifier) && contains(event.Modifier, 'shift')
            scroll(frame, 'left'); % User started pressing Shift, switch to navigator view
        end
        Hotkey = event.Modifier;
        
        
        switch event.Key  % Process shortcut keys
            case 'space'
                chkShowObjects.Value = ~chkShowObjects.Value;
                chkShowObjects_changed();
            case 'v'
                btnToggleValid_clicked();
            case {'leftarrow','a'},  move_left;
            case {'rightarrow','d'}, move_right;
            case {'uparrow','w'},    move_up;
            case {'downarrow','s'},  move_down;
            case 'equal' , btnZoomIn_clicked;
            case 'hyphen', btnZoomOut_clicked;
        end
    end

    function key_release(src, event) %#ok, unused arguments
        if ~isempty(Hotkey) && contains(Hotkey, 'shift') && isempty(event.Modifier)
            scroll(frame, 'right'); % User stopped pressing Shift, switch to zoomed view
        end
        Hotkey = event.Modifier; % Contains 'control, 'alt', 'shift'
    end

	function button_down(src, event)
        if simulatedClick
            return % Do nothing
        end
        
        set(src,'Units','norm');
		click_pos = get(src, 'CurrentPoint');
        set(src,'Units','pixel');
        
        if click_pos(2)<= 0.045 && click_pos(1)>=0.2
            click = 1; % click happened on the scroll bar
            on_click(src,event);
        else
            click = 2; % click happened somewhere else
            on_click(src,event);
        end
	end

	function button_up(src, event)  %#ok, unused arguments
        if simulatedClick
            return % Do nothing
        end        
        click = 0;
	end

	function on_click(src, event)  %#ok, unused arguments
        if simulatedClick
            return % Do nothing
        end
        
        switch click
            case 0 
                % ** Moved mouse without clickling anything **
                
                % Set the proper mouse pointer appearance
                set(fig_handle, 'Units', 'pixels');
                click_point = get(gca, 'CurrentPoint');
                PosX = ceil(click_point(1,1));
                PosY = ceil(click_point(1,2));

                if PosY < 0 || PosY > Isize(1) || PosX < 0 || PosX > Isize(2)
                    % Display the default arrow everywhere else
                    set(fig_handle, 'Pointer', 'arrow');
                    if isvalid(brush), delete(brush); end
                    return;
                end

                if ~isempty(Hotkey) && contains(Hotkey, 'shift')                    
                    % Shift is pressed, display a hand                    
                    set(fig_handle, 'Pointer', 'fleur');
                    if isvalid(brush), delete(brush); end
                    
                else
                    switch actionType
                        case 'Select'
                            % Mouse in Right Panel, act depending of the selected tool
                            [PCData, PHotSpot] = getPointerCrosshair;
                            set(fig_handle, 'Pointer', 'custom', 'PointerShapeCData', PCData, 'PointerShapeHotSpot', PHotSpot, 'Units', 'pixel');

                        case 'Add'
                            % Recreate the brush because frame is redrawn otherwise
                            % just redraw the brush in the new location
                            ZoomFactor = Isize(1) / CutNumVox(1);
                            
                            brushSizeScaled = brushSize * ZoomFactor;
                            PosXfenced = max(1, min(PosX-brushSizeScaled/2, Isize(2)-brushSizeScaled-1));
                            PosYfenced = max(1, min(PosY-brushSizeScaled/2, Isize(1)-brushSizeScaled-1));
                            brushPos = [PosXfenced, PosYfenced, brushSizeScaled, brushSizeScaled];
                            
                            PosMouse = [PosX, PosY];
                            %disp(['X:' num2str(PosX) ' brushX:' num2str(brushPos(1)) ' Y:' num2str(PosY) ' brushY:' num2str(brushPos(2)) ' brushSize:' num2str(brushSizeScaled)]);
                            
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
                            
                            % Make mouse pointer into a crosshair
                            [PCData, PHotSpot] = getPointerCrosshair;
                            set(fig_handle, 'Pointer', 'custom', 'PointerShapeCData', PCData, 'PointerShapeHotSpot', PHotSpot, 'Units', 'pixel');

                    end
                end
                
            case 1 % Clicked on the scroll bar, move to new frame
                
                % Retrieve click position in normalized units
                set(fig_handle, 'Units', 'normalized');
                click_point = get(fig_handle, 'CurrentPoint');
                set(fig_handle, 'Units', 'pixels');
                
                x = (click_point(1)-0.2)/0.8;   % scroll bar size = 0.8 of window and if offset 0.2 to the right                
                new_f = floor(1 + x * nFrames); % get corresponding frame number
                
                if new_f < 1 || new_f > nFrames || new_f == frame
                    return
                end
                set(fig_handle, 'Units', 'pixels');
                scroll(new_f, 'right');
                
            case 2  % User clicked on image
                
                set(fig_handle, 'Units', 'pixels');
                click_point = get(gca, 'CurrentPoint');
                PosX = ceil(click_point(1,1));
                PosY = ceil(click_point(1,2));
                
                if ~isempty(Hotkey) && contains(Hotkey, 'shift') % User holding shift in the LEFT panel
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
                    
                else % User clicked in the zoomed region                    
                    % Detect coordinates of the point clicked in PosZoom
                    % Note: x,y coordinates are inverted in I
                    % Note: x,y coordinates are inverted in CutNumVox
                    PosZoomX = PosX;
                    PosZoomX = ceil(PosZoomX * CutNumVox(2)/(Isize(2)-1));
                    
                    PosZoomY = Isize(1) - PosY;
                    PosZoomY = CutNumVox(1)-ceil(PosZoomY*CutNumVox(1)/(Isize(1)-1));

                    % Do different things depending whether left/right-clicked
                    clickType = get(fig_handle, 'SelectionType');
                    
                    if strcmp(clickType, 'alt')
                        % ** User RIGHT-clicked in the zoomed region **
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
                        % ** User LEFT-clicked in the zoomed region **
                        
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
                                    PosZoomX = PosX;
                                    PosZoomX = round(PosZoomX * CutNumVox(2)/(Isize(2)-1));                
                                    PosZoomY = Isize(1) - PosY;
                                    PosZoomY = CutNumVox(1)-round(PosZoomY*CutNumVox(1)/(Isize(1)-1));
                                    PosZoom = [PosZoomX, PosZoomY];

                                    % Select the Dot below mouse pointer
                                    set(fig_handle, 'CurrentAxes', axes_handle);
                                    Iframe = I(:,:,frame);
                                    Iframe = cat(3, Iframe, Iframe, Iframe); % Create an RGB version of I

                                    SelObjID = redraw(frame_handle, rect_handle, frame, chkShowObjects.Value, Pos, PosZoom, Iframe, CutNumVox, Dots, Dots.Filter, 0, 'right', chkShowAllZ.Value, Surface);
                                    if SelObjID > 0
                                        set(lstDots, 'Value', SelObjID);
                                    end
                                    return
                            end
                        end
                    end
                    
                    if ~isempty(Hotkey) && contains(Hotkey, 'shift')
                        scroll(frame, 'left');
                    else
                        scroll(frame, 'right');
                    end
                end
        end
	end

	function scroll(new_f, WhichPanel)
        if new_f < 1 || new_f > nFrames
            return
        end
        
        if new_f ~= frame
            % Update current frame
            frame = new_f;
            Iframe = I(:,:,frame);
            Iframe = cat(3, Iframe, Iframe, Iframe); % Create an RGB version of I (monochromatic)            
        end

    	% Move scroll bar to new position
        scroll_x = (frame - 1) / nFrames;
        set(scroll_handle, 'XData', scroll_x + [0 1 1 0] * scroll_bar_width);
        set(fig_handle, 'Name', ['Slice ' num2str(frame) '/' num2str(nFrames) ' - Zoom:' num2str(10*ceil(10*Isize(1)/CutNumVox(1)),'%u') '% - Points: ' Dots.Name]);        
        
        %set to the right axes and call the custom redraw function
        set(fig_handle, 'CurrentAxes', axes_handle);
        switch WhichPanel
            case 'left',  [SelObjID, frame_handle, rect_handle] = redraw(frame_handle, rect_handle, frame, chkShowObjects.Value, Pos, PosZoom, Iframe, CutNumVox, Dots, Dots.Filter, SelObjID, 'left', chkShowAllZ.Value, Surface);                
            case 'right', [SelObjID, frame_handle, rect_handle] = redraw(frame_handle, rect_handle, frame, chkShowObjects.Value, Pos, PosZoom, Iframe, CutNumVox, Dots, Dots.Filter, SelObjID, 'right', chkShowAllZ.Value, Surface);                
        end        
        
        if numel(SelObjID) == 1 && SelObjID > 0
            set(txtSelObjID,'string',['Selected: #' num2str(SelObjID)]);
            set(txtSelObjPos,'string',['Pos X:' num2str(Dots.Pos(SelObjID,1)) ', Y:' num2str(Dots.Pos(SelObjID,2)) ', Z:' num2str(Dots.Pos(SelObjID,3))]);            
        else
            set(txtSelObjID,'string','Selected: N/A');
            set(txtSelObjPos,'string','Pos : N/A');
        end
    end
end

function [SelObjID, image_handle, navi_handle] = redraw(image_handle, navi_handle, frameNum, ShowObjects, Pos, PosZoom, F, NaviRectSize, Dots, passF, SelectedObjIDs, WhichPanel, ShowAllZ, Surf)
%% Redraw function, full image on left panel, zoomed area on right panel
% Note: Pos(1), PosZoom(1) is X
% Dots.Pos(:,1), I(1), PostCut(1), NaviRectSize(1) = Y

SelObjID        = 0;
SelObjColor     = uint8([255 255 0])'; % Yellow
ValObjColor     = uint8([0 255 0])';   % Green
RejObjColor     = uint8([255 0 0])';   % Red
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

    % Draw in RejColor all voxels below fitted surface
    if ~isempty(Surf)
        M = Surf>=frameNum;
        SurfMask = uint8(cat(3, M, ~M, M));
        PostVoxMapCut = PostVoxMapCut.*SurfMask(fypad : fypad+fymax-fymin, fxpad : fxpad+fxmax-fxmin,:);
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
end

switch WhichPanel
    case 'left'
        image_handle = image(F);
        navi_handle = rectangle(gca, 'Position',[fxmin,fymin,NaviRectSize(2),NaviRectSize(1)],'EdgeColor', [1 1 0],'LineWidth',2,'LineStyle','-');
    case 'right'
        image_handle = image(PostCutResized);
end
axis image off

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

function SimulateClick
    % Simulates a mouse left left-clicking to bring in the middle of the 
    % main figure and then reposition the mouse back where it was
    import java.awt.Robot;
    import java.awt.event.*;
    
    mouse = Robot;
    ScreenSize = get(0, 'screensize');
    MousePos = get(0, 'PointerLocation');
    MousePos = [MousePos(1,1), ScreenSize(4) - MousePos(1,2)];
    FigPos = get(gcf, 'position');
    mouse.mouseMove(FigPos(1)+FigPos(3)/2, FigPos(2)+FigPos(4)/2);    
    mouse.mousePress(InputEvent.BUTTON1_MASK);
    mouse.mouseRelease(InputEvent.BUTTON1_MASK);
    mouse.mouseMove(MousePos(1), MousePos(2));
end