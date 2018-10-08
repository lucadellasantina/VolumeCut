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
function [I1, I2, Mask1, Mask2] = cutVolume(I, mode, g1, g2, g3)
I1 = I;
I2 = I;
Mask1 = false(size(I));
Mask2 = false(size(I));

fprintf('Slicing the volume... ');
switch mode
    case 1
        % Slice the image in two inside g1-g2 and outside g1-g2
        for x=1:size(I,1)
            for y=1:size(I,2)
                for z=1:size(I,3)
                    if z < g1(ceil(x/2),ceil(y/2))
                        I1(x,y,z)    = 0;
                        Mask2(x,y,z) = true;
                    end
                    if z > g2(ceil(x/2),ceil(y/2))
                        I1(x,y,z)    = 0;
                        Mask2(x,y,z) = true;
                    end
                    if (z >= g1(ceil(x/2),ceil(y/2))) && (z <= g2(ceil(x/2),ceil(y/2)))
                        I2(x,y,z)    = 0;
                        Mask1(x,y,z) = true;
                    end
                end
            end
        end
    case 2
        % Slice the image in two halves between volume start-g3 and g3-end
        for x=1:size(I,1)
            for y=1:size(I,2)
                for z=1:size(I,3)
                    if z >= g3(ceil(x/2),ceil(y/2))
                        I1(x,y,z)    = 0;
                        Mask2(x,y,z) = true;
                    else
                        I2(x,y,z)    = 0;
                        Mask1(x,y,z) = true;
                    end
                end
            end
        end
    case 3
        % Slice the image in two halves along the reference surface g1-g3 and g3-g2
        for x=1:size(I,1)
            for y=1:size(I,2)
                for z=1:size(I,3)
                    if z <= (g1(ceil(x/2),ceil(y/2)))
                        I1(x,y,z)    = 0;
                        Mask2(x,y,z) = true;
                    end
                    if z >= g3(ceil(x/2),ceil(y/2))
                        I1(x,y,z)    = 0;
                        Mask2(x,y,z) = true;
                    else
                        I2(x,y,z)    = 0;
                        Mask1(x,y,z) = true;
                    end
                    if z >= (g2(ceil(x/2),ceil(y/2)))
                        I2(x,y,z)    = 0;
                        Mask1(x,y,z) = true;
                    end
                end
            end
        end
end
fprintf('DONE\n');
end