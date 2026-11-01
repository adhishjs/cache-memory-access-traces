
module cache_prefetch_tb;

    reg clk, rst;

    // CPU interface
    reg cpu_req;
    reg [31:0] cpu_addr;
    wire [31:0] cpu_rdata;
    wire cpu_ready;

    // Cache -> arbiter
    wire demand_req;
    wire [31:0] demand_addr;
    wire demand_accept;
    wire demand_resp_valid;
    wire [127:0] demand_resp_data;

    // Cache -> prefetch buffer
    wire pb_lookup;
    wire [27:0] pb_lookup_line;
    wire pb_hit;
    wire [127:0] pb_hit_data;
    wire pb_consume;
    wire [27:0] pb_consume_line;

    // Testbench -> prefetch buffer insertion
    reg pb_insert;
    reg [27:0] pb_insert_line;
    reg [127:0] pb_insert_data;

    // Prefetch buffer
    wire pb_dummy_hit;
    wire [127:0] pb_dummy_data;

    // Arbiter -> DRAM
    wire dram_req;
    wire [31:0] dram_addr;
    wire dram_busy;
    wire dram_resp_valid;
    wire [127:0] dram_resp_data;

    integer dram_request_count;

    cache_controller cache (
        .clk(clk),
        .rst(rst),

        .cpu_req(cpu_req),
        .cpu_addr(cpu_addr),
        .cpu_rdata(cpu_rdata),
        .cpu_ready(cpu_ready),

        .demand_req(demand_req),
        .demand_addr(demand_addr),
        .demand_accept(demand_accept),
        .demand_resp_valid(demand_resp_valid),
        .demand_resp_data(demand_resp_data),

        .pb_lookup(pb_lookup),
        .pb_lookup_line(pb_lookup_line),
        .pb_hit(pb_hit),
        .pb_hit_data(pb_hit_data),

        .pb_consume(pb_consume),
        .pb_consume_line(pb_consume_line),
        .probe_valid(1'b0),
        .probe_line(28'b0),
        .probe_hit()
    );

    prefetch_buffer pb (
        .clk(clk),
        .rst(rst),

        .insert(pb_insert),
        .insert_line(pb_insert_line),
        .insert_data(pb_insert_data),

        .lookup(pb_lookup),
        .lookup_line(pb_lookup_line),
        .hit(pb_hit),
        .hit_data(pb_hit_data),

        .consume(pb_consume),
        .consume_line(pb_consume_line),
        .probe_valid(1'b0),
        .probe_line(28'b0),
        .probe_hit()
    );

    dram_arbiter arbiter (
        .clk(clk),
        .rst(rst),

        .demand_req(demand_req),
        .demand_addr(demand_addr),
        .demand_accept(demand_accept),
        .demand_resp_valid(demand_resp_valid),
        .demand_resp_data(demand_resp_data),

        .prefetch_req(1'b0),
        .prefetch_addr(32'b0),
        .prefetch_accept(),
        .prefetch_resp_valid(),
        .prefetch_resp_data(),

        .dram_req(dram_req),
        .dram_addr(dram_addr),
        .dram_busy(dram_busy),
        .dram_resp_valid(dram_resp_valid),
        .dram_resp_data(dram_resp_data)
    );

    dram_model #(
        .LATENCY(5),
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

    always #5 clk = ~clk;

    // Count DRAM requests
    always @(posedge clk) begin
        if (rst)
            dram_request_count <= 0;
        else if (dram_req && !dram_busy)
            dram_request_count <= dram_request_count + 1;
    end

    task cpu_read;
        input [31:0] address;
        begin
            @(negedge clk);
            cpu_addr = address;
            cpu_req = 1;

            @(negedge clk);
            cpu_req = 0;

            wait(cpu_ready);
            #1;

            $display("CPU read %h -> %h",
                     address, cpu_rdata);
        end
    endtask

    initial begin
        clk = 0;
        rst = 1;

        cpu_req = 0;
        cpu_addr = 0;

        pb_insert = 0;
        pb_insert_line = 0;
        pb_insert_data = 0;

        dram_request_count = 0;

        repeat (3) @(negedge clk);
        rst = 0;

        // TEST 1: Demand miss
        $display("\n--- TEST 1: MAIN CACHE MISS ---");
        cpu_read(32'h00001000);

        if (cpu_rdata !== 32'hA5000400)
            $display("ERROR: Incorrect demand data");
        else
            $display("PASS: Demand data correct");

        // TEST 2: Main cache hit
        $display("\n--- TEST 2: MAIN CACHE HIT ---");
        cpu_read(32'h00001000);

        if (dram_request_count != 1)
            $display("ERROR: Unexpected DRAM request");
        else
            $display("PASS: No additional DRAM request");

        // TEST 3: Insert prefetched line manually
        $display("\n--- TEST 3: PREFETCH BUFFER HIT ---");

        @(negedge clk);
        pb_insert = 1;
        pb_insert_line = 28'h0000200;
        pb_insert_data = 128'hA5000803_A5000802_A5000801_A5000800;

        @(negedge clk);
        pb_insert = 0;

        cpu_read(32'h00002000);

        if (cpu_rdata !== 32'hA5000800)
            $display("ERROR: Incorrect prefetch data");
        else
            $display("PASS: Prefetch data correct");

        if (dram_request_count != 1)
            $display("ERROR: Prefetch hit caused DRAM access");
        else
            $display("PASS: Prefetch hit avoided DRAM access");

        // TEST 4: Promoted line should now hit main cache
        $display("\n--- TEST 4: PROMOTED CACHE LINE ---");

        cpu_read(32'h00002000);

        if (dram_request_count != 1)
            $display("ERROR: Unexpected DRAM request");
        else
            $display("PASS: Promoted line is in main cache");

        $display("\nTotal DRAM requests = %0d",
                 dram_request_count);

        $display("\n--- INTEGRATION TEST COMPLETE ---");

        #20;
        $finish;
    end

endmodule
