# 🧠 Design and Verification of HBM4 Memory Architecture

![SystemVerilog](https://img.shields.io/badge/SystemVerilog-RTL-blue?style=flat-square)
![UVM](https://img.shields.io/badge/Methodology-UVM-green?style=flat-square)
![Coverage](https://img.shields.io/badge/Functional%20Coverage-95.85%25-brightgreen?style=flat-square)
![Status](https://img.shields.io/badge/Status-Completed-success?style=flat-square)
![Institution](https://img.shields.io/badge/Institution-VIT%20Chennai-red?style=flat-square)

> **Internship Project @ Tata Consultancy Services (TCS)**  
> Feb 2026 – Apr 2026 | Mentor: Venkateswarlu Unnam  
> B.Tech ECE — Vellore Institute of Technology, Chennai

---

## 📌 Project Overview

This project implements and verifies an **HBM4 (High Bandwidth Memory 4) Logic Die interface** using **RTL design in SystemVerilog** and a full **UVM-based verification environment**.

HBM4 is the latest generation of stacked DRAM memory using Through Silicon Vias (TSVs) and microbumps to achieve ultra-high bandwidth — targeting over **1.5 TB/s** — for AI accelerators, HPC systems, and GPU architectures.

The design models the HBM4 Logic Die bank-level controller and verifies its functional correctness through directed and constrained-random simulation using UVM methodology.

---

## 🏗️ Architecture Overview

```
HBM4 Stack
│
├── DRAM Dies (up to 16, stacked vertically via TSV + Microbumps)
│
└── Logic Die (Base)
      ├── Command Processing Unit
      ├── Bank State Machine (FSM)
      ├── Timing Controller (tRCD, tWR, tRP, tRTP, WL, RL)
      ├── Memory Array
      ├── Burst Engine (DDR-like data transfer)
      ├── DQS Generator (WDQS / RDQS)
      └── PHY Wrapper (Clock forwarding, DQ control)
```

### Bank State Machine
```
IDLE → ACTIVATE → ACTIVE → WRITE / READ → PRECHARGE → IDLE
```

---

## ⚙️ Design Parameters

| Parameter   | Description           | Default |
|-------------|-----------------------|---------|
| `WL`        | Write Latency         | 4       |
| `RL`        | Read Latency          | 6       |
| `BL`        | Burst Length          | 8       |
| `tRCD`      | Activate Delay        | 7       |
| `tWTR`      | Write-to-Read Delay   | 4       |
| `tWR`       | Write Recovery        | 6       |
| `tRTP`      | Read-to-Precharge     | 4       |
| `tRP`       | Precharge Delay       | 7       |
| `MEM_DEPTH` | Memory Depth          | 16      |
| `DQ_W`      | Data Width            | 32      |

---

## 🧪 UVM Testbench Architecture

```
Testbench (Top)
└── Test Library (hbm4_test_lib)
      └── Environment (hbm4_env)
            ├── Agent (hbm4_agent)
            │     ├── Sequencer
            │     ├── Driver   → Interface → DUT
            │     └── Monitor  ← Interface ← DUT
            ├── Scoreboard (hbm4_scoreboard)
            └── Coverage Collector (hbm4_coverage)
```

### UVM Components

| Component            | Purpose                                      |
|----------------------|----------------------------------------------|
| `hbm4_item`          | Transaction abstraction (read/write objects) |
| `hbm4_seq_lib`       | Sequence library for stimulus generation     |
| `hbm4_driver`        | Converts transactions to pin-level signals   |
| `hbm4_monitor`       | Observes DUT outputs passively               |
| `hbm4_agent`         | Groups sequencer, driver, monitor            |
| `hbm4_env`           | Top-level verification environment           |
| `hbm4_scoreboard`    | Compares DUT output vs expected values       |
| `hbm4_coverage`      | Functional coverage collection               |

---

## 🔄 Verification Flow

### Write Transaction
```
Reset → Start → Activate → Column Command → Data Transfer (WDQS + DQ burst) → Precharge → Done
```

### Read Transaction
```
Read Command → Memory Access → Burst Output (RDQS + DQ) → Scoreboard Comparison → PASS/FAIL
```

### Test Types Implemented
- **Directed Testing** — deterministic scenario validation
- **Constrained Random Testing** — corner case coverage via sequence library
- **Assertion-Based Verification** — 7 concurrent SVA assertions
- **Coverage-Driven Verification** — covergroups for ops, address, data patterns

---

## 📊 Results

### Coverage Report

| Metric                    | Result     |
|---------------------------|------------|
| Overall Coverage          | **95.85%** |
| Statement Coverage        | 100.00%    |
| Branch Coverage           | 98.46%     |
| Toggle Coverage           | 98.50%     |
| FSM State Coverage        | **100.00%**|
| FSM Transition Coverage   | **100.00%**|
| Assertion Coverage        | 71.42%     |

### Scoreboard Summary

| Parameter           | Result  |
|---------------------|---------|
| Total WRITEs        | 1472    |
| Total READs         | 1516    |
| Data Comparison     | ✅ PASS |
| Burst Integrity     | ✅ PASS |
| Readback Accuracy   | ✅ PASS |
| Protocol Validation | ✅ PASS |
| FAIL Count          | 0       |

### UVM Simulation Summary

| Severity    | Count |
|-------------|-------|
| UVM INFO    | 1842  |
| UVM WARNING | 1     |
| UVM ERROR   | **0** |
| UVM FATAL   | **0** |

> ✅ **FINAL RESULT: TEST PASSED — Zero Mismatches**

---

## 🛠️ Tools Used

| Tool             | Purpose                                      |
|------------------|----------------------------------------------|
| **Quartus Prime**| RTL compilation, synthesis, functional debug |
| **EDA Playground**| Early UVM development and component testing |
| **QuestaSim**    | Full UVM simulation, coverage, waveform debug|
| **SystemVerilog**| RTL design and verification language         |

---

## 📁 Project Structure

```
hbm4-verification/
│
├── rtl/
│   ├── hbm4_bank_model.sv       # Top-level RTL
│   ├── bank_controller.sv       # FSM + command logic
│   ├── timing_controller.sv     # tRCD, tWR, tRP etc.
│   ├── burst_engine.sv          # Burst data handling
│   └── phy_wrapper.sv           # PHY clock/DQS/DQ interface
│
├── tb/
│   ├── hbm4_item.sv             # Transaction class
│   ├── hbm4_seq_lib.sv          # Sequence library
│   ├── hbm4_driver.sv           # Driver
│   ├── hbm4_monitor.sv          # Monitor
│   ├── hbm4_agent.sv            # Agent
│   ├── hbm4_scoreboard.sv       # Scoreboard
│   ├── hbm4_coverage.sv         # Coverage collector
│   ├── hbm4_env.sv              # Environment
│   └── hbm4_test_lib.sv         # Test library
│
├── assertions/
│   └── hbm4_sva.sv              # SystemVerilog Assertions (7 SVAs)
│
├── scripts/
│   └── run_sim.do               # QuestaSim run script
│
└── docs/
    └── report.pdf               # Full project report
```

---

## 🔬 Key Concepts Demonstrated

- **HBM4 Architecture** — Stack hierarchy, TSVs, Logic Die, PHY, pseudo channels
- **RTL Design** — Parameterized FSM, timing-accurate memory controller in SystemVerilog
- **UVM Methodology** — Full layered testbench from transaction to environment
- **Constrained Random Verification** — Automated corner case generation
- **SystemVerilog Assertions (SVA)** — Concurrent protocol property checking
- **Static Timing Analysis (STA)** — Zero TNS, worst-case setup slack of 4.443ns
- **Coverage-Driven Verification** — Covergroups across ops, addresses, data patterns, FSM

---

## 🚀 How to Run

```bash
# Clone the repository
git clone https://github.com/YSAdityaLohit/hbm4-verification.git
cd hbm4-verification

# Run in QuestaSim
vsim -do scripts/run_sim.do

# Or using command line
vlog -sv +incdir+tb/ rtl/*.sv tb/*.sv assertions/*.sv
vsim -c hbm4_top -do "run -all; quit"
```

---

## 📚 References

- JEDEC Standard JESD270-4 — HBM4 DRAM Standard
- Accellera UVM 1.2 Reference Manual
- Spear & Tumbush — *SystemVerilog for Verification*
- Sutherland — *SystemVerilog Assertions Handbook*
- Intel Quartus Prime & Mentor QuestaSim User Guides

---

## 👨‍💻 Author

**Y S Aditya Lohit**  
B.Tech ECE (22BEC1469) — VIT Chennai  
Internship @ TCS | Project: HBM4 Verification Using UVM Methodology  

---

## 📄 License

This project was developed for academic and internship purposes.  
© 2026 Y S Aditya Lohit — VIT Chennai / TCS
