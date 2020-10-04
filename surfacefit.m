function [S, Sfit] = surfacefit(x,y,z, gx, gy)
% Fits a surface to points [x,y,z] and returns the fitted meshgrid

Sfit = fit([x, y], z, 'thinplateinterp');
[X,Y] = meshgrid(gx, gy);
S = feval(Sfit, X, Y);
end