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
function [I1, Mask1, I2, Mask2, I3, Mask3, I4, Mask4] = cutVolume(I, mode, g1, g2, g3)
%%
I1 = I;
I2 = I;
I3 = I;
I4 = I;
Mask1 = false(size(I));
Mask2 = false(size(I));
Mask3 = false(size(I));
Mask4 = false(size(I));

fprintf('Slicing the volume... ');
switch mode
    case 0 % Slice image in two parts: Start-g1 and g1-End
        for x=1:size(I,1)
            for y=1:size(I,2)
                for z=1:size(I,3)
                    if z < g1(ceil(x/2),ceil(y/2))
                        Mask1(x,y,z) = true;
                        I2(x,y,z)    = 0;
                    elseif z >= g1(ceil(x/2),ceil(y/2))
                        I1(x,y,z)    = 0;
                        Mask2(x,y,z) = true;
                    end
                end
            end
        end
        
    case 1 % Slice the image in three parts: Start-g1, g1-g2 and g2-End
        
        % Ensure g1 is first surface along Z, otherwise invert g1 and g2
        if mean(g1(:))> mean(g2(:))
            gx = g1;
            g1 = g2;
            g2 = gx;
        end
                    
        for x=1:size(I,1)
            for y=1:size(I,2)
                for z=1:size(I,3)
                    if z < g1(ceil(x/2),ceil(y/2))
                        Mask1(x,y,z) = true;
                        I2(x,y,z)    = 0;
                        I3(x,y,z)    = 0;
                    elseif (z >= g1(ceil(x/2),ceil(y/2))) && (z <= g2(ceil(x/2),ceil(y/2)))
                        I1(x,y,z)    = 0;
                        Mask2(x,y,z) = true;
                        I3(x,y,z)    = 0;
                    elseif z > g2(ceil(x/2),ceil(y/2))
                        I1(x,y,z)    = 0;
                        I2(x,y,z)    = 0;
                        Mask3(x,y,z) = true;
                    end
                end
            end
        end
        
    case 2 % Slice the image in two parts between surfaces: Start-g3 and g3-End
                
        for x=1:size(I,1)
            for y=1:size(I,2)
                for z=1:size(I,3)
                    if z < (g3(ceil(x/2),ceil(y/2)))
                        Mask1(x,y,z) = true;
                        I2(x,y,z)    = 0;
                    else
                        I1(x,y,z)    = 0;
                        Mask2(x,y,z) = true;
                    end
                end
            end
        end
        
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
        
        for x=1:size(I,1)
            for y=1:size(I,2)
                for z=1:size(I,3)
                    if z < (g1(ceil(x/2),ceil(y/2)))
                        Mask1(x,y,z) = true;
                        I2(x,y,z)    = 0;
                        I3(x,y,z)    = 0;
                        I4(x,y,z)    = 0;
                    elseif (z >= g1(ceil(x/2),ceil(y/2))) && (z < g2(ceil(x/2),ceil(y/2)))
                        I1(x,y,z)    = 0;
                        Mask2(x,y,z) = true;
                        I3(x,y,z)    = 0;
                        I4(x,y,z)    = 0;                        
                    elseif (z >= g2(ceil(x/2),ceil(y/2))) && (z < g3(ceil(x/2),ceil(y/2)))
                        I1(x,y,z)    = 0;
                        I2(x,y,z)    = 0;
                        Mask3(x,y,z) = true;
                        I4(x,y,z)    = 0;                        
                    elseif z >= g3(ceil(x/2),ceil(y/2))
                        I1(x,y,z)    = 0;
                        I2(x,y,z)    = 0;
                        I3(x,y,z)    = 0;
                        Mask4(x,y,z) = true;                        
                    end
                end
            end
        end
end
fprintf('DONE\n');
end