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
function Mask = segmentVolume2D(I)

    % Default parameter values
    CutNumVox  = size(I); % Magnify a zoom region of this size
    Isize      = size(I);
    Mask       = zeros(Isize, 'uint8');
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
    Mframe     = Mask(:,:,frame);
    SelObjID   = 0;
    brushSize  = ceil(Isize(1)/50);
    thresh     = 0;
	
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
    pnlSettings     = uipanel('Title','Segmentation tools','Units','normalized','Position',[.003,.005,.195,.99]); %#ok, unused variable
    cmbAction       = uicontrol('Style','popup'     ,'Units','normalized','Position',[.010,.920,.180,.04],'String', {'Add', 'Select'}, 'tooltip', 'Current Action','Callback', @cmbAction_changed);    
    chkShowObjects  = uicontrol('Style','checkbox'  ,'Units','normalized','position',[.007,.900,.090,.02],'String','Show/Hide', 'Value',1, 'tooltip', 'Color Objects (spacebar)','Callback',@chkShowObjects_changed);
    chkShowAllZ     = uicontrol('Style','checkbox'  ,'Units','normalized','position',[.110,.900,.080,.02],'String','Ignore Z', 'Value',1,'Callback',@chkShowAllZ_changed);

    % Primary filter parameter controls
    txtFilter       = uicontrol('Style','text'      ,'Units','normalized','position',[.007,.835,.185,.02],'String','Threshold'); %#ok, unused variable   
    cmbFilterType   = uicontrol('Style','popup'     ,'Units','normalized','Position',[.007,.790,.140,.04],'String', {'Disabled', 'Simple Threshold'},'Callback', @cmbFilterType_changed);  
    cmbFilterDir    = uicontrol('Style','popup'     ,'Units','normalized','Position',[.150,.790,.045,.04],'String', {'>=', '<='}, 'Visible', 'off'  ,'callback',@cmbFilterDir_changed);            
    btnMinus        = uicontrol('Style','Pushbutton','Units','normalized','position',[.007,.755,.045,.04],'String','-','Visible','off'              ,'CallBack',@btnMinus_clicked);    
    txtThresh       = uicontrol('Style','edit'      ,'Units','normalized','Position',[.053,.755,.091,.04],'String',num2str(thresh),'Visible', 'off' ,'CallBack',@txtThresh_changed);
    btnPlus         = uicontrol('Style','Pushbutton','Units','normalized','position',[.145,.755,.045,.04],'String','+','Visible', 'off'             ,'CallBack',@btnPlus_clicked);    

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
    
    Dots.Name = '';
    Dots.Pos = [];
    Dots.Vox = [];
    Dots.Filter = [];    

    scroll(frame, 'right');
    uiwait;
    
    function cmbFilterDir_changed(src,event) %#ok, unused arguments
        applyFilter(thresh);
        simulatedClick = true;        
        SimulateClick;
        simulatedClick = false;         
    end
    
    function btnPlus_clicked(src, event) %#ok, unused arguments
        new_thresh = min(thresh + 1, 255);
        set(txtThresh,'string',num2str(new_thresh));
        applyFilter(new_thresh);
    end

    function btnMinus_clicked(src, event) %#ok, unused arguments
        new_thresh = max(thresh - 1, 0);
        set(txtThresh,'string',num2str(new_thresh));
        applyFilter(new_thresh);
    end

    function txtThresh_changed(src, event) %#ok, unused arguments
        thresh_str = get(src,'String');
        applyFilter(str2double(thresh_str);
    end

    function cmbFilterType_changed(src, event) %#ok, unused arguments
        switch get(src,'Value')
            case 1 % None
                new_thresh = 0;
                set(cmbFilterDir,'Visible','off');
                set(txtThresh,'Visible','off');
                set(btnPlus,'Visible','off');
                set(btnMinus,'Visible','off');
            case 2 % Simple Threshold
                try
                    new_thresh = round(mean(I(:)));
                    set(cmbFilterDir,'Value', 0);
                end
                set(cmbFilterDir,'Visible','on');
                set(txtThresh,'Visible','on');
                set(btnPlus,'Visible','on');
                set(btnMinus,'Visible','on');                
        end
        applyFilter(new_thresh);
        set(txtThresh,'string',num2str(new_thresh));        
    end

    function applyFilter(new_thresh)
        thresh = new_thresh;
        % Apply primary filter criteria if selected        
        switch get(cmbFilterType,'Value')
            case 1 % None, reset all thresholds
            case 2 % Simple Threshld
                Mask = uint8(I > thresh);
        end
        
        scroll(frame, 'right');
        simulatedClick = true;        
        SimulateClick;
        simulatedClick = false;        
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
        FileName = [Path filesep 'Mask.tif'];
        saveastiff(M, FileName);
        msgbox('Fiducial points saved.', 'Screenshot', 'help');
    end

    function btnLoad_clicked(src, event) %#ok, unused arguments
        FileName = uigetfile('*.mat');
        M = loadImageStack(FileName);
        scroll(frame, 'right');
        msgbox('Mask Loaded.', 'Complete', 'help');
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

                                    SelObjID = redraw(frame_handle, rect_handle, chkShowObjects.Value, Pos, Iframe, CutNumVox, Mask, 'right');
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
            Mframe = Mask(:,:,frame);
        end

    	% Move scroll bar to new position
        scroll_x = (frame - 1) / nFrames;
        set(scroll_handle, 'XData', scroll_x + [0 1 1 0] * scroll_bar_width);
        set(fig_handle, 'Name', ['Slice ' num2str(frame) '/' num2str(nFrames) ' - Zoom:' num2str(10*ceil(10*Isize(1)/CutNumVox(1)),'%u') '%']);        
        
        %set to the right axes and call the custom redraw function
        set(fig_handle, 'CurrentAxes', axes_handle);
        switch WhichPanel
            case 'left',  [frame_handle, rect_handle] = redraw(frame_handle, rect_handle, chkShowObjects.Value, Pos, Iframe, CutNumVox, Mframe, 'left');                
            case 'right', [frame_handle, rect_handle] = redraw(frame_handle, rect_handle, chkShowObjects.Value, Pos, Iframe, CutNumVox, Mframe, 'right');                
        end                
    end
end

function [image_handle, navi_handle] = redraw(image_handle, navi_handle, ShowObjects, Pos, F, NaviRectSize, M, WhichPanel)
%% Redraw function, full image on left panel, zoomed area on right panel
% Note: Pos(1), PosZoom(1) is X
% Dots.Pos(:,1), I(1), PostCut(1), NaviRectSize(1) = Y

PostCut         = ones(NaviRectSize(1), NaviRectSize(2), 3, 'uint8');
MaskColorize    = PostCut;

if (Pos(1) > 0) && (Pos(2) > 0) && (Pos(1) < size(F,2)) && (Pos(2) < size(F,1))
    % Find borders of the area to zoom according to passed mouse position
    fxmin = max(ceil(Pos(1) - NaviRectSize(2)/2)+1, 1);
    fxmax = min(ceil(Pos(1) + NaviRectSize(2)/2), size(F,2));
    fymin = max(ceil(Pos(2) - NaviRectSize(1)/2)+1, 1);
    fymax = min(ceil(Pos(2) + NaviRectSize(1)/2), size(F,1));
    fxpad = NaviRectSize(2) - (fxmax - fxmin); % padding if out of image
    fypad = NaviRectSize(1) - (fymax - fymin); % padding if out of image
            
    % Draw in Purple/Green voxels on either side of fitted surface
    if ~isempty(M)
        Mask = uint8(cat(3, ~M, M, ~M));
        MaskColorize = Mask(fypad : fypad+fymax-fymin, fxpad : fxpad+fxmax-fxmin,:);
    end
        
    % Draw the right panel containing a zoomed version of selected area
    PostCut(fypad : fypad+fymax-fymin, fxpad : fxpad+fxmax-fxmin,:) = F(fymin:fymax, fxmin:fxmax, :);
    if ShowObjects
        PostCutResized = imresize(PostCut.*MaskColorize,[size(F,1), size(F,2)], 'nearest');
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
    
    pause(0.1);
end