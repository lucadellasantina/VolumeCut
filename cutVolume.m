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
function [I1, Mask1, I2, Mask2, I3, Mask3, I4, Mask4] = cutVolume(I, mode, g1, g2, g3)
%%
I1 = I;
I2 = I;
I3 = I;
I4 = I;
Mask1 = zeros(size(I),'uint8');
Mask2 = Mask1;
Mask3 = Mask1;
Mask4 = Mask1;

fprintf('Slicing the volume... ');
tic;

switch mode
    case 0 % Slice image in two parts: Start-g1 and g1-End

        Surf = uint8(imresize(g1, [size(I,1) size(I,2)]));
        for z = 1:size(I,3) 
            Mask1(:,:,z) = Surf >= z;
            Mask2(:,:,z) = Surf <  z;
        end
        I1 = I.*Mask1;
        I2 = I.*Mask2;

    case 1 % Slice the image in three parts: Start-g1, g1-g2 and g2-End
        
        % Ensure g1 is first surface along Z, otherwise invert g1 and g2
        if mean(g1(:))> mean(g2(:))
            gx = g1;
            g1 = g2;
            g2 = gx;
        end
                 
        Surf1 = uint8(imresize(g1, [size(I,1) size(I,2)]));
        Surf2 = uint8(imresize(g2, [size(I,1) size(I,2)]));
        for z = 1:size(I,3) 
            Mask1(:,:,z) = z < Surf1;
            Mask2(:,:,z) = (z >= Surf1) & (z <= Surf2);
            Mask3(:,:,z) = z > Surf2;
        end
        I1 = I.*Mask1;
        I2 = I.*Mask2;
        I3 = I.*Mask3;
        
    case 2 % Slice the image in two parts between surfaces: Start-g3 and g3-End

        Surf = uint8(imresize(g3, [size(I,1) size(I,2)]));
        for z = 1:size(I,3) 
            Mask1(:,:,z) = Surf >= z;
            Mask2(:,:,z) = Surf <  z;
        end
        I1 = I.*Mask1;
        I2 = I.*Mask2;
                
    case 3 % Slice the image in four parts: Start-g1, g1-g2, g2-g3 and g3-End
        % Ensure g1 is first surface along Z, otherwise invert g1 and g2
        if mean(g1(:))> mean(g2(:))
            gx = g1;
            g1 = g2;
            g2 = gx;
        end

        % Ensure g3 is last surface along Z, otherwise invert g2 and g3
        if mean(g2(:))> mean(g3(:))
            gx = g2;
            g2 = g3;
            g3 = gx;
        end

        Surf1 = uint8(imresize(g1, [size(I,1) size(I,2)]));
        Surf2 = uint8(imresize(g2, [size(I,1) size(I,2)]));
        Surf3 = uint8(imresize(g3, [size(I,1) size(I,2)]));
        for z = 1:size(I,3) 
            Mask1(:,:,z) = z < Surf1;
            Mask2(:,:,z) = (z >= Surf1) & (z < Surf2);
            Mask3(:,:,z) = (z >= Surf2) & (z < Surf3);
            Mask4(:,:,z) = z >= Surf3;
        end
        I1 = I.*Mask1;
        I2 = I.*Mask2;
        I3 = I.*Mask3;
        I4 = I.*Mask3;        
end
fprintf(['DONE in ' num2str(toc) ' seconds\n']);
end