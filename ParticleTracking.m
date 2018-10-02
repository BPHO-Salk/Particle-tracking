%% Batch particle tracking for time-lapse live cell images
% 
% This script works independently from Imaris as an Imaris extention. It 
% requires the user to have a good level of familiarity with Imaris.
% This script is used for particle tracking of live cell images.
%
% Notes:
%   - Input: time-lapse 2D/3D single channel images.
%   - Users need to modify parameters in section "Create spots" according
%     to their own needs.
%   - Object-related, track-related and overall stats are saved separately. 
%
% Preconditions:
%   - ImarisLib.jar (which normally locates in the XTensions folder in the
%     Imaris installation directory) needs to be put in the same folder.
%   - Imaris needs to be running when executing the following code. 
% 
% (C) Copyright 2018               Waitt Advanced Biophotonics Core
%     All rights reserved          Salk Institute for Biological Studies
%                                  10010 N Torrey Pines Rd.
%                                  San Diego, CA 92037
%                                  The United States
% Linjing Fang 08-02-2018
%% 
clc; clear
%% Get the image folder. Only read *.ims images.
infolder = uigetdir;
if strcmp(computer, 'MACI64')
    files = [infolder '/*.ims'];
elseif strcmp(computer, 'PCWIN64')
    files = [infolder '\*.ims'];
else
    err('not Windows or Mac')
end
listing = dir(files);
nfiles = size(listing,1);
% dbstop if error

Concat_objects = [];
Concat_tracks = [];
Concat_overallStats = [];

%% open files in Imaris sequentially
for i = 1:nfiles
    if strcmp(computer, 'MACI64')
        filename = [infolder '/' listing(i).name];
        filename = sprintf(filename);
    elseif strcmp(computer, 'PCWIN64')
        filename = [infolder '\' listing(i).name];
        filename = string(filename);
    end
    
    vImarisApplication = StartImaris;
    vImarisApplication.FileOpen(filename,'');
    
    %get dataset in Matlab
    vDataSet = vImarisApplication.GetDataSet;
	
    %get dataset info
    vSizeT = vDataSet.GetSizeT;
    
    %% Create spots
    ip = vImarisApplication.GetImageProcessing;
    ROI = []; %process the entire image
    ChannelIndex = 0;
    SpotDiameter = 0.3;
    BackgroundSubtraction = 1; 
    SpotFilter = '"Quality" above automatic threshold';
    RegionsFromLocalContrast = 1;
    RegionsThresholdAutomatic = 1;
    RegionsThresholdManual = 9.21289;
    RegionsSpotsDiameterFromVolume = 1;
    RegionsCreateChannel = 0;
    vNewSpots = ip.DetectSpotsRegionGrowing(vDataSet, ROI,ChannelIndex, ...
                SpotDiameter, BackgroundSubtraction, SpotFilter, ...
                RegionsFromLocalContrast, RegionsThresholdAutomatic, ...
                RegionsThresholdManual, RegionsSpotsDiameterFromVolume, RegionsCreateChannel);    
    %track spots if dataset has more than one time point
    if vSizeT > 1
        MaxDistance = 0.5;
        GapSize = 0; 
        TrackFilter = '';
        vNewSpots = ip.TrackSpotsAutoregressiveMotion(vNewSpots, MaxDistance, GapSize, TrackFilter);
    end
    
    vNewSpots.SetName(sprintf('New Spot'));
    %vImarisApplication.GetSurpassScene.AddChild(vNewSpots,-1);
    
	%% Get Spots stats 
    vSurpassComponent = vImarisApplication.GetSurpassSelection;
    vImarisObject = vImarisApplication.GetFactory.ToSpots(vSurpassComponent);
    vAllStatistics = vImarisObject.GetStatistics;
    
    vNames = cell(vAllStatistics.mNames);
    vValues = vAllStatistics.mValues;
    vUnits = cell(vAllStatistics.mUnits); 
    vFactors = cell(vAllStatistics.mFactors);
    vFactorNames = cellstr(char(vAllStatistics.mFactorNames));
    vIds = vAllStatistics.mIds;
    
    %All avaialable statistics 
    vUniqueName = unique(vNames);
    
    %Overall statistics
    vTotalSpotNumber = vValues(strmatch('Total Number of Spots', vNames),:);
    vSpotPerTime = vValues(strmatch('Number of Spots per Time Point', vNames),:); 

    %object statistics
    DiameterX = [];
    IntensityMedian = [];
    TrackDuration = [];
    TrackDisplacementLength = [];
    for i = 1:size(vValues)
           %For object statistics, the ID associated is object ID
        if strcmp(vNames{i},'Diameter X')
            Tnew = {vIds(i),vNames{i},vValues(i)};
            Tnew = cell2table(Tnew);
            DiameterX = [DiameterX; Tnew];
        elseif strcmp(vNames{i},'Intensity Median')
            Tnew = {vIds(i),vNames{i},vValues(i)};
            Tnew = cell2table(Tnew);
            IntensityMedian = [IntensityMedian; Tnew];
            % For track statistics, the ID associated is track ID
        elseif strcmp(vNames{i},'Track Duration')
            Tnew = {vIds(i),vNames{i},vValues(i)};
            Tnew = cell2table(Tnew);
            TrackDuration = [TrackDuration; Tnew];
        elseif strcmp(vNames{i},'Track Displacement Length')
            Tnew = {vIds(i),vNames{i},vValues(i)};
            Tnew = cell2table(Tnew);
            TrackDisplacementLength = [TrackDisplacementLength; Tnew];
        end
    end  
    DiameterX.Properties.VariableNames = {'ObjectID' 'DiameterX_' 'DiameterX'};
    IntensityMedian.Properties.VariableNames = {'ObjectID' 'IntensityMedian_' 'IntensityMedian'};
    TrackDuration.Properties.VariableNames = {'ObjectID' 'TrackDuration_' 'TrackDuration'};
    TrackDisplacementLength.Properties.VariableNames = {'ObjectID' 'TrackDisplacementLength_' 'TrackDisplacementLength'};            
%% Output .csv stats
    [file_path, file_name] = fileparts(filename);
    
    name_objects = cell(size(DiameterX, 1),1);
    name_objects(:) = {file_name};  
    objects = horzcat(name_objects, DiameterX(:,1), DiameterX(:,3), IntensityMedian(:,3));
    objects.Properties.VariableNames = {'ImageName' 'ObjectID' 'DiameterX' 'IntensityMedian'};

    name_tracks = cell(size(TrackDuration, 1),1);
    name_tracks(:) = {file_name};  
    tracks = horzcat(name_tracks, TrackDuration(:,1), TrackDuration(:,3), TrackDisplacementLength(:,3));
    tracks.Properties.VariableNames = {'ImageName' 'TrackID' 'TrackDuration' 'TrackDisplacementLength'};
     
    TotalNumOfSpotsVector = zeros(length(vSpotPerTime),1);
    TotalNumOfSpotsVector(1) = vTotalSpotNumber;
    sz = [length(vSpotPerTime) 3];
    varTypes = {'string', 'double', 'double'};
    OverallStats = table('Size', sz, ... 
                         'VariableTypes', varTypes, ...
                         'VariableNames',{'ImageName','NumberOfSpotsPerTimepoint','TotalNumberOfSpots'});
    OverallStats(:,1) = {file_name}; 
    OverallStats(:,2) = num2cell(vSpotPerTime);
    OverallStats(:,3) = num2cell(TotalNumOfSpotsVector);
    
    %% Concatenate tables
    Concat_objects = [Concat_objects; objects];
    Concat_tracks = [Concat_tracks; tracks];
    Concat_overallStats = [Concat_overallStats; OverallStats];
    %% Save files
    objects_csv = strcat(file_path,'\',file_name,'_objects.csv');
    writetable(objects, objects_csv);  
    tracks_csv = strcat(file_path,'\',file_name,'_tracks.csv');
    writetable(tracks, tracks_csv);     
    csv_OverallStats = strcat(file_path,'\',file_name,'_OverallStats.csv');
    writetable(OverallStats,csv_OverallStats);
end

Concat_objects_path = strcat(file_path,'\Objects.csv');
Concat_tracks_path = strcat(file_path,'\Tracks.csv');
Concat_overallStats_path = strcat(file_path,'\OverallStats.csv');
writetable(Concat_objects,Concat_objects_path);
writetable(Concat_tracks,Concat_tracks_path);
writetable(Concat_overallStats,Concat_overallStats_path);

%Quit Imaris Application after all is done
%vImarisApplication.SetVisible(~vImarisApplication.GetVisible);
%vImarisApplication.Quit;

function aImarisApplication = StartImaris
    javaaddpath ImarisLib.jar;
    vImarisLib = ImarisLib;
    server = vImarisLib.GetServer();
    id = server.GetObjectID(0);
    aImarisApplication = vImarisLib.GetApplication(id);
end