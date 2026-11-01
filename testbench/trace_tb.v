
`timescale 1ns/1ps

module trace_tb;

    reg clk;
    reg rst;

    reg cpu_req;
    reg [31:0] cpu_addr;

    wire [31:0] cpu_rdata;
    wire cpu_ready;

    wire dram_req;
    wire [31:0] dram_addr;
    wire dram_busy;
    wire dram_resp_valid;
    wire [127:0] dram_resp_data;

    integer dram_count;
    integer cycle_count;
    integer total_latency;

    integer fd;
    integer scan_result;

    integer sequence_no;
    integer access_size;
    integer access_count;

    reg [7:0] operation;
    reg [31:0] trace_addr;
    reg [8*256-1:0] header;

    integer start_cycle;

    // Clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // --------------------------------------------
    // Cache instance
    // --------------------------------------------

    cache_controller cache (
        .clk(clk),
        .rst(rst),

        .cpu_req(cpu_req),
        .cpu_addr(cpu_addr),
        .cpu_rdata(cpu_rdata),
        .cpu_ready(cpu_ready),

        .dram_req(dram_req),
        .dram_addr(dram_addr),
        .dram_busy(dram_busy),
        .dram_resp_valid(dram_resp_valid),
        .dram_resp_data(dram_resp_data)
    );

    // --------------------------------------------
    // DRAM instance
    // --------------------------------------------

    dram_model #(
        .LATENCY(20),
        .MEM_WORDS(16384)
    ) dram (
        .clk(clk),
        .rst(rst),

        .dram_req(dram_req),
        .dram_addr(dram_addr),

        .dram_busy(dram_busy),
        .resp_valid(dram_resp_valid),
        .resp_data(dram_resp_data)
    );

    // --------------------------------------------
    // Performance counters
    // --------------------------------------------

    always @(posedge clk) begin
        if (rst) begin
            dram_count <= 0;
            cycle_count <= 0;
        end
        else begin
            cycle_count <= cycle_count + 1;

            if (dram_req)
                dram_count <= dram_count + 1;
        end
    end

    // --------------------------------------------
    // CPU read task
    // --------------------------------------------

    task cpu_read;
        input [31:0] address;

        begin
            @(negedge clk);

            cpu_addr = address;
            cpu_req = 1'b1;

            start_cycle = cycle_count;

            @(negedge clk);
            cpu_req = 1'b0;

            wait (cpu_ready == 1'b1);

            total_latency = total_latency +
                            (cycle_count - start_cycle);

            @(negedge clk);
        end
    endtask

    // --------------------------------------------
    // Main trace simulation
    // --------------------------------------------

    initial begin

        rst = 1'b1;
        cpu_req = 1'b0;
        cpu_addr = 32'b0;

        total_latency = 0;
        access_count = 0;

        repeat (3) @(negedge clk);
        rst = 1'b0;

        // Open CSV trace
        fd = $fopen("../level1_analysis/traces/mixed.csv", "r");

        if (fd == 0) begin
            $display("ERROR: Cannot open random.csv");
            $finish;
        end

        // Skip CSV header
        scan_result = $fgets(header, fd);

        $display("\n==================================");
        $display("       CACHE TRACE SIMULATION");
        $display("==================================");
        $display("Trace: mixed.csv");

        // Read CSV records
        scan_result = $fscanf(
            fd, "%d,%c,0x%h,%d\n",
            sequence_no, operation, trace_addr, access_size
        );

        while (scan_result == 4) begin

            if (operation == "R" && access_size == 4) begin

                cpu_read(trace_addr);
                access_count = access_count + 1;

            end
            else begin
                $display("Unsupported operation/size at sequence %0d",
                         sequence_no);
            end

            scan_result = $fscanf(
                fd, "%d,%c,0x%h,%d\n",
                sequence_no, operation, trace_addr, access_size
            );

        end

        $fclose(fd);

        // ----------------------------------------
        // Print final statistics
        // ----------------------------------------

        $display("\n========== RESULTS ==========");

        $display("Trace accesses = %0d", access_count);

        $display("Cache hits     = %0d", cache.hit_count);
        $display("Cache misses   = %0d", cache.miss_count);

        $display("DRAM requests  = %0d", dram_count);

        $display("Total cycles   = %0d", cycle_count);

        $display("Total request latency (cycles) = %0d",
                 total_latency);

        $display("Average request latency = %0f cycles",
                 1.0 * total_latency / access_count);

        $display("Hit rate  = %0f percent",
                 100.0 * cache.hit_count / access_count);

        $display("Miss rate = %0f percent",
                 100.0 * cache.miss_count / access_count);

        $display("=============================");

        $finish;
    end

    // --------------------------------------------
    // Waveform
    // --------------------------------------------

    initial begin
        $dumpfile("trace_tb.vcd");
        $dumpvars(0, trace_tb);
    end

endmodule
