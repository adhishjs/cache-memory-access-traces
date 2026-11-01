
`timescale 1ns/1ps

module cache_tb;

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

    // Clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Cache instance
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

    // DRAM instance
    dram_model #(
        .LATENCY(20),
        .MEM_WORDS(4096)
    ) dram (
        .clk(clk),
        .rst(rst),

        .dram_req(dram_req),
        .dram_addr(dram_addr),

        .dram_busy(dram_busy),
        .resp_valid(dram_resp_valid),
        .resp_data(dram_resp_data)
    );

    // Count DRAM requests
    always @(posedge clk) begin
        if (rst)
            dram_count <= 0;
        else if (dram_req)
            dram_count <= dram_count + 1;
    end

    // CPU read task
    task cpu_read;
        input [31:0] address;

        begin
            @(negedge clk);
            cpu_addr = address;
            cpu_req = 1'b1;

            // Request is accepted at the next rising edge
            @(negedge clk);
            cpu_req = 1'b0;

            wait (cpu_ready == 1'b1);

            $display("Time=%0t | Address=%h | Data=%h",
                     $time, address, cpu_rdata);

            @(negedge clk);
        end
    endtask


    initial begin

        rst = 1'b1;
        cpu_req = 1'b0;
        cpu_addr = 32'b0;
        dram_count = 0;

        repeat (3) @(negedge clk);
        rst = 1'b0;

        $display("\n--- READ WORD 3 ---");
        cpu_read(32'h0000100C);

        $display("\n--- READ WORD 0 ---");
        cpu_read(32'h00001000);

        $display("\n--- READ WORD 1 ---");
        cpu_read(32'h00001004);

        $display("\n--- READ WORD 2 ---");
        cpu_read(32'h00001008);

        $display("\n--- CONFLICT TEST: READ 0x1000 ---");
        cpu_read(32'h00001000);

        $display("\n--- CONFLICT TEST: READ 0x2000 ---");
        cpu_read(32'h00002000);

        $display("\n--- CONFLICT TEST: READ 0x1000 AGAIN ---");
        cpu_read(32'h00001000);

        $display("\nTotal DRAM requests = %0d", dram_count);



        if (dram_count == 3)
            $display("TEST PASSED: Direct-mapped conflict demonstrated.");
        else
            $display("TEST FAILED: Unexpected DRAM request count.");

        $display("\n--- CACHE PERFORMANCE ---");

        $display("Cache hits   = %0d", cache.hit_count);
        $display("Cache misses = %0d", cache.miss_count);

        $display("Total accesses = %0d",
                cache.hit_count + cache.miss_count);

        $display("Hit rate = %0f percent",
                100.0 * cache.hit_count /
                (cache.hit_count + cache.miss_count));

        $display("Miss rate = %0f percent",
                100.0 * cache.miss_count /
                (cache.hit_count + cache.miss_count));

        #20;
        $finish;
    end


    // Generate waveform
    initial begin
        $dumpfile("cache_tb.vcd");
        $dumpvars(0, cache_tb);
    end

endmodule
