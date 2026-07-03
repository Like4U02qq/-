%% 多目标物品自动计数与位置标注系统
% 功能：通过图像二值化、去噪、形态学运算、连通域分析，
%       自动统计画面内物品总数量，对每个目标进行框选标注，
%       并输出每个物品的坐标位置。
% 作者：AI Assistant
% 日期：2024

clear; clc; close all;

%% ==================== 1. 读取图像 ====================
% 图片所在文件夹（自动扫描该文件夹下的所有图片）
inputDir = 'images';
outputDir = 'output';

% 如果输出文件夹不存在，自动创建
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

% 扫描文件夹中所有图片文件
imgExtensions = {'*.jpg', '*.jpeg', '*.png', '*.bmp', '*.tiff'};
imgFiles = [];
for k = 1:length(imgExtensions)
    imgFiles = [imgFiles; dir(fullfile(inputDir, imgExtensions{k}))];
end

if isempty(imgFiles)
    error('在 "%s" 文件夹中未找到任何图片文件！', inputDir);
end

fprintf('在 "%s" 文件夹中找到 %d 张图片\n', inputDir, length(imgFiles));

% 处理每张图片
for imgIdx = 1:length(imgFiles)
    imgPath = fullfile(inputDir, imgFiles(imgIdx).name);
    [~, imgName, ~] = fileparts(imgFiles(imgIdx).name);
    fprintf('\n===== 处理第 %d/%d 张: %s =====\n', imgIdx, length(imgFiles), imgFiles(imgIdx).name);

img = imread(imgPath);
if size(img, 3) == 3
    gray = rgb2gray(img);
else
    gray = img;
end

figure('Name', '多目标物品自动计数系统', 'Position', [50 50 1400 800]);
subplot(2, 3, 1);
imshow(img);
title('1. 原始图像', 'FontSize', 12);

%% ==================== 2. 图像预处理 ====================
% 高斯滤波去噪
grayFiltered = imgaussfilt(gray, 2);

% 自适应直方图均衡化（增强对比度）
grayEnhanced = adapthisteq(grayFiltered, 'ClipLimit', 0.02);

subplot(2, 3, 2);
imshow(grayEnhanced);
title('2. 预处理（去噪+增强）', 'FontSize', 12);

%% ==================== 3. 二值化 ====================
% 自适应阈值分割
thresh = graythresh(grayEnhanced);
binary = imbinarize(grayEnhanced, thresh);

% 如果背景较亮，反转二值图（确保目标为白色）
if sum(binary(:)) > numel(binary) * 0.5
    binary = ~binary;
end

subplot(2, 3, 3);
imshow(binary);
title('3. 二值化', 'FontSize', 12);

%% ==================== 4. 形态学处理 ====================
% 去除小噪点
binaryClean = bwareaopen(binary, 50);  % 去除面积小于50像素的区域

% 闭运算：填充目标内部空洞
seClose = strel('disk', 5);
binaryClosed = imclose(binaryClean, seClose);

% 填充孔洞
binaryFilled = imfill(binaryClosed, 'holes');

% 开运算：分离粘连目标
seOpen = strel('disk', 3);
binaryOpened = imopen(binaryFilled, seOpen);

subplot(2, 3, 4);
imshow(binaryOpened);
title('4. 形态学处理', 'FontSize', 12);

%% ==================== 5. 连通域分析 ====================
% 标记连通区域
[labeled, numObjects] = bwlabel(binaryOpened);

% 获取区域属性
stats = regionprops(labeled, 'Area', 'Centroid', 'BoundingBox', 'Eccentricity', 'Perimeter');

fprintf('\n===== 检测结果 =====\n');
fprintf('检测到物品数量: %d\n', numObjects);

% 过滤异常区域（面积过大或过小的可能是噪声）
if ~isempty(stats)
    areas = [stats.Area];
    medianArea = median(areas);
    
    % 保留面积在中位数0.3~3倍范围内的区域
    validIdx = areas > medianArea * 0.3 & areas < medianArea * 3;
    
    % 重新标记
    validMask = ismember(labeled, find(validIdx));
    [labeled, numObjects] = bwlabel(validMask);
    stats = regionprops(labeled, 'Area', 'Centroid', 'BoundingBox', 'Eccentricity', 'Perimeter');
    
    fprintf('过滤后物品数量: %d\n', numObjects);
end

%% ==================== 6. 标注与可视化 ====================
subplot(2, 3, 5);
resultImg = img;
imshow(resultImg);
hold on;

% 为每个目标分配不同颜色
colors = lines(numObjects);

% 输出表头
fprintf('\n%-6s %-12s %-12s %-10s %-10s\n', ...
    '编号', 'X坐标(pixel)', 'Y坐标(pixel)', '面积(px)', '长宽比');
fprintf('%s\n', repmat('-', 1, 55));

for i = 1:numObjects
    % 获取边界框
    bb = stats(i).BoundingBox;
    centroid = stats(i).Centroid;
    area = stats(i).Area;
    
    % 绘制边界框（矩形框）
    rectangle('Position', bb, 'EdgeColor', colors(i,:), 'LineWidth', 2);
    
    % 绘制中心点
    plot(centroid(1), centroid(2), 'r+', 'MarkerSize', 12, 'LineWidth', 2);
    
    % 标注编号
    text(bb(1), bb(2) - 10, sprintf('#%d', i), ...
        'Color', colors(i,:), 'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', 'white', 'Margin', 1);
    
    % 计算长宽比
    aspectRatio = bb(3) / bb(4);
    
    % 输出每个物品的信息
    fprintf('%-6d %-12.1f %-12.1f %-10d %-10.2f\n', ...
        i, centroid(1), centroid(2), area, aspectRatio);
end

title(sprintf('5. 标注结果（共检测到 %d 个物品）', numObjects), 'FontSize', 12);
hold off;

%% ==================== 7. 连通域可视化（彩色标记） ====================
subplot(2, 3, 6);
labelRGB = label2rgb(labeled, 'jet', 'k', 'shuffle');
imshow(labelRGB);
title('6. 连通域标记（彩色）', 'FontSize', 12);

%% ==================== 8. 保存结果 ====================
% 保存标注后的图像
outputImgPath = fullfile(outputDir, [imgName '_result.png']);
saveas(gcf, outputImgPath);
fprintf('结果图像已保存至: %s\n', outputImgPath);

% 保存坐标数据到CSV
outputCSVPath = fullfile(outputDir, [imgName '_coordinates.csv']);
fid = fopen(outputCSVPath, 'w');
fprintf(fid, '编号,X坐标(pixel),Y坐标(pixel),面积(pixel),宽度(pixel),高度(pixel),长宽比\n');
for i = 1:numObjects
    bb = stats(i).BoundingBox;
    centroid = stats(i).Centroid;
    area = stats(i).Area;
    aspectRatio = bb(3) / bb(4);
    fprintf(fid, '%d,%.1f,%.1f,%d,%.1f,%.1f,%.2f\n', ...
        i, centroid(1), centroid(2), area, bb(3), bb(4), aspectRatio);
end
fclose(fid);
fprintf('坐标数据已保存至: %s\n', outputCSVPath);

fprintf('\n第 %d/%d 张图片处理完成！\n', imgIdx, length(imgFiles));
close all;  % 关闭当前图形，为下一张图片准备

end  % 图片循环结束

fprintf('\n所有图片处理完成！结果保存在 "%s" 文件夹中。\n', outputDir);
