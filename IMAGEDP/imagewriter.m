clear
IMGWidth = 5;
IMGHeight = 11;

x = imread(['bikerply.png']);%Read 24 bit colour image 
x = imresize(x,[IMGHeight IMGWidth]);%Scale image to required size
%%
% Read palette image stored in raster scan
im_pal = imread('palette.png');
imagesc(im_pal)
title("Default Palette")
set(gca,'xtick',[])
set(gca,'ytick',[])
count = 1;
for i = 1:16
for j = 1:16
    P(count,:) = im_pal(i,j,:);
    count = count+1;
end
end
P = double(P);

%%
%Colour quantization
%Find closest match in palette P for RGB image 
for i = 1:IMGHeight
   for j = 1:IMGWidth
       cpxl = double(x(i,j,:));%Read colour pixel
       for c = 1:256
           err(c) = (cpxl(1)-P(c,1))^2+(cpxl(2)-P(c,2))^2+(cpxl(3)-P(c,3))^2 ; %Calculate squared error    
       end 
       [M, I]= min(err); %Smallest error
       cpxlhat = P(I,:);%Palette RGB colour match
       xhat(i,j,:)=(cpxlhat); 
       x_13h(i,j) = I-1;%Palette value in assembly
   end
end

%%
%Write assembly file
x_13h = x_13h';
x_13h = x_13h(:);
fileID = fopen('bikerply.bin','w');
fwrite(fileID,uint8(x_13h));
fclose(fileID);
%%
%Show quantized image
figure;
montage({x,uint8((xhat))})
