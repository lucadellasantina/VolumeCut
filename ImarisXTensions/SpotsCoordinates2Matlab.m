%% Instructions
%
%  Send coordinates of Imaris spots to Matlab
%
%  Installation:
%
%  - Copy this file into the XTensions folder in the Imaris installation directory
%  - You will find this function in the Image Processing menu
%
%    <CustomTools>
%      <Menu>
%       <Submenu name="Spots Functions">
%        <Item name="SpotsCoordinates2Matlab" icon="Matlab" tooltip="SpotsCoordinates2Matlab">
%          <Command>Matlab::SpotsCoordinates2Matlab(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpSpots">
%          <Item name="SpotsCoordinates2Matlab" icon="Matlab" tooltip="SpotsCoordinates2Matlab">
%            <Command>Matlab::SpotsCoordinates2Matlab(%i)</Command>
%          </Item>
%        </SurpassComponent>
%        <SurpassComponent name="bpSpots">
%          <Item name="SpotsCoordinates2Matlab" icon="Matlab" tooltip="SpotsCoordinates2Matlab">
%            <Command>Matlab::SpotsCoordinates2Matlab(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>
%
%  
%  Description:
%
%   The User chooses which spots to export, coordinates of spots are
%   represented as rows of the SpotXYZ matrix, [X,Y,Z] 
%   Coordinates are expressed in pixel
%
%% Connect to Imaris Com interface
function SpotsCoordinates2Matlab(aImarisApplicationID)

if ~isa(aImarisApplicationID, 'COM.Imaris_Application')
    vImarisServer = actxserver('ImarisServer.Server');
    vImarisApplication = vImarisServer.GetObject(aImarisApplicationID);
else
    vImarisApplication = aImarisApplicationID;
end
%% Start Imaris from matlab and make it visible (comment before saving)
%   vImarisApplication=actxserver('Imaris.Application');
%    vImarisApplication.mVisible=true;
  

%% the user has to create a scene 
vSurpassScene = vImarisApplication.mSurpassScene;
if isequal(vSurpassScene, [])
    msgbox('Please create a Surpass scene!');
    return;
end

%% get image size and pixel resolution
tmpDataset = vImarisApplication.mDataset; %get the dataset to retrieve size/resolution
xs = tmpDataset.mSizeX; %X size in pixel
ys = tmpDataset.mSizeY; %Y size in pixel
zs = tmpDataset.mSizeZ; %Z size in pixel
xsReal = tmpDataset.mExtendMaxX - tmpDataset.mExtendMinX; %X size in micron
ysReal = tmpDataset.mExtendMaxY - tmpDataset.mExtendMinY; %Y size in micron
zsReal = tmpDataset.mExtendMaxZ - tmpDataset.mExtendMinZ; %Z size in micron
xr = xsReal/xs; %X pixel resolution (usually micron per pixel)
yr = ysReal/ys; %Y pixel resolution (usually micron per pixel)
zr = zsReal/zs; %Z pixel resolution (usually micron per pixel)

%% make directory of Spots in surpass scene
cnt = 0;
for vChildIndex = 1:vSurpassScene.GetNumberOfChildren
    if vImarisApplication.mFactory.IsSpots(vSurpassScene.GetChild(vChildIndex - 1))
        cnt = cnt+1;
        vSpots{cnt} = vSurpassScene.GetChild(vChildIndex - 1);
    end
end

%% choose passing spots
vSpotsCnt = length(vSpots);
for n= 1:vSpotsCnt
    vSpotsName{n} = vSpots{n}.mName;
end
cellstr = cell2struct(vSpotsName,{'names'},vSpotsCnt+2);
str = {cellstr.names};
[vAnswer_iPass,~] = listdlg('ListSize',[200 160], ... 
    'PromptString','Chose spots to export',...
    'SelectionMode','multiple',...
    'ListString',str);

TPN=uigetdir;
TPN= [TPN filesep];

for i=1:numel(vAnswer_iPass)
    iPassSpots = vSpots{vAnswer_iPass(i)};
    [SpotsXYZ,~,~] = iPassSpots.Get;
    SpotsXYZ(:,1) = ceil(SpotsXYZ(:,1)./xr); %convert coordinates to pixel
    SpotsXYZ(:,2) = ceil(SpotsXYZ(:,2)./yr); %convert coordinates to pixel
    SpotsXYZ(:,3) = ceil(SpotsXYZ(:,3)./zr); %convert coordinates to pixel
    save([TPN vSpotsName{vAnswer_iPass(i)} '.mat'],'SpotsXYZ');
end
fprintf('Spots coordinates saved!')    
%% comments and notes

