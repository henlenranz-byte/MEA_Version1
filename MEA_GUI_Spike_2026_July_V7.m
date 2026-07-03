function MEA_GUI_Spike_2026_July_V7()
    % MEA Analysis Suite - Complete Version with Event Detection
    % 
    % Created: 2025-10-08 by Henner Koch (supported by Claude)
    % Modified: 2026_01_21 - Added Stimulation analysis
    % Modified: 2026_01_23 - Added per-intensity spatial response maps for I/O protocols
    % Modified: 2026_02_11 - V16: Session persistence + Settings display + Tools + HFO
    %           - Added persistent settings (LayerDic, output folder, noisy channels)
    %           - Added "Current Settings" display panel showing active configuration
    %           - Removed IEI/Participation buttons (now auto-run after event detection)
    %           - Auto-runs IEI and Participation analysis when 2+ events detected
    %           - Recording_Type for database now taken directly from output folder name
    %           - Added embedded tools: LayerDic Generator and Channel Inspector
    %           - Added HFO Detection (Ripples 80-250Hz, Fast Ripples 250-500Hz)
    % Modified: 2026_03_09 - V49: Improved Propagation Visualization
    %           - Latency Map: percentile-normalized colormap (5th-95th), early=red, late=blue
    %             Inactive electrodes shown as dark gray
    %           - Wavefront Path: Added Initiator marker (yellow star) from latency map
    %             COM trajectory shown separately (green->red), desaturated layer colors
    %           - Velocity Distribution: excludes near-zero artifacts, cleaner annotations
    % Modified: 2026_07_02 - V7 (MEA_GUI_Spike_2026_July_V7):
    %           - Channel Inspector Aufruf auf V4 aktualisiert.
    % Modified: 2026_07_02 - OLD_V6:
    %           - Channel Inspector Aufruf auf V3 aktualisiert.
    % Modified: 2026_07_02 - V5 (MEA_GUI_Spike_2026_July_V5):
    %           - Bugfix Channel Inspector: Aufruf auf MEA_Channel_Inspector_2026_V4()
    %             korrigiert (Dateiname muss Funktionsnamen entsprechen).
    % Modified: 2026_07_02 - V4 (MEA_GUI_Spike_2026_July_V4):
    %           - Channel Inspector: ruft jetzt MEA_Channel_Inspector() (Standalone)
    %             auf statt eingebetteter Version. Fallback auf eingebettete Version
    %             wenn Standalone nicht im MATLAB-Pfad gefunden.
    %           - Export Master DB: uiputfile-Dialog zum Waehlen des Speicherorts.
    %             Vorschlag: parentDir/MEA_Master_Database.xlsx (wie bisher).
    % Modified: 2026_07_02 - V3 (MEA_GUI_Spike_2026_July_V3):
    %           - Metadaten-Dialog: Noisy Channels Feld wird automatisch aus
    %             noisy_channels.json vorausgefuellt (gleicher H5-Ordner).
    %             Prioritaet: JSON > patientMeta > sessionSettings.
    % Modified: 2026_07_02 - V2 (MEA_GUI_Spike_2026_July_V2):
    %           - Bugfix: noisy_channels.json Auto-Load nutzt jetzt lokale
    %             Variable h5FilePath statt getappdata (war noch nicht gesetzt
    %             zum Zeitpunkt von Step 3 -- daher wurde immer der Dialog gezeigt).
    %           - Debug-Status: zeigt gesuchten JSON-Pfad im Status-Panel.
    % Modified: 2026_07_02 - V1 (MEA_GUI_Spike_2026_July_V1):
    %             Format: {"noisy_channels":["A2","B3",...], "n_noisy":N, ...}
    %             Erstellt vom Channel Inspector Tool. Fallback auf manuellen
    %             inputdlg wenn JSON nicht gefunden oder nicht lesbar.
    %           - Summary Panel: cleaner layout with integrated legend
    %
    % Create main figure
    fig = figure('Name', 'MEA Analysis Suite - Complete Version', ...
                 'Position', [50, 50, 1400, 800], ...
                 'MenuBar', 'none', ...
                 'NumberTitle', 'off');
    
    % Initialize data storage
    setappdata(fig, 'channelData', []);
    setappdata(fig, 'filteredChannelData', []);
    setappdata(fig, 'LayerDic', []);
    setappdata(fig, 'Time', []);
    setappdata(fig, 'samplingRate', 10000);
    setappdata(fig, 'spikeData', []);
    setappdata(fig, 'channelLabels', []);
    setappdata(fig, 'firingRates', []);
    setappdata(fig, 'eventParametersAccepted', false);
    

    outputFolder = '';  % Initialize for nested function scope
    h5FilePath = '';    % Also initialize this if you get similar errors

    % ==================== SESSION PERSISTENCE ====================
    % Load previous session settings (LayerDic path, output folder, noisy channels)
    sessionSettings = loadSessionSettings();
    setappdata(fig, 'sessionSettings', sessionSettings);
    
    % Create panels
    controlPanel = uipanel('Parent', fig, ...
                          'Title', 'Controls', ...
                          'Position', [0.01, 0.5, 0.25, 0.49]);
    
    paramPanel = uipanel('Parent', fig, ...
                        'Title', 'Spike Detection Parameters', ...
                        'Position', [0.27, 0.7, 0.25, 0.29]);
    
    eventParamPanel = uipanel('Parent', fig, ...
                             'Title', 'Event Detection Parameters', ...
                             'Position', [0.27, 0.5, 0.25, 0.19]);
    
    % NEW: Current Settings Display Panel
    settingsDisplayPanel = uipanel('Parent', fig, ...
                                   'Title', 'Current Settings', ...
                                   'Position', [0.53, 0.80, 0.46, 0.19], ...
                                   'ForegroundColor', [0 0.4 0.8]);
    
    statusPanel = uipanel('Parent', fig, ...
                         'Title', 'Status Log', ...
                         'Position', [0.53, 0.5, 0.46, 0.29]);
    
    vizPanel = uipanel('Parent', fig, ...
                       'Title', 'Visualization', ...
                       'Position', [0.01, 0.01, 0.98, 0.48]);

    % ==================== SETTINGS DISPLAY ====================
    % Recording Type (from output folder) display
    uicontrol('Parent', settingsDisplayPanel, 'Style', 'text', ...
              'String', 'Rec Type:', ...
              'Units', 'normalized', 'Position', [0.01, 0.80, 0.18, 0.18], ...
              'HorizontalAlignment', 'left', 'FontWeight', 'bold');
    uicontrol('Parent', settingsDisplayPanel, 'Style', 'text', ...
              'String', '(not set)', ...
              'Units', 'normalized', 'Position', [0.19, 0.80, 0.80, 0.18], ...
              'HorizontalAlignment', 'left', ...
              'Tag', 'settingsOutputFolder', ...
              'ForegroundColor', [0.5 0.5 0.5]);
    
    % LayerDic display
    uicontrol('Parent', settingsDisplayPanel, 'Style', 'text', ...
              'String', 'LayerDic:', ...
              'Units', 'normalized', 'Position', [0.01, 0.62, 0.18, 0.18], ...
              'HorizontalAlignment', 'left', 'FontWeight', 'bold');
    uicontrol('Parent', settingsDisplayPanel, 'Style', 'text', ...
              'String', '(not loaded)', ...
              'Units', 'normalized', 'Position', [0.19, 0.62, 0.80, 0.18], ...
              'HorizontalAlignment', 'left', ...
              'Tag', 'settingsLayerDic', ...
              'ForegroundColor', [0.5 0.5 0.5]);
    
    % Noisy Channels display
    uicontrol('Parent', settingsDisplayPanel, 'Style', 'text', ...
              'String', 'Noisy Ch:', ...
              'Units', 'normalized', 'Position', [0.01, 0.44, 0.18, 0.18], ...
              'HorizontalAlignment', 'left', 'FontWeight', 'bold');
    uicontrol('Parent', settingsDisplayPanel, 'Style', 'text', ...
              'String', '(none)', ...
              'Units', 'normalized', 'Position', [0.19, 0.44, 0.35, 0.18], ...
              'HorizontalAlignment', 'left', ...
              'Tag', 'settingsNoisyChannels', ...
              'ForegroundColor', [0.5 0.5 0.5]);
    
    % Ref Channel display
    uicontrol('Parent', settingsDisplayPanel, 'Style', 'text', ...
              'String', 'Ref Ch:', ...
              'Units', 'normalized', 'Position', [0.55, 0.44, 0.12, 0.18], ...
              'HorizontalAlignment', 'left', 'FontWeight', 'bold');
    uicontrol('Parent', settingsDisplayPanel, 'Style', 'text', ...
              'String', 'C15', ...
              'Units', 'normalized', 'Position', [0.67, 0.44, 0.32, 0.18], ...
              'HorizontalAlignment', 'left', ...
              'Tag', 'settingsRefChannel', ...
              'ForegroundColor', [0 0.5 0]);
    
    % Patient Metadata display (NEW)
    uicontrol('Parent', settingsDisplayPanel, 'Style', 'text', ...
              'String', 'Patient:', ...
              'Units', 'normalized', 'Position', [0.01, 0.24, 0.18, 0.18], ...
              'HorizontalAlignment', 'left', 'FontWeight', 'bold');
    uicontrol('Parent', settingsDisplayPanel, 'Style', 'text', ...
              'String', '(not set)', ...
              'Units', 'normalized', 'Position', [0.19, 0.24, 0.80, 0.18], ...
              'HorizontalAlignment', 'left', ...
              'Tag', 'settingsPatientMeta', ...
              'ForegroundColor', [0.5 0.5 0.5]);
    
    % H5 File display
    uicontrol('Parent', settingsDisplayPanel, 'Style', 'text', ...
              'String', 'H5 File:', ...
              'Units', 'normalized', 'Position', [0.01, 0.04, 0.18, 0.18], ...
              'HorizontalAlignment', 'left', 'FontWeight', 'bold');
    uicontrol('Parent', settingsDisplayPanel, 'Style', 'text', ...
              'String', '(not loaded)', ...
              'Units', 'normalized', 'Position', [0.19, 0.04, 0.80, 0.18], ...
              'HorizontalAlignment', 'left', ...
              'Tag', 'settingsH5File', ...
              'ForegroundColor', [0.5 0.5 0.5]);

    % ==================== CONTROL BUTTONS ====================
    
% ==================== CONTROL BUTTONS (REORGANIZED) ====================

% === SECTION 1: SETUP (Buttons 1-3) ===
uicontrol('Parent', controlPanel, ...
          'Style', 'pushbutton', ...
          'String', '1. Select Output Folder', ...
          'Units', 'normalized', ...
          'Position', [0.05, 0.92, 0.9, 0.05], ...
          'FontSize', 10, ...
          'Callback', @selectOutputFolder);

uicontrol('Parent', controlPanel, ...
          'Style', 'pushbutton', ...
          'String', '2. Load Layer Dictionary (JSON)', ...
          'Units', 'normalized', ...
          'Position', [0.05, 0.86, 0.9, 0.05], ...
          'FontSize', 10, ...
          'Callback', @loadLayerDictionary);

uicontrol('Parent', controlPanel, ...
          'Style', 'pushbutton', ...
          'String', '3. Load H5 MEA Data', ...
          'Units', 'normalized', ...
          'Position', [0.05, 0.80, 0.9, 0.05], ...
          'FontSize', 10, ...
          'FontWeight', 'bold', ...
          'ForegroundColor', [0 0.5 0], ...
          'Callback', @loadH5Data);

% === SECTION 2: SPIKE DETECTION (Buttons 4-5) ===
uicontrol('Parent', controlPanel, ...
          'Style', 'pushbutton', ...
          'String', '4. Test Spike Detection', ...
          'Units', 'normalized', ...
          'Position', [0.05, 0.74, 0.43, 0.05], ...
          'FontSize', 9, ...
          'Callback', @testSpikeDetection);

uicontrol('Parent', controlPanel, ...
          'Style', 'pushbutton', ...
          'String', '5. Run Full Detection', ...
          'Units', 'normalized', ...
          'Position', [0.52, 0.74, 0.43, 0.05], ...
          'FontSize', 9, ...
          'FontWeight', 'bold', ...
          'Callback', @runFullSpikeDetection);

% === SECTION 3: EVENT DETECTION (Buttons 6a-6b) ===
uicontrol('Parent', controlPanel, ...
          'Style', 'pushbutton', ...
          'String', '6a. Test Event', ...
          'Units', 'normalized', ...
          'Position', [0.05, 0.68, 0.29, 0.05], ...
          'FontSize', 9, ...
          'ForegroundColor', [0 0 0.8], ...
          'Callback', @testEventDetection);

uicontrol('Parent', controlPanel, ...
          'Style', 'pushbutton', ...
          'String', '6b. Accept', ...
          'Units', 'normalized', ...
          'Position', [0.365, 0.68, 0.29, 0.05], ...
          'FontSize', 9, ...
          'FontWeight', 'bold', ...
          'ForegroundColor', [0 0.5 0], ...
          'Callback', @acceptEventParameters);

uicontrol('Parent', controlPanel, ...
          'Style', 'pushbutton', ...
          'String', '7. Export Results', ...
          'Units', 'normalized', ...
          'Position', [0.68, 0.68, 0.27, 0.05], ...
          'FontSize', 9, ...
          'Callback', @exportResults);

% === SECTION 4: ANALYSIS (Buttons 8-10) ===
uicontrol('Parent', controlPanel, ...
          'Style', 'pushbutton', ...
          'String', '8. Summary & Figures', ...
          'Units', 'normalized', ...
          'Position', [0.05, 0.62, 0.9, 0.05], ...
          'FontSize', 9, ...
          'FontWeight', 'bold', ...
          'ForegroundColor', [0.8 0 0], ...
          'Callback', @generateSummaryAndFigures);

uicontrol('Parent', controlPanel, ...
          'Style', 'pushbutton', ...
          'String', '9. Analyze Events', ...
          'Units', 'normalized', ...
          'Position', [0.05, 0.56, 0.45, 0.05], ...
          'FontSize', 9, ...
          'FontWeight', 'bold', ...
          'ForegroundColor', [0 0.5 0.8], ...
          'Callback', @analyzeEvents);

uicontrol('Parent', controlPanel, ...
          'Style', 'pushbutton', ...
          'String', '10. Propagation', ...
          'Units', 'normalized', ...
          'Position', [0.52, 0.56, 0.43, 0.05], ...
          'FontSize', 9, ...
          'FontWeight', 'bold', ...
          'ForegroundColor', [0 0.5 0.8], ...
          'Callback', @propagationAnalysis);

% === SECTION 5: DATA EXPORT (Buttons 11-12) ===
uicontrol('Parent', controlPanel, ...
          'Style', 'pushbutton', ...
          'String', '11. Export Spike Data', ...
          'Units', 'normalized', ...
          'Position', [0.05, 0.50, 0.9, 0.05], ...
          'FontSize', 9, ...
          'FontWeight', 'bold', ...
          'ForegroundColor', [0.6 0 0.6], ...
          'Callback', @exportSpikeDataForLFP);

uicontrol('Parent', controlPanel, ...
          'Style', 'pushbutton', ...
          'String', '12. Export to Master DB', ...
          'Units', 'normalized', ...
          'Position', [0.05, 0.44, 0.66, 0.05], ...
          'FontSize', 9, ...
          'FontWeight', 'bold', ...
          'ForegroundColor', [0 0.4 0.8], ...
          'BackgroundColor', [0.9 0.95 1.0], ...
          'Callback', @exportToMasterDatabase);

uicontrol('Parent', controlPanel, ...
          'Style', 'pushbutton', ...
          'String', char(128203), ...
          'Units', 'normalized', ...
          'Position', [0.73, 0.44, 0.22, 0.05], ...
          'FontSize', 10, ...
          'FontWeight', 'bold', ...
          'ForegroundColor', [0 0.4 0.8], ...
          'TooltipString', 'Set / update patient metadata for DB export', ...
          'Callback', @setPatientMetadata);

% === SECTION 6: STIMULATION ANALYSIS ===
uicontrol('Parent', controlPanel, ...
          'Style', 'pushbutton', ...
          'String', '13. Stimulation Response', ...
          'Units', 'normalized', ...
          'Position', [0.05, 0.38, 0.9, 0.05], ...
          'FontSize', 9, ...
          'FontWeight', 'bold', ...
          'ForegroundColor', [1 0.5 0], ...  % Orange
          'Callback', @analyzeStimulationResponse);

% === SECTION 7: HFO DETECTION ===
uicontrol('Parent', controlPanel, ...
          'Style', 'pushbutton', ...
          'String', '14. HFO Detection', ...
          'Units', 'normalized', ...
          'Position', [0.05, 0.32, 0.9, 0.05], ...
          'FontSize', 9, ...
          'FontWeight', 'bold', ...
          'ForegroundColor', [0.6 0 0.6], ...  % Purple
          'TooltipString', 'Detect High Frequency Oscillations (Ripples 80-250Hz, Fast Ripples 250-500Hz)', ...
          'Callback', @analyzeHFO);

% === SECTION 8: CELL-TYPE CLASSIFICATION ===
uicontrol('Parent', controlPanel, ...
          'Style', 'pushbutton', ...
          'String', '15. Cell-Type Classification', ...
          'Units', 'normalized', ...
          'Position', [0.05, 0.26, 0.9, 0.05], ...
          'FontSize', 9, ...
          'FontWeight', 'bold', ...
          'ForegroundColor', [0.1 0.5 0.1], ...
          'BackgroundColor', [0.92 1.0 0.92], ...
          'TooltipString', 'CellExplorer-style: Narrow Interneuron vs Broad Pyramidal via trough-to-peak + ACG', ...
          'Callback', @classifyCellTypes);

% === SECTION 9: PCA SPIKE SORTING ===
uicontrol('Parent', controlPanel, ...
          'Style', 'pushbutton', ...
          'String', '16. PCA Spike Sorting', ...
          'Units', 'normalized', ...
          'Position', [0.05, 0.20, 0.9, 0.05], ...
          'FontSize', 9, ...
          'FontWeight', 'bold', ...
          'ForegroundColor', [0.5 0.25 0], ...
          'BackgroundColor', [1.0 0.96 0.88], ...
          'TooltipString', 'Per-channel PCA waveform clustering: isolate up to 2 units via PC1/PC2 + Silhouette score', ...
          'Callback', @pcaSpikeSorting);

% === SECTION 10: TOOLS ===
uicontrol('Parent', controlPanel, ...
          'Style', 'text', ...
          'String', '─── Tools ───', ...
          'Units', 'normalized', ...
          'Position', [0.05, 0.14, 0.9, 0.04], ...
          'FontSize', 9, ...
          'ForegroundColor', [0.4 0.4 0.4]);

uicontrol('Parent', controlPanel, ...
          'Style', 'pushbutton', ...
          'String', '🔧 LayerDic Generator', ...
          'Units', 'normalized', ...
          'Position', [0.05, 0.07, 0.43, 0.05], ...
          'FontSize', 8, ...
          'ForegroundColor', [0.5 0 0.5], ...
          'TooltipString', 'Create/Edit Layer Dictionary with visual grid', ...
          'Callback', @launchLayerDicGenerator);

uicontrol('Parent', controlPanel, ...
          'Style', 'pushbutton', ...
          'String', '🔍 Channel Inspector', ...
          'Units', 'normalized', ...
          'Position', [0.52, 0.07, 0.43, 0.05], ...
          'FontSize', 8, ...
          'ForegroundColor', [0 0.4 0.6], ...
          'TooltipString', 'Visualize all channels to identify noisy electrodes', ...
          'Callback', @launchChannelInspector);

% === SECTION 9: RESET (Bottom) ===
uicontrol('Parent', controlPanel, ...
          'Style', 'pushbutton', ...
          'String', '🔄 RESET - New Analysis', ...
          'Units', 'normalized', ...
          'Position', [0.05, 0.02, 0.9, 0.06], ...
          'FontSize', 11, ...
          'FontWeight', 'bold', ...
          'ForegroundColor', [0.8 0 0], ...
          'BackgroundColor', [1 0.9 0.9], ...
          'Callback', @resetGUI);
    % ==================== SPIKE DETECTION PARAMETERS ====================
    yPos = 0.75;
    spacing = 0.12;
    
    uicontrol('Parent', paramPanel, 'Style', 'text', ...
              'String', 'Sampling Rate (Hz):', ...
              'Units', 'normalized', 'Position', [0.05, yPos, 0.4, 0.08]);
    uicontrol('Parent', paramPanel, 'Style', 'edit', ...
              'String', '10000', ...
              'Units', 'normalized', 'Position', [0.5, yPos, 0.4, 0.08], ...
              'Tag', 'samplingRate');
    yPos = yPos - spacing;
    
    uicontrol('Parent', paramPanel, 'Style', 'text', ...
              'String', 'Start Time (s):', ...
              'Units', 'normalized', 'Position', [0.05, yPos, 0.4, 0.08]);
    uicontrol('Parent', paramPanel, 'Style', 'edit', ...
              'String', '0', ...
              'Units', 'normalized', 'Position', [0.5, yPos, 0.4, 0.08], ...
              'Tag', 'startTime');
    yPos = yPos - spacing;
    
    uicontrol('Parent', paramPanel, 'Style', 'text', ...
              'String', 'End Time (s):', ...
              'Units', 'normalized', 'Position', [0.05, yPos, 0.4, 0.08]);
    uicontrol('Parent', paramPanel, 'Style', 'edit', ...
              'String', '100', ...
              'Units', 'normalized', 'Position', [0.5, yPos, 0.4, 0.08], ...
              'Tag', 'endTime');
    yPos = yPos - spacing;
    
    uicontrol('Parent', paramPanel, 'Style', 'text', ...
              'String', 'SD Threshold:', ...
              'Units', 'normalized', 'Position', [0.05, yPos, 0.4, 0.08]);
    uicontrol('Parent', paramPanel, 'Style', 'edit', ...
              'String', '4', ...
              'Units', 'normalized', 'Position', [0.5, yPos, 0.4, 0.08], ...
              'Tag', 'sdThreshold');
    yPos = yPos - spacing;
    
    uicontrol('Parent', paramPanel, 'Style', 'text', ...
              'String', 'Test Ref Ch:', ...
              'Units', 'normalized', 'Position', [0.05, yPos, 0.4, 0.08], ...
              'Tooltip', 'Single reference channel for Test Spike Detection (e.g. C15)');
    uicontrol('Parent', paramPanel, 'Style', 'edit', ...
              'String', 'C15', ...
              'Units', 'normalized', 'Position', [0.5, yPos, 0.4, 0.08], ...
              'Tag', 'refChannel', ...
              'Tooltip', 'Single channel used for Test Spike Detection', ...
              'Callback', @(~,~) updateSettingsDisplay());
    yPos = yPos - spacing;
    
    uicontrol('Parent', paramPanel, 'Style', 'text', ...
              'String', 'Method:', ...
              'Units', 'normalized', 'Position', [0.05, yPos, 0.4, 0.08]);
    uicontrol('Parent', paramPanel, 'Style', 'popupmenu', ...
              'String', {'Per-channel', 'Global'}, ...
              'Units', 'normalized', 'Position', [0.5, yPos, 0.4, 0.1], ...
              'Tag', 'method');
    
    % ==================== EVENT DETECTION PARAMETERS ====================
    yPosEvent = 0.7;
    spacingEvent = 0.18;
    
    uicontrol('Parent', eventParamPanel, 'Style', 'text', ...
              'String', 'Event SD Multiplier:', ...
              'Units', 'normalized', 'Position', [0.05, yPosEvent, 0.45, 0.12]);
    uicontrol('Parent', eventParamPanel, 'Style', 'edit', ...
              'String', '4', ...
              'Units', 'normalized', 'Position', [0.55, yPosEvent, 0.35, 0.12], ...
              'Tag', 'eventSDMultiplier', ...
              'TooltipString', 'SD multiplier for event threshold');
    yPosEvent = yPosEvent - spacingEvent;
    
    uicontrol('Parent', eventParamPanel, 'Style', 'text', ...
              'String', 'Min Channels:', ...
              'Units', 'normalized', 'Position', [0.05, yPosEvent, 0.45, 0.12]);
    uicontrol('Parent', eventParamPanel, 'Style', 'edit', ...
              'String', '3', ...
              'Units', 'normalized', 'Position', [0.55, yPosEvent, 0.35, 0.12], ...
              'Tag', 'minChannels', ...
              'TooltipString', 'Minimum active channels');
    yPosEvent = yPosEvent - spacingEvent;
    
    uicontrol('Parent', eventParamPanel, 'Style', 'text', ...
              'String', 'Max Channels:', ...
              'Units', 'normalized', 'Position', [0.05, yPosEvent, 0.45, 0.12]);
    uicontrol('Parent', eventParamPanel, 'Style', 'edit', ...
              'String', '120', ...
              'Units', 'normalized', 'Position', [0.55, yPosEvent, 0.35, 0.12], ...
              'Tag', 'maxChannels', ...
              'TooltipString', 'Maximum active channels');
    yPosEvent = yPosEvent - spacingEvent;
    
    uicontrol('Parent', eventParamPanel, 'Style', 'text', ...
              'String', 'Refractory Time (s):', ...
              'Units', 'normalized', 'Position', [0.05, yPosEvent, 0.45, 0.12]);
    uicontrol('Parent', eventParamPanel, 'Style', 'edit', ...
              'String', '1', ...
              'Units', 'normalized', 'Position', [0.55, yPosEvent, 0.35, 0.12], ...
              'Tag', 'refractoryTime', ...
              'TooltipString', 'Refractory period for merging events');
    yPosEvent = yPosEvent - spacingEvent;
    
    uicontrol('Parent', eventParamPanel, 'Style', 'text', ...
              'String', 'Event Ref Ch(s):', ...
              'Units', 'normalized', 'Position', [0.05, yPosEvent, 0.45, 0.12], ...
              'TooltipString', 'Reference channels for network event filter (comma-separated, e.g. C15,A14)');
    uicontrol('Parent', eventParamPanel, 'Style', 'edit', ...
              'String', '', ...
              'Units', 'normalized', 'Position', [0.55, yPosEvent, 0.35, 0.12], ...
              'Tag', 'eventRefChannels', ...
              'TooltipString', 'Keep only events where at least one ref channel fires (leave blank = no filter)', ...
              'Callback', @saveEventRefChannels);
    
    % ==================== STATUS LOG ====================
    uicontrol('Parent', statusPanel, ...
              'Style', 'listbox', ...
              'Units', 'normalized', ...
              'Position', [0.02, 0.02, 0.96, 0.96], ...
              'Tag', 'statusLog', ...
              'String', {}, ...
              'Value', [], ...
              'FontName', 'FixedWidth');
    
    % ==================== VISUALIZATION AXES ====================
    axes('Parent', vizPanel, ...
         'Position', [0.05, 0.1, 0.43, 0.85], ...
         'Tag', 'mainAxes');
    title('Signal Display');
    
    axes('Parent', vizPanel, ...
         'Position', [0.52, 0.1, 0.43, 0.85], ...
         'Tag', 'secondAxes');
    title('Analysis Results');
    
    % Initialize with welcome message
    addStatus('MEA Analysis GUI Ready - Complete Version');
    addStatus('Based on working MEA_spike_Version17_fix.m');
    addStatus('-----------------------------------');
    
    % ==================== PRE-FILL FIELDS FROM SESSION ====================
    % Restore eventRefChannels from last session
    if isfield(sessionSettings, 'lastEventRefChannels') && ...
            ~isempty(sessionSettings.lastEventRefChannels)
        eventRefEdit = findobj(fig, 'Tag', 'eventRefChannels');
        if ~isempty(eventRefEdit)
            set(eventRefEdit, 'String', sessionSettings.lastEventRefChannels);
        end
    end
    updateSettingsDisplay();
    
    % ==================== CALLBACK FUNCTIONS ====================
    
   function selectOutputFolder(~, ~)
    % Load session settings for default directory
    sessionSettings = getappdata(fig, 'sessionSettings');
    lastParentDir = '';
    if ~isempty(sessionSettings) && isfield(sessionSettings, 'lastOutputParentDir')
        lastParentDir = sessionSettings.lastOutputParentDir;
    end
    
    folderOptions = {
        'Spont1'
        'Spont2'
        'HighK_Spont1'
        'HighK_Spont2'
        'Gabazine_Spont1'
        'Gabazine_Spont2'
        'HighK_Gabazine_Spont1'
        'HighK_Gabazine_Spont2'
        'hCSF_Spont1'
        'hCSF_Spont2'
        'NE_Spont1'
        'NE_Spont2'
        'CNQX_Spont1'
        'CNQX_Spont2'
        'Washout_Spont1'
        'Washout_Spont2'
        'TTX_Spont1'
        'TTX_Spont2'
        'ACH_Spont1'
        'ACH_Spont2'
        '--- Custom (Type your own) ---'  % NEW OPTION
    };
    
    [selection, ok] = listdlg('ListString', folderOptions, ...
                              'SelectionMode', 'single', ...
                              'PromptString', 'Select output folder type:', ...
                              'ListSize', [350, 250]);  % Slightly larger to show all options
    
    if ~ok || isempty(selection)
        addStatus('Output folder selection cancelled');
        return;
    end
    
    % Check if user selected "Custom"
    if selection == length(folderOptions)
        % User wants to type custom folder name
        prompt = {'Enter custom folder name (e.g., "SpecialRecording_Test1", "Patient123_Baseline"):'};
        dlgtitle = 'Custom Folder Name';
        dims = [1 60];
        definput = {''};
        
        answer = inputdlg(prompt, dlgtitle, dims, definput);
        
        if isempty(answer) || isempty(strtrim(answer{1}))
            addStatus('Custom folder name cancelled or empty');
            return;
        end
        
        folderName = strtrim(answer{1});
        
        % Sanitize folder name (remove invalid characters)
        folderName = regexprep(folderName, '[<>:"/\\|?*]', '_');
        
        addStatus(['Custom folder name: ' folderName]);
        
    else
        % User selected a predefined option
        folderName = folderOptions{selection};
    end
    
    % Build prompt with previous directory info
    if ~isempty(lastParentDir) && exist(lastParentDir, 'dir')
        promptStr = sprintf('Create folder "%s" where?\n\nPrevious location: %s', folderName, lastParentDir);
        answer = questdlg(promptStr, ...
                         'Select Location', ...
                         'Previous Dir', 'Current Dir', 'Browse...', 'Previous Dir');
    else
        answer = questdlg(['Create folder "' folderName '" in current directory?'], ...
                         'Select Location', ...
                         'Current Dir', 'Browse...', 'Cancel', 'Current Dir');
    end
    
    if strcmp(answer, 'Cancel') || isempty(answer)
        addStatus('Output folder selection cancelled');
        return;
    end
    
    if strcmp(answer, 'Browse...')
        % Start browse from last parent dir if available
        startDir = pwd;
        if ~isempty(lastParentDir) && exist(lastParentDir, 'dir')
            startDir = lastParentDir;
        end
        parentDir = uigetdir(startDir, 'Select parent directory for output folder');
        if isequal(parentDir, 0)
            addStatus('Output folder selection cancelled');
            return;
        end
    elseif strcmp(answer, 'Previous Dir')
        parentDir = lastParentDir;
    else
        parentDir = pwd;
    end
    
    % Save parent directory to session
    sessionSettings.lastOutputParentDir = parentDir;
    setappdata(fig, 'sessionSettings', sessionSettings);
    saveSessionSettings(sessionSettings);
    
    % Create output folder
    outputFolder = fullfile(parentDir, folderName);
    
    try
        if ~exist(outputFolder, 'dir')
            mkdir(outputFolder);
            addStatus(['Created folder: ' outputFolder]);
        else
            addStatus(['Using existing folder: ' outputFolder]);
        end
        
        % Create figures subfolder
        figuresFolder = fullfile(outputFolder, 'figures');
        if ~exist(figuresFolder, 'dir')
            mkdir(figuresFolder);
            addStatus(['Created figures folder: ' figuresFolder]);
        end
        
        % Store in appdata
        setappdata(fig, 'outputFolder', outputFolder);
        setappdata(fig, 'figuresFolder', figuresFolder);
        
        addStatus(['Output folder set: ' folderName]);
        addStatus(['Full path: ' outputFolder]);
        
        % Update settings display
        updateSettingsDisplay();
        
    catch ME
        addStatus(['ERROR creating folder: ' ME.message]);
    end
end
    
    function loadLayerDictionary(src, ~)
    % Get main GUI figure from the button callback
    fig = ancestor(src, 'figure');
    
    % Check for previous LayerDic file in session settings
    sessionSettings = getappdata(fig, 'sessionSettings');
    lastLayerDicPath = '';
    if ~isempty(sessionSettings) && isfield(sessionSettings, 'lastLayerDicPath')
        lastLayerDicPath = sessionSettings.lastLayerDicPath;
    end
    
    % If previous file exists, offer to reuse it
    if ~isempty(lastLayerDicPath) && exist(lastLayerDicPath, 'file')
        [~, prevFileName, prevExt] = fileparts(lastLayerDicPath);
        
        answer = questdlg(sprintf('Use previous LayerDic?\n\n%s%s', prevFileName, prevExt), ...
                         'Layer Dictionary', ...
                         'Use Previous', 'Browse New', 'Cancel', 'Use Previous');
        
        if strcmp(answer, 'Cancel') || isempty(answer)
            addStatus('Layer dictionary loading cancelled');
            return;
        end
        
        if strcmp(answer, 'Use Previous')
            filename = [prevFileName prevExt];
            pathname = fileparts(lastLayerDicPath);
            pathname = [pathname filesep];  % Add trailing separator
        else
            % Browse for new file, starting in the previous directory
            prevDir = fileparts(lastLayerDicPath);
            [filename, pathname] = uigetfile({'*.json;*.txt', 'Layer Dictionary Files (*.json, *.txt)'; ...
                                              '*.json', 'JSON Files (*.json)'; ...
                                              '*.txt', 'Text Files (*.txt)'; ...
                                              '*.*', 'All Files'}, ...
                                             'Select the LayerDic file', prevDir);
        end
    else
        % No previous file - browse normally
        [filename, pathname] = uigetfile({'*.json;*.txt', 'Layer Dictionary Files (*.json, *.txt)'; ...
                                          '*.json', 'JSON Files (*.json)'; ...
                                          '*.txt', 'Text Files (*.txt)'; ...
                                          '*.*', 'All Files'}, ...
                                         'Select the LayerDic file');
    end
    
    if isequal(filename, 0)
        addStatus('Layer dictionary loading cancelled');
        return;
    end
    
    % Save the selected path to session settings
    full_filename = fullfile(pathname, filename);
    sessionSettings.lastLayerDicPath = full_filename;
    setappdata(fig, 'sessionSettings', sessionSettings);
    saveSessionSettings(sessionSettings);
    addStatus(['Loading LayerDic: ' filename]);
    
    try
        
        % Read file content
        fileID = fopen(full_filename, 'r');
        rawData = fread(fileID, inf, '*char')';
        fclose(fileID);
        
        % Try to parse as JSON
        try
            data = jsondecode(rawData);
        catch
            % If JSON parsing fails, try Python-style dict parsing
            addStatus('JSON parsing failed, trying Python dict format...');
            data = parsePythonDict(rawData);
        end
        
        % Initialize
        LayerDic = zeros(16, 16);
        electrodeLayerMap = containers.Map();
        
        % Detect MEA type by checking if any electrode uses 'I' or 'J'
        allElectrodes = {};
        fieldnamesList = fieldnames(data);
        for i = 1:numel(fieldnamesList)
            layerName = fieldnamesList{i};
            layerElectrodes = data.(layerName);
            
            % Handle both cell arrays and regular arrays
            if ~iscell(layerElectrodes)
                layerElectrodes = {layerElectrodes};
            end
            
            for j = 1:length(layerElectrodes)
                elecName = layerElectrodes{j};
                
                % CRITICAL FIX: Convert to char immediately
                if iscell(elecName)
                    elecName = elecName{1};
                end
                
                % Ensure it's char/string
                if isstring(elecName)
                    elecName = char(elecName);
                elseif ~ischar(elecName)
                    try
                        elecName = char(elecName);
                    catch
                        continue;  % Skip if can't convert
                    end
                end
                
                % Only add if valid
                if ~isempty(elecName) && ischar(elecName)
                    allElectrodes{end+1} = elecName;
                end
            end
        end
        
        % Check for I or J to determine MEA type
        % Now all elements in allElectrodes are guaranteed to be char
        hasI = false;
        hasJ = false;
        
        for i = 1:length(allElectrodes)
            elec = allElectrodes{i};
            if contains(elec, 'I')
                hasI = true;
            end
            if contains(elec, 'J')
                hasJ = true;
            end
        end
        
        if hasI && ~hasJ
            meaType = 'Old MEA (I-naming)';
            addStatus('Detected: OLD MEA system (uses I, skips J)');
        elseif hasJ && ~hasI
            meaType = 'New MEA (J-naming)';
            addStatus('Detected: NEW MEA system (uses J, skips I)');
        else
            meaType = 'Unknown MEA';
            addStatus('Warning: Could not auto-detect MEA type');
        end
        
        % Process each layer
        for i = 1:numel(fieldnamesList)
            layerName = fieldnamesList{i};
            
            % Determine layer value
            val = 0;
            layerNameLower = lower(layerName);
            if contains(layerNameLower, 'layer1') || strcmp(layerNameLower, 'layer1')
                val = 1;
            elseif contains(layerNameLower, 'layer2') || contains(layerNameLower, 'layer2-3') || ...
                   contains(layerNameLower, 'layer2_3')
                val = 2;
            elseif contains(layerNameLower, 'layer4')
                val = 3;
            elseif contains(layerNameLower, 'layer5') || contains(layerNameLower, 'layer5-6') || ...
                   contains(layerNameLower, 'layer5_6')
                val = 4;
            elseif contains(layerNameLower, 'white')
                val = 5;
            end
            
            if val == 0
                addStatus(['Warning: Skipping unknown layer: ' layerName]);
                continue;
            end
            
            % Get electrodes for this layer
            layerElectrodes = data.(layerName);
            
            % Handle empty layers
            if isempty(layerElectrodes)
                addStatus([layerName ': No electrodes (empty)']);
                continue;
            end
            
            % Convert to cell array if needed
            if ~iscell(layerElectrodes)
                layerElectrodes = {layerElectrodes};
            end
            
            % Process each electrode
            numProcessed = 0;
            numFailed = 0;
            failedElectrodes = {};
            
            for j = 1:length(layerElectrodes)
                elecName = layerElectrodes{j};
                
                % Handle nested cell arrays
                if iscell(elecName)
                    elecName = elecName{1};
                end
                
                % Convert to char
                if isstring(elecName)
                    elecName = char(elecName);
                elseif ~ischar(elecName)
                    try
                        elecName = char(elecName);
                    catch
                        numFailed = numFailed + 1;
                        failedElectrodes{end+1} = sprintf('(invalid type: %s)', class(elecName));
                        continue;
                    end
                end
                
                % Skip empty names
                if isempty(strtrim(elecName))
                    continue;
                end
                
                try
                    [rowIdx, colIdx] = electrodeNameToIndex(elecName);
                    LayerDic(rowIdx, colIdx) = val;
                    electrodeLayerMap(elecName) = val;
                    numProcessed = numProcessed + 1;
                catch ME
                    numFailed = numFailed + 1;
                    failedElectrodes{end+1} = elecName;
                    % Only show first few errors
                    if numFailed <= 5
                        addStatus(['Warning: Could not parse "' elecName '": ' ME.message]);
                    end
                end
            end
            
            if numFailed > 5
                addStatus(sprintf('... and %d more failed electrodes', numFailed - 5));
            end
            
            addStatus(sprintf('%s: %d electrodes processed, %d failed', layerName, numProcessed, numFailed));
            
            if numFailed > 0 && numFailed <= 10
                addStatus(['Failed electrodes: ' strjoin(failedElectrodes, ', ')]);
            end
        end
        
        % Store data
        setappdata(fig, 'LayerDic', LayerDic);
        setappdata(fig, 'electrodeLayerMap', electrodeLayerMap);
        setappdata(fig, 'meaType', meaType);
        
        % Visualize

ax = findobj(fig, 'Tag', 'mainAxes');  % ← Capture the handle!
axes(ax);
cla;  % Clear any previous plots

% Display LayerDic directly without rotation
imagesc(LayerDic, [0 5]);

% Set axis properties
set(gca, 'YDir', 'reverse');  % Row 1 at top, Row 16 at bottom

% Define colormap
cmap = [0.5 0.5 0.5;   % 0 = gray (no electrode)
        0 0 0;         % 1 = black (Layer 1)
        1 0 0;         % 2 = red (Layer 2/3)
        0 1 0;         % 3 = green (Layer 4)
        0 0 1;         % 4 = blue (Layer 5/6)
        1 1 0];        % 5 = yellow (White Matter)
colormap(cmap);

% Column labels - use detected MEA type
meaType = getappdata(fig, 'meaType');
if contains(meaType, 'J-naming')
    % New MEA: uses J, skips I
    columnLabels = {'A','B','C','D','E','F','G','H','J','K','L','M','N','O','P','R'};
else
    % Old MEA: uses I, skips J
    columnLabels = {'A','B','C','D','E','F','G','H','I','K','L','M','N','O','P','R'};
end

xticks(1:16);
xticklabels(columnLabels);
xlabel('Electrode Column');

yticks(1:16);
yticklabels(1:16);
ylabel('Electrode Row');

title(['MEA Electrodes and Layers - ' meaType]);

% Optional: Add layer labels on the plot
hold on;
for row = 1:16
    for col = 1:16
        val = LayerDic(row, col);
        if val > 0
            % Map value to layer name
            switch val
                case 1
                    label = 'L1';
                case 2
                    label = 'L2/3';
                case 3
                    label = 'L4';
                case 4
                    label = 'L5/6';
                case 5
                    label = 'WM';
                otherwise
                    label = '';
            end
            
            if ~isempty(label)
                text(col, row, label, ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'Color', 'white', ...
                    'FontSize', 8, ...
                    'FontWeight', 'bold');
            end
        end
    end
end

setappdata(fig, 'LayerAxes', ax);
hold off;
        
        % Count electrodes per layer
        layerCounts = zeros(5, 1);
        for i = 1:5
            layerCounts(i) = sum(LayerDic(:) == i);
        end
        
        addStatus('Layer electrode counts:');
        addStatus(sprintf('  L1: %d electrodes', layerCounts(1)));
        addStatus(sprintf('  L2/3: %d electrodes', layerCounts(2)));
        addStatus(sprintf('  L4: %d electrodes', layerCounts(3)));
        addStatus(sprintf('  L5/6: %d electrodes', layerCounts(4)));
        addStatus(sprintf('  WM: %d electrodes', layerCounts(5)));
        addStatus(sprintf('  Total mapped: %d / 256', sum(layerCounts)));
        
        addStatus('Layer dictionary loaded successfully');
        saveLayerMapFigure();
        
        % Update settings display
        updateSettingsDisplay();
        
    catch ME
        addStatus(['Error loading layer dictionary: ' ME.message]);
        addStatus(['Stack: ' getReport(ME)]);
    end
end
    function loadH5Data(~, ~)
    [filename, pathname] = uigetfile('*.h5', 'Select an HDF5 file');
    if isequal(filename, 0)
        addStatus('H5 file loading cancelled');
        return;
    end
    
    try
        h5FilePath = fullfile(pathname, filename);
        addStatus(['Loading: ' filename]);
        
        channelDataPath = '/Data/Recording_0/AnalogStream/Stream_0/ChannelData';
        
        % Get file info to determine total length
        fileInfo = h5info(h5FilePath, channelDataPath);
        totalSamples = fileInfo.Dataspace.Size(1);
        
        % Read sampling rate first to show time duration
        infoChannelPath = '/Data/Recording_0/AnalogStream/Stream_0/InfoChannel';
        infoChannel = h5read(h5FilePath, infoChannelPath);
        
        samplingRate = [];
        if isfield(infoChannel, 'Tick') && ~isempty(infoChannel.Tick)
            tick = double(infoChannel.Tick(1));
            if tick > 0
                samplingRate = 1e6 / tick;
            end
        end
        if isempty(samplingRate) && isfield(infoChannel, 'SamplingFrequency')
            samplingRate = double(infoChannel.SamplingFrequency(1));
        end
        if isempty(samplingRate) || samplingRate <= 0
            samplingRate = 10000; % Default
        end
        
        totalDuration = totalSamples / samplingRate;
        
        % Ask user: Full or Partial loading?
        loadChoice = questdlg(...
            sprintf('Total recording duration: %.1f seconds (%.1f minutes)\n\nLoad entire file or partial segment?', ...
                    totalDuration, totalDuration/60), ...
            'Data Loading Options', ...
            'Full File', 'Partial Segment', 'Cancel', 'Full File');
        
        if strcmp(loadChoice, 'Cancel')
            addStatus('Loading cancelled');
            return;
        end
        
        % Determine time range
        if strcmp(loadChoice, 'Partial Segment')
            % Ask for time range
            prompt = {
                sprintf('Start time (seconds) [0 - %.1f]:', totalDuration);
                sprintf('End time (seconds) [0 - %.1f]:', totalDuration);
            };
            dlgtitle = 'Partial Loading - Time Range';
            dims = [1 50];
            definput = {'0', '60'};  % Default: first 60 seconds
            
            answer = inputdlg(prompt, dlgtitle, dims, definput);
            
            if isempty(answer)
                addStatus('Loading cancelled');
                return;
            end
            
            startTime = str2double(answer{1});
            endTime = str2double(answer{2});
            
            % Validate inputs
            if isnan(startTime) || isnan(endTime)
                addStatus('ERROR: Invalid time values');
                return;
            end
            
            if startTime < 0
                startTime = 0;
            end
            if endTime > totalDuration
                endTime = totalDuration;
            end
            if startTime >= endTime
                addStatus('ERROR: Start time must be less than end time');
                return;
            end
            
            % Convert to sample indices
            startSample = max(1, round(startTime * samplingRate));
            endSample = min(totalSamples, round(endTime * samplingRate));
            numSamplesToLoad = endSample - startSample + 1;
            
            addStatus(sprintf('Loading partial segment: %.1f - %.1f seconds', startTime, endTime));
            addStatus(sprintf('Samples: %d - %d (total: %d)', startSample, endSample, numSamplesToLoad));
            
            % Read partial data using H5 subsetting
            rawChannelData = h5read(h5FilePath, channelDataPath, [startSample, 1], [numSamplesToLoad, Inf]);
            
        else
            % Load full file
            addStatus('Loading complete file...');
            rawChannelData = h5read(h5FilePath, channelDataPath);
            startTime = 0;
            startSample = 1;
        end
        
        addStatus('ChannelData successfully read.');
        addStatus('InfoChannel successfully read.');
        
        channelLabels = infoChannel.Label;
        
        % Update GUI with detected/used sampling rate
        samplingRateEdit = findobj(fig, 'Tag', 'samplingRate');
        set(samplingRateEdit, 'String', num2str(samplingRate));
        
        numSamples = size(rawChannelData, 1);
        Time = (0:numSamples-1)' / samplingRate + startTime;  % Adjust time offset
        
        % Step 1: Map each raw channel into channelData (convert to µV)
        channelData = struct();
        for i = 1:length(channelLabels)
            channelName = channelLabels{i};
            channelData.(channelName) = double(rawChannelData(:, i)) / 32.64;
        end
        clear rawChannelData;
        
        % Step 2: Apply FIRST high-pass filter
        addStatus('Applying initial high-pass filter...');
        [b_hp, a_hp] = butter(2, 300/(samplingRate/2), 'high');
        
        filteredChannelData = struct();
        for i = 1:length(channelLabels)
            channelName = channelLabels{i};
            filteredChannelData.(channelName) = filtfilt(b_hp, a_hp, channelData.(channelName));
        end
       



%% Before: "Step 3: Ask for noisy channels"

        % ===== BEGIN STIMULATION DATA LOADING =====
        
        % Try to load stimulation data from EventStream
        try
            eventStreamPath = '/Data/Recording_0/EventStream/Stream_0';
            
            % Check if EventStream exists
            try
                h5info(h5FilePath, eventStreamPath);
                eventStreamExists = true;
            catch
                eventStreamExists = false;
            end
            
            if eventStreamExists
                addStatus('Found EventStream - loading stimulation data...');
                
                % Read EventEntity_1 (Stim START)
                eventEntity1 = h5read(h5FilePath, [eventStreamPath '/EventEntity_1']);
                
                % Extract START timestamps from column 1
                stimTimes_start_us = double(eventEntity1(:, 1));
                stimTimes_sec = stimTimes_start_us / 1e6;
                
                % Try to read EventEntity_2 for END timestamps (pulse width calculation)
                try
                    eventEntity2 = h5read(h5FilePath, [eventStreamPath '/EventEntity_2']);
                    stimTimes_end_us = double(eventEntity2(:, 1));
                    
                    % Calculate pulse widths
                    pulseWidths_us = stimTimes_end_us - stimTimes_start_us;
                    setappdata(fig, 'stimulationPulseWidths_us', pulseWidths_us);
                    
                    addStatus(sprintf('  Pulse widths: %.1f - %.1f µs (mean: %.1f µs)', ...
                        min(pulseWidths_us), max(pulseWidths_us), mean(pulseWidths_us)));
                catch
                    addStatus('  No EventEntity_2 found (pulse width unknown)');
                end
                
                % Extract EventID if available (column 3)
                if size(eventEntity1, 2) >= 3
                    eventIDs = eventEntity1(:, 3);
                    setappdata(fig, 'stimulationEventIDs', eventIDs);
                end
                
                % Store stimulation times
                setappdata(fig, 'stimulationTimes', stimTimes_sec);
                setappdata(fig, 'stimulationTimestamps_us', stimTimes_start_us);
                setappdata(fig, 'hasStimulation', true);
                
                % Calculate ISI
                if length(stimTimes_sec) > 1
                    ISI = diff(stimTimes_sec);
                    setappdata(fig, 'stimulationISI', ISI);
                    
                    addStatus(sprintf('  Loaded %d stimulation events', length(stimTimes_sec)));
                    addStatus(sprintf('  Time range: %.2f - %.2f s (%.1f min)', ...
                        min(stimTimes_sec), max(stimTimes_sec), ...
                        (max(stimTimes_sec) - min(stimTimes_sec)) / 60));
                    addStatus(sprintf('  Mean ISI: %.3f s (%.3f Hz)', mean(ISI), 1/mean(ISI)));
                else
                    addStatus(sprintf('  Loaded %d stimulation event', length(stimTimes_sec)));
                end
                
            else
                addStatus('No stimulation data found (EventStream not present)');
                setappdata(fig, 'hasStimulation', false);
            end
            
        catch ME
            addStatus(['Warning: Could not load stimulation data: ' ME.message]);
            setappdata(fig, 'hasStimulation', false);
        end
        
        % ===== END STIMULATION DATA LOADING =====
% ===== USER INPUT FOR STIMULATION ELECTRODE =====

hasStim = getappdata(fig, 'hasStimulation');
if ~isempty(hasStim) && hasStim
    
    prompt  = {'Stimulation Electrode (e.g., F11, H12):'};
    dlgtitle = 'Stimulation Information';
    dims    = [1 50];
    definput = {''};
    
    answer = inputdlg(prompt, dlgtitle, dims, definput);
    
    if ~isempty(answer)
        % Store stimulation electrode
        stimElectrode = strtrim(answer{1});
        if ~isempty(stimElectrode)
            setappdata(fig, 'stimulationElectrode', stimElectrode);
            addStatus(sprintf('  Stimulation electrode: %s', stimElectrode));
            
            % ►►► UPDATE LAYER PLOT IF IT EXISTS ◄◄◄
            LayerDic = getappdata(fig, 'LayerDic');
            if ~isempty(LayerDic)
                updateLayerPlotWithStim(fig);
            end
        end
    end
end

% ===== END USER INPUT =====




%% ============================================================================

        % Step 3: Noisy Channels -- automatisch aus noisy_channels.json laden
        % falls vorhanden, sonst manueller Dialog als Fallback.
        channelNames = fieldnames(channelData);

        % Pfad zur noisy_channels.json: gleicher Ordner wie die H5-Datei
        % h5FilePath ist hier als lokale Variable bereits verfuegbar (Zeile 1034)
        % getappdata wuerde NaN/leer liefern da setappdata erst nach Step 3 kommt
        if ~isempty(h5FilePath) && ischar(h5FilePath)
            h5FolderPath = fileparts(h5FilePath);
        elseif ~isempty(sessionSettings) && isfield(sessionSettings, 'lastH5Path')
            h5FolderPath = fileparts(sessionSettings.lastH5Path);
        else
            h5FolderPath = '';
        end
        noisyJsonPath = fullfile(h5FolderPath, 'noisy_channels.json');
        addStatus(sprintf('Suche noisy_channels.json: %s', noisyJsonPath));

        noisyChannelsStr = '';
        jsonLoaded = false;

        if ~isempty(h5FolderPath) && exist(noisyJsonPath, 'file')
            % --- Auto-Load aus JSON ---
            try
                rawJson  = fileread(noisyJsonPath);
                noisyData = jsondecode(rawJson);
                if isfield(noisyData, 'noisy_channels')
                    chList = noisyData.noisy_channels;
                    if ischar(chList),   chList = {chList}; end
                    if isstring(chList), chList = cellstr(chList); end
                    noisyChannelsStr = strjoin(strtrim(chList), ',');
                    jsonLoaded = true;
                    addStatus(sprintf('✓ noisy_channels.json: %d Kanaele geladen (%s)', ...
                        numel(chList), noisyJsonPath));
                    % Optional: Quelle in sessionSettings sichern
                    sessionSettings.lastNoisyChannels = noisyChannelsStr;
                    setappdata(fig, 'sessionSettings', sessionSettings);
                    saveSessionSettings(sessionSettings);
                end
            catch ME_json
                addStatus(['⚠ noisy_channels.json konnte nicht gelesen werden: ' ME_json.message]);
                addStatus('Fallback: manuelle Eingabe.');
            end
        end

        if ~jsonLoaded
            % --- Manueller Fallback (wie bisher) ---
            sessionSettings = getappdata(fig, 'sessionSettings');
            previousNoisyChannels = '';
            if ~isempty(sessionSettings) && isfield(sessionSettings, 'lastNoisyChannels')
                previousNoisyChannels = sessionSettings.lastNoisyChannels;
            end
            if ~isempty(h5FolderPath)
                promptTxt = sprintf(['noisy_channels.json nicht gefunden in:\n%s\n\n' ...
                    'Kanaele manuell eingeben (kommagetrennt, z.B. A2,B3):'], h5FolderPath);
            else
                promptTxt = 'Noisy Channels eingeben (kommagetrennt, z.B. A2,B3,C4):';
            end
            answer = inputdlg(promptTxt, 'Noisy Channels', [3 70], {previousNoisyChannels});
            if ~isempty(answer)
                noisyChannelsStr = strtrim(answer{1});
                sessionSettings.lastNoisyChannels = noisyChannelsStr;
                setappdata(fig, 'sessionSettings', sessionSettings);
                saveSessionSettings(sessionSettings);
            end
        end

        % --- Kanaele nullen ---
        if ~isempty(noisyChannelsStr)
            channelList = strsplit(noisyChannelsStr, ',');
            for i = 1:length(channelList)
                channeldel = strtrim(channelList{i});
                if ismember(channeldel, channelNames)
                    channelData.(channeldel) = zeros(size(channelData.(channeldel)));
                    addStatus(['Channel ' channeldel ' replaced with zeros']);
                else
                    addStatus(['Channel ' channeldel ' not found']);
                end
            end

            % Step 4: High-pass filter neu anwenden
            addStatus('Re-applying high-pass filter after noisy channel removal...');
            for idx = 1:length(channelNames)
                channelName = channelNames{idx};
                channelSignal = channelData.(channelName);
                filteredSignal = filtfilt(b_hp, a_hp, channelSignal);
                filteredChannelData.(channelName) = filteredSignal;
            end
        end
        % Store data
        setappdata(fig, 'channelData', channelData);
        setappdata(fig, 'filteredChannelData', filteredChannelData);
        setappdata(fig, 'channelLabels', channelLabels);
        setappdata(fig, 'Time', Time);
        setappdata(fig, 'samplingRate', samplingRate);
        setappdata(fig, 'h5FilePath', h5FilePath);
        
        % Update end time in GUI
        set(findobj('Tag', 'endTime'), 'String', num2str(Time(end)));
        
        % Store loading info for reference
        setappdata(fig, 'dataStartTime', startTime);
        setappdata(fig, 'partialLoading', strcmp(loadChoice, 'Partial Segment'));
        
        addStatus(sprintf('Loaded %d channels, %.1f seconds', ...
                        length(channelLabels), Time(end) - Time(1)));
        if strcmp(loadChoice, 'Partial Segment')
            addStatus(sprintf('Time range: %.1f - %.1f seconds', Time(1), Time(end)));
        end
        addStatus('Ready for spike detection');
        
        % Update settings display
        updateSettingsDisplay();
        
    catch ME
        addStatus(['Error loading H5: ' ME.message]);
    end
end
    
    function testSpikeDetection(~, ~)
    filteredChannelData = getappdata(fig, 'filteredChannelData');
    if isempty(filteredChannelData)
        addStatus('Please load H5 data first');
        return;
    end
    
    refChannel = get(findobj('Tag', 'refChannel'), 'String');
    sdThreshold = str2double(get(findobj('Tag', 'sdThreshold'), 'String'));
    Time = getappdata(fig, 'Time');
    samplingRate = getappdata(fig, 'samplingRate');
    
    if ~isfield(filteredChannelData, refChannel)
        addStatus(['Channel ' refChannel ' not found']);
        return;
    end
    
    addStatus(['Testing spike detection on ' refChannel '...']);
    
    methodIdx = get(findobj('Tag', 'method'), 'Value');
    
    if methodIdx == 1  % Per-channel
        [spikeTimes, spikeAmplitudes] = detectSpikes(...
            filteredChannelData.(refChannel), Time, samplingRate, sdThreshold);
        
        noiseStd = median(abs(filteredChannelData.(refChannel)) / 0.6745);
        threshold = -sdThreshold * noiseStd;
        methodLabel = 'Per-channel';
    else  % Global
        threshold = computeGlobalThreshold(filteredChannelData, sdThreshold);
        [spikeTimes, spikeAmplitudes] = detectSpikesGlobal(...
            filteredChannelData.(refChannel), Time, samplingRate, threshold);
        methodLabel = 'Global';
    end
    
    % Plot result in GUI axes
    axes(findobj('Tag', 'secondAxes'));
    cla;
    plot(Time, filteredChannelData.(refChannel), 'b-');
    hold on;
    yline(threshold, 'r--', sprintf('Threshold (%.2f)', threshold));
    plot(spikeTimes, spikeAmplitudes, 'ro', 'MarkerSize', 4);
    title([refChannel ' using ' methodLabel ' threshold']);
    xlabel('Time (s)');
    ylabel('Amplitude (µV)');
    legend('Signal', 'Threshold', 'Spikes', 'Location', 'best');
    hold off;
    
    % Enable zoom by default
    h_zoom = zoom(fig);
    set(h_zoom, 'Motion', 'horizontal', 'Enable', 'on');
    
    % Enable data cursor
    dcm = datacursormode(fig);
    set(dcm, 'Enable', 'off');
    set(dcm, 'UpdateFcn', @dataCursorText);
    
    addStatus(sprintf('Test complete: %d spikes detected', length(spikeTimes)));
    addStatus('=== ZOOM CONTROLS ===');
    addStatus('MOUSE: Scroll wheel to zoom, or click+drag to select region');
    addStatus('KEYBOARD: Press "z" for zoom, "p" for pan, "r" to reset view');
    addStatus('Double-click to zoom out fully');
    
    % ========== ENHANCED EXPORT FUNCTIONALITY ==========
    
    % Get folders
    figuresFolder = getappdata(fig, 'figuresFolder');
    outputFolder = getappdata(fig, 'outputFolder');
    
    % Create figures folder if it doesn't exist but output folder does
    if isempty(figuresFolder) && ~isempty(outputFolder)
        figuresFolder = fullfile(outputFolder, 'figures');
        if ~exist(figuresFolder, 'dir')
            mkdir(figuresFolder);
        end
        setappdata(fig, 'figuresFolder', figuresFolder);
    end
    
    % Decide what to do based on folder availability
    if ~isempty(figuresFolder)
        % AUTO-SAVE MODE: Folder exists, save automatically
        addStatus('Exporting test figure...');
        
        % Create high-quality figure
        hFig = createTestSpikeFigure(Time, filteredChannelData.(refChannel), ...
            threshold, spikeTimes, spikeAmplitudes, refChannel, methodLabel, sdThreshold);
        
        % Generate filename with timestamp
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        baseFilename = sprintf('Test_SpikeDetection_%s_%s', refChannel, timestamp);
        
        % Save in multiple formats (keep figure hidden throughout to avoid
        % "Invalid graphics object" if user closes the window mid-save)
        if isgraphics(hFig)
            print(hFig, fullfile(figuresFolder, baseFilename), '-dpng', '-r300');
        end
        if isgraphics(hFig)
            savefig(hFig, fullfile(figuresFolder, [baseFilename '.fig']));
        end
        if isgraphics(hFig)
            print(hFig, fullfile(figuresFolder, baseFilename), '-dpdf', '-bestfit');
        end
        
        if isgraphics(hFig)
            close(hFig);
        end
        
        addStatus('✓ Figure exported successfully!');
        addStatus(sprintf('  Location: %s', figuresFolder));
        addStatus('  Formats: PNG (300dpi), FIG (interactive), PDF (vector)');
        
        % Simple YES/NO dialog to open folder
        answer = questdlg(sprintf('Figure saved to:\n%s\n\nOpen folder now?', figuresFolder), ...
            'Export Complete', 'Open Folder', 'Continue', 'Open Folder');
        
        if strcmp(answer, 'Open Folder')
            openFolder(figuresFolder);
        end
        
    else
        % MANUAL SAVE MODE: No folder set, ask user what to do
        addStatus('No output folder set.');
        
        choice = questdlg('No output folder selected. How would you like to save the test figure?', ...
            'Save Test Figure', ...
            'Save File...', 'View Only', 'Cancel', 'Save File...');
        
        if strcmp(choice, 'Save File...')
            % Create figure
            hFig = createTestSpikeFigure(Time, filteredChannelData.(refChannel), ...
                threshold, spikeTimes, spikeAmplitudes, refChannel, methodLabel, sdThreshold);
            
            % Let user choose location and format
            [filename, pathname, filterindex] = uiputfile(...
                {'*.png', 'PNG Image (High Resolution)'; ...
                 '*.fig', 'MATLAB Figure (Interactive)'; ...
                 '*.pdf', 'PDF Document (Vector)'; ...
                 '*.*', 'All Files'}, ...
                'Save Test Spike Detection Figure', ...
                sprintf('Test_SpikeDetection_%s.png', refChannel));
            
            if ~isequal(filename, 0)
                fullpath = fullfile(pathname, filename);
                
                if ~isgraphics(hFig)
                    addStatus('ERROR: Figure was closed before saving. Please re-run test.');
                    return;
                end
                
                % Save based on selected filter
                try
                    switch filterindex
                        case 1  % PNG
                            print(hFig, fullpath, '-dpng', '-r300');
                            addStatus(sprintf('✓ Saved as PNG: %s', fullpath));
                        case 2  % FIG
                            savefig(hFig, fullpath);
                            addStatus(sprintf('✓ Saved as FIG: %s', fullpath));
                        case 3  % PDF
                            print(hFig, fullpath, '-dpdf', '-bestfit');
                            addStatus(sprintf('✓ Saved as PDF: %s', fullpath));
                        otherwise
                            % Determine from extension
                            [~, ~, ext] = fileparts(filename);
                            switch lower(ext)
                                case '.png'
                                    print(hFig, fullpath, '-dpng', '-r300');
                                case '.fig'
                                    savefig(hFig, fullpath);
                                case '.pdf'
                                    print(hFig, fullpath, '-dpdf', '-bestfit');
                                otherwise
                                    print(hFig, fullpath, '-dpng', '-r300');
                            end
                            addStatus(sprintf('✓ Saved: %s', fullpath));
                    end
                catch saveErr
                    addStatus(sprintf('WARNING: Save error: %s', saveErr.message));
                end
                
                if isgraphics(hFig), close(hFig); end
                
                % Ask if they want to open the folder
                answer2 = questdlg('Figure saved. Open containing folder?', ...
                    'Save Complete', 'Open Folder', 'Done', 'Done');
                
                if strcmp(answer2, 'Open Folder')
                    openFolder(pathname);
                end
            else
                if isgraphics(hFig), close(hFig); end
                addStatus('Save cancelled');
            end
            
        elseif strcmp(choice, 'View Only')
            % Create and show figure without saving
            hFig = createTestSpikeFigure(Time, filteredChannelData.(refChannel), ...
                threshold, spikeTimes, spikeAmplitudes, refChannel, methodLabel, sdThreshold);
            set(hFig, 'Visible', 'on');
            set(hFig, 'Name', sprintf('Test Spike Detection - %s (Not Saved)', refChannel));
            addStatus('Figure displayed (not saved)');
            addStatus('TIP: Use "1. Select Output Folder" for automatic saving');
        else
            addStatus('Export cancelled');
        end
    end
end

% Helper function to create the test spike figure
function hFig = createTestSpikeFigure(Time, signal, threshold, spikeTimes, ...
                                       spikeAmplitudes, refChannel, methodLabel, sdThreshold)
    % Create figure with consistent formatting
    hFig = figure('Visible', 'off', 'Position', [100, 100, 1200, 600]);
    
    % Plot signal
    plot(Time, signal, 'b-', 'LineWidth', 0.5);
    hold on;
    
    % Plot threshold
    yline(threshold, 'r--', sprintf('Threshold (%.2f µV)', threshold), ...
        'LineWidth', 2, 'LabelHorizontalAlignment', 'left');
    
    % Plot detected spikes
    plot(spikeTimes, spikeAmplitudes, 'ro', 'MarkerSize', 6, ...
        'LineWidth', 1.5, 'MarkerFaceColor', 'r');
    
    % Labels and title
    title(sprintf('%s - Spike Detection Test (%s method, SD=%.1f)', ...
        refChannel, methodLabel, sdThreshold), ...
        'FontSize', 14, 'FontWeight', 'bold');
    xlabel('Time (s)', 'FontSize', 12);
    ylabel('Amplitude (µV)', 'FontSize', 12);
    
    % Legend
    legend('Signal', 'Threshold', sprintf('Detected Spikes (n=%d)', length(spikeTimes)), ...
        'Location', 'best', 'FontSize', 10);
    
    grid on;
    
    % Add summary text box
    firingRate = length(spikeTimes) / (Time(end) - Time(1));
    summaryText = sprintf(['Method: %s\n' ...
        'Threshold: %.1f SD (%.2f µV)\n' ...
        'Spikes detected: %d\n' ...
        'Firing rate: %.2f Hz\n' ...
        'Duration: %.1f s'], ...
        methodLabel, sdThreshold, threshold, length(spikeTimes), ...
        firingRate, Time(end) - Time(1));
    
    annotation('textbox', [0.15, 0.75, 0.2, 0.15], ...
        'String', summaryText, ...
        'FitBoxToText', 'on', ...
        'BackgroundColor', 'white', ...
        'EdgeColor', 'black', ...
        'LineWidth', 1.5, ...
        'FontSize', 9, ...
        'FontWeight', 'bold');
    
    hold off;
end

% Helper function to open folder (cross-platform)
function openFolder(folderPath)
    try
        if ispc
            winopen(folderPath);
        elseif ismac
            system(['open "' folderPath '"']);
        else
            system(['xdg-open "' folderPath '"']);
        end
    catch
        fprintf('Could not open folder: %s\n', folderPath);
    end
end

% Add this helper function at the end of your code (before the final 'end')
function txt = dataCursorText(~, event_obj)
    % Custom data cursor text
    pos = get(event_obj, 'Position');
    txt = {['Time: ', num2str(pos(1), '%.4f'), ' s'], ...
           ['Amplitude: ', num2str(pos(2), '%.2f'), ' µV']};
end
    
    function runFullSpikeDetection(~, ~)
        filteredChannelData = getappdata(fig, 'filteredChannelData');
        if isempty(filteredChannelData)
            addStatus('Please load H5 data first');
            return;
        end
        
        % Get parameters
        sdThreshold = str2double(get(findobj('Tag', 'sdThreshold'), 'String'));
        startTime = str2double(get(findobj('Tag', 'startTime'), 'String'));
        endTime = str2double(get(findobj('Tag', 'endTime'), 'String'));
        Time = getappdata(fig, 'Time');
        samplingRate = getappdata(fig, 'samplingRate');
        
        % Apply time window
        timeMask = (Time >= startTime) & (Time <= endTime);
        TimeWindow = Time(timeMask);
        
        % Apply to filtered data
        channelNames = fieldnames(filteredChannelData);
        filteredDataWindow = struct();
        for i = 1:length(channelNames)
            chName = channelNames{i};
            filteredDataWindow.(chName) = filteredChannelData.(chName)(timeMask);
        end
        
        totalDuration = TimeWindow(end) - TimeWindow(1);
        
        % Initialize results
        spikeData = struct();
        firingRates = struct();
        
        methodIdx = get(findobj('Tag', 'method'), 'Value');
        
        addStatus('Running spike detection on all channels...');
        
        if methodIdx == 2  % Global
            globalThreshold = computeGlobalThreshold(filteredDataWindow, sdThreshold);
            addStatus(sprintf('Global threshold: %.2f', globalThreshold));
        end
        
        for idx = 1:length(channelNames)
            chanName = channelNames{idx};
            channelSignal = filteredDataWindow.(chanName);
            
            if methodIdx == 1  % Per-channel
                [spikeTimesAll, spikeAmplitudesAll] = detectSpikes(...
                    channelSignal, TimeWindow, samplingRate, sdThreshold);
            else  % Global
                [spikeTimesAll, spikeAmplitudesAll] = detectSpikesGlobal(...
                    channelSignal, TimeWindow, samplingRate, globalThreshold);
            end
            
            spikeData.(chanName).times = spikeTimesAll;
            spikeData.(chanName).amplitudes = spikeAmplitudesAll;
            firingRates.(chanName) = numel(spikeTimesAll) / totalDuration;
            
            if mod(idx, 10) == 0
                addStatus(sprintf('Processing channel %d/%d', idx, length(channelNames)));
                drawnow;
            end
        end
        
        % Store results
        setappdata(fig, 'spikeData', spikeData);
        setappdata(fig, 'firingRates', firingRates);
        setappdata(fig, 'TimeWindow', TimeWindow);
        setappdata(fig, 'totalDuration', totalDuration);
        
        % Calculate total spikes
        totalSpikes = sum(structfun(@(x) length(x.times), spikeData));
        
        addStatus(sprintf('Detection complete: %d total spikes', totalSpikes));
        addStatus('Ready for network event detection');
        
        % Generate raster plot
        generateRasterPlot();
    end
    
    function generateRasterPlot()
    spikeData = getappdata(fig, 'spikeData');
    figuresFolder = getappdata(fig, 'figuresFolder');
    
    % ========== GUI DISPLAY SECTION ==========
    axes(findobj('Tag', 'mainAxes'));
    cla;
    hold on;
    
    channelNames = fieldnames(spikeData);
    sortedChannels = sort(channelNames);
    
    for idx = 1:length(sortedChannels)
        channel = sortedChannels{idx};
        spikeTimes = spikeData.(channel).times;
        if ~isempty(spikeTimes)
            plot(spikeTimes, idx * ones(size(spikeTimes)), 'k|', 'MarkerSize', 3);
        end
    end
    
    ylim([0 length(sortedChannels) + 1]);
    xlabel('Time (s)');
    ylabel('Channel');
    title('MEA Raster Plot');
    set(gca, 'YDir', 'reverse');
    
    % ╔═══════════════════════════════════════════════════════════════════╗
    % ║  BLOCK 1: STIMULATION MARKERS - GUI DISPLAY                      ║
    % ╚═══════════════════════════════════════════════════════════════════╝
    % Add stimulation markers
    hasStim = getappdata(fig, 'hasStimulation');
    if ~isempty(hasStim) && hasStim
        stimTimes = getappdata(fig, 'stimulationTimes');
        if ~isempty(stimTimes)
            yLim = get(gca, 'YLim');
            for i = 1:length(stimTimes)
                plot([stimTimes(i) stimTimes(i)], yLim, ...
                    '--', 'Color', [1 0.5 0], 'LineWidth', 1.5);
            end
            legend('Spikes', 'Stimulation', 'Location', 'northeast');
        end
    end
    % ╚═══════════════════════════════════════════════════════════════════╝
    
    hold off;
    
    % ========== SAVED FIGURE SECTION ==========
    % Save the raster plot if figuresFolder exists
    if ~isempty(figuresFolder)
        % Create invisible figure with the same content
        hFig = figure('Visible', 'off', 'Position', [100, 100, 800, 600]);
        hold on;
        
        for idx = 1:length(sortedChannels)
            channel = sortedChannels{idx};
            spikeTimes = spikeData.(channel).times;
            if ~isempty(spikeTimes)
                plot(spikeTimes, idx * ones(size(spikeTimes)), 'k|', 'MarkerSize', 3);
            end
        end
        
        ylim([0 length(sortedChannels) + 1]);
        xlabel('Time (s)');
        ylabel('Channel');
        title('MEA Raster Plot');
        set(gca, 'YDir', 'reverse');
        
        % ╔═══════════════════════════════════════════════════════════════════╗
        % ║  BLOCK 2: STIMULATION MARKERS - SAVED FIGURE                     ║
        % ╚═══════════════════════════════════════════════════════════════════╝
        % Add stimulation markers
        hasStim = getappdata(fig, 'hasStimulation');
        if ~isempty(hasStim) && hasStim
            stimTimes = getappdata(fig, 'stimulationTimes');
            if ~isempty(stimTimes)
                yLim = get(gca, 'YLim');
                for i = 1:length(stimTimes)
                    plot([stimTimes(i) stimTimes(i)], yLim, ...
                        '--', 'Color', [1 0.5 0], 'LineWidth', 1.5);
                end
                legend('Spikes', 'Stimulation', 'Location', 'northeast');
            end
        end
        % ╚═══════════════════════════════════════════════════════════════════╝
        
        hold off;
        
        % Save
        print(hFig, fullfile(figuresFolder, 'MEA_Rasterplot'), '-dpng', '-r300');
        set(hFig, 'Visible', 'on');
        savefig(hFig, fullfile(figuresFolder, ['MEA_Rasterplot' '.fig']));
        close(hFig);
        
        addStatus('Raster plot saved to figures folder');
    end
end

    
    function testEventDetection(~, ~)
        spikeData = getappdata(fig, 'spikeData');
        if isempty(spikeData)
            addStatus('ERROR: Please run spike detection first');
            return;
        end
        
        addStatus('-----------------------------------');
        addStatus('Testing event detection with current parameters...');
        
        % Run detection but don't save as final
        setappdata(fig, 'isTestMode', true);
        detectNetworkEvents();
        setappdata(fig, 'isTestMode', false);
        
        addStatus('Test complete. Adjust parameters if needed, then click "Accept & Finalize"');
    end
    
    function acceptEventParameters(~, ~)
        eventOnsets = getappdata(fig, 'eventOnsets');
        if isempty(eventOnsets)
            addStatus('ERROR: Please run "Test Event Detection" first');
            return;
        end
        
        % Mark parameters as accepted
        setappdata(fig, 'eventParametersAccepted', true);
        
        addStatus('-----------------------------------');
        addStatus('Event detection parameters ACCEPTED');
        addStatus(sprintf('Final result: %d events detected', length(eventOnsets)));
        
        % Save event table
        saveEventTable();
        
        % AUTO-RUN IEI and Participation analysis if 2+ events
        if length(eventOnsets) >= 2
            addStatus('-----------------------------------');
            addStatus('Auto-running IEI and Participation analysis...');
            
            % Run IEI analysis
            calculateIEI();
            
            % Run Participation analysis
            analyzeParticipation();
            
            addStatus('-----------------------------------');
        else
            addStatus('(Skipping IEI/Participation - need at least 2 events)');
        end
        
        addStatus('Ready for export');
    end
    
    function saveEventTable()
        eventOnsets = getappdata(fig, 'eventOnsets');
        eventOffsets = getappdata(fig, 'eventOffsets');
        outputFolder = getappdata(fig, 'outputFolder');
        
        if isempty(eventOnsets) || isempty(outputFolder)
            return;
        end
        
        numEvents = length(eventOnsets);
        eventNumbers = (1:numEvents)';
        startTimes = eventOnsets(:);
        endTimes = eventOffsets(:);
        durations = endTimes - startTimes;
        
        eventTable = table(eventNumbers, startTimes, endTimes, durations, ...
            'VariableNames', {'Event_Number','Start_Time_s','End_Time_s','Duration_s'});
        
        setappdata(fig, 'eventTable', eventTable);
        
        writetable(eventTable, fullfile(outputFolder, 'DetectedEvents.xlsx'));
        addStatus('Event table saved to DetectedEvents.xlsx');
    end
    
    function detectNetworkEvents(~, ~)
        spikeData = getappdata(fig, 'spikeData');
        if isempty(spikeData)
            addStatus('Please run spike detection first');
            return;
        end
        
        isTestMode = getappdata(fig, 'isTestMode');
        if isempty(isTestMode)
            isTestMode = false;
        end
        
        if ~isTestMode
            addStatus('Starting network event detection...');
            end
        
        % Get parameters FROM GUI
        multiplier = str2double(get(findobj('Tag', 'eventSDMultiplier'), 'String'));
        minChannels = str2double(get(findobj('Tag', 'minChannels'), 'String'));
        maxChannels = str2double(get(findobj('Tag', 'maxChannels'), 'String'));
        refractoryTime = str2double(get(findobj('Tag', 'refractoryTime'), 'String'));
        
        % Validate parameters
        if isnan(multiplier) || isnan(minChannels) || isnan(maxChannels) || isnan(refractoryTime)
            addStatus('ERROR: Invalid parameter values');
            return;
        end
        
        % Get data
        TimeWindow = getappdata(fig, 'TimeWindow');
        if isempty(TimeWindow)
            TimeWindow = getappdata(fig, 'Time');
        end
        samplingRate = getappdata(fig, 'samplingRate');
        channelLabels = getappdata(fig, 'channelLabels');
        
        % Get sorted channels (excluding reference electrodes)
        excludedChannels = {'A1', 'R1', 'A16', 'R16'};
        sortedChannels = setdiff(channelLabels, excludedChannels);
        sortedChannels = sort(sortedChannels);
        
        % Define time bins
        startTime = min(TimeWindow);
        endTime = max(TimeWindow);
        binSize = 0.025; % 25 ms bin size
        timeEdges = startTime:binSize:endTime;
        timeCenters = timeEdges(1:end-1) + binSize/2;
        
        % Initialize activity matrix
        activityMatrix = zeros(length(sortedChannels), length(timeCenters));
        
        if ~isTestMode
            addStatus('Building activity matrix...');
        end
        
        % Fill the activity matrix with spike counts per channel per time bin
        for idx = 1:length(sortedChannels)
            channel = sortedChannels{idx};
            if isfield(spikeData, channel)
                spikeTimes = spikeData.(channel).times;
                counts = histcounts(spikeTimes, timeEdges);
                activityMatrix(idx, :) = counts;
            end
        end
        
        % Compute population firing rate
        populationFiringRate = sum(activityMatrix, 1) / length(sortedChannels) / binSize; % in Hz
        activeChannelsOverTime = sum(activityMatrix > 0, 1);
        
        % Calculate threshold
        meanFR = mean(populationFiringRate);
        stdFR = std(populationFiringRate);
        
        refractoryPeriod = ceil(refractoryTime / binSize);
        thresholdFR = meanFR + multiplier * stdFR;
        
        addStatus(sprintf('Parameters: SD=%.1f, MinCh=%d, MaxCh=%d, Refract=%.1fs', ...
                         multiplier, minChannels, maxChannels, refractoryTime));
        addStatus(sprintf('Threshold FR: %.2f Hz (mean=%.2f, std=%.2f)', thresholdFR, meanFR, stdFR));
        
        % Detect events
        eventIndicesFR = (populationFiringRate > thresholdFR);
        eventIndicesNchan = (activeChannelsOverTime >= minChannels) & ...
                            (activeChannelsOverTime <= maxChannels);
        eventIndices = eventIndicesFR & eventIndicesNchan;
        
        % Identify contiguous regions
        eventStarts = [];
        eventEnds = [];
        
        i = 1;
        while i <= length(eventIndices)
            if eventIndices(i)
                eventStartIdx = i;
                while (i <= length(eventIndices)) && eventIndices(i)
                    i = i + 1;
                end
                eventEndIdx = i - 1;
                eventStarts = [eventStarts, eventStartIdx];
                eventEnds = [eventEnds, eventEndIdx];
            else
                i = i + 1;
            end
        end
        
        % Merge events if gap <= refractoryPeriod
        k = 1;
        while k < length(eventStarts)
            gapBins = eventStarts(k+1) - eventEnds(k);
            if gapBins <= refractoryPeriod
                eventEnds(k) = eventEnds(k+1);
                eventStarts(k+1) = [];
                eventEnds(k+1) = [];
            else
                k = k + 1;
            end
        end
        
        % Convert to time (identical to V49/V50 behaviour)
        eventOnsets  = timeCenters(eventStarts);
        eventOffsets = timeCenters(eventEnds);
        
        % Remove invalid events
        invalidEventIdx = (eventOffsets <= eventOnsets);
        if any(invalidEventIdx)
            addStatus(sprintf('Removing %d invalid events', sum(invalidEventIdx)));
            eventOnsets(invalidEventIdx) = [];
            eventOffsets(invalidEventIdx) = [];
            eventStarts(invalidEventIdx) = [];
            eventEnds(invalidEventIdx) = [];
        end
        
        % Apply reference channel filter if set
        % Priority: eventRefChannels field (if filled) → refChannel field → no filter
        addStatus(sprintf('  Events before ref filter: %d', length(eventOnsets)));
        eventRefStr = strtrim(get(findobj('Tag', 'eventRefChannels'), 'String'));
        testRefStr  = strtrim(get(findobj('Tag', 'refChannel'), 'String'));
        if ~isempty(eventRefStr)
            refChannel = eventRefStr;   % Dedicated event ref channels
        else
            refChannel = testRefStr;    % Fall back to test-spike channel (V50 behaviour)
        end
        
        % Support multiple reference channels (comma-separated)
        if ~isempty(refChannel)
            % Parse multiple channels
            refChannels = strsplit(refChannel, ',');
            refChannels = strtrim(refChannels); % Remove whitespace
            
            % Validate channels exist
            validRefChannels = {};
            for i = 1:length(refChannels)
                if isfield(spikeData, refChannels{i})
                    validRefChannels{end+1} = refChannels{i};
                else
                    addStatus(sprintf('Warning: Reference channel %s not found', refChannels{i}));
                end
            end
            
            if ~isempty(validRefChannels)
                addStatus(sprintf('Applying reference channel filter: %s', strjoin(validRefChannels, ', ')));
                
                keepMask = false(length(eventOnsets), 1);
                for e = 1:length(eventOnsets)
                    % Keep event if ANY reference channel has a spike
                    hasSpike = false;
                    for r = 1:length(validRefChannels)
                        refSpikeTimes = spikeData.(validRefChannels{r}).times;
                        if any(refSpikeTimes >= eventOnsets(e) & refSpikeTimes <= eventOffsets(e))
                            hasSpike = true;
                            break;
                        end
                    end
                    keepMask(e) = hasSpike;
                end
                
                numRemoved = sum(~keepMask);
                eventStarts = eventStarts(keepMask);
                eventEnds = eventEnds(keepMask);
                eventOnsets = eventOnsets(keepMask);
                eventOffsets = eventOffsets(keepMask);
                
                addStatus(sprintf('Removed %d events (no spike in any ref channel)', numRemoved));
            end
        end
        
        numEvents = length(eventOnsets);
        
        if isTestMode
            addStatus(sprintf('TEST: Detected %d events with current parameters', numEvents));
        else
            addStatus(sprintf('Detected %d network events', numEvents));
        end
        
        % Store results
        setappdata(fig, 'eventOnsets', eventOnsets);
        setappdata(fig, 'eventOffsets', eventOffsets);
        setappdata(fig, 'eventStarts', eventStarts);
        setappdata(fig, 'eventEnds', eventEnds);
        setappdata(fig, 'timeCenters', timeCenters);
        setappdata(fig, 'populationFiringRate', populationFiringRate);
        setappdata(fig, 'activeChannelsOverTime', activeChannelsOverTime);
        setappdata(fig, 'thresholdFR', thresholdFR);
        setappdata(fig, 'eventSDMultiplier', multiplier);
        setappdata(fig, 'eventMinChannels', minChannels);
        setappdata(fig, 'eventMaxChannels', maxChannels);
        
        % Visualize results
        visualizeNetworkEvents();
    end
    
    function visualizeNetworkEvents()
    % Get data
    timeCenters = getappdata(fig, 'timeCenters');
    populationFiringRate = getappdata(fig, 'populationFiringRate');
    activeChannelsOverTime = getappdata(fig, 'activeChannelsOverTime');
    thresholdFR = getappdata(fig, 'thresholdFR');
    eventOnsets = getappdata(fig, 'eventOnsets');
    eventOffsets = getappdata(fig, 'eventOffsets');
    figuresFolder = getappdata(fig, 'figuresFolder');
    
    if isempty(timeCenters)
        addStatus('No event data to visualize');
        return;
    end
    
    % Plot in mainAxes
    axes(findobj('Tag', 'mainAxes'));
    cla;
    plot(timeCenters, populationFiringRate, 'b-', 'LineWidth', 1.5);
    hold on;
    yline(thresholdFR, 'r--', sprintf('Threshold (%.2f Hz)', thresholdFR), 'LineWidth', 1.5);
    
    % Mark events
    for e = 1:length(eventOnsets)
        xline(eventOnsets(e), 'g--', 'LineWidth', 1);
        xline(eventOffsets(e), 'm--', 'LineWidth', 1);
    end
    
    xlabel('Time (s)');
    ylabel('Population Firing Rate (Hz)');
    title(sprintf('Network Events Detection (%d events)', length(eventOnsets)));
    grid on;
    legend('Pop. FR', 'Threshold', 'Event Onset', 'Event End', 'Location', 'best');
    hold off;
    
    % Plot in secondAxes
    axes(findobj('Tag', 'secondAxes'));
    cla;
    plot(timeCenters, activeChannelsOverTime, 'b-', 'LineWidth', 1.5);
    hold on;
    
    % Mark events
    for e = 1:length(eventOnsets)
        xline(eventOnsets(e), 'g--', 'LineWidth', 1);
        xline(eventOffsets(e), 'm--', 'LineWidth', 1);
    end
    
    xlabel('Time (s)');
    ylabel('Active Channels');
    title('Active Channels Over Time');
    grid on;
    hold off;
    
    addStatus('Visualization complete');
    
    % Save the detection plot if figuresFolder exists
    if ~isempty(figuresFolder) && ~isempty(eventOnsets)
        % Create invisible figure with both subplots
        hFig = figure('Visible', 'off', 'Position', [100, 100, 1000, 600]);
        
        % Subplot 1: Population Firing Rate
        subplot(2,1,1);
        plot(timeCenters, populationFiringRate, 'b-', 'LineWidth', 1.5);
        hold on;
        yline(thresholdFR, 'r--', 'Threshold', 'LineWidth', 1.5);
        
        % Mark events
        for e = 1:min(length(eventOnsets), 10)  % Limit labels for clarity
            xline(eventOnsets(e), 'g--', 'LineWidth', 1);
            xline(eventOffsets(e), 'm--', 'LineWidth', 1);
        end
        
        xlabel('Time (s)');
        ylabel('Population Firing Rate (Hz)');
        title('Population Firing Rate Over Time');
        legend('Pop. FR', 'Threshold', 'Event Onset', 'Event End', 'Location', 'best');
        grid on;
        hold off;
        
        % Subplot 2: Active Channels
        subplot(2,1,2);
        plot(timeCenters, activeChannelsOverTime, 'b-', 'LineWidth', 1.5);
        hold on;
        
        minChannels = getappdata(fig, 'eventMinChannels');
        if ~isempty(minChannels)
            yline(minChannels, 'r--', 'Threshold', 'LineWidth', 1.5);
        end
        
        % Mark events
        for e = 1:min(length(eventOnsets), 10)
            xline(eventOnsets(e), 'g--', 'LineWidth', 1);
            xline(eventOffsets(e), 'm--', 'LineWidth', 1);
        end
        
        xlabel('Time (s)');
        ylabel('Active Channels');
        title('Active Channels Over Time');
        legend('Active Channels', 'Threshold', 'Event Onset', 'Event End', 'Location', 'best');
        grid on;
        hold off;
        
        % Save
        print(hFig, fullfile(figuresFolder, 'Detection'), '-dpng', '-r300');
        set(hFig, 'Visible', 'on');
        savefig(hFig, fullfile(figuresFolder, ['Detection' '.fig']));
        close(hFig);
        
        addStatus('Detection plot saved to figures folder');
    end
end
    
    function exportResults(~, ~)
        if ~getappdata(fig, 'eventParametersAccepted')
            answer = questdlg('Event parameters not accepted yet. Export anyway?', ...
                             'Export Warning', 'Yes', 'No', 'No');
            if strcmp(answer, 'No')
                return;
            end
        end
        
        addStatus('-----------------------------------');
        addStatus('Starting export...');
        
        outputFolder = getappdata(fig, 'outputFolder');
        figuresFolder = getappdata(fig, 'figuresFolder');
        
        if isempty(outputFolder)
            addStatus('ERROR: Please select output folder first');
            return;
        end
        
        % Export current figures
        try
            % Save main axes
            f1 = figure('Visible', 'off');
            ax = findobj('Tag', 'mainAxes');
            newAx = copyobj(ax, f1);
            set(newAx, 'Units', 'normalized', 'Position', [0.1 0.1 0.8 0.8]);
            print(f1, fullfile(figuresFolder, 'MainView.png'), '-dpng', '-r300');
            set(f1, 'Visible', 'on');
            savefig(f1, fullfile(figuresFolder, 'MainView.fig'));
            close(f1);
            
            % Save second axes
            f2 = figure('Visible', 'off');
            ax = findobj('Tag', 'secondAxes');
            newAx = copyobj(ax, f2);
            set(newAx, 'Units', 'normalized', 'Position', [0.1 0.1 0.8 0.8]);
            print(f2, fullfile(figuresFolder, 'SecondView.png'), '-dpng', '-r300');
            set(f2, 'Visible', 'on');
            savefig(f2, fullfile(figuresFolder, 'SecondView.fig'));
            close(f2);
            
            addStatus('Figures exported successfully');
        catch ME
            addStatus(['Export error: ' ME.message]);
        end
        
        addStatus('Export complete!');
    end
    
    function addStatus(msg)
    statusBox = findobj('Tag', 'statusLog');
    if isempty(statusBox)
        return;
    end
    
    % Validate and convert input
    if nargin < 1 || isempty(msg)
        msg = 'Status update';
    end
    if ~ischar(msg) && ~isstring(msg)
        try
            msg = char(string(msg));
        catch
            msg = 'Invalid message';
        end
    end
    
    % Ensure msg is char
    msg = char(msg);
    
    % Create timestamp
    try
        timestamp = datestr(now, 'HH:MM:SS');
    catch
        timestamp = '00:00:00';
    end
    
    % Build message
    newEntry = [timestamp, ' - ', msg];
    
    % Get current strings
    try
        currentText = get(statusBox, 'String');
    catch
        currentText = {};
    end
    
    % Convert to cell array if needed
    if isempty(currentText)
        currentText = {};
    elseif ischar(currentText)
        currentText = {currentText};
    elseif ~iscell(currentText)
        currentText = {};
    end
    
    % Filter out any invalid entries
    validText = {};
    for i = 1:numel(currentText)
        item = currentText{i};
        if ischar(item) && ~isempty(item)
            validText{end+1} = item;
        elseif isstring(item) && strlength(item) > 0
            validText{end+1} = char(item);
        end
    end
    
    % Add new entry
    validText{end+1} = newEntry;
    
    % Limit to 100 entries
    if numel(validText) > 100
        validText = validText(end-99:end);
    end
    
    % Set the string
    try
        set(statusBox, 'String', validText);
        % Set scroll position
        if numel(validText) > 0
            set(statusBox, 'Value', numel(validText));
        end
    catch ME
        % Emergency fallback
        try
            set(statusBox, 'String', {newEntry});
            set(statusBox, 'Value', 1);
        catch
            % Give up silently
        end
    end
    
    drawnow;
    
    % ==================== NEW: SAVE TO APPDATA ====================
    try
        statusLog = getappdata(fig, 'statusLog');
        if isempty(statusLog)
            statusLog = {};
        end
        statusLog{end+1} = newEntry;
        setappdata(fig, 'statusLog', statusLog);
    catch
        % Silently ignore if appdata save fails
    end
    % ==============================================================
end

    function saveEventRefChannels(~, ~)
        % Called when eventRefChannels edit field changes - persist to session
        eventRefEdit = findobj(fig, 'Tag', 'eventRefChannels');
        if ~isempty(eventRefEdit)
            val = strtrim(get(eventRefEdit, 'String'));
            sessionSettings.lastEventRefChannels = val;
            setappdata(fig, 'sessionSettings', sessionSettings);
            saveSessionSettings(sessionSettings);
        end
        updateSettingsDisplay();
    end

    function setPatientMetadata(~, ~)
        % Show dialog to set/update patient metadata stored in sessionSettings.
        % These fields are reused across multiple exports from the same session.
        
        meta = struct();
        if isfield(sessionSettings, 'patientMeta') && isstruct(sessionSettings.patientMeta) ...
                && isfield(sessionSettings.patientMeta, 'sliceID')
            meta = sessionSettings.patientMeta;
        end
        
        def_sliceID    = getMetaField(meta, 'sliceID',     '');
        def_tissue     = getMetaField(meta, 'tissueType',  '');
        def_side       = getMetaField(meta, 'side',        'Left');
        def_area       = getMetaField(meta, 'brainArea',   'Temporal');
        def_age        = getMetaField(meta, 'patientAge',  '');
        def_gender     = getMetaField(meta, 'gender',      'M');
        def_quality    = getMetaField(meta, 'layerQuality','Good');
        def_div        = getMetaField(meta, 'div',         '');
        % NEU V3: noisy_channels.json auto-einlesen fuer Metadaten-Dialog
        % Prioritaet: 1) JSON-Datei im H5-Ordner, 2) patientMeta, 3) sessionSettings
        noisyFromJSON = '';
        h5PathForMeta = getappdata(fig, 'h5FilePath');
        if isempty(h5PathForMeta), h5PathForMeta = h5FilePath; end
        if ~isempty(h5PathForMeta) && ischar(h5PathForMeta)
            jsonPathMeta = fullfile(fileparts(h5PathForMeta), 'noisy_channels.json');
            if exist(jsonPathMeta, 'file')
                try
                    jd = jsondecode(fileread(jsonPathMeta));
                    if isfield(jd, 'noisy_channels')
                        cl = jd.noisy_channels;
                        if ischar(cl),   cl = {cl}; end
                        if isstring(cl), cl = cellstr(cl); end
                        noisyFromJSON = strjoin(strtrim(cl), ',');
                    end
                catch
                end
            end
        end

        def_noisy = noisyFromJSON;
        if isempty(def_noisy)
            def_noisy = getMetaField(meta, 'noisyChannels', ...
                            getMetaField(sessionSettings, 'lastNoisyChannels', ''));
        end
        def_exp        = getMetaField(meta, 'experimenter', '');
        def_notes      = getMetaField(meta, 'notes',       '');
        
        prompt = {
            'Slice ID (Format: YYSSTTTSSS, z.B. 2519CT073):';
            'Tissue Type Code (CT=Cortex Tumor, ET=Epilepsy Temp, etc):';
            'Side (Left / Right):';
            'Brain Area (Temporal, Frontal, Parietal):';
            'Patient Age (Jahre, z.B. 45):';
            'Gender (M / F):';
            'Cortical Layer Quality (Good / Fair / Poor):';
            'Days In Vitro (DIV, z.B. 13):';
            'Noisy Channels (kommagetrennt, z.B. A2,B3):';
            'Experimenter Initials:';
            'Additional Notes:'
        };
        dlgtitle = 'Patient Metadata (wird fuer alle DB-Exporte dieser Session gespeichert)';
        dims     = [1 72];
        definput = {def_sliceID; def_tissue; def_side; def_area; def_age; ...
                    def_gender; def_quality; def_div; def_noisy; def_exp; def_notes};
        
        answer = inputdlg(prompt, dlgtitle, dims, definput);
        if isempty(answer)
            addStatus('Patient metadata: Eingabe abgebrochen');
            return;
        end
        
        sessionSettings.patientMeta.sliceID       = strtrim(answer{1});
        sessionSettings.patientMeta.tissueType     = strtrim(answer{2});
        sessionSettings.patientMeta.side           = strtrim(answer{3});
        sessionSettings.patientMeta.brainArea      = strtrim(answer{4});
        sessionSettings.patientMeta.patientAge     = strtrim(answer{5});
        sessionSettings.patientMeta.gender         = strtrim(answer{6});
        sessionSettings.patientMeta.layerQuality   = strtrim(answer{7});
        sessionSettings.patientMeta.div            = strtrim(answer{8});
        sessionSettings.patientMeta.noisyChannels  = strtrim(answer{9});
        sessionSettings.patientMeta.experimenter   = strtrim(answer{10});
        sessionSettings.patientMeta.notes          = strtrim(answer{11});
        
        % Also sync noisy channels into sessionSettings
        if ~isempty(sessionSettings.patientMeta.noisyChannels)
            sessionSettings.lastNoisyChannels = sessionSettings.patientMeta.noisyChannels;
        end
        
        setappdata(fig, 'sessionSettings', sessionSettings);
        saveSessionSettings(sessionSettings);
        updateSettingsDisplay();
        
        addStatus(sprintf('Patient metadata gespeichert: %s | %s | DIV %s', ...
            sessionSettings.patientMeta.sliceID, ...
            sessionSettings.patientMeta.tissueType, ...
            sessionSettings.patientMeta.div));
    end

    function val = getMetaField(s, field, default)
        % Helper: safely read a field from a struct
        if isstruct(s) && isfield(s, field) && ~isempty(s.(field))
            val = s.(field);
        else
            val = default;
        end
    end

    function updateSettingsDisplay()
        % Update the settings display panel with current values
        % Find the main figure explicitly to ensure we have the right handle
        mainFig = findobj('Type', 'figure', 'Name', 'MEA Analysis Suite - Complete Version');
        if isempty(mainFig)
            return;  % Figure not found, skip update
        end
        mainFig = mainFig(1);  % Use first if multiple
        
        % Recording Type (from output folder name)
        outputFolder = getappdata(mainFig, 'outputFolder');
        outputFolderLabel = findobj(mainFig, 'Tag', 'settingsOutputFolder');
        if ~isempty(outputFolderLabel)
            if ~isempty(outputFolder)
                % Show folder name = Recording Type for database
                [~, folderName] = fileparts(outputFolder);
                set(outputFolderLabel, 'String', folderName, 'ForegroundColor', [0 0.5 0]);
                set(outputFolderLabel, 'TooltipString', ['Full path: ' outputFolder]);
            else
                set(outputFolderLabel, 'String', '(not set)', 'ForegroundColor', [0.5 0.5 0.5]);
            end
        end
        
        % LayerDic
        LayerDic = getappdata(mainFig, 'LayerDic');
        layerDicLabel = findobj(mainFig, 'Tag', 'settingsLayerDic');
        if ~isempty(layerDicLabel)
            if ~isempty(LayerDic) && any(LayerDic(:) > 0)
                numElectrodes = sum(LayerDic(:) > 0);
                meaType = getappdata(mainFig, 'meaType');
                if isempty(meaType)
                    meaType = '';
                end
                set(layerDicLabel, 'String', sprintf('%d electrodes (%s)', numElectrodes, meaType), ...
                    'ForegroundColor', [0 0.5 0]);
            else
                set(layerDicLabel, 'String', '(not loaded)', 'ForegroundColor', [0.5 0.5 0.5]);
            end
        end
        
        % Noisy Channels
        noisyChannelsLabel = findobj(mainFig, 'Tag', 'settingsNoisyChannels');
        if ~isempty(noisyChannelsLabel)
            sessionSettings = getappdata(mainFig, 'sessionSettings');
            if ~isempty(sessionSettings) && isfield(sessionSettings, 'lastNoisyChannels') && ...
                    ~isempty(sessionSettings.lastNoisyChannels)
                set(noisyChannelsLabel, 'String', sessionSettings.lastNoisyChannels, ...
                    'ForegroundColor', [0.8 0 0]);
            else
                set(noisyChannelsLabel, 'String', '(none)', 'ForegroundColor', [0.5 0.5 0.5]);
            end
        end
        
        % Ref Channel (Test) + Event Ref Channels
        refChannelLabel = findobj(mainFig, 'Tag', 'settingsRefChannel');
        refChannelEdit = findobj(mainFig, 'Tag', 'refChannel');
        eventRefEdit   = findobj(mainFig, 'Tag', 'eventRefChannels');
        if ~isempty(refChannelLabel)
            testCh  = '';
            eventCh = '';
            if ~isempty(refChannelEdit)
                testCh = strtrim(get(refChannelEdit, 'String'));
            end
            if ~isempty(eventRefEdit)
                eventCh = strtrim(get(eventRefEdit, 'String'));
            end
            if isempty(eventCh)
                dispStr = sprintf('T:%s  E:(alle)', testCh);
            else
                dispStr = sprintf('T:%s  E:%s', testCh, eventCh);
            end
            set(refChannelLabel, 'String', dispStr, 'ForegroundColor', [0 0.5 0]);
        end
        
        % H5 File
        h5FilePathStored = getappdata(mainFig, 'h5FilePath');
        h5FileLabel = findobj(mainFig, 'Tag', 'settingsH5File');
        if ~isempty(h5FileLabel)
            if ~isempty(h5FilePathStored)
                [~, fileName, ext] = fileparts(h5FilePathStored);
                set(h5FileLabel, 'String', [fileName ext], 'ForegroundColor', [0 0.5 0]);
                set(h5FileLabel, 'TooltipString', h5FilePathStored);  % Full path on hover
            else
                set(h5FileLabel, 'String', '(not loaded)', 'ForegroundColor', [0.5 0.5 0.5]);
            end
        end
        
        % Patient Metadata
        metaLabel = findobj(mainFig, 'Tag', 'settingsPatientMeta');
        if ~isempty(metaLabel)
            ss = getappdata(mainFig, 'sessionSettings');
            if ~isempty(ss) && isfield(ss, 'patientMeta') && isstruct(ss.patientMeta) ...
                    && isfield(ss.patientMeta, 'sliceID') && ~isempty(ss.patientMeta.sliceID)
                pm = ss.patientMeta;
                ageStr = pm.patientAge;
                if isempty(ageStr), ageStr = '?'; end
                divStr = pm.div;
                if isempty(divStr), divStr = '?'; end
                metaStr = sprintf('%s  |  %s  |  %s/%sy  |  DIV%s', ...
                    pm.sliceID, pm.tissueType, pm.gender, ageStr, divStr);
                set(metaLabel, 'String', metaStr, 'ForegroundColor', [0 0.4 0.8]);
            else
                set(metaLabel, 'String', '(not set)', 'ForegroundColor', [0.5 0.5 0.5]);
            end
        end
        
        drawnow;
    end

   function generateSummaryAndFigures(~, ~)
    addStatus('Starting summary and figure generation...');
    
    % Get all necessary data
    spikeData = getappdata(fig, 'spikeData');
    firingRates = getappdata(fig, 'firingRates');
    LayerDic = getappdata(fig, 'LayerDic');
    filteredChannelData = getappdata(fig, 'filteredChannelData');
    totalDuration = getappdata(fig, 'totalDuration');
    figuresFolder = getappdata(fig, 'figuresFolder');
    TimeWindow = getappdata(fig, 'TimeWindow');
    samplingRate = getappdata(fig, 'samplingRate');
    eventOnsets = getappdata(fig, 'eventOnsets');
    eventOffsets = getappdata(fig, 'eventOffsets');
    
    if isempty(spikeData) || isempty(firingRates)
        addStatus('ERROR: Please run spike detection first');
        return;
    end
    
    if isempty(figuresFolder)
        addStatus('ERROR: Please select output folder first');
        return;
    end
    
    % Get sorted channels
    channelNames = fieldnames(spikeData);
    sortedChannels = sort(channelNames);
    
    try
        % Generate Firing Rate Heatmap
        addStatus('Generating firing rate heatmap...');
        generateFiringRateHeatmap(sortedChannels, firingRates, figuresFolder);
        
        % Generate Layer Analysis and get table
        if ~isempty(LayerDic)
            addStatus('Generating layer analysis...');
            LayerFiringRatesTable = generateLayerAnalysis(sortedChannels, spikeData, firingRates, LayerDic, totalDuration, figuresFolder);
            setappdata(fig, 'LayerFiringRatesTable', LayerFiringRatesTable);
        end
        
        % Generate Spike Waveform Analysis (if we have filtered data)
        if ~isempty(filteredChannelData) && ~isempty(TimeWindow) && ~isempty(samplingRate)
            addStatus('Generating spike waveform analysis...');
            [ClusterSummaryTable, PostHocResults] = generateSpikeWaveformAnalysis(sortedChannels, spikeData, filteredChannelData, TimeWindow, samplingRate, totalDuration, figuresFolder);
            setappdata(fig, 'ClusterSummaryTable', ClusterSummaryTable);
            setappdata(fig, 'PostHocResults', PostHocResults);
        else
            addStatus('Skipping waveform analysis (missing data)');
        end
        
        % Generate Event Analysis (if we have events)
        if ~isempty(eventOnsets) && length(eventOnsets) >= 2
            addStatus('Generating event analysis...');
            [CorrelationTable, HistogramData] = generateEventAnalysis(sortedChannels, spikeData, eventOnsets, eventOffsets, samplingRate, figuresFolder);
            setappdata(fig, 'CorrelationTable', CorrelationTable);
            setappdata(fig, 'HistogramData', HistogramData);
        else
            addStatus('Skipping event analysis (need at least 2 events)');
        end
        
        % Generate Summary Table
        addStatus('Generating summary table...');
        SummaryTable = generateSummaryTable();
        setappdata(fig, 'SummaryTable', SummaryTable);
        
        % Generate Event Table
        if ~isempty(eventOnsets)
            EventTable = generateEventTable();
            setappdata(fig, 'EventTable', EventTable);
        end
        
        % Generate Overview Figure
        addStatus('Generating overview figure...');
        generateOverviewFigure(figuresFolder);
        
        % Create Master Excel File with all tables
        outputFolder = getappdata(fig, 'outputFolder');
        if ~isempty(outputFolder)
            addStatus('Creating master Excel file...');
            createMasterExcelFile(outputFolder, figuresFolder);
        end
        
        % Save the status log
        addStatus('Saving status log...');
        saveStatusLog();  % ← ADD THIS LINE
        
        addStatus('All figures, Excel file, and log saved successfully!');
        
    catch ME
        addStatus(['ERROR during analysis: ' ME.message]);
        fprintf('Error details: %s\n', getReport(ME));
    end
end

function generateFiringRateHeatmap(sortedChannels, firingRates, figuresFolder)
    % Initialize matrix
    columns = {'A','B','C','D','E','F','G','H','J','K','L','M','N','O','P','R'};
    rows = 1:16;
    firingRateMatrix = NaN(length(rows), length(columns));
    
    % Populate matrix
    for idx = 1:length(sortedChannels)
        channel = sortedChannels{idx};
        tokens = regexp(channel, '([A-Z]+)(\d+)', 'tokens');
        if isempty(tokens), continue; end
        
        colLetter = tokens{1}{1};
        rowNumber = str2double(tokens{1}{2});
        if isnan(rowNumber) || rowNumber < 1 || rowNumber > 16, continue; end
        
        colIdx = find(strcmp(columns, colLetter));
        if isempty(colIdx), continue; end
        
        if isfield(firingRates, channel)
            firingRateMatrix(rowNumber, colIdx) = firingRates.(channel);
        end
    end
    
    % Create NEW figure (not the GUI!)
    hFig = figure('Name', 'MEA Firing Rate Heatmap', 'NumberTitle', 'off', ...
                  'Visible', 'off');
    imagesc(firingRateMatrix);
    colormap('jet');
    colorbar;
    title('Firing Rates per Electrode (Hz)');
    xlabel('Electrode Column');
    ylabel('Electrode Row');
    xticks(1:length(columns));
    xticklabels(columns);
    yticks(1:length(rows));
    yticklabels(rows);
    set(gca, 'YDir', 'reverse');
    
    % Save and close THIS specific figure
    print(hFig, fullfile(figuresFolder, 'MEA_Firing_Rate_Heatmap'), '-dpng', '-r300');
    set(hFig, 'Visible', 'on');
    savefig(hFig, fullfile(figuresFolder, ['MEA_Firing_Rate_Heatmap' '.fig']));
    close(hFig);
end

    function LayerFiringRatesTable = generateLayerAnalysis(sortedChannels, spikeData, firingRates, LayerDic, totalDuration, figuresFolder)    
    % Layer names
    layerNames = {'L1', 'L2/3', 'L4', 'L5/6', 'Whitematter'};
    numLayers = 5;
    
    % Initialize variables
    totalSpikesPerLayer = zeros(numLayers,1);
    totalElectrodesPerLayer = zeros(numLayers,1);
    activeElectrodesPerLayer = zeros(numLayers,1);
    firingRatesPerLayer = cell(numLayers,1);
    
    totalSpikes = 0;
    maxFiringRate = 0;
    spikesPerMinuteThreshold = 5;
    numActiveElectrodes = 0;
    
    % MEA column labels - get from appdata
    meaType = getappdata(fig, 'meaType');
    if contains(meaType, 'J-naming')
        columns = {'A','B','C','D','E','F','G','H','J','K','L','M','N','O','P','R'};
    else
        columns = {'A','B','C','D','E','F','G','H','I','K','L','M','N','O','P','R'};
    end
    rows = 1:16;
    
    % Analyze each electrode
    for idx = 1:length(sortedChannels)
        channelName = sortedChannels{idx};
        numSpikes = length(spikeData.(channelName).times);
        firingRate = firingRates.(channelName);
        
        totalSpikes = totalSpikes + numSpikes;
        if firingRate > maxFiringRate
            maxFiringRate = firingRate;
        end
        
        spikesPerMinute = numSpikes / (totalDuration / 60);
        isActiveElectrode = spikesPerMinute >= spikesPerMinuteThreshold;
        if isActiveElectrode
            numActiveElectrodes = numActiveElectrodes + 1;
        end
        
        [row, col] = electrodeNameToIndex(channelName);
        layerVal = LayerDic(row, col);
        
        if layerVal >= 1 && layerVal <= numLayers
            totalSpikesPerLayer(layerVal) = totalSpikesPerLayer(layerVal) + numSpikes;
            totalElectrodesPerLayer(layerVal) = totalElectrodesPerLayer(layerVal) + 1;
            firingRatesPerLayer{layerVal} = [firingRatesPerLayer{layerVal}; firingRate];
            if isActiveElectrode
                activeElectrodesPerLayer(layerVal) = activeElectrodesPerLayer(layerVal) + 1;
            end
        end
    end
    
    % Compute statistics
    meanFiringRatePerLayer = zeros(numLayers,1);
    maxFiringRatePerLayer = zeros(numLayers,1);
    minFiringRatePerLayer = zeros(numLayers,1);
    
    for layerIdx = 1:numLayers
        if ~isempty(firingRatesPerLayer{layerIdx})
            meanFiringRatePerLayer(layerIdx) = mean(firingRatesPerLayer{layerIdx});
            maxFiringRatePerLayer(layerIdx) = max(firingRatesPerLayer{layerIdx});
            minFiringRatePerLayer(layerIdx) = min(firingRatesPerLayer{layerIdx});
        else
            meanFiringRatePerLayer(layerIdx) = NaN;
            maxFiringRatePerLayer(layerIdx) = NaN;
            minFiringRatePerLayer(layerIdx) = NaN;
        end
    end
    
    percentageActiveElectrodesPerLayer = (activeElectrodesPerLayer ./ totalElectrodesPerLayer) * 100;
    
    % ========== CREATE FIGURE (CORRECTED VISUALIZATION) ==========
    hFig = figure('Name', 'MEA Electrodes, Layers, and Active Electrodes', 'NumberTitle', 'off', ...
                  'Position', [100, 100, 1000, 800], ...
                  'Visible', 'off');
    tiledlayout(2,1, 'TileSpacing', 'Compact', 'Padding', 'Compact');
    
    % First tile: Layer map with active electrodes
    nexttile;
    
    % Display LayerDic WITHOUT transpose or rotation
    imagesc(LayerDic, [0 5]);
    axis square;
    set(gca, 'YDir', 'reverse');  % Row 1 at top
    
    % Set correct column labels
    xticks(1:16);
    xticklabels(columns);
    xlabel('Electrode Column');
    
    yticks(1:16);
    yticklabels(rows);
    ylabel('Electrode Row');
    
    % Define colormap
    cmap = [0.5 0.5 0.5;   % 0 = gray
            0 0 0;         % 1 = black (L1)
            1 0 0;         % 2 = red (L2/3)
            0 1 0;         % 3 = green (L4)
            0 0 1;         % 4 = blue (L5/6)
            1 1 0];        % 5 = yellow (WM)
    colormap(gca, cmap);
    
    % Add layer labels
    hold on;
    labels = {'', 'L1', 'L2/3', 'L4', 'L5/6', 'WM'};
    for row = 1:16
        for col = 1:16
            val = LayerDic(row, col);
            if val > 0
                text(col, row, labels{val + 1}, ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'FontSize', 8, ...
                    'FontWeight', 'bold', ...
                    'Color', 'white');
            end
        end
    end
    
    % Overlay active electrodes with stars
    for idx = 1:length(sortedChannels)
        channelName = sortedChannels{idx};
        numSpikes = length(spikeData.(channelName).times);
        spikesPerMinute = numSpikes / (totalDuration / 60);
        
        if spikesPerMinute >= spikesPerMinuteThreshold
            [row, col] = electrodeNameToIndex(channelName);
            
            % CORRECTED: plot(x, y) = plot(col, row)
            plot(col, row, 'k*', 'MarkerSize', 8, 'LineWidth', 1.5);
        end
    end
    
    title('MEA Electrodes, Layers, and Active Electrodes');
    hold off;
    
    % Second tile: Layer statistics table
    nexttile;
    axis off;
    xlim([0 1]);
    ylim([0 1]);
    
    % Create table data
    LayerFiringRatesTable = table();
    LayerFiringRatesTable.Layer = layerNames';
    LayerFiringRatesTable.Num_Electrodes = totalElectrodesPerLayer;
    LayerFiringRatesTable.Num_Active = activeElectrodesPerLayer;
    LayerFiringRatesTable.Pct_Active = percentageActiveElectrodesPerLayer;
    LayerFiringRatesTable.Mean_FR_Hz = meanFiringRatePerLayer;
    LayerFiringRatesTable.Max_FR_Hz = maxFiringRatePerLayer;
    LayerFiringRatesTable.Min_FR_Hz = minFiringRatePerLayer;
    
    % Display as formatted text
    tableData = table2cell(LayerFiringRatesTable);
    colNames = LayerFiringRatesTable.Properties.VariableNames;
    
    % Build display matrix
    numRows = size(tableData, 1) + 1;
    numCols = length(colNames);
    displayData = cell(numRows, numCols);
    displayData(1, :) = colNames;
    displayData(2:end, :) = tableData;
    
    % Format each row
    yPositions = linspace(0.95, 0.05, numRows);
    for row = 1:numRows
        rowStr = '';
        for col = 1:numCols
            if isnumeric(displayData{row,col})
                cellStr = sprintf('%.2f', displayData{row,col});
            else
                cellStr = displayData{row,col};
            end
            rowStr = [rowStr, sprintf('%-18s', cellStr)];
        end
        text(0.05, yPositions(row), rowStr, ...
             'FontName', 'Courier New', 'FontSize', 9, ...
             'VerticalAlignment', 'top', 'Interpreter', 'none');
    end
    title('Layer Firing Rates Statistics');
    
    % Save and close
    print(hFig, fullfile(figuresFolder, 'MEA_Electrodes_Layers_and_Active_Electrodes'), '-dpng', '-r300');
    set(hFig, 'Visible', 'on');
    savefig(hFig, fullfile(figuresFolder, ['MEA_Electrodes_Layers_and_Active_Electrodes' '.fig']));
    close(hFig);
end


    function [ClusterSummaryTable, PostHocResults] = generateSpikeWaveformAnalysis(sortedChannels, spikeData, filteredChannelData, TimeWindow, samplingRate, totalDuration, figuresFolder)
    % Spike Waveform Clustering Analysis (PCA + K-means)
    
    % Define snippet extraction parameters
    snippetPreTime = 0.001;  % 1 ms before spike
    snippetPostTime = 0.002; % 2 ms after spike
    
    preSamples = round(snippetPreTime * samplingRate);
    postSamples = round(snippetPostTime * samplingRate);
    snippetLength = preSamples + postSamples + 1;
    
    % Pre-count total valid spikes for pre-allocation
    totalValidSpikes = 0;
    for idx = 1:length(sortedChannels)
        channel = sortedChannels{idx};
        if ~isfield(spikeData, channel) || ~isfield(filteredChannelData, channel)
            continue;
        end
        signal = filteredChannelData.(channel);
        spikeTimes = spikeData.(channel).times;
        spikeIndices = round((spikeTimes - TimeWindow(1)) * samplingRate) + 1;
        validSpikes = (spikeIndices - preSamples >= 1) & ...
                      (spikeIndices + postSamples <= length(signal));
        totalValidSpikes = totalValidSpikes + sum(validSpikes);
    end
    
    % Pre-allocate arrays
    allSnippets = zeros(totalValidSpikes, snippetLength);
    allChannelLabels = cell(totalValidSpikes, 1);
    snippetIdx = 0;
    
    % Collect snippets from all channels
    for idx = 1:length(sortedChannels)
        channel = sortedChannels{idx};
        if ~isfield(spikeData, channel) || ~isfield(filteredChannelData, channel)
            continue;
        end
        
        signal = filteredChannelData.(channel);
        spikeTimes = spikeData.(channel).times;
        
        % Convert spike times to indices
        spikeIndices = round((spikeTimes - TimeWindow(1)) * samplingRate) + 1;
        
        % Filter valid spikes
        validSpikes = (spikeIndices - preSamples >= 1) & ...
                      (spikeIndices + postSamples <= length(signal));
        spikeIndices = spikeIndices(validSpikes);
        
        numSpikes = length(spikeIndices);
        if numSpikes == 0, continue; end
        
        snippets = zeros(numSpikes, snippetLength);
        for s = 1:numSpikes
            idxSpike = spikeIndices(s);
            snippets(s, :) = signal(idxSpike - preSamples : idxSpike + postSamples);
        end
        
        % Store in pre-allocated arrays
        allSnippets(snippetIdx+1:snippetIdx+numSpikes, :) = snippets;
        allChannelLabels(snippetIdx+1:snippetIdx+numSpikes) = repmat({channel}, numSpikes, 1);
        snippetIdx = snippetIdx + numSpikes;
    end
    
    % Trim if we overestimated (shouldn't happen, but safe)
    allSnippets = allSnippets(1:snippetIdx, :);
    allChannelLabels = allChannelLabels(1:snippetIdx);
    
    if size(allSnippets, 1) < 100
        fprintf('Not enough spikes for clustering (%d found)\n', size(allSnippets,1));
        ClusterSummaryTable = table();
        PostHocResults = table();
        return;
    end
    
    % Preprocess waveforms
    waveformsCentered = bsxfun(@minus, allSnippets, mean(allSnippets, 2));
    peakToPeakAmp = max(waveformsCentered, [], 2) - min(waveformsCentered, [], 2);
    waveformsNormalized = bsxfun(@rdivide, waveformsCentered, peakToPeakAmp);
    waveformsNormalized(~isfinite(waveformsNormalized)) = 0;
    
    % Perform PCA
    [coeff, score, ~, ~, explained] = pca(waveformsNormalized);
    numComponents = 3;
    selectedScores = score(:, 1:numComponents);
    
    % K-means clustering
    numClusters = 4;
    rng(0);
    [idxClusters, ~] = kmeans(selectedScores, numClusters, 'Replicates', 10);
    
    % Compute average waveforms and spike widths
    clusterWaveforms = cell(numClusters, 1);
    spikeWidths = cell(numClusters, 1);
    clusterColors = lines(numClusters);
    
    allSnippetTimes = (-preSamples:postSamples) / samplingRate * 1000; % in ms
    
    for c = 1:numClusters
        clusterIndices = idxClusters == c;
        waveformsInCluster = waveformsNormalized(clusterIndices, :);
        clusterWaveforms{c} = mean(waveformsInCluster, 1);
        
        % Compute spike widths
        numWaveforms = size(waveformsInCluster, 1);
        widths = zeros(numWaveforms, 1);
        for i = 1:numWaveforms
            waveform = waveformsInCluster(i, :);
            [~, peakIdx] = max(waveform);
            [~, troughIdx] = min(waveform);
            widths(i) = abs(allSnippetTimes(troughIdx) - allSnippetTimes(peakIdx));
        end
        spikeWidths{c} = widths;
    end
    
    % Compute firing rates per cluster
    clusterFiringRates = zeros(numClusters, 1);
    for c = 1:numClusters
        clusterIndices = idxClusters == c;
        channelsInCluster = allChannelLabels(clusterIndices);
        uniqueChannels = unique(channelsInCluster);
        
        firingRatesLocal = zeros(length(uniqueChannels), 1);
        for i = 1:length(uniqueChannels)
            channel = uniqueChannels{i};
            spikesInChannelCluster = sum(strcmp(allChannelLabels(clusterIndices), channel));
            firingRatesLocal(i) = spikesInChannelCluster / totalDuration;
        end
        clusterFiringRates(c) = mean(firingRatesLocal);
    end
    
    % Create comprehensive figure
    hFig = figure('Name', 'Spike Waveform Clustering Analysis', 'NumberTitle', 'off', ...
                  'Position', [100, 100, 1200, 800], 'Visible', 'off');
    
    % Subplot 1: Average waveforms
    subplot(2, 2, 1);
    hold on;
    for c = 1:numClusters
        plot(allSnippetTimes, clusterWaveforms{c}, 'Color', clusterColors(c, :), ...
             'LineWidth', 2, 'DisplayName', ['Cluster ' num2str(c)]);
    end
    xlabel('Time (ms)');
    ylabel('Normalized Amplitude');
    title('Average Spike Waveforms per Cluster');
    legend('show');
    grid on;
    hold off;
    
    % Subplot 2: Spike width distributions
    subplot(2, 2, 2);
    hold on;
    for c = 1:numClusters
        histogram(spikeWidths{c}, 'Normalization', 'probability', ...
                 'DisplayName', ['Cluster ' num2str(c)], ...
                 'FaceAlpha', 0.5, 'EdgeColor', 'none', ...
                 'FaceColor', clusterColors(c, :));
    end
    xlabel('Spike Width (ms)');
    ylabel('Probability');
    title('Spike Width Distributions');
    legend('show');
    grid on;
    hold off;
    
    % Subplot 3: Spike width vs firing rate
    subplot(2, 2, 3);
    hold on;
    for c = 1:numClusters
        scatter(mean(spikeWidths{c}), clusterFiringRates(c), 100, ...
               clusterColors(c,:), 'filled', ...
               'DisplayName', ['Cluster ' num2str(c)]);
    end
    xlabel('Mean Spike Width (ms)');
    ylabel('Mean Firing Rate (Hz)');
    title('Spike Width vs. Firing Rate');
    legend('show');
    grid on;
    hold off;
    
    % Subplot 4: PCA scores
    subplot(2, 2, 4);
    hold on;
    for c = 1:numClusters
        clusterIndices = idxClusters == c;
        scatter3(selectedScores(clusterIndices, 1), ...
                selectedScores(clusterIndices, 2), ...
                selectedScores(clusterIndices, 3), ...
                10, clusterColors(c, :), 'filled', ...
                'DisplayName', ['Cluster ' num2str(c)]);
    end
    xlabel('PC1');
    ylabel('PC2');
    zlabel('PC3');
    title('PCA Scores Colored by Cluster');
    legend('show');
    grid on;
    hold off;
    
    % Save figure
    print(hFig, fullfile(figuresFolder, 'Spike_Waveform_Clustering'), '-dpng', '-r300');
    set(hFig, 'Visible', 'on');
    savefig(hFig, fullfile(figuresFolder, ['Spike_Waveform_Clustering' '.fig']));
    close(hFig);
    
    % Save PCA variance explained
    hFig2 = figure('Visible', 'off');
    pareto(explained(1:min(10, length(explained))));
    xlabel('Principal Component');
    ylabel('Variance Explained (%)');
    title('PCA Variance Explained');
    print(hFig2, fullfile(figuresFolder, 'PCA_Variance_Explained'), '-dpng', '-r300');
    set(hFig2, 'Visible', 'on');
    savefig(hFig2, fullfile(figuresFolder, ['PCA_Variance_Explained' '.fig']));
    close(hFig2);
    
    % ==================== CREATE SUMMARY TABLES ====================
    
    % Cluster Summary Table
    Cluster_Number = (1:numClusters)';
    Num_Spikes = zeros(numClusters, 1);
    Num_Channels = zeros(numClusters, 1);
    Mean_Spike_Width_ms = zeros(numClusters, 1);
    Std_Spike_Width_ms = zeros(numClusters, 1);
    Mean_Firing_Rate_Hz = clusterFiringRates;
    
    for c = 1:numClusters
        widths = spikeWidths{c};
        Mean_Spike_Width_ms(c) = mean(widths);
        Std_Spike_Width_ms(c) = std(widths);
        Num_Spikes(c) = length(widths);
        
        % Count unique channels in cluster
        clusterIndices = idxClusters == c;
        channelsInCluster = allChannelLabels(clusterIndices);
        uniqueChannels = unique(channelsInCluster);
        Num_Channels(c) = length(uniqueChannels);
    end
    
    ClusterSummaryTable = table(Cluster_Number, Num_Spikes, Num_Channels, ...
        Mean_Spike_Width_ms, Std_Spike_Width_ms, Mean_Firing_Rate_Hz);
    
    % Statistical Tests
    allWidths = [];
    allClusterLabels = [];
    
    for c = 1:numClusters
        widths = spikeWidths{c};
        allWidths = [allWidths; widths];
        allClusterLabels = [allClusterLabels; repmat(c, length(widths), 1)];
    end
    
    % Perform ANOVA
    [p, ~, stats] = anova1(allWidths, allClusterLabels, 'off');
    
    % Post-hoc tests if significant
    if p < 0.05 && ~isempty(stats)
        try
            [c_posthoc, ~, ~, ~] = multcompare(stats, 'Display', 'off');
            
            % Create table based on number of columns
            numColumns = size(c_posthoc, 2);
            
            if numColumns == 6
                PostHocResults = array2table(c_posthoc, 'VariableNames', ...
                    {'Group1', 'Group2', 'LowerCI', 'MeanDiff', 'UpperCI', 'PValue'});
            elseif numColumns == 5
                PostHocResults = array2table(c_posthoc, 'VariableNames', ...
                    {'Group1', 'Group2', 'LowerCI', 'MeanDiff', 'UpperCI'});
            else
                PostHocResults = array2table(c_posthoc);
            end
        catch
            PostHocResults = table();
        end
    else
        PostHocResults = table();
    end
    end

function [CorrelationTable, HistogramData] = generateEventAnalysis(sortedChannels, spikeData, eventOnsets, eventOffsets, samplingRate, figuresFolder)
   % Event Correlation Analysis
    
    if length(eventOnsets) < 2
        fprintf('Not enough events for correlation analysis (<2)\n');
        CorrelationTable = table();
        HistogramData = table();
        return;
    end
    
    % Define time window around events
    preEventTime = 1;  % 1 second before
    postEventTime = 1; % 1 second after
    windowDuration = preEventTime + postEventTime;
    binSize = 0.025; % 25 ms bins
    
    % Align spike trains to events
    alignedSpikeTrains = cell(length(eventOnsets), 1);
    
    for eventIdx = 1:length(eventOnsets)
        eventTime = eventOnsets(eventIdx);
        windowStart = eventTime - preEventTime;
        windowEnd = eventTime + postEventTime;
        
        spikeTrains = zeros(length(sortedChannels), round(windowDuration * samplingRate));
        
        for channelIdx = 1:length(sortedChannels)
            channelName = sortedChannels{channelIdx};
            spikeTimes = spikeData.(channelName).times;
            
            spikesInWindow = spikeTimes(spikeTimes >= windowStart & spikeTimes <= windowEnd);
            spikeIndices = round((spikesInWindow - windowStart) * samplingRate) + 1;
            
            % Validate indices
            validIndices = spikeIndices(spikeIndices >= 1 & spikeIndices <= size(spikeTrains, 2));
            if ~isempty(validIndices)
                spikeTrains(channelIdx, validIndices) = 1;
            end
        end
        
        alignedSpikeTrains{eventIdx} = spikeTrains;
    end
    
    % Compute spike counts in bins
    numBins = round(windowDuration / binSize);
    spikeCounts = zeros(length(eventOnsets), length(sortedChannels), numBins);
    
    for eventIdx = 1:length(eventOnsets)
        spikeTrains = alignedSpikeTrains{eventIdx};
        for binIdx = 1:numBins
            binStart = round((binIdx - 1) * binSize * samplingRate) + 1;
            binEnd = min(round(binIdx * binSize * samplingRate), size(spikeTrains, 2));
            if binStart <= binEnd && binEnd <= size(spikeTrains, 2)
                spikeCounts(eventIdx, :, binIdx) = sum(spikeTrains(:, binStart:binEnd), 2);
            end
        end
    end
    
    % Compute correlation matrix
    correlationMatrix = zeros(length(eventOnsets));
    for i = 1:length(eventOnsets)
        for j = 1:length(eventOnsets)
            spikeCounts_i = squeeze(spikeCounts(i, :, :));
            spikeCounts_j = squeeze(spikeCounts(j, :, :));
            correlationMatrix(i, j) = corr(spikeCounts_i(:), spikeCounts_j(:));
        end
    end
    
    % Create raster plot of aligned events
    hFig = figure('Name', 'Event-Aligned Raster Plot', 'NumberTitle', 'off', ...
                  'Visible', 'off', 'Position', [100, 100, 1000, 600]);
    
    eventColors = lines(min(length(eventOnsets), 10));
    hold on;
    for eventIdx = 1:min(length(eventOnsets), 10)
        spikeTrains = alignedSpikeTrains{eventIdx};
        for channelIdx = 1:length(sortedChannels)
            spikeTimes = find(spikeTrains(channelIdx, :)) / samplingRate - preEventTime;
            if ~isempty(spikeTimes)
                plot(spikeTimes, channelIdx * ones(size(spikeTimes)), '.', ...
                     'Color', eventColors(mod(eventIdx-1, 10)+1, :), 'MarkerSize', 5);
            end
        end
    end
    xlabel('Time relative to event onset (s)');
    ylabel('Channel');
    title('Event-Aligned Spike Raster Plot');
    xlim([-preEventTime postEventTime]);
    hold off;
    
    print(hFig, fullfile(figuresFolder, 'Event_Aligned_Raster'), '-dpng', '-r300');
    set(hFig, 'Visible', 'on');
    savefig(hFig, fullfile(figuresFolder, ['Event_Aligned_Raster' '.fig']));
    close(hFig);
    
    % Plot correlation matrix
    hFig2 = figure('Visible', 'off');
    imagesc(correlationMatrix);
    colormap('jet');
    colorbar;
    title('Event Cross-Correlation Matrix');
    xlabel('Event Index');
    ylabel('Event Index');
    axis square;
    
    print(hFig2, fullfile(figuresFolder, 'Event_Correlation_Matrix'), '-dpng', '-r300');
    set(hFig2, 'Visible', 'on');
    savefig(hFig2, fullfile(figuresFolder, ['Event_Correlation_Matrix' '.fig']));
    close(hFig2);
    
    % Heatmap of Spike Counts
    meanSpikeCounts = squeeze(mean(spikeCounts, 2));
    
    hFig3 = figure('Visible', 'off');
    imagesc(meanSpikeCounts);
    colorbar;
    title('Heatmap of Spike Counts Across Events');
    xlabel('Time Bins');
    ylabel('Event Index');
    
    numBinsPlot = size(meanSpikeCounts, 2);
    binEdges = linspace(-preEventTime, postEventTime, numBinsPlot + 1);
    binCenters = (binEdges(1:end-1) + binEdges(2:end)) / 2;
    xticks(1:numBinsPlot);
    xticklabels(arrayfun(@(x) sprintf('%.1f', x), binCenters, 'UniformOutput', false));
    
    print(hFig3, fullfile(figuresFolder, 'Heatmap_Spike_Counts'), '-dpng', '-r300');
    set(hFig3, 'Visible', 'on');
    savefig(hFig3, fullfile(figuresFolder, ['Heatmap_Spike_Counts' '.fig']));
    close(hFig3);
    
    % Highest & Lowest Correlation Raster Plots
    if length(eventOnsets) >= 2
        % Exclude diagonal
        correlationMatrix(logical(eye(size(correlationMatrix)))) = NaN;
        
        % Find highest correlation
        [maxCorr, maxIdx] = max(correlationMatrix(:));
        [maxEvent1, maxEvent2] = ind2sub(size(correlationMatrix), maxIdx);
        
        % Find lowest correlation
        [minCorr, minIdx] = min(correlationMatrix(:));
        [minEvent1, minEvent2] = ind2sub(size(correlationMatrix), minIdx);
        
        eventColors2 = lines(2);
        
        % Plot highest correlation
        hFig4 = figure('Visible', 'off', 'Position', [100, 100, 1000, 600]);
        hold on;
        for i = 1:2
            eventIdx = [maxEvent1, maxEvent2];
            eventIdx = eventIdx(i);
            spikeTrains = alignedSpikeTrains{eventIdx};
            
            for channelIdx = 1:length(sortedChannels)
                spikeTimes = find(spikeTrains(channelIdx, :)) / samplingRate - preEventTime;
                plot(spikeTimes, channelIdx * ones(size(spikeTimes)), '.', ...
                     'Color', eventColors2(i, :), 'MarkerSize', 10);
            end
        end
        xlabel('Time (s)');
        ylabel('Channel');
        title(sprintf('Raster Plot: Highest Correlation (Events %d & %d, r = %.2f)', ...
              maxEvent1, maxEvent2, maxCorr));
        legend(sprintf('Event %d', maxEvent1), sprintf('Event %d', maxEvent2), ...
               'Location', 'eastoutside');
        hold off;
        
        print(hFig4, fullfile(figuresFolder, 'Raster_Plot_Highest_Correlation'), '-dpng', '-r300');
        set(hFig4, 'Visible', 'on');
        savefig(hFig4, fullfile(figuresFolder, ['Raster_Plot_Highest_Correlation' '.fig']));
        close(hFig4);
        
        % Plot lowest correlation
        hFig5 = figure('Visible', 'off', 'Position', [100, 100, 1000, 600]);
        hold on;
        for i = 1:2
            eventIdx = [minEvent1, minEvent2];
            eventIdx = eventIdx(i);
            spikeTrains = alignedSpikeTrains{eventIdx};
            
            for channelIdx = 1:length(sortedChannels)
                spikeTimes = find(spikeTrains(channelIdx, :)) / samplingRate - preEventTime;
                plot(spikeTimes, channelIdx * ones(size(spikeTimes)), '.', ...
                     'Color', eventColors2(i, :), 'MarkerSize', 10);
            end
        end
        xlabel('Time (s)');
        ylabel('Channel');
        title(sprintf('Raster Plot: Lowest Correlation (Events %d & %d, r = %.2f)', ...
              minEvent1, minEvent2, minCorr));
        legend(sprintf('Event %d', minEvent1), sprintf('Event %d', minEvent2), ...
               'Location', 'eastoutside');
        hold off;
        
        print(hFig5, fullfile(figuresFolder, 'Raster_Plot_Lowest_Correlation'), '-dpng', '-r300');
        set(hFig5, 'Visible', 'on');
        savefig(hFig5, fullfile(figuresFolder, ['Raster_Plot_Lowest_Correlation' '.fig']));
        close(hFig5);
    end
    
    % ==================== CREATE CORRELATION TABLES ====================
    
    % Convert correlation matrix to table
    CorrelationTable = array2table(correlationMatrix);
    CorrelationTable.Properties.VariableNames = arrayfun(@(x) sprintf('Event%d', x), ...
        1:size(correlationMatrix,2), 'UniformOutput', false);
    
    % Create histogram data from correlation values
    correlationValues = correlationMatrix(~isnan(correlationMatrix) & ~eye(size(correlationMatrix)));
    
    if ~isempty(correlationValues)
        [counts, edges] = histcounts(correlationValues, 'Normalization', 'probability');
        binCenters = (edges(1:end-1) + edges(2:end)) / 2;
        
        HistogramData = table(binCenters', counts', ...
            'VariableNames', {'BinCenter', 'Probability'});
    else
        HistogramData = table();
    end
end

function generateOverviewFigure(figuresFolder)
    % Create overview figure with all main plots
    
    % List of figure files to include
    figureFiles = {
        fullfile(figuresFolder, 'MEA Electrodes and Layers.png');
        fullfile(figuresFolder, 'MEA_Rasterplot.png');
        fullfile(figuresFolder, 'MEA_Firing_Rate_Heatmap.png');
        fullfile(figuresFolder, 'Detection.png');
    };
    
    % Check which files exist
    existingFiles = {};
    for i = 1:length(figureFiles)
        if exist(figureFiles{i}, 'file')
            existingFiles{end+1} = figureFiles{i};
        end
    end
    
    if isempty(existingFiles)
        fprintf('No figures found for overview\n');
        return;
    end
    
    % Create overview figure
    hFig = figure('Name', 'Overview of Figures', 'NumberTitle', 'off', ...
                  'Visible', 'off', 'Position', [100, 100, 1200, 900]);
    
    numFigs = length(existingFiles);
    rows = ceil(sqrt(numFigs));
    cols = ceil(numFigs / rows);
    
    tiledlayout(rows, cols, 'TileSpacing', 'Compact', 'Padding', 'Compact');
    
    for idx = 1:numFigs
        img = imread(existingFiles{idx});
        nexttile;
        imshow(img);
        [~, titleStr, ~] = fileparts(existingFiles{idx});
        titleStr = strrep(titleStr, '_', ' ');
        title(titleStr, 'Interpreter', 'none');
    end
    
    print(hFig, fullfile(figuresFolder, 'Overview_Figure'), '-dpng', '-r300');
    set(hFig, 'Visible', 'on');
    savefig(hFig, fullfile(figuresFolder, ['Overview_Figure' '.fig']));
    close(hFig);
end

   function createMasterExcelFile(outputFolder, figuresFolder)
    % Create comprehensive Excel summary file
    
    % Get folder name for filename
    [~, folderName] = fileparts(outputFolder);
    excelFileName = fullfile(outputFolder, sprintf('Recording_Summary_%s.xlsx', folderName));
    
    % Get all tables
    SummaryTable = getappdata(fig, 'SummaryTable');
    LayerFiringRatesTable = getappdata(fig, 'LayerFiringRatesTable');
    EventTable = getappdata(fig, 'EventTable');
    CorrelationTable = getappdata(fig, 'CorrelationTable');
    HistogramData = getappdata(fig, 'HistogramData');
    ClusterSummaryTable = getappdata(fig, 'ClusterSummaryTable');
    PostHocResults = getappdata(fig, 'PostHocResults');
    
    % Initialize empty tables if they don't exist
    if isempty(SummaryTable), SummaryTable = table(); end
    if isempty(LayerFiringRatesTable), LayerFiringRatesTable = table(); end
    if isempty(EventTable), EventTable = table(); end
    if isempty(CorrelationTable), CorrelationTable = table(); end
    if isempty(HistogramData), HistogramData = table(); end
    if isempty(ClusterSummaryTable), ClusterSummaryTable = table(); end
    if isempty(PostHocResults), PostHocResults = table(); end
    
    try
        % Delete existing file if it exists
        if exist(excelFileName, 'file')
            delete(excelFileName);
        end
        
        % Write all sheets
        if ~isempty(SummaryTable)
            writetable(SummaryTable, excelFileName, 'Sheet', 'Summary');
            fprintf('Written: Summary sheet\n');
        end
        
        if ~isempty(LayerFiringRatesTable)
            writetable(LayerFiringRatesTable, excelFileName, 'Sheet', 'Layer Firing Rates');
            fprintf('Written: Layer Firing Rates sheet\n');
        end
        
        if ~isempty(EventTable)
            writetable(EventTable, excelFileName, 'Sheet', 'Events Detected');
            fprintf('Written: Events Detected sheet\n');
        end
        
        if ~isempty(CorrelationTable)
            writetable(CorrelationTable, excelFileName, 'Sheet', 'Correlation Matrix');
            fprintf('Written: Correlation Matrix sheet\n');
        end
        
        if ~isempty(HistogramData)
            writetable(HistogramData, excelFileName, 'Sheet', 'Histogram Data');
            fprintf('Written: Histogram Data sheet\n');
        end
        
        if ~isempty(ClusterSummaryTable)
            writetable(ClusterSummaryTable, excelFileName, 'Sheet', 'Cluster Summary');
            fprintf('Written: Cluster Summary sheet\n');
        end
        
        if ~isempty(PostHocResults)
            writetable(PostHocResults, excelFileName, 'Sheet', 'Post-hoc Tests');
            fprintf('Written: Post-hoc Tests sheet\n');
        end
        
        fprintf('\n===========================================\n');
        fprintf('Excel file created successfully!\n');
        fprintf('File: %s\n', excelFileName);
        fprintf('Total sheets written: %d\n', sum([~isempty(SummaryTable), ~isempty(LayerFiringRatesTable), ...
            ~isempty(EventTable), ~isempty(CorrelationTable), ~isempty(HistogramData), ...
            ~isempty(ClusterSummaryTable), ~isempty(PostHocResults)]));
        fprintf('===========================================\n\n');
        
    catch ME
        fprintf('Error creating Excel file: %s\n', ME.message);
    end
    
    % Create text summary as backup
    summaryFile = fullfile(outputFolder, 'Analysis_Summary.txt');

    % Retrieve appdata variables needed for workspace save
    spikeData     = getappdata(fig, 'spikeData');
    eventOnsets   = getappdata(fig, 'eventOnsets');
    eventOffsets  = getappdata(fig, 'eventOffsets');
    LayerDic      = getappdata(fig, 'LayerDic');
    Time          = getappdata(fig, 'Time');
    samplingRate  = getappdata(fig, 'samplingRate');
    save(fullfile(outputFolder, 'propagation_workspace.mat'), ...
    'spikeData','eventOnsets','eventOffsets','LayerDic','Time','samplingRate','outputFolder');
    fid = fopen(summaryFile, 'w');
    fprintf(fid, 'MEA Analysis Summary\n');
    fprintf(fid, '===================\n\n');
    fprintf(fid, 'Analysis completed: %s\n', datestr(now));
    fprintf(fid, 'Output folder: %s\n', outputFolder);
    fprintf(fid, 'Figures folder: %s\n', figuresFolder);
    fprintf(fid, 'Excel file: %s\n', excelFileName);
    fclose(fid);
end


    function analyzeEvents(~, ~)
    addStatus('Starting Event Analysis...');
    
    % Get all required data
    outputFolder = getappdata(fig, 'outputFolder');
    spikeData = getappdata(fig, 'spikeData');
    eventOnsets = getappdata(fig, 'eventOnsets');
    eventOffsets = getappdata(fig, 'eventOffsets');
    LayerDic = getappdata(fig, 'LayerDic');
    Time = getappdata(fig, 'Time');
    samplingRate = getappdata(fig, 'samplingRate');
    totalDuration = getappdata(fig, 'totalDuration');
    refractoryTime = str2double(get(findobj('Tag', 'refractoryTime'), 'String'));
    multiplier = str2double(get(findobj('Tag', 'eventSDMultiplier'), 'String'));
    
    % Get stored mean and std
    timeCenters = getappdata(fig, 'timeCenters');
    populationFiringRate_stored = getappdata(fig, 'populationFiringRate');
    
    if ~isempty(populationFiringRate_stored)
        meanFR_stored = mean(populationFiringRate_stored);
        stdFR = std(populationFiringRate_stored);
    else
        % Fallback: calculate from scratch
        binSize = 0.025;
        timeEdges = min(Time):binSize:max(Time);
        timeCenters = timeEdges(1:end-1) + binSize/2;
        
        sortedChannels = sort(fieldnames(spikeData));
        activityMatrix = zeros(length(sortedChannels), length(timeCenters));
        
        for idx = 1:length(sortedChannels)
            channel = sortedChannels{idx};
            if isfield(spikeData, channel)
                spikeTimes = spikeData.(channel).times;
                counts = histcounts(spikeTimes, timeEdges);
                activityMatrix(idx, :) = counts;
            end
        end
        
        populationFR = sum(activityMatrix, 1) / length(sortedChannels) / binSize;
        meanFR_stored = mean(populationFR);
        stdFR = std(populationFR);
    end
    
    % Validation
    if isempty(outputFolder) || isempty(spikeData)
        addStatus('ERROR: Please complete spike detection first');
        return;
    end
    
    if isempty(eventOnsets)
        addStatus('ERROR: No events detected. Run event detection first.');
        return;
    end
    
    % Get sorted channels
    sortedChannels = sort(fieldnames(spikeData));
    
    % Configuration
    preBuffer = 0.50;
    postBuffer = 0.50;
    
    % Data bounds
    dataStartTime = min(Time);
    dataEndTime = max(Time);
    
    % MEA configuration
    columns = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', ...
               'J', 'K', 'L', 'M', 'N', 'O', 'P', 'R'};
    rows = 1:16;
    
    % Create Events folder
    eventsOutputFolder = fullfile(outputFolder, 'Events');
    if ~exist(eventsOutputFolder, 'dir')
        mkdir(eventsOutputFolder);
    end
    
    % Get reference channels from event detection parameters
    refChannelInput = get(findobj('Tag', 'refChannel'), 'String');
    
    % Parse multiple channels
    if ~isempty(refChannelInput)
        refChannels = strsplit(refChannelInput, ',');
        refChannels = strtrim(refChannels); % Remove whitespace
        
        % Validate channels exist
        validRefChannels = {};
        for i = 1:length(refChannels)
            if isfield(spikeData, refChannels{i})
                validRefChannels{end+1} = refChannels{i};
            else
                addStatus(sprintf('Warning: Reference channel %s not found', refChannels{i}));
            end
        end
        
        if isempty(validRefChannels)
            addStatus('ERROR: No valid reference channels found');
            return;
        end
        
        addStatus(sprintf('Using reference channels: %s', strjoin(validRefChannels, ', ')));
        
        % Ask if user wants to use these or specify different ones
        prompt = {sprintf('Current reference channels: %s\n\nPress OK to use these, or enter different channels (comma-separated):', ...
            strjoin(validRefChannels, ', '))};
        dlgtitle = 'Reference Channels for Event Analysis';
        dims = [1 70];
        definput = {strjoin(validRefChannels, ', ')};
        answer = inputdlg(prompt, dlgtitle, dims, definput);
        
        if isempty(answer)
            addStatus('Event analysis cancelled');
            return;
        end
        
        % Parse user's response
        refChannels = strsplit(answer{1}, ',');
        refChannels = strtrim(refChannels);
        
        % Re-validate
        validRefChannels = {};
        for i = 1:length(refChannels)
            if isfield(spikeData, refChannels{i})
                validRefChannels{end+1} = refChannels{i};
            else
                addStatus(sprintf('Warning: Reference channel %s not found, skipping', refChannels{i}));
            end
        end
        
        if isempty(validRefChannels)
            addStatus('ERROR: No valid reference channels specified');
            return;
        end
        
        channelsToPlot = validRefChannels;
        addStatus(sprintf('Final reference channels: %s', strjoin(channelsToPlot, ', ')));
        
    else
        % No reference channels set - ask user
        prompt = {'Enter reference channel(s) (comma-separated, e.g., A14, P13):'};
        dlgtitle = 'Reference Channels';
        dims = [1 70];
        definput = {'C15'};
        answer = inputdlg(prompt, dlgtitle, dims, definput);
        
        if isempty(answer)
            addStatus('Event analysis cancelled');
            return;
        end
        
        % Parse and validate
        refChannels = strsplit(answer{1}, ',');
        refChannels = strtrim(refChannels);
        
        validRefChannels = {};
        for i = 1:length(refChannels)
            if isfield(spikeData, refChannels{i})
                validRefChannels{end+1} = refChannels{i};
            else
                addStatus(sprintf('ERROR: Reference channel %s not found', refChannels{i}));
            end
        end
        
        if isempty(validRefChannels)
            addStatus('ERROR: No valid reference channels specified');
            return;
        end
        
        channelsToPlot = validRefChannels;
        addStatus(sprintf('Using reference channels: %s', strjoin(channelsToPlot, ', ')));
    end
    
    % Event selection menu
    numEvents = length(eventOnsets);
    addStatus(sprintf('Total events detected: %d', numEvents));
    
    prompt2 = {sprintf('Event Selection:\n1=All, 2=First N, 3=Random N, 4=Custom (e.g. 1-3,5,7)')};
    answer2 = inputdlg(prompt2, 'Select Events', [1 60], {'1'});
    
    if isempty(answer2)
        addStatus('Event analysis cancelled');
        return;
    end
    
    selectionChoice = str2double(answer2{1});
    
    switch selectionChoice
        case 1
            eventsToProcess = 1:numEvents;
        case 2
            prompt3 = {'How many events?'};
            answer3 = inputdlg(prompt3, 'Number', [1 35], {'5'});
            if isempty(answer3), return; end
            nEvents = str2double(answer3{1});
            eventsToProcess = 1:min(nEvents, numEvents);
        case 3
            prompt4 = {'How many random events?'};
            answer4 = inputdlg(prompt4, 'Random', [1 35], {'5'});
            if isempty(answer4), return; end
            nRand = str2double(answer4{1});
            if nRand > numEvents, nRand = numEvents; end
            eventsToProcess = randperm(numEvents, nRand);
        case 4
            prompt5 = {'Enter selection (e.g. 1-3,5,7-10):'};
            answer5 = inputdlg(prompt5, 'Custom', [1 50], {'1-5'});
            if isempty(answer5), return; end
            eventsToProcess = parseEventString(answer5{1}, numEvents);
        otherwise
            eventsToProcess = 1:numEvents;
    end
    
    if isempty(eventsToProcess)
        addStatus('No events selected');
        return;
    end
    
    addStatus(sprintf('Processing %d events...', length(eventsToProcess)));
    
    % Map channels to y-positions
    channelYPos = containers.Map();
    for idx = 1:length(sortedChannels)
        channelYPos(sortedChannels{idx}) = idx;
    end
    
    % Process each event
    successCount = 0;
    errorCount = 0;
    
    for eventIdx = eventsToProcess
        try
            eventNumber = eventIdx;
            eventStartTime = eventOnsets(eventIdx);
            eventEndTime = eventOffsets(eventIdx);
            
            addStatus(sprintf('  Processing Event %d/%d...', find(eventsToProcess==eventIdx), length(eventsToProcess)));
            
            % Define epoch with buffers
            epochStartTime = eventStartTime - preBuffer;
            epochEndTime = eventEndTime + postBuffer;
            eventOnsetTime = epochStartTime;
            
            % Check bounds
            if epochStartTime < dataStartTime
                epochStartTime = dataStartTime;
            end
            if epochEndTime > dataEndTime
                epochEndTime = dataEndTime;
            end
            
            epochDuration = epochEndTime - epochStartTime;
            if epochDuration <= 0
                addStatus(sprintf('    Event %d: Invalid duration, skipping', eventNumber));
                continue;
            end
            
            % Check if ANY reference channel has spikes in this event
            hasRefSpike = false;
            for r = 1:length(channelsToPlot)
                refChannel = channelsToPlot{r};
                refSpikes = spikeData.(refChannel).times;
                if any(refSpikes >= epochStartTime & refSpikes <= epochEndTime)
                    hasRefSpike = true;
                    break;  % Found at least one, that's enough
                end
            end
            
            if ~hasRefSpike
                addStatus(sprintf('    Event %d: No spike in any reference channel, skipping', eventNumber));
                continue;
            end
            
            % Create event subfolder
            eventSubfolderName = sprintf('Event_%d', eventNumber);
            eventSubfolderPath = fullfile(eventsOutputFolder, eventSubfolderName);
            if ~exist(eventSubfolderPath, 'dir')
                mkdir(eventSubfolderPath);
            end
            
            figuresFolder = fullfile(eventSubfolderPath, 'figures');
            if ~exist(figuresFolder, 'dir')
                mkdir(figuresFolder);
            end
            
            % Extract spike data for this epoch
            currentEpoch = struct('name', ['NetworkEvent_', num2str(eventNumber)], ...
                                  'start', epochStartTime, ...
                                  'end', epochEndTime);
            epochName = currentEpoch.name;
            epochSpikeData = struct();
            
            for c = 1:length(sortedChannels)
                channel = sortedChannels{c};
                if isfield(spikeData, channel)
                    spikeTimes = spikeData.(channel).times;
                    epochSpikes = spikeTimes(spikeTimes >= currentEpoch.start & spikeTimes <= currentEpoch.end);
                    epochSpikeData.(epochName).(channel).times = epochSpikes;
                    epochSpikeData.(epochName).(channel).count = length(epochSpikes);
                else
                    epochSpikeData.(epochName).(channel).times = [];
                    epochSpikeData.(epochName).(channel).count = 0;
                end
            end
            
            % Generate all figures for this event
            processEventData(eventNumber, currentEpoch, epochName, epochSpikeData, ...
                sortedChannels, channelYPos, columns, rows, LayerDic, ...
                samplingRate, refractoryTime, multiplier, meanFR_stored, stdFR, ...
                figuresFolder, eventOnsetTime);successCount = successCount + 1;
            addStatus(sprintf('    Event %d: SUCCESS', eventNumber));
            
        catch ME
            errorCount = errorCount + 1;
            addStatus(sprintf('    ERROR in Event %d: %s', eventIdx, ME.message));
            fprintf('Detailed error for Event %d:\n%s\n', eventIdx, getReport(ME));
        end
    end
    
    % Merge all event summaries
    addStatus('Merging event summaries...');
    mergeEventSummaries(eventsOutputFolder);
    
    addStatus(sprintf('Event analysis complete! Processed %d events', length(eventsToProcess)));
    addStatus(sprintf('Successful: %d | Errors: %d', successCount, errorCount));
    addStatus(sprintf('Results: %s', eventsOutputFolder));
end

    function analyzeStimulationResponse(~, ~)
    % STIMULATION RESPONSE ANALYSIS - PSTH and Event Triggering
    meaType = getappdata(fig, 'meaType');
    addStatus('========================================');
    addStatus('Starting Stimulation Response Analysis...');
    addStatus('========================================');
    
    % Check if we have stimulation data
    hasStim = getappdata(fig, 'hasStimulation');
    if isempty(hasStim) || ~hasStim
        addStatus('ERROR: No stimulation data found');
        addStatus('Please load an H5 file with EventStream data');
        return;
    end
    
    % Get required data
    stimTimes = getappdata(fig, 'stimulationTimes');
    stimElectrode = getappdata(fig, 'stimulationElectrode');
    spikeData = getappdata(fig, 'spikeData');
    eventOnsets = getappdata(fig, 'eventOnsets');
    eventOffsets = getappdata(fig, 'eventOffsets');
    outputFolder = getappdata(fig, 'outputFolder');
    samplingRate = getappdata(fig, 'samplingRate');
    LayerDic = getappdata(fig, 'LayerDic');
    totalDuration = getappdata(fig, 'totalDuration');
    [stimIntensities, protocolName] = getStimulationProtocol(length(stimTimes));
    addStatus(sprintf('Protocol: %s', protocolName))
    % Validate required data
    if isempty(spikeData)
        addStatus('ERROR: Please run spike detection first (Button 5)');
        return;
    end
    
    if isempty(stimTimes)
        addStatus('ERROR: No stimulation times found');
        return;
    end
    
    if isempty(outputFolder)
        addStatus('ERROR: Please select output folder first (Button 1)');
        return;
    end
    
    % Create output folder
    stimAnalysisFolder = fullfile(outputFolder, 'Stimulation_Analysis');
    if ~exist(stimAnalysisFolder, 'dir')
        mkdir(stimAnalysisFolder);
    end
    figuresFolder = fullfile(stimAnalysisFolder, 'figures');
    if ~exist(figuresFolder, 'dir')
        mkdir(figuresFolder);
    end
    
    addStatus(sprintf('Processing %d stimulation pulses...', length(stimTimes)));
    if ~isempty(stimElectrode)
        addStatus(sprintf('Stimulation electrode: %s', stimElectrode));
    end
    
    % Get sorted channels
    sortedChannels = sort(fieldnames(spikeData));
    
    % ============================================================
    % ANALYSIS 1: PERI-STIMULUS TIME HISTOGRAM (PSTH)
    % ============================================================
    addStatus('Computing Peri-Stimulus Time Histogram (PSTH)...');
    
    % PSTH parameters - get user input for artifact blanking
    prompt = {'Pre-stimulus window (ms):', ...
              'Post-stimulus window (ms):', ...
              'Bin size (ms):', ...
              'Artifact blanking (ms):'};
    dlgtitle = 'PSTH Parameters';
    dims = [1 45];
    definput = {'100', '300', '2', '3'};
    
    psthParams = inputdlg(prompt, dlgtitle, dims, definput);
    
    if isempty(psthParams)
        addStatus('Analysis cancelled by user');
        return;
    end
    
    preStimWindow = str2double(psthParams{1}) / 1000;   % Convert ms to s
    postStimWindow = str2double(psthParams{2}) / 1000;  % Convert ms to s
    binSize = str2double(psthParams{3}) / 1000;         % Convert ms to s
    artifactBlanking = str2double(psthParams{4}) / 1000; % Convert ms to s
    
    % Validate inputs
    if any(isnan([preStimWindow, postStimWindow, binSize, artifactBlanking]))
        addStatus('ERROR: Invalid parameter values');
        return;
    end
    
    addStatus(sprintf('  Pre-stim: %.0f ms, Post-stim: %.0f ms, Bin: %.1f ms, Artifact blanking: %.1f ms', ...
        preStimWindow*1000, postStimWindow*1000, binSize*1000, artifactBlanking*1000));
    
    [psthData, psthStats, responsiveChannels] = computePSTH(...
        spikeData, sortedChannels, stimTimes, ...
        preStimWindow, postStimWindow, binSize, samplingRate, artifactBlanking);
    
    addStatus(sprintf('  Found %d responsive channels (p < 0.05)', ...
        length(responsiveChannels)));
    
    % ============================================================
    % ANALYSIS 2: EVENT TRIGGERING ANALYSIS
    % ============================================================
    if ~isempty(eventOnsets)
        addStatus('Analyzing event triggering probability...');
        
        eventWindow = 0.500;  % Look within 500 ms after stim
        [triggerStats, evokedEventIndices] = analyzeEventTriggering(...
            stimTimes, eventOnsets, eventOffsets, eventWindow, totalDuration);
        
        addStatus(sprintf('  Evoked events: %d / %d stims (%.1f%%)', ...
            triggerStats.NumEvokedEvents, triggerStats.NumStims, ...
            triggerStats.TriggerProbability_Percent));
    else
        addStatus('Skipping event triggering (no events detected)');
        triggerStats = [];
        evokedEventIndices = [];
    end
    
    % ============================================================
    % GENERATE FIGURES
    % ============================================================
    addStatus('Generating figures...');
    
    % Figure 1: PSTH Overview (Population and per-channel)
    generatePSTHFigure(psthData, psthStats, responsiveChannels, ...
        preStimWindow, postStimWindow, binSize, figuresFolder);
    
    % Figure 2: Raster plot aligned to stimulation
    generateStimRasterFigure(spikeData, sortedChannels, stimTimes, ...
        preStimWindow, postStimWindow, figuresFolder);
    
    % Figure 3: Response latency distribution
    generateLatencyFigure(psthStats, responsiveChannels, figuresFolder);
    
    % Figure 4: Event triggering (if applicable)
    if ~isempty(triggerStats)
        generateTriggeringFigure(triggerStats, evokedEventIndices, ...
            stimTimes, eventOnsets, eventOffsets, figuresFolder);
    end

    % Figure 5: Spatial response map (AVERAGED across all stims)
    if ~isempty(LayerDic)
    generateSpatialResponseFigure(psthStats, responsiveChannels, ...
        stimElectrode, LayerDic, meaType, figuresFolder);
    end
    
    % Figure 5b: Per-intensity spatial maps (for I/O protocols)
    if ~isempty(LayerDic) && length(stimTimes) > 1
        addStatus('Generating per-intensity spatial maps...');
        generatePerIntensitySpatialMaps(psthData, spikeData, sortedChannels, ...
            stimIntensities, meaType, LayerDic, stimElectrode, figuresFolder);
    end
    
    % Figure 6: Sequential responses (for I/O analysis)
    generateSequentialResponseFigure(psthData, spikeData, sortedChannels, ...
    stimTimes, preStimWindow, postStimWindow, stimIntensities, protocolName, figuresFolder);
    % ============================================================
    % SAVE RESULTS TO EXCEL
    % ============================================================
    addStatus('Saving results to Excel...');
    
    excelFile = fullfile(stimAnalysisFolder, 'Stimulation_Response_Analysis.xlsx');
    
    % Sheet 1: PSTH Statistics Summary
    writetable(psthStats, excelFile, 'Sheet', 'PSTH_Statistics');
    
    % Sheet 2: Responsive Channels
    if ~isempty(responsiveChannels)
        respTable = psthStats(ismember(psthStats.Channel, responsiveChannels), :);
        writetable(respTable, excelFile, 'Sheet', 'Responsive_Channels');
    end
    
    % Sheet 3: Event Triggering
    if ~isempty(triggerStats)
        % Convert struct to table
        trigTable = struct2table(triggerStats);
        writetable(trigTable, excelFile, 'Sheet', 'Event_Triggering');
    end
    % Sheet 4: Stimulation Times
    stimTable = table();
    stimTable.Stim_Number = (1:length(stimTimes))';
    stimTable.Stim_Time_s = stimTimes(:);

    % Add inter-stimulus intervals
    ISIs = [NaN; diff(stimTimes(:))];
    stimTable.ISI_s = ISIs;

    % Add stimulation electrode info
    stimTable.Stim_Electrode = repmat({stimElectrode}, length(stimTimes), 1);

writetable(stimTable, excelFile, 'Sheet', 'Stimulation_Times');


% Export Detected Stim Events (same format as DetectedEvents.xlsx + intensity)
stimEventTable = table();
stimEventTable.Event_Number = (1:length(stimTimes))';
stimEventTable.Start_Time_s = stimTimes(:);
stimEventTable.End_Time_s = stimTimes(:) + 0.200;  % 200ms biphasic pulse
stimEventTable.Duration_s = ones(length(stimTimes), 1) * 0.200;
stimEventTable.Intensity_uA = stimIntensities(:);
stimEventTable.Protocol = repmat({protocolName}, length(stimTimes), 1);

stimEventFile = fullfile(stimAnalysisFolder, 'Detected_Stim_Events.xlsx');
writetable(stimEventTable, stimEventFile);
addStatus(sprintf('  Exported %d stim events to: Detected_Stim_Events.xlsx', length(stimTimes)));

setappdata(fig, 'stimIntensities', stimIntensities);
setappdata(fig, 'stimProtocolName', protocolName);
addStatus(sprintf('  Exported %d stimulation times to Excel', length(stimTimes)));
    addStatus('========================================');
    addStatus('✓ Stimulation Response Analysis Complete!');
    addStatus(sprintf('Results saved to: %s', stimAnalysisFolder));
    addStatus(sprintf('Responsive channels: %d / %d', ...
        length(responsiveChannels), length(sortedChannels)));
    addStatus('========================================');
end
function [stimIntensities, protocolName] = getStimulationProtocol(numStims)
    % GET STIMULATION PROTOCOL
    % Lets user select predefined protocol or enter custom intensities
    
    % Predefined protocols
    protocols = {
        'Julia I/O Curve (0-500 µA)', ...
        'Linear 10 µA steps', ...
        'Linear 50 µA steps', ...
        'Custom (enter manually)', ...
        'Unknown (use stim numbers)'
    };
    
    % Show selection dialog
    [selection, ok] = listdlg('PromptString', 'Select stimulation protocol:', ...
        'SelectionMode', 'single', ...
        'ListString', protocols, ...
        'ListSize', [250 150], ...
        'Name', 'Stimulation Protocol');
    
    if ~ok
        % Default to unknown if cancelled
        stimIntensities = 1:numStims;
        protocolName = 'Unknown';
        return;
    end
    
    switch selection
        case 1  % Julia I/O Curve
            stimIntensities = [0, 10, 20, 30, 40, 50, 75, 100, 125, 150, 200, 250, 300, 400, 500];
            protocolName = 'Julia I/O (µA)';
            
        case 2  % Linear 10 µA
            stimIntensities = (0:numStims-1) * 10;
            protocolName = 'Linear 10 µA steps';
            
        case 3  % Linear 50 µA
            stimIntensities = (0:numStims-1) * 50;
            protocolName = 'Linear 50 µA steps';
            
        case 4  % Custom
            % Multi-line input dialog
            prompt = {sprintf('Enter %d intensity values (comma or space separated):', numStims), ...
                      'Protocol name:'};
            dlgTitle = 'Custom Stimulation Protocol';
            dims = [2 60; 1 60];
            defaultVals = {num2str(0:10:(numStims-1)*10), 'Custom Protocol'};
            
            answer = inputdlg(prompt, dlgTitle, dims, defaultVals);
            
            if isempty(answer)
                stimIntensities = 1:numStims;
                protocolName = 'Unknown';
                return;
            end
            
            % Parse intensity values
            valStr = answer{1};
            valStr = strrep(valStr, ',', ' ');  % Replace commas with spaces
            stimIntensities = str2num(valStr);  %#ok<ST2NM>
            protocolName = answer{2};
            
        case 5  % Unknown
            stimIntensities = 1:numStims;
            protocolName = 'Unknown (stim #)';
    end
    
    % Validate length
    if length(stimIntensities) ~= numStims
        warning('Number of intensities (%d) does not match number of stims (%d). Adjusting...', ...
            length(stimIntensities), numStims);
        
        if length(stimIntensities) > numStims
            stimIntensities = stimIntensities(1:numStims);
        else
            % Pad with NaN or extrapolate
            lastVal = stimIntensities(end);
            stimIntensities = [stimIntensities, repmat(lastVal, 1, numStims - length(stimIntensities))];
        end
    end
    
    stimIntensities = stimIntensities(:)';  % Ensure row vector
end
function calculateIEI(~, ~)
    addStatus('Calculating Inter-Event Intervals...');
    
    eventOnsets = getappdata(fig, 'eventOnsets');
    outputFolder = getappdata(fig, 'outputFolder');
    
    if isempty(eventOnsets) || length(eventOnsets) < 2
        addStatus('ERROR: Need at least 2 events for IEI analysis');
        return;
    end
    
    % Calculate IEIs
    IEI = diff(eventOnsets);
    
    % Create comprehensive table
    IEI_Table = table();
    for i = 1:length(IEI)
        newRow = table(i, eventOnsets(i), eventOnsets(i+1), IEI(i), ...
            'VariableNames', {'Interval_Number', 'Event_Start_s', ...
            'Next_Event_Start_s', 'IEI_s'});
        IEI_Table = [IEI_Table; newRow];
    end
    
    % Add statistics
    IEI_Stats = table();
    IEI_Stats.Measure = {'Mean_IEI_s'; 'Median_IEI_s'; 'Std_IEI_s'; ...
        'Min_IEI_s'; 'Max_IEI_s'; 'CV'; 'Total_Events'};
    IEI_Stats.Value = [mean(IEI); median(IEI); std(IEI); ...
        min(IEI); max(IEI); std(IEI)/mean(IEI); length(eventOnsets)];
    
    % Save to Excel
    excelFile = fullfile(outputFolder, 'Inter_Event_Intervals.xlsx');
    writetable(IEI_Table, excelFile, 'Sheet', 'IEI_Data');
    writetable(IEI_Stats, excelFile, 'Sheet', 'IEI_Statistics');
    
    % Create histogram
    figuresFolder = getappdata(fig, 'figuresFolder');
    if ~isempty(figuresFolder)
        hFig = figure('Visible', 'off', 'Position', [100, 100, 800, 600]);
        
        subplot(2,1,1);
        histogram(IEI, 20, 'FaceColor', [0.3 0.6 0.9]);
        xlabel('Inter-Event Interval (s)');
        ylabel('Count');
        title(sprintf('IEI Distribution (Mean: %.2f ± %.2f s)', mean(IEI), std(IEI)));
        grid on;
        
        subplot(2,1,2);
        plot(1:length(IEI), IEI, 'o-', 'LineWidth', 1.5, 'MarkerSize', 6);
        xlabel('Interval Number');
        ylabel('IEI (s)');
        title('IEI Over Time');
        grid on;
        
        print(hFig, fullfile(figuresFolder, 'Inter_Event_Intervals'), '-dpng', '-r300');
        set(hFig, 'Visible', 'on');
        savefig(hFig, fullfile(figuresFolder, ['Inter_Event_Intervals' '.fig']));
        close(hFig);
    end
    
    addStatus(sprintf('IEI analysis complete: Mean = %.2f s, CV = %.2f', ...
        mean(IEI), std(IEI)/mean(IEI)));
    addStatus(sprintf('Saved to: %s', excelFile));
end

function analyzeParticipation(~, ~)
    addStatus('Analyzing electrode participation...');
    
    spikeData = getappdata(fig, 'spikeData');
    eventOnsets = getappdata(fig, 'eventOnsets');
    eventOffsets = getappdata(fig, 'eventOffsets');
    outputFolder = getappdata(fig, 'outputFolder');
    
    if isempty(spikeData) || isempty(eventOnsets)
        addStatus('ERROR: Need spike data and events');
        return;
    end
    
    sortedChannels = sort(fieldnames(spikeData));
    numEvents = length(eventOnsets);
    
    % Create participation matrix (channels × events)
    participationMatrix = false(length(sortedChannels), numEvents);
    
    for e = 1:numEvents
        for c = 1:length(sortedChannels)
            channel = sortedChannels{c};
            spikes = spikeData.(channel).times;
            
            % Check if channel has spikes during this event
            hasSpikes = any(spikes >= eventOnsets(e) & spikes <= eventOffsets(e));
            participationMatrix(c, e) = hasSpikes;
        end
    end
    
    % Calculate statistics
    participationRate = sum(participationMatrix, 2) / numEvents * 100; % Percent of events
    eventsPerChannel = sum(participationMatrix, 2);
    channelsPerEvent = sum(participationMatrix, 1)';
    
    % Create summary table
    participationTable = table(sortedChannels, eventsPerChannel, participationRate, ...
        'VariableNames', {'Channel', 'Num_Events_Participated', 'Participation_Rate_Percent'});
    
    % Event summary
    eventSummary = table((1:numEvents)', channelsPerEvent, ...
        'VariableNames', {'Event_Number', 'Num_Participating_Channels'});
    
    % Save to Excel
    excelFile = fullfile(outputFolder, 'Electrode_Participation.xlsx');
    writetable(participationTable, excelFile, 'Sheet', 'Channel_Participation');
    writetable(eventSummary, excelFile, 'Sheet', 'Event_Participation');
    
    % Save participation matrix
    participationMatrixTable = array2table(double(participationMatrix), ...
        'RowNames', sortedChannels, ...
        'VariableNames', arrayfun(@(x) sprintf('Event%d', x), 1:numEvents, 'UniformOutput', false));
    writetable(participationMatrixTable, excelFile, 'Sheet', 'Participation_Matrix', ...
        'WriteRowNames', true);
    
    % Create visualization
    figuresFolder = getappdata(fig, 'figuresFolder');
    if ~isempty(figuresFolder)
        hFig = figure('Visible', 'off', 'Position', [100, 100, 1200, 800]);
        
        subplot(2,2,1);
        imagesc(participationMatrix);
        colormap(gca, [1 1 1; 0 0 0.8]);
        xlabel('Event Number');
        ylabel('Channel');
        title('Electrode Participation Matrix');
        colorbar('Ticks', [0 1], 'TickLabels', {'No', 'Yes'});
        
        subplot(2,2,2);
        histogram(participationRate, 20, 'FaceColor', [0.3 0.6 0.9]);
        xlabel('Participation Rate (%)');
        ylabel('Number of Channels');
        title('Participation Rate Distribution');
        grid on;
        
        subplot(2,2,3);
        histogram(channelsPerEvent, 20, 'FaceColor', [0.9 0.4 0.3]);
        xlabel('Number of Participating Channels');
        ylabel('Number of Events');
        title('Channels per Event Distribution');
        grid on;
        
        subplot(2,2,4);
        plot(1:numEvents, channelsPerEvent, 'o-', 'LineWidth', 1.5);
        xlabel('Event Number');
        ylabel('Participating Channels');
        title('Event Size Over Time');
        grid on;
        
        print(hFig, fullfile(figuresFolder, 'Electrode_Participation'), '-dpng', '-r300');
        set(hFig, 'Visible', 'on');
        savefig(hFig, fullfile(figuresFolder, ['Electrode_Participation' '.fig']));
        close(hFig);
    end
    
    addStatus(sprintf('Participation analysis complete'));
    addStatus(sprintf('Mean participation rate: %.1f%%', mean(participationRate)));
    addStatus(sprintf('Mean channels per event: %.1f', mean(channelsPerEvent)));
    addStatus(sprintf('Saved to: %s', excelFile));

    % Retrieve appdata variables needed for workspace save
    spikeData     = getappdata(fig, 'spikeData');
    eventOnsets   = getappdata(fig, 'eventOnsets');
    eventOffsets  = getappdata(fig, 'eventOffsets');
    LayerDic      = getappdata(fig, 'LayerDic');
    Time          = getappdata(fig, 'Time');
    samplingRate  = getappdata(fig, 'samplingRate');
    save(fullfile(outputFolder, 'propagation_workspace.mat'), ...
    'spikeData','eventOnsets','eventOffsets','LayerDic','Time','samplingRate','outputFolder');
end

    function multiNetworkDetection(~, ~)
    addStatus('Starting Enhanced Multi-Network Detection...');
    
    % Check required data
    outputFolder = getappdata(fig, 'outputFolder');
    spikeData = getappdata(fig, 'spikeData');
    eventOnsets = getappdata(fig, 'eventOnsets');
    eventOffsets = getappdata(fig, 'eventOffsets');
    samplingRate = getappdata(fig, 'samplingRate');
    Time = getappdata(fig, 'Time');
    totalDuration = getappdata(fig, 'totalDuration');
    
    if isempty(spikeData) || isempty(eventOnsets)
        addStatus('ERROR: Please complete spike and event detection first');
        return;
    end
    
    sortedChannels = sort(fieldnames(spikeData));
    
    % Get time-related data
    timeCenters = getappdata(fig, 'timeCenters');
    populationFiringRate = getappdata(fig, 'populationFiringRate');
    activeChannelsOverTime = getappdata(fig, 'activeChannelsOverTime');
    thresholdFR = getappdata(fig, 'thresholdFR');
    minChannels = getappdata(fig, 'eventMinChannels');
    maxChannels = getappdata(fig, 'eventMaxChannels');
    
    %% === Step 1: Get Reference Channels ===
    prompt = {'Enter reference channels separated by commas (e.g., A2,B3,K13):'};
    dlgtitle = 'Multi-Network Setup';
    dims = [1 60];
    definput = {'A14,B14'};
    answer = inputdlg(prompt, dlgtitle, dims, definput);
    
    if isempty(answer)
        addStatus('Multi-network detection cancelled');
        return;
    end
    
    % Parse and validate channels
    refChannels = strsplit(answer{1}, ',');
    refChannels = strtrim(refChannels);
    
    validChannels = {};
    for i = 1:length(refChannels)
        if isfield(spikeData, refChannels{i})
            validChannels{end+1} = refChannels{i};
        else
            addStatus(sprintf('Warning: Channel %s not found, skipping', refChannels{i}));
        end
    end
    
    if isempty(validChannels)
        addStatus('ERROR: No valid reference channels found');
        return;
    end
    
    refChannels = validChannels;
    numRefChannels = length(refChannels);
    addStatus(sprintf('Using %d reference channels: %s', numRefChannels, strjoin(refChannels, ', ')));
    
    % Create output folders
    multiNetworkFolder = fullfile(outputFolder, 'MultiNetwork_Analysis');
    if ~exist(multiNetworkFolder, 'dir')
        mkdir(multiNetworkFolder);
    end
    
    figuresFolder = fullfile(multiNetworkFolder, 'figures');
    if ~exist(figuresFolder, 'dir')
        mkdir(figuresFolder);
    end
    
    % Save reference channels to file
    fileID = fopen(fullfile(multiNetworkFolder, 'Reference_channels.txt'), 'w');
    for i = 1:length(refChannels)
        fprintf(fileID, 'refChan%d = ''%s'';\n', i, refChannels{i});
    end
    fclose(fileID);
    
    %% === Step 2: Network-Specific Event Detection ===
    addStatus('Processing network-specific events...');
    
    networkResults = struct();
    allNetworkEvents = [];
    
    for netIdx = 1:numRefChannels
        currentRefChan = refChannels{netIdx};
        addStatus(sprintf('  Processing Network %d (Reference: %s)...', netIdx, currentRefChan));
        
        refSpikeTimes = spikeData.(currentRefChan).times;
        
        % Filter events that have spikes in this reference channel
        nEv = length(eventOnsets);
        keepMask = false(nEv, 1);
        
        for e = 1:nEv
            hasSpike = any(refSpikeTimes >= eventOnsets(e) & refSpikeTimes <= eventOffsets(e));
            keepMask(e) = hasSpike;
        end
        
        % Get network-specific events
        networkEventOnsets = eventOnsets(keepMask);
        networkEventOffsets = eventOffsets(keepMask);
        numNetworkEvents = length(networkEventOnsets);
        
        addStatus(sprintf('    Network %d: %d events detected', netIdx, numNetworkEvents));
        
        % Store results
        networkResults(netIdx).refChannel = currentRefChan;
        networkResults(netIdx).eventOnsets = networkEventOnsets;
        networkResults(netIdx).eventOffsets = networkEventOffsets;
        networkResults(netIdx).numEvents = numNetworkEvents;
        
        % Create event table
        if numNetworkEvents > 0
            eventNumbers = (1:numNetworkEvents)';
            startTimes = networkEventOnsets(:);
            endTimes = networkEventOffsets(:);
            durations = endTimes - startTimes;
            networkLabels = repmat(netIdx, numNetworkEvents, 1);
            refChannelLabels = repmat({currentRefChan}, numNetworkEvents, 1);
            
            networkEventTable = table(eventNumbers, startTimes, endTimes, durations, ...
                networkLabels, refChannelLabels, ...
                'VariableNames', {'Event_Number', 'Start_Time_s', 'End_Time_s', ...
                'Duration_s', 'Network_ID', 'Reference_Channel'});
            
            networkResults(netIdx).eventTable = networkEventTable;
            
            % Add to combined events
            if isempty(allNetworkEvents)
                allNetworkEvents = networkEventTable;
            else
                networkEventTable.Event_Number = networkEventTable.Event_Number + height(allNetworkEvents);
                allNetworkEvents = [allNetworkEvents; networkEventTable];
            end
        end
    end
    
    %% === Step 3: Merge Overlapping Events (NEW!) ===
    addStatus('Merging overlapping events...');
    
    % Sort by start time
    [~, sortIdx] = sort(allNetworkEvents.Start_Time_s);
    allNetworkEvents = allNetworkEvents(sortIdx, :);
    
    % Merge events with tolerance
    tol = 0.2; % 200 ms tolerance for simultaneous events
    
    used = false(height(allNetworkEvents), 1);
    mergedStart = [];
    mergedEnd = [];
    mergedCat = [];
    mergedNets = {};
    
    for ii = 1:height(allNetworkEvents)
        if used(ii), continue; end
        
        on = allNetworkEvents.Start_Time_s(ii);
        off = allNetworkEvents.End_Time_s(ii);
        
        % Find overlapping events within tolerance
        idx = find(~used & ...
            allNetworkEvents.Start_Time_s <= off + tol & ...
            allNetworkEvents.End_Time_s >= on - tol);
        
        used(idx) = true;
        
        mergedStart(end+1, 1) = min(allNetworkEvents.Start_Time_s(idx));
        mergedEnd(end+1, 1) = max(allNetworkEvents.End_Time_s(idx));
        
        nets = unique(allNetworkEvents.Network_ID(idx));
        
        % Category: 1 = only Net1, 2 = only Net2, 3 = both, etc.
        if numel(nets) == 1
            mergedCat(end+1, 1) = nets(1);
        else
            mergedCat(end+1, 1) = numRefChannels + 1; % Category for "multiple networks"
        end
        
        mergedNets{end+1, 1} = strjoin(string(nets), ',');
    end
    
    mergedDur = mergedEnd - mergedStart;
    
    % Create merged events table
    mergedEvents = table((1:numel(mergedStart))', mergedStart, mergedEnd, ...
        mergedDur, mergedCat, mergedNets, ...
        'VariableNames', {'Event_Number', 'Start_Time_s', 'End_Time_s', ...
        'Duration_s', 'Category', 'Networks_Involved'});
    
    % For compatibility, add Network_ID column
    mergedEvents.Network_ID = mergedCat;
    
    addStatus(sprintf('Merged into %d unique events', height(mergedEvents)));
    
    % Count events by category
    for netIdx = 1:numRefChannels
        numOnly = sum(mergedEvents.Category == netIdx);
        addStatus(sprintf('  %s only: %d events', refChannels{netIdx}, numOnly));
    end
    numBoth = sum(mergedEvents.Category == numRefChannels + 1);
    addStatus(sprintf('  Multiple networks: %d events', numBoth));
    
    %% === Step 4: Network-Specific Visualization ===
    addStatus('Creating visualization...');
    
    try
        hFig = figure('Visible', 'off', 'Position', [100, 100, 1400, 800]);
        
        networkColors = lines(numRefChannels);
        
        % Subplot 1: Population Firing Rate
        subplot(2, 1, 1);
        plot(timeCenters, populationFiringRate, 'k-', 'LineWidth', 1);
        hold on;
        yline(thresholdFR, 'r--', 'Threshold', 'LineWidth', 1);
        
        % Plot events for each network
        for netIdx = 1:numRefChannels
            if networkResults(netIdx).numEvents > 0
                networkOnsets = networkResults(netIdx).eventOnsets;
                networkOffsets = networkResults(netIdx).eventOffsets;
                
                for e = 1:length(networkOnsets)
                    xline(networkOnsets(e), '--', 'Color', networkColors(netIdx, :), ...
                        'LineWidth', 1.5, 'Alpha', 0.7);
                    xline(networkOffsets(e), ':', 'Color', networkColors(netIdx, :), ...
                        'LineWidth', 1.5, 'Alpha', 0.7);
                end
            end
        end
        
        xlabel('Time (s)');
        ylabel('Population Firing Rate (Hz)');
        title('Population Firing Rate with Multi-Network Events');
        
        legendEntries = {'Pop. Firing Rate', 'Threshold'};
        for netIdx = 1:numRefChannels
            legendEntries{end+1} = sprintf('Network %d (%s)', netIdx, refChannels{netIdx});
        end
        legend(legendEntries, 'Location', 'best');
        grid on;
        hold off;
        
        % Subplot 2: Active Channels
        subplot(2, 1, 2);
        plot(timeCenters, activeChannelsOverTime, 'k-', 'LineWidth', 1);
        hold on;
        if ~isempty(minChannels)
            yline(minChannels, 'r--', 'Min Threshold', 'LineWidth', 1);
        end
        if ~isempty(maxChannels)
            yline(maxChannels, 'r:', 'Max Threshold', 'LineWidth', 1);
        end
        
        % Plot events
        for netIdx = 1:numRefChannels
            if networkResults(netIdx).numEvents > 0
                networkOnsets = networkResults(netIdx).eventOnsets;
                networkOffsets = networkResults(netIdx).eventOffsets;
                
                for e = 1:length(networkOnsets)
                    xline(networkOnsets(e), '--', 'Color', networkColors(netIdx, :), ...
                        'LineWidth', 1.5, 'Alpha', 0.7);
                    xline(networkOffsets(e), ':', 'Color', networkColors(netIdx, :), ...
                        'LineWidth', 1.5, 'Alpha', 0.7);
                end
            end
        end
        
        xlabel('Time (s)');
        ylabel('Active Channels');
        title('Active Channels with Multi-Network Events');
        legend(legendEntries, 'Location', 'best');
        grid on;
        hold off;
        
        % Save figure
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        print(hFig, fullfile(figuresFolder, ['MultiNetwork_Detection_', timestamp]), '-dpng', '-r300');
        set(hFig, 'Visible', 'on');
        savefig(hFig, fullfile(figuresFolder, ['MultiNetwork_Detection_', timestamp, '.fig']));
        close(hFig);
        
    catch ME
        addStatus(sprintf('Warning: Could not create visualization: %s', ME.message));
    end
    
    %% === Step 5: Network-Specific Correlation Analysis (NEW!) ===
    addStatus('Computing network-specific correlations...');
    
    binSize = 0.025; % 25 ms bins
    
    for netIdx = 1:numRefChannels
        if networkResults(netIdx).numEvents < 2
            addStatus(sprintf('  Network %d: Skipping correlation (< 2 events)', netIdx));
            continue;
        end
        
        addStatus(sprintf('  Network %d: Computing correlations...', netIdx));
        
        netEventOnsets = networkResults(netIdx).eventOnsets;
        netEventOffsets = networkResults(netIdx).eventOffsets;
        numNetEvents = length(netEventOnsets);
        
        % Window parameters
        preEventTime = 1;
        postEventTime = 1;
        windowDuration = preEventTime + postEventTime;
        
        % Extract spike trains
        alignedSpikeTrains = cell(numNetEvents, 1);
        
        for eventIdx = 1:numNetEvents
            eventTime = netEventOnsets(eventIdx);
            windowStart = eventTime - preEventTime;
            windowEnd = eventTime + postEventTime;
            
            spikeTrains = zeros(length(sortedChannels), round(windowDuration * samplingRate));
            
            for channelIdx = 1:length(sortedChannels)
                channelName = sortedChannels{channelIdx};
                spikeTimes = spikeData.(channelName).times;
                
                spikesInWindow = spikeTimes(spikeTimes >= windowStart & spikeTimes <= windowEnd);
                spikeIndices = round((spikesInWindow - windowStart) * samplingRate) + 1;
                
                % Validate indices
                validIndices = spikeIndices(spikeIndices >= 1 & spikeIndices <= size(spikeTrains, 2));
                if ~isempty(validIndices)
                    spikeTrains(channelIdx, validIndices) = 1;
                end
            end
            
            alignedSpikeTrains{eventIdx} = spikeTrains;
        end
        
        % Bin spike data
        numBins = round(windowDuration / binSize);
        spikeCounts = zeros(numNetEvents, length(sortedChannels), numBins);
        
        for eventIdx = 1:numNetEvents
            spikeTrains = alignedSpikeTrains{eventIdx};
            
            for binIdx = 1:numBins
                binStart = round((binIdx - 1) * binSize * samplingRate) + 1;
                binEnd = min(round(binIdx * binSize * samplingRate), size(spikeTrains, 2));
                
                if binStart <= binEnd && binEnd <= size(spikeTrains, 2)
                    spikeCounts(eventIdx, :, binIdx) = sum(spikeTrains(:, binStart:binEnd), 2);
                end
            end
        end
        
        % Compute correlation matrix
        correlationMatrix = zeros(numNetEvents);
        
        for i = 1:numNetEvents
            for j = 1:numNetEvents
                spikeCounts_i = squeeze(spikeCounts(i, :, :));
                spikeCounts_j = squeeze(spikeCounts(j, :, :));
                correlationMatrix(i, j) = corr(spikeCounts_i(:), spikeCounts_j(:));
            end
        end
        
        % Store results
        networkResults(netIdx).correlationMatrix = correlationMatrix;
        networkResults(netIdx).alignedSpikeTrains = alignedSpikeTrains;
        
        % Compute average correlation
        corrVals = correlationMatrix(~eye(size(correlationMatrix)));
        avgCorr = mean(corrVals, 'omitnan');
        networkResults(netIdx).avgCorrelation = avgCorr;
        
        addStatus(sprintf('    Network %d: Average correlation = %.3f', netIdx, avgCorr));
        
        % Plot correlation matrix
        try
            hFig2 = figure('Visible', 'off');
            imagesc(correlationMatrix);
            colormap(jet);
            colorbar;
            caxis([-1 1]);
            title(sprintf('Network %d (%s): Event Correlations (Avg: %.3f)', ...
                netIdx, refChannels{netIdx}, avgCorr));
            xlabel('Event Index');
            ylabel('Event Index');
            
            print(hFig2, fullfile(figuresFolder, ...
                sprintf('Network%d_Correlation_Matrix_%s', netIdx, timestamp)), '-dpng', '-r300');
            savefig(hFig2, fullfile(figuresFolder, sprintf('Network%d_Correlation_Matrix_%s.fig', netIdx, timestamp)));
            close(hFig2);
        catch ME
            addStatus(sprintf('    Warning: Could not create correlation plot: %s', ME.message));
        end
    end
    
    %% === Step 6: Lead/Lag Analysis (NEW!) ===
    if numRefChannels >= 2
        addStatus('Computing lead/lag analysis...');
        
        searchWindow = 2; % seconds
        leadLagMat = NaN(numRefChannels);
        pctLeadMat = NaN(numRefChannels);
        
        for i = 1:numRefChannels
            A = networkResults(i).eventOnsets;
            
            for j = 1:numRefChannels
                if i == j, continue; end
                B = networkResults(j).eventOnsets;
                
                lags = [];
                for k = 1:numel(A)
                    dt = B - A(k);
                    idx = find(abs(dt) <= searchWindow, 1, 'first');
                    if ~isempty(idx)
                        lags(end+1) = dt(idx);
                    end
                end
                
                if ~isempty(lags)
                    leadLagMat(i, j) = mean(lags);
                    pctLeadMat(i, j) = mean(lags < 0) * 100;
                end
            end
        end
        
        % Store results
        setappdata(fig, 'leadLagMat', leadLagMat);
        setappdata(fig, 'pctLeadMat', pctLeadMat);
        
        % Display results
        addStatus('Lead/Lag Matrix (seconds):');
        for i = 1:numRefChannels
            for j = 1:numRefChannels
                if i ~= j && ~isnan(leadLagMat(i, j))
                    addStatus(sprintf('  %s -> %s: %.3f s (%.1f%% lead)', ...
                        refChannels{i}, refChannels{j}, leadLagMat(i, j), pctLeadMat(i, j)));
                end
            end
        end
        
        %% === Step 7: Permutation Test for Statistical Significance (NEW!) ===
        addStatus('Running permutation tests (this may take a moment)...');
        
        nPerm = 1000;
        dur = totalDuration;
        
        pLagMat = nan(numRefChannels);
        pLeadMat = nan(numRefChannels);
        
        for i = 1:numRefChannels
            A = networkResults(i).eventOnsets;
            
            for j = 1:numRefChannels
                if i == j, continue; end
                B_orig = networkResults(j).eventOnsets;
                
                obsLag = leadLagMat(i, j);
                obsLead = pctLeadMat(i, j);
                
                if isnan(obsLag), continue; end
                
                permLag = nan(nPerm, 1);
                permLead = nan(nPerm, 1);
                
                for p = 1:nPerm
                    % Random circular shift
                    rndShift = rand * dur;
                    B = B_orig + rndShift;
                    B = mod(B - Time(1), dur) + Time(1);
                    B = sort(B);
                    
                    % Compute lag and lead
                    lags = [];
                    for k = 1:numel(A)
                        dt = B - A(k);
                        idx = find(abs(dt) <= searchWindow, 1, 'first');
                        if ~isempty(idx)
                            lags(end+1) = dt(idx);
                        end
                    end
                    
                    if ~isempty(lags)
                        permLag(p) = mean(lags);
                        permLead(p) = mean(lags < 0) * 100;
                    end
                end
                
                % Remove NaNs
                permLag = permLag(~isnan(permLag));
                permLead = permLead(~isnan(permLead));
                
                % Compute p-values
                if obsLag < 0
                    pLag = mean(permLag <= obsLag);
                else
                    pLag = mean(permLag >= obsLag);
                end
                pLagMat(i, j) = pLag;
                
                pLeadMat(i, j) = mean(permLead >= obsLead);
                
                addStatus(sprintf('  %s -> %s: p(Lag)=%.4f, p(Lead)=%.4f', ...
                    refChannels{i}, refChannels{j}, pLag, pLeadMat(i, j)));
            end
        end
        
        setappdata(fig, 'pLagMat', pLagMat);
        setappdata(fig, 'pLeadMat', pLeadMat);
    end
    
    %% === Step 8: Save Comprehensive Excel File (NEW!) ===
    addStatus('Creating comprehensive Excel file...');
    
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    excelFile = fullfile(multiNetworkFolder, ['MultiNetwork_Analysis_', timestamp, '.xlsx']);
    
    try
        % Sheet 1: Merged events
        writetable(mergedEvents, excelFile, 'Sheet', 'Merged_Events');
        
        % Sheet 2-N: Individual network events
        for netIdx = 1:numRefChannels
            if networkResults(netIdx).numEvents > 0
                writetable(networkResults(netIdx).eventTable, excelFile, ...
                    'Sheet', sprintf('Network%d_%s', netIdx, refChannels{netIdx}));
            end
        end
        
        % Sheet: Network summary
        if numRefChannels > 0
            summaryTable = table();
            for netIdx = 1:numRefChannels
                newRow = table(netIdx, {refChannels{netIdx}}, ...
                    networkResults(netIdx).numEvents, ...
                    'VariableNames', {'Network_ID', 'Reference_Channel', 'Num_Events'});
                
                if isfield(networkResults(netIdx), 'avgCorrelation')
                    newRow.Avg_Correlation = networkResults(netIdx).avgCorrelation;
                end
                
                summaryTable = [summaryTable; newRow];
            end
            writetable(summaryTable, excelFile, 'Sheet', 'Network_Summary');
        end
        
        % Sheet: Lead/Lag matrices
        if numRefChannels >= 2
            leadLagTable = array2table(leadLagMat, 'RowNames', refChannels, ...
                'VariableNames', refChannels);
            writetable(leadLagTable, excelFile, 'Sheet', 'LeadLag_Matrix', ...
                'WriteRowNames', true);
            
            pctLeadTable = array2table(pctLeadMat, 'RowNames', refChannels, ...
                'VariableNames', refChannels);
            writetable(pctLeadTable, excelFile, 'Sheet', 'LeadLag_Percent', ...
                'WriteRowNames', true);
            
            % P-values
            if exist('pLagMat', 'var')
                pLagTable = array2table(pLagMat, 'RowNames', refChannels, ...
                    'VariableNames', refChannels);
                writetable(pLagTable, excelFile, 'Sheet', 'P_Values_Lag', ...
                    'WriteRowNames', true);
                
                pLeadTable = array2table(pLeadMat, 'RowNames', refChannels, ...
                    'VariableNames', refChannels);
                writetable(pLeadTable, excelFile, 'Sheet', 'P_Values_Lead', ...
                    'WriteRowNames', true);
            end
        end
        
        % Sheet: Correlation matrices for each network
        for netIdx = 1:numRefChannels
            if isfield(networkResults(netIdx), 'correlationMatrix')
                corrMatrix = networkResults(netIdx).correlationMatrix;
                corrTable = array2table(corrMatrix);
                writetable(corrTable, excelFile, ...
                    'Sheet', sprintf('Network%d_Correlation', netIdx));
            end
        end
        
        addStatus(sprintf('Excel file saved: %s', excelFile));
        
    catch ME
        addStatus(sprintf('Warning: Could not create Excel file: %s', ME.message));
    end
    
    %% === Final Summary ===
    addStatus('-----------------------------------');
    addStatus('Multi-Network Analysis Complete!');
    addStatus(sprintf('Total events analyzed: %d', height(mergedEvents)));
    addStatus(sprintf('Networks: %d (%s)', numRefChannels, strjoin(refChannels, ', ')));
    addStatus(sprintf('Results saved to: %s', multiNetworkFolder));
    addStatus('-----------------------------------');
    
    % Store results in appdata
    setappdata(fig, 'networkResults', networkResults);
    setappdata(fig, 'mergedNetworkEvents', mergedEvents);
end
    
    % Berechne tatsächliche Distanzen zwischen Elektroden
    function propagationAnalysis(~, ~)
    addStatus('Starting Propagation Analysis...');
    
    % Check required data
    outputFolder = getappdata(fig, 'outputFolder');
    spikeData = getappdata(fig, 'spikeData');
    eventOnsets = getappdata(fig, 'eventOnsets');
    eventOffsets = getappdata(fig, 'eventOffsets');
    LayerDic = getappdata(fig, 'LayerDic');
    Time = getappdata(fig, 'Time');
    samplingRate = getappdata(fig, 'samplingRate');
    
    if isempty(spikeData) || isempty(eventOnsets)
        addStatus('ERROR: Please complete spike and event detection first');
        return;
    end
    
    sortedChannels = sort(fieldnames(spikeData));
    
    % Configuration
    electrodeSpacing = 0.2; % mm between electrodes
    preBuffer = 0.50;
    postBuffer = 0.50;
    binSize = 0.001;        % 1 ms bins for high-resolution
    
    % MEA configuration
    columns = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', ...
               'J', 'K', 'L', 'M', 'N', 'O', 'P', 'R'};
    rows = 1:16;
    
    % Create output folder
    propagationFolder = fullfile(outputFolder, 'Propagation_Analysis');
    if ~exist(propagationFolder, 'dir')
        mkdir(propagationFolder);
    end
    
    figuresFolder = fullfile(propagationFolder, 'figures');
    if ~exist(figuresFolder, 'dir')
        mkdir(figuresFolder);
    end
    
    % Get data bounds
    dataStartTime = min(Time);
    dataEndTime = max(Time);
    
    % EVENT SELECTION DIALOG
    numEvents = length(eventOnsets);
    
    % Create dialog for event selection
    prompt = {sprintf('Total events detected: %d\n\nEnter event selection:\n- Type "all" for all events\n- Type range as "1-10" or "5-20"\n- Type specific events as "1,5,10,15"', numEvents)};
    dlgtitle = 'Select Events to Analyze';
    dims = [1 60];
    definput = {'1-10'};  % Default to first 10 events
    
    answer = inputdlg(prompt, dlgtitle, dims, definput);
    
    % Handle cancel
    if isempty(answer)
        addStatus('Propagation analysis cancelled by user');
        return;
    end
    
    % Parse user input
    userInput = strtrim(answer{1});
    
    try
        if strcmpi(userInput, 'all')
            % Analyze all events
            eventsToAnalyze = 1:numEvents;
            addStatus(sprintf('Analyzing all %d events...', numEvents));
            
        elseif contains(userInput, '-')
            % Range format (e.g., "1-10")
            rangeParts = split(userInput, '-');
            startEvent = str2double(rangeParts{1});
            endEvent = str2double(rangeParts{2});
            
            if isnan(startEvent) || isnan(endEvent)
                error('Invalid range format');
            end
            
            startEvent = max(1, min(startEvent, numEvents));
            endEvent = max(1, min(endEvent, numEvents));
            
            if startEvent > endEvent
                error('Start event must be <= end event');
            end
            
            eventsToAnalyze = startEvent:endEvent;
            addStatus(sprintf('Analyzing events %d to %d (%d events)...', startEvent, endEvent, length(eventsToAnalyze)));
            
        elseif contains(userInput, ',')
            % Specific events format (e.g., "1,5,10,15")
            eventList = split(userInput, ',');
            eventsToAnalyze = [];
            
            for i = 1:length(eventList)
                eventNum = str2double(strtrim(eventList{i}));
                if ~isnan(eventNum) && eventNum >= 1 && eventNum <= numEvents
                    eventsToAnalyze = [eventsToAnalyze, eventNum];
                end
            end
            
            eventsToAnalyze = unique(eventsToAnalyze);  % Remove duplicates and sort
            
            if isempty(eventsToAnalyze)
                error('No valid events specified');
            end
            
            addStatus(sprintf('Analyzing %d specific events: %s', length(eventsToAnalyze), mat2str(eventsToAnalyze)));
            
        else
            % Try to parse as single number
            singleEvent = str2double(userInput);
            if ~isnan(singleEvent) && singleEvent >= 1 && singleEvent <= numEvents
                eventsToAnalyze = singleEvent;
                addStatus(sprintf('Analyzing event %d...', singleEvent));
            else
                error('Invalid input format');
            end
        end
        
    catch ME
        addStatus(sprintf('ERROR: Invalid event selection - %s', ME.message));
        addStatus('Please use format: "all", "1-10", or "1,5,10,15"');
        return;
    end
    
    addStatus(sprintf('Analyzing propagation for %d events...', length(eventsToAnalyze)));
    
    % Initialize results storage
    propagationResults = struct();
    eventSummaryTable = table();
    
    % Process each event
    for i = 1:length(eventsToAnalyze)
        eventIdx = eventsToAnalyze(i);
        
        try
            eventNumber = eventIdx;
            eventStartTime = eventOnsets(eventIdx);
            eventEndTime = eventOffsets(eventIdx);
            
            addStatus(sprintf('  Processing Event %d...', eventNumber));
            
            % Define epoch
            epochStartTime = max(eventStartTime - preBuffer, dataStartTime);
            epochEndTime = min(eventEndTime + postBuffer, dataEndTime);
            
            if epochEndTime <= epochStartTime
                addStatus(sprintf('    Event %d: Invalid time range, skipping', eventNumber));
                continue;
            end
            
            % Extract spike data
            epochSpikeData = struct();
            for c = 1:length(sortedChannels)
                channel = sortedChannels{c};
                if isfield(spikeData, channel)
                    spikeTimes = spikeData.(channel).times;
                    epochSpikes = spikeTimes(spikeTimes >= epochStartTime & spikeTimes <= epochEndTime);
                    epochSpikeData.(channel).times = epochSpikes;
                end
            end
            
            %% Build High-Resolution Activity Matrix
            timeEdges = epochStartTime:binSize:epochEndTime;
            timeCenters = timeEdges(1:end-1) + binSize/2;
            activityMatrix = zeros(length(sortedChannels), length(timeCenters));
            
            for idx = 1:length(sortedChannels)
                channel = sortedChannels{idx};
                if isfield(epochSpikeData, channel) && ~isempty(epochSpikeData.(channel).times)
                    spikeTimes = epochSpikeData.(channel).times;
                    counts = histcounts(spikeTimes, timeEdges);
                    activityMatrix(idx, :) = counts;
                end
            end
            

%% ================================================================

%% Wavefront Analysis - CORRECTED TO MATCH LATENCY MATRIX
centerOfMass = zeros(length(timeCenters), 2);
totalActivity = zeros(length(timeCenters), 1);

for t = 1:length(timeCenters)
    activeElectrodes = find(activityMatrix(:, t) > 0);
    if ~isempty(activeElectrodes)
        coords = [];
        weights = [];
        
        for idx = activeElectrodes'
            channel = sortedChannels{idx};
            
            % PARSE DIRECTLY - Same method as latency calculation
            tokens = regexp(channel, '^([A-Z]+)(\d+)$', 'tokens');
            if isempty(tokens), continue; end
            
            colLetter = tokens{1}{1};              % e.g., 'H'
            rowNumber = str2double(tokens{1}{2});  % e.g., 12
            
            % Find column index
            colIdx = find(strcmp(columns, colLetter));
            
            if isempty(colIdx) || isnan(rowNumber), continue; end
            
            % Coordinates: [x, y] = [column, row]
            % This EXACTLY matches how latency matrix is indexed!
            x_display = colIdx;
            y_display = rowNumber;
            
            coords = [coords; x_display, y_display];
            weights = [weights; activityMatrix(idx, t)];
        end
        
        if ~isempty(coords)
            centerOfMass(t, :) = sum(coords .* weights, 1) / sum(weights);
            totalActivity(t) = sum(weights);
        end
    end
end

%% Calculate Propagation Velocity (COM Method)
validCOM = find(totalActivity > 0);
meanVelocity_COM = NaN;
velocities_COM = [];

if length(validCOM) > 1
    comTimes = timeCenters(validCOM);
    comCoords = centerOfMass(validCOM, :);
    
    % Calculate distances between consecutive COM positions
    distances = sqrt(sum(diff(comCoords).^2, 2)) * electrodeSpacing;
    timeDeltas = diff(comTimes);
    
    % Calculate velocities
    velocities_COM = distances ./ timeDeltas;
    
    % Filter out infinities and unrealistic values
    validVelocities = velocities_COM(~isinf(velocities_COM) & ...
        velocities_COM < 1000 & velocities_COM > 0);
    
    if ~isempty(validVelocities)
        meanVelocity_COM = mean(validVelocities);
    end
end

%% Calculate First Spike Latency Matrix - CORRECTED
onsetTime = eventStartTime;
firstSpikeLatencyMatrix = NaN(length(rows), length(columns));

% Also store channel info for each spike
spikeInfo = struct('channel', {}, 'row', {}, 'col', {}, 'latency', {});
spikeCount = 0;

for idx = 1:length(sortedChannels)
    channel = sortedChannels{idx};
    
    % PARSE DIRECTLY - Same as analyzeEvents
    tokens = regexp(channel, '^([A-Z]+)(\d+)$', 'tokens');
    if isempty(tokens), continue; end
    
    colLetter = tokens{1}{1};
    rowNumber = str2double(tokens{1}{2});
    colIdx = find(strcmp(columns, colLetter));
    
    if isempty(colIdx) || isnan(rowNumber), continue; end
    
    if isfield(epochSpikeData, channel) && ~isempty(epochSpikeData.(channel).times)
        spikeTimes = epochSpikeData.(channel).times;
        spikeAfterOnset = spikeTimes(spikeTimes >= onsetTime);
        
        if ~isempty(spikeAfterOnset)
            firstSpikeTime = spikeAfterOnset(1);
            latency = firstSpikeTime - onsetTime;
            
            % Use correct indices: (row, col)
            firstSpikeLatencyMatrix(rowNumber, colIdx) = latency;
            
            % Store spike info with CORRECTED coordinates
            spikeCount = spikeCount + 1;
            spikeInfo(spikeCount).channel = channel;
            spikeInfo(spikeCount).row = rowNumber;
            spikeInfo(spikeCount).col = colIdx;
            spikeInfo(spikeCount).latency = latency;
        end
    end
end

%% Alternative Method: Gradient-based - CORRECTED
meanVelocity_gradient = NaN;

if length(spikeInfo) >= 3
    positions = zeros(length(spikeInfo), 2);
    latencies = zeros(length(spikeInfo), 1);
    
    for ii = 1:length(spikeInfo)
        % Positions: [col, row] to match COM coordinate system
        positions(ii, :) = [spikeInfo(ii).col, spikeInfo(ii).row];
        latencies(ii) = spikeInfo(ii).latency;
    end
    
    % Fit plane: latency = a*col + b*row + c
    X = [positions, ones(length(spikeInfo), 1)];
    coeffs = X \ latencies;
    
    % Calculate gradient magnitude (s/electrode)
    gradient_magnitude = sqrt(coeffs(1)^2 + coeffs(2)^2);
    
    % Convert to velocity (mm/s)
    if gradient_magnitude > 0
        meanVelocity_gradient = electrodeSpacing / gradient_magnitude;
    end
end
%%


%% Calculate Wave Direction and Coherence
[waveDirection, waveCoherence] = calculateWaveDirection(firstSpikeLatencyMatrix);

%% Store results
propagationResults(eventIdx).eventNumber = eventNumber;
propagationResults(eventIdx).firstSpikeLatencyMatrix = firstSpikeLatencyMatrix;
propagationResults(eventIdx).centerOfMass = centerOfMass;
propagationResults(eventIdx).totalActivity = totalActivity;
propagationResults(eventIdx).timeCenters = timeCenters;
propagationResults(eventIdx).meanVelocity_COM = meanVelocity_COM;
propagationResults(eventIdx).meanVelocity_gradient = meanVelocity_gradient;
propagationResults(eventIdx).velocities_COM = velocities_COM;
propagationResults(eventIdx).waveDirection = waveDirection;
propagationResults(eventIdx).waveCoherence = waveCoherence;
propagationResults(eventIdx).numActiveElectrodes = length(spikeInfo);
propagationResults(eventIdx).validCOM = validCOM;

% Add to summary table
newRow = table(eventNumber, ...
    meanVelocity_COM, meanVelocity_gradient, ...
    waveDirection, waveCoherence, length(spikeInfo), ...
    'VariableNames', {'EventNumber', ...
    'Velocity_COM_mm_s', 'Velocity_Gradient_mm_s', ...
    'WaveDirection_deg', 'WaveCoherence', 'NumActiveElectrodes'});
eventSummaryTable = [eventSummaryTable; newRow];

%% Save individual event figure - ENHANCED VERSION WITH IMPROVED LAYOUT
hFig = figure('Visible', 'off', 'Position', [100, 100, 1800, 600], 'Color', 'white');

% Use tiled layout for better control
t = tiledlayout(1, 4, 'TileSpacing', 'compact', 'Padding', 'compact');

%% ===== TILE 1: First Spike Latency Map (IMPROVED V42) =====
% Percentile-normalized colormap: 5th-95th percentile range for better contrast
ax1 = nexttile;

% Create display matrix with NaN handling
latencyDisplay = firstSpikeLatencyMatrix;
nanMask = isnan(latencyDisplay) | isinf(latencyDisplay) | latencyDisplay == 0;

% Find valid latencies and calculate percentiles
validLatencies = latencyDisplay(~nanMask);
if ~isempty(validLatencies) && length(validLatencies) > 5
    p5 = prctile(validLatencies, 5);
    p95 = prctile(validLatencies, 95);
    medianLat = median(validLatencies);
    
    % Ensure minimum range
    if p95 - p5 < 0.001
        p5 = min(validLatencies);
        p95 = max(validLatencies);
    end
else
    p5 = 0;
    p95 = 1;
    medianLat = 0.5;
end

% Plot with NaN as dark gray background
h = imagesc(latencyDisplay);
set(h, 'AlphaData', ~nanMask);  % Transparent where NaN/inactive
set(gca, 'Color', [0.45 0.45 0.45]);  % Dark gray background for inactive electrodes
set(gca, 'YDir', 'reverse');

% Warm-to-cool colormap: Red -> Orange -> Yellow -> Cyan -> Blue
% Early = warm (red/orange), Late = cool (cyan/blue)
nColors = 256;
warmToCool = zeros(nColors, 3);
for i = 1:nColors
    t = (i - 1) / (nColors - 1);  % 0 to 1
    if t < 0.25
        % Dark red to red
        warmToCool(i, :) = [0.6 + 0.4*(t/0.25), 0, 0];
    elseif t < 0.5
        % Red to yellow
        tt = (t - 0.25) / 0.25;
        warmToCool(i, :) = [1, tt, 0];
    elseif t < 0.75
        % Yellow to cyan
        tt = (t - 0.5) / 0.25;
        warmToCool(i, :) = [1 - tt, 1, tt];
    else
        % Cyan to blue
        tt = (t - 0.75) / 0.25;
        warmToCool(i, :) = [0, 1 - tt, 1];
    end
end
colormap(ax1, warmToCool);

% Set color axis to percentile range (clips extremes)
caxis([p5 p95]);

% Colorbar
cb1 = colorbar('eastoutside');
ylabel(cb1, 'Latency (s)', 'FontSize', 9);
cb1.FontSize = 8;

% Get MEA column labels
meaType = getappdata(fig, 'meaType');
if contains(meaType, 'J-naming')
    columns = {'A','B','C','D','E','F','G','H','J','K','L','M','N','O','P','R'};
else
    columns = {'A','B','C','D','E','F','G','H','I','K','L','M','N','O','P','R'};
end
rows = 1:16;

% Axis labels
xticks(1:16);
xticklabels(columns);
xtickangle(0);
set(gca, 'FontSize', 8);
xlabel('Column', 'FontSize', 10, 'FontWeight', 'bold');

yticks(1:16);
yticklabels(rows);
ylabel('Row', 'FontSize', 10, 'FontWeight', 'bold');

title(sprintf('Event %d: First Spike Latency', eventNumber), ...
    'FontSize', 12, 'FontWeight', 'bold');

%% ===== TILE 2: Latency-on-Layers (Clean - no contour lines) =====
ax2 = nexttile;

% Soft tissue-like layer colormap - no hard outlines
cmap_layers = [
    0.78 0.78 0.78;   % 0 = gray (outside)
    0.60 0.60 0.60;   % 1 = L1 medium gray
    0.88 0.65 0.65;   % 2 = L2/3 muted rose
    0.65 0.82 0.65;   % 3 = L4 muted green
    0.62 0.72 0.90;   % 4 = L5/6 muted blue
    0.88 0.88 0.65];  % 5 = WM muted yellow

imagesc(LayerDic, [0 5]);
colormap(ax2, cmap_layers);
set(gca, 'YDir', 'reverse');
hold on;

% --- Build warm-to-cool colormap for latency dots ---
nColors = 256;
warmToCool = zeros(nColors, 3);
for ci = 1:nColors
    tc = (ci - 1) / (nColors - 1);
    if tc < 0.25
        warmToCool(ci,:) = [0.6 + 0.4*(tc/0.25), 0, 0];
    elseif tc < 0.5
        tt = (tc-0.25)/0.25;
        warmToCool(ci,:) = [1, tt, 0];
    elseif tc < 0.75
        tt = (tc-0.5)/0.25;
        warmToCool(ci,:) = [1-tt, 1, tt];
    else
        tt = (tc-0.75)/0.25;
        warmToCool(ci,:) = [0, 1-tt, 1];
    end
end

% --- Gather valid latency data per electrode ---
dotCols     = [];
dotRows     = [];
dotLatencies = [];

for idx = 1:length(sortedChannels)
    channel = sortedChannels{idx};
    tokens = regexp(channel, '^([A-Z]+)(\d+)$', 'tokens');
    if isempty(tokens), continue; end
    colLetter = tokens{1}{1};
    rowNumber = str2double(tokens{1}{2});
    colIdx    = find(strcmp(columns, colLetter));
    if isempty(colIdx) || isnan(rowNumber), continue; end

    lat = firstSpikeLatencyMatrix(rowNumber, colIdx);
    if ~isnan(lat) && ~isinf(lat) && lat > 0
        dotCols(end+1)      = colIdx;
        dotRows(end+1)      = rowNumber;
        dotLatencies(end+1) = lat;
    end
end

% --- Draw latency-colored electrode dots ---
if ~isempty(dotLatencies)
    p5_dot  = prctile(dotLatencies, 5);
    p95_dot = prctile(dotLatencies, 95);
    if p95_dot - p5_dot < 0.001
        p5_dot  = min(dotLatencies);
        p95_dot = max(dotLatencies);
    end

    for di = 1:length(dotLatencies)
        normLat  = (dotLatencies(di) - p5_dot) / (p95_dot - p5_dot);
        normLat  = max(0, min(1, normLat));
        colorIdx = max(1, round(normLat * (nColors-1)) + 1);
        dotColor = warmToCool(colorIdx, :);

        % White halo for separation from background
        scatter(dotCols(di), dotRows(di), 100, 'w', 'filled', ...
            'MarkerEdgeColor', 'none');
        % Colored dot
        scatter(dotCols(di), dotRows(di), 65, dotColor, 'filled', ...
            'MarkerEdgeColor', [0.2 0.2 0.2], 'LineWidth', 0.5);
    end
end

% --- Initiator marker ---
latencyTemp = firstSpikeLatencyMatrix;
latencyTemp(isnan(latencyTemp) | isinf(latencyTemp) | latencyTemp == 0) = Inf;
[minLatency, minIdx] = min(latencyTemp(:));
if ~isinf(minLatency)
    [initRow, initCol] = ind2sub(size(latencyTemp), minIdx);

    % Gold star on top
    plot(initCol, initRow, 'p', 'MarkerSize', 26, ...
        'MarkerFaceColor', [1 0.85 0], ...
        'MarkerEdgeColor', [0.4 0.25 0], 'LineWidth', 2);

    % Layer identity label
    initLayerVal = LayerDic(initRow, initCol);
    layerNameMap = {'L1','L2/3','L4','L5/6','WM'};
    if initLayerVal >= 1 && initLayerVal <= 5
        initLayerName = layerNameMap{initLayerVal};
    else
        initLayerName = '?';
    end
    text(initCol + 0.8, initRow, sprintf('Initiator\n(%s)', initLayerName), ...
        'FontSize', 8, 'FontWeight', 'bold', ...
        'Color', [0.25 0.12 0], ...
        'BackgroundColor', [1 1 1 0.80], 'Margin', 1.5);
end

% --- Layer labels (left edge) ---
layerLabels = {'L1', 'L2/3', 'L4', 'L5/6', 'WM'};
layerValues = [1, 2, 3, 4, 5];
labelColors = {[0.2 0.2 0.2],[0.45 0.08 0.08],[0.08 0.38 0.08],[0.08 0.08 0.45],[0.38 0.32 0.08]};

for layerIdx = 1:length(layerValues)
    [layerRows_l, ~] = find(LayerDic == layerValues(layerIdx));
    if ~isempty(layerRows_l)
        text(0.4, mean(layerRows_l), layerLabels{layerIdx}, ...
            'Color', labelColors{layerIdx}, 'FontWeight', 'bold', ...
            'FontSize', 9, 'HorizontalAlignment', 'center', ...
            'BackgroundColor', [1 1 1 0.80], 'Margin', 1);
    end
end

% --- Separate colorbar axes for latency scale ---
% (avoids overwriting the layer colormap on ax2)
cb_pos = ax2.Position;
ax2_cb = axes('Position', [cb_pos(1)+cb_pos(3)+0.005, ...
                             cb_pos(2), 0.012, cb_pos(4)]);
imagesc(ax2_cb, flipud(linspace(0,1,256)'));
colormap(ax2_cb, warmToCool);
set(ax2_cb, 'YDir', 'normal', 'XTick', [], ...
    'YTick', [1 128 256], 'YTickLabel', {'Late','','Early'}, ...
    'FontSize', 8);
ylabel(ax2_cb, 'Spike latency', 'FontSize', 9);
axes(ax2);  % return focus

% --- Axis formatting ---
xlim([0.5 16.5]);
ylim([0.5 16.5]);
xticks(1:16);  xticklabels(columns);  xtickangle(0);
yticks(1:16);  yticklabels(rows);
set(gca, 'FontSize', 8);
xlabel('Column', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Row',    'FontSize', 10, 'FontWeight', 'bold');
title(sprintf('Event %d: Latency on Layers  |  R² = %.2f', ...
    eventNumber, waveCoherence), ...
    'FontSize', 11, 'FontWeight', 'bold');

hold off;
%% ===== TILE 3: Velocity Distribution (IMPROVED V42) =====
ax3 = nexttile;

if ~isempty(velocities_COM) && length(velocities_COM) > 1
    % Filter: exclude inf, >1000, and values very close to 0 (artifacts)
    velThreshold = 5;  % mm/s minimum
    validVel = velocities_COM(~isinf(velocities_COM) & ...
        velocities_COM < 1000 & velocities_COM > velThreshold);
    
    % Count excluded near-zero values for annotation
    nearZeroCount = sum(velocities_COM >= 0 & velocities_COM <= velThreshold & ~isinf(velocities_COM));
    
    if length(validVel) > 10
        % Create histogram with adaptive binning
        nBins = min(30, max(10, round(length(validVel)/5)));
        histogram(validVel, nBins, 'FaceColor', [0.3 0.5 0.8], ...
            'EdgeColor', [0.2 0.3 0.5], 'LineWidth', 0.8, 'FaceAlpha', 0.8);
        hold on;
        
        % Statistics
        meanVel = mean(validVel);
        medianVel = median(validVel);
        p25 = prctile(validVel, 25);
        p75 = prctile(validVel, 75);
        
        % Vertical lines for mean and median
        yl = ylim;
        hMean = plot([meanVel meanVel], yl, '-', 'Color', [0.8 0.2 0.2], 'LineWidth', 2.5);
        hMedian = plot([medianVel medianVel], yl, '--', 'Color', [0.2 0.6 0.2], 'LineWidth', 2);
        
        % Compact legend with all info
        legend([hMean, hMedian], ...
               {sprintf('Mean: %.0f mm/s', meanVel), ...
                sprintf('Median: %.0f mm/s', medianVel)}, ...
               'Location', 'northeast', 'FontSize', 8, 'Box', 'off');
        
        hold off;
        
        xlabel('Velocity (mm/s)', 'FontSize', 10, 'FontWeight', 'bold');
        ylabel('Count', 'FontSize', 10, 'FontWeight', 'bold');
        
        % Title includes sample size info
        if nearZeroCount > 0
            title(sprintf('Velocity Distribution (n=%d, excl. %d)', ...
                length(validVel), nearZeroCount), 'FontSize', 11, 'FontWeight', 'bold');
        else
            title(sprintf('Velocity Distribution (n=%d)', length(validVel)), ...
                'FontSize', 11, 'FontWeight', 'bold');
        end
        
        % Clean grid
        grid on;
        set(gca, 'GridAlpha', 0.3, 'FontSize', 9);
        xlim([0 max(validVel)*1.1]);
    else
        axis off;
        text(0.5, 0.5, sprintf('Insufficient data\n(n=%d valid)', length(validVel)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontSize', 10);
    end
else
    axis off;
    text(0.5, 0.5, 'No velocity data', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontSize', 10);
end

%% ===== TILE 4: Summary Panel (IMPROVED V42 - cleaner layout) =====
ax4 = nexttile;
axis off;
hold on;

% ========== SUMMARY TEXT (Top portion) ==========
text(0.02, 0.98, sprintf('Event %d Summary:', eventNumber), ...
    'Units', 'normalized', 'FontSize', 11, 'FontWeight', 'bold', ...
    'VerticalAlignment', 'top');

text(0.02, 0.85, sprintf('Active Electrodes: %d', length(spikeInfo)), ...
    'Units', 'normalized', 'FontSize', 9, 'VerticalAlignment', 'top');

text(0.02, 0.76, sprintf('Wave Direction: %.1f°', waveDirection), ...
    'Units', 'normalized', 'FontSize', 9, 'VerticalAlignment', 'top');

text(0.02, 0.67, sprintf('Wave Coherence: %.2f', waveCoherence), ...
    'Units', 'normalized', 'FontSize', 9, 'VerticalAlignment', 'top');

text(0.02, 0.55, 'Velocity Methods:', ...
    'Units', 'normalized', 'FontSize', 9, 'FontWeight', 'bold', 'VerticalAlignment', 'top');

text(0.02, 0.46, sprintf('  COM-based: %.1f mm/s', meanVelocity_COM), ...
    'Units', 'normalized', 'FontSize', 9, 'VerticalAlignment', 'top');

text(0.02, 0.37, sprintf('  Gradient: %.1f mm/s', meanVelocity_gradient), ...
    'Units', 'normalized', 'FontSize', 9, 'VerticalAlignment', 'top');

% ========== LEGEND (within same axes) ==========
% Initiator symbol
plot(0.08, 0.26, 'p', 'MarkerSize', 14, 'MarkerFaceColor', [1 0.85 0], ...
    'MarkerEdgeColor', [0.6 0.4 0], 'LineWidth', 1.5);
text(0.18, 0.26, 'Initiator (1st spike)', 'Units', 'data', ...
    'FontSize', 8, 'VerticalAlignment', 'middle');

% COM trajectory symbols
scatter(0.05, 0.18, 50, [0 0.7 0], 'filled', 'MarkerEdgeColor', 'k');
plot([0.05 0.11], [0.18 0.18], '-', 'Color', [0.5 0.5 0], 'LineWidth', 2);
scatter(0.11, 0.18, 50, [0.8 0 0], 'filled', 'MarkerEdgeColor', 'k');
text(0.18, 0.18, 'COM trajectory', 'Units', 'data', ...
    'FontSize', 8, 'VerticalAlignment', 'middle');

% ========== DIRECTION COMPASS (simplified, within axes) ==========
if ~isnan(waveDirection) && waveCoherence > 0.1
    % Compass center position
    cx = 0.75; cy = 0.25; r = 0.15;
    
    % Draw compass circle
    theta = linspace(0, 2*pi, 40);
    plot(cx + r*cos(theta), cy + r*sin(theta), 'k-', 'LineWidth', 1);
    
    % Cardinal directions
    text(cx, cy + r + 0.03, 'N', 'HorizontalAlignment', 'center', 'FontSize', 7, 'FontWeight', 'bold');
    text(cx + r + 0.03, cy, 'E', 'HorizontalAlignment', 'center', 'FontSize', 7);
    text(cx, cy - r - 0.03, 'S', 'HorizontalAlignment', 'center', 'FontSize', 7);
    text(cx - r - 0.03, cy, 'W', 'HorizontalAlignment', 'center', 'FontSize', 7);
    
    % Direction arrow
    dirRad = deg2rad(waveDirection);
    arrowLen = r * 0.85;
    quiver(cx, cy, arrowLen*sin(dirRad), -arrowLen*cos(dirRad), 0, ...
        'Color', [0.7 0 0], 'LineWidth', 2, 'MaxHeadSize', 0.8);
    
    % Direction label
    text(cx, cy - r - 0.10, sprintf('%.1f°', waveDirection), ...
        'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold');
end

xlim([0 1]);
ylim([0 1]);
hold off;

%% Save figure
print(hFig, fullfile(figuresFolder, sprintf('Event_%d_Propagation.png', eventNumber)), '-dpng', '-r300');
set(hFig, 'Visible', 'on');
savefig(hFig, fullfile(figuresFolder, strrep(sprintf('Event_%d_Propagation.png', eventNumber), '.png', '.fig')));
close(hFig);



% ================================================================
% END OF CORRECTED PROPAGATION ANALYSIS SECTION
% ================================================================
           
        catch ME
            addStatus(sprintf('  ERROR in Event %d: %s', eventIdx, ME.message));
            fprintf('Detailed error:\n%s\n', getReport(ME));
        end
    end
    
    %% Generate summary figure
    if ~isempty(eventSummaryTable) && height(eventSummaryTable) > 0
        try
            hFig = figure('Name', 'Propagation Analysis Summary', 'Visible', 'off', 'Position', [100, 100, 1400, 800]);
            
            % Subplot 1: COM Velocity distribution
            subplot(2, 3, 1);
            validVel = eventSummaryTable.Velocity_COM_mm_s(~isnan(eventSummaryTable.Velocity_COM_mm_s));
            if ~isempty(validVel)
                histogram(validVel, 10);
                xlabel('Propagation Velocity (mm/s)');
                ylabel('Count');
                title(sprintf('COM Velocity Distribution\nMean: %.1f ± %.1f mm/s', mean(validVel), std(validVel)));
                grid on;
            else
                text(0.5, 0.5, 'No valid data', 'HorizontalAlignment', 'center');
            end
            
            % Subplot 2: Method comparison
            subplot(2, 3, 2);
            validCOM = eventSummaryTable.Velocity_COM_mm_s(~isnan(eventSummaryTable.Velocity_COM_mm_s));
            validGrad = eventSummaryTable.Velocity_Gradient_mm_s(~isnan(eventSummaryTable.Velocity_Gradient_mm_s));
            
            if ~isempty(validCOM) && ~isempty(validGrad)
                methods = {'COM', 'Gradient'};
                means = [mean(validCOM), mean(validGrad)];
                stds = [std(validCOM), std(validGrad)];
                
                bar(means);
                hold on;
                errorbar(1:2, means, stds, 'k.', 'LineWidth', 1.5);
                set(gca, 'XTickLabel', methods);
                ylabel('Velocity (mm/s)');
                title('Method Comparison');
                grid on;
                hold off;
            end
            
            % Subplot 3: Direction distribution
            subplot(2, 3, 3);
            validDir = eventSummaryTable.WaveDirection_deg(~isnan(eventSummaryTable.WaveDirection_deg));
            if ~isempty(validDir)
                polarhistogram(deg2rad(validDir), 12);
                title('Wave Direction Distribution');
            else
                text(0.5, 0.5, 'No valid data', 'HorizontalAlignment', 'center');
            end
            
            % Subplot 4: Coherence vs Velocity
            subplot(2, 3, 4);
            validData = ~isnan(eventSummaryTable.Velocity_COM_mm_s) & ~isnan(eventSummaryTable.WaveCoherence);
            if sum(validData) > 0
                scatter(eventSummaryTable.WaveCoherence(validData), ...
                    eventSummaryTable.Velocity_COM_mm_s(validData), 50, 'filled');
                xlabel('Wave Coherence');
                ylabel('COM Velocity (mm/s)');
                title('Coherence vs Velocity');
                grid on;
            else
                text(0.5, 0.5, 'No valid data', 'HorizontalAlignment', 'center');
            end
            
            % Subplot 5: Velocity per event
            subplot(2, 3, 5);
            if ~isempty(validVel)
                plot(eventSummaryTable.EventNumber(~isnan(eventSummaryTable.Velocity_COM_mm_s)), ...
                    validVel, 'o-', 'LineWidth', 1.5, 'MarkerSize', 8);
                xlabel('Event Number');
                ylabel('Velocity (mm/s)');
                title('Velocity by Event');
                grid on;
            end
            
            % Subplot 6: Summary statistics
            subplot(2, 3, 6);
            axis off;
            
            summaryText = {
                'PROPAGATION SUMMARY:';
                '';
                sprintf('Events Analyzed: %d', length(eventsToAnalyze));
                sprintf('Valid Velocities: %d', sum(~isnan(eventSummaryTable.Velocity_COM_mm_s)));
                '';
                'COM-based Method:';
                sprintf('  Mean: %.1f mm/s', mean(validVel));
                sprintf('  Std: %.1f mm/s', std(validVel));
                sprintf('  Median: %.1f mm/s', median(validVel));
                sprintf('  Range: %.1f - %.1f mm/s', min(validVel), max(validVel));
                '';
                'Method: Center of Mass';
                'Wave Front Tracking';
                '(Original from V17)';
                '';
                'CORRECTED: Coordinates';
                'now match LayerDic display';
            };
            
            text(0.1, 0.5, summaryText, 'FontSize', 9, 'FontWeight', 'bold', ...
                'VerticalAlignment', 'middle', 'FontName', 'FixedWidth');
            
            print(hFig, fullfile(figuresFolder, 'Propagation_Summary.png'), '-dpng', '-r300');
            set(hFig, 'Visible', 'on');
            savefig(hFig, fullfile(figuresFolder, 'Propagation_Summary.fig'));
            close(hFig);
            
        catch ME
            addStatus(sprintf('Warning: Could not generate summary figure: %s', ME.message));
        end
        
        % Save results
        try
            writetable(eventSummaryTable, fullfile(propagationFolder, 'PropagationSummary.xlsx'));
            
            validVelocities = eventSummaryTable.Velocity_COM_mm_s(~isnan(eventSummaryTable.Velocity_COM_mm_s));
            
            addStatus(sprintf('Propagation analysis complete! Analyzed %d events', length(eventsToAnalyze)));
            if ~isempty(validVelocities)
                addStatus(sprintf('COM Mean velocity: %.2f ± %.2f mm/s', mean(validVelocities), std(validVelocities)));
            else
                addStatus('No valid velocity measurements');
            end
            addStatus(sprintf('Results saved to: %s', propagationFolder));
            
        catch ME
            addStatus(sprintf('Warning: Could not save results: %s', ME.message));
        end
        
    else
        addStatus('No propagation results generated');
    end

    addStatus('-----------------------------------');
    addStatus('Analysis pipeline complete!');
    addStatus('Saving final status log...');
    saveStatusLog();  % ← Add this call here!
    addStatus('Final log saved successfully!');
    addStatus('===================================');
end


% ==================== HELPER FUNCTIONS ====================

function createSpikeSummary(spikeDataFolder, sortedChannels, spikeData, ...
    samplingRate, preTime, postTime, totalSpikes)
    % Create text summary of spike data export
    
    summaryFile = fullfile(spikeDataFolder, 'Spike_Summary.txt');
    fid = fopen(summaryFile, 'w');
    
    fprintf(fid, '=========================================\n');
    fprintf(fid, 'SPIKE DATA EXPORT FOR LFP CORRELATION\n');
    fprintf(fid, '=========================================\n\n');
    fprintf(fid, 'Export Date: %s\n\n', datestr(now));
    
    fprintf(fid, 'CONFIGURATION:\n');
    fprintf(fid, '  Sampling Rate: %d Hz\n', samplingRate);
    fprintf(fid, '  Snippet Pre-time: %.1f ms\n', preTime * 1000);
    fprintf(fid, '  Snippet Post-time: %.1f ms\n', postTime * 1000);
    fprintf(fid, '  Snippet Length: %d samples\n\n', ...
        round((preTime + postTime) * samplingRate) + 1);
    
    fprintf(fid, 'SPIKE COUNTS PER CHANNEL:\n');
    fprintf(fid, '%-10s %15s\n', 'Channel', 'Spike Count');
    fprintf(fid, '%-10s %15s\n', '-------', '-----------');
    
    activeChannels = 0;
    for i = 1:length(sortedChannels)
        channel = sortedChannels{i};
        numSpikes = length(spikeData.(channel).times);
        if numSpikes > 0
            fprintf(fid, '%-10s %15d\n', channel, numSpikes);
            activeChannels = activeChannels + 1;
        end
    end
    
    fprintf(fid, '\nSUMMARY:\n');
    fprintf(fid, '  Total Channels: %d\n', length(sortedChannels));
    fprintf(fid, '  Active Channels: %d\n', activeChannels);
    fprintf(fid, '  Total Spikes: %d\n', totalSpikes);
    if activeChannels > 0
        fprintf(fid, '  Mean Spikes per Active Channel: %.1f\n', totalSpikes / activeChannels);
    end
    
    fprintf(fid, '\nFILE FORMATS:\n');
    fprintf(fid, '  All_Spike_Times.xlsx/csv: Complete list of all spike times\n');
    fprintf(fid, '    Columns: Channel, Spike_Number, Time_s, Sample_Index\n\n');
    fprintf(fid, '  Snippets_[Channel].mat: Spike waveform snippets per channel\n');
    fprintf(fid, '    Variables:\n');
    fprintf(fid, '      - snippets: [N_spikes x N_samples] waveform matrix\n');
    fprintf(fid, '      - spikeTimes: [N_spikes x 1] spike times in seconds\n');
    fprintf(fid, '      - spikeIndices: [N_spikes x 1] spike sample indices\n');
    fprintf(fid, '      - timeVector: Time axis for snippets (in ms)\n');
    fprintf(fid, '      - samplingRate: Sampling rate in Hz\n');
    fprintf(fid, '      - channel: Channel name\n\n');
    
    fprintf(fid, '  Spike_Propagation_Data.mat: Propagation analysis data\n');
    fprintf(fid, '    Compatible with LFP propagation analysis format\n');
    fprintf(fid, '    Contains latency matrices and wave metrics\n\n');
    
    fprintf(fid, '  Event_Spike_Data.mat: Spikes organized by network events\n');
    fprintf(fid, '    Each event contains spike times and snippets per channel\n\n');
    
    fprintf(fid, 'USAGE FOR LFP CORRELATION:\n');
    fprintf(fid, '  1. Load All_Spike_Times.mat or .csv for spike timing\n');
    fprintf(fid, '  2. Load Snippets_[Channel].mat for waveform analysis\n');
    fprintf(fid, '  3. Use Time_s or Sample_Index to align with LFP data\n');
    fprintf(fid, '  4. Load Spike_Propagation_Data.mat for propagation comparison\n\n');
    fprintf(fid, '  Example MATLAB code:\n');
    fprintf(fid, '       load(''All_Spike_Times.mat'');\n');
    fprintf(fid, '       channelSpikes = allSpikeTimes(strcmp(allSpikeTimes.Channel, ''C15''), :);\n');
    fprintf(fid, '       spikeTimestamps = channelSpikes.Time_s;\n\n');
    fprintf(fid, '  For comparison with LFP propagation:\n');
    fprintf(fid, '       [spikeProp, metadata] = load_spike_data_for_lfp(''Spike_Data_for_LFP'');\n');
    fprintf(fid, '       compareSpikeLFPPropagation(''Spike_Data_for_LFP'', lfpPropagationResults);\n\n');
    
    fprintf(fid, '=========================================\n');
    
    fclose(fid);
end

function createSpikeSnippetVisualization(spikeDataFolder, sortedChannels, ...
    spikeData, filteredChannelData, samplingRate, preSamples, postSamples)
    % Create example visualization of spike snippets
    
    % Find channel with most spikes
    maxSpikes = 0;
    bestChannel = '';
    for i = 1:length(sortedChannels)
        channel = sortedChannels{i};
        numSpikes = length(spikeData.(channel).times);
        if numSpikes > maxSpikes
            maxSpikes = numSpikes;
            bestChannel = channel;
        end
    end
    
    if isempty(bestChannel) || maxSpikes == 0
        fprintf('  No spikes found for visualization\n');
        return;
    end
    
    % Extract snippets from best channel
    Time = getappdata(fig, 'Time');
    spikeTimes = spikeData.(bestChannel).times;
    spikeIndices = round((spikeTimes - Time(1)) * samplingRate) + 1;
    signal = filteredChannelData.(bestChannel);
    
    snippetLength = preSamples + postSamples + 1;
    snippets = zeros(min(100, maxSpikes), snippetLength);
    
    count = 0;
    for s = 1:min(100, maxSpikes)
        idx = spikeIndices(s);
        
        if idx - preSamples < 1 || idx + postSamples > length(signal)
            continue;
        end
        
        count = count + 1;
        snippets(count, :) = signal(idx - preSamples : idx + postSamples);
    end
    
    snippets = snippets(1:count, :);
    
    if count == 0
        fprintf('  No valid snippets for visualization\n');
        return;
    end
    
    % Create figure
    hFig = figure('Visible', 'off', 'Position', [100, 100, 1200, 800]);
    
    % Subplot 1: All snippets overlaid
    subplot(2, 2, 1);
    timeVector = (-preSamples:postSamples) / samplingRate * 1000; % ms
    plot(timeVector, snippets', 'Color', [0.5 0.5 0.5 0.3], 'LineWidth', 0.5);
    hold on;
    meanSnippet = mean(snippets, 1);
    plot(timeVector, meanSnippet, 'r-', 'LineWidth', 2);
    xline(0, 'k--', 'Spike Time', 'LineWidth', 1.5);
    xlabel('Time (ms)');
    ylabel('Amplitude (µV)');
    title(sprintf('Spike Snippets - %s (%d spikes)', bestChannel, count));
    legend('Individual Spikes', 'Mean', 'Location', 'best');
    grid on;
    hold off;
    
    % Subplot 2: Heatmap of all snippets
    subplot(2, 2, 2);
    imagesc(timeVector, 1:count, snippets);
    colormap('jet');
    colorbar;
    xlabel('Time (ms)');
    ylabel('Spike Number');
    title('Spike Snippet Heatmap');
    xline(0, 'w--', 'LineWidth', 2);
    
    % Subplot 3: Mean ± STD
    subplot(2, 2, 3);
    meanSnippet = mean(snippets, 1);
    stdSnippet = std(snippets, 0, 1);
    
    fill([timeVector, fliplr(timeVector)], ...
         [meanSnippet + stdSnippet, fliplr(meanSnippet - stdSnippet)], ...
         'r', 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    hold on;
    plot(timeVector, meanSnippet, 'r-', 'LineWidth', 2);
    xline(0, 'k--', 'Spike Time', 'LineWidth', 1.5);
    xlabel('Time (ms)');
    ylabel('Amplitude (µV)');
    title('Mean Spike Waveform ± STD');
    grid on;
    hold off;
    
    % Subplot 4: Peak amplitude distribution
    subplot(2, 2, 4);
    peakAmplitudes = min(snippets, [], 2);
    histogram(peakAmplitudes, 30, 'FaceColor', [0.3 0.6 0.9]);
    xlabel('Peak Amplitude (µV)');
    ylabel('Count');
    title(sprintf('Peak Amplitude Distribution (Mean: %.1f µV)', mean(peakAmplitudes)));
    grid on;
    
    % Save figure
    print(hFig, fullfile(spikeDataFolder, 'Example_Spike_Snippets.png'), '-dpng', '-r300');
    set(hFig, 'Visible', 'on');
    savefig(hFig, fullfile(spikeDataFolder, 'Example_Spike_Snippets.fig'));
    close(hFig);
    
    fprintf('  ✓ Spike snippet visualization saved\n');
end

    function [row, col] = electrodeNameToIndex(elecName)
    % Parse electrode name to row/column indices
    % Handles both old (uses I, skips J) and new (uses J, skips I) MEA systems
    
    % Clean up input - remove quotes, whitespace, etc.
    if ~ischar(elecName) && ~isstring(elecName)
        error('Invalid electrode name type: %s', class(elecName));
    end
    
    elecName = char(elecName);  % Convert to char if string
    elecName = strtrim(elecName);  % Remove whitespace
    elecName = strrep(elecName, '"', '');  % Remove quotes
    elecName = strrep(elecName, '''', '');  % Remove single quotes
    
    % Extract letter and number with more flexible pattern
    % Pattern matches: one or more letters followed by one or more digits
    tokens = regexp(elecName, '^([A-PR]+)(\d+)$', 'tokens', 'once');
    
    if isempty(tokens)
        error('Invalid electrode name format: "%s" (expected format: A1, I15, etc.)', elecName);
    end
    
    colLetter = upper(tokens{1});  % Ensure uppercase
    rowNum = str2double(tokens{2});
    
    % Validate row number
    if isnan(rowNum) || rowNum < 1 || rowNum > 16
        error('Invalid row number %d in electrode: %s (must be 1-16)', rowNum, elecName);
    end
    
    % Column mapping for both MEA types
    % OLD MEA: A,B,C,D,E,F,G,H,I,K,L,M,N,O,P,R (skips J)
    % NEW MEA: A,B,C,D,E,F,G,H,J,K,L,M,N,O,P,R (skips I)
    
    oldColumns = {'A','B','C','D','E','F','G','H','I','K','L','M','N','O','P','R'};
    newColumns = {'A','B','C','D','E','F','G','H','J','K','L','M','N','O','P','R'};
    
    % First, try to find in old columns (handles I)
    colIdx = find(strcmp(oldColumns, colLetter), 1);
    
    % If not found, try new columns (handles J)
    if isempty(colIdx)
        colIdx = find(strcmp(newColumns, colLetter), 1);
    end
    
    % If still not found, error
    if isempty(colIdx)
        error('Invalid column letter "%s" in electrode: %s (must be A-H,I/J,K-P,R)', ...
            colLetter, elecName);
    end
    
    row = rowNum;
    col = colIdx;
end

function [spikeTimes, spikeAmplitudes] = detectSpikes(channelSignal, Time, sr, multiplier)
    noiseStd = median(abs(channelSignal) / 0.6745);
    threshold = -multiplier * noiseStd;
    
    crossesThreshold = channelSignal < threshold;
    thresholdCrossings = find(diff(crossesThreshold) == 1) + 1;
    
    spikeIndices = [];
    windowSize = round(0.001 * sr);
    for idx = thresholdCrossings'
        windowStart = max(idx - windowSize, 1);
        windowEnd = min(idx + windowSize, length(channelSignal));
        [~, localMinIdx] = min(channelSignal(windowStart:windowEnd));
        spikeIndices = [spikeIndices; (windowStart + localMinIdx - 1)];
    end
    
    refractorySamples = round(0.001 * sr);
    spikeIndices = unique(spikeIndices);
    if numel(spikeIndices) > 1
        spikeDiffs = diff(spikeIndices);
        keepMask = [true; spikeDiffs > refractorySamples];
        spikeIndices = spikeIndices(keepMask);
    end
    
    spikeTimes = Time(spikeIndices);
    spikeAmplitudes = channelSignal(spikeIndices);
end

function globalThreshold = computeGlobalThreshold(filteredChannelData, multiplier)
    allSignals = [];
    channelNames = fieldnames(filteredChannelData);
    
    for iChan = 1:length(channelNames)
        sig = filteredChannelData.(channelNames{iChan});
        allSignals = [allSignals; sig(:)];
    end
    
    noiseStdGlobal = median(abs(allSignals) / 0.6745);
    globalThreshold = -multiplier * noiseStdGlobal;
end

function [spikeTimes, spikeAmplitudes] = detectSpikesGlobal(channelSignal, Time, sr, globalThreshold)
    crossesThreshold = channelSignal < globalThreshold;
    thresholdCrossings = find(diff(crossesThreshold) == 1) + 1;
    
    spikeIndices = [];
    windowSize = round(0.001 * sr);
    for idx = thresholdCrossings'
        windowStart = max(idx - windowSize, 1);
        windowEnd = min(idx + windowSize, length(channelSignal));
        [~, localMinIdx] = min(channelSignal(windowStart:windowEnd));
        spikeIndices = [spikeIndices; windowStart + localMinIdx - 1];
    end
    
    refractorySamples = round(0.001 * sr);
    spikeIndices = unique(spikeIndices);
    if ~isempty(spikeIndices) && length(spikeIndices) > 1
        spikeDiffs = diff(spikeIndices);
        keepMask = [true; spikeDiffs > refractorySamples];
        spikeIndices = spikeIndices(keepMask);
    end
    
    spikeTimes = Time(spikeIndices);
    spikeAmplitudes = channelSignal(spikeIndices);
end
    function SummaryTable = generateSummaryTable()
    % Get all necessary data
    totalDuration = getappdata(fig, 'totalDuration');
    spikeData = getappdata(fig, 'spikeData');
    firingRates = getappdata(fig, 'firingRates');
    eventOnsets = getappdata(fig, 'eventOnsets');
    eventOffsets = getappdata(fig, 'eventOffsets');
    samplingRate = getappdata(fig, 'samplingRate');
    
    % ===== GET SPIKE DETECTION PARAMETERS =====
    sdThreshold = str2double(get(findobj('Tag', 'sdThreshold'), 'String'));
    if isnan(sdThreshold)
        sdThreshold = 4; % Default
    end
    
    methodIdx = get(findobj('Tag', 'method'), 'Value');
    if methodIdx == 1
        detectionMethod = 'Per-channel';
    else
        detectionMethod = 'Global';
    end
    
    % ===== GET EVENT DETECTION PARAMETERS =====
    eventSDMultiplier = str2double(get(findobj('Tag', 'eventSDMultiplier'), 'String'));
    if isnan(eventSDMultiplier)
        eventSDMultiplier = getappdata(fig, 'eventSDMultiplier');
        if isempty(eventSDMultiplier)
            eventSDMultiplier = 4; % Default
        end
    end
    
    minChannels = str2double(get(findobj('Tag', 'minChannels'), 'String'));
    if isnan(minChannels)
        minChannels = 3;
    end
    
    maxChannels = str2double(get(findobj('Tag', 'maxChannels'), 'String'));
    if isnan(maxChannels)
        maxChannels = 120;
    end
    
    % ===== GET REFERENCE CHANNEL =====
    refChannel = get(findobj('Tag', 'refChannel'), 'String');
    if isempty(refChannel)
        refChannel = 'Not set';
    end
    
    % Calculate statistics
    channelNames = fieldnames(spikeData);
    totalElectrodes = length(channelNames);
    
    % Pre-count total spikes for pre-allocation
    totalSpikes = 0;
    for idx = 1:length(channelNames)
        channel = channelNames{idx};
        totalSpikes = totalSpikes + length(spikeData.(channel).times);
    end
    
    % Pre-allocate
    allSpikeAmplitudes = zeros(totalSpikes, 1);
    ampIdx = 0;
    maxFiringRate = 0;
    numActiveElectrodes = 0;
    spikesPerMinuteThreshold = 5;
    
    for idx = 1:length(channelNames)
        channel = channelNames{idx};
        numSpikes = length(spikeData.(channel).times);
        
        fr = firingRates.(channel);
        if fr > maxFiringRate
            maxFiringRate = fr;
        end
        
        % Store amplitudes in pre-allocated array
        channelAmps = spikeData.(channel).amplitudes;
        allSpikeAmplitudes(ampIdx+1:ampIdx+numSpikes) = channelAmps;
        ampIdx = ampIdx + numSpikes;
        
        spikesPerMinute = numSpikes / (totalDuration / 60);
        if spikesPerMinute >= spikesPerMinuteThreshold
            numActiveElectrodes = numActiveElectrodes + 1;
        end
    end
    
    meanGlobalFiringRate = totalSpikes / totalDuration / totalElectrodes;
    firingRatesArray = cell2mat(struct2cell(firingRates));
    stdFiringRate = std(firingRatesArray);
    meanSpikeAmplitude = mean(abs(allSpikeAmplitudes));
    percentageActiveElectrodes = (numActiveElectrodes / totalElectrodes) * 100;
    
    % Event statistics
    if ~isempty(eventOnsets)
        numEvents = length(eventOnsets);
        avgEventDuration = mean(eventOffsets - eventOnsets);
        totalTimeInEvents = sum(eventOffsets - eventOnsets);
    else
        numEvents = 0;
        avgEventDuration = 0;
        totalTimeInEvents = 0;
    end
    
    % ===== CREATE ENHANCED SUMMARY TABLE =====
    SummaryTable = table();
    SummaryTable.Parameter = {
        '=== RECORDING INFO ===';
        'Total Recording Duration (s)';
        'Sampling Rate (Hz)';
        'Total Number of Electrodes';
        '';
        '=== SPIKE DETECTION ===';
        'Total Number of Detected Spikes';
        'Spike Detection Method';
        'Spike Detection Threshold (SD)';
        'Mean Spike Amplitude (µV)';
        'Mean Global Firing Rate (Hz per electrode)';
        'Standard Deviation of Firing Rates (Hz)';
        'Max Firing Rate (Hz)';
        '';
        '=== ACTIVE ELECTRODES ===';
        'Number of Active Electrodes (≥5 spikes/min)';
        'Percentage of Active Electrodes (%)';
        '';
        '=== NETWORK EVENTS ===';
        'Number of Network Events Detected';
        'Event Detection Threshold (SD multiplier)';
        'Event Min Channels';
        'Event Max Channels';
        'Reference Channel for Events';
        'Average Network Event Duration (s)';
        'Total Time in Network Events (s)';
        'Percentage of Time in Events (%)';
    };
    
    SummaryTable.Value = {
        '';
        totalDuration;
        samplingRate;
        totalElectrodes;
        '';
        '';
        totalSpikes;
        detectionMethod;
        sdThreshold;
        meanSpikeAmplitude;
        meanGlobalFiringRate;
        stdFiringRate;
        maxFiringRate;
        '';
        '';
        numActiveElectrodes;
        percentageActiveElectrodes;
        '';
        '';
        numEvents;
        eventSDMultiplier;
        minChannels;
        maxChannels;
        refChannel;
        avgEventDuration;
        totalTimeInEvents;
        (totalTimeInEvents / totalDuration) * 100;
    };
    
    % Store for later use
    setappdata(fig, 'sdThreshold', sdThreshold);
    setappdata(fig, 'detectionMethod', detectionMethod);
    setappdata(fig, 'refChannel', refChannel);
end


function EventTable = generateEventTable()
    eventOnsets = getappdata(fig, 'eventOnsets');
    eventOffsets = getappdata(fig, 'eventOffsets');
    
    if isempty(eventOnsets)
        EventTable = table();
        return;
    end
    
    eventNumbers = (1:length(eventOnsets))';
    startTimes = eventOnsets(:);
    endTimes = eventOffsets(:);
    durations = endTimes - startTimes;
    
    EventTable = table(eventNumbers, startTimes, endTimes, durations, ...
        'VariableNames', {'Event_Number', 'Start_Time_s', 'End_Time_s', 'Duration_s'});
end

    function saveStatusLog()
    % Save the status log to a text file
    outputFolder = getappdata(fig, 'outputFolder');
    statusLog = getappdata(fig, 'statusLog');
    
    if isempty(outputFolder)
        fprintf('No output folder selected, cannot save log\n');
        return;
    end
    
    % Create log filename with timestamp
    timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
    logFileName = fullfile(outputFolder, sprintf('Analysis_Log_%s.txt', timestamp));
    
    % Write to file
    fid = fopen(logFileName, 'w');
    
    if fid == -1
        fprintf('Could not create log file\n');
        return;
    end
    
    fprintf(fid, '========================================\n');
    fprintf(fid, 'MEA Analysis Log\n');
    fprintf(fid, '========================================\n');
    fprintf(fid, 'Generated: %s\n\n', datestr(now));
    fprintf(fid, 'Output folder: %s\n', outputFolder);
    fprintf(fid, '========================================\n\n');
    
    % Write each line of the status log
    if ~isempty(statusLog) && iscell(statusLog)
        fprintf(fid, 'STATUS LOG:\n');
        fprintf(fid, '----------\n\n');
        for i = 1:length(statusLog)
            fprintf(fid, '%s\n', statusLog{i});
        end
        fprintf('\n*** Full status log saved (%d messages) ***\n', length(statusLog));
    else
        fprintf(fid, 'No status messages recorded.\n');
        fprintf(fid, '\nNote: Status logging may not have been initialized.\n');
        fprintf(fid, 'Basic information:\n');
        fprintf(fid, '- Analysis completed successfully\n');
        fprintf(fid, '- Excel file with 7 sheets created\n');
        fprintf(fid, '- All figures generated\n');
        fprintf('\n*** Basic log saved (no status messages found) ***\n');
    end
    
    fprintf(fid, '\n========================================\n');
    fprintf(fid, 'Log saved: %s\n', datestr(now));
    fprintf(fid, '========================================\n');
    
    fclose(fid);
    
    fprintf('Status log saved to: %s\n\n', logFileName);
end


function idxList = parseEventString(selectionStr, maxEvent)
    % Parse event selection string like "1-3,5,7-10"
    idxList = [];
    segments = strsplit(selectionStr, ',');
    
    for i = 1:length(segments)
        seg = strtrim(segments{i});
        if contains(seg, '-')
            parts = strsplit(seg, '-');
            if length(parts) == 2
                startVal = str2double(parts{1});
                endVal = str2double(parts{2});
                if ~isnan(startVal) && ~isnan(endVal) && startVal <= endVal
                    idxList = [idxList, startVal:endVal];
                end
            end
        else
            val = str2double(seg);
            if ~isnan(val)
                idxList = [idxList, val];
            end
        end
    end
    
    idxList = unique(idxList);
    idxList(idxList < 1 | idxList > maxEvent) = [];
end

function generateEventFigures(eventNumber, epochStartTime, epochEndTime, ...
    epochSpikeData, firingRateMatrix_Epoch, LayerDic, ...
    sortedChannels, channelYPos, columns, rows, figuresFolder)
    
    % Generate comprehensive figures for a single event
    
    % Figure 1: Firing Rate Heatmap with Raster
    hFig = figure('Visible', 'off', 'Position', [100, 100, 1000, 800]);
    
    % Subplot 1: Firing rate heatmap
    subplot(2, 1, 1);
    imagesc(firingRateMatrix_Epoch);
    colormap('hot');
    colorbar;
    title(sprintf('Event %d: Firing Rates', eventNumber));
    xlabel('Column');
    ylabel('Row');
    set(gca, 'XTick', 1:length(columns), 'XTickLabel', columns);
    set(gca, 'YTick', 1:length(rows), 'YTickLabel', rows);
    set(gca, 'YDir', 'reverse');
    
    % Subplot 2: Raster plot
    subplot(2, 1, 2);
    hold on;
    
    for idx = 1:length(sortedChannels)
        channel = sortedChannels{idx};
        if isfield(epochSpikeData, channel)
            spikeTimes = epochSpikeData.(channel).times;
            if ~isempty(spikeTimes)
                yPos = channelYPos(channel);
                plot(spikeTimes, repmat(yPos, size(spikeTimes)), 'k.', 'MarkerSize', 3);
            end
        end
    end
    
    xlim([epochStartTime, epochEndTime]);
    ylim([0, length(sortedChannels) + 1]);
    xlabel('Time (s)');
    ylabel('Channel');
    title('Raster Plot');
    set(gca, 'YDir', 'reverse');
    hold off;
    
    print(hFig, fullfile(figuresFolder, sprintf('Event_%d_Overview.png', eventNumber)), '-dpng', '-r300');
    set(hFig, 'Visible', 'on');
    savefig(hFig, fullfile(figuresFolder, strrep(sprintf('Event_%d_Overview.png', eventNumber), '.png', '.fig')));
    close(hFig);
end

function [direction, coherence] = calculateWaveDirection(firstSpikeLatencyMatrix)
    % Calculate wave propagation direction and coherence
    [nRows, nCols] = size(firstSpikeLatencyMatrix);
    [X, Y] = meshgrid(1:nCols, 1:nRows);
    
    valid = ~isnan(firstSpikeLatencyMatrix);
    if sum(valid(:)) < 3
        direction = NaN;
        coherence = NaN;
        return;
    end
    
    x_coords = X(valid);
    y_coords = Y(valid);
    latencies = firstSpikeLatencyMatrix(valid);
    
    % Fit plane to latencies
    design_matrix = [x_coords(:), y_coords(:), ones(length(latencies), 1)];
    coeffs = design_matrix \ latencies(:);
    
    % Calculate direction (in degrees)
    direction = atan2(coeffs(2), coeffs(1)) * 180/pi;
    
    % Calculate coherence (R-squared)
    predicted = design_matrix * coeffs;
    ss_res = sum((latencies(:) - predicted).^2);
    ss_tot = sum((latencies(:) - mean(latencies)).^2);
    coherence = 1 - ss_res/ss_tot;
    
    if coherence < 0
        coherence = 0;
    end
end

  function processEventData(eventNumber, currentEpoch, epochName, epochSpikeData, ...
    sortedChannels, channelYPos, columns, rows, LayerDic, ...
    samplingRate, refractoryTime, multiplier, meanFR_stored, stdFR, ...
    figuresFolder, eventOnsetTime)
    
    % This function generates ALL figures for one event
    % Each figure is created independently and saved
    
    try
        %% 1. Population Firing Rate Over Time
        binSize = 0.1;
        timeEdges = currentEpoch.start:binSize:currentEpoch.end;
        timeCenters = timeEdges(1:end-1) + binSize/2;
        
        firingRatesOverTime = zeros(length(sortedChannels), length(timeCenters));
        
        for idx = 1:length(sortedChannels)
            channel = sortedChannels{idx};
            if isfield(epochSpikeData.(epochName), channel)
                spikeTimes = epochSpikeData.(epochName).(channel).times;
                if ~isempty(spikeTimes)
                    counts = histcounts(spikeTimes, timeEdges);
                    firingRatesOverTime(idx, :) = counts / binSize;
                end
            end
        end
        
        populationFiringRate = mean(firingRatesOverTime, 1, 'omitnan');
        
        % CREATE NEW FIGURE
        hFig = figure('Visible', 'off', 'Position', [100, 100, 800, 600]);
        plot(timeCenters, populationFiringRate, 'LineWidth', 1.5);
        xlabel('Time (s)');
        ylabel('Population Firing Rate (Hz)');
        title(['Population Firing Rate During ', currentEpoch.name, ' Epoch']);
        grid on;
        print(hFig, fullfile(figuresFolder, 'Population_Firing_Rate_During.png'), '-dpng', '-r300');
        set(hFig, 'Visible', 'on');
        savefig(hFig, fullfile(figuresFolder, 'Population_Firing_Rate_During.fig'));
        close(hFig);
        
    catch ME
        fprintf('Error in section 1 (Population FR): %s\n', ME.message);
    end
    
    try
        %% 2. Activity Heatmap
        binSize = 0.001;
        startTime = currentEpoch.start;
        endTime = currentEpoch.end;
        
        timeEdges = startTime:binSize:endTime;
        timeCenters = timeEdges(1:end-1) + binSize/2;
        
        activityMatrix = zeros(length(sortedChannels), length(timeCenters));
        
        for idx = 1:length(sortedChannels)
            channel = sortedChannels{idx};
            if isfield(epochSpikeData.(epochName), channel)
                spikeTimes = epochSpikeData.(epochName).(channel).times;
                if ~isempty(spikeTimes)
                    counts = histcounts(spikeTimes, timeEdges);
                    activityMatrix(idx, :) = counts;
                end
            end
        end
        
        % CREATE NEW FIGURE
        hFig = figure('Visible', 'off', 'Position', [100, 100, 1000, 600]);
        imagesc(timeCenters, 1:length(sortedChannels), activityMatrix);
        xlabel('Time (s)');
        ylabel('Channel');
        yticks(1:10:length(sortedChannels));
        yticklabels(sortedChannels(1:10:end));
        title(['Population Activity Heatmap During ', currentEpoch.name, ' Epoch']);
        colorbar;
        ylabel(colorbar, 'Spike Count');
        set(gca, 'YDir', 'normal');
        print(hFig, fullfile(figuresFolder, 'Heat_Map_Firing.png'), '-dpng', '-r300');
        set(hFig, 'Visible', 'on');
        savefig(hFig, fullfile(figuresFolder, 'Heat_Map_Firing.fig'));
        close(hFig);
        
    catch ME
        fprintf('Error in section 2 (Activity Heatmap): %s\n', ME.message);
    end
    
    try
        %% 3. Global Firing Rate
        globalSpikeCounts = sum(activityMatrix, 1);
        globalFiringRate = globalSpikeCounts / (length(sortedChannels) * binSize);
        meanGlobalFiringRate = mean(globalFiringRate);
        maxGlobalFiringRate = max(globalFiringRate);
        
        % CREATE NEW FIGURE
        hFig = figure('Visible', 'off', 'Position', [100, 100, 800, 600]);
        plot(timeCenters, globalFiringRate, 'LineWidth', 1.5);
        xlabel('Time (s)');
        ylabel('Global Firing Rate (Hz)');
        title(['Global Firing Rate During ', currentEpoch.name, ' Epoch']);
        grid on;
        print(hFig, fullfile(figuresFolder, 'Global_Firing.png'), '-dpng', '-r300');
        set(hFig, 'Visible', 'on');
        savefig(hFig, fullfile(figuresFolder, 'Global_Firing.fig'));
        close(hFig);
        
    catch ME
        fprintf('Error in section 3 (Global FR): %s\n', ME.message);
    end
    
    try
        %% 4. Event Detection within Epoch (Merged Events)
        binSize = 0.01;
        timeEdges = startTime:binSize:endTime;
        timeCenters = timeEdges(1:end-1) + binSize/2;
        
        activityMatrix = zeros(length(sortedChannels), length(timeCenters));
        
        for idx = 1:length(sortedChannels)
            channel = sortedChannels{idx};
            if isfield(epochSpikeData.(epochName), channel)
                spikeTimes = epochSpikeData.(epochName).(channel).times;
                if ~isempty(spikeTimes)
                    counts = histcounts(spikeTimes, timeEdges);
                    activityMatrix(idx, :) = counts;
                end
            end
        end
        
        populationFiringRate = sum(activityMatrix, 1) / length(sortedChannels) / binSize;
        
        meanFR = meanFR_stored;
        thresholdFR = meanFR + multiplier * stdFR;
        
        eventIndicesFR = populationFiringRate > thresholdFR;
        
        % Detect events
        eventStarts = [];
        eventEnds = [];
        
        i = 1;
        while i <= length(eventIndicesFR)
            if eventIndicesFR(i)
                eventStartIdx = i;
                while i <= length(eventIndicesFR) && eventIndicesFR(i)
                    i = i + 1;
                end
                eventEndIdx = i - 1;
                eventStarts = [eventStarts, eventStartIdx];
                eventEnds = [eventEnds, eventEndIdx];
            else
                i = i + 1;
            end
        end
        
        % Merge events
        refractoryPeriodBins = ceil(refractoryTime / binSize);
        
        k = 1;
        while k < length(eventStarts)
            gapBins = eventStarts(k+1) - eventEnds(k);
            if gapBins <= refractoryPeriodBins
                eventEnds(k) = eventEnds(k+1);
                eventStarts(k+1) = [];
                eventEnds(k+1) = [];
            else
                k = k + 1;
            end
        end
        
        eventOnsets = timeCenters(eventStarts);
        eventOffsets = timeCenters(eventEnds);
        
        % CREATE NEW FIGURE
        hFig = figure('Visible', 'off', 'Position', [100, 100, 1000, 600]);
        plot(timeCenters, populationFiringRate, 'b', 'LineWidth', 1.5);
        hold on;
        yline(thresholdFR, 'r--', 'Threshold', 'LineWidth', 1.5);
        
        for e = 1:length(eventOnsets)
            xline(eventOnsets(e), 'g--', 'LineWidth', 1);
            xline(eventOffsets(e), 'm--', 'LineWidth', 1);
        end
        
        xlabel('Time (s)');
        ylabel('Population Firing Rate (Hz)');
        title(['Population Firing Rate During ', currentEpoch.name, ' Epoch']);
        if length(eventOnsets) <= 5
            legend('Population Firing Rate','Threshold','Onsets','Offsets','Location','Best');
        else
            legend('Population Firing Rate','Threshold','Location','Best');
        end
        grid on;
        hold off;
        print(hFig, fullfile(figuresFolder, 'Population_Firing_Rate_MergedEvents.png'), '-dpng', '-r300');
        set(hFig, 'Visible', 'on');
        savefig(hFig, fullfile(figuresFolder, 'Population_Firing_Rate_MergedEvents.fig'));
        close(hFig);
        
    catch ME
        fprintf('Error in section 4 (Event Detection): %s\n', ME.message);
    end
    
    try
        %% 5. Firing Rate Matrix
        firingRateMatrix_Epoch = NaN(length(rows), length(columns));
        epochDuration = currentEpoch.end - currentEpoch.start;
        
        for idx = 1:length(sortedChannels)
            channel = sortedChannels{idx};
            tokens = regexp(channel, '^([A-Z]+)(\d+)$', 'tokens');
            if isempty(tokens), continue; end
            
            colLetter = tokens{1}{1};
            rowNumber = str2double(tokens{1}{2});
            colIdx = find(strcmp(columns, colLetter), 1);
            
            if ~isempty(colIdx) && rowNumber >= 1 && rowNumber <= length(rows)
                if isfield(epochSpikeData.(epochName), channel)
                    spikeCount = epochSpikeData.(epochName).(channel).count;
                else
                    spikeCount = 0;
                end
                firingRate = spikeCount / epochDuration;
                firingRateMatrix_Epoch(rowNumber, colIdx) = firingRate;
            end
        end
        
    catch ME
        fprintf('Error in section 5 (FR Matrix): %s\n', ME.message);
    end
    
    try
        %% 6. Combined Firing Rate and Raster Plot
        % CREATE NEW FIGURE
        hFig = figure('Visible', 'off', 'Position', [100, 100, 1000, 800]);
        
        % Subplot 1: Firing Rate Heatmap
        subplot(2, 1, 1);
        imagesc(firingRateMatrix_Epoch);
        colormap(gca, 'hot');
        colorbar;
        xlabel('Electrode Column');
        ylabel('Electrode Row');
        title(['Firing Rates During ', currentEpoch.name, ' Epoch']);
        xticks(1:length(columns));
        xticklabels(columns);
        yticks(1:length(rows));
        yticklabels(arrayfun(@num2str, rows, 'UniformOutput', false));
        set(gca, 'YDir', 'reverse');
        
        % Subplot 2: Raster Plot
        subplot(2, 1, 2);
        
        % Build spike arrays
        epochXSpikes = [];
        epochYSpikes = [];
        
        for idx = 1:length(sortedChannels)
            channel = sortedChannels{idx};
            if isfield(epochSpikeData.(epochName), channel) && ...
               isfield(epochSpikeData.(epochName).(channel), 'times')
                
                spikeTimes = epochSpikeData.(epochName).(channel).times;
                numSpikes = length(spikeTimes);
                
                if numSpikes > 0
                    % Force column vectors
                    spikeTimes = spikeTimes(:);
                    
                    % Get y-position
                    yPos = channelYPos(channel);
                    
                    % Create column vector of y-positions
                    yPositions = yPos * ones(numSpikes, 1);
                    
                    % Concatenate
                    epochXSpikes = [epochXSpikes; spikeTimes];
                    epochYSpikes = [epochYSpikes; yPositions];
                end
            end
        end
        
        % Plot if we have spikes
        if ~isempty(epochXSpikes) && ~isempty(epochYSpikes)
            colors = lines(length(columns));
            epochSpikeColors = zeros(length(epochXSpikes), 3);
            
            for s = 1:length(epochXSpikes)
                channelIdx = round(epochYSpikes(s));
                if channelIdx >= 1 && channelIdx <= length(sortedChannels)
                    channel = sortedChannels{channelIdx};
                    tokens = regexp(channel, '^([A-Z]+)(\d+)$', 'tokens');
                    if ~isempty(tokens)
                        colLetter = tokens{1}{1};
                        colIdx = find(strcmp(columns, colLetter), 1);
                        if ~isempty(colIdx)
                            if colIdx > size(colors, 1)
                                colors = lines(colIdx);
                            end
                            epochSpikeColors(s, :) = colors(colIdx, :);
                        end
                    end
                end
            end
            
            scatter(epochXSpikes, epochYSpikes, 10, epochSpikeColors, 'Marker', '*');
        end
        
        xlim([currentEpoch.start, currentEpoch.end]);
        yticks(1:10:length(sortedChannels));
        yticklabels(sortedChannels(1:10:end));
        ylim([0, length(sortedChannels) + 1]);
        set(gca, 'YDir', 'reverse');
        xlabel('Time (s)');
        ylabel('Electrode');
        title(['Raster Plot During ', currentEpoch.name, ' Epoch']);
        set(gca, 'FontSize', 8);
        
        print(hFig, fullfile(figuresFolder, 'Combined_FiringRate_Raster.png'), '-dpng', '-r300');
        set(hFig, 'Visible', 'on');
        savefig(hFig, fullfile(figuresFolder, 'Combined_FiringRate_Raster.fig'));
        close(hFig);
        
    catch ME
        fprintf('Error in section 6 (Combined Raster): %s\n', ME.message);
        fprintf('Stack trace:\n%s\n', getReport(ME));
    end
    
    try
        %% 7. Active Electrodes and Layer Summary
        % CREATE NEW FIGURE
        hFig = figure('Visible', 'off', 'Position', [100, 100, 1000, 800]);
        
        % Subplot 1: Active Electrodes Map
        subplot(2, 1, 1);
        activeThreshold = 0.1;
        activeMatrix = double(firingRateMatrix_Epoch > activeThreshold);
        
        imagesc(activeMatrix);
        colormap(gca, gray(2));
        cb = colorbar;
        cb.Ticks = [0 1];
        cb.TickLabels = {'Inactive', 'Active'};
        title(['Active Electrodes (Threshold: ', num2str(activeThreshold), ' Hz)']);
        xlabel('Electrode Column');
        ylabel('Electrode Row');
        xticks(1:length(columns));
        xticklabels(columns);
        yticks(1:length(rows));
        yticklabels(arrayfun(@num2str, rows, 'UniformOutput', false));
        set(gca, 'YDir', 'reverse');
        
        % Subplot 2: Layer Statistics Table
        subplot(2, 1, 2);
        axis off;
        
        layerNames = {'L1', 'L2/3', 'L4', 'L5/6', 'WM'};
        numLayers = length(layerNames);
        
        activeCount = zeros(numLayers, 1);
        meanFR_layer = zeros(numLayers, 1);
        maxFR_layer = zeros(numLayers, 1);
        totalElectrodes = zeros(numLayers, 1);
        
        for layer = 1:numLayers
            mask = (LayerDic == layer);
            totalElectrodes(layer) = sum(mask(:));
            layerFR = firingRateMatrix_Epoch(mask);
            
            validIdx = (layerFR > activeThreshold) & ~isnan(layerFR);
            layerFR_valid = layerFR(validIdx);
            
            activeCount(layer) = sum(validIdx);
            if ~isempty(layerFR_valid)
                meanFR_layer(layer) = mean(layerFR_valid);
                maxFR_layer(layer) = max(layerFR_valid);
            else
                meanFR_layer(layer) = NaN;
                maxFR_layer(layer) = NaN;
            end
        end
        
        summaryTable = table(layerNames', activeCount, totalElectrodes, ...
            meanFR_layer, maxFR_layer, ...
            'VariableNames', {'Layer', 'ActiveElectrodes', 'TotalElectrodes', ...
            'MeanFiringRate_Hz', 'MaxFiringRate_Hz'});
        
        % Display table as text
        tableCell = [summaryTable.Properties.VariableNames; table2cell(summaryTable)];
        tableText = cell(size(tableCell,1),1);
        for i = 1:size(tableCell,1)
            if i == 1
                tableText{i} = sprintf('%-8s | %-16s | %-16s | %-18s | %-18s', ...
                    tableCell{i,1}, tableCell{i,2}, tableCell{i,3}, tableCell{i,4}, tableCell{i,5});
            else
                tableText{i} = sprintf('%-8s | %-16d | %-16d | %-18.2f | %-18.2f', ...
                    tableCell{i,1}, tableCell{i,2}, tableCell{i,3}, tableCell{i,4}, tableCell{i,5});
            end
        end
        
        text(0.05, 0.5, strjoin(tableText, '\n'), ...
            'FontName', 'Courier New', 'FontSize', 9, 'VerticalAlignment', 'middle');
        title(sprintf('Layer-wise Summary (Threshold: %.2f Hz)', activeThreshold));
        
        print(hFig, fullfile(figuresFolder, 'Combined_Active_electrodes_and_Table.png'), '-dpng', '-r300');
        set(hFig, 'Visible', 'on');
        savefig(hFig, fullfile(figuresFolder, 'Combined_Active_electrodes_and_Table.fig'));
        close(hFig);
        
        % Save table to Excel
        writetable(summaryTable, fullfile(fileparts(figuresFolder), 'LayerWise_Summary.xlsx'));
        
    catch ME
        fprintf('Error in section 7 (Active Electrodes): %s\n', ME.message);
    end
    
    try
     %% 8. First Spike Latency - CORRECTED VERSION
% Use the eventOnsetTime parameter that's already passed to this function
onsetTime = eventOnsetTime;
firstSpikeLatencyMatrix = NaN(length(rows), length(columns));

fprintf('  Computing first spike latencies from onset: %.3f s\n', onsetTime);
numChannelsWithSpikes = 0;

for idx = 1:length(sortedChannels)
    channel = sortedChannels{idx};
    
    % Parse electrode name directly (same as firing rate section)
    tokens = regexp(channel, '^([A-Z]+)(\d+)$', 'tokens');
    if isempty(tokens)
        continue;
    end
    
    colLetter = tokens{1}{1};              % e.g., 'H'
    rowNumber = str2double(tokens{1}{2});  % e.g., 12
    
    % Find column index
    colIdx = find(strcmp(columns, colLetter));
    
    % Validate indices
    if isempty(colIdx) || isnan(rowNumber) || ...
       rowNumber < 1 || rowNumber > length(rows)
        continue;
    end
    
    % Extract spike times
    if isfield(epochSpikeData.(epochName), channel) && ...
       isfield(epochSpikeData.(epochName).(channel), 'times')
        
        spikeTimes = epochSpikeData.(epochName).(channel).times;
        
        % Find spikes AFTER the onset
        spikeAfterOnset = spikeTimes(spikeTimes >= onsetTime);
        
        if ~isempty(spikeAfterOnset)
            firstSpikeTime = spikeAfterOnset(1);
            latency = firstSpikeTime - onsetTime;
            
            % Only accept reasonable latencies
            if latency >= 0 && latency < 1.0
                % CORRECTED ASSIGNMENT: (row, column)
                firstSpikeLatencyMatrix(rowNumber, colIdx) = latency;
                numChannelsWithSpikes = numChannelsWithSpikes + 1;
            end
        end
    end
end

% Debug output
validLatencies = firstSpikeLatencyMatrix(~isnan(firstSpikeLatencyMatrix));
fprintf('  Channels with valid latencies: %d\n', numChannelsWithSpikes);

if ~isempty(validLatencies)
    fprintf('  Latency: min=%.1f ms, max=%.1f ms, mean=%.1f ms\n', ...
        min(validLatencies)*1000, max(validLatencies)*1000, mean(validLatencies)*1000);
else
    fprintf('  WARNING: NO VALID LATENCIES!\n');
end
        
        % CREATE NEW FIGURE
        hFig = figure('Visible', 'off', 'Position', [100, 100, 800, 700]);
        imagesc(firstSpikeLatencyMatrix);
        colormap(gca, 'jet');
        colorbar;
        xticks(1:length(columns));
        xticklabels(columns);
        yticks(1:length(rows));
        yticklabels(rows);
        xlabel('Electrode Column');
        ylabel('Electrode Row');
        title(['First Spike Latency After Onset at ', num2str(onsetTime, '%.2f'), ' s']);
        set(gca, 'YDir', 'reverse');
        print(hFig, fullfile(figuresFolder, 'Latency_of_Spikes.png'), '-dpng', '-r300');
        set(hFig, 'Visible', 'on');
        savefig(hFig, fullfile(figuresFolder, 'Latency_of_Spikes.fig'));
        close(hFig);
        
    catch ME
        fprintf('Error in section 8 (Latency): %s\n', ME.message);
    end
    
    try
        %% 9. Save Event Summary
        totalSpikes = sum(globalSpikeCounts);
        meanFRLayer = nan(5,1);
        
        for layer = 1:5
            mask = (LayerDic == layer);
            layerFRvalues = firingRateMatrix_Epoch(mask);
            meanFRLayer(layer) = mean(layerFRvalues,'omitnan');
        end
        
        eventSummary = table(eventNumber, totalSpikes, ...
            meanGlobalFiringRate, maxGlobalFiringRate, ...
            meanFRLayer(1), meanFRLayer(2), meanFRLayer(3), meanFRLayer(4), meanFRLayer(5), ...
            'VariableNames', {'Event', 'TotalSpikes', 'MeanGlobalFR_Hz', 'MaxGlobalFR_Hz', ...
            'FR_L1_Hz', 'FR_L23_Hz', 'FR_L4_Hz', 'FR_L56_Hz', 'FR_WM_Hz'});
        
        summaryFile = fullfile(fileparts(figuresFolder), sprintf('Event_Summary2_NetworkEvent_%d.xlsx', eventNumber));
        writetable(eventSummary, summaryFile);
        
    catch ME
        fprintf('Error in section 9 (Event Summary): %s\n', ME.message);
    end
end

function mergeEventSummaries(eventsFolder)
    % Merge all Event_Summary2_NetworkEvent_*.xlsx files
    
    parentFolder = eventsFolder;
    allItems = dir(parentFolder);
    isSubfolder = [allItems.isdir];
    subfolderNames = {allItems(isSubfolder).name};
    subfolderNames = subfolderNames(~ismember(subfolderNames, {'.', '..'}));
    
    T_merged = table();
    
    for i = 1:numel(subfolderNames)
        folderPath = fullfile(parentFolder, subfolderNames{i});
        xlsxFiles = dir(fullfile(folderPath, 'Event_Summary2_NetworkEvent_*.xlsx'));
        
        for f = 1:numel(xlsxFiles)
            filePath = fullfile(folderPath, xlsxFiles(f).name);
            T_temp = readtable(filePath);
            T_merged = [T_merged; T_temp];
        end
    end
    
    if ~isempty(T_merged)
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        outFileName = fullfile(parentFolder, ['Merged_Event_Summary_', timestamp, '.xlsx']);
        writetable(T_merged, outFileName);
        
        % Clean up old merged files
        oldFiles = dir(fullfile(parentFolder, 'Merged_Event_Summary_*.xlsx'));
        if length(oldFiles) > 1
            [~, sortIdx] = sort([oldFiles.datenum], 'descend');
            filesToDelete = oldFiles(sortIdx(2:end));
            
            for i = 1:length(filesToDelete)
                try
                    delete(fullfile(parentFolder, filesToDelete(i).name));
                catch
                end
            end
        end
    end
end

    function exportSpikeDataForLFP(~, ~)
    addStatus('Starting spike data export for LFP correlation...');
    
    % Get required data
    spikeData = getappdata(fig, 'spikeData');
    filteredChannelData = getappdata(fig, 'filteredChannelData');
    outputFolder = getappdata(fig, 'outputFolder');
    samplingRate = getappdata(fig, 'samplingRate');
    Time = getappdata(fig, 'Time');
    eventOnsets = getappdata(fig, 'eventOnsets');
    eventOffsets = getappdata(fig, 'eventOffsets');
    LayerDic = getappdata(fig, 'LayerDic');
    
    if isempty(spikeData) || isempty(filteredChannelData)
        addStatus('ERROR: Please run spike detection first');
        return;
    end
    
    if isempty(outputFolder)
        addStatus('ERROR: Please select output folder first');
        return;
    end
    
    % Create spike data folder
    spikeDataFolder = fullfile(outputFolder, 'Spike_Data_for_LFP');
    if ~exist(spikeDataFolder, 'dir')
        mkdir(spikeDataFolder);
    end
    
    % Configuration for spike snippets (matching LFP analysis)
    preTime = 0.002;   % 2 ms before spike
    postTime = 0.003;  % 3 ms after spike
    preSamples = round(preTime * samplingRate);
    postSamples = round(postTime * samplingRate);
    snippetLength = preSamples + postSamples + 1;
    
    % ========== PRE-ONSET WINDOW FOR INITIATOR ANALYSIS ==========
    preOnsetWindow = 0.100;  % 100ms before event onset - CRITICAL for true initiators
    
    addStatus(sprintf('Extracting snippets: %.1f ms pre, %.1f ms post spike', ...
        preTime*1000, postTime*1000));
    addStatus(sprintf('Pre-onset window for events: %.0f ms', preOnsetWindow*1000));
    
    % Get all channels
    sortedChannels = sort(fieldnames(spikeData));
    
    % Initialize master spike times table
    allSpikeTimes = table();
    
    % ========== Initialize event-based spike organization ==========
    if ~isempty(eventOnsets)
        addStatus(sprintf('Organizing spikes by %d network events (with %.0fms pre-onset)...', ...
            length(eventOnsets), preOnsetWindow*1000));
        eventSpikes = cell(length(eventOnsets), 1);
        
        for e = 1:length(eventOnsets)
            eventSpikes{e} = struct();
            eventSpikes{e}.eventNumber = e;
            eventSpikes{e}.startTime = eventOnsets(e);
            eventSpikes{e}.endTime = eventOffsets(e);
            eventSpikes{e}.channels = {};
        end
    else
        eventSpikes = {};
    end
    
    % ========== PROCESS EACH CHANNEL ==========
    totalSpikes = 0;
    
    for chIdx = 1:length(sortedChannels)
        channel = sortedChannels{chIdx};
        
        if ~isfield(spikeData, channel) || ~isfield(filteredChannelData, channel)
            continue;
        end
        
        spikeTimes = spikeData.(channel).times;
        numSpikes = length(spikeTimes);
        
        if numSpikes == 0
            continue;
        end
        
        totalSpikes = totalSpikes + numSpikes;
        
        % Convert spike times to sample indices
        spikeIndices = round((spikeTimes - Time(1)) * samplingRate) + 1;
        
        % Extract snippets
        snippets = zeros(numSpikes, snippetLength);
        validSpikes = true(numSpikes, 1);
        signal = filteredChannelData.(channel);
        
        for s = 1:numSpikes
            idx = spikeIndices(s);
            
            % Check boundaries
            if idx - preSamples < 1 || idx + postSamples > length(signal)
                validSpikes(s) = false;
                continue;
            end
            
            % Extract snippet
            snippets(s, :) = signal(idx - preSamples : idx + postSamples);
        end
        
        % Keep only valid spikes
        snippets = snippets(validSpikes, :);
        spikeTimes = spikeTimes(validSpikes);
        spikeIndices = spikeIndices(validSpikes);
        
        % ========== ASSIGN SPIKES TO EVENTS (WITH PRE-ONSET WINDOW) ==========
        if ~isempty(eventOnsets)
            for s = 1:length(spikeTimes)
                spikeTime = spikeTimes(s);
                
                % Find which event this spike belongs to
                for e = 1:length(eventOnsets)
                    % CRITICAL: Include spikes BEFORE onset (potential initiators)
                    % Spikes from (onset - preOnsetWindow) to eventOffset are included
                    if spikeTime >= (eventOnsets(e) - preOnsetWindow) && spikeTime <= eventOffsets(e)
                        
                        if ~isfield(eventSpikes{e}, channel)
                            eventSpikes{e}.(channel) = struct();
                            eventSpikes{e}.(channel).times = [];
                            eventSpikes{e}.(channel).indices = [];
                            eventSpikes{e}.(channel).snippets = [];
                            eventSpikes{e}.channels{end+1} = channel;
                        end
                        
                        eventSpikes{e}.(channel).times(end+1) = spikeTime;
                        eventSpikes{e}.(channel).indices(end+1) = spikeIndices(s);
                        eventSpikes{e}.(channel).snippets(end+1, :) = snippets(s, :);
                        break; % Spike assigned to this event, move to next spike
                    end
                end
            end
        end
        
        % Save snippets for this channel
        if ~isempty(snippets)
            snippetFile = fullfile(spikeDataFolder, sprintf('Snippets_%s.mat', channel));
            timeVector = (-preSamples:postSamples) / samplingRate * 1000; % in ms
            save(snippetFile, 'snippets', 'spikeTimes', 'spikeIndices', ...
                'timeVector', 'samplingRate', 'channel', '-v7.3');
        end
        
        % Add to master spike times table
        channelLabel = repmat({channel}, length(spikeTimes), 1);
        spikeNum = (1:length(spikeTimes))';
        channelTable = table(channelLabel, spikeNum, spikeTimes, spikeIndices, ...
            'VariableNames', {'Channel', 'Spike_Number', 'Time_s', 'Sample_Index'});
        allSpikeTimes = [allSpikeTimes; channelTable];
        
        if mod(chIdx, 20) == 0
            addStatus(sprintf('  Processed %d/%d channels...', chIdx, length(sortedChannels)));
        end
    end
    
    % ========== SAVE EVENT-BASED SPIKE DATA ==========
    if ~isempty(eventOnsets)
        addStatus('Saving event-based spike organization (with pre-onset window)...');
        save(fullfile(spikeDataFolder, 'Event_Spike_Data.mat'), ...
            'eventSpikes', 'eventOnsets', 'eventOffsets', 'preOnsetWindow', '-v7.3');
        
        % Create event summary
        createEventSpikeSummary(spikeDataFolder, eventSpikes);
    end
    
    % Save master spike times (.csv + .mat only — no Excel row limit issues)
    writetable(allSpikeTimes, fullfile(spikeDataFolder, 'All_Spike_Times.csv'));
    save(fullfile(spikeDataFolder, 'All_Spike_Times.mat'), 'allSpikeTimes', '-v7.3');
    addStatus(sprintf('  Saved All_Spike_Times.csv + .mat (%d spikes total)', height(allSpikeTimes)));
    
    % ========== Create propagation-compatible format ==========
    addStatus('Creating propagation-compatible format...');
    createSpikePropagationData(spikeDataFolder, spikeData, filteredChannelData, ...
        samplingRate, Time, LayerDic, eventOnsets, eventOffsets);
    
    % Create summary document
    createSpikeSummary(spikeDataFolder, sortedChannels, spikeData, ...
        samplingRate, preTime, postTime, totalSpikes);
    
    % Create example visualization
    createSpikeSnippetVisualization(spikeDataFolder, sortedChannels, ...
        spikeData, filteredChannelData, samplingRate, preSamples, postSamples);
    
    addStatus(sprintf('Export complete! Total spikes: %d', totalSpikes));
    addStatus(sprintf('Saved to: %s', spikeDataFolder));
    addStatus('Files created:');
    addStatus('  - All_Spike_Times.csv/mat (all spikes with timestamps)');
    addStatus('  - Snippets_[Channel].mat (waveform snippets per channel)');
    addStatus('  - Event_Spike_Data.mat (spikes organized by network events)');
    addStatus('  - Spike_Propagation_Data.mat (for comparison with LFP)');
    addStatus('  - Spike_Summary.txt (analysis summary)');
    addStatus('  - Example_Spike_Snippets.png (visualization)');
    end


% ========== NEW FUNCTION: Create propagation-compatible data ==========
function createSpikePropagationData(spikeDataFolder, spikeData, filteredChannelData, ...
    samplingRate, Time, LayerDic, eventOnsets, eventOffsets)
    % Create data structure compatible with LFP propagation analysis
    
    sortedChannels = sort(fieldnames(spikeData));
    
    % MEA configuration (matching LFP analysis)
    columns = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', ...
               'J', 'K', 'L', 'M', 'N', 'O', 'P', 'R'};
    rows = 1:16;
    electrodeSpacing = 0.2; % mm
    
    % Create electrode-to-layer map
    electrodeLayerMap = containers.Map();
    for r = 1:16
        for c = 1:16
            channelName = sprintf('%s%d', columns{c}, r);
            if LayerDic(r, c) > 0
                electrodeLayerMap(channelName) = LayerDic(r, c);
            end
        end
    end
    
    if isempty(eventOnsets)
        fprintf('  No events detected, skipping propagation data\n');
        return;
    end
    
    % Initialize spike propagation results (matching LFP format)
    spikePropagationResults = struct();
    
    for eventIdx = 1:length(eventOnsets)
        eventStart = eventOnsets(eventIdx);
        eventEnd = eventOffsets(eventIdx);
        
        % Create latency matrix (first spike after event onset)
        spikeLatencyMatrix = NaN(16, 16);
        spikePeakAmplitudeMatrix = NaN(16, 16);
        
        spikeInfo = struct('channel', {}, 'row', {}, 'col', {}, ...
            'latency', {}, 'amplitude', {});
        spikeCount = 0;
        
        for ch = 1:length(sortedChannels)
            channel = sortedChannels{ch};
            
            % Parse channel name
            tokens = regexp(channel, '^([A-Z]+)(\d+)$', 'tokens');
            if isempty(tokens), continue; end
            
            colLetter = tokens{1}{1};
            rowNumber = str2double(tokens{1}{2});
            colIdx = find(strcmp(columns, colLetter));
            
            if isempty(colIdx) || isnan(rowNumber), continue; end
            
            % Get spikes in this event
            spikeTimes = spikeData.(channel).times;
            spikeAmps = spikeData.(channel).amplitudes;
            
            eventSpikes = spikeTimes >= eventStart & spikeTimes <= eventEnd;
            eventSpikeTimes = spikeTimes(eventSpikes);
            eventSpikeAmps = spikeAmps(eventSpikes);
            
            if ~isempty(eventSpikeTimes)
                % First spike latency (relative to event onset)
                firstSpikeTime = eventSpikeTimes(1);
                latency = firstSpikeTime - eventStart;
                amplitude = eventSpikeAmps(1);
                
                spikeLatencyMatrix(rowNumber, colIdx) = latency;
                spikePeakAmplitudeMatrix(rowNumber, colIdx) = amplitude;
                
                spikeCount = spikeCount + 1;
                spikeInfo(spikeCount).channel = channel;
                spikeInfo(spikeCount).row = rowNumber;
                spikeInfo(spikeCount).col = colIdx;
                spikeInfo(spikeCount).latency = latency;
                spikeInfo(spikeCount).amplitude = amplitude;
            end
        end
        
        % Calculate wave direction and coherence (matching LFP function)
        [waveDirection, waveCoherence] = calculateWaveDirection(spikeLatencyMatrix);
        
        % Store results
        spikePropagationResults(eventIdx).eventNumber = eventIdx;
        spikePropagationResults(eventIdx).latencyMatrix = spikeLatencyMatrix;
        spikePropagationResults(eventIdx).amplitudeMatrix = spikePeakAmplitudeMatrix;
        spikePropagationResults(eventIdx).waveDirection = waveDirection;
        spikePropagationResults(eventIdx).waveCoherence = waveCoherence;
        spikePropagationResults(eventIdx).numActiveElectrodes = spikeCount;
        spikePropagationResults(eventIdx).electrodeInfo = spikeInfo;
        spikePropagationResults(eventIdx).eventStartTime = eventStart;
        spikePropagationResults(eventIdx).eventEndTime = eventEnd;
    end
    
    % Save
    save(fullfile(spikeDataFolder, 'Spike_Propagation_Data.mat'), ...
        'spikePropagationResults', 'electrodeLayerMap', 'electrodeSpacing', ...
        'columns', 'rows', 'samplingRate', '-v7.3');
    
    fprintf('  ✓ Spike propagation data saved\n');
end

% ========== NEW FUNCTION: Event spike summary ==========
function createEventSpikeSummary(spikeDataFolder, eventSpikes)
    % Create summary of spikes per event
    
    summaryFile = fullfile(spikeDataFolder, 'Event_Spike_Summary.txt');
    fid = fopen(summaryFile, 'w');
    
    fprintf(fid, '=========================================\n');
    fprintf(fid, 'SPIKE ORGANIZATION BY NETWORK EVENTS\n');
    fprintf(fid, '=========================================\n\n');
    fprintf(fid, 'Export Date: %s\n\n', datestr(now));
    
    fprintf(fid, 'EVENT SUMMARY:\n');
    fprintf(fid, '%-10s %-15s %-15s %-15s %-15s\n', ...
        'Event', 'Start (s)', 'End (s)', 'Duration (s)', 'Num Spikes');
    fprintf(fid, '%-10s %-15s %-15s %-15s %-15s\n', ...
        '-----', '----------', '--------', '------------', '----------');
    
    for e = 1:length(eventSpikes)
        event = eventSpikes{e};
        
        % Count total spikes in this event
        totalSpikes = 0;
        for ch = 1:length(event.channels)
            channel = event.channels{ch};
            if isfield(event, channel)
                totalSpikes = totalSpikes + length(event.(channel).times);
            end
        end
        
        fprintf(fid, '%-10d %-15.3f %-15.3f %-15.3f %-15d\n', ...
            event.eventNumber, event.startTime, event.endTime, ...
            event.endTime - event.startTime, totalSpikes);
    end
    
    fprintf(fid, '\nUSAGE:\n');
    fprintf(fid, '  Load Event_Spike_Data.mat to access event-organized spikes\n');
    fprintf(fid, '  Each event contains spike times and snippets per channel\n\n');
    fprintf(fid, '  Example MATLAB code:\n');
    fprintf(fid, '    load(''Event_Spike_Data.mat'');\n');
    fprintf(fid, '    event1 = eventSpikes{1};\n');
    fprintf(fid, '    channelC15_spikes = event1.C15.times;\n');
    fprintf(fid, '    channelC15_snippets = event1.C15.snippets;\n\n');
    
    fprintf(fid, '=========================================\n');
    fclose(fid);
end

    %% ========== AUTOMATIC MULTI-NETWORK DETECTION ==========
    % This new function automatically identifies networks without manual input
    
    function autoMultiNetworkDetection(~, ~)
        % AUTOMATIC MULTI-NETWORK DETECTION - IMPROVED VERSION
        % This function automatically identifies multiple networks based on spatial clustering
        % of firing rate patterns across the MEA
        
        addStatus('Starting AUTOMATIC Multi-Network Detection (Improved)...');
        
        % Check required data
        outputFolder = getappdata(fig, 'outputFolder');
        spikeData = getappdata(fig, 'spikeData');
        eventOnsets = getappdata(fig, 'eventOnsets');
        eventOffsets = getappdata(fig, 'eventOffsets');
        LayerDic = getappdata(fig, 'LayerDic');
        samplingRate = getappdata(fig, 'samplingRate');
        Time = getappdata(fig, 'Time');
        
        if isempty(spikeData) || isempty(eventOnsets) || isempty(LayerDic)
            addStatus('ERROR: Please complete spike detection, event detection, and load layer dictionary first');
            return;
        end
        
        sortedChannels = sort(fieldnames(spikeData));
        
        %% Step 1: For each event, compute firing rate heatmap
        addStatus('Analyzing spatial patterns for each event...');
        
        numEvents = length(eventOnsets);
        addStatus(sprintf('Processing %d events total', numEvents));
        
        rows = {'1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16'};
        columns = {'A','B','C','D','E','F','G','H','J','K','L','M','N','O','P','R'};
        
        % Store firing rate matrices for each event
        eventFiringRates = zeros(16, 16, numEvents);
        eventPeakFR = zeros(numEvents, 1);
        eventTotalSpikes = zeros(numEvents, 1);
        
        for eventIdx = 1:numEvents
            frMatrix = zeros(16, 16);  % Changed from NaN to 0
            
            eventStart = eventOnsets(eventIdx);
            eventEnd = eventOffsets(eventIdx);
            eventDuration = eventEnd - eventStart;
            
            if eventDuration <= 0
                eventDuration = 0.001;  % Prevent division by zero
            end
            
            % Calculate firing rate for each channel during this event
            totalSpikes = 0;
            maxFR = 0;
            
            for ch = 1:length(sortedChannels)
                channel = sortedChannels{ch};
                
                % Parse electrode position
                tokens = regexp(channel, '^([A-Z]+)(\d+)$', 'tokens');
                if isempty(tokens), continue; end
                
                colLetter = tokens{1}{1};
                rowNumber = str2double(tokens{1}{2});
                
                colIdx = find(strcmp(columns, colLetter));
                if isempty(colIdx) || rowNumber < 1 || rowNumber > 16
                    continue;
                end
                
                % Get spike times in this event
                spikeTimes = spikeData.(channel).times;
                spikesInEvent = spikeTimes(spikeTimes >= eventStart & spikeTimes <= eventEnd);
                numSpikes = length(spikesInEvent);
                firingRate = numSpikes / eventDuration;
                
                frMatrix(rowNumber, colIdx) = firingRate;
                totalSpikes = totalSpikes + numSpikes;
                maxFR = max(maxFR, firingRate);
            end
            
            eventFiringRates(:,:,eventIdx) = frMatrix;
            eventPeakFR(eventIdx) = maxFR;
            eventTotalSpikes(eventIdx) = totalSpikes;
        end
        
        addStatus(sprintf('Event stats: Peak FR range = %.1f-%.1f Hz, Total spikes range = %d-%d', ...
            min(eventPeakFR), max(eventPeakFR), min(eventTotalSpikes), max(eventTotalSpikes)));
        
        %% Step 2: Cluster events by spatial pattern similarity
        addStatus('Clustering events by spatial patterns...');
        
        % Flatten each event's firing rate matrix into a vector
        eventVectors = zeros(numEvents, 16*16);
        for eventIdx = 1:numEvents
            frMat = eventFiringRates(:,:,eventIdx);
            eventVectors(eventIdx, :) = frMat(:)';
        end
        
        % Check if we have any activity
        nonZeroEvents = sum(eventVectors, 2) > 0;
        numActiveEvents = sum(nonZeroEvents);
        
        if numActiveEvents < numEvents
            addStatus(sprintf('Warning: %d events have no spike activity', numEvents - numActiveEvents));
        end
        
        % Normalize each vector
        for eventIdx = 1:numEvents
            vecNorm = norm(eventVectors(eventIdx, :));
            if vecNorm > 0
                eventVectors(eventIdx, :) = eventVectors(eventIdx, :) / vecNorm;
            end
        end
        
        % Compute similarity matrix (correlation)
        similarityMatrix = eventVectors * eventVectors';
        
        % Convert to distance
        distanceMatrix = 1 - abs(similarityMatrix);
        distanceMatrix(distanceMatrix < 0) = 0;
        
        % Report similarity statistics
        upperTri = triu(similarityMatrix, 1);
        similarities = upperTri(upperTri ~= 0);
        if ~isempty(similarities)
            addStatus(sprintf('Event similarity: mean=%.3f, min=%.3f, max=%.3f', ...
                mean(similarities), min(similarities), max(similarities)));
        end
        
        % Use hierarchical clustering
        try
            Z = linkage(squareform(distanceMatrix), 'average');
            
            % Automatically determine number of clusters (try 2-5)
            maxClusters = min(5, numEvents);
            bestK = 1;  % Default to 1 network
            
            if numEvents >= 3  % Lowered from 4 to 3
                silhouetteScores = zeros(maxClusters - 1, 1);
                for k = 2:maxClusters
                    try
                        clusterLabels = cluster(Z, 'maxclust', k);
                        silhouetteScores(k-1) = mean(silhouette(eventVectors, clusterLabels, 'euclidean'));
                    catch
                        silhouetteScores(k-1) = -1;  % Invalid clustering
                    end
                end
                
                addStatus(sprintf('Silhouette scores for k=2:%d: %s', maxClusters, ...
                    mat2str(silhouetteScores', 3)));
                
                % Use multiple approaches to determine best k
                [maxScore, maxScoreIdx] = max(silhouetteScores);
                
                % Approach 1: Use silhouette with LOWERED threshold
                if maxScore > 0.15  % Lowered from 0.2 to 0.15
                    bestK = maxScoreIdx + 1;
                    addStatus(sprintf('Selected k=%d networks via silhouette (score=%.3f)', bestK, maxScore));
                    
                % Approach 2: If silhouette is inconclusive, try dendrogram inconsistency
                elseif numEvents >= 4
                    try
                        inconsistency = inconsistent(Z);
                        % Look for large jumps in inconsistency (suggests natural clusters)
                        avgIncon = inconsistency(:,4);  % 4th column is inconsistency coefficient
                        
                        % Try k=2 if there's a reasonable dendrogram structure
                        if max(avgIncon) > 1.5
                            bestK = 2;
                            addStatus(sprintf('Selected k=2 networks via dendrogram inconsistency (max=%.3f)', max(avgIncon)));
                        else
                            bestK = 1;
                            addStatus('Using single network (no clear cluster structure).');
                        end
                    catch
                        bestK = 1;
                        addStatus('Using single network (dendrogram analysis failed).');
                    end
                    
                % Approach 3: For very small datasets, check max dissimilarity
                else
                    % If at least 2 events are very dissimilar, split into 2 networks
                    if min(similarities) < 0.5 && numEvents >= 3
                        bestK = 2;
                        addStatus(sprintf('Selected k=2 networks (min similarity=%.3f suggests distinct patterns)', min(similarities)));
                    else
                        bestK = 1;
                        addStatus(sprintf('Using single network (events too similar: min similarity=%.3f)', min(similarities)));
                    end
                end
            else
                % For 2 events, check if they're dissimilar
                if numEvents == 2 && similarities(1) < 0.7
                    bestK = 2;
                    addStatus(sprintf('Selected k=2 networks (2 events with low similarity=%.3f)', similarities(1)));
                else
                    bestK = 1;
                    addStatus('Too few events for meaningful clustering. Using single network.');
                end
            end
            
            clusterLabels = cluster(Z, 'maxclust', bestK);
            
            addStatus(sprintf('Identified %d distinct network pattern(s)', bestK));
            
        catch ME
            addStatus(sprintf('Clustering failed: %s. Using single network.', ME.message));
            clusterLabels = ones(numEvents, 1);
            bestK = 1;
        end
        
        %% Step 3: Identify representative channels for each network
        addStatus('Identifying representative channels for each network...');
        
        networkRepChannels = cell(bestK, 1);
        networkResults = struct();
        
        for netIdx = 1:bestK
            % Get events in this cluster
            eventsInNetwork = find(clusterLabels == netIdx);
            
            addStatus(sprintf('Network %d: Processing %d events', netIdx, length(eventsInNetwork)));
            
            % Average firing rate pattern across these events
            avgFiringPattern = mean(eventFiringRates(:,:,eventsInNetwork), 3);
            
            % Find channels with highest activity in this pattern
            [sortedFR, sortIdx] = sort(avgFiringPattern(:), 'descend');
            
            % Get top channels with non-zero activity
            topChannels = {};
            for i = 1:length(sortIdx)
                if sortedFR(i) <= 0 || isnan(sortedFR(i))
                    break;  % No more active channels
                end
                
                if length(topChannels) >= 5  % Limit to top 5
                    break;
                end
                
                [rowIdx, colIdx] = ind2sub([16, 16], sortIdx(i));
                channelName = [columns{colIdx}, rows{rowIdx}];
                
                if isfield(spikeData, channelName)
                    topChannels{end+1} = channelName;
                    addStatus(sprintf('  Top channel: %s (FR=%.1f Hz)', channelName, sortedFR(i)));
                end
            end
            
            if isempty(topChannels)
                addStatus(sprintf('  WARNING: No active channels found for Network %d', netIdx));
            end
            
            networkRepChannels{netIdx} = topChannels;
            
            % Store network info
            networkResults(netIdx).networkID = netIdx;
            networkResults(netIdx).numEvents = length(eventsInNetwork);
            networkResults(netIdx).eventIndices = eventsInNetwork;
            networkResults(netIdx).eventOnsets = eventOnsets(eventsInNetwork);
            networkResults(netIdx).eventOffsets = eventOffsets(eventsInNetwork);
            networkResults(netIdx).representativeChannels = topChannels;
            networkResults(netIdx).avgFiringPattern = avgFiringPattern;
            
            addStatus(sprintf('  Network %d: %d events, Rep. channels: %s', ...
                netIdx, length(eventsInNetwork), strjoin(topChannels, ', ')));
        end
        
        %% Step 4: Save results
        addStatus('Saving results...');
        
        multiNetworkFolder = fullfile(outputFolder, 'AutoMultiNetwork_Analysis');
        if ~exist(multiNetworkFolder, 'dir')
            mkdir(multiNetworkFolder);
        end
        
        figuresFolder = fullfile(multiNetworkFolder, 'figures');
        if ~exist(figuresFolder, 'dir')
            mkdir(figuresFolder);
        end
        
        % Save summary
        fileID = fopen(fullfile(multiNetworkFolder, 'Network_Summary.txt'), 'w');
        fprintf(fileID, 'Automatic Multi-Network Detection Results\n');
        fprintf(fileID, '==========================================\n\n');
        fprintf(fileID, 'Total Events: %d\n', numEvents);
        fprintf(fileID, 'Networks Identified: %d\n\n', bestK);
        
        % Add clustering diagnostics
        if ~isempty(similarities)
            fprintf(fileID, 'Clustering Diagnostics:\n');
            fprintf(fileID, '  Event Similarity: mean=%.3f, min=%.3f, max=%.3f\n', ...
                mean(similarities), min(similarities), max(similarities));
            if exist('maxScore', 'var')
                fprintf(fileID, '  Best Silhouette Score: %.3f (for k=%d)\n', maxScore, maxScoreIdx+1);
            end
            fprintf(fileID, '\n');
        end
        
        for netIdx = 1:bestK
            fprintf(fileID, 'Network %d:\n', netIdx);
            fprintf(fileID, '  Events: %d\n', networkResults(netIdx).numEvents);
            fprintf(fileID, '  Representative Channels: %s\n', ...
                strjoin(networkResults(netIdx).representativeChannels, ', '));
            fprintf(fileID, '  Event indices: %s\n', mat2str(networkResults(netIdx).eventIndices));
            fprintf(fileID, '\n');
        end
        fclose(fileID);
        
        % Create merged events table
        allEvents = table();
        for netIdx = 1:bestK
            netOnsets = networkResults(netIdx).eventOnsets;
            netOffsets = networkResults(netIdx).eventOffsets;
            n = length(netOnsets);
            
            netTable = table((1:n)', netOnsets(:), netOffsets(:), ...
                netOffsets(:) - netOnsets(:), repmat(netIdx, n, 1), ...
                'VariableNames', {'Event_Number', 'Start_Time_s', 'End_Time_s', ...
                'Duration_s', 'Network_ID'});
            
            allEvents = [allEvents; netTable];
        end
        
        % Sort by time
        [~, sortIdx] = sort(allEvents.Start_Time_s);
        allEvents = allEvents(sortIdx, :);
        allEvents.Event_Number = (1:height(allEvents))';
        
        writetable(allEvents, fullfile(multiNetworkFolder, 'All_Network_Events.xlsx'));
        
        %% Step 5: Create visualizations
        addStatus('Creating visualizations...');
        
        try
            % Figure 0: Similarity Matrix (DIAGNOSTIC)
            if numEvents > 1
                hFig0 = figure('Visible', 'off', 'Position', [100, 100, 600, 500]);
                imagesc(similarityMatrix);
                colormap('jet');
                cb = colorbar;
                ylabel(cb, 'Similarity');
                caxis([0, 1]);
                
                xlabel('Event Number');
                ylabel('Event Number');
                title('Event Similarity Matrix (Spatial Pattern Correlation)');
                
                % Add text labels
                for i = 1:numEvents
                    for j = 1:numEvents
                        text(j, i, sprintf('%.2f', similarityMatrix(i,j)), ...
                            'HorizontalAlignment', 'center', ...
                            'Color', 'white', 'FontSize', 10);
                    end
                end
                
                % Add cluster boundaries if multiple clusters
                if bestK > 1
                    hold on;
                    for k = 1:bestK
                        eventsInCluster = find(clusterLabels == k);
                        if length(eventsInCluster) > 1
                            minIdx = min(eventsInCluster);
                            maxIdx = max(eventsInCluster);
                            rectangle('Position', [minIdx-0.5, minIdx-0.5, ...
                                maxIdx-minIdx+1, maxIdx-minIdx+1], ...
                                'EdgeColor', 'white', 'LineWidth', 2);
                        end
                    end
                    hold off;
                end
                
                timestamp = datestr(now, 'yyyymmdd_HHMMSS');
                print(hFig0, fullfile(figuresFolder, ['Similarity_Matrix_', timestamp]), '-dpng', '-r300');
                set(hFig0, 'Visible', 'on');
                savefig(hFig0, fullfile(figuresFolder, ['Similarity_Matrix_', timestamp, '.fig']));
                close(hFig0);
            end
            
            % Figure 1: Average firing patterns for each network
            hFig1 = figure('Visible', 'off', 'Position', [100, 100, 1400, 400*bestK]);
            
            for netIdx = 1:bestK
                subplot(bestK, 1, netIdx);
                avgPattern = networkResults(netIdx).avgFiringPattern;
                imagesc(avgPattern);
                colormap(gca, 'jet');
                cb = colorbar;
                ylabel(cb, 'Firing Rate (Hz)');
                
                xticks(1:16);
                xticklabels(columns);
                yticks(1:16);
                yticklabels(rows);
                xlabel('Electrode Column');
                ylabel('Electrode Row');
                title(sprintf('Network %d - Average Firing Pattern (%d events, Channels: %s)', ...
                    netIdx, networkResults(netIdx).numEvents, ...
                    strjoin(networkResults(netIdx).representativeChannels(1:min(3,end)), ',')));
                set(gca, 'YDir', 'reverse');
                caxis([0 max(avgPattern(:))*1.1]);
            end
            
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            print(hFig1, fullfile(figuresFolder, ['Network_Patterns_', timestamp]), '-dpng', '-r300');
            set(hFig1, 'Visible', 'on');
            savefig(hFig1, fullfile(figuresFolder, ['Network_Patterns_', timestamp, '.fig']));
            close(hFig1);
            
            % Figure 2: Timeline with network-coded events
            hFig2 = figure('Visible', 'off', 'Position', [100, 100, 1400, 600]);
            
            % Get population firing rate data
            timeCenters = getappdata(fig, 'timeCenters');
            populationFiringRate = getappdata(fig, 'populationFiringRate');
            thresholdFR = getappdata(fig, 'thresholdFR');
            
            plot(timeCenters, populationFiringRate, 'k-', 'LineWidth', 1);
            hold on;
            yline(thresholdFR, 'r--', 'Threshold', 'LineWidth', 1);
            
            % Color-code events by network
            networkColors = lines(bestK);
            
            for netIdx = 1:bestK
                netOnsets = networkResults(netIdx).eventOnsets;
                for e = 1:length(netOnsets)
                    xline(netOnsets(e), '--', 'Color', networkColors(netIdx, :), ...
                        'LineWidth', 2, 'Alpha', 0.7);
                end
            end
            
            xlabel('Time (s)');
            ylabel('Population Firing Rate (Hz)');
            title(sprintf('Automatic Multi-Network Detection (%d networks)', bestK));
            
            legendEntries = {'Pop. FR', 'Threshold'};
            for netIdx = 1:bestK
                topChan = networkResults(netIdx).representativeChannels;
                if ~isempty(topChan)
                    legendEntries{end+1} = sprintf('Network %d (%s)', netIdx, topChan{1});
                else
                    legendEntries{end+1} = sprintf('Network %d ()', netIdx);
                end
            end
            legend(legendEntries, 'Location', 'best');
            grid on;
            hold off;
            
            print(hFig2, fullfile(figuresFolder, ['Timeline_MultiNetwork_', timestamp]), '-dpng', '-r300');
            set(hFig2, 'Visible', 'on');
            savefig(hFig2, fullfile(figuresFolder, ['Timeline_MultiNetwork_', timestamp, '.fig']));
            close(hFig2);
            
        catch ME
            addStatus(sprintf('Warning: Visualization error: %s', ME.message));
        end
        
        % Store results in appdata
        setappdata(fig, 'autoNetworkResults', networkResults);
        setappdata(fig, 'networkClusterLabels', clusterLabels);
        
        addStatus('Automatic multi-network detection complete!');
        addStatus(sprintf('Results saved to: %s', multiNetworkFolder));
    end
    
    % ==================== HFO DETECTION ====================
    
    function analyzeHFO(~, ~)
        % High Frequency Oscillation (HFO) Detection
        % Detects Ripples (80-250 Hz) and Fast Ripples (250-500 Hz)
        
        addStatus('========================================');
        addStatus('Starting HFO Detection...');
        addStatus('========================================');
        
        % Check for required data
        filteredChannelData = getappdata(fig, 'filteredChannelData');
        channelLabels = getappdata(fig, 'channelLabels');
        samplingRate = getappdata(fig, 'samplingRate');
        outputFolder = getappdata(fig, 'outputFolder');
        
        if isempty(filteredChannelData)
            addStatus('ERROR: Please load H5 data first');
            return;
        end
        
        if isempty(outputFolder)
            addStatus('ERROR: Please select output folder first');
            return;
        end
        
        % Check if sampling rate is sufficient for HFO detection
        if samplingRate < 2000
            addStatus('WARNING: Sampling rate may be too low for reliable HFO detection');
            addStatus(sprintf('Current: %d Hz, Recommended: >= 2000 Hz', samplingRate));
        end
        
        % Get analysis parameters
        prompt = {
            'Ripple Band - Low Frequency (Hz):', ...
            'Ripple Band - High Frequency (Hz):', ...
            'Fast Ripple Band - Low Frequency (Hz):', ...
            'Fast Ripple Band - High Frequency (Hz):', ...
            'Detection Threshold (SD above baseline):', ...
            'Minimum Event Duration (ms):', ...
            'Maximum Event Duration (ms):', ...
            'Minimum Oscillations per Event:', ...
            'Analyze which bands? (1=Ripples, 2=FastRipples, 3=Both):', ...
            'Remove Line Noise? (1=Yes, 0=No):', ...
            'Line Frequency (50=Europe, 60=US):'
        };
        dlgtitle = 'HFO Detection Parameters';
        dims = [1 60];
        definput = {'80', '250', '250', '500', '4', '10', '200', '4', '3', '1', '50'};
        
        answer = inputdlg(prompt, dlgtitle, dims, definput);
        
        if isempty(answer)
            addStatus('HFO detection cancelled');
            return;
        end
        
        % Parse parameters
        params = struct();
        params.rippleLow = str2double(answer{1});
        params.rippleHigh = str2double(answer{2});
        params.fastRippleLow = str2double(answer{3});
        params.fastRippleHigh = str2double(answer{4});
        params.threshold = str2double(answer{5});
        params.minDuration = str2double(answer{6}) / 1000;  % Convert to seconds
        params.maxDuration = str2double(answer{7}) / 1000;
        params.minOscillations = str2double(answer{8});
        params.bandChoice = str2double(answer{9});
        params.removeLineNoise = str2double(answer{10});
        params.lineFreq = str2double(answer{11});
        
        % Validate parameters
        nyquist = samplingRate / 2;
        if params.rippleHigh >= nyquist || params.fastRippleHigh >= nyquist
            addStatus(sprintf('ERROR: Filter frequencies must be below Nyquist frequency (%.0f Hz)', nyquist));
            return;
        end
        
        addStatus('HFO Detection Parameters:');
        if params.bandChoice == 1 || params.bandChoice == 3
            addStatus(sprintf('  Ripple band: %.0f-%.0f Hz', params.rippleLow, params.rippleHigh));
        end
        if params.bandChoice == 2 || params.bandChoice == 3
            addStatus(sprintf('  Fast Ripple band: %.0f-%.0f Hz', params.fastRippleLow, params.fastRippleHigh));
        end
        addStatus(sprintf('  Detection threshold: %.1f SD', params.threshold));
        addStatus(sprintf('  Duration: %.0f-%.0f ms', params.minDuration*1000, params.maxDuration*1000));
        addStatus(sprintf('  Min oscillations: %d', params.minOscillations));
        
        % Line noise removal preprocessing
        if params.removeLineNoise
            addStatus(sprintf('  Line noise removal: ENABLED (%d Hz + harmonics)', params.lineFreq));
            addStatus('Removing line noise from all channels...');
            
            % Only remove harmonics that fall within HFO frequency bands
            % Ripples: 80-250 Hz, Fast Ripples: 250-500 Hz
            % So we only need harmonics from ~80 Hz to ~500 Hz
            minFreqNeeded = min(params.rippleLow, params.fastRippleLow) - 20;  % 60 Hz
            maxFreqNeeded = max(params.rippleHigh, params.fastRippleHigh) + 20;  % 520 Hz
            
            % Calculate relevant harmonics only
            allHarmonics = params.lineFreq * (1:20);  % Max 20 harmonics
            harmonics = allHarmonics(allHarmonics >= minFreqNeeded & allHarmonics <= maxFreqNeeded);
            
            % Also ensure below Nyquist
            harmonics = harmonics(harmonics < (nyquist - 5));
            
            addStatus(sprintf('  Removing %d harmonics in HFO range: %s Hz', length(harmonics), mat2str(harmonics)));
            
            channelNamesClean = fieldnames(filteredChannelData);
            cleanedChannelData = struct();
            
            % Pre-compute filter coefficients (much faster!)
            notchWidth = 2;  % Hz bandwidth
            filterCoeffs = cell(length(harmonics), 1);
            for h = 1:length(harmonics)
                freq = harmonics(h);
                wo = freq / nyquist;
                bw = notchWidth / nyquist;
                try
                    [b, a] = iirnotch(wo, bw);
                    filterCoeffs{h} = struct('b', b, 'a', a);
                catch
                    filterCoeffs{h} = [];
                end
            end
            
            for chClean = 1:length(channelNamesClean)
                chName = channelNamesClean{chClean};
                signal = filteredChannelData.(chName);
                
                % Apply pre-computed notch filters
                cleanedSignal = signal;
                for h = 1:length(filterCoeffs)
                    if ~isempty(filterCoeffs{h})
                        cleanedSignal = filtfilt(filterCoeffs{h}.b, filterCoeffs{h}.a, cleanedSignal);
                    end
                end
                
                cleanedChannelData.(chName) = cleanedSignal;
                
                if mod(chClean, 50) == 0
                    addStatus(sprintf('  Cleaned channel %d/%d', chClean, length(channelNamesClean)));
                end
            end
            
            % Use cleaned data for HFO detection
            hfoInputData = cleanedChannelData;
            addStatus('Line noise removal complete!');
        else
            addStatus('  Line noise removal: DISABLED');
            hfoInputData = filteredChannelData;
        end
        
        % Create output folder for HFO results
        hfoFolder = fullfile(outputFolder, 'HFO_Analysis');
        if ~exist(hfoFolder, 'dir')
            mkdir(hfoFolder);
        end
        
        % Initialize results storage
        channelNames = fieldnames(hfoInputData);
        numChannels = length(channelNames);
        
        rippleResults = struct();
        fastRippleResults = struct();
        
        % Progress tracking
        addStatus(sprintf('Analyzing %d channels for HFOs...', numChannels));
        
        % Process each channel
        for ch = 1:numChannels
            channelName = channelNames{ch};
            signal = hfoInputData.(channelName);
            
            if mod(ch, 50) == 0
                addStatus(sprintf('  Processing channel %d/%d...', ch, numChannels));
            end
            
            % Detect Ripples
            if params.bandChoice == 1 || params.bandChoice == 3
                rippleEvents = detectHFOEvents(signal, samplingRate, ...
                    params.rippleLow, params.rippleHigh, params.threshold, ...
                    params.minDuration, params.maxDuration, params.minOscillations);
                rippleResults.(channelName) = rippleEvents;
            end
            
            % Detect Fast Ripples
            if params.bandChoice == 2 || params.bandChoice == 3
                fastRippleEvents = detectHFOEvents(signal, samplingRate, ...
                    params.fastRippleLow, params.fastRippleHigh, params.threshold, ...
                    params.minDuration, params.maxDuration, params.minOscillations);
                fastRippleResults.(channelName) = fastRippleEvents;
            end
        end
        
        % Compile summary statistics
        addStatus('Compiling results...');
        
        Time = getappdata(fig, 'Time');
        recordingDuration = (Time(end) - Time(1)) / 60;  % Minutes
        
        % Pre-allocate arrays for table
        channelList = cell(numChannels, 1);
        
        if params.bandChoice == 1 || params.bandChoice == 3
            ripple_Count = zeros(numChannels, 1);
            ripple_Rate = zeros(numChannels, 1);
            ripple_MeanDuration = NaN(numChannels, 1);
            ripple_MeanAmplitude = NaN(numChannels, 1);
        end
        
        if params.bandChoice == 2 || params.bandChoice == 3
            fastRipple_Count = zeros(numChannels, 1);
            fastRipple_Rate = zeros(numChannels, 1);
            fastRipple_MeanDuration = NaN(numChannels, 1);
            fastRipple_MeanAmplitude = NaN(numChannels, 1);
        end
        
        for ch = 1:numChannels
            channelName = channelNames{ch};
            channelList{ch} = channelName;
            
            % Ripple stats
            if params.bandChoice == 1 || params.bandChoice == 3
                events = rippleResults.(channelName);
                ripple_Count(ch) = length(events);
                ripple_Rate(ch) = length(events) / recordingDuration;  % events/min
                if ~isempty(events)
                    ripple_MeanDuration(ch) = mean([events.duration]) * 1000;
                    ripple_MeanAmplitude(ch) = mean([events.amplitude]);
                end
            end
            
            % Fast Ripple stats
            if params.bandChoice == 2 || params.bandChoice == 3
                events = fastRippleResults.(channelName);
                fastRipple_Count(ch) = length(events);
                fastRipple_Rate(ch) = length(events) / recordingDuration;
                if ~isempty(events)
                    fastRipple_MeanDuration(ch) = mean([events.duration]) * 1000;
                    fastRipple_MeanAmplitude(ch) = mean([events.amplitude]);
                end
            end
        end
        
        % Build summary table based on band choice
        if params.bandChoice == 1  % Ripples only
            summaryTable = table(channelList, ripple_Count, ripple_Rate, ...
                                 ripple_MeanDuration, ripple_MeanAmplitude, ...
                                 'VariableNames', {'Channel', 'Ripple_Count', 'Ripple_Rate', ...
                                                   'Ripple_MeanDuration_ms', 'Ripple_MeanAmplitude_uV'});
        elseif params.bandChoice == 2  % Fast Ripples only
            summaryTable = table(channelList, fastRipple_Count, fastRipple_Rate, ...
                                 fastRipple_MeanDuration, fastRipple_MeanAmplitude, ...
                                 'VariableNames', {'Channel', 'FastRipple_Count', 'FastRipple_Rate', ...
                                                   'FastRipple_MeanDuration_ms', 'FastRipple_MeanAmplitude_uV'});
        else  % Both
            summaryTable = table(channelList, ripple_Count, ripple_Rate, ...
                                 ripple_MeanDuration, ripple_MeanAmplitude, ...
                                 fastRipple_Count, fastRipple_Rate, ...
                                 fastRipple_MeanDuration, fastRipple_MeanAmplitude, ...
                                 'VariableNames', {'Channel', 'Ripple_Count', 'Ripple_Rate', ...
                                                   'Ripple_MeanDuration_ms', 'Ripple_MeanAmplitude_uV', ...
                                                   'FastRipple_Count', 'FastRipple_Rate', ...
                                                   'FastRipple_MeanDuration_ms', 'FastRipple_MeanAmplitude_uV'});
        end
        
        % Save results to Excel
        excelPath = fullfile(hfoFolder, 'HFO_Summary.xlsx');
        writetable(summaryTable, excelPath, 'Sheet', 'Channel_Summary');
        addStatus(sprintf('Summary saved to: %s', excelPath));
        
        % Calculate overall statistics
        addStatus('');
        addStatus('===== HFO Detection Summary =====');
        addStatus(sprintf('Recording duration: %.2f minutes', recordingDuration));
        
        if params.bandChoice == 1 || params.bandChoice == 3
            totalRipples = sum(summaryTable.Ripple_Count);
            channelsWithRipples = sum(summaryTable.Ripple_Count > 0);
            avgRippleRate = mean(summaryTable.Ripple_Rate(summaryTable.Ripple_Count > 0));
            addStatus(sprintf('RIPPLES (%.0f-%.0f Hz):', params.rippleLow, params.rippleHigh));
            addStatus(sprintf('  Total events: %d', totalRipples));
            addStatus(sprintf('  Channels with ripples: %d/%d', channelsWithRipples, numChannels));
            if ~isnan(avgRippleRate)
                addStatus(sprintf('  Avg rate (active channels): %.2f events/min', avgRippleRate));
            end
        end
        
        if params.bandChoice == 2 || params.bandChoice == 3
            totalFR = sum(summaryTable.FastRipple_Count);
            channelsWithFR = sum(summaryTable.FastRipple_Count > 0);
            avgFRRate = mean(summaryTable.FastRipple_Rate(summaryTable.FastRipple_Count > 0));
            addStatus(sprintf('FAST RIPPLES (%.0f-%.0f Hz):', params.fastRippleLow, params.fastRippleHigh));
            addStatus(sprintf('  Total events: %d', totalFR));
            addStatus(sprintf('  Channels with fast ripples: %d/%d', channelsWithFR, numChannels));
            if ~isnan(avgFRRate)
                addStatus(sprintf('  Avg rate (active channels): %.2f events/min', avgFRRate));
            end
        end
        
        % Store results
        setappdata(fig, 'rippleResults', rippleResults);
        setappdata(fig, 'fastRippleResults', fastRippleResults);
        setappdata(fig, 'hfoSummary', summaryTable);
        setappdata(fig, 'hfoParams', params);
        
        % Create visualizations
        addStatus('Generating visualizations...');
        
        % Figure 1: HFO Rate Spatial Map
        createHFOSpatialMap(summaryTable, params, hfoFolder);
        
        % Figure 2: HFO Rate Distribution
        createHFORateHistogram(summaryTable, params, hfoFolder);
        
        % Figure 3: Example HFO Events (top channels) - use cleaned data for visualization
        if params.bandChoice == 1 || params.bandChoice == 3
            createHFOExamplePlot(hfoInputData, rippleResults, summaryTable, ...
                                 samplingRate, params, 'Ripple', hfoFolder);
        end
        if params.bandChoice == 2 || params.bandChoice == 3
            createHFOExamplePlot(hfoInputData, fastRippleResults, summaryTable, ...
                                 samplingRate, params, 'FastRipple', hfoFolder);
        end
        
        % Ask if user wants to run HFO-Burst coupling analysis
        % Check for network burst data from spike detection
        eventOnsets = getappdata(fig, 'eventOnsets');
        eventOffsets = getappdata(fig, 'eventOffsets');
        
        hasBursts = ~isempty(eventOnsets) && ~isempty(eventOffsets);
        
        if hasBursts
            answer = questdlg('Run HFO-Burst Coupling Analysis?', ...
                              'HFO-Burst Coupling', 'Yes', 'No', 'Yes');
            if strcmp(answer, 'Yes')
                analyzeHFOBurstCoupling(hfoInputData, rippleResults, fastRippleResults, ...
                                        params, hfoFolder, samplingRate);
            end
        else
            addStatus('Note: Run spike detection first to enable HFO-Burst coupling analysis');
        end
        
        addStatus('========================================');
        addStatus('HFO Detection Complete!');
        addStatus(sprintf('Results saved to: %s', hfoFolder));
        addStatus('========================================');
    end
    
    function analyzeHFOBurstCoupling(hfoInputData, rippleResults, fastRippleResults, ...
                                      params, outputFolder, samplingRate)
        % Analyze coupling between HFOs and network bursts
        % Determines if HFOs occur during bursts or in inter-burst intervals
        
        addStatus('');
        addStatus('=== HFO-Burst Coupling Analysis ===');
        
        % Get burst timing data
        burstOnsets = getappdata(fig, 'eventOnsets');
        burstOffsets = getappdata(fig, 'eventOffsets');
        
        if isempty(burstOnsets) || isempty(burstOffsets)
            addStatus('ERROR: No burst data available. Run spike detection first.');
            return;
        end
        
        % Ensure column vectors and same length
        burstOnsets = burstOnsets(:);
        burstOffsets = burstOffsets(:);
        
        if length(burstOnsets) ~= length(burstOffsets)
            addStatus('ERROR: Burst onset/offset count mismatch.');
            return;
        end
        
        numBursts = length(burstOnsets);
        addStatus(sprintf('Found %d network bursts', numBursts));
        
        % Calculate total burst duration and inter-burst duration
        channelNamesTemp = fieldnames(hfoInputData);
        totalRecordingTime = length(hfoInputData.(channelNamesTemp{1})) / samplingRate;
        totalBurstTime = sum(burstOffsets - burstOnsets);
        totalInterburstTime = totalRecordingTime - totalBurstTime;
        
        addStatus(sprintf('Recording duration: %.1f s', totalRecordingTime));
        addStatus(sprintf('Total burst time: %.2f s (%.1f%%)', totalBurstTime, totalBurstTime/totalRecordingTime*100));
        addStatus(sprintf('Total inter-burst time: %.2f s (%.1f%%)', totalInterburstTime, totalInterburstTime/totalRecordingTime*100));
        
        % Analyze Ripples
        rippleCoupling = struct();
        if params.bandChoice == 1 || params.bandChoice == 3
            addStatus('Analyzing Ripple-Burst coupling...');
            rippleCoupling = analyzeHFOBurstType(rippleResults, burstOnsets, burstOffsets, 'Ripple');
        end
        
        % Analyze Fast Ripples
        fastRippleCoupling = struct();
        if params.bandChoice == 2 || params.bandChoice == 3
            addStatus('Analyzing Fast Ripple-Burst coupling...');
            fastRippleCoupling = analyzeHFOBurstType(fastRippleResults, burstOnsets, burstOffsets, 'FastRipple');
        end
        
        % Create visualizations
        addStatus('Generating coupling visualizations...');
        
        % Figure 1: Coupling summary pie charts
        createBurstCouplingOverview(rippleCoupling, fastRippleCoupling, params, ...
                                    totalBurstTime, totalInterburstTime, outputFolder);
        
        % Figure 2: HFO timing relative to burst structure
        createBurstTimingHistogram(rippleResults, fastRippleResults, burstOnsets, burstOffsets, ...
                                   params, outputFolder);
        
        % Figure 3: Spatial distribution of burst-coupled vs inter-burst HFOs
        createBurstCouplingSpatialMap(rippleCoupling, fastRippleCoupling, params, outputFolder);
        
        % Figure 4: Timeline showing bursts and HFOs
        createBurstHFOTimeline(rippleResults, fastRippleResults, burstOnsets, burstOffsets, ...
                               params, totalRecordingTime, outputFolder);
        
        % Figure 5: Example waveforms
        createBurstCouplingExamples(hfoInputData, rippleResults, fastRippleResults, ...
                                    rippleCoupling, fastRippleCoupling, burstOnsets, burstOffsets, ...
                                    samplingRate, params, outputFolder);
        
        % Figure 6: HFO Hotspot Analysis
        createHFOHotspotAnalysis(rippleResults, fastRippleResults, params, outputFolder);
        
        % Save coupling results
        couplingResults = struct();
        couplingResults.rippleCoupling = rippleCoupling;
        couplingResults.fastRippleCoupling = fastRippleCoupling;
        couplingResults.burstOnsets = burstOnsets;
        couplingResults.burstOffsets = burstOffsets;
        couplingResults.totalBurstTime = totalBurstTime;
        couplingResults.totalInterburstTime = totalInterburstTime;
        setappdata(fig, 'hfoBurstCouplingResults', couplingResults);
        
        % Save to Excel
        saveBurstCouplingToExcel(rippleCoupling, fastRippleCoupling, params, ...
                                 totalBurstTime, totalInterburstTime, outputFolder);
        
        addStatus('HFO-Burst Coupling Analysis Complete!');
    end
    
    function couplingData = analyzeHFOBurstType(hfoResults, burstOnsets, burstOffsets, hfoType)
        % Analyze burst coupling for one type of HFO (Ripple or FastRipple)
        
        channelNames = fieldnames(hfoResults);
        
        couplingData = struct();
        couplingData.totalHFOs = 0;
        couplingData.burstHFOs = 0;      % HFOs during bursts
        couplingData.interburstHFOs = 0;  % HFOs between bursts
        couplingData.channelData = struct();
        
        allBurstTimes = [];
        allInterburstTimes = [];
        
        for ch = 1:length(channelNames)
            chName = channelNames{ch};
            events = hfoResults.(chName);
            
            chBurst = 0;
            chInterburst = 0;
            chBurstIdx = [];
            chInterburstIdx = [];
            
            for e = 1:length(events)
                hfoTime = events(e).peakTime;
                
                % Check if HFO falls within any burst period
                isDuringBurst = false;
                for b = 1:length(burstOnsets)
                    if hfoTime >= burstOnsets(b) && hfoTime <= burstOffsets(b)
                        isDuringBurst = true;
                        break;
                    end
                end
                
                if isDuringBurst
                    chBurst = chBurst + 1;
                    chBurstIdx(end+1) = e;
                    allBurstTimes(end+1) = hfoTime;
                else
                    chInterburst = chInterburst + 1;
                    chInterburstIdx(end+1) = e;
                    allInterburstTimes(end+1) = hfoTime;
                end
            end
            
            couplingData.channelData.(chName).burstCoupled = chBurst;
            couplingData.channelData.(chName).interburst = chInterburst;
            couplingData.channelData.(chName).total = length(events);
            couplingData.channelData.(chName).burstIdx = chBurstIdx;
            couplingData.channelData.(chName).interburstIdx = chInterburstIdx;
            
            couplingData.totalHFOs = couplingData.totalHFOs + length(events);
            couplingData.burstHFOs = couplingData.burstHFOs + chBurst;
            couplingData.interburstHFOs = couplingData.interburstHFOs + chInterburst;
        end
        
        couplingData.burstTimes = allBurstTimes;
        couplingData.interburstTimes = allInterburstTimes;
        
        if couplingData.totalHFOs > 0
            couplingData.burstCouplingRate = couplingData.burstHFOs / couplingData.totalHFOs * 100;
        else
            couplingData.burstCouplingRate = 0;
        end
        
        addStatus(sprintf('  %s: %d total, %d during bursts (%.1f%%), %d inter-burst', ...
                 hfoType, couplingData.totalHFOs, couplingData.burstHFOs, ...
                 couplingData.burstCouplingRate, couplingData.interburstHFOs));
    end
    
    function createBurstCouplingOverview(rippleCoupling, fastRippleCoupling, params, ...
                                          totalBurstTime, totalInterburstTime, outputFolder)
        % Create overview figure with pie charts showing burst vs inter-burst HFOs
        
        fig_overview = figure('Name', 'HFO-Burst Coupling Overview', ...
                              'Position', [100 100 1400 600], 'Color', 'white');
        
        numPlots = 0;
        if params.bandChoice == 1 || params.bandChoice == 3
            numPlots = numPlots + 1;
        end
        if params.bandChoice == 2 || params.bandChoice == 3
            numPlots = numPlots + 1;
        end
        
        plotIdx = 1;
        
        % Ripple coupling pie chart
        if (params.bandChoice == 1 || params.bandChoice == 3) && ~isempty(fieldnames(rippleCoupling))
            subplot(2, numPlots, plotIdx);
            
            if rippleCoupling.totalHFOs > 0
                pie([rippleCoupling.burstHFOs, rippleCoupling.interburstHFOs]);
                colormap(gca, [0.8 0.3 0.3; 0.3 0.7 0.3]);
                legend({'During Bursts', 'Inter-Burst'}, 'Location', 'southoutside');
                title(sprintf('Ripples (%.0f-%.0f Hz)\n%d total, %.1f%% during bursts', ...
                      params.rippleLow, params.rippleHigh, ...
                      rippleCoupling.totalHFOs, rippleCoupling.burstCouplingRate), ...
                      'FontSize', 11, 'FontWeight', 'bold');
            else
                text(0.5, 0.5, 'No Ripples Detected', 'HorizontalAlignment', 'center');
                axis off;
            end
            
            % Add normalized rate comparison
            subplot(2, numPlots, plotIdx + numPlots);
            if rippleCoupling.totalHFOs > 0 && totalBurstTime > 0 && totalInterburstTime > 0
                burstRate = rippleCoupling.burstHFOs / (totalBurstTime / 60);  % per minute
                interburstRate = rippleCoupling.interburstHFOs / (totalInterburstTime / 60);
                bar([burstRate, interburstRate], 'FaceColor', [0.8 0.3 0.3]);
                set(gca, 'XTickLabel', {'During Bursts', 'Inter-Burst'});
                ylabel('HFO Rate (events/min)');
                title('Normalized Ripple Rate', 'FontSize', 10);
                
                % Add fold-change annotation
                if interburstRate > 0
                    foldChange = burstRate / interburstRate;
                    text(1.5, max([burstRate, interburstRate]) * 0.9, ...
                         sprintf('%.1fx', foldChange), 'HorizontalAlignment', 'center', ...
                         'FontSize', 12, 'FontWeight', 'bold');
                end
            end
            
            plotIdx = plotIdx + 1;
        end
        
        % Fast Ripple coupling pie chart
        if (params.bandChoice == 2 || params.bandChoice == 3) && ~isempty(fieldnames(fastRippleCoupling))
            subplot(2, numPlots, plotIdx);
            
            if fastRippleCoupling.totalHFOs > 0
                pie([fastRippleCoupling.burstHFOs, fastRippleCoupling.interburstHFOs]);
                colormap(gca, [0.3 0.3 0.8; 0.3 0.7 0.3]);
                legend({'During Bursts', 'Inter-Burst'}, 'Location', 'southoutside');
                title(sprintf('Fast Ripples (%.0f-%.0f Hz)\n%d total, %.1f%% during bursts', ...
                      params.fastRippleLow, params.fastRippleHigh, ...
                      fastRippleCoupling.totalHFOs, fastRippleCoupling.burstCouplingRate), ...
                      'FontSize', 11, 'FontWeight', 'bold');
            else
                text(0.5, 0.5, 'No Fast Ripples Detected', 'HorizontalAlignment', 'center');
                axis off;
            end
            
            % Add normalized rate comparison
            subplot(2, numPlots, plotIdx + numPlots);
            if fastRippleCoupling.totalHFOs > 0 && totalBurstTime > 0 && totalInterburstTime > 0
                burstRate = fastRippleCoupling.burstHFOs / (totalBurstTime / 60);
                interburstRate = fastRippleCoupling.interburstHFOs / (totalInterburstTime / 60);
                bar([burstRate, interburstRate], 'FaceColor', [0.3 0.3 0.8]);
                set(gca, 'XTickLabel', {'During Bursts', 'Inter-Burst'});
                ylabel('HFO Rate (events/min)');
                title('Normalized Fast Ripple Rate', 'FontSize', 10);
                
                if interburstRate > 0
                    foldChange = burstRate / interburstRate;
                    text(1.5, max([burstRate, interburstRate]) * 0.9, ...
                         sprintf('%.1fx', foldChange), 'HorizontalAlignment', 'center', ...
                         'FontSize', 12, 'FontWeight', 'bold');
                end
            end
        end
        
        sgtitle('HFO-Burst Coupling Analysis', 'FontSize', 14, 'FontWeight', 'bold');
        
        saveas(fig_overview, fullfile(outputFolder, 'HFO_Burst_Coupling_Overview.png'));
        saveas(fig_overview, fullfile(outputFolder, 'HFO_Burst_Coupling_Overview.fig'));
    end
    
    function createBurstTimingHistogram(rippleResults, fastRippleResults, burstOnsets, burstOffsets, ...
                                         params, outputFolder)
        % Create histogram showing HFO timing relative to burst onset
        
        fig_hist = figure('Name', 'HFO Timing Relative to Bursts', ...
                          'Position', [100 100 1200 500], 'Color', 'white');
        
        binEdges = -1:0.05:1;  % -1 to +1 seconds in 50 ms bins
        
        numPlots = 0;
        if params.bandChoice == 1 || params.bandChoice == 3
            numPlots = numPlots + 1;
        end
        if params.bandChoice == 2 || params.bandChoice == 3
            numPlots = numPlots + 1;
        end
        
        plotIdx = 1;
        
        % Ripples timing histogram
        if params.bandChoice == 1 || params.bandChoice == 3
            subplot(1, numPlots, plotIdx);
            
            allDelays = [];
            channelNames = fieldnames(rippleResults);
            for ch = 1:length(channelNames)
                events = rippleResults.(channelNames{ch});
                for e = 1:length(events)
                    hfoTime = events(e).peakTime;
                    
                    % Find nearest burst onset
                    [minDist, nearestIdx] = min(abs(burstOnsets - hfoTime));
                    if minDist <= 1  % Within 1 second
                        delay = hfoTime - burstOnsets(nearestIdx);
                        allDelays(end+1) = delay;
                    end
                end
            end
            
            if ~isempty(allDelays)
                histogram(allDelays, binEdges, 'FaceColor', [0.8 0.2 0.2], 'EdgeColor', 'none');
                hold on;
                xline(0, 'k-', 'LineWidth', 2, 'Label', 'Burst Onset');
                
                % Mark average burst duration
                avgBurstDur = mean(burstOffsets - burstOnsets);
                xline(avgBurstDur, 'k--', 'LineWidth', 1.5, 'Label', 'Avg Burst End');
                hold off;
                
                xlabel('Time relative to burst onset (s)');
                ylabel('HFO count');
                title(sprintf('Ripples (%.0f-%.0f Hz)\nn=%d within ±1s of burst', ...
                      params.rippleLow, params.rippleHigh, length(allDelays)));
                xlim([-1 1]);
            else
                text(0.5, 0.5, 'No Ripples near bursts', 'HorizontalAlignment', 'center');
                axis off;
            end
            
            plotIdx = plotIdx + 1;
        end
        
        % Fast Ripples timing histogram
        if params.bandChoice == 2 || params.bandChoice == 3
            subplot(1, numPlots, plotIdx);
            
            allDelays = [];
            channelNames = fieldnames(fastRippleResults);
            for ch = 1:length(channelNames)
                events = fastRippleResults.(channelNames{ch});
                for e = 1:length(events)
                    hfoTime = events(e).peakTime;
                    
                    [minDist, nearestIdx] = min(abs(burstOnsets - hfoTime));
                    if minDist <= 1
                        delay = hfoTime - burstOnsets(nearestIdx);
                        allDelays(end+1) = delay;
                    end
                end
            end
            
            if ~isempty(allDelays)
                histogram(allDelays, binEdges, 'FaceColor', [0.2 0.2 0.8], 'EdgeColor', 'none');
                hold on;
                xline(0, 'k-', 'LineWidth', 2, 'Label', 'Burst Onset');
                avgBurstDur = mean(burstOffsets - burstOnsets);
                xline(avgBurstDur, 'k--', 'LineWidth', 1.5, 'Label', 'Avg Burst End');
                hold off;
                
                xlabel('Time relative to burst onset (s)');
                ylabel('HFO count');
                title(sprintf('Fast Ripples (%.0f-%.0f Hz)\nn=%d within ±1s of burst', ...
                      params.fastRippleLow, params.fastRippleHigh, length(allDelays)));
                xlim([-1 1]);
            else
                text(0.5, 0.5, 'No Fast Ripples near bursts', 'HorizontalAlignment', 'center');
                axis off;
            end
        end
        
        sgtitle('HFO Timing Relative to Network Burst Onset', 'FontSize', 12, 'FontWeight', 'bold');
        
        saveas(fig_hist, fullfile(outputFolder, 'HFO_Burst_Timing_Histogram.png'));
        saveas(fig_hist, fullfile(outputFolder, 'HFO_Burst_Timing_Histogram.fig'));
    end
    
    function createBurstCouplingSpatialMap(rippleCoupling, fastRippleCoupling, params, outputFolder)
        % Create spatial map showing burst-coupled vs inter-burst HFO distribution
        
        fig_spatial = figure('Name', 'HFO-Burst Coupling Spatial Distribution', ...
                             'Position', [100 100 1400 600], 'Color', 'white');
        
        electrode_positions = {'A','B','C','D','E','F','G','H','J','K','L','M','N','O','P','R'};
        
        plotIdx = 1;
        
        % Ripples spatial maps
        if (params.bandChoice == 1 || params.bandChoice == 3) && ~isempty(fieldnames(rippleCoupling))
            % During Burst Ripples
            subplot(2, 4, plotIdx);
            burstMatrix = createBurstCouplingMatrix(rippleCoupling, 'burstCoupled', electrode_positions);
            imagesc(burstMatrix);
            colormap(gca, hot); colorbar;
            set(gca, 'XTick', 1:16, 'XTickLabel', electrode_positions, 'FontSize', 7);
            set(gca, 'YTick', 1:16, 'YTickLabel', 1:16, 'FontSize', 7);
            title('Ripples - During Bursts', 'FontSize', 9);
            axis square;
            
            % Inter-burst Ripples
            subplot(2, 4, plotIdx + 1);
            interburstMatrix = createBurstCouplingMatrix(rippleCoupling, 'interburst', electrode_positions);
            imagesc(interburstMatrix);
            colormap(gca, hot); colorbar;
            set(gca, 'XTick', 1:16, 'XTickLabel', electrode_positions, 'FontSize', 7);
            set(gca, 'YTick', 1:16, 'YTickLabel', 1:16, 'FontSize', 7);
            title('Ripples - Inter-Burst', 'FontSize', 9);
            axis square;
            
            plotIdx = plotIdx + 2;
        end
        
        % Fast Ripples spatial maps
        if (params.bandChoice == 2 || params.bandChoice == 3) && ~isempty(fieldnames(fastRippleCoupling))
            % During Burst Fast Ripples
            subplot(2, 4, plotIdx);
            burstMatrix = createBurstCouplingMatrix(fastRippleCoupling, 'burstCoupled', electrode_positions);
            imagesc(burstMatrix);
            colormap(gca, hot); colorbar;
            set(gca, 'XTick', 1:16, 'XTickLabel', electrode_positions, 'FontSize', 7);
            set(gca, 'YTick', 1:16, 'YTickLabel', 1:16, 'FontSize', 7);
            title('Fast Ripples - During Bursts', 'FontSize', 9);
            axis square;
            
            % Inter-burst Fast Ripples
            subplot(2, 4, plotIdx + 1);
            interburstMatrix = createBurstCouplingMatrix(fastRippleCoupling, 'interburst', electrode_positions);
            imagesc(interburstMatrix);
            colormap(gca, hot); colorbar;
            set(gca, 'XTick', 1:16, 'XTickLabel', electrode_positions, 'FontSize', 7);
            set(gca, 'YTick', 1:16, 'YTickLabel', 1:16, 'FontSize', 7);
            title('Fast Ripples - Inter-Burst', 'FontSize', 9);
            axis square;
        end
        
        sgtitle('Spatial Distribution: Burst-Coupled vs Inter-Burst HFOs', 'FontSize', 14, 'FontWeight', 'bold');
        
        saveas(fig_spatial, fullfile(outputFolder, 'HFO_Burst_Coupling_SpatialMap.png'));
        saveas(fig_spatial, fullfile(outputFolder, 'HFO_Burst_Coupling_SpatialMap.fig'));
    end
    
    function matrix = createBurstCouplingMatrix(couplingData, couplingType, electrode_positions)
        % Create 16x16 matrix for spatial visualization
        matrix = zeros(16, 16);
        
        channelNames = fieldnames(couplingData.channelData);
        for ch = 1:length(channelNames)
            chName = channelNames{ch};
            
            % Parse channel name
            colLetter = regexp(chName, '[A-Z]+', 'match', 'once');
            rowNum = str2double(regexp(chName, '\d+', 'match', 'once'));
            
            colIdx = find(strcmp(electrode_positions, colLetter));
            
            if ~isempty(colIdx) && ~isnan(rowNum) && rowNum >= 1 && rowNum <= 16
                matrix(rowNum, colIdx) = couplingData.channelData.(chName).(couplingType);
            end
        end
    end
    
    function createBurstHFOTimeline(rippleResults, fastRippleResults, burstOnsets, burstOffsets, ...
                                     params, totalRecordingTime, outputFolder)
        % Create timeline showing bursts and HFO occurrences
        
        fig_timeline = figure('Name', 'HFO-Burst Timeline', ...
                              'Position', [50 100 1600 500], 'Color', 'white');
        
        % Plot burst periods as shaded regions
        hold on;
        for b = 1:length(burstOnsets)
            fill([burstOnsets(b) burstOffsets(b) burstOffsets(b) burstOnsets(b)], ...
                 [0 0 3 3], [0.9 0.9 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
        end
        
        yPos = 1;
        
        % Plot Ripples
        if params.bandChoice == 1 || params.bandChoice == 3
            channelNames = fieldnames(rippleResults);
            for ch = 1:length(channelNames)
                events = rippleResults.(channelNames{ch});
                for e = 1:length(events)
                    plot(events(e).peakTime, yPos, 'r|', 'MarkerSize', 8, 'LineWidth', 1);
                end
            end
            yPos = yPos + 1;
        end
        
        % Plot Fast Ripples
        if params.bandChoice == 2 || params.bandChoice == 3
            channelNames = fieldnames(fastRippleResults);
            for ch = 1:length(channelNames)
                events = fastRippleResults.(channelNames{ch});
                for e = 1:length(events)
                    plot(events(e).peakTime, yPos, 'b|', 'MarkerSize', 8, 'LineWidth', 1);
                end
            end
        end
        
        hold off;
        
        xlim([0 totalRecordingTime]);
        ylim([0 3]);
        xlabel('Time (s)', 'FontSize', 12);
        
        % Create legend entries
        yticks = [];
        yticklabels = {};
        if params.bandChoice == 1 || params.bandChoice == 3
            yticks(end+1) = 1;
            yticklabels{end+1} = 'Ripples';
        end
        if params.bandChoice == 2 || params.bandChoice == 3
            yticks(end+1) = 2;
            yticklabels{end+1} = 'Fast Ripples';
        end
        set(gca, 'YTick', yticks, 'YTickLabel', yticklabels);
        
        title('HFO Timeline (Gray shading = Network Bursts)', 'FontSize', 14, 'FontWeight', 'bold');
        
        saveas(fig_timeline, fullfile(outputFolder, 'HFO_Burst_Timeline.png'));
        saveas(fig_timeline, fullfile(outputFolder, 'HFO_Burst_Timeline.fig'));
    end
    
    function createBurstCouplingExamples(hfoInputData, rippleResults, fastRippleResults, ...
                                          rippleCoupling, fastRippleCoupling, burstOnsets, burstOffsets, ...
                                          samplingRate, params, outputFolder)
        % Create example waveforms comparing burst-coupled vs inter-burst HFOs
        
        fig_examples = figure('Name', 'HFO-Burst Coupling Examples', ...
                              'Position', [50 50 1400 800], 'Color', 'white');
        
        % Find channels with both burst-coupled and inter-burst events
        if (params.bandChoice == 1 || params.bandChoice == 3) && ~isempty(fieldnames(rippleCoupling))
            plotBurstCouplingExamples(hfoInputData, rippleResults, rippleCoupling, ...
                                      burstOnsets, burstOffsets, samplingRate, params, 'Ripple', ...
                                      [0.8 0.2 0.2], 1);
        end
        
        if (params.bandChoice == 2 || params.bandChoice == 3) && ~isempty(fieldnames(fastRippleCoupling))
            startRow = 1;
            if params.bandChoice == 3
                startRow = 3;
            end
            plotBurstCouplingExamples(hfoInputData, fastRippleResults, fastRippleCoupling, ...
                                      burstOnsets, burstOffsets, samplingRate, params, 'FastRipple', ...
                                      [0.2 0.2 0.8], startRow);
        end
        
        sgtitle('HFO-Burst Coupling Examples: During Burst (left) vs Inter-Burst (right)', ...
                'FontSize', 14, 'FontWeight', 'bold');
        
        saveas(fig_examples, fullfile(outputFolder, 'HFO_Burst_Coupling_Examples.png'));
        saveas(fig_examples, fullfile(outputFolder, 'HFO_Burst_Coupling_Examples.fig'));
    end
    
    function plotBurstCouplingExamples(hfoInputData, hfoResults, couplingData, ...
                                        burstOnsets, burstOffsets, samplingRate, params, hfoType, ...
                                        plotColor, startRow)
        % Plot example burst-coupled and inter-burst HFOs
        
        if strcmp(hfoType, 'Ripple')
            lowFreq = params.rippleLow;
            highFreq = params.rippleHigh;
        else
            lowFreq = params.fastRippleLow;
            highFreq = params.fastRippleHigh;
        end
        
        [b, a] = butter(4, [lowFreq highFreq] / (samplingRate/2), 'bandpass');
        
        % Find a channel with both burst-coupled and inter-burst events
        channelNames = fieldnames(couplingData.channelData);
        exampleChannel = '';
        for ch = 1:length(channelNames)
            chName = channelNames{ch};
            if couplingData.channelData.(chName).burstCoupled > 0 && ...
               couplingData.channelData.(chName).interburst > 0
                exampleChannel = chName;
                break;
            end
        end
        
        if isempty(exampleChannel)
            % Fall back to any channel with events
            for ch = 1:length(channelNames)
                if couplingData.channelData.(channelNames{ch}).total > 0
                    exampleChannel = channelNames{ch};
                    break;
                end
            end
        end
        
        if isempty(exampleChannel)
            return;
        end
        
        signal = hfoInputData.(exampleChannel);
        filteredSig = filtfilt(b, a, signal);
        events = hfoResults.(exampleChannel);
        chCoupling = couplingData.channelData.(exampleChannel);
        
        % Plot burst-coupled example
        if ~isempty(chCoupling.burstIdx)
            eventIdx = chCoupling.burstIdx(1);
            event = events(eventIdx);
            
            subplot(4, 2, (startRow-1)*2 + 1);
            plotBurstHFOWaveform(signal, filteredSig, event, burstOnsets, burstOffsets, ...
                                 samplingRate, plotColor);
            title(sprintf('%s %s - DURING BURST\n%.0f ms, %.1f µV', exampleChannel, hfoType, ...
                  event.duration*1000, event.amplitude), 'FontSize', 10);
        end
        
        % Plot inter-burst example
        if ~isempty(chCoupling.interburstIdx)
            eventIdx = chCoupling.interburstIdx(1);
            event = events(eventIdx);
            
            subplot(4, 2, (startRow-1)*2 + 2);
            plotBurstHFOWaveform(signal, filteredSig, event, burstOnsets, burstOffsets, ...
                                 samplingRate, plotColor);
            title(sprintf('%s %s - INTER-BURST\n%.0f ms, %.1f µV', exampleChannel, hfoType, ...
                  event.duration*1000, event.amplitude), 'FontSize', 10);
        end
    end
    
    function plotBurstHFOWaveform(signal, filteredSig, event, burstOnsets, burstOffsets, ...
                                   samplingRate, plotColor)
        % Plot a single HFO event with burst period marking
        
        windowSamples = round(0.200 * samplingRate);  % ±200 ms for burst context
        startSample = max(1, round(event.startTime * samplingRate) - windowSamples);
        endSample = min(length(signal), round(event.endTime * samplingRate) + windowSamples);
        
        segment = signal(startSample:endSample);
        filteredSegment = filteredSig(startSample:endSample);
        timeVec = (startSample:endSample) / samplingRate * 1000;  % ms
        
        hold on;
        
        % Mark burst periods in view
        for b = 1:length(burstOnsets)
            burstStartMs = burstOnsets(b) * 1000;
            burstEndMs = burstOffsets(b) * 1000;
            
            if burstEndMs >= timeVec(1) && burstStartMs <= timeVec(end)
                % Burst overlaps with view
                visStart = max(burstStartMs, timeVec(1));
                visEnd = min(burstEndMs, timeVec(end));
                yl = [min(segment)*1.1, max(segment)*1.1];
                fill([visStart visEnd visEnd visStart], ...
                     [yl(1) yl(1) yl(2) yl(2)], [0.9 0.9 0.7], ...
                     'EdgeColor', 'none', 'FaceAlpha', 0.4);
            end
        end
        
        % Plot raw and filtered
        plot(timeVec, segment, 'k-', 'LineWidth', 0.5);
        plot(timeVec, filteredSegment, 'Color', plotColor, 'LineWidth', 1.2);
        
        % Mark HFO event
        eventStartMs = event.startTime * 1000;
        eventEndMs = event.endTime * 1000;
        yl = ylim;
        fill([eventStartMs eventEndMs eventEndMs eventStartMs], ...
             [yl(1) yl(1) yl(2) yl(2)], plotColor, ...
             'FaceAlpha', 0.15, 'EdgeColor', 'none');
        
        hold off;
        xlabel('Time (ms)');
        ylabel('µV');
        xlim([timeVec(1) timeVec(end)]);
    end
    
    function saveBurstCouplingToExcel(rippleCoupling, fastRippleCoupling, params, ...
                                       totalBurstTime, totalInterburstTime, outputFolder)
        % Save burst coupling results to Excel
        
        excelPath = fullfile(outputFolder, 'HFO_Burst_Coupling.xlsx');
        
        % Summary sheet
        summaryData = {};
        summaryData{1, 1} = 'HFO Type';
        summaryData{1, 2} = 'Total HFOs';
        summaryData{1, 3} = 'During Bursts';
        summaryData{1, 4} = 'Inter-Burst';
        summaryData{1, 5} = 'Burst Coupling Rate (%)';
        summaryData{1, 6} = 'Burst Rate (events/min)';
        summaryData{1, 7} = 'Inter-Burst Rate (events/min)';
        summaryData{1, 8} = 'Rate Ratio (Burst/Inter-burst)';
        
        row = 2;
        if (params.bandChoice == 1 || params.bandChoice == 3) && ~isempty(fieldnames(rippleCoupling))
            burstRate = rippleCoupling.burstHFOs / (totalBurstTime / 60);
            interburstRate = rippleCoupling.interburstHFOs / (totalInterburstTime / 60);
            rateRatio = burstRate / max(interburstRate, eps);
            
            summaryData{row, 1} = sprintf('Ripples (%.0f-%.0f Hz)', params.rippleLow, params.rippleHigh);
            summaryData{row, 2} = rippleCoupling.totalHFOs;
            summaryData{row, 3} = rippleCoupling.burstHFOs;
            summaryData{row, 4} = rippleCoupling.interburstHFOs;
            summaryData{row, 5} = rippleCoupling.burstCouplingRate;
            summaryData{row, 6} = burstRate;
            summaryData{row, 7} = interburstRate;
            summaryData{row, 8} = rateRatio;
            row = row + 1;
        end
        
        if (params.bandChoice == 2 || params.bandChoice == 3) && ~isempty(fieldnames(fastRippleCoupling))
            burstRate = fastRippleCoupling.burstHFOs / (totalBurstTime / 60);
            interburstRate = fastRippleCoupling.interburstHFOs / (totalInterburstTime / 60);
            rateRatio = burstRate / max(interburstRate, eps);
            
            summaryData{row, 1} = sprintf('Fast Ripples (%.0f-%.0f Hz)', params.fastRippleLow, params.fastRippleHigh);
            summaryData{row, 2} = fastRippleCoupling.totalHFOs;
            summaryData{row, 3} = fastRippleCoupling.burstHFOs;
            summaryData{row, 4} = fastRippleCoupling.interburstHFOs;
            summaryData{row, 5} = fastRippleCoupling.burstCouplingRate;
            summaryData{row, 6} = burstRate;
            summaryData{row, 7} = interburstRate;
            summaryData{row, 8} = rateRatio;
        end
        
        % Add timing info
        row = row + 2;
        summaryData{row, 1} = 'Total Burst Time (s)';
        summaryData{row, 2} = totalBurstTime;
        row = row + 1;
        summaryData{row, 1} = 'Total Inter-Burst Time (s)';
        summaryData{row, 2} = totalInterburstTime;
        
        % Write to Excel
        summaryTable = cell2table(summaryData(2:end, :), 'VariableNames', ...
            {'Metric', 'Value1', 'Value2', 'Value3', 'Value4', 'Value5', 'Value6', 'Value7'});
        writetable(summaryTable, excelPath, 'Sheet', 'Summary');
        
        addStatus(sprintf('Burst coupling results saved to: %s', excelPath));
    end
    
    function createHFOHotspotAnalysis(rippleResults, fastRippleResults, params, outputFolder)
        % Identify and visualize HFO hotspots - channels with highest HFO rates
        
        addStatus('Generating HFO Hotspot Analysis...');
        
        electrode_positions = {'A','B','C','D','E','F','G','H','J','K','L','M','N','O','P','R'};
        nTopChannels = 10;  % Number of top channels to identify as hotspots
        
        fig_hotspot = figure('Name', 'HFO Hotspot Analysis', ...
                             'Position', [50 50 1400 700], 'Color', 'white');
        
        plotIdx = 1;
        numPlots = 0;
        if params.bandChoice == 1 || params.bandChoice == 3
            numPlots = numPlots + 2;
        end
        if params.bandChoice == 2 || params.bandChoice == 3
            numPlots = numPlots + 2;
        end
        
        % Ripple hotspots
        if params.bandChoice == 1 || params.bandChoice == 3
            % Count HFOs per channel
            rippleMatrix = zeros(16, 16);
            channelNames = fieldnames(rippleResults);
            channelCounts = zeros(length(channelNames), 1);
            
            for ch = 1:length(channelNames)
                chName = channelNames{ch};
                count = length(rippleResults.(chName));
                channelCounts(ch) = count;
                
                colLetter = regexp(chName, '[A-Z]+', 'match', 'once');
                rowNum = str2double(regexp(chName, '\d+', 'match', 'once'));
                colIdx = find(strcmp(electrode_positions, colLetter));
                
                if ~isempty(colIdx) && ~isnan(rowNum) && rowNum >= 1 && rowNum <= 16
                    rippleMatrix(rowNum, colIdx) = count;
                end
            end
            
            % Find top channels
            [sortedCounts, sortIdx] = sort(channelCounts, 'descend');
            topChannels = channelNames(sortIdx(1:min(nTopChannels, length(sortIdx))));
            topCounts = sortedCounts(1:min(nTopChannels, length(sortIdx)));
            
            % Spatial map with hotspots marked
            subplot(2, numPlots/2, plotIdx);
            imagesc(rippleMatrix);
            colormap(gca, hot); colorbar;
            hold on;
            
            % Mark hotspots with circles
            for i = 1:length(topChannels)
                chName = topChannels{i};
                colLetter = regexp(chName, '[A-Z]+', 'match', 'once');
                rowNum = str2double(regexp(chName, '\d+', 'match', 'once'));
                colIdx = find(strcmp(electrode_positions, colLetter));
                
                if ~isempty(colIdx)
                    plot(colIdx, rowNum, 'wo', 'MarkerSize', 20, 'LineWidth', 2);
                    text(colIdx, rowNum, sprintf('%d', i), 'Color', 'w', ...
                         'HorizontalAlignment', 'center', 'FontWeight', 'bold');
                end
            end
            hold off;
            
            set(gca, 'XTick', 1:16, 'XTickLabel', electrode_positions, 'FontSize', 7);
            set(gca, 'YTick', 1:16);
            title(sprintf('Ripple Spatial Map\n(Top %d hotspots circled)', nTopChannels), 'FontSize', 10);
            axis square;
            plotIdx = plotIdx + 1;
            
            % Bar chart of top channels
            subplot(2, numPlots/2, plotIdx);
            barh(flipud(topCounts), 'FaceColor', [0.8 0.3 0.3]);
            set(gca, 'YTick', 1:length(topChannels), 'YTickLabel', flipud(topChannels));
            xlabel('HFO Count');
            title('Top Ripple Hotspots', 'FontSize', 10);
            grid on;
            plotIdx = plotIdx + 1;
            
            % Report to status
            addStatus(sprintf('  Ripple Hotspots: %s', strjoin(topChannels(1:min(5,end))', ', ')));
        end
        
        % Fast Ripple hotspots
        if params.bandChoice == 2 || params.bandChoice == 3
            % Count HFOs per channel
            frMatrix = zeros(16, 16);
            channelNames = fieldnames(fastRippleResults);
            channelCounts = zeros(length(channelNames), 1);
            
            for ch = 1:length(channelNames)
                chName = channelNames{ch};
                count = length(fastRippleResults.(chName));
                channelCounts(ch) = count;
                
                colLetter = regexp(chName, '[A-Z]+', 'match', 'once');
                rowNum = str2double(regexp(chName, '\d+', 'match', 'once'));
                colIdx = find(strcmp(electrode_positions, colLetter));
                
                if ~isempty(colIdx) && ~isnan(rowNum) && rowNum >= 1 && rowNum <= 16
                    frMatrix(rowNum, colIdx) = count;
                end
            end
            
            % Find top channels
            [sortedCounts, sortIdx] = sort(channelCounts, 'descend');
            topChannels = channelNames(sortIdx(1:min(nTopChannels, length(sortIdx))));
            topCounts = sortedCounts(1:min(nTopChannels, length(sortIdx)));
            
            % Spatial map with hotspots marked
            subplot(2, numPlots/2, plotIdx);
            imagesc(frMatrix);
            colormap(gca, hot); colorbar;
            hold on;
            
            for i = 1:length(topChannels)
                chName = topChannels{i};
                colLetter = regexp(chName, '[A-Z]+', 'match', 'once');
                rowNum = str2double(regexp(chName, '\d+', 'match', 'once'));
                colIdx = find(strcmp(electrode_positions, colLetter));
                
                if ~isempty(colIdx)
                    plot(colIdx, rowNum, 'wo', 'MarkerSize', 20, 'LineWidth', 2);
                    text(colIdx, rowNum, sprintf('%d', i), 'Color', 'w', ...
                         'HorizontalAlignment', 'center', 'FontWeight', 'bold');
                end
            end
            hold off;
            
            set(gca, 'XTick', 1:16, 'XTickLabel', electrode_positions, 'FontSize', 7);
            set(gca, 'YTick', 1:16);
            title(sprintf('Fast Ripple Spatial Map\n(Top %d hotspots circled)', nTopChannels), 'FontSize', 10);
            axis square;
            plotIdx = plotIdx + 1;
            
            % Bar chart
            subplot(2, numPlots/2, plotIdx);
            barh(flipud(topCounts), 'FaceColor', [0.3 0.3 0.8]);
            set(gca, 'YTick', 1:length(topChannels), 'YTickLabel', flipud(topChannels));
            xlabel('HFO Count');
            title('Top Fast Ripple Hotspots', 'FontSize', 10);
            grid on;
            
            addStatus(sprintf('  Fast Ripple Hotspots: %s', strjoin(topChannels(1:min(5,end))', ', ')));
        end
        
        sgtitle('HFO Hotspot Analysis - Channels with Highest HFO Rates', ...
                'FontSize', 14, 'FontWeight', 'bold');
        
        saveas(fig_hotspot, fullfile(outputFolder, 'HFO_Hotspot_Analysis.png'));
        saveas(fig_hotspot, fullfile(outputFolder, 'HFO_Hotspot_Analysis.fig'));
        
        addStatus('Hotspot analysis complete!');
    end
    
    function events = detectHFOEvents(signal, samplingRate, lowFreq, highFreq, ...
                                       threshold, minDur, maxDur, minOsc)
        % Detect HFO events in a single channel
        % Returns structure array with event properties
        
        events = struct('startTime', {}, 'endTime', {}, 'duration', {}, ...
                        'amplitude', {}, 'peakTime', {}, 'oscillations', {});
        
        % Design bandpass filter
        try
            [b, a] = butter(4, [lowFreq highFreq] / (samplingRate/2), 'bandpass');
            
            % Filter signal
            filteredSig = filtfilt(b, a, signal);
            
            % Compute envelope using Hilbert transform
            envelope = abs(hilbert(filteredSig));
            
            % Compute baseline statistics (using median for robustness)
            baseline = median(envelope);
            noiseSD = median(abs(envelope - baseline)) * 1.4826;  % Robust SD estimate
            
            % Detection threshold
            detThreshold = baseline + threshold * noiseSD;
            
            % Find threshold crossings
            aboveThresh = envelope > detThreshold;
            
            % Find event boundaries
            diffSignal = diff([0; aboveThresh; 0]);
            eventStarts = find(diffSignal == 1);
            eventEnds = find(diffSignal == -1) - 1;
            
            % Process each candidate event
            for i = 1:length(eventStarts)
                startIdx = eventStarts(i);
                endIdx = eventEnds(i);
                
                % Calculate duration
                duration = (endIdx - startIdx + 1) / samplingRate;
                
                % Check duration criteria
                if duration < minDur || duration > maxDur
                    continue;
                end
                
                % Extract event segment
                eventSig = filteredSig(startIdx:endIdx);
                
                % Count oscillations (zero crossings / 2)
                zeroCrossings = sum(abs(diff(sign(eventSig))) > 0);
                oscillations = zeroCrossings / 2;
                
                % Check oscillation criteria
                if oscillations < minOsc
                    continue;
                end
                
                % Calculate amplitude (peak-to-peak of filtered signal)
                amplitude = max(eventSig) - min(eventSig);
                
                % Find peak time
                [~, peakIdx] = max(envelope(startIdx:endIdx));
                peakTime = (startIdx + peakIdx - 1) / samplingRate;
                
                % Store event
                event = struct();
                event.startTime = startIdx / samplingRate;
                event.endTime = endIdx / samplingRate;
                event.duration = duration;
                event.amplitude = amplitude;
                event.peakTime = peakTime;
                event.oscillations = oscillations;
                
                events(end+1) = event;
            end
            
        catch ME
            % Return empty if filtering fails
            warning('HFO detection failed for channel: %s', ME.message);
        end
    end
    
    function createHFOSpatialMap(summaryTable, params, outputFolder)
        % Create spatial map of HFO rates
        
        fig_spatial = figure('Name', 'HFO Spatial Distribution', ...
                             'Position', [100 100 1200 500], 'Color', 'white');
        
        % Get electrode positions
        electrode_positions = {'A','B','C','D','E','F','G','H','J','K','L','M','N','O','P','R'};
        
        numPlots = 0;
        if params.bandChoice == 1 || params.bandChoice == 3
            numPlots = numPlots + 1;
        end
        if params.bandChoice == 2 || params.bandChoice == 3
            numPlots = numPlots + 1;
        end
        
        plotIdx = 1;
        
        % Ripple map
        if params.bandChoice == 1 || params.bandChoice == 3
            subplot(1, numPlots, plotIdx);
            rateMatrix = createRateMatrix(summaryTable, 'Ripple_Rate', electrode_positions);
            
            imagesc(rateMatrix);
            colormap(gca, hot);
            colorbar;
            
            set(gca, 'XTick', 1:16, 'XTickLabel', electrode_positions);
            set(gca, 'YTick', 1:16, 'YTickLabel', 1:16);
            xlabel('Column'); ylabel('Row');
            title(sprintf('Ripple Rate (%.0f-%.0f Hz)\nevents/min', ...
                  params.rippleLow, params.rippleHigh), 'FontSize', 12);
            axis square;
            
            plotIdx = plotIdx + 1;
        end
        
        % Fast Ripple map
        if params.bandChoice == 2 || params.bandChoice == 3
            subplot(1, numPlots, plotIdx);
            rateMatrix = createRateMatrix(summaryTable, 'FastRipple_Rate', electrode_positions);
            
            imagesc(rateMatrix);
            colormap(gca, hot);
            colorbar;
            
            set(gca, 'XTick', 1:16, 'XTickLabel', electrode_positions);
            set(gca, 'YTick', 1:16, 'YTickLabel', 1:16);
            xlabel('Column'); ylabel('Row');
            title(sprintf('Fast Ripple Rate (%.0f-%.0f Hz)\nevents/min', ...
                  params.fastRippleLow, params.fastRippleHigh), 'FontSize', 12);
            axis square;
        end
        
        sgtitle('HFO Spatial Distribution', 'FontSize', 14, 'FontWeight', 'bold');
        
        % Save figure
        saveas(fig_spatial, fullfile(outputFolder, 'HFO_SpatialMap.png'));
        saveas(fig_spatial, fullfile(outputFolder, 'HFO_SpatialMap.fig'));
    end
    
    function rateMatrix = createRateMatrix(summaryTable, rateColumn, electrode_positions)
        % Create 16x16 matrix of HFO rates
        rateMatrix = zeros(16, 16);
        
        for i = 1:height(summaryTable)
            channelName = summaryTable.Channel{i};
            rate = summaryTable.(rateColumn)(i);
            
            % Parse channel name
            colLetter = regexp(channelName, '[A-Z]+', 'match', 'once');
            rowNum = str2double(regexp(channelName, '\d+', 'match', 'once'));
            
            colIdx = find(strcmp(electrode_positions, colLetter));
            
            if ~isempty(colIdx) && ~isnan(rowNum) && rowNum >= 1 && rowNum <= 16
                rateMatrix(rowNum, colIdx) = rate;
            end
        end
    end
    
    function createHFORateHistogram(summaryTable, params, outputFolder)
        % Create histogram of HFO rates
        
        fig_hist = figure('Name', 'HFO Rate Distribution', ...
                          'Position', [100 100 1000 400], 'Color', 'white');
        
        numPlots = 0;
        if params.bandChoice == 1 || params.bandChoice == 3
            numPlots = numPlots + 1;
        end
        if params.bandChoice == 2 || params.bandChoice == 3
            numPlots = numPlots + 1;
        end
        
        plotIdx = 1;
        
        % Ripple histogram
        if params.bandChoice == 1 || params.bandChoice == 3
            subplot(1, numPlots, plotIdx);
            
            rates = summaryTable.Ripple_Rate;
            rates = rates(rates > 0);  % Only channels with events
            
            if ~isempty(rates)
                histogram(rates, 20, 'FaceColor', [0.8 0.2 0.2], 'EdgeColor', 'none');
                xlabel('Ripple Rate (events/min)');
                ylabel('Number of Channels');
                title(sprintf('Ripple Rate Distribution\n(%.0f-%.0f Hz)', ...
                      params.rippleLow, params.rippleHigh));
                
                % Add statistics
                meanRate = mean(rates);
                medianRate = median(rates);
                text(0.95, 0.95, sprintf('Mean: %.2f\nMedian: %.2f\nn=%d', ...
                     meanRate, medianRate, length(rates)), ...
                     'Units', 'normalized', 'HorizontalAlignment', 'right', ...
                     'VerticalAlignment', 'top', 'FontSize', 10);
            else
                text(0.5, 0.5, 'No ripples detected', ...
                     'HorizontalAlignment', 'center', 'FontSize', 12);
            end
            
            plotIdx = plotIdx + 1;
        end
        
        % Fast Ripple histogram
        if params.bandChoice == 2 || params.bandChoice == 3
            subplot(1, numPlots, plotIdx);
            
            rates = summaryTable.FastRipple_Rate;
            rates = rates(rates > 0);
            
            if ~isempty(rates)
                histogram(rates, 20, 'FaceColor', [0.2 0.2 0.8], 'EdgeColor', 'none');
                xlabel('Fast Ripple Rate (events/min)');
                ylabel('Number of Channels');
                title(sprintf('Fast Ripple Rate Distribution\n(%.0f-%.0f Hz)', ...
                      params.fastRippleLow, params.fastRippleHigh));
                
                meanRate = mean(rates);
                medianRate = median(rates);
                text(0.95, 0.95, sprintf('Mean: %.2f\nMedian: %.2f\nn=%d', ...
                     meanRate, medianRate, length(rates)), ...
                     'Units', 'normalized', 'HorizontalAlignment', 'right', ...
                     'VerticalAlignment', 'top', 'FontSize', 10);
            else
                text(0.5, 0.5, 'No fast ripples detected', ...
                     'HorizontalAlignment', 'center', 'FontSize', 12);
            end
        end
        
        sgtitle('HFO Rate Distributions', 'FontSize', 14, 'FontWeight', 'bold');
        
        % Save figure
        saveas(fig_hist, fullfile(outputFolder, 'HFO_RateDistribution.png'));
        saveas(fig_hist, fullfile(outputFolder, 'HFO_RateDistribution.fig'));
    end
    
    function createHFOExamplePlot(filteredChannelData, hfoResults, summaryTable, ...
                                   samplingRate, params, hfoType, outputFolder)
        % Create example plots of HFO events with time-frequency spectrograms
        % Uses baseline-normalized power for better visualization
        % Each event shows: top = raw + filtered trace, bottom = spectrogram
        
        % Determine which rate column to use
        if strcmp(hfoType, 'Ripple')
            rateCol = 'Ripple_Rate';
            lowFreq = params.rippleLow;
            highFreq = params.rippleHigh;
            plotColor = [0.8 0.2 0.2];
            freqRange = [20 300];  % Spectrogram frequency range for ripples
        else
            rateCol = 'FastRipple_Rate';
            lowFreq = params.fastRippleLow;
            highFreq = params.fastRippleHigh;
            plotColor = [0.2 0.2 0.8];
            freqRange = [50 600];  % Spectrogram frequency range for fast ripples
        end
        
        % Find top 4 channels by rate
        [~, sortIdx] = sort(summaryTable.(rateCol), 'descend');
        topChannels = summaryTable.Channel(sortIdx(1:min(4, length(sortIdx))));
        
        % Create figure - 4 channels x 2 examples, each with trace + spectrogram
        fig_examples = figure('Name', sprintf('%s Examples with Spectrograms', hfoType), ...
                              'Position', [50 50 1600 900], 'Color', 'white');
        
        % Design filter for display
        [b, a] = butter(4, [lowFreq highFreq] / (samplingRate/2), 'bandpass');
        
        % Spectrogram parameters - shorter window for better time resolution
        windowLength = round(samplingRate * 0.010);  % 10 ms window (better for HFOs)
        overlap = round(windowLength * 0.90);        % 90% overlap for smooth display
        nfft = max(256, 2^nextpow2(windowLength * 2));  % Zero-pad for freq resolution
        
        plotIdx = 1;
        for i = 1:length(topChannels)
            channelName = topChannels{i};
            signal = filteredChannelData.(channelName);
            events = hfoResults.(channelName);
            
            if isempty(events)
                continue;
            end
            
            % Filter for display
            filteredSig = filtfilt(b, a, signal);
            
            % Plot 2 example events per channel
            numExamples = min(2, length(events));
            
            for j = 1:numExamples
                event = events(j);
                
                % Window around event (±100 ms for better spectrogram context)
                windowSamples = round(0.100 * samplingRate);
                startSample = max(1, round(event.startTime * samplingRate) - windowSamples);
                endSample = min(length(signal), round(event.endTime * samplingRate) + windowSamples);
                
                % Extract segment
                segment = signal(startSample:endSample);
                filteredSegment = filteredSig(startSample:endSample);
                timeVec = (startSample:endSample) / samplingRate * 1000;  % ms
                
                % === Top panel: Waveform ===
                subplot(8, 2, plotIdx);
                
                % Plot raw signal
                plot(timeVec, segment, 'k-', 'LineWidth', 0.5);
                hold on;
                
                % Overlay filtered signal - color the event portion red
                % Before event: gray
                eventStartSample = round(event.startTime * samplingRate);
                eventEndSample = round(event.endTime * samplingRate);
                
                % Plot filtered signal with event highlighted
                preEventIdx = find((startSample:endSample) < eventStartSample);
                eventIdx = find((startSample:endSample) >= eventStartSample & (startSample:endSample) <= eventEndSample);
                postEventIdx = find((startSample:endSample) > eventEndSample);
                
                if ~isempty(preEventIdx)
                    plot(timeVec(preEventIdx), filteredSegment(preEventIdx), 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
                end
                if ~isempty(eventIdx)
                    plot(timeVec(eventIdx), filteredSegment(eventIdx), 'Color', plotColor, 'LineWidth', 1.5);
                end
                if ~isempty(postEventIdx)
                    plot(timeVec(postEventIdx), filteredSegment(postEventIdx), 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
                end
                
                hold off;
                ylabel('µV');
                set(gca, 'XTickLabel', []);  % Remove x labels from top panel
                
                title(sprintf('%s - Event %d: %.0f ms, %.1f µV', channelName, j, ...
                      event.duration*1000, event.amplitude), 'FontSize', 9, 'FontWeight', 'bold');
                xlim([timeVec(1) timeVec(end)]);
                
                % === Bottom panel: Baseline-normalized Spectrogram ===
                subplot(8, 2, plotIdx + 2);
                
                % Compute spectrogram
                [S, F, T] = spectrogram(segment, windowLength, overlap, nfft, samplingRate);
                
                % Convert to power
                power = abs(S).^2;
                
                % Baseline normalization: use edges of window as baseline
                % (first and last 25% of time points)
                nTimePoints = size(power, 2);
                baselineIdx = [1:round(nTimePoints*0.25), round(nTimePoints*0.75):nTimePoints];
                
                % Calculate baseline mean power at each frequency
                baselinePower = mean(power(:, baselineIdx), 2);
                
                % Normalize: (power - baseline) / baseline * 100 = percent change
                % Or use Z-score: (power - mean) / std
                baselineStd = std(power(:, baselineIdx), 0, 2);
                baselineStd(baselineStd < eps) = eps;  % Avoid division by zero
                
                % Z-score normalization (shows standard deviations above baseline)
                powerNorm = (power - baselinePower) ./ baselineStd;
                
                % Adjust time vector to match segment
                T_ms = T * 1000 + timeVec(1);
                
                % Plot normalized spectrogram
                imagesc(T_ms, F, powerNorm);
                axis xy;  % Flip so low frequencies at bottom
                ylim(freqRange);
                
                % Better colormap and scaling
                colormap(gca, jet);
                
                % Scale to show -2 to +6 SD (or use percentile-based)
                caxis([-2 6]);
                
                % Add horizontal lines for target frequency band
                hold on;
                plot([T_ms(1) T_ms(end)], [lowFreq lowFreq], 'w--', 'LineWidth', 1.5);
                plot([T_ms(1) T_ms(end)], [highFreq highFreq], 'w--', 'LineWidth', 1.5);
                
                % Mark event boundaries on spectrogram
                eventStartMs = event.startTime * 1000;
                eventEndMs = event.endTime * 1000;
                plot([eventStartMs eventStartMs], freqRange, 'w-', 'LineWidth', 1.5);
                plot([eventEndMs eventEndMs], freqRange, 'w-', 'LineWidth', 1.5);
                hold off;
                
                xlabel('Time (ms)');
                ylabel('Freq (Hz)');
                xlim([timeVec(1) timeVec(end)]);
                
                % Add colorbar for first spectrogram only
                if plotIdx == 1
                    cb = colorbar('eastoutside');
                    cb.Label.String = 'Power (Z-score)';
                    cb.FontSize = 7;
                end
                
                plotIdx = plotIdx + 1;
            end
            
            % Move to next row (skip spectrogram row)
            plotIdx = plotIdx + 2;
        end
        
        sgtitle(sprintf('%s Examples with Time-Frequency Verification (%.0f-%.0f Hz) - Top 4 Channels\nBaseline-normalized power (Z-score) | White dashed = target band, solid = event boundaries', ...
                hfoType, lowFreq, highFreq), 'FontSize', 12, 'FontWeight', 'bold');
        
        % Save figure
        saveas(fig_examples, fullfile(outputFolder, sprintf('HFO_%s_Examples.png', hfoType)));
        saveas(fig_examples, fullfile(outputFolder, sprintf('HFO_%s_Examples.fig', hfoType)));
    end
    
    % ==================== TOOL LAUNCHERS ====================
    
    function launchLayerDicGenerator(~, ~)
        % Launch the LayerDic Generator tool in a new figure
        addStatus('Launching LayerDic Generator...');
        try
            layerDicGeneratorTool();
            addStatus('LayerDic Generator opened');
        catch ME
            addStatus(['ERROR launching LayerDic Generator: ' ME.message]);
        end
    end
    
    function pcaSpikeSorting(~, ~)
    % =========================================================
    % PER-CHANNEL PCA SPIKE SORTING
    % Extracts spike snippets per channel, PCA, k-means k=2,
    % Silhouette score to assess cluster separability.
    % Useful to detect if 2 units can be isolated on one electrode.
    % =========================================================
    addStatus('========================================');
    addStatus('Starting PCA Spike Sorting...');
    addStatus('========================================');

    spikeData           = getappdata(fig, 'spikeData');
    filteredChannelData = getappdata(fig, 'filteredChannelData');
    samplingRate        = getappdata(fig, 'samplingRate');
    outputFolder        = getappdata(fig, 'outputFolder');
    electrodeLayerMap   = getappdata(fig, 'electrodeLayerMap');

    if isempty(spikeData)
        addStatus('ERROR: Run spike detection first.'); return;
    end
    if isempty(filteredChannelData)
        addStatus('ERROR: No filtered signal available.'); return;
    end

    sortedChannels = sort(fieldnames(spikeData));

    % --- Parameter dialog ---
    defaults = {'0.5', '1.5', '30', '0.35', '0.90', '0.20', 'All'};
    prompt = {'Pre-spike window (ms):', ...
              'Post-spike window (ms):', ...
              'Min spikes for sorting:', ...
              'Min silhouette to flag as separable:', ...
              'Max amplitude ratio min/max (<1 = more different)  [0.70 = >30% diff]:', ...
              'Min cluster size ratio (smaller/larger, 0-1):', ...
              'Channel to plot (e.g. C8), or ''All'' for summary only:'};
    answer = inputdlg(prompt, 'PCA Spike Sorting Parameters', 1, defaults);
    if isempty(answer), addStatus('Cancelled.'); return; end

    preMs        = str2double(answer{1});
    postMs       = str2double(answer{2});
    minSpikes    = str2double(answer{3});
    minSil       = str2double(answer{4});
    maxAmpRatio  = str2double(answer{5});  % min(|A1|,|A2|)/max(|A1|,|A2|), lower = more different
    minSizeRatio = str2double(answer{6});  % smaller cluster / larger cluster
    targetCh     = strtrim(answer{7});

    preSamples  = round(preMs  / 1000 * samplingRate);
    postSamples = round(postMs / 1000 * samplingRate);
    snippetLen  = preSamples + postSamples + 1;
    timeAxis_ms = (-preSamples:postSamples) / samplingRate * 1000;

    % Output folder
    sortFolder = fullfile(outputFolder, 'PCA_SpikeSorting');
    if ~exist(sortFolder, 'dir'), mkdir(sortFolder); end
    figFolder  = fullfile(sortFolder, 'Figures');
    if ~exist(figFolder, 'dir'), mkdir(figFolder); end

    % ---- Run per channel ----
    results = struct('channel',{},'region',{},'nSpikes',{},'silhouette',{},...
                     'nCluster1',{},'nCluster2',{},...
                     'meanAmp1',{},'meanAmp2',{},'ampRatio',{},'ampDiff',{},'sizeRatio',{},'separable',{});

    allChannels = sortedChannels;
    if ~strcmp(lower(targetCh), 'all')
        % Check if requested channel exists
        if isfield(spikeData, targetCh)
            allChannels = {targetCh};
        else
            addStatus(sprintf('WARNING: Channel %s not found, running all.', targetCh));
        end
    end

    nCh = length(allChannels);
    h_wait = waitbar(0, 'PCA Spike Sorting...');

    for ci = 1:nCh
        waitbar(ci/nCh, h_wait, sprintf('Channel %d / %d', ci, nCh));
        chField = allChannels{ci};

        if ~isfield(filteredChannelData, chField), continue; end
        signal   = filteredChannelData.(chField);
        spkTimes = spikeData.(chField).times;
        nSpk     = length(spkTimes);

        if nSpk < minSpikes, continue; end

        % Convert to sample indices
        spkIdx = round(spkTimes * samplingRate);
        valid  = spkIdx > preSamples & spkIdx <= length(signal) - postSamples;
        spkIdx = spkIdx(valid);
        if length(spkIdx) < minSpikes, continue; end

        % Extract snippets
        snippets = zeros(length(spkIdx), snippetLen);
        amps     = zeros(length(spkIdx), 1);
        for si = 1:length(spkIdx)
            snip = signal(spkIdx(si)-preSamples : spkIdx(si)+postSamples);
            snippets(si,:) = snip;
            amps(si) = min(snip);   % trough amplitude
        end

        % Normalize each snippet to unit trough
        troughVals = min(snippets, [], 2);
        snipNorm   = snippets ./ (abs(troughVals) + eps);

        % PCA
        try
            [~, score, ~, ~, explained] = pca(snipNorm, 'NumComponents', 3);
        catch
            continue;
        end
        if size(score,2) < 2, continue; end

        % k-means k=2, 10 replicates
        try
            [labels, ~] = kmeans(score(:,1:2), 2, 'Replicates', 10, 'Display', 'off');
        catch
            continue;
        end

        % Silhouette score
        try
            silVals = silhouette(score(:,1:2), labels);
            silMean = mean(silVals);
        catch
            silMean = NaN;
        end

        % Cluster stats
        cl1 = labels == 1;
        cl2 = labels == 2;
        n1  = sum(cl1); n2 = sum(cl2);
        amp1 = mean(amps(cl1)); amp2 = mean(amps(cl2));

        % Region
        regionStr = 'Unknown';
        if ~isempty(electrodeLayerMap) && isKey(electrodeLayerMap, chField)
            regionStr = cortexLayerName(electrodeLayerMap(chField));
        end

        % Additional separability criteria
        ampDiff   = abs(amp1 - amp2);
        ampRatio  = min(abs(amp1),abs(amp2)) / (max(abs(amp1),abs(amp2)) + eps);
        sizeRatio = min(n1,n2) / max(n1,n2+eps);
        isSeparable = silMean >= minSil && ampRatio <= maxAmpRatio && sizeRatio >= minSizeRatio;

        ri = length(results) + 1;
        results(ri).channel   = chField;
        results(ri).region    = regionStr;
        results(ri).nSpikes   = length(spkIdx);
        results(ri).silhouette = silMean;
        results(ri).nCluster1 = n1;
        results(ri).nCluster2 = n2;
        results(ri).meanAmp1  = amp1;
        results(ri).meanAmp2  = amp2;
        results(ri).ampRatio  = ampRatio;
        results(ri).ampDiff   = ampDiff;
        results(ri).sizeRatio = sizeRatio;
        results(ri).separable = isSeparable;

        % Generate figure if: single channel requested OR all criteria met
        doFig = strcmp(lower(targetCh), 'all') && isSeparable;
        doFig = doFig || (~strcmp(lower(targetCh), 'all') && strcmpi(chField, targetCh));

        if doFig
            colC1 = [0.85 0.15 0.15];
            colC2 = [0.15 0.40 0.80];

            hFig = figure('Position', [50 50 1400 420], 'Color', 'w', 'Visible', 'off', ...
                          'Name', sprintf('PCA Spike Sorting - %s', chField));
            tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

            % Panel 1: PC1 vs PC2
            nexttile;
            scatter(score(cl1,1), score(cl1,2), 18, colC1, 'filled', 'MarkerFaceAlpha', 0.5); hold on;
            scatter(score(cl2,1), score(cl2,2), 18, colC2, 'filled', 'MarkerFaceAlpha', 0.5);
            xlabel(sprintf('PC1 (%.1f%%)', explained(1)));
            ylabel(sprintf('PC2 (%.1f%%)', explained(2)));
            title(sprintf('%s  |  Silhouette = %.3f', chField, silMean));
            legend({'Cluster 1','Cluster 2'}, 'Location', 'best');
            grid on; hold off;

            % Panel 2: Mean waveforms ± std
            nexttile;
            mean1 = mean(snippets(cl1,:), 1);
            std1  = std(snippets(cl1,:), 0, 1);
            mean2 = mean(snippets(cl2,:), 1);
            std2  = std(snippets(cl2,:), 0, 1);

            fill([timeAxis_ms fliplr(timeAxis_ms)], ...
                 [mean1+std1 fliplr(mean1-std1)], colC1, ...
                 'FaceAlpha', 0.2, 'EdgeColor', 'none'); hold on;
            fill([timeAxis_ms fliplr(timeAxis_ms)], ...
                 [mean2+std2 fliplr(mean2-std2)], colC2, ...
                 'FaceAlpha', 0.2, 'EdgeColor', 'none');
            plot(timeAxis_ms, mean1, 'Color', colC1, 'LineWidth', 2);
            plot(timeAxis_ms, mean2, 'Color', colC2, 'LineWidth', 2);
            xline(0, 'k--');
            xlabel('Time (ms)'); ylabel('Amplitude (µV)');
            title(sprintf('Mean Waveforms  (n=%d / n=%d)', n1, n2));
            legend({'Cluster 1','Cluster 2'}, 'Location', 'best');
            grid on; hold off;

            % Panel 3: Amplitude histogram
            nexttile;
            allEdges = linspace(min(amps)*1.1, max(amps)*0.9, 30);
            histogram(amps(cl1), allEdges, 'FaceColor', colC1, 'FaceAlpha', 0.7, 'EdgeColor', 'none'); hold on;
            histogram(amps(cl2), allEdges, 'FaceColor', colC2, 'FaceAlpha', 0.7, 'EdgeColor', 'none');
            xlabel('Trough Amplitude (µV)'); ylabel('Count');
            title(sprintf('Amplitude Distribution  (%.1f / %.1f µV)', amp1, amp2));
            legend({'Cluster 1','Cluster 2'}, 'Location', 'best');
            grid on; hold off;

            sgtitle(sprintf('PCA Spike Sorting — %s  |  Region: %s  |  Sil=%.3f  AmpRatio=%.2f (%.0f%% diff)  SizeRatio=%.2f  |  %s', ...
                chField, regionStr, silMean, ampRatio, (1-ampRatio)*100, sizeRatio, ...
                ternaryStr(isSeparable, '✓ SEPARABLE', '✗ not separable')), ...
                'FontSize', 12, 'FontWeight', 'bold');

            fname = fullfile(figFolder, sprintf('SpikeSorting_%s', chField));
            print(hFig, fname, '-dpng', '-r200');
            set(hFig, 'Visible', 'on');
            savefig(hFig, [fname '.fig']);
            if ~strcmp(lower(targetCh), 'all')
                % Keep figure open for single-channel inspection
            else
                close(hFig);
            end
        end
    end
    close(h_wait);

    if isempty(results)
        addStatus('No channels met the minimum spike count threshold.'); return;
    end

    % Sort by silhouette descending
    [~, sidx] = sort([results.silhouette], 'descend');
    results    = results(sidx);

    nSep = sum([results.separable]);
    addStatus(sprintf('PCA Spike Sorting complete: %d / %d channels separable', nSep, length(results)));
    addStatus(sprintf('  Criteria: Sil ≥ %.2f  +  AmpRatio ≤ %.2f (>%.0f%% amp diff)  +  SizeRatio ≥ %.2f', ...
        minSil, maxAmpRatio, (1-maxAmpRatio)*100, minSizeRatio));

    % Top 5 separable, then top 5 overall by silhouette
    sepIdx = find([results.separable]);
    if ~isempty(sepIdx)
        addStatus(sprintf('Separable channels (%d):', length(sepIdx)));
        for ri = 1:min(10, length(sepIdx))
            idx = sepIdx(ri);
            addStatus(sprintf('  ✓ %s [%s]: Sil=%.3f  AmpRatio=%.2f (%.0f%% diff)  SizeRatio=%.2f  n=%d+%d', ...
                results(idx).channel, results(idx).region, results(idx).silhouette, ...
                results(idx).ampRatio, (1-results(idx).ampRatio)*100, results(idx).sizeRatio, ...
                results(idx).nCluster1, results(idx).nCluster2));
        end
    else
        addStatus('No channels met all separability criteria.');
        addStatus('Top 5 by silhouette (not separable):');
        for ri = 1:min(5, length(results))
            addStatus(sprintf('  %s [%s]: Sil=%.3f  AmpRatio=%.2f (%.0f%% diff)  SizeRatio=%.2f', ...
                results(ri).channel, results(ri).region, results(ri).silhouette, ...
                results(ri).ampRatio, (1-results(ri).ampRatio)*100, results(ri).sizeRatio));
        end
    end

    % Save Excel summary
    try
        T = table({results.channel}', {results.region}', [results.nSpikes]', ...
            [results.silhouette]', [results.ampRatio]', [results.ampDiff]', [results.sizeRatio]', [results.separable]', ...
            [results.nCluster1]', [results.nCluster2]', ...
            [results.meanAmp1]', [results.meanAmp2]', ...
            'VariableNames', {'Channel','Region','nSpikes','Silhouette', ...
            'AmpRatio','AmpDiff_uV','SizeRatio','Separable', ...
            'nCluster1','nCluster2','MeanAmp1_uV','MeanAmp2_uV'});
        writetable(T, fullfile(sortFolder, 'PCA_SpikeSorting_Summary.xlsx'));
        addStatus(['Summary saved: ' fullfile(sortFolder, 'PCA_SpikeSorting_Summary.xlsx')]);
    catch ME
        addStatus(['Warning: Could not save Excel: ' ME.message]);
    end
    end  % pcaSpikeSorting

    function s = ternaryStr(cond, a, b)
        if cond, s = a; else, s = b; end
    end

        function classifyCellTypes(~, ~)
    % =========================================================
    % CELL-TYPE CLASSIFICATION (CellExplorer-style)
    % Narrow Interneuron vs Broad Pyramidal via:
    %   - Trough-to-peak duration (primary classifier)
    %   - Half-width at half-trough amplitude
    %   - Peak asymmetry
    %   - Repolarization slope
    %   - Autocorrelogram (tau_rise, burst index)
    % =========================================================
    addStatus('========================================');
    addStatus('Starting Cell-Type Classification...');
    addStatus('========================================');

    % --- Get data from appdata ---
    spikeData          = getappdata(fig, 'spikeData');
    filteredChannelData = getappdata(fig, 'filteredChannelData');
    samplingRate       = getappdata(fig, 'samplingRate');
    totalDuration      = getappdata(fig, 'totalDuration');
    outputFolder       = getappdata(fig, 'outputFolder');
    figuresFolder      = getappdata(fig, 'figuresFolder');
    electrodeLayerMap  = getappdata(fig, 'electrodeLayerMap');

    if isempty(spikeData)
        addStatus('ERROR: Please run spike detection first'); return;
    end
    if isempty(filteredChannelData)
        addStatus('ERROR: No filtered signal data available'); return;
    end

    % --- Parameter dialog ---
    defaults = {'0.425', '0.5', '1.5', '200', '500', '1'};
    prompt = { ...
        'Trough-to-Peak threshold (ms)  [Narrow < threshold < Broad]:', ...
        'Pre-spike window (ms):', ...
        'Post-spike window (ms):', ...
        'Max spikes per channel for averaging:', ...
        'ACG window (ms, half-width):', ...
        'ACG bin size (ms):'};
    answer = inputdlg(prompt, 'Cell-Type Classification Parameters', 1, defaults);
    if isempty(answer), addStatus('Cancelled.'); return; end

    params.ttpThreshold  = str2double(answer{1});
    params.preSpike_ms   = str2double(answer{2});
    params.postSpike_ms  = str2double(answer{3});
    params.maxSpikes     = str2double(answer{4});
    params.acgWindow_ms  = str2double(answer{5});
    params.acgBin_ms     = str2double(answer{6});

    preSamples  = round(params.preSpike_ms  / 1000 * samplingRate);
    postSamples = round(params.postSpike_ms / 1000 * samplingRate);
    snippetLen  = preSamples + postSamples + 1;
    timeAxis_ms = (-preSamples:postSamples) / samplingRate * 1000;

    % ACG setup
    acgEdges    = -params.acgWindow_ms : params.acgBin_ms : params.acgWindow_ms;
    acgCenters_ms = (acgEdges(1:end-1) + acgEdges(2:end)) / 2;
    acgBins     = length(acgCenters_ms) / 2;   % half-window index

    % --- Output folder ---
    cellFolder = fullfile(outputFolder, 'Cell_Classification');
    if ~exist(cellFolder, 'dir'), mkdir(cellFolder); end
    figFolder  = fullfile(cellFolder, 'Figures');
    if ~exist(figFolder, 'dir'), mkdir(figFolder); end

    % Interpolation factor for sub-sample TTP precision
    interpFactor = 10;

    sortedChannels = sort(fieldnames(spikeData));
    nCh = length(sortedChannels);

    % Pre-allocate metrics struct
    cellMetrics.channel       = {};
    cellMetrics.nSpikes       = [];
    cellMetrics.meanWaveform  = {};
    cellMetrics.troughToPeak_ms  = [];
    cellMetrics.halfWidth_ms  = [];
    cellMetrics.peakAsymmetry = [];
    cellMetrics.repolarSlope  = [];
    cellMetrics.troughAmplitude = [];
    cellMetrics.firingRate    = [];
    cellMetrics.acg           = {};
    cellMetrics.acgTauRise    = [];
    cellMetrics.burstIndex    = [];
    cellMetrics.cellType      = {};
    cellMetrics.region        = {};

    nValid = 0;
    h_wait = waitbar(0, 'Extracting waveforms...');

    for ci = 1:nCh
        waitbar(ci/nCh, h_wait, sprintf('Waveform %d / %d', ci, nCh));
        chField = sortedChannels{ci};

        if ~isfield(filteredChannelData, chField), continue; end
        signal    = filteredChannelData.(chField);
        spkTimes  = spikeData.(chField).times;   % in seconds
        nSpk      = length(spkTimes);

        if nSpk < 5, continue; end   % need enough spikes for a stable mean

        % Convert spike times to sample indices
        spkIdx = round(spkTimes * samplingRate);
        spkIdx = spkIdx(spkIdx > preSamples & spkIdx <= length(signal) - postSamples);
        if isempty(spkIdx), continue; end

        % Limit spikes for averaging
        if length(spkIdx) > params.maxSpikes
            randSel = randperm(length(spkIdx), params.maxSpikes);
            spkIdx  = spkIdx(randSel);
        end

        % Extract snippets and compute mean waveform
        snippets = zeros(length(spkIdx), snippetLen);
        for si = 1:length(spkIdx)
            snippets(si,:) = signal(spkIdx(si)-preSamples : spkIdx(si)+postSamples);
        end
        meanWF = mean(snippets, 1);

        % --- Interpolate for sub-sample precision ---
        tv_orig   = timeAxis_ms;
        tv_interp = linspace(tv_orig(1), tv_orig(end), snippetLen * interpFactor);
        wf_interp = interp1(tv_orig, meanWF, tv_interp, 'spline');

        % 1. Trough (minimum)
        [troughVal, troughIdx] = min(wf_interp);
        troughTime = tv_interp(troughIdx);

        % 2. Peak after trough
        afterTrough  = wf_interp(troughIdx:end);
        afterTime    = tv_interp(troughIdx:end);
        [peakAfterVal, peakAfterIdx] = max(afterTrough);
        peakAfterTime = afterTime(peakAfterIdx);

        % 3. Trough-to-peak
        ttp_ms = peakAfterTime - troughTime;

        % 4. Peak before trough
        [peakBeforeVal, ~] = max(wf_interp(1:troughIdx));

        % 5. Peak asymmetry
        peakAsym = (peakAfterVal - peakBeforeVal) / (abs(peakAfterVal) + abs(peakBeforeVal) + eps);

        % 6. Half-width at half-trough
        halfAmp   = troughVal / 2;
        belowHalf = wf_interp < halfAmp;
        crossings = diff(belowHalf);
        startCross = find(crossings == 1,  1, 'first');
        endCross   = find(crossings == -1, 1, 'last');
        if ~isempty(startCross) && ~isempty(endCross) && endCross > startCross
            hw_ms = tv_interp(endCross) - tv_interp(startCross);
        else
            hw_ms = NaN;
        end

        % 7. Repolarization slope
        if ttp_ms > 0
            repSlope = (peakAfterVal - troughVal) / ttp_ms;
        else
            repSlope = NaN;
        end

        % --- Autocorrelogram ---
        spkT_sec = sort(spikeData.(chField).times);
        if length(spkT_sec) >= 10
            acgCounts = zeros(1, length(acgEdges)-1);
            for si = 1:length(spkT_sec)
                diffs = spkT_sec - spkT_sec(si);
                diffs = diffs(diffs ~= 0);
                validDiffs = diffs(abs(diffs) <= params.acgWindow_ms/1000);
                if ~isempty(validDiffs)
                    acgCounts = acgCounts + histcounts(validDiffs*1000, acgEdges);
                end
            end
            acgRate = acgCounts / length(spkT_sec) / (params.acgBin_ms/1000);

            halfACG  = acgRate(acgBins+1:end);
            halfTime = acgCenters_ms(acgBins+1:end);

            tauRise  = NaN;
            burstIdx = NaN;
            if length(halfACG) >= 5 && max(halfACG) > 0
                try
                    normACG = halfACG / max(halfACG);
                    ft = fit(halfTime(:), normACG(:), '1-a*exp(-x/b)', ...
                        'StartPoint', [1, 10], 'Lower', [0, 0.5], 'Upper', [2, 500]);
                    tauRise = ft.b;
                catch
                end
                burst3_6     = mean(halfACG(halfTime >= 3   & halfTime <= 6));
                burst100_200 = mean(halfACG(halfTime >= 100 & halfTime <= 200));
                if burst100_200 > 0
                    burstIdx = burst3_6 / burst100_200;
                end
            end
        else
            acgRate  = zeros(1, length(acgEdges)-1);
            tauRise  = NaN;
            burstIdx = NaN;
        end

        % --- Classify ---
        if ttp_ms < params.ttpThreshold
            cellType = 'Narrow Interneuron';
        else
            cellType = 'Broad Pyramidal';
        end

        % --- Region assignment ---
        nValid = nValid + 1;
        cellMetrics.channel{nValid}          = chField;
        cellMetrics.nSpikes(nValid)          = nSpk;
        cellMetrics.meanWaveform{nValid}     = meanWF;
        cellMetrics.troughToPeak_ms(nValid)  = ttp_ms;
        cellMetrics.halfWidth_ms(nValid)     = hw_ms;
        cellMetrics.peakAsymmetry(nValid)    = peakAsym;
        cellMetrics.repolarSlope(nValid)     = repSlope;
        cellMetrics.troughAmplitude(nValid)  = troughVal;
        cellMetrics.firingRate(nValid)       = nSpk / totalDuration;
        cellMetrics.acg{nValid}              = acgRate;
        cellMetrics.acgTauRise(nValid)       = tauRise;
        cellMetrics.burstIndex(nValid)       = burstIdx;
        cellMetrics.cellType{nValid}         = cellType;

        % Region from electrodeLayerMap
        regionStr = 'Unknown';
        if ~isempty(electrodeLayerMap) && isKey(electrodeLayerMap, chField)
            regionStr = cortexLayerName(electrodeLayerMap(chField));
        end
        cellMetrics.region{nValid} = regionStr;
    end
    close(h_wait);

    if nValid == 0
        addStatus('ERROR: No valid waveforms extracted. Check that filteredChannelData is available.');
        return;
    end

    % --- Summary ---
    isNarrow = strcmp(cellMetrics.cellType, 'Narrow Interneuron');
    isBroad  = strcmp(cellMetrics.cellType, 'Broad Pyramidal');
    nNarrow  = sum(isNarrow);
    nBroad   = sum(isBroad);

    addStatus(sprintf('Classified %d channels:', nValid));
    addStatus(sprintf('  Narrow Interneurons: %d (%.1f%%)', nNarrow, 100*nNarrow/nValid));
    addStatus(sprintf('  Broad Pyramidal:     %d (%.1f%%)', nBroad,  100*nBroad/nValid));
    addStatus(sprintf('  TTP range: %.3f – %.3f ms  (median: %.3f ms)', ...
        min(cellMetrics.troughToPeak_ms), max(cellMetrics.troughToPeak_ms), ...
        median(cellMetrics.troughToPeak_ms)));
    addStatus(sprintf('  TTP threshold used: %.3f ms', params.ttpThreshold));

    cellMetrics.params        = params;
    cellMetrics.timeAxis_ms   = timeAxis_ms;
    cellMetrics.acgCenters_ms = acgCenters_ms;
    cellMetrics.samplingRate  = samplingRate;

    % --- FIGURE 1: Waveform gallery + TTP histogram + ACG ---
    colNarrow = [0.80 0.18 0.18];
    colBroad  = [0.18 0.38 0.75];

    hFig1 = figure('Position', [30 30 1600 900], 'Color', 'w', 'Visible', 'off', ...
                   'Name', 'Cell-Type Classification');
    tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

    % Panel 1: All waveforms overlay
    nexttile;
    hold on;
    for wi = 1:nValid
        wf = cellMetrics.meanWaveform{wi};
        wfN = wf / (abs(min(wf)) + eps);
        if isNarrow(wi)
            plot(timeAxis_ms, wfN, 'Color', [colNarrow 0.12], 'LineWidth', 0.5);
        else
            plot(timeAxis_ms, wfN, 'Color', [colBroad  0.12], 'LineWidth', 0.5);
        end
    end
    if nNarrow > 0
        allN = cellfun(@(x) x/max(abs(x)+eps), cellMetrics.meanWaveform(isNarrow), 'UniformOutput', false);
        plot(timeAxis_ms, mean(cat(1, allN{:}), 1), 'Color', colNarrow, 'LineWidth', 2.5);
    end
    if nBroad > 0
        allB = cellfun(@(x) x/max(abs(x)+eps), cellMetrics.meanWaveform(isBroad),  'UniformOutput', false);
        plot(timeAxis_ms, mean(cat(1, allB{:}), 1), 'Color', colBroad,  'LineWidth', 2.5);
    end
    xlabel('Time (ms)'); ylabel('Norm. Amplitude');
    title(sprintf('Mean Waveforms (Narrow n=%d, Broad n=%d)', nNarrow, nBroad));
    legend({'Narrow (mean)','Broad (mean)'}, 'Location', 'best');
    xline(0, 'k--', 'LineWidth', 1); grid on; hold off;

    % Panel 2: TTP histogram
    nexttile;
    ttpN = cellMetrics.troughToPeak_ms(isNarrow);
    ttpB = cellMetrics.troughToPeak_ms(isBroad);
    edges = linspace(min(cellMetrics.troughToPeak_ms)*0.8, max(cellMetrics.troughToPeak_ms)*1.2, 25);
    histogram(ttpN, edges, 'FaceColor', colNarrow, 'EdgeColor', 'none', 'FaceAlpha', 0.7); hold on;
    histogram(ttpB, edges, 'FaceColor', colBroad,  'EdgeColor', 'none', 'FaceAlpha', 0.7);
    xline(params.ttpThreshold, 'k--', 'LineWidth', 2, 'Label', sprintf('%.3f ms', params.ttpThreshold));
    xlabel('Trough-to-Peak (ms)'); ylabel('Count');
    title('TTP Distribution'); legend({'Narrow','Broad'}); grid on; hold off;

    % Panel 3: TTP vs Firing Rate scatter
    nexttile;
    scatter(cellMetrics.troughToPeak_ms(isNarrow), cellMetrics.firingRate(isNarrow), ...
        40, colNarrow, 'filled', 'MarkerFaceAlpha', 0.7); hold on;
    scatter(cellMetrics.troughToPeak_ms(isBroad),  cellMetrics.firingRate(isBroad), ...
        40, colBroad,  'filled', 'MarkerFaceAlpha', 0.7);
    xlabel('Trough-to-Peak (ms)'); ylabel('Firing Rate (Hz)');
    title('TTP vs Firing Rate'); legend({'Narrow','Broad'},'Location','best'); grid on; hold off;

    % Panel 4: Mean ACG – Narrow
    nexttile;
    if nNarrow > 0
        acgMat = cat(1, cellMetrics.acg{isNarrow});
        if ~isempty(acgMat)
            acgMean = mean(acgMat, 1);
            bar(acgCenters_ms, acgMean, 'FaceColor', colNarrow, 'EdgeColor', 'none');
        end
    end
    xlabel('Lag (ms)'); ylabel('Rate (Hz)'); title('ACG – Narrow Interneuron'); grid on;

    % Panel 5: Mean ACG – Broad
    nexttile;
    if nBroad > 0
        acgMat = cat(1, cellMetrics.acg{isBroad});
        if ~isempty(acgMat)
            acgMean = mean(acgMat, 1);
            bar(acgCenters_ms, acgMean, 'FaceColor', colBroad, 'EdgeColor', 'none');
        end
    end
    xlabel('Lag (ms)'); ylabel('Rate (Hz)'); title('ACG – Broad Pyramidal'); grid on;

    % Panel 6: Region breakdown
    nexttile;
    regions = unique(cellMetrics.region);
    nReg    = length(regions);
    regNarrow = zeros(nReg,1);
    regBroad  = zeros(nReg,1);
    for ri = 1:nReg
        inReg = strcmp(cellMetrics.region, regions{ri});
        regNarrow(ri) = sum(inReg(:) & isNarrow(:));
        regBroad(ri)  = sum(inReg(:) & isBroad(:));
    end
    b = bar(categorical(regions), [regNarrow, regBroad], 'stacked');
    b(1).FaceColor = colNarrow; b(2).FaceColor = colBroad;
    ylabel('Electrode count'); title('Cell Types by Region');
    legend({'Narrow','Broad'},'Location','best'); grid on;

    sgtitle(sprintf('Cell-Type Classification  |  TTP threshold = %.3f ms  |  n = %d channels', ...
        params.ttpThreshold, nValid), 'FontSize', 13, 'FontWeight', 'bold');

    print(hFig1, fullfile(figFolder, 'CellType_Classification_Overview'), '-dpng', '-r300');
    set(hFig1, 'Visible', 'on');
    savefig(hFig1, fullfile(figFolder, 'CellType_Classification_Overview.fig'));
    close(hFig1);

    % --- Excel export ---
    try
        excelFile = fullfile(cellFolder, 'CellType_Classification.xlsx');
        T = table(cellMetrics.channel', cellMetrics.region', cellMetrics.cellType', ...
            cellMetrics.troughToPeak_ms', cellMetrics.halfWidth_ms', ...
            cellMetrics.peakAsymmetry',  cellMetrics.repolarSlope', ...
            cellMetrics.troughAmplitude', cellMetrics.firingRate', ...
            cellMetrics.nSpikes',        cellMetrics.acgTauRise', ...
            cellMetrics.burstIndex', ...
            'VariableNames', {'Channel','Region','CellType', ...
            'TTP_ms','HalfWidth_ms','PeakAsymmetry','RepolarSlope_uVperms', ...
            'TroughAmplitude_uV','FiringRate_Hz','nSpikes','ACG_TauRise_ms','BurstIndex'});
        writetable(T, excelFile, 'Sheet', 'Classification');
        addStatus(['Cell classification saved: ' excelFile]);
    catch ME
        addStatus(['Warning: Could not save Excel: ' ME.message]);
    end

    % --- Save .mat ---
    try
        save(fullfile(cellFolder, 'cellMetrics.mat'), 'cellMetrics');
        addStatus('cellMetrics.mat saved');
    catch ME
        addStatus(['Warning: Could not save .mat: ' ME.message]);
    end

    addStatus('Cell-Type Classification complete.');
    end  % classifyCellTypes

        function launchChannelInspector(~, ~)
        % NEU V7: Ruft MEA_Channel_Inspector_2026_V4 (Standalone) auf.
        % Dateiname muss mit Funktionsnamen uebereinstimmen -- daher direkter Aufruf.
        addStatus('Launching Channel Inspector...');
        try
            MEA_Channel_Inspector_2026_V4();
            addStatus('Channel Inspector opened');
        catch ME
            addStatus(['Standalone nicht gefunden, nutze eingebettete Version: ' ME.message]);
            try
                channelInspectorTool();
            catch ME2
                addStatus(['ERROR launching Channel Inspector: ' ME2.message]);
            end
        end
    end
    
    % ==================== CALLBACK: Reset GUI ====================
    
    function resetGUI(~, ~)
        % Ask for confirmation
        answer = questdlg('Are you sure you want to reset? This will clear all loaded data and analysis results.', ...
                         'Confirm Reset', ...
                         'Yes, Reset', 'Cancel', 'Cancel');
        
        if strcmp(answer, 'Yes, Reset')
            addStatus('======================================');
            addStatus('RESETTING GUI - Clearing all data...');
            addStatus('======================================');
            
            % Clear all appdata - Core data
            setappdata(fig, 'channelData', []);
            setappdata(fig, 'filteredChannelData', []);
            setappdata(fig, 'LayerDic', []);
            setappdata(fig, 'Time', []);
            setappdata(fig, 'samplingRate', 10000);
            setappdata(fig, 'spikeData', []);
            setappdata(fig, 'channelLabels', []);
            setappdata(fig, 'firingRates', []);
            setappdata(fig, 'eventParametersAccepted', false);
            setappdata(fig, 'eventOnsets', []);
            setappdata(fig, 'eventOffsets', []);
            setappdata(fig, 'timeCenters', []);
            setappdata(fig, 'populationFiringRate', []);
            setappdata(fig, 'thresholdFR', []);
            setappdata(fig, 'autoNetworkResults', []);
            setappdata(fig, 'networkClusterLabels', []);
            setappdata(fig, 'h5FilePath', []);
            setappdata(fig, 'outputFolder', []);
            
            % Clear additional fields that were missing
            setappdata(fig, 'figuresFolder', []);
            setappdata(fig, 'TimeWindow', []);
            setappdata(fig, 'totalDuration', []);
            setappdata(fig, 'meaType', []);
            setappdata(fig, 'electrodeLayerMap', []);
            setappdata(fig, 'dataStartTime', []);
            setappdata(fig, 'partialLoading', false);
            setappdata(fig, 'noisyChannels', []);
            
            % Clear stimulation-related fields
            setappdata(fig, 'hasStimulation', false);
            setappdata(fig, 'stimulationTimes', []);
            setappdata(fig, 'stimulationElectrode', []);
            setappdata(fig, 'stimulationIntensities', []);
            
            % Clear analysis results
            setappdata(fig, 'LayerFiringRatesTable', []);
            setappdata(fig, 'ClusterSummaryTable', []);
            setappdata(fig, 'PostHocResults', []);
            setappdata(fig, 'CorrelationTable', []);
            setappdata(fig, 'HistogramData', []);
            setappdata(fig, 'SummaryTable', []);
            setappdata(fig, 'EventTable', []);
            setappdata(fig, 'sdThreshold', []);
            setappdata(fig, 'detectionMethod', []);
            setappdata(fig, 'refChannel', []);
            setappdata(fig, 'eventSDMultiplier', []);
            setappdata(fig, 'statusLog', {});
            
            % Clear both axes
            mainAx = findobj(fig, 'Tag', 'mainAxes');
            if ~isempty(mainAx)
                cla(mainAx);
                title(mainAx, 'Signal Display');
            end
            
            secondAx = findobj(fig, 'Tag', 'secondAxes');
            if ~isempty(secondAx)
                cla(secondAx);
                title(secondAx, 'Analysis Results');
            end
            
            % Reset parameter fields to defaults
            set(findobj('Tag', 'endTime'), 'String', '100');
            set(findobj('Tag', 'startTime'), 'String', '0');
            
            % Update settings display to show cleared state
            updateSettingsDisplay();
            
            addStatus('All data cleared successfully!');
            addStatus('Ready for new analysis - Start with Step 1');
            addStatus('======================================');
        else
            addStatus('Reset cancelled');
        end
    end
    
function [year, surgeryNum, tissueCode, sliceNum] = parsePatientID(patientID)
    % Parse patient ID format: YYSSCTTTSSS
    % Example: 2519CT073 → Year=2025, Surgery=19, Type=CT, Slice=073
    
    year = NaN;
    surgeryNum = NaN;
    tissueCode = '';
    sliceNum = NaN;
    
    % Remove any whitespace
    patientID = strtrim(patientID);
    
    if length(patientID) < 8
        warning('Patient ID too short: %s', patientID);
        return;
    end
    
    try
        % Extract year (first 2 digits)
        year = 2000 + str2double(patientID(1:2));
        
        % Extract surgery number (next 2 digits)
        surgeryNum = str2double(patientID(3:4));
        
        % Extract tissue code (next 2 letters)
        tissueCode = patientID(5:6);
        
        % Extract slice number (remaining digits)
        sliceNum = str2double(patientID(7:end));
        
    catch ME
        warning('Could not parse patient ID: %s (%s)', patientID, ME.message);
    end
end


    function exportToMasterDatabase(~, ~)
    % Export analysis results to Master Database with automated metadata extraction
    % ENHANCED VERSION - Reuses settings from previous recordings of same patient
    % UPDATED: Uses Slice_ID instead of Patient_ID in database
    
    addStatus('========================================');
    addStatus('Starting Master Database Export...');
    addStatus('========================================');
    
    % Get all required data
    outputFolder = getappdata(fig, 'outputFolder');
    spikeData = getappdata(fig, 'spikeData');
    h5FilePath = getappdata(fig, 'h5FilePath');
    noisyChannels = getappdata(fig, 'noisyChannels');
    
    if isempty(spikeData)
        addStatus('ERROR: Please run spike detection first');
        return;
    end
    
    if isempty(outputFolder)
        addStatus('ERROR: Please select output folder first');
        return;
    end
    
 % ==== EXTRACT METADATA FROM H5 FILE ====
addStatus('Extracting metadata from H5 file...');

% Get samplingRate from appdata first (CRITICAL FIX!)
samplingRate = getappdata(fig, 'samplingRate');
if isempty(samplingRate)
    samplingRate = 10000; % Default fallback
end

metadata = struct();
metadata.h5_filename = '';
metadata.recording_date = '';
metadata.recording_time = '';
metadata.mea_serial = '';
metadata.mea_layout = '';
metadata.sampling_rate = samplingRate;
metadata.div = NaN;
metadata.tissue_type = '';
metadata.mea_type = '';
metadata.patient_id_from_filename = '';
metadata.condition = '';
metadata.recording_type = '';

if ~isempty(h5FilePath) && exist(h5FilePath, 'file')
    try
        [~, h5name, h5ext] = fileparts(h5FilePath);
        metadata.h5_filename = [h5name, h5ext];
        addStatus(sprintf('  Reading from: %s', metadata.h5_filename));
        
        % ========== FIRST: PARSE FILENAME (Most reliable!) ==========
        addStatus('  Parsing filename metadata...');
        filenameMetadata = parseFilenameMetadata(metadata.h5_filename);
        
        % Use filename data if found
        if ~isempty(filenameMetadata.recording_date)
            metadata.recording_date = filenameMetadata.recording_date;
            addStatus(sprintf('    ✓ Date from filename: %s', metadata.recording_date));
        end
        
        if ~isempty(filenameMetadata.recording_time)
            metadata.recording_time = filenameMetadata.recording_time;
            addStatus(sprintf('    ✓ Time from filename: %s', metadata.recording_time));
        end
        
        if ~isnan(filenameMetadata.div)
            metadata.div = filenameMetadata.div;
            addStatus(sprintf('    ✓ DIV from filename: %d', metadata.div));
        end
        
        if ~isempty(filenameMetadata.tissue_type)
            metadata.tissue_type = filenameMetadata.tissue_type;
            addStatus(sprintf('    ✓ Tissue type from filename: %s', metadata.tissue_type));
        end
        
        if ~isempty(filenameMetadata.mea_type)
            metadata.mea_type = filenameMetadata.mea_type;
            addStatus(sprintf('    ✓ MEA type from filename: %s', metadata.mea_type));
        end
        
        if ~isempty(filenameMetadata.patient_id)
            metadata.patient_id_from_filename = filenameMetadata.patient_id;
            addStatus(sprintf('    ✓ Patient ID from filename: %s', metadata.patient_id_from_filename));
        end
        
        if ~isempty(filenameMetadata.condition)
            metadata.condition = filenameMetadata.condition;
            addStatus(sprintf('    ✓ Condition from filename: %s', metadata.condition));
        end
        
        if ~isempty(filenameMetadata.recording_type)
            metadata.recording_type = filenameMetadata.recording_type;
            addStatus(sprintf('    ✓ Recording type from filename: %s', metadata.recording_type));
        end
        
        % === METHOD 1: Try to read from H5 structure (as backup) ===
        try
            % First, explore what's actually in the H5 file
            h5structure = h5info(h5FilePath, '/');
            addStatus(sprintf('  H5 root has %d groups', length(h5structure.Groups)));
            
            % Try RecordingInfo path
            try
                recording_info = h5read(h5FilePath, '/Data/Recording_0/RecordingInfo');
                addStatus('  Found: /Data/Recording_0/RecordingInfo');
                
                % Try to extract date (only if not already from filename)
                if isempty(metadata.recording_date) && isfield(recording_info, 'Date')
                    rawDate = recording_info.Date;
                    if iscell(rawDate)
                        metadata.recording_date = char(rawDate{1});
                    elseif ischar(rawDate)
                        metadata.recording_date = rawDate;
                    else
                        metadata.recording_date = char(rawDate');
                    end
                    addStatus(sprintf('    Date from H5: %s', metadata.recording_date));
                end
                
                % Try to extract time (only if not already from filename)
                if isempty(metadata.recording_time) && isfield(recording_info, 'Time')
                    rawTime = recording_info.Time;
                    if iscell(rawTime)
                        metadata.recording_time = char(rawTime{1});
                    elseif ischar(rawTime)
                        metadata.recording_time = rawTime;
                    else
                        metadata.recording_time = char(rawTime');
                    end
                    addStatus(sprintf('    Time from H5: %s', metadata.recording_time));
                end
                
            catch ME1
                addStatus(['  RecordingInfo not accessible: ' ME1.message]);
            end
            
            % Try InfoChannel for MEA info
            try
                mea_info = h5read(h5FilePath, '/Data/Recording_0/AnalogStream/Stream_0/InfoChannel');
                addStatus('  Found: InfoChannel');
                
                % Extract MEA serial/device ID
                if isfield(mea_info, 'DeviceID')
                    rawID = mea_info.DeviceID;
                    if ~isempty(rawID)
                        if iscell(rawID)
                            metadata.mea_serial = char(rawID{1});
                        elseif ischar(rawID)
                            metadata.mea_serial = rawID;
                        else
                            metadata.mea_serial = char(rawID(1,:));
                        end
                        addStatus(sprintf('    MEA Serial: %s', metadata.mea_serial));
                    end
                end
                
                % Try alternative device ID fields
                if isempty(metadata.mea_serial) && isfield(mea_info, 'DeviceDataType')
                    rawType = mea_info.DeviceDataType;
                    if ~isempty(rawType)
                        if iscell(rawType)
                            metadata.mea_serial = char(rawType{1});
                        elseif ischar(rawType)
                            metadata.mea_serial = rawType;
                        else
                            metadata.mea_serial = char(rawType(1,:));
                        end
                        addStatus(sprintf('    MEA Type: %s', metadata.mea_serial));
                    end
                end
                
                % Try to extract layout info
                if isfield(mea_info, 'Label')
                    numChannels = length(mea_info.Label);
                    metadata.mea_layout = sprintf('256-channel MEA (%d active)', numChannels);
                    addStatus(sprintf('    Layout: %s', metadata.mea_layout));
                end
                
                % Try to read sampling rate from H5
                try
                    if isfield(mea_info, 'Tick') && ~isempty(mea_info.Tick)
                        tick = double(mea_info.Tick(1));
                        if tick > 0
                            h5_samplingRate = 1e6 / tick;
                            metadata.sampling_rate = h5_samplingRate;
                            addStatus(sprintf('    Sampling Rate from Tick: %.0f Hz', h5_samplingRate));
                        end
                    elseif isfield(mea_info, 'SamplingFrequency')
                        h5_samplingRate = double(mea_info.SamplingFrequency(1));
                        metadata.sampling_rate = h5_samplingRate;
                        addStatus(sprintf('    Sampling Rate: %.0f Hz', h5_samplingRate));
                    end
                catch
                    addStatus(sprintf('    Using detected Sampling Rate: %.0f Hz', samplingRate));
                end
                
            catch ME2
                addStatus(['  InfoChannel not accessible: ' ME2.message]);
            end
            
        catch ME
            addStatus(['  Warning: H5 structure exploration failed: ' ME.message]);
        end
        
        % === METHOD 2: Try alternative H5 paths (as final backup) ===
        if isempty(metadata.recording_date)
            try
                % Some systems store at root level
                attrs = h5readatt(h5FilePath, '/', 'DateCreated');
                metadata.recording_date = char(attrs);
                addStatus(sprintf('  Found date in root attributes: %s', metadata.recording_date));
            catch
                % Try another common location
                try
                    date_data = h5read(h5FilePath, '/Date');
                    metadata.recording_date = char(date_data');
                    addStatus(sprintf('  Found date at /Date: %s', metadata.recording_date));
                catch
                    addStatus('  Could not find recording date in H5 structure');
                end
            end
        end
        
        % === SUMMARY ===
        addStatus('  ======= Metadata Extraction Summary =======');
        addStatus(sprintf('  Recording date: %s', ifelse(~isempty(metadata.recording_date), metadata.recording_date, 'Unknown')));
        addStatus(sprintf('  Recording time: %s', ifelse(~isempty(metadata.recording_time), metadata.recording_time, 'Unknown')));
        addStatus(sprintf('  DIV: %s', ifelse(~isnan(metadata.div), num2str(metadata.div), 'Not found')));
        addStatus(sprintf('  Tissue type: %s', ifelse(~isempty(metadata.tissue_type), metadata.tissue_type, 'Not found')));
        addStatus(sprintf('  MEA type: %s', ifelse(~isempty(metadata.mea_type), metadata.mea_type, 'Not found')));
        addStatus(sprintf('  MEA serial: %s', ifelse(~isempty(metadata.mea_serial), metadata.mea_serial, 'Not found')));
        addStatus(sprintf('  Patient ID: %s', ifelse(~isempty(metadata.patient_id_from_filename), metadata.patient_id_from_filename, 'Not found')));
        addStatus(sprintf('  Condition: %s', ifelse(~isempty(metadata.condition), metadata.condition, 'Not found')));
        addStatus(sprintf('  Recording type: %s', ifelse(~isempty(metadata.recording_type), metadata.recording_type, 'Not found')));
        addStatus(sprintf('  Sampling rate: %.0f Hz', metadata.sampling_rate));
        addStatus('  ============================================');
        
        % Set defaults for missing values
        if isempty(metadata.recording_date)
            metadata.recording_date = 'Unknown';
        end
        if isempty(metadata.recording_time)
            metadata.recording_time = 'Unknown';
        end
        if isempty(metadata.mea_serial)
            metadata.mea_serial = 'Unknown';
        end
        
    catch ME
        addStatus(['  ERROR reading metadata: ' ME.message]);
        addStatus('  Will proceed with available information');
        
        % Set defaults
        metadata.recording_date = 'Unknown';
        metadata.recording_time = 'Unknown';
        metadata.mea_serial = 'Unknown';
    end
else
    addStatus('  ⚠ No H5 file loaded');
    metadata.h5_filename = 'None';
    metadata.recording_date = 'Unknown';
    metadata.recording_time = 'Unknown';
    metadata.mea_serial = 'Unknown';
    metadata.mea_layout = 'Unknown';
end

addStatus('Metadata extraction complete.');

% Helper function for inline if-else
function result = ifelse(condition, trueVal, falseVal)
    if condition
        result = trueVal;
    else
        result = falseVal;
    end
end
    
    % ==== AUTO-DETECT FROM FOLDER STRUCTURE ====
    addStatus('Auto-detecting recording information...');

[~, folderName] = fileparts(outputFolder);
parentFolder = fileparts(outputFolder);
[~, parentName] = fileparts(parentFolder);

% Initialize default values
patientID_guess = '';
sliceNum_guess = '';
tissueType_guess = 'Unknown';

% *** RECORDING TYPE: Use output folder name directly ***
% The output folder name IS the recording type (Spont1, HighK_Spont1, etc.)
recordingType_fromFolder = folderName;
addStatus(sprintf('  Recording Type from output folder: %s', recordingType_fromFolder));

% Try to extract patient ID from folder names (pattern: YYSSTTTSSS)
patientMatch = regexp(parentName, '(\d{4}[A-Z]{2,3}\d{3})', 'tokens');
if ~isempty(patientMatch)
    patientID_guess = patientMatch{1}{1};
else
    % Try current folder
    patientMatch = regexp(folderName, '(\d{4}[A-Z]{2,3}\d{3})', 'tokens');
    if ~isempty(patientMatch)
        patientID_guess = patientMatch{1}{1};
    end
end

% Try to detect recording type from folder name OR H5 filename
% NOTE: Now using output folder name directly - this detection is only for metadata fallback
h5FileName = '';
if ~isempty(h5FilePath)
    [~, h5FileName, ~] = fileparts(h5FilePath);
end

if ~isempty(patientID_guess)
    [year_guess, surgery_guess, tissue_code_guess, slice_guess] = parsePatientID(patientID_guess);
    
    if ~isnan(slice_guess)
        addStatus(sprintf('  Parsed ID: Year=%d, Surgery=%d, Type=%s, Slice=%03d', ...
            year_guess, surgery_guess, tissue_code_guess, slice_guess));
        
        % Map tissue code
        switch upper(tissue_code_guess)
            case 'CT'
                tissueType_guess = 'Cortex Tumor';
            case 'ET'
                tissueType_guess = 'Epilepsy Temporal';
            case 'EF'
                tissueType_guess = 'Epilepsy Frontal';
            case 'GC'
                tissueType_guess = 'Glioma Cortex';
            otherwise
                tissueType_guess = tissue_code_guess;
        end
    end
end

% Check if grandparent contains slice info
grandparentFolder = fileparts(parentFolder);
[~, grandparentName] = fileparts(grandparentFolder);
sliceMatch = regexp(grandparentName, '[Ss]lice[\s_-]*(\d+)', 'tokens');
if ~isempty(sliceMatch)
    sliceNum_guess = sliceMatch{1}{1};
end

% Detect tissue type from folder names
if contains(lower(parentName), 'epil') || contains(lower(grandparentName), 'epil')
    tissueType_guess = 'Epilepsy';
elseif contains(lower(parentName), 'glio') || contains(lower(grandparentName), 'glio')
    tissueType_guess = 'Glioma';
else
    tissueType_guess = 'Unknown';
end

% Format noisy channels for display
if isempty(noisyChannels)
    noisyChannelStr = '';
else
    noisyChannelStr = strjoin(noisyChannels, ', ');
end

addStatus(sprintf('  Auto-detected: Slice=%s, Type=%s', ...
    patientID_guess, recordingType_fromFolder));

% ==== STEP 1: ASK FOR SLICE ID TO ENABLE DATABASE LOOKUP ====
addStatus('Step 1: Identifying slice for database lookup...');

% Quick dialog to get Slice ID for lookup
prompt_id = {'Enter Slice ID (e.g., 2203CE046) to check for previous recordings:'};
dlgtitle_id = 'Slice Identification';
dims_id = [1 60];
definput_id = {patientID_guess};

answer_id = inputdlg(prompt_id, dlgtitle_id, dims_id, definput_id);

if isempty(answer_id)
    addStatus('Master database export cancelled');
    return;
end

sliceID_lookup = strtrim(answer_id{1});

if isempty(sliceID_lookup)
    addStatus('ERROR: Slice ID is required');
    return;
end

% Extract patient ID (first 6 characters) for finding related entries
truePatientID = sliceID_lookup(1:min(6, length(sliceID_lookup)));

% ==== CHECK FOR EXISTING DATABASE AND PREVIOUS ENTRIES ====
addStatus(sprintf('Step 2: Checking database for patient %s recordings...', truePatientID));

% NEU V4: Speicherort fuer Master Database per Dialog abfragen
% Vorschlag: parentDir/MEA_Master_Database.xlsx (wie bisher automatisch)
parentDir    = fileparts(fileparts(outputFolder));
defaultDBPath = fullfile(parentDir, 'MEA_Master_Database.xlsx');

[dbFile, dbDir] = uiputfile({'*.xlsx','Excel Datei (*.xlsx)'}, ...
    'Master Database speichern als', defaultDBPath);
if isequal(dbFile, 0)
    addStatus('Export abgebrochen (kein Speicherort gewaehlt).');
    return;
end
masterDBPath = fullfile(dbDir, dbFile);
addStatus(sprintf('  Datenbank: %s', masterDBPath));

previousEntry = [];
foundPrevious = false;

if exist(masterDBPath, 'file')
    try
        existingData = readtable(masterDBPath, 'Sheet', 'Master_Database');
        
        % Find most recent entry for this PATIENT (first 6 chars of Slice_ID)
        patientMask = cellfun(@(x) strncmp(x, truePatientID, 6), existingData.SliceID);
        
        if any(patientMask)
            patientEntries = existingData(patientMask, :);
            
            % Get most recent entry (last row)
            previousEntry = patientEntries(end, :);
            foundPrevious = true;
            
            addStatus(sprintf('  ✓ Found %d previous recording(s) for patient %s', ...
                sum(patientMask), truePatientID));
            addStatus('  → Will auto-fill settings from most recent entry');
        else
            addStatus(sprintf('  No previous recordings found for patient %s', truePatientID));
            addStatus('  → Using auto-detected defaults');
        end
    catch ME
        addStatus(['  Note: Could not read existing database: ' ME.message]);
    end
else
    addStatus('  No existing database found - will create new');
end

% ==== PREPARE DEFAULT VALUES ====
% Use previous entry if available, otherwise use auto-detected values

if foundPrevious && ~isempty(previousEntry)
    % Reuse from previous entry
    default_sliceID = previousEntry.SliceID{1};
    default_sliceNum = num2str(previousEntry.Slice_Number);
    default_tissueType = previousEntry.Tissue_Type{1};
    default_side = previousEntry.Side{1};
    default_layerQuality = previousEntry.Layer_Quality{1};
    
    % New fields from previous entry
    if ismember('Patient_Age', previousEntry.Properties.VariableNames)
        if ~isnan(previousEntry.Patient_Age)
            default_patientAge = num2str(previousEntry.Patient_Age);
        else
            default_patientAge = '';
        end
    else
        default_patientAge = '';
    end
    
    if ismember('Brain_Area', previousEntry.Properties.VariableNames)
        default_brainArea = previousEntry.Brain_Area{1};
    else
        default_brainArea = 'Temporal';
    default_gender = 'M';
    end
    
    if ismember('Gender', previousEntry.Properties.VariableNames)
        if ~isempty(previousEntry.Gender{1})
            default_gender = previousEntry.Gender{1};
        else
            default_gender = 'M';
        end
    else
        default_gender = 'M';
    end
    
    
    if ismember('DIV', previousEntry.Properties.VariableNames)
        if ~isnan(previousEntry.DIV)
            default_div = num2str(previousEntry.DIV);
        else
            default_div = '';
        end
    else
        default_div = '';
    end
    
    default_experimenter = previousEntry.Experimenter{1};
    
    % Get noisy channels from previous entry if available
    if ismember('Noisy_Channels_List', previousEntry.Properties.VariableNames)
        prevNoisy = previousEntry.Noisy_Channels_List{1};
        if ~strcmp(prevNoisy, 'None') && ~isempty(prevNoisy)
    
    % Demographics defaults for new patients
    default_patientAge = '';
    default_gender = 'M';
    default_brainArea = 'Temporal';
            default_noisyChannels = prevNoisy;
        else
            default_noisyChannels = noisyChannelStr;
        end
    else
        default_noisyChannels = noisyChannelStr;
    end
    
    % For repeated measures, suggest next recording type
    prevRecType = previousEntry.Recording_Type{1};
    
    % Recording Type: Always use output folder name
    % (No need for smart suggestion - user already chose the folder)
    default_recordingType = recordingType_fromFolder;
    
    addStatus(sprintf('  Recording type from output folder: %s', default_recordingType));
    
else
    % Use filename metadata if available, otherwise use auto-detected values
    if ~isempty(metadata.patient_id_from_filename)
        default_sliceID = metadata.patient_id_from_filename;
    else
        default_sliceID = sliceID_lookup;
    end
    
    if ~isnan(metadata.div)
        default_div = num2str(metadata.div);
    else
        default_div = '';
    end
    
    % Recording Type: Always use output folder name
    default_recordingType = recordingType_fromFolder;
    
    % Use tissue type from filename metadata if available
    if ~isempty(metadata.tissue_type)
        default_tissueType = metadata.tissue_type;
    else
        default_tissueType = tissueType_guess;
    end
    
    default_sliceNum = sliceNum_guess;
    default_side = 'Left';
    default_brainArea = 'Temporal';
    default_patientAge = '';
    default_gender = 'M';
    default_layerQuality = 'Good';
    default_experimenter = '';
    default_noisyChannels = noisyChannelStr;
end
    
    % ==== USE / UPDATE SESSION METADATA ====
    % Metadata is entered once and reused across multiple exports.
    % Use the clipboard (📋) button next to "12. Export to Master DB" to set/update.
    addStatus(sprintf('Recording Type (from output folder): %s', recordingType_fromFolder));
    
    hasMeta = isfield(sessionSettings, 'patientMeta') && ...
              isstruct(sessionSettings.patientMeta) && ...
              isfield(sessionSettings.patientMeta, 'sliceID') && ...
              ~isempty(sessionSettings.patientMeta.sliceID);
    
    if hasMeta
        pm = sessionSettings.patientMeta;
        previewStr = sprintf('%s | %s | %s | DIV %s', ...
            pm.sliceID, pm.tissueType, pm.brainArea, pm.div);
        useMeta = questdlg( ...
            sprintf('Gespeicherte Patienten-Metadaten gefunden:\n\n  %s\n\nMetadaten verwenden?', previewStr), ...
            'Patient Metadata', ...
            'Verwenden', 'Aktualisieren', 'Abbrechen', 'Verwenden');
        switch useMeta
            case 'Abbrechen'
                addStatus('Master database export abgebrochen');
                return;
            case 'Aktualisieren'
                setPatientMetadata();
                % Re-check after update
                hasMeta = isfield(sessionSettings, 'patientMeta') && ...
                          isfield(sessionSettings.patientMeta, 'sliceID') && ...
                          ~isempty(sessionSettings.patientMeta.sliceID);
                if ~hasMeta
                    addStatus('Export abgebrochen - keine Metadaten eingegeben');
                    return;
                end
        end
    else
        addStatus('Keine gespeicherten Metadaten. Bitte Patientendaten eingeben:');
        setPatientMetadata();
        hasMeta = isfield(sessionSettings, 'patientMeta') && ...
                  isfield(sessionSettings.patientMeta, 'sliceID') && ...
                  ~isempty(sessionSettings.patientMeta.sliceID);
        if ~hasMeta
            addStatus('Export abgebrochen - keine Metadaten eingegeben');
            return;
        end
    end
    
    % Extract values from stored metadata
    pm = sessionSettings.patientMeta;
    sliceID          = pm.sliceID;
    recordingType    = recordingType_fromFolder;
    tissueTypeManual = pm.tissueType;
    side             = pm.side;
    brainArea        = pm.brainArea;
    patientAge_str   = pm.patientAge;
    gender           = pm.gender;
    layerQuality     = pm.layerQuality;
    div_str          = pm.div;
    noisyChannelInput= pm.noisyChannels;
    experimenter     = pm.experimenter;
    notes            = pm.notes;
    
    % Sync noisy channels to session
    if ~isempty(noisyChannelInput)
        sessionSettings.lastNoisyChannels = noisyChannelInput;
        setappdata(fig, 'sessionSettings', sessionSettings);
    end
    
    addStatus(sprintf('  Verwende Metadaten: %s | %s | %s | DIV %s', ...
        sliceID, tissueTypeManual, brainArea, div_str));

% Parse patient age
if ~isempty(patientAge_str)
    patientAge = str2double(patientAge_str);
    if isnan(patientAge)
        patientAge = NaN;
        addStatus('Warning: Invalid patient age, using NaN');
    end
else
    patientAge = NaN;
end

% ==== PARSE SLICE ID ====
addStatus('Parsing slice ID...');
[year, surgeryNum, tissueCode, sliceNum] = parsePatientID(sliceID);

if isnan(sliceNum)
    addStatus('ERROR: Could not parse slice ID format');
    addStatus('Expected format: YYSSTTTSSS (e.g., 2519CT073)');
    return;
end

addStatus(sprintf('  Parsed: Year=%d, Surgery=%d, Type=%s, Slice=%03d', ...
    year, surgeryNum, tissueCode, sliceNum));

% Extract patient ID (first 6 characters)
truePatientID = sliceID(1:min(6, length(sliceID)));

% ==== EARLY DUPLICATE CHECK ====
addStatus('========================================');
addStatus('DUPLICATE CHECK:');
addStatus(sprintf('  Checking for: %s + %s', sliceID, recordingType));

% Initialize flag - should we overwrite an existing entry?
shouldOverwrite = false;
originalRecordingType = recordingType;  % Store in case user changes it

addStatus(sprintf('  [DEBUG] Initial shouldOverwrite = %s', string(shouldOverwrite)));
addStatus(sprintf('  [DEBUG] Original Recording Type = %s', originalRecordingType));

if exist(masterDBPath, 'file')
    try
        tempData = readtable(masterDBPath, 'Sheet', 'Master_Database');
        addStatus(sprintf('  [DEBUG] Database has %d total entries', height(tempData)));
        
        earlyDuplicateMask = strcmp(tempData.SliceID, sliceID) & ...
                             strcmp(tempData.Recording_Type, recordingType);
        
        numEarlyMatches = sum(earlyDuplicateMask);
        addStatus(sprintf('  [DEBUG] Found %d matches for %s + %s', numEarlyMatches, sliceID, recordingType));
        
        if numEarlyMatches > 0
            addStatus('  ⚠️  WARNING: This entry already exists!');
            addStatus(sprintf('  Found: %s | %s | Slice %03d', ...
                sliceID, recordingType, sliceNum));
            
            % Show warning dialog
            warningMsg = sprintf(['DUPLICATE DETECTED!\n\n' ...
                'Slice ID: %s\n' ...
                'Recording Type: %s\n' ...
                'Slice: %03d\n\n' ...
                'This combination already exists in the database.\n' ...
                'What would you like to do?'], ...
                sliceID, recordingType, sliceNum);
            
            choice = questdlg(warningMsg, ...
                'Duplicate Entry Warning', ...
                'Change Recording Type', 'Overwrite existing', 'Cancel', ...
                'Change Recording Type');
            
            addStatus(sprintf('  [DEBUG] User choice = %s', choice));
            
            if strcmp(choice, 'Cancel')
                addStatus('Export cancelled by user');
                addStatus('========================================');
                return;
            elseif strcmp(choice, 'Change Recording Type')
                % Offer to re-enter just the recording type
                newRecType = inputdlg(...
                    {'Enter NEW Recording Type (different from existing):'}, ...
                    'Change Recording Type', ...
                    [1 50], ...
                    {recordingType});
                
                if isempty(newRecType)
                    addStatus('Export cancelled');
                    addStatus('========================================');
                    return;
                end
                
                recordingType = strtrim(newRecType{1});
                addStatus(sprintf('  → Changed to: %s', recordingType));
                addStatus(sprintf('  [DEBUG] New Recording Type = %s', recordingType));
                
                % Check again if this new type is also duplicate
                newDupMask = strcmp(tempData.SliceID, sliceID) & ...
                            strcmp(tempData.Recording_Type, recordingType);
                numNewMatches = sum(newDupMask);
                addStatus(sprintf('  [DEBUG] Checking new name: found %d matches', numNewMatches));
                
                if numNewMatches > 0
                    addStatus('  ⚠️  WARNING: This is also a duplicate!');
                    addStatus('  User will be asked again if they want to overwrite.');
                    shouldOverwrite = true;  % Mark for overwrite check later
                    addStatus(sprintf('  [DEBUG] Set shouldOverwrite = TRUE (new name is duplicate)'));
                else
                    addStatus('  ✓ New name is unique - will ADD as new entry');
                    shouldOverwrite = false;  % Definitely a new entry
                    addStatus(sprintf('  [DEBUG] Set shouldOverwrite = FALSE (new name is unique)'));
                end
            else
                % User chose "Overwrite existing"
                addStatus('  → User chose to OVERWRITE existing entry');
                shouldOverwrite = true;
                addStatus(sprintf('  [DEBUG] Set shouldOverwrite = TRUE (user chose overwrite)'));
            end
        else
            addStatus('  ✓ No duplicate found - this is a NEW entry');
            shouldOverwrite = false;
            addStatus(sprintf('  [DEBUG] Set shouldOverwrite = FALSE (no duplicate)'));
        end
    catch ME
        addStatus(['  Note: Could not check for duplicates: ' ME.message]);
        shouldOverwrite = false;
        addStatus(sprintf('  [DEBUG] Set shouldOverwrite = FALSE (error in check)'));
    end
else
    addStatus('  No existing database - this will be the first entry');
    shouldOverwrite = false;
    addStatus(sprintf('  [DEBUG] Set shouldOverwrite = FALSE (no database)'));
end

addStatus(sprintf('  [DEBUG] FINAL shouldOverwrite value = %s', string(shouldOverwrite)));
addStatus(sprintf('  [DEBUG] FINAL recordingType value = %s', recordingType));
addStatus('========================================');

% Map tissue code to full name (if not manually specified)
if isempty(tissueTypeManual)
    switch upper(tissueCode)
        case 'CT'
            tissueType = 'Cortex Tumor';
        case 'ET'
            tissueType = 'Epilepsy Temporal';
        case 'EF'
            tissueType = 'Epilepsy Frontal';
        case 'GC'
            tissueType = 'Glioma Cortex';
        otherwise
            tissueType = tissueCode;  % Use code as-is
    end
else
    tissueType = tissueTypeManual;
end

addStatus(sprintf('  Tissue type: %s', tissueType));
    
    % Convert DIV
    if ~isempty(div_str)
        div = str2double(div_str);
        if isnan(div) || div < 0
            addStatus('Warning: Invalid DIV value. Setting to empty.');
            div = NaN;
        end
    else
        div = NaN;
    end
    
    % Parse noisy channels
    if ~isempty(noisyChannelInput)
        noisyChannelsList = strsplit(noisyChannelInput, ',');
        noisyChannelsList = strtrim(noisyChannelsList);
        numNoisyChannels = length(noisyChannelsList);
        noisyChannelStr = strjoin(noisyChannelsList, ', ');
    else
        noisyChannelsList = {};
        numNoisyChannels = 0;
        noisyChannelStr = 'None';
    end
    
    % Validate required fields
    if isempty(sliceID) || isnan(sliceNum)
        addStatus('ERROR: Slice ID and Slice Number are required');
        return;
    end
    
    % ==== COLLECT ALL ANALYSIS RESULTS ====
    addStatus('Collecting analysis results...');
    
    % Get stored results
    totalDuration = getappdata(fig, 'totalDuration');
    samplingRate = getappdata(fig, 'samplingRate');
    eventOnsets = getappdata(fig, 'eventOnsets');
    eventOffsets = getappdata(fig, 'eventOffsets');
    LayerFiringRatesTable = getappdata(fig, 'LayerFiringRatesTable');
    firingRates = getappdata(fig, 'firingRates');
    
    % Get detection parameters
    sdThreshold = getappdata(fig, 'sdThreshold');
    detectionMethod = getappdata(fig, 'detectionMethod');
    eventSDMultiplier = getappdata(fig, 'eventSDMultiplier');
    refChannel = getappdata(fig, 'refChannel');
    
    if isempty(sdThreshold)
        sdThreshold = str2double(get(findobj('Tag', 'sdThreshold'), 'String'));
    end
    if isempty(detectionMethod)
        methodIdx = get(findobj('Tag', 'method'), 'Value');
        methodOptions = {'Per-channel', 'Global'};
        detectionMethod = methodOptions{methodIdx};
    end
    if isempty(eventSDMultiplier)
        eventSDMultiplier = str2double(get(findobj('Tag', 'eventSDMultiplier'), 'String'));
    end
    if isempty(refChannel)
        refChannel = get(findobj('Tag', 'refChannel'), 'String');
    end
    
    % Compute metrics
    sortedChannels = sort(fieldnames(spikeData));
    totalChannels = length(sortedChannels);
    
    totalSpikes = 0;
    activeChannels = 0;
    spikesPerMinThreshold = 5;
    allFiringRates = [];
    
    for idx = 1:length(sortedChannels)
        channel = sortedChannels{idx};
        numSpikes = length(spikeData.(channel).times);
        totalSpikes = totalSpikes + numSpikes;
        
        fr = firingRates.(channel);
        allFiringRates(end+1) = fr;
        
        if numSpikes / (totalDuration / 60) >= spikesPerMinThreshold
            activeChannels = activeChannels + 1;
        end
    end
    
    meanGlobalFR = mean(allFiringRates);
    medianGlobalFR = median(allFiringRates);
    stdGlobalFR = std(allFiringRates);
    maxGlobalFR = max(allFiringRates);
    
    % Event metrics
    numEvents = length(eventOnsets);
    meanEventDuration = NaN;
    stdEventDuration = NaN;
    meanIEI = NaN;
    stdIEI = NaN;
    cvIEI = NaN;
    eventRate = NaN;
    
    if numEvents > 0
        durations = eventOffsets - eventOnsets;
        meanEventDuration = mean(durations);
        stdEventDuration = std(durations);
        eventRate = numEvents / totalDuration;
        
        if numEvents > 1
            IEI = diff(eventOnsets);
            meanIEI = mean(IEI);
            stdIEI = std(IEI);
            cvIEI = stdIEI / meanIEI;
        end
    end
    
    % ==== SPIKE AMPLITUDE METRICS ====
    addStatus('Calculating spike amplitude metrics...');
    allAmplitudes = [];
    
    for idx = 1:length(sortedChannels)
        channel = sortedChannels{idx};
        if isfield(spikeData.(channel), 'amplitudes')
            channelAmps = spikeData.(channel).amplitudes;
            allAmplitudes = [allAmplitudes; abs(channelAmps(:))];
        end
    end
    
    if ~isempty(allAmplitudes)
        meanSpikeAmplitude = mean(allAmplitudes);
        addStatus(sprintf('  Mean spike amplitude: %.2f µV', meanSpikeAmplitude));
    else
        meanSpikeAmplitude = NaN;
        addStatus('  Warning: No spike amplitudes found');
    end
    
    % Layer metrics
    L1_FR = NaN; L23_FR = NaN; L4_FR = NaN; L56_FR = NaN; WM_FR = NaN;
    L1_Active = NaN; L23_Active = NaN; L4_Active = NaN; L56_Active = NaN; WM_Active = NaN;
    L1_Total = NaN; L23_Total = NaN; L4_Total = NaN; L56_Total = NaN; WM_Total = NaN;
    
    if ~isempty(LayerFiringRatesTable) && height(LayerFiringRatesTable) >= 5
        try
            L1_FR = LayerFiringRatesTable.Mean_FR_Hz(1);
            L23_FR = LayerFiringRatesTable.Mean_FR_Hz(2);
            L4_FR = LayerFiringRatesTable.Mean_FR_Hz(3);
            L56_FR = LayerFiringRatesTable.Mean_FR_Hz(4);
            WM_FR = LayerFiringRatesTable.Mean_FR_Hz(5);
            
            L1_Active = LayerFiringRatesTable.Num_Active(1);
            L23_Active = LayerFiringRatesTable.Num_Active(2);
            L4_Active = LayerFiringRatesTable.Num_Active(3);
            L56_Active = LayerFiringRatesTable.Num_Active(4);
            WM_Active = LayerFiringRatesTable.Num_Active(5);
            
            L1_Total = LayerFiringRatesTable.Num_Electrodes(1);
            L23_Total = LayerFiringRatesTable.Num_Electrodes(2);
            L4_Total = LayerFiringRatesTable.Num_Electrodes(3);
            L56_Total = LayerFiringRatesTable.Num_Electrodes(4);
            WM_Total = LayerFiringRatesTable.Num_Electrodes(5);
        catch
            addStatus('Warning: Could not extract complete layer metrics');
        end
    end
    
    % ==== PROPAGATION METRICS ====
    addStatus('Loading propagation statistics...');
    
    % Initialize all propagation metrics as NaN
    mean_velocity_COM = NaN;
    std_velocity_COM = NaN;
    mean_velocity_gradient = NaN;
    std_velocity_gradient = NaN;
    mean_wave_direction = NaN;
    std_wave_direction = NaN;
    mean_wave_coherence = NaN;
    std_wave_coherence = NaN;
    mean_active_electrodes_per_event = NaN;
    std_active_electrodes_per_event = NaN;
    
    % Try to load PropagationSummary.xlsx from Propagation_Analysis subfolder
    propagationFile = fullfile(outputFolder, 'Propagation_Analysis', 'PropagationSummary.xlsx');
    
    if exist(propagationFile, 'file')
        try
            propData = readtable(propagationFile);
            
            % Check if we have the expected columns
            if ismember('Velocity_COM_mm_s', propData.Properties.VariableNames)
                mean_velocity_COM = mean(propData.Velocity_COM_mm_s, 'omitnan');
                std_velocity_COM = std(propData.Velocity_COM_mm_s, 'omitnan');
                addStatus(sprintf('  Velocity COM: %.1f ± %.1f mm/s', mean_velocity_COM, std_velocity_COM));
            end
            
            if ismember('Velocity_Gradient_mm_s', propData.Properties.VariableNames)
                mean_velocity_gradient = mean(propData.Velocity_Gradient_mm_s, 'omitnan');
                std_velocity_gradient = std(propData.Velocity_Gradient_mm_s, 'omitnan');
                addStatus(sprintf('  Velocity Gradient: %.1f ± %.1f mm/s', mean_velocity_gradient, std_velocity_gradient));
            end
            
            if ismember('WaveDirection_deg', propData.Properties.VariableNames)
                mean_wave_direction = mean(propData.WaveDirection_deg, 'omitnan');
                std_wave_direction = std(propData.WaveDirection_deg, 'omitnan');
                addStatus(sprintf('  Wave Direction: %.1f ± %.1f°', mean_wave_direction, std_wave_direction));
            end
            
            if ismember('WaveCoherence', propData.Properties.VariableNames)
                mean_wave_coherence = mean(propData.WaveCoherence, 'omitnan');
                std_wave_coherence = std(propData.WaveCoherence, 'omitnan');
                addStatus(sprintf('  Wave Coherence: %.3f ± %.3f', mean_wave_coherence, std_wave_coherence));
            end
            
            if ismember('NumActiveElectrodes', propData.Properties.VariableNames)
                mean_active_electrodes_per_event = mean(propData.NumActiveElectrodes, 'omitnan');
                std_active_electrodes_per_event = std(propData.NumActiveElectrodes, 'omitnan');
                addStatus(sprintf('  Active Electrodes/Event: %.1f ± %.1f', mean_active_electrodes_per_event, std_active_electrodes_per_event));
            end
            
            addStatus('  ✓ Propagation statistics loaded successfully');
            
        catch ME
            addStatus(['  Warning: Could not load propagation data: ' ME.message]);
        end
    else
        addStatus(sprintf('  Note: PropagationSummary.xlsx not found'));
        addStatus('  Run Propagation Analysis (Button 10) to generate these metrics');
    end
    
    % ==== CREATE DATABASE ROW ====
    addStatus('Creating database entry...');
    addStatus(sprintf('  → Using Slice_ID: %s', sliceID));
    addStatus(sprintf('  → Using Recording_Type: %s', recordingType));
    
    newRow = table();
    
    % === RECORDING IDENTIFICATION ===
    newRow.SliceID = {sliceID};
    newRow.Year = year;
    newRow.Surgery_Number = surgeryNum;
    newRow.Tissue_Code = {tissueCode};
    newRow.Slice_Number = sliceNum;
    newRow.Recording_Type = {recordingType};
    newRow.Tissue_Type = {tissueType};
    newRow.Side = {side};
    newRow.Brain_Area = {brainArea};
    newRow.Patient_Age = patientAge;
    newRow.Gender = {gender};
    newRow.DIV = div;
    newRow.Layer_Quality = {layerQuality};
    newRow.Experimenter = {experimenter};
    newRow.Analysis_Date = {datestr(now, 'yyyy-mm-dd')};
    newRow.Analysis_Time = {datestr(now, 'HH:MM:SS')};
    
    % === H5 FILE METADATA ===
    newRow.H5_Filename = {metadata.h5_filename};
    newRow.Recording_Date = {metadata.recording_date};
    newRow.Recording_Time = {metadata.recording_time};
    newRow.MEA_Serial = {metadata.mea_serial};
    
    % === RECORDING PARAMETERS ===
    newRow.Duration_s = totalDuration;
    newRow.Sampling_Rate_Hz = samplingRate;
    newRow.Total_Channels = totalChannels;
    newRow.Active_Channels = activeChannels;
    newRow.Active_Percent = (activeChannels / totalChannels) * 100;
    
    % === NOISY CHANNELS INFO ===
    newRow.Num_Noisy_Channels = numNoisyChannels;
    newRow.Noisy_Channels_List = {noisyChannelStr};
    
    % === SPIKE DETECTION PARAMETERS ===
    newRow.Spike_Threshold_SD = sdThreshold;
    newRow.Detection_Method = {detectionMethod};
    
    % === SPIKE METRICS ===
    newRow.Total_Spikes = totalSpikes;
    newRow.Mean_FR_Hz = meanGlobalFR;
    newRow.Median_FR_Hz = medianGlobalFR;
    newRow.Std_FR_Hz = stdGlobalFR;
    newRow.Max_FR_Hz = maxGlobalFR;
    newRow.Mean_Spike_Amplitude_uV = meanSpikeAmplitude;
    
    % === EVENT DETECTION PARAMETERS ===
    newRow.Event_Threshold_SD = eventSDMultiplier;
    newRow.Reference_Channel = {refChannel};
    
    % === EVENT METRICS ===
    newRow.Num_Events = numEvents;
    newRow.Event_Rate_per_min = eventRate * 60;
    newRow.Mean_Event_Duration_s = meanEventDuration;
    newRow.Std_Event_Duration_s = stdEventDuration;
    newRow.Mean_IEI_s = meanIEI;
    newRow.Std_IEI_s = stdIEI;
    newRow.CV_IEI = cvIEI;
    
    % === PROPAGATION METRICS ===
    newRow.Mean_Velocity_COM_mm_s = mean_velocity_COM;
    newRow.Std_Velocity_COM_mm_s = std_velocity_COM;
    newRow.Mean_Velocity_Gradient_mm_s = mean_velocity_gradient;
    newRow.Std_Velocity_Gradient_mm_s = std_velocity_gradient;
    newRow.Mean_WaveDirection_deg = mean_wave_direction;
    newRow.Std_WaveDirection_deg = std_wave_direction;
    newRow.Mean_WaveCoherence = mean_wave_coherence;
    newRow.Std_WaveCoherence = std_wave_coherence;
    newRow.Mean_Active_Electrodes_per_Event = mean_active_electrodes_per_event;
    newRow.Std_Active_Electrodes_per_Event = std_active_electrodes_per_event;
    
    % === LAYER-SPECIFIC FIRING RATES ===
    newRow.L1_Mean_FR_Hz = L1_FR;
    newRow.L23_Mean_FR_Hz = L23_FR;
    newRow.L4_Mean_FR_Hz = L4_FR;
    newRow.L56_Mean_FR_Hz = L56_FR;
    newRow.WM_Mean_FR_Hz = WM_FR;
    
    % === LAYER-SPECIFIC ACTIVE ELECTRODES ===
    newRow.L1_Active = L1_Active;
    newRow.L23_Active = L23_Active;
    newRow.L4_Active = L4_Active;
    newRow.L56_Active = L56_Active;
    newRow.WM_Active = WM_Active;
    
    % === LAYER-SPECIFIC TOTAL ELECTRODES ===
    newRow.L1_Total = L1_Total;
    newRow.L23_Total = L23_Total;
    newRow.L4_Total = L4_Total;
    newRow.L56_Total = L56_Total;
    newRow.WM_Total = WM_Total;
    
    % === FILE PATHS ===
    newRow.Output_Folder = {outputFolder};
    newRow.H5_Path = {h5FilePath};
    
    % === NOTES ===
    newRow.Notes = {notes};
    
    % ==== LOCATE/CREATE MASTER DATABASE ====
    % Use the path we already determined
    if ~exist(masterDBPath, 'file')
        answer2 = questdlg('Master Database not found. Create new?', ...
            'Database File', ...
            'Create new', 'Browse existing', 'Cancel', 'Create new');
        
        if strcmp(answer2, 'Browse existing')
            [dbFile, dbPath] = uigetfile('*.xlsx', 'Select Master Database');
            if isequal(dbFile, 0)
                addStatus('Export cancelled');
                return;
            end
            masterDBPath = fullfile(dbPath, dbFile);
        elseif strcmp(answer2, 'Cancel')
            addStatus('Export cancelled');
            return;
        end
    end
    
    addStatus(sprintf('Database path: %s', masterDBPath));
    
    % ==== APPEND TO DATABASE ====
    addStatus('Writing to master database...');
    
    try
        % Read existing or create new
        if exist(masterDBPath, 'file')
            try
                existingData = readtable(masterDBPath, 'Sheet', 'Master_Database');
                addStatus(sprintf('  Found existing database with %d entries', height(existingData)));
                
                % ==== HANDLE COLUMN MISMATCHES ====
                % This is critical! Old database may not have all the new columns we added
                addStatus('Checking for column mismatches...');
                
                existingCols = existingData.Properties.VariableNames;
                newCols = newRow.Properties.VariableNames;
                
                % Find columns in newRow that don't exist in existingData
                missingInExisting = setdiff(newCols, existingCols);
                if ~isempty(missingInExisting)
                    addStatus(sprintf('  Adding %d new columns to existing data:', length(missingInExisting)));
                    for i = 1:length(missingInExisting)
                        colName = missingInExisting{i};
                        addStatus(sprintf('    - %s', colName));
                        
                        % Add column with appropriate default value based on data type
                        colValue = newRow.(colName);
                        if iscell(colValue)
                            existingData.(colName) = repmat({''}, height(existingData), 1);
                        elseif isnumeric(colValue)
                            existingData.(colName) = nan(height(existingData), 1);
                        else
                            existingData.(colName) = repmat(colValue, height(existingData), 1);
                        end
                    end
                else
                    addStatus('  ✓ All new columns already exist');
                end
                
                % Find columns in existingData that don't exist in newRow (shouldn't happen but just in case)
                missingInNew = setdiff(existingCols, newCols);
                if ~isempty(missingInNew)
                    addStatus(sprintf('  Adding %d old columns to new row:', length(missingInNew)));
                    for i = 1:length(missingInNew)
                        colName = missingInNew{i};
                        addStatus(sprintf('    - %s', colName));
                        
                        % Add column with appropriate default value
                        colValue = existingData.(colName)(1);
                        if iscell(colValue)
                            newRow.(colName) = {''};
                        elseif isnumeric(colValue)
                            newRow.(colName) = NaN;
                        else
                            newRow.(colName) = colValue;
                        end
                    end
                else
                    addStatus('  ✓ All old columns present in new row');
                end
                
                % Ensure column order matches (critical for concatenation)
                newRow = newRow(:, existingData.Properties.VariableNames);
                addStatus('  ✓ Column alignment complete');
                
                % ==== HANDLE DATA TYPE MISMATCHES ====
                addStatus('Checking data types for each column...');
                allCols = existingData.Properties.VariableNames;
                typeMismatches = 0;
                
                for i = 1:length(allCols)
                    colName = allCols{i};
                    existingType = class(existingData.(colName));
                    newType = class(newRow.(colName));
                    
                    if ~strcmp(existingType, newType)
                        typeMismatches = typeMismatches + 1;
                        addStatus(sprintf('  Type mismatch in "%s": existing=%s, new=%s', ...
                            colName, existingType, newType));
                        
                        % Convert new row to match existing data type
                        if strcmp(existingType, 'cell') && ~strcmp(newType, 'cell')
                            % Convert new row value to cell
                            newRow.(colName) = {newRow.(colName)};
                            addStatus(sprintf('    → Converted new row to cell'));
                        elseif strcmp(newType, 'cell') && ~strcmp(existingType, 'cell')
                            % Convert existing data to cell
                            existingData.(colName) = num2cell(existingData.(colName));
                            addStatus(sprintf('    → Converted existing data to cell'));
                        elseif strcmp(existingType, 'double') && strcmp(newType, 'cell')
                            % New is cell but should be double
                            if iscell(newRow.(colName)) && ~isempty(newRow.(colName))
                                newRow.(colName) = newRow.(colName){1};
                            end
                            addStatus(sprintf('    → Extracted value from cell'));
                        elseif strcmp(newType, 'double') && strcmp(existingType, 'cell')
                            % Existing is cell but new is double
                            newRow.(colName) = {newRow.(colName)};
                            addStatus(sprintf('    → Wrapped in cell'));
                        end
                    end
                end
                
                if typeMismatches == 0
                    addStatus('  ✓ All data types match');
                else
                    addStatus(sprintf('  ✓ Fixed %d type mismatches', typeMismatches));
                end
                
                % Debug: Show all existing entries for this patient
                addStatus('========================================');
                addStatus('EXISTING ENTRIES IN DATABASE:');
                patientRows = cellfun(@(x) strncmp(x, truePatientID, 6), existingData.SliceID);
                if any(patientRows)
                    addStatus(sprintf('  Entries for Patient %s:', truePatientID));
                    patientData = existingData(patientRows, :);
                    for i = 1:height(patientData)
                        addStatus(sprintf('    Row %d: %s | %s', ...
                            find(patientRows, i, 'first'), ...
                            patientData.SliceID{i}, ...
                            patientData.Recording_Type{i}));
                    end
                else
                    addStatus(sprintf('  No existing entries for Patient %s', truePatientID));
                end
                addStatus('========================================');
                
                % Debug: Final check before append
                addStatus('FINAL DATABASE WRITE:');
                addStatus(sprintf('  Slice ID: %s', sliceID));
                addStatus(sprintf('  Recording Type: %s', recordingType));
                addStatus(sprintf('  Should overwrite: %s', string(shouldOverwrite)));
                
                % Check if this exact combination exists
                finalDuplicateMask = strcmp(existingData.SliceID, sliceID) & ...
                                    strcmp(existingData.Recording_Type, recordingType);
                
                numMatches = sum(finalDuplicateMask);
                addStatus(sprintf('  Existing entries matching %s + %s: %d', sliceID, recordingType, numMatches));
                
                if shouldOverwrite && numMatches > 0
                    % User explicitly chose to overwrite
                    addStatus('  → REMOVING old entry (user requested overwrite)');
                    % Show which entry is being removed
                    oldEntry = existingData(finalDuplicateMask, :);
                    rowToRemove = find(finalDuplicateMask, 1);
                    addStatus(sprintf('    Removing row %d: %s | %s', ...
                        rowToRemove, oldEntry.SliceID{1}, oldEntry.Recording_Type{1}));
                    existingData(finalDuplicateMask, :) = [];
                    addStatus(sprintf('  After removal: %d entries remain', height(existingData)));
                elseif numMatches > 0
                    % Duplicate exists but user didn't choose overwrite - this shouldn't happen!
                    addStatus('  ⚠️  WARNING: Duplicate exists but shouldOverwrite=false');
                    addStatus('  → ADDING as new entry anyway (will create duplicate!)');
                else
                    % No duplicate - normal case
                    addStatus('  → ADDING as new entry (no duplicate found)');
                end
                
                % ==== ROBUST CONCATENATION USING CELL ARRAYS ====
                % Instead of trying to concatenate tables directly (which fails with type mismatches),
                % convert both to cell arrays, concatenate those, then create new table
                
                addStatus('Using robust cell array concatenation method...');
                
                try
                    % Get column names (use existing data's columns as master list)
                    allColumns = existingData.Properties.VariableNames;
                    addStatus(sprintf('  Total columns: %d', length(allColumns)));
                    
                    % Convert existing data to cell array
                    existingCellArray = table2cell(existingData);
                    addStatus(sprintf('  Converted existing data: %d rows x %d cols', ...
                        size(existingCellArray, 1), size(existingCellArray, 2)));
                    
                    % Create new row as cell array matching column order
                    newRowCellArray = cell(1, length(allColumns));
                    for i = 1:length(allColumns)
                        colName = allColumns{i};
                        if ismember(colName, newRow.Properties.VariableNames)
                            % Column exists in new row
                            value = newRow.(colName);
                            if iscell(value)
                                newRowCellArray{i} = value{1};  % Extract from cell
                            else
                                newRowCellArray{i} = value;
                            end
                        else
                            % Column doesn't exist in new row - use default
                            newRowCellArray{i} = NaN;
                        end
                    end
                    
                    addStatus('  Created new row as cell array');
                    
                    % Check if we should remove old entry (overwrite mode)
                    if shouldOverwrite
                        finalDuplicateMask = strcmp(existingData.SliceID, sliceID) & ...
                                            strcmp(existingData.Recording_Type, recordingType);
                        if any(finalDuplicateMask)
                            addStatus(sprintf('  Removing old entry (overwrite mode)'));
                            existingCellArray(finalDuplicateMask, :) = [];
                        end
                    end
                    
                    % Concatenate cell arrays
                    combinedCellArray = [existingCellArray; newRowCellArray];
                    addStatus(sprintf('  Combined: %d total rows', size(combinedCellArray, 1)));
                    
                    % Convert back to table
                    combinedData = cell2table(combinedCellArray, 'VariableNames', allColumns);
                    addStatus('  ✓ Converted back to table successfully');
                    
                    % Count entries for this patient
                    patientEntries = sum(cellfun(@(x) strncmp(x, truePatientID, 6), combinedData.SliceID));
                    addStatus(sprintf('  Total entries for patient %s: %d', truePatientID, patientEntries));
                    
                    % List them
                    addStatus('  Entries for this patient:');
                    patientRows = cellfun(@(x) strncmp(x, truePatientID, 6), combinedData.SliceID);
                    patientData = combinedData(patientRows, :);
                    for i = 1:height(patientData)
                        addStatus(sprintf('    %d: %s | %s', i, ...
                            patientData.SliceID{i}, ...
                            patientData.Recording_Type{i}));
                    end
                    
                catch ME
                    addStatus('  ❌ Cell array method also failed!');
                    addStatus(['  Error: ' ME.message]);
                    addStatus('  Stack:');
                    for k = 1:length(ME.stack)
                        addStatus(sprintf('    %s (line %d)', ME.stack(k).name, ME.stack(k).line));
                    end
                    rethrow(ME);
                end
                addStatus('========================================');
                
            catch ME
                addStatus(['  Could not read existing sheet: ' ME.message]);
                addStatus('  Creating new database');
                combinedData = newRow;
            end
        else
            addStatus('  Creating new database file');
            combinedData = newRow;
        end
        
        % Sort by Patient (first 6 chars of Slice_ID), Slice, Recording Type
        [~, sortIdx] = sortrows(combinedData, {'SliceID', 'Recording_Type'});
        combinedData = combinedData(sortIdx, :);
        
        % Write to Excel
        writetable(combinedData, masterDBPath, 'Sheet', 'Master_Database');
        
        addStatus('========================================');
        addStatus('✓ MASTER DATABASE EXPORT COMPLETE!');
        addStatus('========================================');
        addStatus(sprintf('Entry: %s | Slice %d | %s | DIV %d', sliceID, sliceNum, recordingType, div));
        if numNoisyChannels > 0
            addStatus(sprintf('Noisy channels: %d (%s)', numNoisyChannels, noisyChannelStr));
        end
        addStatus(sprintf('Total database entries: %d', height(combinedData)));
        addStatus(sprintf('Location: %s', masterDBPath));
        addStatus('========================================');
        
        % Offer to open
        answer4 = questdlg('Open database file?', 'Success', 'Yes', 'No', 'Yes');
        if strcmp(answer4, 'Yes')
            try
                winopen(masterDBPath);
            catch
                addStatus('Could not auto-open file');
            end
        end
        
    catch ME
        addStatus('========================================');
        addStatus(['ERROR: ' ME.message]);
        addStatus('Stack trace:');
        addStatus(getReport(ME));
        addStatus('========================================');
    end
end

function metadata = parseFilenameMetadata(filename)
    % Parse MCS/Biometra MEA filename format
    % Example: 2025-11-19T13-25-12__cortex_div8_biometra_ID2519CT073_nodrug_spont_1__.h5
    
    metadata = struct();
    metadata.recording_date = '';
    metadata.recording_time = '';
    metadata.div = NaN;
    metadata.tissue_type = '';
    metadata.tissue_code = '';
    metadata.mea_type = '';
    metadata.patient_id = '';
    metadata.condition = '';
    metadata.recording_type = '';
    
    % Remove .h5 extension and convert to lower case for easier parsing
    filename_lower = lower(strrep(filename, '.h5', ''));
    filename_original = strrep(filename, '.h5', '');
    
    % === EXTRACT DATE AND TIME ===
    % Pattern: YYYY-MM-DDTHH-MM-SS or YYYY-MM-DD_HH-MM-SS
    dateTimePattern = '(\d{4})-(\d{2})-(\d{2})[T_](\d{2})-(\d{2})-(\d{2})';
    tokens = regexp(filename, dateTimePattern, 'tokens');
    
    if ~isempty(tokens)
        metadata.recording_date = sprintf('%s-%s-%s', tokens{1}{1}, tokens{1}{2}, tokens{1}{3});
        metadata.recording_time = sprintf('%s:%s:%s', tokens{1}{4}, tokens{1}{5}, tokens{1}{6});
    else
        % Try alternative pattern without time
        datePattern = '(\d{4})-(\d{2})-(\d{2})';
        tokens = regexp(filename, datePattern, 'tokens');
        if ~isempty(tokens)
            metadata.recording_date = sprintf('%s-%s-%s', tokens{1}{1}, tokens{1}{2}, tokens{1}{3});
        end
    end
    
    % === EXTRACT DIV ===
    divPattern = 'div[_-]?(\d+)';
    tokens = regexp(filename_lower, divPattern, 'tokens');
    if ~isempty(tokens)
        metadata.div = str2double(tokens{1}{1});
    end
    
    % === EXTRACT PATIENT ID AND PARSE TISSUE CODE ===
    % Pattern: ID followed by YYSSTTTSSS (e.g., ID2519CT073)
    % where TTT is the tissue code (CT, ET, EF, GC, etc.)
    patientPattern = '[ID|id]*(\d{4})([A-Z]{2,3})(\d{3})';
    tokens = regexp(filename_original, patientPattern, 'tokens');
    if ~isempty(tokens)
        yearSurgery = tokens{1}{1};
        tissueCode = tokens{1}{2};
        sliceNum = tokens{1}{3};
        
        metadata.patient_id = [yearSurgery tissueCode sliceNum];
        metadata.tissue_code = tissueCode;
        
        % Map tissue code to full name
        switch upper(tissueCode)
            case 'CT'
                metadata.tissue_type = 'Cortex Tumor';
            case 'ET'
                metadata.tissue_type = 'Epilepsy Temporal';
            case 'EF'
                metadata.tissue_type = 'Epilepsy Frontal';
            case 'GC'
                metadata.tissue_type = 'Glioma Cortex';
            case 'HC'
                metadata.tissue_type = 'Hippocampus Control';
            case 'HT'
                metadata.tissue_type = 'Hippocampus Tumor';
            otherwise
                metadata.tissue_type = tissueCode;  % Use code as-is
        end
    end
    
    % If we didn't get tissue type from patient ID, try keywords in filename
    if isempty(metadata.tissue_type)
        if contains(filename_lower, 'cortex') && contains(filename_lower, 'tumor')
            metadata.tissue_type = 'Cortex Tumor';
        elseif contains(filename_lower, 'cortex')
            metadata.tissue_type = 'Cortex';
        elseif contains(filename_lower, 'hippocampus') || contains(filename_lower, 'hippo')
            metadata.tissue_type = 'Hippocampus';
        elseif contains(filename_lower, 'tumor') || contains(filename_lower, 'glioma')
            metadata.tissue_type = 'Tumor';
        end
    end
    
    % === EXTRACT MEA TYPE ===
    if contains(filename_lower, 'biometra')
        metadata.mea_type = 'Biometra';
    elseif contains(filename_lower, 'mcs')
        metadata.mea_type = 'MCS';
    elseif contains(filename_lower, 'multichannel') || contains(filename_lower, 'multi_channel')
        metadata.mea_type = 'Multi Channel Systems';
    end
    
    % === EXTRACT CONDITION ===
    if contains(filename_lower, 'nodrug') || contains(filename_lower, 'no_drug') || contains(filename_lower, 'baseline')
        metadata.condition = 'Baseline';
    elseif contains(filename_lower, 'highk') || contains(filename_lower, 'high_k') || contains(filename_lower, 'mmk')
        metadata.condition = 'High K+';
    elseif contains(filename_lower, 'gabazine') || contains(filename_lower, 'gbz')
        metadata.condition = 'Gabazine';
    elseif contains(filename_lower, 'ttx')
        metadata.condition = 'TTX';
    elseif contains(filename_lower, 'cnqx')
        metadata.condition = 'CNQX';
    elseif contains(filename_lower, 'norepinephrine') || contains(filename_lower, 'ne')
        metadata.condition = 'Norepinephrine';
    end
    
    % === EXTRACT RECORDING TYPE ===
    if contains(filename_lower, 'spont_3') || contains(filename_lower, 'spont3')
        metadata.recording_type = 'Spont3';
    elseif contains(filename_lower, 'spont_2') || contains(filename_lower, 'spont2')
        metadata.recording_type = 'Spont2';
    elseif contains(filename_lower, 'spont_1') || contains(filename_lower, 'spont1') || contains(filename_lower, 'spont')
        metadata.recording_type = 'Spont1';
    end
    
    % Combine condition + recording type if both exist
    if ~isempty(metadata.condition) && ~isempty(metadata.recording_type)
        if strcmp(metadata.condition, 'High K+')
            metadata.recording_type = ['HighK_' metadata.recording_type];
        elseif strcmp(metadata.condition, 'Gabazine')
            metadata.recording_type = ['Gabazine_' metadata.recording_type];
        end
    end
end


function saveLayerMapFigure()
    % Save the layer map visualization to the figures folder
    % NOTE: This must be a nested function inside MEA_GUI_Spike_2026_July_V7
    
    figuresFolder = getappdata(fig, 'figuresFolder');
    
    if isempty(figuresFolder)
        % No figures folder set yet - skip saving
        return;
    end
    
    try
        % Get the current layer map from mainAxes
        mainAx = findobj(fig, 'Tag', 'mainAxes');
        
        if isempty(mainAx)
            return;
        end
        
        % Create a new invisible figure with the same content
        hFig = figure('Visible', 'off', 'Position', [100, 100, 800, 700]);
        
        % Copy the axes content
        newAx = copyobj(mainAx, hFig);
        set(newAx, 'Units', 'normalized', 'Position', [0.1, 0.1, 0.8, 0.85]);
        
        % Save with timestamp
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        filename = sprintf('MEA_Layer_Map_%s', timestamp);
        
        % Save in multiple formats
        print(hFig, fullfile(figuresFolder, filename), '-dpng', '-r300');
        set(hFig, 'Visible', 'on');
        savefig(hFig, fullfile(figuresFolder, [filename '.fig']));
        
        close(hFig);
        
        addStatus(sprintf('Layer map saved to: %s', figuresFolder));
        
    catch ME
        % Silent fail - not critical
        addStatus(['Note: Could not save layer map figure: ' ME.message]);
    end
end



end  % ← END der Hauptfunktion MEA_GUI_Spike_2026_July_V7




function data = parsePythonDict(rawText)
    % Parse Python-style dictionary from text files
    % Converts Python dict notation to MATLAB struct
    
    data = struct();
    
    % Remove comments
    lines = strsplit(rawText, '\n');
    cleanLines = {};
    for i = 1:length(lines)
        line = strtrim(lines{i});
        if ~isempty(line) && ~startsWith(line, '#')
            cleanLines{end+1} = line;
        end
    end
    cleanText = strjoin(cleanLines, ' ');
    
    % Find layer definitions using regex
    % Pattern: 'layerName': [electrode list]
    pattern = '''([^'']+)'':\s*\[([^\]]*)\]';
    matches = regexp(cleanText, pattern, 'tokens');
    
    for i = 1:length(matches)
        layerName = matches{i}{1};
        electrodeStr = matches{i}{2};
        
        % Clean layer name for MATLAB field
        layerNameClean = strrep(layerName, '-', '_');
        layerNameClean = strrep(layerNameClean, ' ', '_');
        
        % Parse electrode list
        if isempty(strtrim(electrodeStr))
            data.(layerNameClean) = {};
        else
            % Extract electrode names
            elecPattern = '["'']([A-Z]\d+)["'']';
            elecMatches = regexp(electrodeStr, elecPattern, 'tokens');
            
            electrodes = {};
            for j = 1:length(elecMatches)
                electrodes{end+1} = elecMatches{j}{1};
            end
            
            data.(layerNameClean) = electrodes;
        end
    end
end




   

function updateLayerPlotWithStim(fig)
    % Re-draw layer plot with stimulation electrode highlighted

    % Data from main GUI
    LayerDic      = getappdata(fig, 'LayerDic');
    meaType       = getappdata(fig, 'meaType');
    stimElectrode = getappdata(fig, 'stimulationElectrode');

    if isempty(LayerDic)
        addStatus('LayerDic is empty; cannot update layer plot.');
        return;
    end
    % get the axes chosen in loadLayerDictionary
    ax = getappdata(fig, 'LayerAxes');
    if isempty(ax) || ~ishandle(ax)
        addStatus('Warning: LayerAxes not found; cannot update layer plot.');
        return;
    end

   

    cla(ax);

    % Redraw the layer plot (same code as before, but using ax)
    imagesc(ax, LayerDic, [0 5]);
    set(ax, 'YDir', 'reverse');

    % Colormap
    cmap = [0.5 0.5 0.5; 0 0 0; 1 0 0; 0 1 0; 0 0 1; 1 1 0];
    colormap(ax, cmap);

    % Column labels
    if contains(meaType, 'J-naming')
        columnLabels = {'A','B','C','D','E','F','G','H','J','K','L','M','N','O','P','R'};
    else
        columnLabels = {'A','B','C','D','E','F','G','H','I','K','L','M','N','O','P','R'};
    end

    set(ax, 'XTick', 1:16, 'XTickLabel', columnLabels);
    xlabel(ax, 'Electrode Column');
    set(ax, 'YTick', 1:16, 'YTickLabel', 1:16);
    ylabel(ax, 'Electrode Row');
    title(ax, ['MEA Electrodes and Layers - ' meaType]);

    % Add layer labels
    hold(ax, 'on');
    for row = 1:16
        for col = 1:16
            val = LayerDic(row, col);
            if val > 0
                switch val
                    case 1, label = 'L1';
                    case 2, label = 'L2/3';
                    case 3, label = 'L4';
                    case 4, label = 'L5/6';
                    case 5, label = 'WM';
                    otherwise, label = '';
                end
                if ~isempty(label)
                    text(col, row, label, ...
                        'Parent', ax, ...
                        'HorizontalAlignment', 'center', ...
                        'VerticalAlignment', 'middle', ...
                        'Color', 'white', ...
                        'FontSize', 8, ...
                        'FontWeight', 'bold');
                end
            end
        end
    end

    % STIM HIGHLIGHT
    if ~isempty(stimElectrode)
        tokens = regexp(stimElectrode, '^([A-Z]+)(\d+)$', 'tokens');
        if ~isempty(tokens)
            colLetter = tokens{1}{1};
            rowNumber = str2double(tokens{1}{2});
            colIdx = find(strcmp(columnLabels, colLetter));

            if ~isempty(colIdx) && ~isnan(rowNumber)
                plot(ax, colIdx, rowNumber, 'p', 'MarkerSize', 25, ...
                    'MarkerFaceColor', 'cyan', 'MarkerEdgeColor', 'black', 'LineWidth', 2);
                text(colIdx, rowNumber-0.8, 'STIM', ...
                    'Parent', ax, ...
                    'HorizontalAlignment', 'center', 'Color', 'cyan', ...
                    'FontWeight', 'bold', 'FontSize', 9);
            end
        end
    end
    hold(ax, 'off');

    addStatus('Layer plot updated with stimulation electrode');
end

function addStatus(msg)
    if nargin < 1 || isempty(msg)
        return;
    end

    statusBox = findobj('Tag', 'statusLog');
    if isempty(statusBox) || ~ishandle(statusBox)
        % Fallback: print to command window
        fprintf('%s\n', msg);
        return;
    end

    oldText = get(statusBox, 'String');
    if ischar(oldText)
        oldText = {oldText};
    end

    oldText{end+1} = msg;
    set(statusBox, 'String', oldText, 'Value', numel(oldText));
    drawnow;
end

function [psthData, psthStats, responsiveChannels] = computePSTH(...
    spikeData, sortedChannels, stimTimes, preStimWindow, postStimWindow, binSize, samplingRate, artifactBlanking)
    % Compute Peri-Stimulus Time Histogram for all channels
    % artifactBlanking: time in seconds to blank after stimulus (default 0.003s = 3ms)
    
    if nargin < 8 || isempty(artifactBlanking)
        artifactBlanking = 0.003;  % Default 3ms
    end
    
    % Time bins
    timeEdges = -preStimWindow:binSize:postStimWindow;
    timeCenters = timeEdges(1:end-1) + binSize/2;
    numBins = length(timeCenters);
    
    % Initialize storage
    numChannels = length(sortedChannels);
    numStims = length(stimTimes);
    
    % Store spike counts for each channel and each stimulus
    allPSTHs = zeros(numChannels, numStims, numBins);
    
    % Compute PSTH for each channel
    for chIdx = 1:numChannels
        channel = sortedChannels{chIdx};
        spikeTimes = spikeData.(channel).times;
        
        if isempty(spikeTimes)
            continue;
        end
        
        % Align spikes to each stimulus
        for stimIdx = 1:numStims
            stimTime = stimTimes(stimIdx);
            
            % Get spikes in window around this stimulus
            windowSpikes = spikeTimes(spikeTimes >= (stimTime - preStimWindow) & ...
                                      spikeTimes <= (stimTime + postStimWindow));
            
            % Convert to relative times (relative to stim)
            relativeSpikes = windowSpikes - stimTime;
            
            % Bin the spikes
            counts = histcounts(relativeSpikes, timeEdges);
            allPSTHs(chIdx, stimIdx, :) = counts;
        end
    end
    
    % Compute statistics for each channel
    psthStats = table();
    responsiveChannels = {};
    
    for chIdx = 1:numChannels
        channel = sortedChannels{chIdx};
        
        % Average across stimuli
        meanPSTH = squeeze(mean(allPSTHs(chIdx, :, :), 2));
        stdPSTH = squeeze(std(allPSTHs(chIdx, :, :), 0, 2));
        
        % Baseline firing rate (pre-stim period)
        baselineBins = timeCenters < 0;
        baselineFR = mean(meanPSTH(baselineBins)) / binSize;
        baselineStd = std(meanPSTH(baselineBins)) / binSize;
        
        % Response period (0-100 ms post-stim)
        responseBins = (timeCenters >= 0) & (timeCenters <= 0.100);
        responseFR = mean(meanPSTH(responseBins)) / binSize;
        responseStd = std(meanPSTH(responseBins)) / binSize;
        
        % Peak response
        [peakFR, peakIdx] = max(meanPSTH / binSize);
        peakLatency = timeCenters(peakIdx);
        
        % Statistical test: Is response significantly different from baseline?
        % Use Wilcoxon signed-rank test
        baselineCounts = squeeze(mean(allPSTHs(chIdx, :, baselineBins), 3));
        responseCounts = squeeze(mean(allPSTHs(chIdx, :, responseBins), 3));
        
        if length(baselineCounts) > 3 && length(responseCounts) > 3
            try
                [p_value, ~] = signrank(baselineCounts, responseCounts);
            catch
                p_value = 1;
            end
        else
            p_value = 1;
        end
        
        % Response latency using FIRST-SPIKE method (sub-ms resolution)
        % with artifact blanking
        artifactBlanking_s = artifactBlanking;  % Use parameter passed to function
        
        spikeTimes = spikeData.(channel).times;
        firstSpikeLatencies = nan(numStims, 1);
        
        for stimIdx = 1:numStims
            stimTime = stimTimes(stimIdx);
            
            % Get spikes AFTER artifact blanking, within 50ms window
            postStimSpikes = spikeTimes(spikeTimes > (stimTime + artifactBlanking_s) & ...
                                         spikeTimes <= stimTime + 0.050);
            if ~isempty(postStimSpikes)
                firstSpikeLatencies(stimIdx) = (postStimSpikes(1) - stimTime) * 1000;  % ms
            end
        end
        
        % Use median across trials (robust to outliers)
        validLatencies = firstSpikeLatencies(~isnan(firstSpikeLatencies));
        if ~isempty(validLatencies)
            responseLatency = median(validLatencies);  % Already in ms
        else
            responseLatency = NaN;
        end
        
        % Add to table
        newRow = table({channel}, baselineFR, responseFR, peakFR, ...
            peakLatency * 1000, responseLatency, p_value, ...
            'VariableNames', {'Channel', 'Baseline_FR_Hz', 'Response_FR_Hz', ...
            'Peak_FR_Hz', 'Peak_Latency_ms', 'Response_Latency_ms', 'P_Value'});
        
        psthStats = [psthStats; newRow];
        
        % Mark as responsive if significant
        if p_value < 0.05 && responseFR > baselineFR
            responsiveChannels{end+1} = channel;
        end
    end
    
    % Store complete PSTH data
    psthData.timeCenters = timeCenters;
    psthData.timeEdges = timeEdges;
    psthData.allPSTHs = allPSTHs;
    psthData.sortedChannels = sortedChannels;
    psthData.binSize = binSize;
end

function generatePSTHFigure(psthData, psthStats, responsiveChannels, ...
    preStimWindow, postStimWindow, binSize, figuresFolder)
    % Generate comprehensive PSTH visualization
    
    timeCenters = psthData.timeCenters;
    allPSTHs = psthData.allPSTHs;
    sortedChannels = psthData.sortedChannels;
    
    % Compute population PSTH (average across all channels)
    populationPSTH = squeeze(mean(mean(allPSTHs, 1), 2)) / binSize;  % Convert to Hz
    populationSEM = squeeze(std(mean(allPSTHs, 1), 0, 2)) / binSize / sqrt(size(allPSTHs, 2));
    
    % ========== FIX: ENSURE ALL VECTORS ARE ROW VECTORS ==========
    timeCenters = timeCenters(:)';      % Force row vector
    populationPSTH = populationPSTH(:)';  % Force row vector
    populationSEM = populationSEM(:)';    % Force row vector
    % =============================================================
    
    % Create figure
    hFig = figure('Visible', 'off', 'Position', [100, 100, 1400, 900], 'Color', 'white');
    
    % ========== SUBPLOT 1: Population PSTH ==========
    subplot(2, 2, 1);
    
    % Plot with shaded error bar
    timeMs = timeCenters * 1000;  % Convert to ms
    
    fill([timeMs, fliplr(timeMs)], ...
         [populationPSTH + populationSEM, fliplr(populationPSTH - populationSEM)], ...
         [0.7 0.7 1], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
    hold on;
    plot(timeMs, populationPSTH, 'b-', 'LineWidth', 2);
    
    % Mark stimulation time
    xline(0, 'r--', 'Stim', 'LineWidth', 2, 'FontSize', 10, 'FontWeight', 'bold');
    
    % Get current y-limits for baseline shading
    yl = ylim;
    
    % Baseline shading (pre-stim period)
    baselineRegion = patch([-preStimWindow*1000, 0, 0, -preStimWindow*1000], ...
        [yl(1), yl(1), yl(2), yl(2)], [0.9 0.9 0.9], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.3);
    uistack(baselineRegion, 'bottom');
    
    xlabel('Time from Stimulation (ms)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Population Firing Rate (Hz)', 'FontSize', 12, 'FontWeight', 'bold');
    title('Population PSTH (All Channels)', 'FontSize', 14, 'FontWeight', 'bold');
    grid on;
    xlim([-preStimWindow*1000, postStimWindow*1000]);
    hold off;
    
    % ========== SUBPLOT 2: Heatmap of All Channels ==========
    subplot(2, 2, 2);
    
    % Average PSTH for each channel
    channelPSTHs = squeeze(mean(allPSTHs, 2)) / binSize;  % Channels x Time
    
    % Sort by response latency for visualization
    [~, sortIdx] = sort(psthStats.Response_Latency_ms, 'ascend', 'MissingPlacement', 'last');
    
    imagesc(timeMs, 1:length(sortedChannels), channelPSTHs(sortIdx, :));
    colormap(gca, 'jet');
    cb = colorbar;
    ylabel(cb, 'Firing Rate (Hz)', 'FontSize', 10);
    
    hold on;
    xline(0, 'w--', 'LineWidth', 2);
    hold off;
    
    xlabel('Time from Stimulation (ms)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Channel (sorted by latency)', 'FontSize', 12, 'FontWeight', 'bold');
    title('PSTH Heatmap (All Channels)', 'FontSize', 14, 'FontWeight', 'bold');
    
    % ========== SUBPLOT 3: Top Responsive Channels ==========
    subplot(2, 2, 3);
    
    if ~isempty(responsiveChannels)
        % Show top 10 responsive channels
        numToShow = min(10, length(responsiveChannels));
        
        hold on;
        colors = lines(numToShow);
        
        for i = 1:numToShow
            channel = responsiveChannels{i};
            chIdx = find(strcmp(sortedChannels, channel));
            
            channelPSTH = squeeze(mean(allPSTHs(chIdx, :, :), 2)) / binSize;
            channelPSTH = channelPSTH(:)';  % Force row vector
            
            plot(timeMs, channelPSTH, 'Color', colors(i, :), ...
                'LineWidth', 1.5, 'DisplayName', channel);
        end
        
        xline(0, 'r--', 'Stim', 'LineWidth', 2);
        
        xlabel('Time from Stimulation (ms)', 'FontSize', 12, 'FontWeight', 'bold');
        ylabel('Firing Rate (Hz)', 'FontSize', 12, 'FontWeight', 'bold');
        title(sprintf('Top %d Responsive Channels', numToShow), 'FontSize', 14, 'FontWeight', 'bold');
        legend('Location', 'eastoutside', 'FontSize', 8);
        grid on;
        xlim([-preStimWindow*1000, postStimWindow*1000]);
        hold off;
    else
        text(0.5, 0.5, 'No Responsive Channels', ...
            'HorizontalAlignment', 'center', 'FontSize', 14);
        axis off;
    end
    
    % ========== SUBPLOT 4: Summary Statistics ==========
    subplot(2, 2, 4);
    axis off;
    
    % Compute summary statistics
    numResponsive = length(responsiveChannels);
    totalChannels = length(sortedChannels);
    percentResponsive = (numResponsive / totalChannels) * 100;
    
    validLatencies = psthStats.Response_Latency_ms(~isnan(psthStats.Response_Latency_ms));
    if ~isempty(validLatencies)
        meanLatency = mean(validLatencies);
        medianLatency = median(validLatencies);
        minLatency = min(validLatencies);
    else
        meanLatency = NaN;
        medianLatency = NaN;
        minLatency = NaN;
    end
    
    baselineFR = mean(psthStats.Baseline_FR_Hz);
    peakFR = mean(psthStats.Peak_FR_Hz);
    
    % Create summary text
    summaryText = {
        '\bfPSTH ANALYSIS SUMMARY\rm';
        '';
        '\bfResponsiveness:\rm';
        sprintf('  Responsive Channels: %d / %d (%.1f%%)', numResponsive, totalChannels, percentResponsive);
        sprintf('  Significance threshold: p < 0.05');
        '';
        '\bfResponse Latency:\rm';
        sprintf('  Mean: %.1f ms', meanLatency);
        sprintf('  Median: %.1f ms', medianLatency);
        sprintf('  Minimum: %.1f ms', minLatency);
        '';
        '\bfFiring Rate:\rm';
        sprintf('  Baseline (avg): %.2f Hz', baselineFR);
        sprintf('  Peak (avg): %.2f Hz', peakFR);
        sprintf('  Modulation: %.1fx', peakFR / baselineFR);
        '';
        '\bfAnalysis Parameters:\rm';
        sprintf('  Pre-stim window: %.0f ms', preStimWindow * 1000);
        sprintf('  Post-stim window: %.0f ms', postStimWindow * 1000);
        sprintf('  Bin size: %.1f ms', binSize * 1000);
    };
    
    text(0.05, 0.95, summaryText, ...
        'Units', 'normalized', ...
        'VerticalAlignment', 'top', ...
        'FontSize', 10, ...
        'FontName', 'FixedWidth', ...
        'Interpreter', 'tex');
    
    % Save figure
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    print(hFig, fullfile(figuresFolder, ['PSTH_Analysis_' timestamp]), '-dpng', '-r300');
    set(hFig, 'Visible', 'on');
    savefig(hFig, fullfile(figuresFolder, ['PSTH_Analysis_' timestamp '.fig']));
    close(hFig);
end

function generateStimRasterFigure(spikeData, sortedChannels, stimTimes, ...
    preStimWindow, postStimWindow, figuresFolder)
    % RASTER PLOT ALIGNED TO STIMULATION
    % Shows spike timing across trials for visualization of response reliability
    
    fig = figure('Position', [100, 100, 1400, 900], 'Color', 'w');
    
    nChannels = length(sortedChannels);
    nStims = length(stimTimes);
    
    % Limit to top 20 most active channels to keep readable
    % Calculate total spikes per channel in response window
    spikeCounts = zeros(nChannels, 1);
    for ch = 1:nChannels
        chName = sortedChannels{ch};
        if isfield(spikeData, chName)
            spikeTimes = spikeData.(chName).times;
            for s = 1:nStims
                windowStart = stimTimes(s);
                windowEnd = stimTimes(s) + postStimWindow;
                spikeCounts(ch) = spikeCounts(ch) + ...
                    sum(spikeTimes >= windowStart & spikeTimes <= windowEnd);
            end
        end
    end
    
    [~, sortIdx] = sort(spikeCounts, 'descend');
    topChannels = sortIdx(1:min(20, nChannels));
    
    % ---- Panel 1: Full raster (all channels, aggregated across trials) ----
    subplot(2, 2, [1, 3]);
    hold on;
    
    colors = lines(length(topChannels));
    yPos = 0;
    yTickPositions = [];
    yTickLabels = {};
    
    for chIdx = 1:length(topChannels)
        ch = topChannels(chIdx);
        chName = sortedChannels{ch};
        
        if isfield(spikeData, chName)
            spikeTimes = spikeData.(chName).times;
            
            for s = 1:nStims
                stimTime = stimTimes(s);
                
                % Get spikes relative to this stim
                relSpikes = spikeTimes - stimTime;
                validSpikes = relSpikes(relSpikes >= -preStimWindow & ...
                                        relSpikes <= postStimWindow);
                
                % Plot as ticks
                yVal = yPos + (s - 1) / nStims * 0.8;
                if ~isempty(validSpikes)
                    plot(validSpikes * 1000, ones(size(validSpikes)) * yVal, ...
                        '|', 'Color', colors(chIdx, :), 'MarkerSize', 2);
                end
            end
        end
        
        yTickPositions(end+1) = yPos + 0.4;
        yTickLabels{end+1} = chName;
        yPos = yPos + 1;
    end
    
    % Stim line
    xline(0, 'r--', 'LineWidth', 1.5);
    
    xlabel('Time from Stimulation (ms)');
    ylabel('Channel');
    title(sprintf('Stimulus-Aligned Raster (Top %d Channels, %d trials)', ...
        length(topChannels), nStims));
    xlim([-preStimWindow postStimWindow] * 1000);
    ylim([-0.5, yPos + 0.5]);
    yticks(yTickPositions);
    yticklabels(yTickLabels);
    
    % Shade pre-stim
    patch([-preStimWindow*1000 0 0 -preStimWindow*1000], ...
          [-0.5 -0.5 yPos+0.5 yPos+0.5], [0.9 0.9 0.9], ...
          'EdgeColor', 'none', 'FaceAlpha', 0.3);
    
    hold off;
    box on;
    
    % ---- Panel 2: Single channel detail (most active) ----
    subplot(2, 2, 2);
    hold on;
    
    topCh = topChannels(1);
    topChName = sortedChannels{topCh};
    spikeTimes = spikeData.(topChName).times;
    
    for s = 1:nStims
        stimTime = stimTimes(s);
        relSpikes = spikeTimes - stimTime;
        validSpikes = relSpikes(relSpikes >= -preStimWindow & ...
                                relSpikes <= postStimWindow);
        
        if ~isempty(validSpikes)
            plot(validSpikes * 1000, ones(size(validSpikes)) * s, ...
                'k|', 'MarkerSize', 4);
        end
    end
    
    xline(0, 'r--', 'LineWidth', 1.5);
    xlabel('Time from Stimulation (ms)');
    ylabel('Trial');
    title(sprintf('Channel %s (most responsive)', topChName));
    xlim([-preStimWindow postStimWindow] * 1000);
    ylim([0 nStims + 1]);
    box on;
    hold off;
    
    % ---- Panel 3: Trial-averaged spike count histogram ----
    subplot(2, 2, 4);
    
    % Count spikes per trial in early response window (0-50 ms)
    earlyWindow = 0.050;
    spikesPerTrial = zeros(nStims, 1);
    
    for s = 1:nStims
        stimTime = stimTimes(s);
        for ch = 1:nChannels
            chName = sortedChannels{ch};
            if isfield(spikeData, chName)
                spikeTimes_ch = spikeData.(chName).times;
                spikesPerTrial(s) = spikesPerTrial(s) + ...
                    sum(spikeTimes_ch >= stimTime & ...
                        spikeTimes_ch <= stimTime + earlyWindow);
            end
        end
    end
    
    histogram(spikesPerTrial, 'FaceColor', [0.3 0.5 0.8], 'EdgeColor', 'w');
    xlabel('Spike Count (0-50 ms post-stim)');
    ylabel('Number of Trials');
    title('Trial-to-Trial Response Variability');
    
    % Add stats
    text(0.95, 0.95, sprintf('Mean: %.1f\nSD: %.1f\nCV: %.2f', ...
        mean(spikesPerTrial), std(spikesPerTrial), ...
        std(spikesPerTrial)/mean(spikesPerTrial)), ...
        'Units', 'normalized', 'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'top', 'FontSize', 10);
    
    box on;
    
    % Save
    sgtitle('Stimulation-Aligned Raster Analysis', 'FontSize', 14, 'FontWeight', 'bold');
    
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    saveas(fig, fullfile(figuresFolder, sprintf('Stim_Raster_%s.png', timestamp)));
    saveas(fig, fullfile(figuresFolder, sprintf('Stim_Raster_%s.fig', timestamp)));
    close(fig);
end


function generateLatencyFigure(psthStats, responsiveChannels, figuresFolder)
    % RESPONSE LATENCY DISTRIBUTION
    % Visualizes the distribution of response onset latencies
    
    fig = figure('Position', [100, 100, 1200, 800], 'Color', 'w');
    
    % Get latencies for responsive channels only
    respIdx = ismember(psthStats.Channel, responsiveChannels);
    latencies = psthStats.Response_Latency_ms(respIdx);
    
    % Remove NaN/Inf
    validLatencies = latencies(isfinite(latencies) & latencies > 0);
    
    if isempty(validLatencies)
        text(0.5, 0.5, 'No valid latency data', 'HorizontalAlignment', 'center', ...
            'FontSize', 14);
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        saveas(fig, fullfile(figuresFolder, sprintf('Latency_Analysis_%s.png', timestamp)));
        close(fig);
        return;
    end
    
    % ---- Panel 1: Latency histogram ----
    subplot(2, 2, 1);
    
    edges = 0:1:max(validLatencies)+5;  % 1 ms bins
    histogram(validLatencies, edges, 'FaceColor', [0.2 0.6 0.4], 'EdgeColor', 'w');
    
    xlabel('Response Latency (ms)');
    ylabel('Number of Channels');
    title('Response Latency Distribution');
    
    % Add statistics
    meanLat = mean(validLatencies);
    medianLat = median(validLatencies);
    xline(meanLat, 'r-', 'LineWidth', 2);
    xline(medianLat, 'b--', 'LineWidth', 2);
    legend({'', sprintf('Mean: %.1f ms', meanLat), ...
            sprintf('Median: %.1f ms', medianLat)}, 'Location', 'northeast');
    box on;
    
    % ---- Panel 2: Cumulative distribution ----
    subplot(2, 2, 2);
    
    [f, x] = ecdf(validLatencies);
    plot(x, f * 100, 'b-', 'LineWidth', 2);
    
    xlabel('Response Latency (ms)');
    ylabel('Cumulative Percentage');
    title('Cumulative Latency Distribution');
    grid on;
    
    % Mark key percentiles
    hold on;
    p25 = prctile(validLatencies, 25);
    p50 = prctile(validLatencies, 50);
    p75 = prctile(validLatencies, 75);
    
    plot([p25 p25], [0 25], 'k--');
    plot([p50 p50], [0 50], 'k--');
    plot([p75 p75], [0 75], 'k--');
    
    text(p75 + 2, 50, sprintf('IQR: %.1f - %.1f ms', p25, p75), 'FontSize', 10);
    hold off;
    box on;
    
    % ---- Panel 3: Latency vs Response Magnitude ----
    subplot(2, 2, 3);
    
    peakRates = psthStats.Peak_FR_Hz(respIdx);
    validPeaks = peakRates(isfinite(latencies) & latencies > 0);
    
    scatter(validLatencies, validPeaks, 30, [0.3 0.5 0.8], 'filled', 'MarkerFaceAlpha', 0.6);
    xlabel('Response Latency (ms)');
    ylabel('Peak Firing Rate (Hz)');
    title('Latency vs Response Magnitude');
    
    % Fit line if correlation exists
    if length(validLatencies) > 5
        [r, p] = corrcoef(validLatencies, validPeaks);
        if numel(r) > 1
            text(0.05, 0.95, sprintf('r = %.2f, p = %.3f', r(1,2), p(1,2)), ...
                'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 10);
        end
    end
    box on;
    
    % ---- Panel 4: Summary statistics ----
    subplot(2, 2, 4);
    axis off;
    
    stats_text = {
        'LATENCY STATISTICS', ...
        '', ...
        sprintf('Responsive Channels: %d', length(validLatencies)), ...
        '', ...
        sprintf('Mean Latency: %.2f ms', mean(validLatencies)), ...
        sprintf('Median Latency: %.2f ms', median(validLatencies)), ...
        sprintf('Std Deviation: %.2f ms', std(validLatencies)), ...
        '', ...
        sprintf('Minimum: %.2f ms', min(validLatencies)), ...
        sprintf('Maximum: %.2f ms', max(validLatencies)), ...
        sprintf('Range: %.2f ms', max(validLatencies) - min(validLatencies)), ...
        '', ...
        sprintf('25th Percentile: %.2f ms', p25), ...
        sprintf('75th Percentile: %.2f ms', p75), ...
        sprintf('IQR: %.2f ms', p75 - p25)
    };
    
    text(0.1, 0.9, stats_text, 'VerticalAlignment', 'top', ...
        'FontSize', 11, 'FontName', 'FixedWidth');
    
    % Save
    sgtitle('Response Latency Analysis', 'FontSize', 14, 'FontWeight', 'bold');
    
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    saveas(fig, fullfile(figuresFolder, sprintf('Latency_Analysis_%s.png', timestamp)));
    saveas(fig, fullfile(figuresFolder, sprintf('Latency_Analysis_%s.fig', timestamp)));
    close(fig);
end


function generateTriggeringFigure(triggerStats, evokedEventIndices, ...
    stimTimes, eventOnsets, eventOffsets, figuresFolder)
    % EVENT TRIGGERING ANALYSIS
    % Visualizes relationship between stimulation and network events
    
    fig = figure('Position', [100, 100, 1400, 800], 'Color', 'w');
    
    nStims = length(stimTimes);
    nEvents = length(eventOnsets);
    
    % ---- Panel 1: Stim-Event temporal alignment ----
    subplot(2, 3, [1, 4]);
    hold on;
    
    % Plot all events as horizontal bars
    for e = 1:nEvents
        eventColor = [0.7 0.7 0.7];  % Default: spontaneous
        if ismember(e, evokedEventIndices)
            eventColor = [0.8 0.2 0.2];  % Evoked: red
        end
        
        plot([eventOnsets(e) eventOffsets(e)], [e e], '-', ...
            'Color', eventColor, 'LineWidth', 2);
    end
    
    % Overlay stim times as vertical lines
    for s = 1:nStims
        plot([stimTimes(s) stimTimes(s)], [0 nEvents+1], 'b-', ...
            'LineWidth', 0.5, 'Color', [0.2 0.5 0.8 0.5]);
    end
    
    xlabel('Time (s)');
    ylabel('Event #');
    title('Temporal Relationship: Stimulations & Events');
    ylim([0 nEvents + 1]);
    
    % Legend
    plot(NaN, NaN, '-', 'Color', [0.8 0.2 0.2], 'LineWidth', 2);
    plot(NaN, NaN, '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 2);
    plot(NaN, NaN, '-', 'Color', [0.2 0.5 0.8], 'LineWidth', 1);
    legend({'Evoked Events', 'Spontaneous Events', 'Stimulation'}, ...
        'Location', 'northeast');
    
    hold off;
    box on;
    
    % ---- Panel 2: Event onset latency from stim ----
    subplot(2, 3, 2);
    
    % Calculate latency of evoked events
    evokedLatencies = [];
    for idx = 1:length(evokedEventIndices)
        e = evokedEventIndices(idx);
        eventTime = eventOnsets(e);
        
        % Find preceding stim
        precedingStims = stimTimes(stimTimes < eventTime);
        if ~isempty(precedingStims)
            latency = eventTime - precedingStims(end);
            if latency < 1.0  % Only within 1 second
                evokedLatencies(end+1) = latency * 1000;  % Convert to ms
            end
        end
    end
    
    if ~isempty(evokedLatencies)
        histogram(evokedLatencies, 20, 'FaceColor', [0.8 0.3 0.3], 'EdgeColor', 'w');
        xlabel('Latency from Stimulation (ms)');
        ylabel('Number of Events');
        title('Evoked Event Latency Distribution');
        
        meanLat = mean(evokedLatencies);
        xline(meanLat, 'k--', 'LineWidth', 1.5);
        text(0.95, 0.95, sprintf('Mean: %.1f ms', meanLat), ...
            'Units', 'normalized', 'HorizontalAlignment', 'right', ...
            'VerticalAlignment', 'top');
    else
        text(0.5, 0.5, 'No evoked events detected', 'HorizontalAlignment', 'center');
    end
    box on;
    
    % ---- Panel 3: Triggering probability pie chart ----
    subplot(2, 3, 3);
    
    nEvoked = length(evokedEventIndices);
    nNoResponse = nStims - nEvoked;
    
    if nEvoked > 0 || nNoResponse > 0
        pie([nEvoked, nNoResponse]);
        legend({sprintf('Triggered (%d)', nEvoked), ...
                sprintf('No Event (%d)', nNoResponse)}, ...
               'Location', 'southoutside');
        title(sprintf('Triggering Probability: %.1f%%', ...
            triggerStats.TriggerProbability_Percent));
    end
    
    % ---- Panel 4: Inter-event interval analysis ----
    subplot(2, 3, 5);
    
    if nEvents > 1
        IEIs = diff(eventOnsets);
        
        histogram(IEIs, 30, 'FaceColor', [0.4 0.6 0.8], 'EdgeColor', 'w');
        xlabel('Inter-Event Interval (s)');
        ylabel('Count');
        title('Inter-Event Interval Distribution');
        
        % Mark mean stim interval
        if nStims > 1
            meanStimInterval = mean(diff(stimTimes));
            xline(meanStimInterval, 'r--', 'LineWidth', 1.5);
            text(0.95, 0.95, sprintf('Mean Stim Interval: %.2f s', meanStimInterval), ...
                'Units', 'normalized', 'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'top', 'Color', 'r');
        end
    else
        text(0.5, 0.5, 'Insufficient events for IEI analysis', ...
            'HorizontalAlignment', 'center');
    end
    box on;
    
    % ---- Panel 5: Summary statistics ----
    subplot(2, 3, 6);
    axis off;
    
    stats_text = {
        'EVENT TRIGGERING SUMMARY', ...
        '', ...
        sprintf('Total Stimulations: %d', nStims), ...
        sprintf('Total Events: %d', nEvents), ...
        '', ...
        sprintf('Evoked Events: %d', nEvoked), ...
        sprintf('Spontaneous Events: %d', nEvents - nEvoked), ...
        '', ...
        sprintf('Trigger Probability: %.1f%%', triggerStats.TriggerProbability_Percent), ...
        '', ...
        sprintf('Detection Window: %.0f ms', triggerStats.DetectionWindow_ms)
    };
    
    if isfield(triggerStats, 'MeanEventLatency_ms')
        stats_text{end+1} = '';
        stats_text{end+1} = sprintf('Mean Event Latency: %.1f ms', ...
            triggerStats.MeanEventLatency_ms);
    end
    
    text(0.1, 0.9, stats_text, 'VerticalAlignment', 'top', ...
        'FontSize', 11, 'FontName', 'FixedWidth');
    
    % Save
    sgtitle('Stimulation Event Triggering Analysis', 'FontSize', 14, 'FontWeight', 'bold');
    
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    saveas(fig, fullfile(figuresFolder, sprintf('Event_Triggering_%s.png', timestamp)));
    saveas(fig, fullfile(figuresFolder, sprintf('Event_Triggering_%s.fig', timestamp)));
    close(fig);
end


function generateSpatialResponseFigure(psthStats, responsiveChannels, ...
    stimElectrode, LayerDic, meaType, figuresFolder)
    % SPATIAL RESPONSE MAP
    % Maps stimulation response metrics onto the MEA grid
    
    fig = figure('Position', [100, 100, 1600, 900], 'Color', 'w');
    
    % Determine column labels based on MEA type
    if contains(meaType, 'J-naming')
        columnLabels = {'A','B','C','D','E','F','G','H','J','K','L','M','N','O','P','R'};
    else
        columnLabels = {'A','B','C','D','E','F','G','H','I','K','L','M','N','O','P','R'};
    end
    
    % Parse stimulation electrode position
    stimCol = NaN;
    stimRow = NaN;
    if ~isempty(stimElectrode)
        tokens = regexp(stimElectrode, '^([A-Z]+)(\d+)$', 'tokens');
        if ~isempty(tokens)
            colLetter = tokens{1}{1};
            stimRow = str2double(tokens{1}{2});
            stimCol = find(strcmp(columnLabels, colLetter));
        end
    end
    
    % Initialize 16x16 grids for metrics
    peakFRGrid = nan(16, 16);
    latencyGrid = nan(16, 16);
    responsiveGrid = zeros(16, 16);  % Binary: responsive or not
    distanceGrid = nan(16, 16);      % Distance from stim electrode
    
    % Parse channel names and fill grids
    for i = 1:height(psthStats)
        chName = psthStats.Channel{i};
        
        % Parse channel name (e.g., 'A10' -> col=1, row=10)
        tokens = regexp(chName, '^([A-Z]+)(\d+)$', 'tokens');
        if ~isempty(tokens)
            colLetter = tokens{1}{1};
            rowNum = str2double(tokens{1}{2});
            colIdx = find(strcmp(columnLabels, colLetter));
            
            if ~isempty(colIdx) && ~isnan(rowNum) && rowNum >= 1 && rowNum <= 16
                peakFRGrid(rowNum, colIdx) = psthStats.Peak_FR_Hz(i);
                latencyGrid(rowNum, colIdx) = psthStats.Response_Latency_ms(i);
                
                if ismember(chName, responsiveChannels)
                    responsiveGrid(rowNum, colIdx) = 1;
                end
                
                % Calculate distance from stim electrode (in electrode units)
                if ~isnan(stimCol) && ~isnan(stimRow)
                    distanceGrid(rowNum, colIdx) = sqrt((colIdx - stimCol)^2 + (rowNum - stimRow)^2);
                end
            end
        end
    end
    
    % ---- Panel 1: Peak Firing Rate Map ----
    subplot(2, 3, 1);
    
    imagesc(peakFRGrid, 'AlphaData', ~isnan(peakFRGrid));
    set(gca, 'Color', [0.9 0.9 0.9], 'YDir', 'reverse');
    colormap(gca, 'hot');
    cb = colorbar;
    cb.Label.String = 'Peak FR (Hz)';
    
    hold on;
    % Mark stim electrode
    if ~isnan(stimCol) && ~isnan(stimRow)
        plot(stimCol, stimRow, 'p', 'MarkerSize', 20, ...
            'MarkerFaceColor', 'cyan', 'MarkerEdgeColor', 'black', 'LineWidth', 2);
    end
    hold off;
    
    set(gca, 'XTick', 1:16, 'XTickLabel', columnLabels, 'FontSize', 7);
    set(gca, 'YTick', 1:16, 'YTickLabel', 1:16);
    xlabel('Column'); ylabel('Row');
    title('Peak Firing Rate');
    
    % ---- Panel 2: Response Latency Map ----
    subplot(2, 3, 2);
    
    % Use reversed colormap so shorter latency = warmer color
    imagesc(latencyGrid, 'AlphaData', ~isnan(latencyGrid));
    set(gca, 'Color', [0.9 0.9 0.9], 'YDir', 'reverse');
    cmap_latency = flipud(hot(256));  % Flip so low latency is bright
    colormap(gca, cool(256));
    cb = colorbar;
    cb.Label.String = 'Latency (ms)';
    
    hold on;
    if ~isnan(stimCol) && ~isnan(stimRow)
        plot(stimCol, stimRow, 'p', 'MarkerSize', 20, ...
            'MarkerFaceColor', 'cyan', 'MarkerEdgeColor', 'black', 'LineWidth', 2);
    end
    hold off;
    
    set(gca, 'XTick', 1:16, 'XTickLabel', columnLabels, 'FontSize', 7);
    set(gca, 'YTick', 1:16, 'YTickLabel', 1:16);
    xlabel('Column'); ylabel('Row');
    title('Response Latency');
    
    % ---- Panel 3: Responsive Channels Overlay on Layer Map ----
    subplot(2, 3, 3);
    
    % Show layer map as background
    imagesc(LayerDic, [0 5]);
    set(gca, 'YDir', 'reverse');
    cmap_layers = [0.5 0.5 0.5; 0 0 0; 1 0 0; 0 1 0; 0 0 1; 1 1 0];
    colormap(gca, cmap_layers);
    
    hold on;
    % Overlay responsive channels as circles
    [respRows, respCols] = find(responsiveGrid == 1);
    for k = 1:length(respRows)
        plot(respCols(k), respRows(k), 'o', 'MarkerSize', 10, ...
            'MarkerFaceColor', 'white', 'MarkerEdgeColor', 'black', 'LineWidth', 1.5);
    end
    
    % Mark non-responsive recorded channels
    [nonRespRows, nonRespCols] = find(responsiveGrid == 0 & ~isnan(peakFRGrid));
    for k = 1:length(nonRespRows)
        plot(nonRespCols(k), nonRespRows(k), 'x', 'MarkerSize', 8, ...
            'Color', [0.5 0.5 0.5], 'LineWidth', 1.5);
    end
    
    % Mark stim electrode
    if ~isnan(stimCol) && ~isnan(stimRow)
        plot(stimCol, stimRow, 'p', 'MarkerSize', 25, ...
            'MarkerFaceColor', 'cyan', 'MarkerEdgeColor', 'black', 'LineWidth', 2);
    end
    hold off;
    
    set(gca, 'XTick', 1:16, 'XTickLabel', columnLabels, 'FontSize', 7);
    set(gca, 'YTick', 1:16, 'YTickLabel', 1:16);
    xlabel('Column'); ylabel('Row');
    title('Responsive Channels on Layer Map');
    legend({'Responsive', 'Non-responsive', 'Stim'}, 'Location', 'northeastoutside');
    
    % ---- Panel 4: Response vs Distance from Stim ----
    subplot(2, 3, 4);
    
    % Flatten and remove NaNs
    validIdx = ~isnan(distanceGrid(:)) & ~isnan(peakFRGrid(:));
    distances = distanceGrid(validIdx);
    peakFRs = peakFRGrid(validIdx);
    
    if ~isempty(distances)
        scatter(distances, peakFRs, 50, [0.3 0.5 0.8], 'filled', 'MarkerFaceAlpha', 0.6);
        xlabel('Distance from Stim (electrode units)');
        ylabel('Peak Firing Rate (Hz)');
        title('Response Magnitude vs Distance');
        
        % Fit and show correlation
        if length(distances) > 5
            [r, p] = corrcoef(distances, peakFRs);
            if numel(r) > 1
                % Add trend line
                coeffs = polyfit(distances, peakFRs, 1);
                xfit = linspace(min(distances), max(distances), 100);
                yfit = polyval(coeffs, xfit);
                hold on;
                plot(xfit, yfit, 'r--', 'LineWidth', 1.5);
                hold off;
                
                text(0.95, 0.95, sprintf('r = %.2f\np = %.3f', r(1,2), p(1,2)), ...
                    'Units', 'normalized', 'HorizontalAlignment', 'right', ...
                    'VerticalAlignment', 'top', 'FontSize', 10);
            end
        end
    else
        text(0.5, 0.5, 'No valid distance data', 'HorizontalAlignment', 'center');
    end
    box on;
    
    % ---- Panel 5: Latency vs Distance from Stim ----
    subplot(2, 3, 5);
    
    validIdx = ~isnan(distanceGrid(:)) & ~isnan(latencyGrid(:)) & latencyGrid(:) > 0;
    distances = distanceGrid(validIdx);
    latencies = latencyGrid(validIdx);
    
    if ~isempty(distances)
        scatter(distances, latencies, 50, [0.8 0.3 0.3], 'filled', 'MarkerFaceAlpha', 0.6);
        xlabel('Distance from Stim (electrode units)');
        ylabel('Response Latency (ms)');
        title('Response Latency vs Distance');
        
        if length(distances) > 5
            [r, p] = corrcoef(distances, latencies);
            if numel(r) > 1
                coeffs = polyfit(distances, latencies, 1);
                xfit = linspace(min(distances), max(distances), 100);
                yfit = polyval(coeffs, xfit);
                hold on;
                plot(xfit, yfit, 'r--', 'LineWidth', 1.5);
                hold off;
                
                % Estimate propagation velocity if positive correlation
                if coeffs(1) > 0
                    % Slope is ms per electrode unit
                    % Electrode spacing typically 200 µm
                    electrodeSpacing_um = 200;
                    velocity_m_s = electrodeSpacing_um / (coeffs(1) * 1000);  % m/s
                    text(0.95, 0.85, sprintf('Est. velocity: %.2f m/s', velocity_m_s), ...
                        'Units', 'normalized', 'HorizontalAlignment', 'right', ...
                        'VerticalAlignment', 'top', 'FontSize', 9, 'Color', [0.5 0 0]);
                end
                
                text(0.95, 0.95, sprintf('r = %.2f\np = %.3f', r(1,2), p(1,2)), ...
                    'Units', 'normalized', 'HorizontalAlignment', 'right', ...
                    'VerticalAlignment', 'top', 'FontSize', 10);
            end
        end
    else
        text(0.5, 0.5, 'No valid latency-distance data', 'HorizontalAlignment', 'center');
    end
    box on;
    
    % ---- Panel 6: Summary Statistics ----
    subplot(2, 3, 6);
    axis off;
    
    nResponsive = sum(responsiveGrid(:));
    nRecorded = sum(~isnan(peakFRGrid(:)));
    
    % Layer-specific responsiveness
    layerNames = {'L1', 'L2/3', 'L4', 'L5/6', 'WM'};
    layerStats = '';
    for L = 1:5
        layerMask = (LayerDic == L);
        nInLayer = sum(layerMask(:) & ~isnan(peakFRGrid(:)));
        nRespInLayer = sum(layerMask(:) & responsiveGrid(:));
        if nInLayer > 0
            layerStats = [layerStats sprintf('%s: %d/%d (%.0f%%)\n', ...
                layerNames{L}, nRespInLayer, nInLayer, 100*nRespInLayer/nInLayer)];
        end
    end
    
    stats_text = {
        'SPATIAL RESPONSE SUMMARY', ...
        '(Averaged across all stim trials)', ...
        '', ...
        sprintf('Stimulation Electrode: %s', stimElectrode), ...
        '', ...
        sprintf('Responsive Channels: %d / %d (%.1f%%)', ...
            nResponsive, nRecorded, 100*nResponsive/nRecorded), ...
        '', ...
        'LAYER-SPECIFIC RESPONSIVENESS:', ...
        layerStats
    };
    
    text(0.1, 0.95, stats_text, 'VerticalAlignment', 'top', ...
        'FontSize', 11, 'FontName', 'FixedWidth');
    
    % Save
    sgtitle(sprintf('Spatial Response Map (AVERAGED) - Stim: %s', stimElectrode), ...
        'FontSize', 14, 'FontWeight', 'bold');
    
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    saveas(fig, fullfile(figuresFolder, sprintf('Spatial_Response_AVERAGED_%s.png', timestamp)));
    saveas(fig, fullfile(figuresFolder, sprintf('Spatial_Response_AVERAGED_%s.fig', timestamp)));
    close(fig);
end


function generatePerIntensitySpatialMaps(psthData, spikeData, sortedChannels, ...
    stimIntensities, meaType, LayerDic, stimElectrode, figuresFolder)
    % PER-INTENSITY SPATIAL RESPONSE MAPS
    % Generates spatial maps for each individual stimulus intensity
    % Essential for I/O protocols where averaging across intensities is misleading
    
    nStims = size(psthData.allPSTHs, 2);
    nChannels = length(sortedChannels);
    timeCenters = psthData.timeCenters;
    binSize = psthData.binSize;
    
    % Determine column labels based on MEA type
    if contains(meaType, 'J-naming')
        columnLabels = {'A','B','C','D','E','F','G','H','J','K','L','M','N','O','P','R'};
    else
        columnLabels = {'A','B','C','D','E','F','G','H','I','K','L','M','N','O','P','R'};
    end
    
    % Response window (0-50 ms post-stim)
    responseBins = (timeCenters >= 0) & (timeCenters <= 0.050);
    
    % Compute per-channel, per-stimulus peak firing rate
    % Result: nChannels x nStims matrix
    peakFRMatrix = zeros(nChannels, nStims);
    
    for chIdx = 1:nChannels
        for stimIdx = 1:nStims
            stimPSTH = squeeze(psthData.allPSTHs(chIdx, stimIdx, :));
            stimPSTH_Hz = stimPSTH / binSize;
            peakFRMatrix(chIdx, stimIdx) = max(stimPSTH_Hz(responseBins));
        end
    end
    
    % Map channels to grid positions
    channelToGrid = containers.Map();
    for chIdx = 1:nChannels
        chName = sortedChannels{chIdx};
        tokens = regexp(chName, '^([A-Z]+)(\d+)$', 'tokens');
        if ~isempty(tokens)
            colLetter = tokens{1}{1};
            rowNum = str2double(tokens{1}{2});
            colIdx = find(strcmp(columnLabels, colLetter));
            if ~isempty(colIdx) && ~isnan(rowNum) && rowNum >= 1 && rowNum <= 16
                channelToGrid(chName) = [rowNum, colIdx];
            end
        end
    end
    
    % Determine grid layout for figure
    nCols = min(5, nStims);
    nRows = ceil(nStims / nCols);
    
    % Get global color scale
    maxFR = max(peakFRMatrix(:));
    if maxFR == 0
        maxFR = 1;
    end
    
    % =====================================================================
    % FIGURE: Per-Intensity Spatial Maps
    % =====================================================================
    fig = figure('Position', [50, 50, 350 * nCols, 350 * nRows], 'Color', 'w');
    
    for stimIdx = 1:nStims
        subplot(nRows, nCols, stimIdx);
        
        % Create grid for this stimulus
        peakFRGrid = nan(16, 16);
        
        for chIdx = 1:nChannels
            chName = sortedChannels{chIdx};
            if isKey(channelToGrid, chName)
                pos = channelToGrid(chName);
                peakFRGrid(pos(1), pos(2)) = peakFRMatrix(chIdx, stimIdx);
            end
        end
        
        % Plot
        imagesc(peakFRGrid, 'AlphaData', ~isnan(peakFRGrid));
        set(gca, 'Color', [0.9 0.9 0.9], 'YDir', 'reverse');
        colormap(gca, 'hot');
        caxis([0 maxFR]);  % Same scale for all panels
        
        % Mark stim electrode(s)
        hold on;
        stimElectrodes = strsplit(stimElectrode, ',');
        for se = 1:length(stimElectrodes)
            thisStim = strtrim(stimElectrodes{se});
            tokens = regexp(thisStim, '^([A-Z]+)(\d+)$', 'tokens');
            if ~isempty(tokens)
                colLetter = tokens{1}{1};
                stimRow = str2double(tokens{1}{2});
                stimCol = find(strcmp(columnLabels, colLetter));
                if ~isempty(stimCol) && ~isnan(stimRow)
                    plot(stimCol, stimRow, 'p', 'MarkerSize', 12, ...
                        'MarkerFaceColor', 'cyan', 'MarkerEdgeColor', 'black', 'LineWidth', 1.5);
                end
            end
        end
        hold off;
        
        % Labels
        set(gca, 'XTick', 1:4:16, 'XTickLabel', columnLabels(1:4:16), 'FontSize', 7);
        set(gca, 'YTick', 1:4:16, 'YTickLabel', 1:4:16);
        
        % Title with intensity
        if isnumeric(stimIntensities) && length(stimIntensities) >= stimIdx
            title(sprintf('%d µA', stimIntensities(stimIdx)), 'FontSize', 10, 'FontWeight', 'bold');
        else
            title(sprintf('Stim #%d', stimIdx), 'FontSize', 10, 'FontWeight', 'bold');
        end
        
        % Count active channels for this stim
        activeCount = sum(peakFRGrid(:) > 5, 'omitnan');  % >5 Hz threshold
        xlabel(sprintf('Active: %d ch', activeCount), 'FontSize', 8);
    end
    
    % Add shared colorbar
    cb = colorbar('Position', [0.92 0.15 0.02 0.7]);
    cb.Label.String = 'Peak FR (Hz)';
    cb.Label.FontSize = 10;
    
    sgtitle(sprintf('Per-Intensity Spatial Response Maps - Stim: %s', stimElectrode), ...
        'FontSize', 14, 'FontWeight', 'bold');
    
    % Save
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    saveas(fig, fullfile(figuresFolder, sprintf('Spatial_Response_PerIntensity_%s.png', timestamp)));
    saveas(fig, fullfile(figuresFolder, sprintf('Spatial_Response_PerIntensity_%s.fig', timestamp)));
    close(fig);
    
    % =====================================================================
    % FIGURE 2: Summary comparison (first vs last intensity)
    % =====================================================================
    if nStims >= 2
        fig2 = figure('Position', [100, 100, 1200, 500], 'Color', 'w');
        
        for panelIdx = 1:3
            subplot(1, 3, panelIdx);
            
            if panelIdx == 1
                stimIdx = 1;  % First (lowest) intensity
                titleStr = sprintf('Lowest: %d µA', stimIntensities(1));
            elseif panelIdx == 2
                stimIdx = nStims;  % Last (highest) intensity
                titleStr = sprintf('Highest: %d µA', stimIntensities(end));
            else
                % Difference map
                peakFRGrid_low = nan(16, 16);
                peakFRGrid_high = nan(16, 16);
                for chIdx = 1:nChannels
                    chName = sortedChannels{chIdx};
                    if isKey(channelToGrid, chName)
                        pos = channelToGrid(chName);
                        peakFRGrid_low(pos(1), pos(2)) = peakFRMatrix(chIdx, 1);
                        peakFRGrid_high(pos(1), pos(2)) = peakFRMatrix(chIdx, nStims);
                    end
                end
                diffGrid = peakFRGrid_high - peakFRGrid_low;
                
                imagesc(diffGrid, 'AlphaData', ~isnan(diffGrid));
                set(gca, 'Color', [0.9 0.9 0.9], 'YDir', 'reverse');
                colormap(gca, 'jet');
                colorbar;
                title('Difference (High - Low)', 'FontSize', 11, 'FontWeight', 'bold');
                set(gca, 'XTick', 1:16, 'XTickLabel', columnLabels, 'FontSize', 6);
                set(gca, 'YTick', 1:16);
                xlabel('Column'); ylabel('Row');
                continue;
            end
            
            % Create grid for this stimulus
            peakFRGrid = nan(16, 16);
            for chIdx = 1:nChannels
                chName = sortedChannels{chIdx};
                if isKey(channelToGrid, chName)
                    pos = channelToGrid(chName);
                    peakFRGrid(pos(1), pos(2)) = peakFRMatrix(chIdx, stimIdx);
                end
            end
            
            imagesc(peakFRGrid, 'AlphaData', ~isnan(peakFRGrid));
            set(gca, 'Color', [0.9 0.9 0.9], 'YDir', 'reverse');
            colormap(gca, 'hot');
            caxis([0 maxFR]);
            colorbar;
            
            title(titleStr, 'FontSize', 11, 'FontWeight', 'bold');
            set(gca, 'XTick', 1:16, 'XTickLabel', columnLabels, 'FontSize', 6);
            set(gca, 'YTick', 1:16);
            xlabel('Column'); ylabel('Row');
        end
        
        sgtitle('Spatial Recruitment: Low vs High Intensity', 'FontSize', 14, 'FontWeight', 'bold');
        
        saveas(fig2, fullfile(figuresFolder, sprintf('Spatial_LowVsHigh_%s.png', timestamp)));
        saveas(fig2, fullfile(figuresFolder, sprintf('Spatial_LowVsHigh_%s.fig', timestamp)));
        close(fig2);
    end
end


function generateSequentialResponseFigure(psthData, spikeData, sortedChannels, ...
    stimTimes, preStimWindow, postStimWindow, stimIntensities, protocolName, figuresFolder)
    % SEQUENTIAL RESPONSE FIGURE
    % Shows population response for each stimulus separately (useful for I/O curves)
    
    nStims = length(stimTimes);
    timeCenters = psthData.timeCenters;
    binSize = psthData.binSize;
    
    % Handle missing intensity data
    if isempty(stimIntensities)
        stimIntensities = 1:nStims;
        protocolName = 'Unknown';
        xLabelStr = 'Stimulus Number';
    else
        xLabelStr = 'Stimulus Intensity (µA)';
    end
    
    % Determine grid layout
    nCols = 5;
    nRows = ceil(nStims / nCols);
    
    % =====================================================================
    % FIGURE 1: Population PSTH per stimulus
    % =====================================================================
    fig = figure('Position', [50, 50, 1800, 300 * nRows], 'Color', 'w');
    
    for stimIdx = 1:nStims
        subplot(nRows, nCols, stimIdx);
        hold on;
        
        % Get spike counts for this stimulus only
        stimPSTH = squeeze(psthData.allPSTHs(:, stimIdx, :));  % channels x bins
        
        % Population mean and SEM
        popMean = mean(stimPSTH, 1) / binSize;  % Convert to Hz
        popSEM = std(stimPSTH, 0, 1) / binSize / sqrt(size(stimPSTH, 1));
        
        % Shaded error region
        fill([timeCenters*1000 fliplr(timeCenters*1000)], ...
             [popMean + popSEM, fliplr(popMean - popSEM)], ...
             [0.7 0.7 1], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
        
        % Mean line
        plot(timeCenters * 1000, popMean, 'b-', 'LineWidth', 1.5);
        
        % Stim marker
        xline(0, 'r--', 'LineWidth', 1);
        
        % Calculate response metrics for this trial
        responseBins = (timeCenters >= 0) & (timeCenters <= 0.050);  % 0-50 ms
        peakFR = max(popMean(responseBins));
        totalSpikes = sum(sum(stimPSTH(:, responseBins)));
        
        % Title with intensity and metrics
        title(sprintf('%d µA\nPeak: %.0f Hz | n=%d', ...
            stimIntensities(stimIdx), peakFR, totalSpikes), 'FontSize', 9);
        
        xlabel('Time (ms)');
        if mod(stimIdx-1, nCols) == 0
            ylabel('Firing Rate (Hz)');
        end
        
        xlim([-preStimWindow postStimWindow] * 1000);
        ylim([0 max(popMean) * 1.3 + 1]);
        
        box on;
        hold off;
    end
    
    sgtitle(sprintf('Sequential Stimulus Responses - %s', protocolName), ...
        'FontSize', 14, 'FontWeight', 'bold');
    
    % Save
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    saveas(fig, fullfile(figuresFolder, sprintf('Sequential_Responses_%s.png', timestamp)));
    saveas(fig, fullfile(figuresFolder, sprintf('Sequential_Responses_%s.fig', timestamp)));
    close(fig);
    
    % =====================================================================
    % FIGURE 2: Raster per stimulus
    % =====================================================================
    fig2 = figure('Position', [50, 50, 1800, 300 * nRows], 'Color', 'w');
    
    nChannels = length(sortedChannels);
    
    for stimIdx = 1:nStims
        subplot(nRows, nCols, stimIdx);
        hold on;
        
        stimTime = stimTimes(stimIdx);
        yPos = 0;
        
        for ch = 1:nChannels
            chName = sortedChannels{ch};
            if isfield(spikeData, chName)
                spikeTimes_ch = spikeData.(chName).times;
                
                relSpikes = spikeTimes_ch - stimTime;
                validSpikes = relSpikes(relSpikes >= -preStimWindow & ...
                                        relSpikes <= postStimWindow);
                
                if ~isempty(validSpikes)
                    plot(validSpikes * 1000, ones(size(validSpikes)) * yPos, ...
                        'k.', 'MarkerSize', 1);
                end
                yPos = yPos + 1;
            end
        end
        
        xline(0, 'r-', 'LineWidth', 1);
        
        % Count spikes
        totalSpikes = 0;
        for ch = 1:nChannels
            chName = sortedChannels{ch};
            if isfield(spikeData, chName)
                spikeTimes_ch = spikeData.(chName).times;
                totalSpikes = totalSpikes + ...
                    sum(spikeTimes_ch >= stimTime & ...
                        spikeTimes_ch <= stimTime + 0.050);
            end
        end
        
        title(sprintf('%d µA (n=%d)', stimIntensities(stimIdx), totalSpikes), 'FontSize', 9);
        
        xlabel('Time (ms)');
        if mod(stimIdx-1, nCols) == 0
            ylabel('Channel');
        end
        
        xlim([-preStimWindow postStimWindow] * 1000);
        ylim([0 nChannels]);
        
        box on;
        hold off;
    end
    
    sgtitle(sprintf('Sequential Rasters - %s', protocolName), ...
        'FontSize', 14, 'FontWeight', 'bold');
    
    saveas(fig2, fullfile(figuresFolder, sprintf('Sequential_Rasters_%s.png', timestamp)));
    saveas(fig2, fullfile(figuresFolder, sprintf('Sequential_Rasters_%s.fig', timestamp)));
    close(fig2);
    
    % =====================================================================
    % FIGURE 3: I/O Summary with real intensities
    % =====================================================================
    fig3 = figure('Position', [100, 100, 1000, 800], 'Color', 'w');
    
    % Calculate metrics per stimulus
    peakFRs = zeros(nStims, 1);
    totalSpikes = zeros(nStims, 1);
    activeChannels = zeros(nStims, 1);
    
    for stimIdx = 1:nStims
        stimPSTH = squeeze(psthData.allPSTHs(:, stimIdx, :));
        popMean = mean(stimPSTH, 1) / binSize;
        
        responseBins = (timeCenters >= 0) & (timeCenters <= 0.050);
        peakFRs(stimIdx) = max(popMean(responseBins));
        totalSpikes(stimIdx) = sum(sum(stimPSTH(:, responseBins)));
        activeChannels(stimIdx) = sum(sum(stimPSTH(:, responseBins), 2) > 0);
    end
    
    % Panel 1: Peak firing rate vs intensity
    subplot(2, 2, 1);
    plot(stimIntensities, peakFRs, 'bo-', 'LineWidth', 2, 'MarkerFaceColor', 'b', 'MarkerSize', 8);
    xlabel(xLabelStr);
    ylabel('Peak Firing Rate (Hz)');
    title('Peak Population Response');
    grid on;
    box on;
    
    % Panel 2: Total spike count vs intensity - FIXED
    subplot(2, 2, 2);
    bar(1:nStims, totalSpikes, 'FaceColor', [0.3 0.6 0.8]);
    set(gca, 'XTick', 1:nStims, 'XTickLabel', stimIntensities);
    xtickangle(45);
    xlabel(xLabelStr);
    ylabel('Total Spikes (0-50 ms)');
    title('Spike Count vs Intensity');
    box on;
    
    % Panel 3: Active channels vs intensity
    subplot(2, 2, 3);
    plot(stimIntensities, activeChannels, 'go-', 'LineWidth', 2, 'MarkerFaceColor', 'g', 'MarkerSize', 8);
    xlabel(xLabelStr);
    ylabel('Active Channels');
    title('Spatial Recruitment');
    ylim([0 nChannels]);
    grid on;
    box on;
    
  % Panel 4: Normalized I/O curve with sigmoid fit
    subplot(2, 2, 4);
    normResponse = totalSpikes / max(totalSpikes);
    plot(stimIntensities, normResponse, 'ro-', 'LineWidth', 2, 'MarkerFaceColor', 'r', 'MarkerSize', 8);
    xlabel(xLabelStr);
    ylabel('Normalized Response');
    title('I/O Curve (Normalized)');
    ylim([0 1.1]);
    grid on;
    
    % Smarter sigmoid fit - only use ascending portion before any dip
    % Find the first peak (where response starts declining significantly)
    [maxResp, peakIdx] = max(normResponse);
    
    % Check if there's a significant dip after peak (depolarization block)
    hasDepBlock = false;
    if peakIdx < nStims - 2
        postPeakMin = min(normResponse(peakIdx:end));
        if postPeakMin < 0.7 * maxResp
            % Depolarization block detected - fit only up to peak
            fitRange = 1:peakIdx;
            hasDepBlock = true;
        else
            fitRange = 1:nStims;
        end
    else
        fitRange = 1:nStims;
    end
    
    % Only fit if we have enough points and range
    if length(fitRange) >= 4 && range(normResponse(fitRange)) > 0.3 && ~all(stimIntensities == 1:nStims)
        try
            % Sigmoid: y = ymax / (1 + exp(-k*(x-x50)))
            ft = fittype('ymax / (1 + exp(-k*(x-x50)))', 'independent', 'x');
            opts = fitoptions(ft);
            
            xData = stimIntensities(fitRange)';
            yData = normResponse(fitRange);
            
            opts.StartPoint = [max(yData), 0.05, median(xData)];
            opts.Lower = [0.5, 0.001, min(xData)];
            opts.Upper = [1.5, 1, max(xData)];
            
            [fitResult, gof] = fit(xData, yData, ft, opts);
            
            % Only show fit if R² is reasonable
            if gof.rsquare > 0.7
                hold on;
                xfit = linspace(min(xData), max(xData), 100);
                yfit = feval(fitResult, xfit);
                plot(xfit, yfit, 'b--', 'LineWidth', 2);
                
                % Mark I50
                I50 = fitResult.x50;
                if I50 > min(xData) && I50 < max(xData)
                    plot([I50 I50], [0 0.5], 'k:', 'LineWidth', 1);
                    plot([min(stimIntensities) I50], [0.5 0.5], 'k:', 'LineWidth', 1);
                    plot(I50, 0.5, 'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'k');
                end
                
                text(0.95, 0.15, sprintf('I_{50} = %.0f µA\nR² = %.3f\n(fit to %d-%d µA)', ...
                    I50, gof.rsquare, stimIntensities(fitRange(1)), stimIntensities(fitRange(end))), ...
                    'Units', 'normalized', 'HorizontalAlignment', 'right', ...
                    'VerticalAlignment', 'bottom', 'FontSize', 10, 'BackgroundColor', 'w');
                hold off;
            else
                text(0.95, 0.05, sprintf('Sigmoid fit poor (R²=%.2f)', gof.rsquare), ...
                    'Units', 'normalized', 'HorizontalAlignment', 'right', ...
                    'FontSize', 9, 'Color', [0.5 0.5 0.5]);
            end
            
        catch ME
            text(0.95, 0.05, 'Sigmoid fit failed', ...
                'Units', 'normalized', 'HorizontalAlignment', 'right', ...
                'FontSize', 9, 'Color', [0.5 0.5 0.5]);
        end
    end
    
    % Add depolarization block annotation if detected
    if hasDepBlock
        hold on;
        xline(stimIntensities(peakIdx), 'm--', 'LineWidth', 2);
        text(stimIntensities(peakIdx) + 20, 0.85, sprintf('Dep. block\n@ %d µA', stimIntensities(peakIdx)), ...
            'FontSize', 9, 'Color', [0.8 0 0.8], 'FontWeight', 'bold');
        hold off;
    end
    box on;
    
    sgtitle(sprintf('Input-Output Curve - %s', protocolName), ...
        'FontSize', 14, 'FontWeight', 'bold');
    
    saveas(fig3, fullfile(figuresFolder, sprintf('IO_Summary_%s.png', timestamp)));
    saveas(fig3, fullfile(figuresFolder, sprintf('IO_Summary_%s.fig', timestamp)));
    close(fig3);
end


%% ========== ANALYZE EVENT TRIGGERING ==========
function [triggerStats, evokedEventIndices] = analyzeEventTriggering(...
    stimTimes, eventOnsets, eventOffsets, eventWindow, totalDuration)
    % ANALYZE EVENT TRIGGERING
    % Determines which network events were evoked by stimulation
    
    numStims = length(stimTimes);
    numEvents = length(eventOnsets);
    
    evokedEventIndices = [];
    evokedLatencies = [];
    
    % For each stimulation, check if an event started within the window
    for s = 1:numStims
        stimTime = stimTimes(s);
        windowEnd = stimTime + eventWindow;
        
        % Find events that started within this window
        eventsInWindow = find(eventOnsets > stimTime & eventOnsets <= windowEnd);
        
        % Take the first event (if any) as the evoked event
        if ~isempty(eventsInWindow)
            evokedIdx = eventsInWindow(1);
            
            % Avoid double-counting: only count if not already attributed to earlier stim
            if ~ismember(evokedIdx, evokedEventIndices)
                evokedEventIndices(end+1) = evokedIdx;
                evokedLatencies(end+1) = (eventOnsets(evokedIdx) - stimTime) * 1000;  % ms
            end
        end
    end
    
    % Calculate statistics
    triggerStats = struct();
    triggerStats.NumStims = numStims;
    triggerStats.NumEvents = numEvents;
    triggerStats.NumEvokedEvents = length(evokedEventIndices);
    triggerStats.NumSpontaneousEvents = numEvents - length(evokedEventIndices);
    triggerStats.TriggerProbability_Percent = 100 * length(evokedEventIndices) / numStims;
    triggerStats.DetectionWindow_ms = eventWindow * 1000;
    
    if ~isempty(evokedLatencies)
        triggerStats.MeanEventLatency_ms = mean(evokedLatencies);
        triggerStats.StdEventLatency_ms = std(evokedLatencies);
        triggerStats.MinEventLatency_ms = min(evokedLatencies);
        triggerStats.MaxEventLatency_ms = max(evokedLatencies);
    else
        triggerStats.MeanEventLatency_ms = NaN;
        triggerStats.StdEventLatency_ms = NaN;
        triggerStats.MinEventLatency_ms = NaN;
        triggerStats.MaxEventLatency_ms = NaN;
    end
    
    % Expected spontaneous rate (events per second * window duration)
    if totalDuration > 0
        spontRate = numEvents / totalDuration;  % events/second
        expectedSpontInWindow = spontRate * eventWindow * numStims;
        triggerStats.ExpectedSpontaneous = expectedSpontInWindow;
        triggerStats.ObservedOverExpected = length(evokedEventIndices) / max(expectedSpontInWindow, 0.1);
    else
        triggerStats.ExpectedSpontaneous = NaN;
        triggerStats.ObservedOverExpected = NaN;
    end
end

%% ==================== SESSION PERSISTENCE FUNCTIONS ====================
% These functions manage persistent settings across GUI sessions

function settings = loadSessionSettings()
    % Load session settings from JSON file
    % Settings file is stored in user's home directory or MATLAB userpath
    
    settings = struct();
    settingsFile = getSessionSettingsPath();
    
    if exist(settingsFile, 'file')
        try
            fid = fopen(settingsFile, 'r');
            rawJson = fread(fid, inf, '*char')';
            fclose(fid);
            settings = jsondecode(rawJson);
        catch ME
            warning('Could not load session settings: %s', ME.message);
            settings = struct();
        end
    end
    
    % Ensure all expected fields exist with defaults
    if ~isfield(settings, 'lastLayerDicPath')
        settings.lastLayerDicPath = '';
    end
    if ~isfield(settings, 'lastOutputParentDir')
        settings.lastOutputParentDir = '';
    end
    if ~isfield(settings, 'lastNoisyChannels')
        settings.lastNoisyChannels = '';
    end
    if ~isfield(settings, 'lastEventRefChannels')
        settings.lastEventRefChannels = '';
    end
    if ~isfield(settings, 'patientMeta')
        settings.patientMeta = struct();
    end
end

function saveSessionSettings(settings)
    % Save session settings to JSON file
    
    settingsFile = getSessionSettingsPath();
    
    try
        jsonStr = jsonencode(settings);
        
        % Pretty-print the JSON for readability
        jsonStr = strrep(jsonStr, ',"', sprintf(',\n  "'));
        jsonStr = strrep(jsonStr, '{', sprintf('{\n  '));
        jsonStr = strrep(jsonStr, '}', sprintf('\n}'));
        
        fid = fopen(settingsFile, 'w');
        fprintf(fid, '%s', jsonStr);
        fclose(fid);
    catch ME
        warning('Could not save session settings: %s', ME.message);
    end
end

function settingsPath = getSessionSettingsPath()
    % Get the path for the session settings file
    % Stores in MATLAB userpath or user's home directory
    
    % Try userpath first (MATLAB's preferred location for user files)
    userDir = userpath;
    if isempty(userDir)
        % Fall back to user's home directory
        if ispc
            userDir = getenv('USERPROFILE');
        else
            userDir = getenv('HOME');
        end
    else
        % userpath returns path with trailing pathsep, remove it
        userDir = strtrim(userDir);
        if userDir(end) == pathsep
            userDir = userDir(1:end-1);
        end
    end
    
    settingsPath = fullfile(userDir, 'MEA_GUI_session_settings.json');
end

%% ==================== EMBEDDED TOOL: LayerDic Generator ====================
function layerDicGeneratorTool()
% GUI for creating/editing Layer Dictionary (Cortex)
% Saves with keys: layer1, layer2_3, layer4, layer5_6, whitematter

    % Configuration
    LayerDic = zeros(16,16);
    
    electrode_positions = {'A','B','C','D','E','F','G','H', ...
                           'J','K','L','M','N','O','P','R'};
    
    layerNames = {'layer1','layer2_3','layer4','layer5_6','whitematter'};
    
    % Color palette
    colors = [0.95 0.90 0.25;   % layer1 - yellow
              0.98 0.70 0.20;   % layer2_3 - orange
              0.90 0.50 0.10;   % layer4 - dark orange
              0.90 0.10 0.10;   % layer5_6 - red
              0.70 0.70 0.70];  % whitematter - gray
    
    % Alias map for loading different formats
    alias2idx = containers.Map( ...
       {'L1','layer1', ...
        'L2_3','layer2_3', ...
        'L4','layer4', ...
        'L5','layer5','layer5_6','L6','layer6', ...
        'whitematter','WM'}, ...
       [1 1  2 2  3 3  4 4 4 4 4  5 5]);
    
    % Create figure
    toolFig = figure('Name','MEA Layer Dictionary Generator', ...
                     'NumberTitle','off','MenuBar','none','ToolBar','none', ...
                     'Position',[100 100 850 850]);
    
    ax = axes('Parent',toolFig,'Position',[0.10 0.10 0.80 0.80]);
    axis(ax,[0.5 16.5 0.5 16.5]);
    set(ax,'YDir','reverse');
    xticks(ax,1:16); xticklabels(ax,electrode_positions);
    yticks(ax,1:16); yticklabels(ax,1:16);
    grid(ax,'on'); hold(ax,'on');
    xlabel(ax, 'Column'); ylabel(ax, 'Row');
    title(ax, 'Click buttons to assign layers (enter layer number first)');
    
    defaultBG = get(toolFig,'Color');
    
    % Controls
    ctrlH = 0.04; yCtrl = 0.94;
    
    uicontrol('Parent', toolFig, 'Style','text','String','Layer (0-5):', ...
              'Units','normalized','Position',[0.02 yCtrl 0.10 ctrlH], ...
              'HorizontalAlignment','left');
    
    layerInput = uicontrol('Parent', toolFig, 'Style','edit', ...
                           'Units','normalized','Position',[0.12 yCtrl 0.06 ctrlH], ...
                           'String', '1');
    
    uicontrol('Parent', toolFig, 'Style','pushbutton','String','Load LayerDic', ...
              'Units','normalized','Position',[0.20 yCtrl 0.12 ctrlH], ...
              'Callback',@loadLayerDicTool);
    
    uicontrol('Parent', toolFig, 'Style','pushbutton','String','Save LayerDic', ...
              'Units','normalized','Position',[0.34 yCtrl 0.12 ctrlH], ...
              'Callback',@saveLayerDicTool);
    
    % Legend
    uicontrol('Parent', toolFig, 'Style','text', ...
              'String','Legend: 1=L1(yellow) 2=L2/3(orange) 3=L4(dk orange) 4=L5/6(red) 5=WM(gray) 0=clear', ...
              'Units','normalized','Position',[0.48 yCtrl 0.50 ctrlH], ...
              'HorizontalAlignment','left', 'FontSize', 8);
    
    % Button grid
    button_grid = gobjects(16,16);
    for col = 1:16
        for row = 1:16
            xpos = 0.10 + (col-1)*0.05;
            ypos = 0.90 - row*0.05;
            button_grid(row,col) = uicontrol('Parent', toolFig, 'Style','pushbutton', ...
                'Units','normalized','Position',[xpos ypos 0.05 0.05], ...
                'String','', 'BackgroundColor',defaultBG, ...
                'Callback',@(src,~)assignLayerTool(src,row,col));
        end
    end
    
    % Nested callbacks
    function assignLayerTool(src,row,col)
        layer = str2double(get(layerInput,'String'));
        if isnan(layer) || ~ismember(layer,0:5)
            errordlg('Please enter a number between 0 and 5 (0 = clear).');
            return
        end
        
        if layer == 0
            LayerDic(row,col) = 0;
            set(src,'String','', 'BackgroundColor',defaultBG);
        else
            LayerDic(row,col) = layer;
            set(src,'String',num2str(layer), 'BackgroundColor',colors(layer,:));
        end
    end
    
    function saveLayerDicTool(~,~)
        map = containers.Map(layerNames, repmat({cell(0,1)},1,5));
        
        for row = 1:16
            for col = 1:16
                layer = LayerDic(row,col);
                if layer==0, continue, end
                elName = sprintf('%s%02d',electrode_positions{col},row);
                lname = layerNames{layer};
                tmp = map(lname);
                tmp{end+1} = elName;
                map(lname) = tmp;
            end
        end
        
        s = struct();
        for k = 1:numel(layerNames)
            s.(layerNames{k}) = map(layerNames{k});
        end
        
        jsonStr = jsonencode(s,'PrettyPrint',true);
        
        [f,p] = uiputfile('LayerDic_Cortex.json','Save LayerDic As');
        if isequal(f,0), return, end
        fid = fopen(fullfile(p,f),'w');
        if fid==-1, errordlg('Cannot create file.'); return, end
        fwrite(fid,jsonStr,'char'); fclose(fid);
        msgbox(['LayerDic saved to ' fullfile(p,f)], 'Saved');
    end
    
    function loadLayerDicTool(~,~)
        [f,p] = uigetfile('*.json','Select LayerDic JSON');
        if isequal(f,0), return, end
        
        fid = fopen(fullfile(p,f),'r');
        if fid==-1, errordlg('Cannot open file.'); return, end
        raw = fread(fid,'*char')'; fclose(fid);
        
        try
            s = jsondecode(raw);
        catch ME
            errordlg(['JSON decode error: ' ME.message]); return
        end
        
        % Reset
        LayerDic(:) = 0;
        set(button_grid(:),'String','', 'BackgroundColor',defaultBG);
        
        % Parse all fields
        for fld = fieldnames(s)'
            key = fld{1};
            
            if isKey(alias2idx,key)
                idx = alias2idx(key);
            else
                warning('Unknown layer field "%s" ignored.', key);
                continue
            end
            
            elist = s.(key);
            if ~iscell(elist), elist = {elist}; end
            
            for k = 1:numel(elist)
                el = elist{k};
                if isstring(el), el = char(el); end
                if isempty(el) || ~ischar(el), continue, end
                
                colLetter = regexp(el,'[A-Z]+','match','once');
                rowStr = regexp(el,'\d+','match','once');
                if isempty(colLetter) || isempty(rowStr), continue, end
                
                col = find(strcmp(electrode_positions,colLetter));
                row = str2double(rowStr);
                
                if isempty(col) || col<1 || col>16 || isnan(row) || row<1 || row>16
                    continue
                end
                
                LayerDic(row,col) = idx;
                set(button_grid(row,col),'String',num2str(idx), ...
                                         'BackgroundColor',colors(idx,:));
            end
        end
        msgbox(['LayerDic loaded from ' fullfile(p,f)], 'Loaded');
    end
end

%% ==================== EMBEDDED TOOL: Channel Inspector ====================
function channelInspectorTool()
% MEA Channel Inspector - Visualize all channels to identify noisy electrodes
% Click channels to mark as noisy, then send selection to main GUI

    % Select H5 file
    [filename, pathname] = uigetfile('*.h5', 'Select H5 MEA Data File');
    if isequal(filename, 0)
        disp('File selection cancelled');
        return;
    end
    
    fullpath = fullfile(pathname, filename);
    fprintf('Loading: %s\n', filename);
    
    % Read H5 file
    try
        channelDataPath = '/Data/Recording_0/AnalogStream/Stream_0/ChannelData';
        infoChannelPath = '/Data/Recording_0/AnalogStream/Stream_0/InfoChannel';
        
        fileInfo = h5info(fullpath, channelDataPath);
        totalSamples = fileInfo.Dataspace.Size(1);
        
        fprintf('Reading channel information...\n');
        infoChannel = h5read(fullpath, infoChannelPath);
        channelLabels = infoChannel.Label;
        
        % Get sampling rate
        samplingRate = [];
        if isfield(infoChannel, 'Tick') && ~isempty(infoChannel.Tick)
            tick = double(infoChannel.Tick(1));
            if tick > 0
                samplingRate = 1e6 / tick;
            end
        end
        if isempty(samplingRate) && isfield(infoChannel, 'SamplingFrequency')
            samplingRate = double(infoChannel.SamplingFrequency(1));
        end
        if isempty(samplingRate) || samplingRate <= 0
            samplingRate = 10000;
        end
        
        totalDuration = totalSamples / samplingRate;
        
        % Ask user for load options
        loadChoice = questdlg(...
            sprintf('Total recording: %.1f s (%.1f min)\n\nFor noise inspection, 5-10 seconds is usually sufficient.', ...
                    totalDuration, totalDuration/60), ...
            'Data Loading Options', ...
            'First 10 seconds', 'Custom Range', 'Cancel', 'First 10 seconds');
        
        if strcmp(loadChoice, 'Cancel')
            return;
        end
        
        if strcmp(loadChoice, 'Custom Range')
            prompt = {sprintf('Start time (s) [0 - %.1f]:', totalDuration);
                      sprintf('End time (s) [0 - %.1f]:', totalDuration)};
            answer = inputdlg(prompt, 'Custom Time Range', [1 50], {'0', '10'});
            
            if isempty(answer), return; end
            
            startTime = str2double(answer{1});
            endTime = str2double(answer{2});
            
            if isnan(startTime), startTime = 0; end
            if isnan(endTime), endTime = 10; end
            startTime = max(0, startTime);
            endTime = min(totalDuration, endTime);
            if startTime >= endTime, endTime = startTime + 10; end
        else
            startTime = 0;
            endTime = min(10, totalDuration);
        end
        
        % Load data
        startSample = max(1, round(startTime * samplingRate));
        endSample = min(totalSamples, round(endTime * samplingRate));
        numSamplesToLoad = endSample - startSample + 1;
        
        fprintf('Loading %.1f - %.1f seconds...\n', startTime, endTime);
        rawData = h5read(fullpath, channelDataPath, [startSample, 1], [numSamplesToLoad, Inf]);
        rawData = double(rawData) / 32.64;  % Convert to µV
        
        fprintf('Loaded %d channels, %.2f seconds\n', length(channelLabels), numSamplesToLoad/samplingRate);
        
    catch ME
        errordlg(['Error loading H5 file: ' ME.message], 'Load Error');
        return;
    end
    
    % Detect MEA type
    hasI = any(contains(channelLabels, 'I'));
    hasJ = any(contains(channelLabels, 'J'));
    if hasI && ~hasJ
        meaType = 'Old MEA (I-naming)';
        columns = {'A','B','C','D','E','F','G','H','I','K','L','M','N','O','P','R'};
    else
        meaType = 'New MEA (J-naming)';
        columns = {'A','B','C','D','E','F','G','H','J','K','L','M','N','O','P','R'};
    end
    fprintf('Detected: %s\n', meaType);
    
    % Ask for y-axis limits
    answer = inputdlg({'Y-axis limits (µV) - min,max (e.g., -100,100):'}, ...
                      'Y-Axis Range', [1 60], {'-100,100'});
    
    if isempty(answer)
        yLimits = [-100, 100];
    else
        yLimitsStr = strsplit(answer{1}, ',');
        if length(yLimitsStr) == 2
            yLimits = [str2double(yLimitsStr{1}), str2double(yLimitsStr{2})];
            if isnan(yLimits(1)) || isnan(yLimits(2))
                yLimits = [-100, 100];
            end
        else
            yLimits = [-100, 100];
        end
    end
    
    % Create figure
    hFig = figure('Name', 'MEA Channel Inspector - Click to mark noisy channels', ...
                  'NumberTitle', 'off', ...
                  'Position', [50, 50, 1600, 950], ...
                  'Color', 'white');
    
    % Initialize noisy channels tracking
    noisyChannelsList = {};  % Cell array to store marked noisy channels
    
    setappdata(hFig, 'rawData', rawData);
    setappdata(hFig, 'channelLabels', channelLabels);
    setappdata(hFig, 'samplingRate', samplingRate);
    setappdata(hFig, 'filename', filename);
    setappdata(hFig, 'pathname', pathname);   % NEU V5: fuer JSON-Save benoetigt
    setappdata(hFig, 'timeRange', [startTime, endTime]);
    setappdata(hFig, 'yLimits', yLimits);
    setappdata(hFig, 'noisyChannelsList', noisyChannelsList);
    setappdata(hFig, 'columns', columns);

    % NEU V5: Auto-Load bestehende noisy_channels.json wenn vorhanden
    existingJSON = fullfile(pathname, 'noisy_channels.json');
    if exist(existingJSON, 'file')
        try
            jsonData = jsondecode(fileread(existingJSON));
            if isfield(jsonData, 'noisy_channels')
                preMarked = jsonData.noisy_channels;
                if ischar(preMarked),   preMarked = {preMarked}; end
                if isstring(preMarked), preMarked = cellstr(preMarked); end
                noisyChannelsList = preMarked(:)';
                setappdata(hFig, 'noisyChannelsList', noisyChannelsList);
                fprintf('  ✓ Bestehende noisy_channels.json geladen: %d Kanaele\n', numel(noisyChannelsList));
            end
        catch
            fprintf('  ⚠ noisy_channels.json konnte nicht gelesen werden\n');
        end
    end

    % Create control panel at top
    controlPanel = uipanel('Parent', hFig, 'Title', '', ...
                           'Position', [0 0.92 1 0.08], ...
                           'BackgroundColor', [0.95 0.95 0.95]);
    
    % Noisy channels label
    uicontrol('Parent', controlPanel, 'Style', 'text', ...
              'String', 'Noisy Channels:', ...
              'Units', 'normalized', 'Position', [0.01 0.55 0.10 0.35], ...
              'HorizontalAlignment', 'left', 'FontWeight', 'bold', ...
              'BackgroundColor', [0.95 0.95 0.95]);
    
    % Editable text field for noisy channels
    noisyEditField = uicontrol('Parent', controlPanel, 'Style', 'edit', ...
              'String', '', ...
              'Units', 'normalized', 'Position', [0.11 0.52 0.47 0.42], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 10, ...
              'BackgroundColor', [1 1 1], ...
              'TooltipString', 'Type channel names separated by commas (e.g., A2,B3,C4)', ...
              'Tag', 'noisyEditField');
    
    % Buttons
    uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
              'String', '✓ Send to GUI', ...
              'Units', 'normalized', 'Position', [0.60 0.50 0.12 0.45], ...
              'FontSize', 10, 'FontWeight', 'bold', ...
              'ForegroundColor', [0 0.5 0], ...
              'BackgroundColor', [0.85 1 0.85], ...
              'TooltipString', 'Send noisy channels list to main GUI session settings', ...
              'Callback', @(~,~) sendNoisyToGUI(hFig));
    
    uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
              'String', 'Clear', ...
              'Units', 'normalized', 'Position', [0.73 0.50 0.06 0.45], ...
              'FontSize', 9, ...
              'TooltipString', 'Clear all noisy channels', ...
              'Callback', @(~,~) clearAllNoisy(hFig));
    
    uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
              'String', 'Auto-Detect', ...
              'Units', 'normalized', 'Position', [0.80 0.50 0.09 0.45], ...
              'FontSize', 9, ...
              'TooltipString', 'Auto-mark channels with high noise (red background)', ...
              'Callback', @(~,~) autoDetectNoisy(hFig));
    
    uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
              'String', 'Copy', ...
              'Units', 'normalized', 'Position', [0.90 0.50 0.05 0.45], ...
              'FontSize', 9, ...
              'TooltipString', 'Copy noisy channels list to clipboard', ...
              'Callback', @(~,~) copyNoisyToClipboard(hFig));

    % NEU V5: Save JSON Button -- speichert noisy_channels.json im H5-Ordner
    uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
              'String', '💾 Save JSON', ...
              'Units', 'normalized', 'Position', [0.60 0.03 0.12 0.42], ...
              'FontSize', 9, 'FontWeight', 'bold', ...
              'ForegroundColor', [1 1 1], ...
              'BackgroundColor', [0.15 0.45 0.75], ...
              'TooltipString', 'noisy_channels.json im H5-Ordner speichern (wird von Spike-GUI auto-geladen)', ...
              'Callback', @(~,~) saveNoisyChannelsJSON(hFig));
    
    % Instructions row
    uicontrol('Parent', controlPanel, 'Style', 'text', ...
              'String', 'Type channels above (comma-separated, e.g., A2,B3,C4) or use Auto-Detect. Right-click grid for channel details.', ...
              'Units', 'normalized', 'Position', [0.01 0.05 0.98 0.40], ...
              'HorizontalAlignment', 'left', 'FontSize', 9, ...
              'BackgroundColor', [0.95 0.95 0.95]);
    
    setappdata(hFig, 'noisyEditField', noisyEditField);
    
    % Create axes panel
    axesPanel = uipanel('Parent', hFig, 'Title', '', ...
                        'Position', [0 0 1 0.92], ...
                        'BackgroundColor', 'white');
    
    % Title
    annotation(hFig, 'textbox', [0.01, 0.895, 0.98, 0.025], ...
        'String', sprintf('Channel Inspector: %s (%s) | Time: %.1f-%.1f s | Y: %.0f to %.0f µV', ...
            filename, meaType, startTime, endTime, yLimits(1), yLimits(2)), ...
        'EdgeColor', 'none', 'FontSize', 11, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'Interpreter', 'none');
    
    % Create 16x16 grid
    fprintf('Creating grid visualization...\n');
    rows = 1:16;
    axesHandles = gobjects(16, 16);  % Store axes handles
    
    for row = 1:16
        for col = 1:16
            % Calculate position within axes panel
            xPos = 0.02 + (col-1) * 0.06;
            yPos = 0.93 - row * 0.058;
            
            ax = axes('Parent', axesPanel, ...
                      'Position', [xPos yPos 0.055 0.052]);
            axesHandles(row, col) = ax;
            
            elecName = sprintf('%s%d', columns{col}, rows(row));
            
            channelIdx = find(strcmpi(channelLabels, elecName), 1);
            
            if ~isempty(channelIdx)
                trace = rawData(:, channelIdx);
                timeVec = (0:length(trace)-1) / samplingRate;
                
                hLine = plot(timeVec, trace, 'k-', 'LineWidth', 0.3);
                set(hLine, 'HitTest', 'off', 'PickableParts', 'none');  % Allow clicks to pass through to axes
                ylim(yLimits);
                
                stdVal = std(trace);
                pkpk = max(trace) - min(trace);
                isClipping = any(trace < yLimits(1)) || any(trace > yLimits(2));
                
                % Color code by noise level
                if isClipping || stdVal > 50 || pkpk > 500
                    baseColor = [1 0.85 0.85];  % Light red - high noise
                    isHighNoise = true;
                elseif stdVal > 20 || pkpk > 200
                    baseColor = [1 1 0.85];     % Light yellow - medium noise
                    isHighNoise = false;
                else
                    baseColor = [1 1 1];        % White - normal
                    isHighNoise = false;
                end
                set(ax, 'Color', baseColor);
                
                setappdata(ax, 'channelIdx', channelIdx);
                setappdata(ax, 'elecName', elecName);
                setappdata(ax, 'stdVal', stdVal);
                setappdata(ax, 'pkpk', pkpk);
                setappdata(ax, 'baseColor', baseColor);
                setappdata(ax, 'isMarkedNoisy', false);
                setappdata(ax, 'isHighNoise', isHighNoise);
            else
                set(ax, 'Color', [0.9 0.9 0.9]);
                ylim(yLimits);
                hText = text(0.5, 0, 'N/A', 'HorizontalAlignment', 'center', ...
                    'FontSize', 6, 'Color', [0.5 0.5 0.5]);
                set(hText, 'HitTest', 'off', 'PickableParts', 'none');
                setappdata(ax, 'elecName', elecName);
                setappdata(ax, 'isMarkedNoisy', false);
            end
            
            set(ax, 'XTick', [], 'YTick', [], 'Box', 'on', 'LineWidth', 0.5);
            title(elecName, 'FontSize', 6, 'FontWeight', 'bold');
            
            % Set click callback - left click to toggle noisy, right click for details
            set(ax, 'ButtonDownFcn', @(src, evt) channelClickHandler(src, evt, hFig));
        end
    end
    
    setappdata(hFig, 'axesHandles', axesHandles);
    
    % Instructions at bottom
    annotation(hFig, 'textbox', [0.01, 0.001, 0.98, 0.025], ...
        'String', 'Background: RED=High noise, YELLOW=Medium, WHITE=Normal | Click channels or type names above | Right-click for details', ...
        'EdgeColor', 'none', 'FontSize', 9, 'HorizontalAlignment', 'center');
    
    fprintf('Done! Type noisy channels in the text field or click on grid, then "Send to GUI".\n');
end

function channelClickHandler(src, evt, hFig)
    % Handle clicks on channel axes
    % Left click = toggle noisy marking
    % Right click = show detailed view
    
    elecName = getappdata(src, 'elecName');
    if isempty(elecName), return; end
    
    % Check click type
    clickType = get(hFig, 'SelectionType');
    
    if strcmp(clickType, 'alt')  % Right-click
        % Show detailed view
        channelIdx = getappdata(src, 'channelIdx');
        if isempty(channelIdx), return; end
        showChannelDetails(src, hFig);
    else  % Left-click (normal or open)
        % Toggle noisy marking
        toggleNoisyChannel(src, hFig);
    end
end

function toggleNoisyChannel(ax, hFig)
    % Toggle whether a channel is marked as noisy
    
    elecName = getappdata(ax, 'elecName');
    if isempty(elecName), return; end
    
    channelIdx = getappdata(ax, 'channelIdx');
    if isempty(channelIdx), return; end  % Skip N/A channels
    
    % Get current edit field content
    noisyEditField = getappdata(hFig, 'noisyEditField');
    currentText = strtrim(get(noisyEditField, 'String'));
    
    % Parse to list
    if isempty(currentText)
        noisyChannelsList = {};
    else
        noisyChannelsList = strsplit(currentText, {',', ' ', ';'});
        noisyChannelsList = strtrim(noisyChannelsList);
        noisyChannelsList = noisyChannelsList(~cellfun(@isempty, noisyChannelsList));
    end
    
    isMarkedNoisy = getappdata(ax, 'isMarkedNoisy');
    baseColor = getappdata(ax, 'baseColor');
    
    if isMarkedNoisy
        % Unmark as noisy
        setappdata(ax, 'isMarkedNoisy', false);
        set(ax, 'LineWidth', 0.5, 'XColor', 'k', 'YColor', 'k');
        set(ax, 'Color', baseColor);
        
        % Remove from list
        noisyChannelsList = noisyChannelsList(~strcmpi(noisyChannelsList, elecName));
    else
        % Mark as noisy
        setappdata(ax, 'isMarkedNoisy', true);
        set(ax, 'LineWidth', 3, 'XColor', [0 0 0.8], 'YColor', [0 0 0.8]);
        
        % Add to list if not already present
        if ~any(strcmpi(noisyChannelsList, elecName))
            noisyChannelsList{end+1} = elecName;
        end
    end
    
    % Sort and update edit field
    noisyChannelsList = sort(noisyChannelsList);
    if isempty(noisyChannelsList)
        set(noisyEditField, 'String', '');
    else
        set(noisyEditField, 'String', strjoin(noisyChannelsList, ','));
    end
end

function updateNoisyDisplay(hFig)
    % Update the noisy channels edit field
    noisyChannelsList = getappdata(hFig, 'noisyChannelsList');
    noisyEditField = getappdata(hFig, 'noisyEditField');
    
    if ~isempty(noisyEditField) && isgraphics(noisyEditField)
        if isempty(noisyChannelsList)
            set(noisyEditField, 'String', '');
        else
            noisyStr = strjoin(noisyChannelsList, ',');
            set(noisyEditField, 'String', noisyStr);
        end
    end
end

function sendNoisyToGUI(hFig)
    % Send noisy channels list to main GUI session settings
    % Read directly from edit field
    noisyEditField = getappdata(hFig, 'noisyEditField');
    noisyStr = strtrim(get(noisyEditField, 'String'));
    
    % Parse to count channels
    if isempty(noisyStr)
        numChannels = 0;
    else
        channels = strsplit(noisyStr, {',', ' ', ';'});
        channels = channels(~cellfun(@isempty, channels));
        numChannels = length(channels);
        noisyStr = strjoin(channels, ',');  % Clean up formatting
    end
    
    if numChannels == 0
        answer = questdlg('No channels specified. Send empty list to GUI?', ...
                          'Confirm', 'Yes', 'No', 'No');
        if ~strcmp(answer, 'Yes')
            return;
        end
        noisyStr = '';
    end
    
    % Find main GUI figure
    mainFig = findobj('Type', 'figure', 'Name', 'MEA Analysis Suite - Complete Version');
    
    if isempty(mainFig)
        % GUI not open - save to session file directly
        settings = loadSessionSettingsExternal();
        settings.lastNoisyChannels = noisyStr;
        saveSessionSettingsExternal(settings);
        
        msgbox(sprintf('Saved %d noisy channels to session settings.\n\nChannels: %s\n\nThey will be pre-filled when you load H5 data.', ...
               numChannels, noisyStr), 'Saved to Session');
    else
        % GUI is open - update session settings
        mainFig = mainFig(1);
        sessionSettings = getappdata(mainFig, 'sessionSettings');
        if isempty(sessionSettings)
            sessionSettings = struct();
        end
        sessionSettings.lastNoisyChannels = noisyStr;
        setappdata(mainFig, 'sessionSettings', sessionSettings);
        
        % Save to file as well
        saveSessionSettingsExternal(sessionSettings);
        
        % Update display in main GUI
        try
            noisyChannelsLabel = findobj(mainFig, 'Tag', 'settingsNoisyChannels');
            if ~isempty(noisyChannelsLabel)
                if ~isempty(noisyStr)
                    set(noisyChannelsLabel, 'String', noisyStr, 'ForegroundColor', [0.8 0 0]);
                else
                    set(noisyChannelsLabel, 'String', '(none)', 'ForegroundColor', [0.5 0.5 0.5]);
                end
            end
        catch
            % Ignore display update errors
        end
        
        msgbox(sprintf('Sent %d noisy channels to GUI!\n\nChannels: %s\n\nThey will be pre-filled in the noisy channels dialog.', ...
               numChannels, noisyStr), 'Sent to GUI');
    end
end

function clearAllNoisy(hFig)
    % Clear the noisy channels edit field
    noisyEditField = getappdata(hFig, 'noisyEditField');
    if ~isempty(noisyEditField) && isgraphics(noisyEditField)
        set(noisyEditField, 'String', '');
    end
    setappdata(hFig, 'noisyChannelsList', {});
end

function autoDetectNoisy(hFig)
    % Auto-detect channels with high noise and add to edit field
    axesHandles = getappdata(hFig, 'axesHandles');
    
    noisyChannelsList = {};
    for row = 1:16
        for col = 1:16
            ax = axesHandles(row, col);
            if isgraphics(ax)
                isHighNoise = getappdata(ax, 'isHighNoise');
                channelIdx = getappdata(ax, 'channelIdx');
                
                if ~isempty(isHighNoise) && isHighNoise && ~isempty(channelIdx)
                    elecName = getappdata(ax, 'elecName');
                    noisyChannelsList{end+1} = elecName;
                end
            end
        end
    end
    
    % Sort and update edit field
    noisyChannelsList = sort(noisyChannelsList);
    setappdata(hFig, 'noisyChannelsList', noisyChannelsList);
    
    noisyEditField = getappdata(hFig, 'noisyEditField');
    if ~isempty(noisyEditField) && isgraphics(noisyEditField)
        if isempty(noisyChannelsList)
            set(noisyEditField, 'String', '');
        else
            set(noisyEditField, 'String', strjoin(noisyChannelsList, ','));
        end
    end
    
    if ~isempty(noisyChannelsList)
        msgbox(sprintf('Auto-detected %d high-noise channels:\n%s', ...
               length(noisyChannelsList), strjoin(noisyChannelsList, ', ')), 'Auto-Detect');
    else
        msgbox('No high-noise channels detected.', 'Auto-Detect');
    end
end

function copyNoisyToClipboard(hFig)
    % Copy noisy channels to clipboard from edit field
    noisyEditField = getappdata(hFig, 'noisyEditField');
    noisyStr = strtrim(get(noisyEditField, 'String'));
    
    if isempty(noisyStr)
        clipboard('copy', '');
        msgbox('No channels specified. Clipboard cleared.', 'Copied');
    else
        clipboard('copy', noisyStr);
        msgbox(sprintf('Copied to clipboard:\n%s', noisyStr), 'Copied');
    end
end

function saveNoisyChannelsJSON(hFig)
% NEU V5: Speichert noisy_channels.json im H5-Ordner.
% Format identisch zum Standalone Channel Inspector und zur
% Auto-Load-Logik in Step 3 des Spike-GUI.
    noisyEditField = getappdata(hFig, 'noisyEditField');
    noisyStr  = strtrim(get(noisyEditField, 'String'));
    pathname  = getappdata(hFig, 'pathname');
    filename  = getappdata(hFig, 'filename');

    if isempty(pathname)
        msgbox('Kein H5-Ordner bekannt. Bitte H5-Datei neu laden.', 'Fehler', 'error');
        return;
    end

    % Kanaele aus Edit-Feld parsen
    if isempty(noisyStr)
        noisyChannels = {};
    else
        chRaw = strsplit(noisyStr, {',', ' ', ';'});
        noisyChannels = sort(strtrim(chRaw(~cellfun(@isempty, chRaw))));
    end

    % JSON-Struct aufbauen (identisches Format wie Standalone-Inspector)
    jsonStruct = struct();
    jsonStruct.noisy_channels = noisyChannels(:);
    jsonStruct.n_noisy        = numel(noisyChannels);
    jsonStruct.source_file    = filename;
    jsonStruct.created        = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    jsonStruct.notes          = '';

    outFile = fullfile(pathname, 'noisy_channels.json');

    % Pretty-print JSON schreiben
    try
        jsonText = jsonencode(jsonStruct, 'PrettyPrint', true);
    catch
        % Fallback fuer aeltere MATLAB-Versionen ohne PrettyPrint
        jsonText = jsonencode(jsonStruct);
        jsonText = strrep(jsonText, ',\"', sprintf(',\n  "'));
        jsonText = strrep(jsonText, '{',   sprintf('{\n  '));
        jsonText = strrep(jsonText, '}',   sprintf('\n}'));
    end

    fid = fopen(outFile, 'w');
    if fid < 0
        msgbox(sprintf('Datei konnte nicht geschrieben werden:\n%s', outFile), 'Fehler', 'error');
        return;
    end
    fprintf(fid, '%s', jsonText);
    fclose(fid);

    fprintf('\n✓ %d Noisy Channels gespeichert:\n  %s\n', numel(noisyChannels), outFile);
    msgbox(sprintf('✓ %d Kanaele gespeichert:\n%s\n\nWird beim naechsten H5-Load automatisch eingelesen.', ...
        numel(noisyChannels), outFile), 'noisy_channels.json gespeichert', 'help');
end

function showChannelDetails(ax, hFig)
    % Show detailed view of selected channel (right-click)
    channelIdx = getappdata(ax, 'channelIdx');
    if isempty(channelIdx), return; end
    
    elecName = getappdata(ax, 'elecName');
    stdVal = getappdata(ax, 'stdVal');
    pkpk = getappdata(ax, 'pkpk');
    
    rawData = getappdata(hFig, 'rawData');
    samplingRate = getappdata(hFig, 'samplingRate');
    filename = getappdata(hFig, 'filename');
    timeRange = getappdata(hFig, 'timeRange');
    
    trace = rawData(:, channelIdx);
    timeVec = (0:length(trace)-1) / samplingRate + timeRange(1);
    
    % Create detail figure
    detailFig = figure('Name', sprintf('Channel Details: %s', elecName), ...
                       'NumberTitle', 'off', ...
                       'Position', [200, 200, 1200, 700], ...
                       'Color', 'white');
    
    % Full trace
    subplot(3, 1, 1);
    plot(timeVec, trace, 'k-', 'LineWidth', 0.5);
    xlabel('Time (s)'); ylabel('Voltage (µV)');
    title(sprintf('Channel %s - Full Trace', elecName), 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    
    % Zoomed view
    subplot(3, 1, 2);
    maxSamples = min(2 * samplingRate, length(trace));
    plot(timeVec(1:maxSamples), trace(1:maxSamples), 'b-', 'LineWidth', 0.8);
    xlabel('Time (s)'); ylabel('Voltage (µV)');
    title('Zoomed View (First 2 seconds)', 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    
    % Power spectrum
    subplot(3, 1, 3);
    [pxx, f] = pwelch(trace, [], [], [], samplingRate);
    plot(f, 10*log10(pxx), 'r-', 'LineWidth', 1);
    xlabel('Frequency (Hz)'); ylabel('Power (dB/Hz)');
    title('Power Spectral Density', 'FontSize', 12, 'FontWeight', 'bold');
    xlim([0, min(500, samplingRate/2)]);
    grid on;
    
    sgtitle(sprintf('Channel: %s | Std: %.2f µV | Peak-to-Peak: %.2f µV | File: %s', ...
        elecName, stdVal, pkpk, filename), 'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');
end

% Helper functions for session settings (standalone versions)
function settings = loadSessionSettingsExternal()
    settings = struct();
    settingsFile = getSessionSettingsPathExternal();
    
    if exist(settingsFile, 'file')
        try
            fid = fopen(settingsFile, 'r');
            rawJson = fread(fid, inf, '*char')';
            fclose(fid);
            settings = jsondecode(rawJson);
        catch
            settings = struct();
        end
    end
    
    if ~isfield(settings, 'lastLayerDicPath'), settings.lastLayerDicPath = ''; end
    if ~isfield(settings, 'lastOutputParentDir'), settings.lastOutputParentDir = ''; end
    if ~isfield(settings, 'lastNoisyChannels'), settings.lastNoisyChannels = ''; end
end

function saveSessionSettingsExternal(settings)
    settingsFile = getSessionSettingsPathExternal();
    
    try
        jsonStr = jsonencode(settings);
        jsonStr = strrep(jsonStr, ',"', sprintf(',\n  "'));
        jsonStr = strrep(jsonStr, '{', sprintf('{\n  '));
        jsonStr = strrep(jsonStr, '}', sprintf('\n}'));
        
        fid = fopen(settingsFile, 'w');
        fprintf(fid, '%s', jsonStr);
        fclose(fid);
    catch
        warning('Could not save session settings');
    end
end

function settingsPath = getSessionSettingsPathExternal()
    userDir = userpath;
    if isempty(userDir)
        if ispc
            userDir = getenv('USERPROFILE');
        else
            userDir = getenv('HOME');
        end
    else
        userDir = strtrim(userDir);
        if userDir(end) == pathsep
            userDir = userDir(1:end-1);
        end
    end
    settingsPath = fullfile(userDir, 'MEA_GUI_session_settings.json');
end
function regionStr = cortexLayerName(val)
% Map LayerDic integer value to cortical layer name
switch val
    case 1,  regionStr = 'L1';
    case 2,  regionStr = 'L2/3';
    case 3,  regionStr = 'L4';
    case 4,  regionStr = 'L5/6';
    case 5,  regionStr = 'WM';
    otherwise, regionStr = 'Unknown';
end
end
