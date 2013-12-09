function [NaN_indices_EEG, NaN_indices_EOG, isNaN] = pre_artifactFASTER_fixedThresholds(EEG, EOG, debugOn, parameters, handles)

    debugMatFileName = 'tempFASTERfixedThresholds.mat';
    if nargin == 0
        load('debugPath.mat')
        load(fullfile(path.debugMATs, debugMatFileName))
        close all
    else
        if handles.flags.saveDebugMATs == 1
            path = handles.path;
            save('debugPath.mat', 'path')
            save(fullfile(path.debugMATs, debugMatFileName))            
        end
    end
        
    numberOfEpochs = length(EEG.ERP);
    
    NaN_indices_EEG = zeros(numberOfEpochs, parameters.EEG.nrOfChannels);
    NaN_indices_EOG = zeros(numberOfEpochs, parameters.EEG.nrOfChannels);
    
    HDR.SampleRate = parameters.EEG.srate;
    
    % if you use the very raw input without referencing
    parameters.BioSemi.chOffset = 0;
    
    for ep = 1 : numberOfEpochs
    
        % slightly redundant processing (fix maybe later for computational
        % efficiency)
        Reference = mean(EEG.ERP{ep}(:,1:parameters.BioSemi.chOffset),2);
        EEG_channels = EEG.ERP{ep}(:,parameters.BioSemi.chOffset+1:parameters.BioSemi.chOffset+parameters.EEG.nrOfChannels);            
            EEG_channels = EEG_channels - repmat(Reference, 1, size(EEG_channels,2));
            
            noOfChannels = size(EEG_channels,2);
            for ch = 1 : noOfChannels
                EEG_channels(:,ch) = pre_remove5060hz_modified(EEG_channels(:,ch), HDR, 'PCA 60');                
            end
            
        EOGin = EEG.ERP{ep}(:,parameters.BioSemi.chOffset+parameters.EEG.nrOfChannels+1:parameters.BioSemi.chOffset+parameters.EEG.nrOfChannels+1);
            % EOG already referenced so no need to subtract
            
            % filter            
            EOGnotch = pre_remove5060hz_modified(EOGin, HDR, 'PCA 60');
            
            cutOffs = [25 0]; % remove high frequency noise, try to keep the trend
            filterOrder = 10; % conservative 
            try 
                EOG = pre_bandbassFilter(EOGnotch, HDR.SampleRate, cutOffs, filterOrder, filterOrder, handles);
            catch err
                err
                filterOrder = filterOrder / 2;
                EOG = pre_bandbassFilter(EOGnotch, HDR.SampleRate, cutOffs, filterOrder, filterOrder, handles);
                error('Bandpass filter parameters too "extreme"')
            end
        
        %% DEBUG PLOTS

        
            %% EOG TIME DOMAIN PLOT
            if debugOn == 1   
                %{
                try
                    subplot(5,8,ep)
                    plot(EOG); title(num2str(ep)); lab(1,ep) = xlabel('Epoch samples'); lab(1,ep) = ylabel('\muV');
                    xlim([1 length(EOG)])
                    set(gca, 'FontName', handles.style.fontName, 'FontSize', handles.style.fontSizeBase-2)
                    set(lab, 'FontName', handles.style.fontName, 'FontSize', handles.style.fontSizeBase-2)
                catch err
                    err
                end
                %}
            end
            
            %% EEG TIME DOMAIN PLOT
            if debugOn == 1                
                try
                    subplot(5,8,ep)
                    plot(EEG_channels); title(num2str(ep)); lab(1,ep) = xlabel('Epoch samples'); lab(1,ep) = ylabel('\muV');
                    xlim([1 length(EEG_channels)])
                    set(gca, 'FontName', handles.style.fontName, 'FontSize', handles.style.fontSizeBase-2)
                    set(lab, 'FontName', handles.style.fontName, 'FontSize', handles.style.fontSizeBase-2)
                catch err
                    err
                end
            end
            
            
        
            %% FREQUENCY ANALYSIS of EPOCH       
            if debugOn == 1
                %{
                subplot(1,2,1)
                    plot(EOGin)
                    title(num2str(ep)); lab(1,1) = xlabel('Epoch samples'); lab(1,2) = ylabel('\muV');
                    xlim([1 length(EOG)])
                    set(gca, 'FontName', handles.style.fontName, 'FontSize', handles.style.fontSizeBase-2)
                    set(lab, 'FontName', handles.style.fontName, 'FontSize', handles.style.fontSizeBase-2)
                subplot(1,2,2)
                    % FFT
                    Fs = parameters.EEG.srate;   
                    freqRange = 0 : 0.1 : parameters.filter.bandPass_hiFreq;
                    nOverlap = parameters.powerAnalysis.nOverlap; % in %  
                    [f, EOGStruct.amplit, EOGStruct.PSD, EOGStruct.amplit_matrix, EOGStruct.PSD_matrix] = ...
                        analyze_powerSpectrum(EOGin, Fs, 'Tukey', 0.10, length(EOGin), length(EOGin), freqRange, nOverlap, 'EOG');
                    plot(f, 10*log10(EOGStruct.PSD.mean), 'b'); lab(2,1) = xlabel('Freq'); lab(2,2) = ylabel('Amplitude');
                    xlim([0.1 2*parameters.filter.bandPass_hiFreq])

                    %HDR.SampleRate = parameters.EEG.srate;
                    %EOG = pre_remove5060hz_modified(EOG, HDR, 'PCA 60');
                    [f, EOGStruct.amplit, EOGStruct.PSD, EOGStruct.amplit_matrix, EOGStruct.PSD_matrix] = ...
                        analyze_powerSpectrum(EOG, Fs, 'Tukey', 0.10, length(EOG), length(EOG), freqRange, nOverlap, 'EOG');
                    hold on
                    plot(f, 10*log10(EOGStruct.PSD.mean), 'r');
                    hold off
                    legend('EOG in', 'EOG with NOTCH60')

                    subplot(1,2,1)
                    hold on
                    plot(EOG, 'r')
                    hold off

                pause(1.0)
                %}
            end
                
        % re-correct for baseline        
        EEG_channels = pre_removeBaseline_epochByEpoch(EEG_channels, ep, parameters, handles);        
            
        % whether EEG channels exceeds the threshold
        NaN_indices_EEG_raw = abs(EEG_channels) > parameters.artifacts.fixedThr; % individual samples
        NaN_indices_EEG(ep,:) = logical(sum(NaN_indices_EEG_raw,1)); % for channel

        % whether EOG channel exceeds the threshold
        NaN_indices_EOG_raw = abs(EOG) > parameters.artifacts.fixedThrEOG; % individual samples
        NaN_indices_EOG_raw = logical(sum(NaN_indices_EOG_raw)); % for EOG channel        
        NaN_indices_EOG(ep,:) = repmat(NaN_indices_EOG_raw, length(NaN_indices_EOG_raw), length(NaN_indices_EEG(ep,:))); % to match the EEG channels
        
    end
    
    % simple boolean, giving 1 when the epoch is artifacted 
    isNaN = logical(NaN_indices_EEG + NaN_indices_EOG);
