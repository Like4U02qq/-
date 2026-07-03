%% 生成测试图片（用于验证计数系统）
% 创建包含不同数量圆形物体的测试图

if ~exist('images', 'dir')
    mkdir('images');
end

%% 图1：5个圆形物体（白色背景，深色物体）
img1 = 255 * ones(400, 600, 3, 'uint8');
circles1 = [100, 100, 35; 300, 100, 30; 500, 100, 40; 200, 250, 35; 400, 250, 30];
for c = 1:size(circles1, 1)
    [X, Y] = meshgrid(1:600, 1:400);
    mask = (X - circles1(c,1)).^2 + (Y - circles1(c,2)).^2 <= circles1(c,3)^2;
    img1(repmat(mask, [1, 1, 3])) = 50;
end
imwrite(img1, 'images/test_5circles.png');
fprintf('已创建: images/test_5circles.png (5个圆形)\n');

%% 图2：8个方形物体
img2 = 240 * ones(400, 600, 3, 'uint8');
rects = [50,50,60,60; 150,50,50,50; 280,50,70,55; 420,50,55,65;
         80,200,65,60; 220,200,55,55; 370,200,60,50; 500,200,50,60];
for r = 1:size(rects, 1)
    x1 = rects(r,1); y1 = rects(r,2); w = rects(r,3); h = rects(r,4);
    img2(y1:y1+h, x1:x1+w, :) = 80;
end
imwrite(img2, 'images/test_8rects.png');
fprintf('已创建: images/test_8rects.png (8个方形)\n');

%% 图3：混合形状（圆形+方形），共10个
img3 = 255 * ones(500, 700, 3, 'uint8');
% 圆形
mixed_circles = [100,100,30; 300,80,25; 500,100,35; 150,250,28; 400,220,32];
for c = 1:size(mixed_circles, 1)
    [X, Y] = meshgrid(1:700, 1:500);
    mask = (X - mixed_circles(c,1)).^2 + (Y - mixed_circles(c,2)).^2 <= mixed_circles(c,3)^2;
    img3(repmat(mask, [1, 1, 3])) = 40;
end
% 方形
mixed_rects = [550,50,50,50; 200,350,60,55; 450,350,55,50; 600,350,45,55; 350,380,50,50];
for r = 1:size(mixed_rects, 1)
    x1 = mixed_rects(r,1); y1 = mixed_rects(r,2); w = mixed_rects(r,3); h = mixed_rects(r,4);
    img3(y1:y1+h, x1:x1+w, :) = 60;
end
imwrite(img3, 'images/test_mixed10.png');
fprintf('已创建: images/test_mixed10.png (10个混合形状)\n');

fprintf('\n共创建 3 张测试图片，可用 object_counting.m 进行检测。\n');
