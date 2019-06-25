function [Rmask,Rimg,roihemi] = drawroipoly(img,Lookup,Rimg)
%[Rmask,Rimg,roihemi] = drawroipoly(himg,Lookup,Rimg)
%
%Interface for drawing ROI and converting to surface vertex mask
%
%Inputs
%   img:        MxN image to draw on, or handle to existing GUI image handle 
%   Lookup:     cvnlookupimages Lookup struct (or cell of structs for lh,rh)
%   Rimg (optional): MxN matrix where 1s exist in the matrix.
%                    If supplied, we skip manual user drawing of the polygon
%                    and instead act as if Rimg==1 is the drawn polygon mask.
%
%Outputs
%   Rmask:      Vx1 logical (If Lookup is a single hemi, V=(numlh x 1) or (numrh x 1)
%                      If Lookup is both hemis, V=(numlh+numrh x 1)
%   Rimg:       MxN binary image of ROI as drawn
%   roihemi:    'lh' or 'rh' depending on which hemi user drew on
%
% Note: We automatically fill any holes in the drawn binary mask!
%       This is useful when Rimg is supplied by the user (there might be holes).

Rmask=[];

if(~iscell(Lookup))
    Lookup={Lookup};
end


if(isempty(img))
    himg=findobj(gca,'type','image');
end

if(ishandle(img))
    himg=img;
    if(~isequal(get(himg,'type'),'image'))
        himg=findobj(himg,'type','image');
    end
    rgbimg=get(himg,'cdata');
else
    rgbimg=img;
    figure;
    himg=imshow(rgbimg);
end

wantbypass = exist('Rimg','var') && ~isempty(Rimg);

imgroi=[];
%Press Escape to erase and start again
%double click on final vertex to close polygon
%or right click on first vertex, and click "Create mask" to view the result
%Keep going until user closes the window
if ~wantbypass
  fprintf('Press Escape to erase and start again\n');
  fprintf('Double click on final vertex to close polygon\n');
  fprintf('Right click on first vertex, and click "Create mask" to view the result\n');
  fprintf('When finished, close window to continue\n');
end
while(ishandle(himg))
    if wantbypass
      [ry,rx] = ind2sub(size(Rimg),find(Rimg==1));
      rimg = double(Rimg==1);
    else
      [rimg,rx,ry]=roipoly();
    end

    rimgNEW = imfill(rimg,'holes');
    if ~isequal(rimgNEW,rimg)
      fprintf('** NOTE: There were holes, so we are using imfill to fill holes!\n');
      rimg = rimgNEW;
    end

    if(isempty(rimg))
        continue;
    end
    
    %Which hemisphere did we draw on?
    if(any(rx>Lookup{1}.imgsize(2)))
        h=2;
        rimg=rimg(:,Lookup{1}.imgsize(2)+1:end);
    else
        h=1;
        rimg=rimg(:,1:Lookup{1}.imgsize(2));
    end
    
    % Rmask = (hemi vertices)x1 binary vector for a single hemisphere
    Rmask=spherelookup_image2vert(rimg,Lookup{h})>0;
    
    imgroi=spherelookup_vert2image(Rmask,Lookup{h},0);
    if(numel(Lookup)>1)
        if(h==1)
            imgroi=[imgroi zeros(Lookup{2}.imgsize)];
        else
            imgroi=[zeros(Lookup{1}.imgsize) imgroi];
        end
    end
    
    %quick way to merge rgbimg background with roi mask
    tmprgb=bsxfun(@times,rgbimg,.75*imgroi + .25);
    set(himg,'cdata',tmprgb);
    
    if wantbypass
      close;
    end
end


if(numel(Lookup)>1)
    %make sure to use inputN for numlh, numrh, since vertsN will be DENSE for
    %when input type is DENSETRUNCpt
    numlh=0;
    numrh=0;
    for hi = 1:numel(Lookup)
        if(isequal(Lookup{hi}.hemi,'lh'))
            numlh=Lookup{hi}.inputN;
        elseif(isequal(Lookup{hi}.hemi,'rh'))
            numrh=Lookup{hi}.inputN;
        end
    end

    vertidx=find(Rmask);
    if(isequal(Lookup{h}.hemi,'rh'))
        vertidx=vertidx+numlh;
    end

    Rmask=zeros(numlh+numrh,1);
    Rmask(vertidx)=1;
end

Rimg=imgroi;
roihemi=Lookup{h}.hemi;