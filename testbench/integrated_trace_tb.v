`timescale 1ns/1ps

module integrated_trace_tb;

    reg clk;
    reg rst;
    reg cpu_req;
    reg [31:0] cpu_addr;

    wire [31:0] cpu_rdata;
    wire cpu_ready;

    integer fd;
    integer scan_result;
    integer sequence_no;
    integer access_size;
    integer access_count;
    integer cycle_count;
    integer total_latency;
    integer start_cycle;

    integer dram_requests;
    integer demand_requests;
    integer prefetch_requests;

    reg [7:0] operation;
    reg [31:0] trace_addr;
    reg [8*256-1:0] header;
    reg [8*256-1:0] trace_file;

    real hit_rate;
    real miss_rate;
    real avg_latency;
    real prefetch_accuracy;
    real prefetch_coverage;

    cache_system dut (
        .clk(clk),
        .rst(rst),
        .cpu_req(cpu_req),
        .cpu_addr(cpu_addr),
        .cpu_rdata(cpu_rdata),
        .cpu_ready(cpu_ready)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Count accepted transactions, not request signal-high cycles.
    // The arbiter's accept signals identify one accepted transaction.
    always @(posedge clk) begin
        if (rst) begin
            cycle_count       <= 0;
            dram_requests     <= 0;
            demand_requests   <= 0;
            prefetch_requests <= 0;
        end
        else begin
            cycle_count <= cycle_count + 1;

            // Total DRAM transactions are calculated after the trace as
            // demand_accepts + prefetch_accepts. Do not count request-high
            // cycles here: a request can remain asserted while waiting.
            if (dut.demand_accept)
                demand_requests <= demand_requests + 1;

            if (dut.prefetch_accept)
                prefetch_requests <= prefetch_requests + 1;
        end
    end

    task cpu_read;
        input [31:0] address;
        begin
            @(negedge clk);
            cpu_addr = address;
            cpu_req  = 1'b1;
            start_cycle = cycle_count;

            @(negedge clk);
            cpu_req = 1'b0;

            wait (cpu_ready === 1'b1);

            total_latency = total_latency +
                            (cycle_count - start_cycle);

            access_count = access_count + 1;

            // Allow the controller to leave RESPOND before next request.
            @(negedge clk);
        end
    endtask

    initial begin
        rst = 1'b1;
        cpu_req = 1'b0;
        cpu_addr = 32'b0;

        access_count = 0;
        total_latency = 0;

        if (!$value$plusargs("TRACE=%s", trace_file)) begin
            $display("ERROR: supply trace path using +TRACE=<file>");
            $finish;
        end

        repeat (4) @(negedge clk);
        rst = 1'b0;

        // Wait one full cycle after reset deassertion.
        @(negedge clk);

        fd = $fopen(trace_file, "r");
        if (fd == 0) begin
            $display("ERROR: Cannot open trace: %0s", trace_file);
            $finish;
        end

        scan_result = $fgets(header, fd);

        $display("");
        $display("==================================================");
        $display("INTEGRATED CACHE + PREFETCH TRACE BENCHMARK");
        $display("Trace: %0s", trace_file);
        $display("==================================================");

        scan_result = $fscanf(
            fd, "%d,%c,0x%h,%d\n",
            sequence_no, operation, trace_addr, access_size
        );

        while (scan_result == 4) begin
            if ((operation == "R") && (access_size == 4)) begin
                cpu_read(trace_addr);
            end
            else begin
                $display("WARNING: skipped sequence %0d op=%c size=%0d",
                         sequence_no, operation, access_size);
            end

            scan_result = $fscanf(
                fd, "%d,%c,0x%h,%d\n",
                sequence_no, operation, trace_addr, access_size
            );
        end

        $fclose(fd);

        // Allow final accepted prefetches to complete. These are counted
        // as issued requests even if the trace never consumes their data.
        repeat (30) @(negedge clk);

        // Count accepted transactions, not combinational request cycles.
        dram_requests = demand_requests + prefetch_requests;

        if (access_count > 0) begin
            hit_rate = 100.0 * dut.cache.hit_count / access_count;
            miss_rate = 100.0 * dut.cache.miss_count / access_count;
            avg_latency = 1.0 * total_latency / access_count;
        end
        else begin
            hit_rate = 0.0;
            miss_rate = 0.0;
            avg_latency = 0.0;
        end

        if (dut.issued_count > 0)
            prefetch_accuracy =
                100.0 * dut.cache.prefetch_hit_count / dut.issued_count;
        else
            prefetch_accuracy = 0.0;

        if (dut.cache.miss_count > 0)
            prefetch_coverage =
                100.0 * dut.cache.prefetch_hit_count /
                dut.cache.miss_count;
        else
            prefetch_coverage = 0.0;

        $display("");
        $display("-------------------- RESULTS ----------------------");
        $display("Trace accesses             = %0d", access_count);
        $display("Main-cache hits             = %0d", dut.cache.hit_count);
        $display("Initial cache misses        = %0d", dut.cache.miss_count);
        $display("Prefetch-buffer hits        = %0d",
                 dut.cache.prefetch_hit_count);
        $display("Demand DRAM requests        = %0d", demand_requests);
        $display("Prefetch requests accepted  = %0d", prefetch_requests);
        $display("Total DRAM requests         = %0d", dram_requests);
        $display("Prefetch controller issued  = %0d", dut.issued_count);
        $display("Duplicate predictions       = %0d", dut.duplicate_count);

        // Pending-prediction slot diagnostics from prefetch_ctrl.
        $display("Pending predictions captured = %0d",
                 dut.prefetch_ctrl.pending_capture_count);
        $display("Pending predictions overwritten = %0d",
                 dut.prefetch_ctrl.pending_overwrite_count);
        $display("Pending predictions consumed = %0d",
                 dut.prefetch_ctrl.pending_consume_count);

        $display("Total measured cycles       = %0d", cycle_count);
        $display("Total CPU request latency   = %0d cycles", total_latency);
        $display("Average CPU latency         = %0f cycles", avg_latency);
        $display("Main-cache hit rate         = %0f %%", hit_rate);
        $display("Initial miss rate           = %0f %%", miss_rate);
        $display("Prefetch accuracy           = %0f %%", prefetch_accuracy);
        $display("Prefetch coverage            = %0f %%", prefetch_coverage);
        $display("--------------------------------------------------");

        $display("CSV_RESULT,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0f,%0f,%0f",
                 access_count,
                 dut.cache.hit_count,
                 dut.cache.miss_count,
                 dut.cache.prefetch_hit_count,
                 demand_requests,
                 prefetch_requests,
                 dram_requests,
                 avg_latency,
                 prefetch_accuracy,
                 prefetch_coverage);

        $display("PENDING_RESULT,%0d,%0d,%0d",
                 dut.prefetch_ctrl.pending_capture_count,
                 dut.prefetch_ctrl.pending_overwrite_count,
                 dut.prefetch_ctrl.pending_consume_count);

        $finish;
    end

endmodule
