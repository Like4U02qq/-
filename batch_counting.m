%% 批量处理：多目标物品自动计数
% 功能：批量处理文件夹中的所有图像，自动计数并生成报告

clear; clc; close all;

%% ==================== 配置 ====================
inputDir = 'images';
outputDir = 'results';

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

% 获取所有图片
imgFiles = [dir(fullfile(inputDir, '*.jpg')); ...
            dir(fullfile(inputDir, '*.jpeg')); ...
            dir(fullfile(inputDir, '*.png')); ...
            dir(fullfile(inputDir, '*.bmp'))];

fprintf('找到 %d 张图像\n', length(imgFiles));

%% ==================== 批量处理 ====================
allResults = {};

for idx = 1:length(imgFiles)
    fprintf('\n========== 处理 %d/%d: %s ==========\n', ...
        idx, length(imgFiles), imgFiles(idx).name);
    
    try
        imgPath = fullfile(inputDir, imgFiles(idx).name);
        img = imread(imgPath);
        
        if size(img, 3) == 3
            gray = rgb2gray(img);
        else
            gray = img;
        end
        
        % 预处理
        grayFiltered = imgaussfilt(gray, 2);
        grayEnhanced = adapthisteq(grayFiltered, 'ClipLimit', 0.02);
        
        % 二值化
        thresh = graythresh(grayEnhanced);
        binary = imbinarize(grayEnhanced, thresh);
        if sum(binary(:)) > numel(binary) * 0.5
            binary = ~binary;
        end
        
        % 形态学处理
        binaryClean = bwareaopen(binary, 50);
        seClose = strel('disk', 5);
        binaryClosed = imclose(binaryClean, seClose);
        binaryFilled = imfill(binaryClosed, 'holes');
        seOpen = strel('disk', 3);
        binaryOpened = imopen(binaryFilled, seOpen);
        
        % 连通域分析
        [labeled, numObjects] = bwlabel(binaryOpened);
        stats = regionprops(labeled, 'Area', 'Centroid', 'BoundingBox');
        
        % 过滤
        if ~isempty(stats)
            areas = [stats.Area];
            medianArea = median(areas);
            validIdx = areas > medianArea * 0.3 & areas < medianArea * 3;
            validMask = ismember(labeled, find(validIdx));
            [labeled, numObjects] = bwlabel(validMask);
            stats = regionprops(labeled, 'Area', 'Centroid', 'BoundingBox');
        end
        
        % 绘制结果
        fig = figure('Visible', 'off', 'Position', [0 0 800 600]);
        imshow(img); hold on;
        
        colors = lines(numObjects);
        for i = 1:numObjects
            bb = stats(i).BoundingBox;
            centroid = stats(i).Centroid;
            rectangle('Position', bb, 'EdgeColor', colors(i,:), 'LineWidth', 2);
            plot(centroid(1), centroid(2), 'r+', 'MarkerSize', 12, 'LineWidth', 2);
            text(bb(1), bb(2)-8, sprintf('#%d', i), ...
                'Color', colors(i,:), 'FontSize', 9, 'FontWeight', 'bold', ...
                'BackgroundColor', 'white');
        end
        
        title(sprintf('检测结果: %d 个物品 | %s', numObjects, imgFiles(idx).name), ...
            'Interpreter', 'none');
        hold off;
        
        % 保存
        [~, name, ~] = fileparts(imgFiles(idx).name);
        saveas(fig, fullfile(outputDir, [name '_result.png']));
        close(fig);
        
        % 记录
        allResults{end+1, 1} = imgFiles(idx).name;
        allResults{end, 2} = numObjects;
        
        fprintf('检测到 %d 个物品\n', numObjects);
        
    catch ME
        fprintf('处理失败: %s\n', ME.message);
        allResults{end+1, 1} = imgFiles(idx).name;
        allResults{end, 2} = -1;
    end
end

%% ==================== 生成报告 ====================
fprintf('\n\n========== 汇总报告 ==========\n');
fprintf('%-30s %s\n', '文件名', '物品数量');
fprintf('%s\n', repmat('-', 1, 45));
for i = 1:size(allResults, 1)
    fprintf('%-30s %d\n', allResults{i,1}, allResults{i,2});
end

% 保存CSV
csvPath = fullfile(outputDir, 'counting_report.csv');
fid = fopen(csvPath, 'w');
fprintf(fid, '文件名,物品数量\n');
for i = 1:size(allResults, 1)
    fprintf(fid, '%s,%d\n', allResults{i,1}, allResults{i,2});
end
fclose(fid);
fprintf('\n报告已保存至: %s\n', csvPath);
