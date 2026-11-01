# AI-Aware Cache and Prefetch Engine

## Project Overview

This project implements an RTL-based cache subsystem with a stride-based
hardware prefetching mechanism. The design combines a direct-mapped
cache, stride predictor, prefetch controller, prefetch buffer, DRAM
arbiter, and behavioral DRAM model.

The project uses Python-generated memory-access traces to study memory
locality and evaluate cache and prefetch performance. RTL simulation is
performed using **Icarus Verilog**. Waveforms can be inspected using
**GTKWave**.

## Project Directory Structure

``` text
AI_Cache_Prefetch/
│
├── memory/
│   └── memory.hex
│
├── Python/
│   ├── analyse_traces.py
│   ├── cache_array_test
│   ├── cache_array_test.v
│   ├── cache_simulator.py
│   ├── generate_traces.py
│   ├── reuse_analysis.py
│   ├── reuse_results.txt
│   │
│   ├── results/
│   │   └── cache_comparison.csv
│   │
│   └── traces/
│       ├── matrix_column.csv
│       ├── matrix_row.csv
│       ├── mixed.csv
│       ├── random.csv
│       ├── repeated.csv
│       ├── sequential.csv
│       └── stride16.csv
│
├── rtl/
│   ├── cache_controller.v
│   ├── cache_system.v
│   ├── cache_tb.v
│   ├── dram_arbiter.v
│   ├── dram_model.v
│   ├── prefetch_buffer.v
│   ├── prefetch_controller.v
│   └── stride_predictor.v
│
├── simulation/
│   ├── arbiter_sim
│   ├── cache_prefetch_sim
│   ├── cache_sim
│   ├── cache_system_sim
│   ├── cache_tb.vcd
│   ├── dram.vcd
│   ├── dram_sim
│   ├── integrated_trace_sim
│   ├── predictor_sim
│   ├── prefetch_buffer_sim
│   ├── prefetch_controller_sim
│   ├── stride_predictor.vcd
│   ├── trace_sim
│   └── trace_tb.vcd
│
└── testbench/
    ├── cache_prefetch_tb.v
    ├── cache_system_tb.v
    ├── dram_arbiter_tb.v
    ├── integrated_trace_tb.v
    ├── prefetch_buffer_tb.v
    ├── prefetch_controller_tb.v
    ├── stride_predictor_tb.v
    ├── tb_dram.v
    └── trace_tb.v
```

## Directory Description

### `memory/`

Contains the memory initialization file used by the behavioral memory
model, where applicable.

### `Python/`

Contains Python scripts used for memory trace generation and cache
analysis.

  -----------------------------------------------------------------------
  File / Folder                       Description
  ----------------------------------- -----------------------------------
  `generate_traces.py`                Generates the seven memory-access
                                      traces.

  `analyse_traces.py`                 Analyses memory access patterns and
                                      trace characteristics.

  `cache_simulator.py`                Simulates cache configurations and
                                      evaluates their behaviour.

  `reuse_analysis.py`                 Analyses reuse/locality
                                      characteristics in the traces.

  `reuse_results.txt`                 Stores reuse-analysis output.

  `cache_array_test.v`                Verilog cache-array test source.

  `results/`                          Stores Python cache-analysis
                                      results.

  `traces/`                           Contains the CSV memory traces used
                                      for evaluation.
  -----------------------------------------------------------------------

The seven traces are:

-   `sequential.csv` -- sequential word accesses.
-   `stride16.csv` -- accesses separated by a fixed 16-byte stride.
-   `repeated.csv` -- repeated accesses to a small address set.
-   `random.csv` -- seeded random accesses.
-   `matrix_row.csv` -- row-major traversal of a matrix.
-   `matrix_column.csv` -- column-major traversal of a matrix.
-   `mixed.csv` -- a combination of different access patterns.

These are controlled synthetic traces generated for design evaluation;
they are not captured from real AI application workloads.

### `rtl/`

Contains the synthesizable RTL design modules and the cache testbench
source.

  -----------------------------------------------------------------------
  Module                              Responsibility
  ----------------------------------- -----------------------------------
  `cache_controller.v`                Controls cache lookup, hit/miss
                                      handling, line fill, and CPU
                                      response.

  `cache_system.v`                    Top-level integration of the cache
                                      and prefetch subsystem.

  `stride_predictor.v`                Detects repeated cache-line address
                                      strides and predicts a future line.

  `prefetch_controller.v`             Controls prefetch requests,
                                      duplicate checks, and returned
                                      prefetch data.

  `prefetch_buffer.v`                 Stores prefetched cache lines until
                                      they are requested by the CPU.

  `dram_arbiter.v`                    Arbitrates between demand requests
                                      and speculative prefetch requests.

  `dram_model.v`                      Behavioral DRAM model with
                                      configurable response latency.

  `cache_tb.v`                        Cache-level testbench.
  -----------------------------------------------------------------------

### `testbench/`

Contains testbenches for individual modules and the integrated design.

  -----------------------------------------------------------------------
  Testbench                           Purpose
  ----------------------------------- -----------------------------------
  `cache_prefetch_tb.v`               Tests cache and prefetch
                                      interaction.

  `cache_system_tb.v`                 Tests the integrated cache system.

  `dram_arbiter_tb.v`                 Tests DRAM request arbitration.

  `integrated_trace_tb.v`             Runs a CSV trace through the
                                      integrated cache and prefetch
                                      system and reports performance
                                      metrics.

  `prefetch_buffer_tb.v`              Tests prefetch-buffer insertion,
                                      lookup, and consumption.

  `prefetch_controller_tb.v`          Tests prefetch-controller
                                      operation.

  `stride_predictor_tb.v`             Tests stride detection and address
                                      prediction.

  `tb_dram.v`                         Tests the behavioral DRAM model.

  `trace_tb.v`                        Runs traces against the baseline
                                      cache.
  -----------------------------------------------------------------------

### `simulation/`

Contains generated Icarus Verilog simulation executables and waveform
files (`.vcd`). These files are outputs of simulation, not RTL source
files.

Waveforms can be opened with GTKWave, for example:

``` powershell
gtkwave simulation/trace_tb.vcd
```

The exact waveform to open depends on which simulation generated it.

## Architecture Summary

The integrated design contains two paths:

1.  **Demand path:** The CPU sends an address to the cache. On a cache
    miss, the cache checks the prefetch buffer. If the line is not
    available there, a demand request is sent to DRAM through the
    arbiter.
2.  **Prefetch path:** The stride predictor observes CPU cache-line
    accesses and predicts a future line. The prefetch controller checks
    whether that line is already in the main cache or prefetch buffer.
    If not, it requests the line through the DRAM arbiter. Returned data
    is stored in the prefetch buffer.

The DRAM arbiter gives demand requests priority over prefetch requests.

## Cache Configuration Used in the Prototype

The current experimental configuration is:

-   CPU address width: 32 bits.
-   CPU data width: 32 bits.
-   Cache data capacity: 1 KB.
-   Cache organization: direct-mapped.
-   Number of cache lines: 64.
-   Cache-line size: 16 bytes (128 bits).
-   Words per cache line: four 32-bit words.
-   Address fields: 22-bit tag, 6-bit index, and 4-bit byte offset.
-   Prefetch buffer: four entries.

These are prototype design parameters selected for the project
experiments, not Micron-provided specifications.

## Running the Integrated Trace Simulation

Run the following commands from the **project root directory** in
Windows PowerShell.

### 1. Compile

``` powershell
iverilog -g2012 -s integrated_trace_tb -o simulation/integrated_trace_sim rtl/cache_controller.v rtl/prefetch_buffer.v rtl/stride_predictor.v rtl/prefetch_controller.v rtl/dram_arbiter.v rtl/dram_model.v rtl/cache_system.v testbench/integrated_trace_tb.v
```

### 2. Run one trace

``` powershell
vvp simulation/integrated_trace_sim +TRACE=Python/traces/sequential.csv
```

### 3. Run the remaining traces

``` powershell
vvp simulation/integrated_trace_sim +TRACE=Python/traces/stride16.csv
vvp simulation/integrated_trace_sim +TRACE=Python/traces/repeated.csv
vvp simulation/integrated_trace_sim +TRACE=Python/traces/random.csv
vvp simulation/integrated_trace_sim +TRACE=Python/traces/matrix_row.csv
vvp simulation/integrated_trace_sim +TRACE=Python/traces/matrix_column.csv
vvp simulation/integrated_trace_sim +TRACE=Python/traces/mixed.csv
```

The integrated testbench reports cache hits and misses, prefetch-buffer
hits, demand DRAM requests, accepted prefetch requests, total DRAM
transactions, average CPU request latency, prefetch accuracy, and
prefetch coverage.

**Note:** These commands assume that the testbench uses the `TRACE`
plusarg and that the paths shown match the final project folder. If the
testbench or trace file names are changed, update the commands
accordingly.

## Simulation Tools

-   **Icarus Verilog (`iverilog`, `vvp`)** -- RTL compilation and
    simulation.
-   **GTKWave** -- viewing generated VCD waveforms.
-   **Python 3** -- trace generation, cache simulation, and analysis.

## Performance Metric Definitions

-   **Cache hit rate:** Main-cache hits divided by total CPU accesses.
-   **Prefetch accuracy:** Useful prefetch-buffer hits divided by
    accepted prefetch requests, using the benchmark's counting
    convention.
-   **Prefetch coverage:** CPU misses served by the prefetch buffer
    divided by initial cache misses.
-   **Demand DRAM requests:** DRAM transactions initiated to satisfy CPU
    misses.
-   **Total DRAM transactions:** Demand transactions plus accepted
    speculative prefetch transactions.

Demand-request reduction must not be described as total DRAM traffic
reduction. Speculative prefetches also consume DRAM transactions.

## Current Limitations and Future Work

-   The evaluated traces are synthetic, controlled access patterns
    rather than real AI workload traces.
-   The prototype focuses on read accesses.
-   The stride predictor is less effective for irregular and random
    access patterns.
-   The pending prediction storage is a one-entry slot; matrix-column
    testing showed that predictions can be overwritten while the
    prefetch controller is busy.
-   A multi-entry prediction FIFO, adaptive prefetch throttling, and
    evaluation with real AI memory traces are possible future
    improvements.
-   Power, physical area, timing closure, and post-layout performance
    have not been measured.

## Reproducibility and Submission Notes

-   Keep the RTL source files, testbenches, Python scripts, and all
    seven trace CSV files together.
-   Simulation executables can be regenerated using the compile commands
    above.
-   Retain relevant `.vcd` files if waveform evidence is required.
-   Ensure that the final `prefetch_controller.v` and
    `integrated_trace_tb.v` are the tested versions.
-   Do not include multiple ambiguous versions of the same RTL module in
    the final source submission.
