# MEA Analysis Suite

This repository contains **two separate MATLAB scripts** for Microelectrode Array (MEA) analysis, developed by **Henner Koch**.

---

## \ud83d\udccc **Important: Execution Order**
**The `MEA_GUI_Spike_2026_July_V7.m` must be run FIRST**, as it performs **event detection** (spike detection, stimulation analysis, etc.). The results (e.g., detected events, spike data) are required for the subsequent LFP analysis.

---

## \ud83d\udd39 1. **MEA_GUI_Spike_2026_July_V7.m** (Basis - Event Detection)
- **Purpose:** GUI-based tool for **spike and event detection** in MEA recordings.
- **Key Features:**
  - Event detection (spikes, bursts, etc.)
  - Stimulation analysis
  - High-Frequency Oscillation (HFO) detection (Ripples: 80\u2013250Hz, Fast Ripples: 250\u2013500Hz)
  - Propagation visualization (latency maps, wavefront paths, velocity distribution)
  - Session persistence (saves settings like LayerDic, output folder, noisy channels)
  - Embedded tools: LayerDic Generator, Channel Inspector
- **Dependencies:**
  - MATLAB (tested with recent versions)
  - Requires `.h5` (HDF5) file support for data input.
- **Output:**
  - Detected events, spike data, and metadata used by the LFP analysis script.

---

## \ud83d\udd39 2. **MEA_LFP_Analysis_Suite_Mai2026_V15.m** (LFP Analysis)
- **Purpose:** Advanced **Local Field Potential (LFP) analysis** based on the events detected by `MEA_GUI_Spike_2026_July_V7.m`.
- **Key Features:**
  - LFP signal processing
  - Analysis of network dynamics (e.g., synchrony, oscillations)
  - Visualization of LFP patterns
- **Dependencies:**
  - Output files from `MEA_GUI_Spike_2026_July_V7.m` (e.g., event data, spike times).
  - MATLAB.

---

## \ud83d\ude80 **Quick Start**
1. **Run Event Detection First:**
   ```matlab
   MEA_GUI_Spike_2026_July_V7
   ```
   - Load your `.h5` data file.
   - Configure settings (LayerDic, output folder, etc.).
   - Run event detection and save results.

2. **Run LFP Analysis:**
   ```matlab
   MEA_LFP_Analysis_Suite_Mai2026_V15
   ```
   - Ensure the output from `MEA_GUI_Spike_2026_July_V7.m` is in the expected directory.

---

## \ud83d\udcc2 **Repository Structure**
```
MEA_Version1/
\u251c\u2500\u2500 MEA_GUI_Spike_2026_July_V7.m          # Basis: Event Detection (run first!)
\u251c\u2500\u2500 MEA_LFP_Analysis_Suite_Mai2026_V15.m  # LFP Analysis (requires event data)
\u2514\u2500\u2500 README.md                        # This file
```

---

## \ud83d\udd27 **Notes**
- Both scripts are **independent** but designed to work together.
- The LFP analysis script **depends on the output** of the event detection GUI.
- For questions or issues, refer to the MATLAB console output or check the script headers for version history.
