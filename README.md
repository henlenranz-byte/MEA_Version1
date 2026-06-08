# MEA Analysis Suite

This repository contains **two separate MATLAB scripts** for Microelectrode Array (MEA) analysis, developed by **Henner Koch**.

---

## 📌 **Important: Execution Order**
**The `MEA_GUI_WithWorkingH5.m` must be run FIRST**, as it performs **event detection** (spike detection, stimulation analysis, etc.). The results (e.g., detected events, spike data) are required for the subsequent LFP analysis.

---

## 🔹 1. **MEA_GUI_WithWorkingH5.m** (Basis - Event Detection)
- **Purpose:** GUI-based tool for **spike and event detection** in MEA recordings.
- **Key Features:**
  - Event detection (spikes, bursts, etc.)
  - Stimulation analysis
  - High-Frequency Oscillation (HFO) detection (Ripples: 80–250Hz, Fast Ripples: 250–500Hz)
  - Propagation visualization (latency maps, wavefront paths, velocity distribution)
  - Session persistence (saves settings like LayerDic, output folder, noisy channels)
  - Embedded tools: LayerDic Generator, Channel Inspector
- **Dependencies:**
  - MATLAB (tested with recent versions)
  - Requires `.h5` (HDF5) file support for data input.
- **Output:**
  - Detected events, spike data, and metadata used by the LFP analysis script.

---

## 🔹 2. **MEA_LFP_Analysis_Suite_Mai2026_V15.m** (LFP Analysis)
- **Purpose:** Advanced **Local Field Potential (LFP) analysis** based on the events detected by `MEA_GUI_WithWorkingH5.m`.
- **Key Features:**
  - LFP signal processing
  - Analysis of network dynamics (e.g., synchrony, oscillations)
  - Visualization of LFP patterns
- **Dependencies:**
  - Output files from `MEA_GUI_WithWorkingH5.m` (e.g., event data, spike times).
  - MATLAB.

---

## 🚀 **Quick Start**
1. **Run Event Detection First:**
   ```matlab
   MEA_GUI_WithWorkingH5
   ```
   - Load your `.h5` data file.
   - Configure settings (LayerDic, output folder, etc.).
   - Run event detection and save results.

2. **Run LFP Analysis:**
   ```matlab
   MEA_LFP_Analysis_Suite_Mai2026_V15
   ```
   - Ensure the output from `MEA_GUI_WithWorkingH5.m` is in the expected directory.

---

## 📂 **Repository Structure**
```
MEA_Version1/
├── MEA_GUI_WithWorkingH5.m          # Basis: Event Detection (run first!)
├── MEA_LFP_Analysis_Suite_Mai2026_V15.m  # LFP Analysis (requires event data)
└── README.md                        # This file
```

---

## 🔧 **Notes**
- Both scripts are **independent** but designed to work together.
- The LFP analysis script **depends on the output** of the event detection GUI.
- For questions or issues, refer to the MATLAB console output or check the script headers for version history.
